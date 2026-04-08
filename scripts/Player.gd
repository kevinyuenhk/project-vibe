extends CharacterBody2D

## Top-down Player Controller — smooth 8-way movement + touch support

@export var speed: float = 200.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var friction: float = 15.0
@export var attack_duration: float = 0.12
@export var attack_cooldown: float = 0.22
@export var attack_offset: float = 28.0
@export var combo_reset_time: float = 0.45
@export var max_hp: int = 120
@export var hurt_invuln_time: float = 0.4

var _direction := Vector2.ZERO
var _touch_direction := Vector2.ZERO
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _combo_timer: float = 0.0
var _combo_step: int = 0
var _active_attack: Dictionary = {}
var _invuln_timer: float = 0.0
var _current_hp: int = 0
var _facing := Vector2.DOWN

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_telegraph: Polygon2D = $AttackTelegraph

const _COMBO_PROFILE: Array[Dictionary] = [
	{"duration": 0.09, "cooldown": 0.09, "offset": 24.0, "size": Vector2(30, 20), "damage": 12, "knockback": 250.0},
	{"duration": 0.10, "cooldown": 0.11, "offset": 30.0, "size": Vector2(38, 24), "damage": 16, "knockback": 310.0},
	{"duration": 0.13, "cooldown": 0.17, "offset": 38.0, "size": Vector2(48, 30), "damage": 24, "knockback": 440.0},
]

signal attack_started(facing: Vector2, combo_step: int)
signal attack_finished()
signal attack_hit(target: Node2D, damage: int, knockback: float, hit_direction: Vector2)
signal hp_changed(current: int, maximum: int)
signal died()

func _ready() -> void:
	_current_hp = max_hp
	attack_shape.disabled = true
	attack_area.monitoring = false
	attack_telegraph.visible = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	hp_changed.emit(_current_hp, max_hp)

func _physics_process(delta: float) -> void:
	if _current_hp <= 0:
		velocity = velocity.move_toward(Vector2.ZERO, speed * friction * delta)
		move_and_slide()
		return

	if _dash_cooldown_timer > 0:
		_dash_cooldown_timer -= delta
	if _attack_cooldown_timer > 0:
		_attack_cooldown_timer -= delta
	if _combo_timer > 0:
		_combo_timer -= delta
	elif _combo_step != 0:
		_combo_step = 0
	if _invuln_timer > 0:
		_invuln_timer -= delta

	if _dash_timer > 0:
		_dash_timer -= delta
		velocity = velocity.normalized() * dash_speed
		move_and_slide()
		return
	if _attack_timer > 0:
		_attack_timer -= delta
		if _attack_timer <= 0:
			_end_attack()

	# Keyboard input
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	
	# Use touch direction if active, otherwise keyboard
	var move_input = _touch_direction if _touch_direction != Vector2.ZERO else input
	
	if move_input != Vector2.ZERO:
		_direction = _project_input_to_world(move_input)
		_facing = move_input
		velocity = velocity.move_toward(_direction * speed, speed * friction * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * friction * delta)
		_direction = Vector2.ZERO

	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0 and _direction != Vector2.ZERO:
		velocity = _direction.normalized() * dash_speed
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown
	if Input.is_action_just_pressed("attack"):
		trigger_attack()

	move_and_slide()

func set_touch_direction(dir: Vector2) -> void:
	_touch_direction = dir

func trigger_attack() -> void:
	if _attack_cooldown_timer > 0:
		return

	if _combo_timer > 0:
		_combo_step = min(_combo_step + 1, _COMBO_PROFILE.size())
	else:
		_combo_step = 1
	_combo_timer = combo_reset_time

	var profile := _COMBO_PROFILE[_combo_step - 1]
	_active_attack = profile
	var facing_direction := _get_world_facing()
	attack_area.position = facing_direction * float(profile["offset"])
	attack_area.rotation = facing_direction.angle()
	_show_attack_telegraph(profile, facing_direction)
	var hit_box := attack_shape.shape as RectangleShape2D
	if hit_box:
		hit_box.size = profile["size"]

	attack_shape.disabled = false
	attack_area.monitoring = true
	_attack_timer = float(profile["duration"])
	_attack_cooldown_timer = float(profile["cooldown"])
	attack_started.emit(facing_direction, _combo_step)

func trigger_dash() -> void:
	if _dash_cooldown_timer <= 0 and _direction != Vector2.ZERO:
		velocity = _direction.normalized() * dash_speed
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown

func get_facing_direction() -> Vector2:
	return _facing

func _end_attack() -> void:
	_attack_timer = 0.0
	attack_shape.disabled = true
	attack_area.monitoring = false
	attack_telegraph.visible = false
	attack_finished.emit()

func _get_world_facing() -> Vector2:
	if _facing == Vector2.ZERO:
		return Vector2.DOWN

	return _project_input_to_world(_facing)

func _project_input_to_world(input_dir: Vector2) -> Vector2:
	return input_dir.normalized()

func _show_attack_telegraph(profile: Dictionary, facing_direction: Vector2) -> void:
	var hit_size: Vector2 = profile["size"]
	var width: float = hit_size.x
	var depth: float = float(profile["offset"]) + hit_size.y * 0.5
	var half_width: float = width * 0.5
	attack_telegraph.polygon = PackedVector2Array([
		Vector2(0, -half_width),
		Vector2(depth, 0),
		Vector2(0, half_width),
	])
	attack_telegraph.rotation = facing_direction.angle()
	var combo_t: float = float(_combo_step) / float(_COMBO_PROFILE.size())
	attack_telegraph.color = Color(1.0, lerpf(0.95, 0.45, combo_t), 0.22, lerpf(0.25, 0.45, combo_t))
	attack_telegraph.visible = true

func _on_attack_area_body_entered(body: Node2D) -> void:
	if _attack_timer <= 0 or body == self:
		return

	var damage := int(_active_attack.get("damage", 10))
	var knockback := float(_active_attack.get("knockback", 200.0))
	var hit_direction := (body.global_position - global_position).normalized()
	attack_hit.emit(body, damage, knockback, hit_direction)

func take_damage(amount: int, from_direction: Vector2, knockback_force: float = 180.0) -> void:
	if _current_hp <= 0 or _invuln_timer > 0:
		return

	_current_hp = max(_current_hp - amount, 0)
	_invuln_timer = hurt_invuln_time
	velocity += from_direction.normalized() * knockback_force
	modulate = Color(1.0, 0.7, 0.7, 1.0)
	var flash_timer := get_tree().create_timer(0.08)
	flash_timer.timeout.connect(func():
		modulate = Color(1, 1, 1, 1)
	)
	hp_changed.emit(_current_hp, max_hp)
	if _current_hp <= 0:
		died.emit()

func get_hp() -> int:
	return _current_hp
