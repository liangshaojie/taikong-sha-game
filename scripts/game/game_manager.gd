extends Node

# GameManager - 游戏状态机（Autoload）
# 服务端为权威：分配角色、校验击杀、处理会议与投票、判定胜负

signal game_state_changed(new_state: int)
signal role_assigned(my_role: int)
signal player_died(peer_id: int)
signal meeting_started(caller_peer_id: int)
signal vote_started()
signal vote_ended(outed_peer_id: int)         # -1 表示无人出局
signal game_over(winning_role: int, reason: String)
signal task_progress_changed(completed: int, total: int)
signal kill_cooldown_changed(remaining: float)
signal player_revived(peer_id: int)

enum State { LOBBY, ROLE_ASSIGN, PLAYING, MEETING, VOTING, RESULT }

const IMPOSTOR_RATIO := 0.30                # 内鬼比例（向上取整，最少 1 个）
const KILL_COOLDOWN := 30.0                 # 内鬼击杀冷却（秒）
const KILL_RANGE := 70.0                    # 击杀最大距离（像素）
const TASK_TOTAL := 3                       # 任务总数
const TASK_DURATION := 3.0                  # 完成任务需要按住的时间
const MEETING_COOLDOWN := 15.0              # 紧急会议冷却

# === State ===
var game_state: int = State.LOBBY
var my_role: int = Role.Kind.UNKNOWN
var player_roles: Dictionary = {}           # peer_id -> {role, alive}
var tasks_completed: int = 0
var kill_cooldown_remaining: float = 0.0
var last_meeting_time: float = -999.0

# Server-internal
var _votes: Dictionary = {}                 # voter_peer_id -> target_peer_id (-1 = skip)

func _ready() -> void:
	Lobby.game_starting.connect(_on_game_starting)

# 当 Lobby 通知游戏场景即将加载时，服务端自动开始分配角色
# 这样 main.gd 不需要显式调用 start_game_session()
func _on_game_starting(_path: String) -> void:
	if multiplayer.is_server():
		start_game_session()

# ============================================================
# Public API - 服务端调用
# ============================================================

func start_game_session() -> void:
	"""服务端在玩家全部进入游戏后调用，分配角色并开始。"""
	if not multiplayer.is_server():
		push_warning("[GameManager] start_game_session must be called on server")
		return
	_assign_roles_and_begin()

# ============================================================
# Public API - 任何客户端调用
# ============================================================

func request_kill(target_peer_id: int) -> void:
	"""内鬼按 K 时调用。"""
	if multiplayer.is_server():
		_server_handle_kill(multiplayer.get_unique_id(), target_peer_id)
	else:
		rpc_id(1, "server_kill", target_peer_id)

func request_meeting() -> void:
	"""任何活着的玩家按 R 时调用。"""
	if multiplayer.is_server():
		_server_handle_meeting(multiplayer.get_unique_id())
	else:
		rpc_id(1, "server_meeting")

func request_vote(target_peer_id: int) -> void:
	"""投票（target_peer_id = -1 表示跳过）。"""
	if multiplayer.is_server():
		_server_handle_vote(multiplayer.get_unique_id(), target_peer_id)
	else:
		rpc_id(1, "server_vote", target_peer_id)

func report_task_done(task_id: String) -> void:
	"""船员完成任务时调用。"""
	if multiplayer.is_server():
		_server_handle_task_done(multiplayer.get_unique_id(), task_id)
	else:
		rpc_id(1, "server_task_done", task_id)

func get_player_role(peer_id: int) -> int:
	if player_roles.has(peer_id):
		return player_roles[peer_id].role
	return Role.Kind.UNKNOWN

func is_alive(peer_id: int) -> bool:
	# 角色未分配时默认认为是活着的（避免被误判成鬼魂）
	if not player_roles.has(peer_id):
		return true
	return player_roles[peer_id].alive

func am_i_alive() -> bool:
	return is_alive(Lobby.get_my_id())

func am_i_crewmate() -> bool:
	return my_role == Role.Kind.CREWMATE

func am_i_impostor() -> bool:
	return my_role == Role.Kind.IMPOSTOR

func am_i_ghost() -> bool:
	# 鬼魂 = 角色已分配且已死亡
	# 角色还没分配时不算鬼魂（避免在分配前的瞬间被锁住）
	return player_roles.has(Lobby.get_my_id()) and not is_alive(Lobby.get_my_id())

# ============================================================
# Server logic
# ============================================================

