extends Node2D

# Main - 游戏主场景脚本
# 进入时假设已在网络会话中（从大厅进来）
# Host 负责通过 MultiplayerSpawner 同步生成所有玩家

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var status_label: Label = $UI/StatusLabel

const SPAWN_POSITIONS := {
	1: Vector2(330, 360),    # Host → CAFETERIA
	2: Vector2(950, 360),    # First client → REACTOR
	3: Vector2(640, 540),
	4: Vector2(440, 540),
	5: Vector2(840, 540),
}

func _ready() -> void:
	player_spawner.spawn_function = _spawn_player

	Lobby.hosted.connect(_on_hosted)
	Lobby.peer_joined.connect(_on_peer_joined)
	Lobby.peer_left.connect(_on_peer_left)
	Lobby.connection_failed.connect(_on_connection_failed)
	Lobby.server_disconnected.connect(_on_server_disconnected)

	# 进入游戏时已经在 lobby session 里，host 立即生成所有已知玩家
	if Lobby.is_in_game():
		_on_entered_game()
	else:
		_show_status("❌ Not in a network session. Return to menu.")

# === Spawner 自定义函数 ===
# 在 host 端调用 player_spawner.spawn(data) 时，自动在所有 peer 上执行本函数

func _spawn_player(data: Variant) -> Node:
	var peer_id: int = int(data.get("peer_id", 0))
	var spawn_pos: Vector2 = data.get("spawn_pos", Vector2.ZERO)
	var color: Color = data.get("color", Color.WHITE)

	var player: Node = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = spawn_pos

	# 关键：必须在节点加入树之前设置 authority
	# 否则 MultiplayerSynchronizer 会丢失 network ID，同步失败
	if peer_id > 0:
		player.set_multiplayer_authority(peer_id)

	# 替换 Sprite2D 颜色（每人不同颜色便于区分）
	var sprite: Polygon2D = player.get_node("Sprite2D")
	sprite.color = color

	return player

# === 触发 spawn 的入口 ===

func _on_entered_game() -> void:
	if Lobby.is_host():
		# Host 生成所有已连接玩家（包括自己）
		for info in Lobby.get_player_list():
			_spawn_player_for_info(info)
		_show_status("🟢 Hosting. %d player(s)" % Lobby.players.size())
	else:
		_show_status("✅ Joined. Waiting for spawn from server...")

func _on_peer_joined(peer_id: int, info: Dictionary) -> void:
	if Lobby.is_host():
		_spawn_player_for_info(info)

func _spawn_player_for_info(info: Dictionary) -> void:
	if not Lobby.is_host():
		return
	var peer_id: int = info.peer_id
	var spawn_pos: Vector2 = SPAWN_POSITIONS.get(peer_id, Vector2(640, 360 + peer_id * 40))
	var color: Color = info.get("color", Color.WHITE)
	player_spawner.spawn({
		"peer_id": peer_id,
		"spawn_pos": spawn_pos,
		"color": color,
	})

# === Lobby 回调 ===

func _on_hosted() -> void:
	pass  # Already in game when hosted fires (used in lobby scene)

func _on_peer_left(peer_id: int) -> void:
	_show_status("🚪 Player %d left" % peer_id)

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
