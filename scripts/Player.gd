extends CharacterBody2D

## Isometric Player Controller — smooth 8-way movement

@export var speed: float = 200.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var friction: float = 15.0

var _direction := Vector2.ZERO
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _facing := Vector2.DOWN  # isometric default

func _physics_process(delta: float) -> void:
	# Cooldowns
	if _dash_cooldown_timer > 0:
		_dash_cooldown_timer -= delta
	if _dash_timer > 0:
		_dash_timer -= delta
		velocity = velocity.normalized() * dash_speed
		move_and_slide()
		return

	# Input → isometric direction
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	
	# Convert to isometric movement (diamond grid feel)
	if input != Vector2.ZERO:
		# Isometric transform: rotate 45° and squash Y
		_direction = Vector2(
			input.x - input.y,
			(input.x + input.y) * 0.5
		).normalized()
		_facing = input
		velocity = velocity.move_toward(_direction * speed, speed * friction * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * friction * delta)
		_direction = Vector2.ZERO

	# Dash
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0 and _direction != Vector2.ZERO:
		velocity = _direction.normalized() * dash_speed
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown

	move_and_slide()

func get_facing_direction() -> Vector2:
	return _facing