func _assign_roles_and_begin() -> void:
	var peer_ids: Array = Lobby.players.keys()
	peer_ids.sort()
	var impostor_count: int = max(1, int(ceil(float(peer_ids.size()) * IMPOSTOR_RATIO)))

	# 随机选内鬼
	var shuffled := peer_ids.duplicate()
	shuffled.shuffle()
	var impostors := shuffled.slice(0, impostor_count)

	player_roles.clear()
	for pid in peer_ids:
		var role := Role.Kind.IMPOSTOR if impostors.has(pid) else Role.Kind.CREWMATE
		player_roles[pid] = {"role": role, "alive": true}

	print("[GameManager] Roles assigned: %d players, %d impostors" % [peer_ids.size(), impostor_count])
	for pid in player_roles:
		print("  peer %d → %s" % [pid, Role.name_zh(player_roles[pid].role)])

	# 服务器本地直接设置自己的角色（rpc_id 不会本地执行）
	var server_id := multiplayer.get_unique_id()
	if player_roles.has(server_id):
		my_role = player_roles[server_id].role
		role_assigned.emit(my_role)
		print("[GameManager] Server's role: %s" % Role.name_zh(my_role))

	# 告知每个**客户端**自己的角色（跳过服务器自己）
	for pid in player_roles:
		if pid != server_id:
			rpc_id(pid, "client_receive_role", player_roles[pid].role)

	# 切换状态
	game_state = State.PLAYING
	tasks_completed = 0
	rpc("client_game_started")

func _server_handle_kill(killer_id: int, target_id: int) -> void:
	if game_state != State.PLAYING:
		return
	if not player_roles.has(killer_id) or not player_roles.has(target_id):
		return
	var killer_info: Dictionary = player_roles[killer_id]
	if killer_info.role != Role.Kind.IMPOSTOR or not killer_info.alive:
		return
	if not player_roles[target_id].alive:
		return
	if kill_cooldown_remaining > 0.0:
		print("[GameManager] Kill rejected: cooldown %.1fs" % kill_cooldown_remaining)
		return
	# 距离校验：服务端需要知道双方位置
	var killer_pos := _get_player_position(killer_id)
	var target_pos := _get_player_position(target_id)
	if killer_pos == Vector2.ZERO and target_pos == Vector2.ZERO:
		# 拿不到位置（可能是测试场景），暂时跳过距离校验
		pass
	else:
		var dist := killer_pos.distance_to(target_pos)
		if dist > KILL_RANGE:
			print("[GameManager] Kill rejected: distance %.1f > %.1f" % [dist, KILL_RANGE])
			return

	# 击杀成功
	print("[GameManager] Peer %d killed peer %d" % [killer_id, target_id])
	kill_cooldown_remaining = KILL_COOLDOWN
	rpc("client_set_kill_cooldown", KILL_COOLDOWN)
	_server_kill_player(target_id)

func _server_kill_player(victim_id: int) -> void:
	if not player_roles.has(victim_id) or not player_roles[victim_id].alive:
		return
	player_roles[victim_id].alive = false
	rpc("client_player_died", victim_id)
	_check_win_condition()

func _server_handle_meeting(caller_id: int) -> void:
	if game_state != State.PLAYING:
		return
	if not player_roles.has(caller_id) or not player_roles[caller_id].alive:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_meeting_time < MEETING_COOLDOWN:
		print("[GameManager] Meeting rejected: cooldown")
		return
	last_meeting_time = now
	print("[GameManager] Meeting called by peer %d" % caller_id)
	game_state = State.MEETING
	_votes.clear()
	rpc("client_meeting_started", caller_id)
	# 简化：会议直接进入投票
	_start_voting()

func _start_voting() -> void:
	game_state = State.VOTING
	_votes.clear()
	rpc("client_vote_started")

func _server_handle_vote(voter_id: int, target_id: int) -> void:
	if game_state != State.VOTING:
		return
	if not player_roles.has(voter_id):
		return
	_votes[voter_id] = target_id
	print("[GameManager] Vote: %d → %d (%d/%d)" % [voter_id, target_id, _votes.size(), _count_alive()])
	if _votes.size() >= _count_alive():
		_tally_votes()

func _tally_votes() -> void:
	# 不要改 game_state，保留在 VOTING/MEETING，让 _check_win_condition 决定
	var tally: Dictionary = {}
	for target in _votes.values():
		tally[target] = tally.get(target, 0) + 1
	var max_votes := -1
	var outed := -1
	var tied := false
	for target in tally:
		var v: int = tally[target]
		if v > max_votes:
			max_votes = v
			outed = target
			tied = false
		elif v == max_votes:
			tied = true
	if tied or outed == -1:
		outed = -1
		print("[GameManager] Voting tied or no votes - no ejection")
	else:
		print("[GameManager] Ejected peer %d with %d votes" % [outed, max_votes])
		if player_roles.has(outed):
			player_roles[outed].alive = false
	_votes.clear()
	rpc("client_vote_ended", outed)
	_check_win_condition()
	# 如果没有胜负，3 秒后回到 PLAYING（让客户端 UI 有时间显示结果）
	if game_state != State.RESULT:
		await get_tree().create_timer(3.0).timeout
		if game_state != State.RESULT:  # 期间可能游戏结束了
			game_state = State.PLAYING
			rpc("client_resume_playing")

