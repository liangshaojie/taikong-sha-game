extends CharacterBody2D

# Player - 玩家脚本（角色 + 输入 + 死亡）
# authority 由 spawner 在 main.gd 的 _spawn_player 里设置（节点加入树之前）

@export var speed: float = 300.0

# 任务交互状态（本地，不同步）
var _in_task_zone: Node = null
var _task_progress: float = 0.0
var _in_vent_zone: String = ""

@onready var sprite: Polygon2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	GameManager.role_assigned.connect(_on_role_assigned)
	GameManager.player_died.connect(_on_player_died)
	GameManager.game_state_changed.connect(_on_game_state_changed)

func _physics_process(delta: float) -> void:
	# 死亡 / 鬼魂：不能移动，但仍能开会和投票
	if GameManager.am_i_ghost():
		velocity = Vector2.ZERO
		return
	# 非 authority 端不做输入处理（位置由 MultiplayerSynchronizer 自动同步）
	if not is_multiplayer_authority():
		return

	# 游戏中才处理输入
	if GameManager.game_state == GameManager.State.PLAYING:
		_process_gameplay_input(delta)

func _process_gameplay_input(delta: float) -> void:
	# 移动
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	velocity = input_dir.normalized() * speed
	move_and_slide()

	# 任务交互（按住 E）
	if Input.is_action_pressed("interact") and _in_task_zone and GameManager.am_i_crewmate():
		_task_progress += delta
		if _task_progress >= GameManager.TASK_DURATION:
			_task_progress = 0.0
			if _in_task_zone.has_method("complete"):
				_in_task_zone.complete()
	else:
		_task_progress = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if not GameManager.am_i_alive():
		return
	if GameManager.game_state != GameManager.State.PLAYING:
		return
	if event.is_action_pressed("kill"):
		_try_kill()
	elif event.is_action_pressed("meeting"):
		GameManager.request_meeting()
	elif event.is_action_pressed("vent"):
		_try_use_vent()

func _try_use_vent() -> void:
	if not GameManager.am_i_impostor():
		return
	if GameManager.vent_cooldown_remaining > 0.0:
		print("[Player] Vent on cooldown: %.1fs" % GameManager.vent_cooldown_remaining)
		return
	var current_vent := VentSystem.get_vent_at_position(global_position)
	if current_vent.is_empty():
		print("[Player] Not on a vent")
		return
	print("[Player] Opening vent panel at '%s'" % current_vent)
	GameManager.show_vent_panel(current_vent)

func _try_kill() -> void:
	if not GameManager.am_i_impostor():
		return
	if GameManager.kill_cooldown_remaining > 0.0:
		print("[Player] Kill on cooldown: %.1fs" % GameManager.kill_cooldown_remaining)
		return
	# 找最近的活着的船员
	var target_id := _find_nearest_alive_crewmate()
	if target_id == -1:
		print("[Player] No valid target nearby")
		return
	print("[Player] Killing peer %d" % target_id)
	GameManager.request_kill(target_id)

func _find_nearest_alive_crewmate() -> int:
	var my_pos := global_position
	var best_id := -1
	var best_dist := GameManager.KILL_RANGE
	for pid in Lobby.players:
		if pid == Lobby.get_my_id():
			continue
		if not GameManager.is_alive(pid):
			continue
		if GameManager.get_player_role(pid) != Role.Kind.CREWMATE:
			continue
		var node := get_tree().root.get_node_or_null("Main/Players/" + str(pid))
		if not node or not (node is Node2D):
			continue
		var dist: float = my_pos.distance_to((node as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best_id = pid
	return best_id

# === 任务区域 ===

func _on_task_zone_entered(zone: Node) -> void:
	if is_multiplayer_authority():
		_in_task_zone = zone

func _on_task_zone_exited(zone: Node) -> void:
	if is_multiplayer_authority() and _in_task_zone == zone:
		_in_task_zone = null
		_task_progress = 0.0

# === 通风管区域 ===

func _on_vent_zone_entered(vent_id: String) -> void:
	if is_multiplayer_authority():
		_in_vent_zone = vent_id
		# 内鬼进入 vent 区域时自动弹出 UI（方便测试）
		# 实际游玩中也可以只让玩家按 V 才弹
		if GameManager.am_i_impostor() and not GameManager.am_i_ghost():
			if GameManager.game_state == GameManager.State.PLAYING:
				GameManager.show_vent_panel(vent_id)

func _on_vent_zone_exited(vent_id: String) -> void:
	if is_multiplayer_authority() and _in_vent_zone == vent_id:
		_in_vent_zone = ""
		GameManager.hide_vent_panel()

# === 信号回调 ===

func _on_role_assigned(_role: int) -> void:
	# 重新设置颜色
	if GameManager.am_i_ghost():
		sprite.color = Role.COLOR_BY_ROLE[Role.Kind.GHOST]
	elif GameManager.am_i_impostor():
		sprite.color = Role.COLOR_BY_ROLE[Role.Kind.IMPOSTOR]
	elif GameManager.am_i_crewmate():
		sprite.color = Role.COLOR_BY_ROLE[Role.Kind.CREWMATE]

func _on_player_died(dead_peer_id: int) -> void:
	if dead_peer_id == Lobby.get_my_id():
		# 我死了：变灰、停止处理移动输入
		sprite.color = Role.COLOR_BY_ROLE[Role.Kind.GHOST]
	elif int(name) == dead_peer_id:
		# 别的客户端看到这个 peer 死了
		sprite.color = Role.COLOR_BY_ROLE[Role.Kind.GHOST]

func _on_game_state_changed(_new_state: int) -> void:
	pass  # 由 UI 处理
