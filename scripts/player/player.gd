extends CharacterBody2D

# 玩家移动脚本 - Phase 1 单人 Demo
# WASD 或方向键控制移动

@export var speed: float = 300.0

func _physics_process(_delta: float) -> void:
	var input_dir := Vector2.ZERO

	# 读取四个方向的输入
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1

	# 标准化后乘速度，避免斜向移动比直线更快
	velocity = input_dir.normalized() * speed

	# CharacterBody2D 自带的移动方法，会自动处理碰撞反弹
	move_and_slide()
