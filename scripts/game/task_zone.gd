extends Area2D

# TaskZone - 任务交互点
# 玩家进入区域 + 按住 E → 进度条填满 → 完成任务

@export var task_id: String = "task_default"

@onready var label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_multiplayer_authority():
		body._on_task_zone_entered(self)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_multiplayer_authority():
		body._on_task_zone_exited(self)

func complete() -> void:
	print("[TaskZone] %s completed" % task_id)
	GameManager.report_task_done(task_id)
	# 视觉反馈
	label.text = "✓ %s" % task_id
	label.add_theme_color_override("font_color", Color.GREEN)
