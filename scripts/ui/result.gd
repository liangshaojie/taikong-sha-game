extends Control

# Result - 结算界面

@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var reason_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/ReasonLabel
@onready var role_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/RoleLabel
@onready var back_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	back_button.pressed.connect(_on_back_pressed)

func _on_game_over(winner_role: int, reason: String) -> void:
	if winner_role == Role.Kind.CREWMATE:
		title_label.text = "🎉 船员胜利！"
		title_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
	elif winner_role == Role.Kind.IMPOSTOR:
		title_label.text = "💀 内鬼胜利！"
		title_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		title_label.text = "游戏结束"
	reason_label.text = reason
	role_label.text = "你的身份：%s" % Role.name_zh(GameManager.my_role)

func _on_back_pressed() -> void:
	# 离开房间，回主菜单
	Lobby.leave_game()
	get_tree().change_scene_to_file("res://scenes/lobby/main_menu.tscn")
