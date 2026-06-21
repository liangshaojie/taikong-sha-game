extends Node2D

# Main - 游戏主场景脚本
# 启动时根据命令行参数决定 host 还是 client
# 负责玩家对象的动态生成（通过 MultiplayerSpawner）

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var status_label: Label = $UI/StatusLabel

# 玩家出生点配置（peer_id → 位置）
const SPAWN_POSITIONS := {
	1: Vector2(330, 360),   # Host → CAFETERIA
	2: Vector2(950, 360),   # Client → REACTOR
}

func _ready() -> void:
	# 1. 配置 spawner 的自定义生成函数
	player_spawner.spawn_function = _spawn_player

	# 2. 监听 lobby 信号
	Lobby.hosted.connect(_on_hosted)
	Lobby.joined.connect(_on_joined)
	Lobby.peer_joined.connect(_on_peer_joined)
	Lobby.peer_left.connect(_on_peer_left)
	Lobby.connection_failed.connect(_on_connection_failed)
	Lobby.server_disconnected.connect(_on_server_disconnected)

	# 3. 根据命令行参数决定模式
	var args := OS.get_cmdline_user_args()
	if "--client" in args:
		_start_as_client()
	else:
		_start_as_host()

# === 启动模式 ===

func _start_as_host() -> void:
	var err := Lobby.host_game()
	if err != OK:
		_show_status("❌ Host failed: %s" % error_string(err))
		return
	# 等 hosted 信号触发后再生成本机玩家

func _start_as_client() -> void:
	var err := Lobby.join_game()
	if err != OK:
		_show_status("❌ Join failed: %s" % error_string(err))
		return
	_show_status("🔄 Connecting to %s:%d..." % [Lobby.DEFAULT_SERVER_IP, Lobby.PORT])

# === Lobby 回调 ===

func _on_hosted() -> void:
	_show_status("🟢 Hosted on port %d. Run another instance with --client to join." % Lobby.PORT)
	_spawn_player_for(Lobby.get_my_id())

func _on_joined() -> void:
	_show_status("✅ Connected as Peer %d. Waiting for spawn..." % Lobby.get_my_id())

func _on_peer_joined(peer_id: int) -> void:
	if Lobby.is_host():
		_spawn_player_for(peer_id)
		_show_status("👤 Player %d joined" % peer_id)

func _on_peer_left(peer_id: int) -> void:
	_show_status("🚪 Player %d left" % peer_id)

func _on_connection_failed() -> void:
	_show_status("❌ Connection failed. Check that host is running on %s:%d" % [Lobby.DEFAULT_SERVER_IP, Lobby.PORT])

func _on_server_disconnected() -> void:
	_show_status("🚨 Server disconnected")

# === Spawner 自定义函数 ===
# 在 host 端调用 player_spawner.spawn(data) 时，会自动在所有 peer 上执行本函数

func _spawn_player(data: Variant) -> Node:
	var peer_id: int = int(data.get("peer_id", 0))
	var spawn_pos: Vector2 = data.get("spawn_pos", Vector2.ZERO)

	var player: Node = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)  # 唯一名（peer_id 即 multiplayer id）
	player.position = spawn_pos
	return player

# === 工具 ===

func _spawn_player_for(peer_id: int) -> void:
	if not Lobby.is_host():
		return
	var spawn_pos: Vector2 = SPAWN_POSITIONS.get(peer_id, Vector2(640, 360))
	player_spawner.spawn({"peer_id": peer_id, "spawn_pos": spawn_pos})

func _show_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
	print("[Main] %s" % msg)
