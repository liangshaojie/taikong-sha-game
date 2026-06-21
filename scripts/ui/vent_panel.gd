extends Control

# VentPanel - 内鬼选择目的地的弹窗

@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var status_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var vent_buttons: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/VentButtons
@onready var close_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/CloseButton

var _current_vent: String = ""

func _ready() -> void:
	GameManager.vent_panel_toggle.connect(_on_vent_panel_toggle)
	GameManager.vent_cooldown_changed.connect(_on_cooldown_changed)
	close_button.pressed.connect(_on_close_pressed)
	visible = false

func _on_vent_panel_toggle(show: bool, current_vent: String) -> void:
	visible = show
	if show and not current_vent.is_empty():
		_populate(current_vent)

func _populate(current_vent: String) -> void:
	_current_vent = current_vent
	title_label.text = "🕳 " + VentSystem.get_vent_name_zh(current_vent)
	status_label.text = "选择要去的通风管："

	for child in vent_buttons.get_children():
		child.queue_free()

	for target_vent in VentSystem.get_connected_vents(current_vent):
		var btn := Button.new()
		btn.text = "→ " + VentSystem.get_vent_name_zh(target_vent)
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_vent_selected.bind(target_vent))
		vent_buttons.add_child(btn)

func _on_vent_selected(target_vent: String) -> void:
	GameManager.request_vent_use(target_vent)
	visible = false

func _on_cooldown_changed(remaining: float) -> void:
	if remaining > 0:
		status_label.text = "🕳 通风管冷却中... %.0fs" % remaining

func _on_close_pressed() -> void:
	visible = false
