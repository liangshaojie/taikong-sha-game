extends CharacterBody2D

# Player - 玩家移动脚本（联网版）
# 只在 owner 端处理输入；其他端只接收位置同步

@export var speed: float = 300.0

func _ready() -> void:
	# Spawner 把玩家名设为 peer_id 字符串，据此设置 authority
	# 这样每个玩家只在自己的客户端响应输入
	set_multiplayer_authority(int(name))

func _physics_process(_delta: float) -> void:
	# 非 authority 端不做输入处理（位置由 MultiplayerSynchronizer 自动同步）
	if not is_multiplayer_authority():
		return

	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1

	velocity = input_dir.normalized() * speed
	move_and_slide()
