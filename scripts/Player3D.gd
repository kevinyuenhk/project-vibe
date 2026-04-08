extends CharacterBody3D

@export var move_speed: float = 7.5
@export var dash_speed: float = 18.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.6
@export var attack_duration: float = 0.12
@export var attack_cooldown: float = 0.2
@export var max_hp: int = 120
@export var hurt_invuln: float = 0.35
@export var gravity: float = 28.0
@export var attack_reach: float = 2.2
@export var attack_arc_dot: float = 0.35

var _dash_timer: float = 0.0
var _dash_cd_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_cd_timer: float = 0.0
var _current_hp: int = 0
var _hurt_timer: float = 0.0
var _move_dir := Vector3.ZERO
var _camera: Camera3D
var _attack_hit_once: Dictionary = {}
var _attack_anim_tween: Tween

@onready var body_mesh: MeshInstance3D = $Body
@onready var attack_area: Area3D = $AttackArea
@onready var attack_shape: CollisionShape3D = $AttackArea/CollisionShape3D

signal attack_started()
signal attack_hit(target: Node3D, damage: int, knockback: float, direction: Vector3)
signal hp_changed(current: int, maximum: int)
signal died()

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_current_hp = max_hp
	attack_shape.disabled = true
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	hp_changed.emit(_current_hp, max_hp)

func _physics_process(delta: float) -> void:
	if _current_hp <= 0:
		velocity.y = 0.0
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	if _dash_cd_timer > 0:
		_dash_cd_timer -= delta
	if _attack_cd_timer > 0:
		_attack_cd_timer -= delta
	if _hurt_timer > 0:
		_hurt_timer -= delta

	if _dash_timer > 0:
		_dash_timer -= delta
		velocity.y = _get_vertical_velocity(delta)
		velocity.x = _move_dir.x * dash_speed
		velocity.z = _move_dir.z * dash_speed
		move_and_slide()
		return

	if _attack_timer > 0:
		_attack_timer -= delta
		_apply_attack_hits()
		if _attack_timer <= 0:
			attack_shape.disabled = true
			attack_area.monitoring = false
			_attack_hit_once.clear()

	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	_move_dir = _to_camera_relative(input)
	velocity.y = _get_vertical_velocity(delta)
	velocity.x = _move_dir.x * move_speed
	velocity.z = _move_dir.z * move_speed

	if _move_dir != Vector3.ZERO:
		body_mesh.look_at(global_position + _move_dir, Vector3.UP)

	if Input.is_action_just_pressed("dash") and _dash_cd_timer <= 0 and _move_dir != Vector3.ZERO:
		_dash_timer = dash_duration
		_dash_cd_timer = dash_cooldown

	if Input.is_action_just_pressed("attack"):
		trigger_attack()

	move_and_slide()

func trigger_attack() -> void:
	if _attack_cd_timer > 0:
		return

	var dir := _move_dir
	if dir == Vector3.ZERO:
		dir = -global_basis.z
	dir.y = 0
	dir = dir.normalized()

	var attack_point := dir * 1.35
	attack_area.position = Vector3(attack_point.x, 0.7, attack_point.z)
	attack_area.look_at(global_position + dir, Vector3.UP)
	attack_shape.disabled = false
	attack_area.monitoring = true
	_attack_hit_once.clear()
	_attack_timer = attack_duration
	_attack_cd_timer = attack_cooldown
	_play_attack_anim()
	_apply_attack_hits()
	_apply_attack_fallback(dir)
	attack_started.emit()

func take_damage(amount: int, from_direction: Vector3, knockback: float = 6.0) -> void:
	if _current_hp <= 0 or _hurt_timer > 0:
		return
	_current_hp = max(_current_hp - amount, 0)
	_hurt_timer = hurt_invuln
	velocity += from_direction.normalized() * knockback
	hp_changed.emit(_current_hp, max_hp)
	if _current_hp <= 0:
		died.emit()

func get_hp() -> int:
	return _current_hp

func reset_for_run(at_position: Vector3) -> void:
	global_position = at_position
	velocity = Vector3.ZERO
	_dash_timer = 0.0
	_dash_cd_timer = 0.0
	_attack_timer = 0.0
	_attack_cd_timer = 0.0
	_hurt_timer = 0.0
	_current_hp = max_hp
	attack_shape.disabled = true
	attack_area.monitoring = false
	_attack_hit_once.clear()
	hp_changed.emit(_current_hp, max_hp)

func set_camera_ref(cam: Camera3D) -> void:
	_camera = cam

func _to_camera_relative(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO

	if _camera == null:
		return Vector3(input.x, 0.0, input.y).normalized()

	var forward := -_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := _camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return (right * input.x + forward * -input.y).normalized()

func _on_attack_area_body_entered(body: Node3D) -> void:
	if _attack_timer <= 0 or body == self:
		return
	var body_id := body.get_instance_id()
	if _attack_hit_once.has(body_id):
		return
	_attack_hit_once[body_id] = true
	var dir := (body.global_position - global_position).normalized()
	attack_hit.emit(body, 16, 9.0, dir)

func _apply_attack_hits() -> void:
	for body in attack_area.get_overlapping_bodies():
		if not (body is Node3D):
			continue
		if body == self:
			continue
		var hit_target := body as Node3D
		var body_id := hit_target.get_instance_id()
		if _attack_hit_once.has(body_id):
			continue
		_attack_hit_once[body_id] = true
		var dir := (hit_target.global_position - global_position).normalized()
		attack_hit.emit(hit_target, 16, 9.0, dir)

func _apply_attack_fallback(forward_dir: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node3D):
			continue
		var enemy := node as Node3D
		var enemy_id := enemy.get_instance_id()
		if _attack_hit_once.has(enemy_id):
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance > attack_reach:
			continue
		if distance < 0.01:
			continue
		var dir_to_enemy := to_enemy / distance
		if dir_to_enemy.dot(forward_dir) < attack_arc_dot:
			continue
		_attack_hit_once[enemy_id] = true
		attack_hit.emit(enemy, 16, 9.0, dir_to_enemy)

func _get_vertical_velocity(delta: float) -> float:
	if is_on_floor():
		return -0.1
	return velocity.y - gravity * delta

func _play_attack_anim() -> void:
	if _attack_anim_tween and _attack_anim_tween.is_valid():
		_attack_anim_tween.kill()
	body_mesh.scale = Vector3.ONE
	_attack_anim_tween = create_tween()
	_attack_anim_tween.tween_property(body_mesh, "scale", Vector3(1.25, 0.78, 1.1), 0.05)
	_attack_anim_tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.1)
