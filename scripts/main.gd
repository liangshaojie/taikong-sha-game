extends Node2D

# Main - 游戏主场景脚本
# 包含：地图、玩家生成、UI（HUD + 会议 + 结算面板）

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const TASK_ZONE_SCENE: PackedScene = preload("res://scenes/game/task_zone.tscn")

@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var status_label: Label = $UI/GameHUD/HintLabel
@onready var task_label: Label = $UI/GameHUD/TaskLabel
@onready var role_label: Label = $UI/GameHUD/RoleLabel
@onready var meeting_panel: Control = $UI/MeetingPanel
@onready var result_panel: Control = $UI/ResultPanel

const SPAWN_POSITIONS := {
	1: Vector2(330, 360),
	2: Vector2(950, 360),
	3: Vector2(640, 540),
}

var _spawn_counter: int = 0

func _grid_spawn_pos(idx: int) -> Vector2:
	var col: int = (idx - 1) % 4
	var row: int = (idx - 1) / 4
	return Vector2(160 + col * 320, 150 + row * 140)

func _ready() -> void:
	player_spawner.spawn_function = _spawn_player

	Lobby.hosted.connect(_on_hosted)
	Lobby.peer_joined.connect(_on_peer_joined)
	Lobby.peer_left.connect(_on_peer_left)
	Lobby.connection_failed.connect(_on_connection_failed)
	Lobby.server_disconnected.connect(_on_server_disconnected)

	# GameManager 信号
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.role_assigned.connect(_on_role_assigned)
	GameManager.task_progress_changed.connect(_on_task_progress_changed)
	GameManager.kill_cooldown_changed.connect(_on_kill_cooldown_changed)
	GameManager.player_died.connect(_on_player_died)
	GameManager.game_over.connect(_on_game_over)

	# 默认隐藏会议和结算面板
	meeting_panel.visible = false
	result_panel.visible = false

	if Lobby.is_in_game():
		_on_entered_game()
	else:
		_show_status("❌ Not in a network session. Return to menu.")

func _spawn_player(data: Variant) -> Node:
	var peer_id: int = int(data.get("peer_id", 0))
	var spawn_pos: Vector2 = data.get("spawn_pos", Vector2.ZERO)
	var color: Color = data.get("color", Color.WHITE)

	var player: Node = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = spawn_pos

	if peer_id > 0:
		player.set_multiplayer_authority(peer_id)

	var sprite: Polygon2D = player.get_node("Sprite2D")
	sprite.color = color
	return player

func _on_entered_game() -> void:
	# 添加任务区
	_spawn_task_zones()

	if Lobby.is_host():
		for info in Lobby.get_player_list():
			_spawn_player_for_info(info)
		_show_status("🟢 Host. 等待 GameManager 分配角色...")
		# 触发角色分配
		GameManager.start_game_session()
	else:
		_show_status("✅ Joined. Waiting...")

func _spawn_player_for_info(info: Dictionary) -> void:
	if not Lobby.is_host():
		return
	var peer_id: int = info.peer_id
	_spawn_counter += 1
	var spawn_pos: Vector2 = SPAWN_POSITIONS.get(_spawn_counter, _grid_spawn_pos(_spawn_counter))
	var color: Color = Lobby.get_color_by_index(_spawn_counter - 1)
	print("[Main] Spawn peer %d (slot %d) at %s color=%s" % [peer_id, _spawn_counter, spawn_pos, color])
	player_spawner.spawn({
		"peer_id": peer_id,
		"spawn_pos": spawn_pos,
		"color": color,
	})

func _spawn_task_zones() -> void:
	if not Lobby.is_host():
		return
	var task_positions := [
		{"id": "upload_1", "pos": Vector2(330, 200)},
		{"id": "fix_wires", "pos": Vector2(950, 200)},
		{"id": "calibrate", "pos": Vector2(640, 660)},
	]
	for info in task_positions:
		var zone: Node = TASK_ZONE_SCENE.instantiate()
		zone.name = "Task_" + info.id
		zone.position = info.pos
		zone.task_id = info.id
		zone.get_node("Label").text = "📋 " + info.id
		$Tasks.add_child(zone)
		print("[Main] Task zone '%s' at %s" % [info.id, info.pos])

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.MEETING:
			meeting_panel.visible = true
			result_panel.visible = false
		GameManager.State.PLAYING:
			meeting_panel.visible = false
		GameManager.State.RESULT:
			result_panel.visible = true
			meeting_panel.visible = false
		_:
			pass

func _on_role_assigned(role: int) -> void:
	role_label.text = "身份：%s" % Role.name_zh(role)
	if role == Role.Kind.IMPOSTOR:
		role_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		status_label.text = "🔪 按 K 击杀船员   |   按 R 开会"
	else:
		role_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
		status_label.text = "🛠️ 走到任务点按住 E   |   按 R 开会"

func _on_task_progress_changed(completed: int, total: int) -> void:
	task_label.text = "任务：%d / %d" % [completed, total]

func _on_kill_cooldown_changed(remaining: float) -> void:
	if GameManager.am_i_impostor():
		if remaining > 0:
			status_label.text = "🔪 击杀冷却中... %.0fs   |   按 R 开会" % remaining
		else:
			status_label.text = "🔪 按 K 击杀船员   |   按 R 开会"

func _on_player_died(_dead_id: int) -> void:
	pass

func _on_game_over(_winner: int, _reason: String) -> void:
	# result.gd 监听 game_over 信号自己处理
	pass

# === Lobby 回调（保持兼容） ===

func _on_hosted() -> void:
	pass

func _on_peer_joined(peer_id: int, info: Dictionary) -> void:
	if Lobby.is_host():
		_spawn_player_for_info(info)

func _on_peer_left(peer_id: int) -> void:
	pass

func _on_connection_failed() -> void:
	_show_status("❌ Connection failed")
	_back_to_menu()

func _on_server_disconnected() -> void:
	_show_status("🚨 Server disconnected")
	_back_to_menu()

func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/main_menu.tscn")

func _show_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
	print("[Main] %s" % msg)
