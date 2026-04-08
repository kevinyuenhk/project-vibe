extends CharacterBody2D

@export var speed: float = 110.0
@export var max_hp: int = 40
@export var touch_damage: int = 8
@export var attack_interval: float = 0.85
@export var chase_range: float = 500.0
@export var stop_distance: float = 22.0

var _target: Node2D
var _hp: int = 0
var _attack_timer: float = 0.0
var _hitstun_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO

signal died(enemy: CharacterBody2D)
signal hit_player(damage: int, from_position: Vector2)

func _ready() -> void:
	_hp = max_hp

func setup(target: Node2D) -> void:
	_target = target

func _physics_process(delta: float) -> void:
	if _attack_timer > 0:
		_attack_timer -= delta
	if _hitstun_timer > 0:
		_hitstun_timer -= delta
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return

	if not is_instance_valid(_target):
		velocity = velocity.move_toward(Vector2.ZERO, speed * 8.0 * delta)
		move_and_slide()
		return

	var delta_vec := _target.global_position - global_position
	var distance := delta_vec.length()
	if distance > chase_range:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 6.0 * delta)
		move_and_slide()
		return

	var dir := delta_vec.normalized()
	if distance > stop_distance:
		velocity = velocity.move_toward(dir * speed, speed * 8.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 10.0 * delta)
		if _attack_timer <= 0:
			_attack_timer = attack_interval
			hit_player.emit(touch_damage, global_position)

	move_and_slide()

func take_hit(damage: int, knockback: float, hit_direction: Vector2) -> void:
	_hp -= damage
	_hitstun_timer = 0.11
	_knockback_velocity = hit_direction.normalized() * knockback
	modulate = Color(1.0, 0.55, 0.55, 1.0)
	var flash_timer := get_tree().create_timer(0.08)
	flash_timer.timeout.connect(func():
		modulate = Color(1, 1, 1, 1)
	)
	if _hp <= 0:
		died.emit(self)
		queue_free()
