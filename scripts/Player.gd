extends CharacterBody2D

## Isometric Player Controller — smooth 8-way movement + touch support

@export var speed: float = 200.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var friction: float = 15.0

var _direction := Vector2.ZERO
var _touch_direction := Vector2.ZERO
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _facing := Vector2.DOWN

func _physics_process(delta: float) -> void:
	if _dash_cooldown_timer > 0:
		_dash_cooldown_timer -= delta
	if _dash_timer > 0:
		_dash_timer -= delta
		velocity = velocity.normalized() * dash_speed
		move_and_slide()
		return

	# Keyboard input
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	
	# Use touch direction if active, otherwise keyboard
	var move_input = _touch_direction if _touch_direction != Vector2.ZERO else input
	
	if move_input != Vector2.ZERO:
		_direction = Vector2(
			move_input.x - move_input.y,
			(move_input.x + move_input.y) * 0.5
		).normalized()
		_facing = move_input
		velocity = velocity.move_toward(_direction * speed, speed * friction * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * friction * delta)
		_direction = Vector2.ZERO

	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0 and _direction != Vector2.ZERO:
		velocity = _direction.normalized() * dash_speed
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown

	move_and_slide()

func set_touch_direction(dir: Vector2) -> void:
	_touch_direction = dir

func trigger_dash() -> void:
	if _dash_cooldown_timer <= 0 and _direction != Vector2.ZERO:
		velocity = _direction.normalized() * dash_speed
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown

func get_facing_direction() -> Vector2:
	return _facing
