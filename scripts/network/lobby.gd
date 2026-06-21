extends Node

# Lobby - 网络管理器（Autoload，全局单例）
# 提供房间创建/加入/离开，并维护玩家列表（含名字和颜色）
# 服务端为单一权威，通过 RPC 广播玩家列表给所有客户端

signal hosted                                # 本机创建房间成功
signal joined                                # 本机加入房间成功
signal peer_joined(peer_id: int, info: Dictionary)   # 新玩家加入
signal peer_left(peer_id: int)                        # 玩家离开
signal connection_failed                              # 加入失败
signal server_disconnected                           # 与服务器断开
signal game_starting(path: String)                    # 服务端通知开始游戏

const PORT := 7777
const DEFAULT_SERVER_IP := "127.0.0.1"
const MAX_CONNECTIONS := 10

# 玩家颜色调色板
const PLAYER_COLORS: Array[Color] = [
	Color(0.40, 0.70, 1.00),   # 蓝色  - Host
	Color(1.00, 0.60, 0.40),   # 橙色
	Color(0.60, 0.80, 0.40),   # 绿色
	Color(1.00, 0.85, 0.40),   # 黄色
	Color(0.80, 0.60, 1.00),   # 紫色
	Color(1.00, 0.60, 0.80),   # 粉色
	Color(0.40, 0.85, 0.85),   # 青色
	Color(1.00, 0.40, 0.40),   # 红色
	Color(0.60, 1.00, 0.60),   # 柠檬
	Color(0.80, 0.65, 0.45),   # 棕色
]

# peer_id -> {peer_id, name, color}
var players: Dictionary = {}

# 本机玩家名（在 host_game / join_game 时设置）
var local_player_name: String = "Player"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# === Public API ===

func host_game(player_name: String) -> Error:
	"""创建房间（作为 host/服务端）。"""
	var name := _normalize_name(player_name, "Host")
	local_player_name = name
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_CONNECTIONS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	var my_id := multiplayer.get_unique_id()
	players[my_id] = _make_player_info(my_id, name)
	hosted.emit()
	# 让 UI 立即看到 host 自己
	peer_joined.emit(my_id, players[my_id])
	return OK

func join_game(address: String, player_name: String) -> Error:
	"""加入房间（作为 client）。"""
	var addr := address if not address.is_empty() else DEFAULT_SERVER_IP
	var name := _normalize_name(player_name, "Client")
	local_player_name = name
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(addr, PORT)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	return OK

func leave_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()

func start_game(game_scene_path: String) -> void:
	"""Host 调用，通知所有客户端加载游戏场景。"""
	if not multiplayer.is_server():
		return
	rpc("load_game_scene", game_scene_path)

func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

func is_in_game() -> bool:
	return multiplayer.multiplayer_peer != null

func get_my_id() -> int:
	if multiplayer.multiplayer_peer:
		return multiplayer.get_unique_id()
	return 0

func get_player_list() -> Array:
	# 按 peer_id 排序，方便 UI 稳定显示
	var list: Array = players.values()
	list.sort_custom(func(a, b): return int(a.peer_id) < int(b.peer_id))
	return list

func get_color_for_peer(peer_id: int) -> Color:
	# 警告：peer_id 在 Godot 4 里是随机大整数，不适合当数组下标
	# 仅用于调试/向后兼容；游戏内应该用 get_color_by_index
	return PLAYER_COLORS[(peer_id - 1) % PLAYER_COLORS.size()]

func get_color_by_index(index: int) -> Color:
	# 按 spawn 顺序（0, 1, 2...）取颜色，与 peer_id 解耦
	return PLAYER_COLORS[index % PLAYER_COLORS.size()]

# === RPCs ===

@rpc("authority", "call_local", "reliable")
func load_game_scene(path: String) -> void:
	print("[Lobby] Loading game scene: %s" % path)
	game_starting.emit(path)
	get_tree().change_scene_to_file(path)

@rpc("any_peer", "call_remote", "reliable")
func register_self(info: Dictionary) -> void:
	"""Client 调用，告诉服务端自己的名字。"""
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	info["peer_id"] = sender_id
	# 大厅 UI 显示的颜色仍然按 peer_id（仅用于 UI，不影响游戏内同步）
	info["color"] = get_color_for_peer(sender_id)
	var is_new := not players.has(sender_id)
	players[sender_id] = info
	print("[Lobby] Registered peer %d as '%s'" % [sender_id, info.name])
	# 服务端本地也要通知 UI（rpc 是 call_remote，不会本地执行 receive_player_list）
	if is_new:
		peer_joined.emit(sender_id, info)
	_broadcast_player_list()

@rpc("authority", "call_remote", "reliable")
func receive_player_list(snapshot: Dictionary) -> void:
	"""客户端接收服务端推送的玩家列表。"""
	var previous := players.keys()
	players = snapshot
	for prev_id in previous:
		if not snapshot.has(prev_id):
			peer_left.emit(prev_id)
	for peer_id in snapshot:
		if peer_id not in previous:
			peer_joined.emit(peer_id, snapshot[peer_id])
	# 第一次拿到列表 → 通知 UI 已加入
	if previous.is_empty() and not multiplayer.is_server():
		joined.emit()

# === Internal callbacks ===

func _on_peer_connected(peer_id: int) -> void:
	print("[Lobby] Peer %d connected (waiting for register_self)" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[Lobby] Peer %d left" % peer_id)
	var existed := players.has(peer_id)
	players.erase(peer_id)
	# 服务端本地也要通知 UI
	if existed:
		peer_left.emit(peer_id)
	_broadcast_player_list()

func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	print("[Lobby] Connected to server as Peer %d, sending register_self" % my_id)
	# 发送自己的信息给 server
	var info := _make_player_info(my_id, local_player_name)
	rpc_id(1, "register_self", info)

func _on_connection_failed() -> void:
	print("[Lobby] Connection failed")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[Lobby] Server disconnected")
	leave_game()
	server_disconnected.emit()

# === Helpers ===

func _normalize_name(name: String, fallback: String) -> String:
	var n := name.strip_edges()
	return n if not n.is_empty() else fallback

func _make_player_info(peer_id: int, name: String) -> Dictionary:
	return {
		"peer_id": peer_id,
		"name": name,
		"color": get_color_for_peer(peer_id),
	}

func _broadcast_player_list() -> void:
	if not multiplayer.is_server():
		return
	rpc("receive_player_list", players)
