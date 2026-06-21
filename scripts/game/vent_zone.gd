extends Area2D

# VentZone - 通风管交互区域（玩家进入后可以按 V 钻入）

@export var vent_id: String = "medbay"

@onready var label: Label = $Label

func _ready() -> void:
	label.text = "🕳 " + VentSystem.get_vent_name_zh(vent_id)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_multiplayer_authority():
		body._on_vent_zone_entered(vent_id)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_multiplayer_authority():
		body._on_vent_zone_exited(vent_id)