func _server_handle_task_done(peer_id: int, task_id: String) -> void:
	if game_state != State.PLAYING:
		return
	if not player_roles.has(peer_id):
		return
	if player_roles[peer_id].role != Role.Kind.CREWMATE or not player_roles[peer_id].alive:
		return
	tasks_completed += 1
	print("[GameManager] Task '%s' done by peer %d (total %d/%d)" % [task_id, peer_id, tasks_completed, TASK_TOTAL])
	rpc("client_task_progress", tasks_completed)
	_check_win_condition()

func _check_win_condition() -> void:
	if game_state == State.RESULT:
		return
	var crewmates := 0
	var impostors := 0
	for info in player_roles.values():
		if not info.alive:
			continue
		if info.role == Role.Kind.CREWMATE:
			crewmates += 1
		elif info.role == Role.Kind.IMPOSTOR:
			impostors += 1

	var winner := -1
	var reason := ""
	if impostors == 0 and player_roles.size() > 0:
		winner = Role.Kind.CREWMATE
		reason = "所有内鬼被淘汰！船员胜利！"
	elif impostors >= crewmates and crewmates > 0:
		winner = Role.Kind.IMPOSTOR
		reason = "内鬼数量≥船员，内鬼胜利！"
	elif tasks_completed >= TASK_TOTAL:
		winner = Role.Kind.CREWMATE
		reason = "所有任务完成！船员胜利！"

	if winner != -1:
		_end_game(winner, reason)

func _end_game(winner: int, reason: String) -> void:
	game_state = State.RESULT
	print("[GameManager] Game over: %s" % reason)
	rpc("client_game_over", winner, reason)

func _get_player_position(peer_id: int) -> Vector2:
	# 通过节点路径查找玩家位置
	var node := get_tree().root.get_node_or_null("Main/Players/" + str(peer_id))
	if node and node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO

func _count_alive() -> int:
	var count := 0
	for info in player_roles.values():
		if info.alive:
			count += 1
	return count

# ============================================================
# RPCs - 客户端接收
# ============================================================

@rpc("authority", "call_remote", "reliable")
func client_receive_role(role: int) -> void:
	my_role = role
	role_assigned.emit(role)
	print("[GameManager] My role: %s" % Role.name_zh(role))

@rpc("authority", "call_remote", "reliable")
func client_game_started() -> void:
	game_state = State.PLAYING
	tasks_completed = 0
	game_state_changed.emit(game_state)
	task_progress_changed.emit(0, TASK_TOTAL)

@rpc("authority", "call_remote", "reliable")
func client_resume_playing() -> void:
	game_state = State.PLAYING
	game_state_changed.emit(game_state)

@rpc("authority", "call_remote", "reliable")
func client_player_died(victim_id: int) -> void:
	if player_roles.has(victim_id):
		player_roles[victim_id].alive = false
	player_died.emit(victim_id)

@rpc("authority", "call_remote", "reliable")
func client_set_kill_cooldown(cooldown: float) -> void:
	kill_cooldown_remaining = cooldown
	kill_cooldown_changed.emit(cooldown)
	# 自动倒数
	var tween := create_tween()
	tween.tween_property(self, "kill_cooldown_remaining", 0.0, cooldown)
	tween.tween_callback(func() -> void: kill_cooldown_changed.emit(0.0))

@rpc("authority", "call_remote", "reliable")
func client_meeting_started(caller_id: int) -> void:
	game_state = State.MEETING
	game_state_changed.emit(game_state)
	meeting_started.emit(caller_id)

@rpc("authority", "call_remote", "reliable")
func client_vote_started() -> void:
	game_state = State.VOTING
	game_state_changed.emit(game_state)
	vote_started.emit()

@rpc("authority", "call_remote", "reliable")
func client_vote_ended(outed_id: int) -> void:
	game_state = State.RESULT
	game_state_changed.emit(game_state)
	vote_ended.emit(outed_id)
	# 显示 RESULT UI 由 UI 自己监听

@rpc("authority", "call_remote", "reliable")
func client_task_progress(completed: int) -> void:
	tasks_completed = completed
	task_progress_changed.emit(completed, TASK_TOTAL)

@rpc("authority", "call_remote", "reliable")
func client_game_over(winner: int, reason: String) -> void:
	game_state = State.RESULT
	game_state_changed.emit(game_state)
	game_over.emit(winner, reason)
