extends CharacterBody3D

@export var move_speed: float = 4.2
@export var max_hp: int = 42
@export var touch_damage: int = 8
@export var attack_interval: float = 0.9
@export var stop_range: float = 1.25
@export var aggro_range: float = 10.0
@export var chase_drop_range: float = 16.0
@export var return_stop_range: float = 0.6

var _hp: int = 0
var _target: Node3D
var _attack_timer: float = 0.0
var _stun_timer: float = 0.0
var _knockback := Vector3.ZERO
var _anim_tween: Tween
var _spawn_position := Vector3.ZERO
var _is_aggro: bool = false

@onready var body_mesh: MeshInstance3D = $Body

signal died(enemy: Node3D)
signal hit_player(damage: int, from_position: Vector3)

func _ready() -> void:
	_hp = max_hp
	add_to_group("enemy")
	_spawn_position = global_position

func setup(target: Node3D) -> void:
	_target = target
	_spawn_position = global_position

func _physics_process(delta: float) -> void:
	if _attack_timer > 0:
		_attack_timer -= delta

	if _stun_timer > 0:
		_stun_timer -= delta
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector3.ZERO, 26.0 * delta)
		move_and_slide()
		return

	if not is_instance_valid(_target):
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0
	var distance := to_target.length()
	var dir := to_target.normalized() if distance > 0.001 else Vector3.ZERO

	if not _is_aggro and distance <= aggro_range:
		_is_aggro = true
	elif _is_aggro and distance >= chase_drop_range:
		_is_aggro = false

	if _is_aggro:
		if distance > stop_range:
			velocity = dir * move_speed
		else:
			velocity = Vector3.ZERO
			if _attack_timer <= 0:
				_attack_timer = attack_interval
				_play_attack_anim()
				hit_player.emit(touch_damage, global_position)
	else:
		var to_home := _spawn_position - global_position
		to_home.y = 0
		var home_distance := to_home.length()
		if home_distance > return_stop_range:
			velocity = to_home.normalized() * (move_speed * 0.8)
		else:
			velocity = Vector3.ZERO

	if velocity.length_squared() > 0.001:
		var look_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
		body_mesh.look_at(global_position + look_dir, Vector3.UP)
	elif dir != Vector3.ZERO and _is_aggro:
		body_mesh.look_at(global_position + dir, Vector3.UP)

	move_and_slide()

func take_hit(damage: int, knockback: float, direction: Vector3) -> void:
	_hp -= damage
	_stun_timer = 0.11
	_knockback = direction.normalized() * knockback
	_play_hit_anim()
	if _hp <= 0:
		died.emit(self)
		queue_free()

func _play_attack_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	body_mesh.scale = Vector3.ONE
	_anim_tween = create_tween()
	_anim_tween.tween_property(body_mesh, "scale", Vector3(1.18, 0.85, 1.18), 0.06)
	_anim_tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.12)

func _play_hit_anim() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	body_mesh.scale = Vector3.ONE
	_anim_tween = create_tween()
	_anim_tween.tween_property(body_mesh, "scale", Vector3(0.82, 1.18, 0.82), 0.05)
	_anim_tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.12)
