extends Node

# Lobby - 网络管理器（Autoload，全局单例）
# 提供房间创建/加入/离开功能，并把网络事件翻译为业务信号

signal hosted                                # 本机成功创建了房间（作为 host）
signal joined                                # 本机成功加入了房间（作为 client）
signal peer_joined(peer_id: int)            # 有新玩家加入（host 侧触发）
signal peer_left(peer_id: int)              # 有玩家断开
signal connection_failed                     # 加入失败
signal server_disconnected                  # 与服务器断开（client 侧触发）

const PORT := 7777
const DEFAULT_SERVER_IP := "127.0.0.1"
const MAX_CONNECTIONS := 10

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# === Public API ===

func host_game() -> Error:
	"""创建房间（作为 host/服务端）。"""
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_CONNECTIONS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	hosted.emit()
	return OK

func join_game(address: String = DEFAULT_SERVER_IP) -> Error:
	"""加入房间（作为 client）。"""
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	return OK

func leave_game() -> void:
	"""离开当前房间。"""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

func is_in_game() -> bool:
	return multiplayer.multiplayer_peer != null

func get_my_id() -> int:
	if multiplayer.multiplayer_peer:
		return multiplayer.get_unique_id()
	return 0

# === Internal callbacks ===

func _on_peer_connected(peer_id: int) -> void:
	# 仅 host 端会收到这个信号
	print("[Lobby] Peer %d joined" % peer_id)
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[Lobby] Peer %d left" % peer_id)
	peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
	print("[Lobby] Connected to server as Peer %d" % multiplayer.get_unique_id())
	joined.emit()

func _on_connection_failed() -> void:
	print("[Lobby] Connection failed")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[Lobby] Server disconnected")
	leave_game()
	server_disconnected.emit()
