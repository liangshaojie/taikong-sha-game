extends Control

# Meeting - 会议投票面板（嵌在 main.tscn 里）

@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var status_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var vote_buttons_container: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/VoteButtons
@onready var result_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/ResultLabel

var _voted: bool = false

func _ready() -> void:
	GameManager.meeting_started.connect(_on_meeting_started)
	GameManager.vote_started.connect(_on_vote_started)
	GameManager.vote_ended.connect(_on_vote_ended)
	result_label.visible = false
	visible = false

func _on_meeting_started(_caller_id: int) -> void:
	_reset_ui()
	title_label.text = "🗣️ 紧急会议"
	status_label.text = "讨论中... (简化版：直接进入投票)"

func _on_vote_started() -> void:
	_reset_ui()
	title_label.text = "🗳️ 投票"
	# 死人也能投票（鬼魂也算），活人不能投自己
	var my_id := Lobby.get_my_id()
	for pid in Lobby.players:
		if pid == my_id and GameManager.is_alive(pid):
			continue
		if not GameManager.is_alive(pid):
			continue
		var info: Dictionary = Lobby.players[pid]
		var btn := Button.new()
		btn.text = "  投 %s (Peer %d)" % [info.name, pid]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_vote_button_pressed.bind(pid))
		vote_buttons_container.add_child(btn)

	var skip_btn := Button.new()
	skip_btn.text = "  ⏭️ 跳过投票"
	skip_btn.custom_minimum_size = Vector2(0, 50)
	skip_btn.add_theme_font_size_override("font_size", 20)
	skip_btn.pressed.connect(_on_vote_button_pressed.bind(-1))
	vote_buttons_container.add_child(skip_btn)

func _on_vote_button_pressed(target_id: int) -> void:
	if _voted:
		return
	_voted = true
	status_label.text = "✅ 已投 %s，等待其他人..." % (
		"跳过" if target_id == -1
		else Lobby.players[target_id].name
	)
	GameManager.request_vote(target_id)
	for child in vote_buttons_container.get_children():
		(child as Button).disabled = true

func _on_vote_ended(outed_id: int) -> void:
	if outed_id == -1:
		result_label.text = "🎲 平票或无人投票，无人被淘汰"
	else:
		var info: Dictionary = Lobby.players.get(outed_id, {"name": "Unknown"})
		result_label.text = "💀 %s (Peer %d) 被投出！" % [info.name, outed_id]
	result_label.visible = true
	status_label.text = "3 秒后自动返回..."
	# 不要切换场景！main.gd 会监听 game_state_changed 决定显示哪个面板

func _reset_ui() -> void:
	_voted = false
	result_label.visible = false
	status_label.text = ""
	for child in vote_buttons_container.get_children():
		child.queue_free()
