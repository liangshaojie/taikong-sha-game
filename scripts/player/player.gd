extends CharacterBody2D

# Player - 玩家移动脚本（联网版）
# authority 由 spawner 在 main.gd 的 _spawn_player 里设置（节点加入树之前）
# 这里**不要**在 _ready 里改 authority，否则 MultiplayerSynchronizer 会失去 network ID

@export var speed: float = 300.0

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
