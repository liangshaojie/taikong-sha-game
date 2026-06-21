extends Control

# MainMenu - 启动主菜单
# 输入玩家名字 → 选择创建房间或加入房间

@onready var name_input: LineEdit = $CenterContainer/Panel/MarginContainer/VBoxContainer/NameRow/NameInput
@onready var host_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonRow/HostButton
@onready var join_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonRow/JoinButton
@onready var join_panel: PanelContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/JoinPanel
@onready var ip_input: LineEdit = $CenterContainer/Panel/MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/IPRow/IPInput
@onready var connect_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/ButtonRow/ConnectButton
@onready var cancel_join_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/ButtonRow/CancelJoinButton
@onready var status_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	# 默认值
	name_input.text = "Player"
	ip_input.text = Lobby.DEFAULT_SERVER_IP
	join_panel.visible = false

	# 信号连接
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	cancel_join_button.pressed.connect(_on_cancel_join_pressed)
	name_input.text_submitted.connect(_on_name_submitted)

	Lobby.hosted.connect(_on_network_event)
	Lobby.joined.connect(_on_network_event)
	Lobby.connection_failed.connect(_on_connection_failed)
	Lobby.server_disconnected.connect(_on_server_disconnected)

func _on_name_submitted(_new_text: String) -> void:
	# 在名字输入框按 Enter → 相当于点创建房间
	_on_host_pressed()

func _on_host_pressed() -> void:
	var name := name_input.text.strip_edges()
	if name.is_empty():
		_show_status("请先输入玩家名字")
		name_input.grab_focus()
		return
	var err := Lobby.host_game(name)
	if err != OK:
		_show_status("❌ 创建失败：%s" % error_string(err))
		return
	_show_status("🔄 创建房间中...")

func _on_join_pressed() -> void:
	var name := name_input.text.strip_edges()
	if name.is_empty():
		_show_status("请先输入玩家名字")
		name_input.grab_focus()
		return
	join_panel.visible = true
	ip_input.grab_focus()
	ip_input.select_all()
	_show_status("输入服务器 IP 后按 Enter 或点击连接")

func _on_connect_pressed() -> void:
	var name := name_input.text.strip_edges()
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = Lobby.DEFAULT_SERVER_IP
	var err := Lobby.join_game(ip, name)
	if err != OK:
		_show_status("❌ 加入失败：%s" % error_string(err))
		return
	_show_status("🔄 正在连接 %s:%d..." % [ip, Lobby.PORT])

func _on_cancel_join_pressed() -> void:
	join_panel.visible = false
	_show_status("已取消")

func _on_network_event() -> void:
	# Host 或 Client 成功建立连接后跳到大厅
	get_tree().change_scene_to_file("res://scenes/lobby/lobby_room.tscn")

func _on_connection_failed() -> void:
	_show_status("❌ 连接失败，请检查 IP 和网络（host 是否已启动？）")

func _on_server_disconnected() -> void:
	_show_status("🚨 与服务器断开")

func _show_status(msg: String) -> void:
	status_label.text = msg
	print("[MainMenu] %s" % msg)
