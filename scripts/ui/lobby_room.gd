extends Control

# LobbyRoom - 大厅等待界面
# 显示房间信息、玩家列表（带颜色）、开始/离开按钮

@onready var room_info_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/RoomInfoLabel
@onready var role_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/RoleLabel
@onready var player_list: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/PlayerList
@onready var start_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonRow/StartButton
@onready var leave_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonRow/LeaveButton
@onready var status_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel

# 动态创建的玩家条目（peer_id → Control）
var _player_entries: Dictionary = {}

func _ready() -> void:
	start_button.visible = Lobby.is_host()
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	Lobby.peer_joined.connect(_on_peer_joined)
	Lobby.peer_left.connect(_on_peer_left)
	Lobby.server_disconnected.connect(_on_server_disconnected)
	Lobby.connection_failed.connect(_on_connection_failed)

	_update_room_info()
	# 把已有玩家也渲染一遍（包括自己）
	for info in Lobby.get_player_list():
		_add_player_entry(info)

	# 默认提示
	if Lobby.is_host():
		status_label.text = "等待玩家加入... (至少 1 人即可开始)"
	else:
		status_label.text = "等待 Host 开始游戏..."

# === 玩家条目管理 ===

func _add_player_entry(info: Dictionary) -> void:
	var peer_id: int = info.peer_id
	if _player_entries.has(peer_id):
		return

	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 36)
	hbox.add_theme_constant_override("separation", 12)

	# 颜色色块
	var swatch := ColorRect.new()
	swatch.color = info.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(28, 28)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(swatch)

	# 名字标签
	var label := Label.new()
	var prefix := "👑 " if peer_id == 1 else "   "
	var is_you := peer_id == Lobby.get_my_id()
	var suffix := " (你)" if is_you else ""
	label.text = "%s%s (Peer %d)%s" % [prefix, info.name, peer_id, suffix]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(label)

	player_list.add_child(hbox)
	_player_entries[peer_id] = hbox

func _remove_player_entry(peer_id: int) -> void:
	if _player_entries.has(peer_id):
		var entry: Control = _player_entries[peer_id]
		entry.queue_free()
		_player_entries.erase(peer_id)

# === 按钮回调 ===

func _on_start_pressed() -> void:
	if Lobby.players.size() < 1:
		_show_status("没有玩家")
		return
	start_button.disabled = true
	_show_status("🎮 正在加载游戏...")
	Lobby.start_game("res://scenes/main.tscn")

func _on_leave_pressed() -> void:
	Lobby.leave_game()
	_back_to_menu()

func _on_peer_joined(peer_id: int, info: Dictionary) -> void:
	_add_player_entry(info)
	_show_status("玩家 %s 加入了 (共 %d 人)" % [info.name, Lobby.players.size()])

func _on_peer_left(peer_id: int) -> void:
	_remove_player_entry(peer_id)
	_show_status("玩家离开了 (剩 %d 人)" % Lobby.players.size())

func _on_server_disconnected() -> void:
	_show_status("🚨 服务器断开，正在返回主菜单...")
	_back_to_menu()

func _on_connection_failed() -> void:
	_show_status("❌ 连接失败")
	_back_to_menu()

# === Helpers ===

func _update_room_info() -> void:
	var my_id := Lobby.get_my_id()
	var role := "Host" if Lobby.is_host() else "Client"
	room_info_label.text = "房间：127.0.0.1:%d" % Lobby.PORT
	role_label.text = "你是 %s (Peer %d)" % [role, my_id]

func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/main_menu.tscn")

func _show_status(msg: String) -> void:
	status_label.text = msg
	print("[LobbyRoom] %s" % msg)
