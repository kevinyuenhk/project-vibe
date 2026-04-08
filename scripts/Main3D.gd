extends Node3D

@onready var player: CharacterBody3D = $World/Actors/Player
@onready var actors: Node3D = $World/Actors
@onready var wall_root: Node3D = $World/Walls
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var status_label: Label = $HUD/BottomBar/StatusLabel
@onready var combo_label: Label = $HUD/BottomBar/ComboLabel

const ENEMY_SCENE := preload("res://scenes/Enemy3D.tscn")

var _enemies: Array[Node3D] = []
var _kills: int = 0
var _combo_hits: int = 0
var _combo_timer: float = 0.0
var _is_dead: bool = false
@export var arena_radius: int = 60
@export var visible_ground_margin: int = 96
@export var obstacle_count: int = 90
@export var enemy_count: int = 42
@export var player_safe_spawn_radius: float = 22.0
@export var guaranteed_clear_start_radius: float = 28.0
@export var enemy_spawn_min_radius_from_player: float = 34.0
@export var spawn_damage_grace_time: float = 1.0
@export var camera_height: float = 11.0
@export var camera_distance: float = 11.5
@export var camera_orbit_sensitivity: float = 0.006
var _camera_yaw: float = 0.0
var _spawn_sanitize_time_left: float = 0.0
var _spawn_damage_grace_left: float = 0.0

func _ready() -> void:
	player.set_camera_ref(camera)
	player.attack_started.connect(_on_attack_started)
	player.attack_hit.connect(_on_attack_hit)
	player.hp_changed.connect(_on_hp_changed)
	player.died.connect(_on_player_died)
	_build_arena()
	_spawn_wave()
	_refresh_status()
	camera.current = true

func _process(delta: float) -> void:
	var orbit_offset := Vector3(0.0, camera_height, camera_distance).rotated(Vector3.UP, _camera_yaw)
	var target: Vector3 = player.global_position + orbit_offset
	camera.global_position = camera.global_position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	camera.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)

	if _combo_timer > 0:
		_combo_timer -= delta
	else:
		_combo_hits = 0
		combo_label.text = ""

	if _spawn_sanitize_time_left > 0.0:
		_spawn_sanitize_time_left -= delta
		_enforce_player_safe_zone(player.global_position, enemy_spawn_min_radius_from_player)
	if _spawn_damage_grace_left > 0.0:
		_spawn_damage_grace_left -= delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var motion := event as InputEventMouseMotion
		_camera_yaw -= motion.relative.x * camera_orbit_sensitivity

	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_R:
			_reset_run()

func _build_arena() -> void:
	for child in wall_root.get_children():
		child.queue_free()

	var full_floor_size := float(arena_radius * 2 + visible_ground_margin)
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(full_floor_size, 1.0, full_floor_size)
	floor.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.24, 0.23, 0.21)
	floor_mat.metallic = 0.1
	floor_mat.roughness = 0.86
	floor.material_override = floor_mat
	floor.position.y = -0.5
	wall_root.add_child(floor)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 4
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(full_floor_size, 1.0, full_floor_size)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	wall_root.add_child(floor_body)

	for x in range(-arena_radius, arena_radius + 1):
		_make_wall_block(Vector3(x, 1.0, -arena_radius))
		_make_wall_block(Vector3(x, 1.0, arena_radius))
	for z in range(-arena_radius + 1, arena_radius):
		_make_wall_block(Vector3(-arena_radius, 1.0, z))
		_make_wall_block(Vector3(arena_radius, 1.0, z))

	for i in range(obstacle_count):
		var px := randi_range(-arena_radius + 4, arena_radius - 4)
		var pz := randi_range(-arena_radius + 4, arena_radius - 4)
		if abs(px) <= 6 and abs(pz) <= 6:
			continue
		var pos := Vector3(px, 0.0, pz)
		if randi() % 2 == 0:
			_make_pillar(pos)
		else:
			_make_crate(pos)

func _make_wall_block(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.position = pos
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 2.0, 1)
	collider.shape = shape
	body.add_child(collider)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 2.0, 1)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.14, 0.13)
	mat.roughness = 0.9
	mesh.material_override = mat
	body.add_child(mesh)
	wall_root.add_child(body)

func _make_pillar(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.position = pos + Vector3(0, 0.8, 0)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 1.6
	shape.radius = 0.65
	collider.shape = shape
	body.add_child(collider)

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 1.6
	cyl.top_radius = 0.58
	cyl.bottom_radius = 0.7
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.27, 0.22)
	mesh.material_override = mat
	body.add_child(mesh)
	wall_root.add_child(body)

func _make_crate(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.position = pos + Vector3(0, 0.65, 0)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var side := randf_range(0.9, 1.5)
	shape.size = Vector3(side, 1.3, side)
	collider.shape = shape
	body.add_child(collider)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.27, 0.21, 0.16)
	mat.roughness = 0.95
	mesh.material_override = mat
	body.add_child(mesh)
	wall_root.add_child(body)

func _spawn_wave() -> void:
	_remove_all_enemy_nodes_immediately()
	_enemies.clear()
	_kills = 0
	_combo_hits = 0
	_combo_timer = 0.0
	_is_dead = false
	combo_label.text = ""
	player.reset_for_run(Vector3(0, 0, 0))
	var player_pos := player.global_position
	for i in range(enemy_count):
		var spawn := _find_enemy_spawn(player_pos, null, enemy_spawn_min_radius_from_player)
		if spawn == Vector3.INF:
			continue
		var enemy := ENEMY_SCENE.instantiate()
		actors.add_child(enemy)
		enemy.global_position = spawn
		enemy.setup(player)
		enemy.died.connect(_on_enemy_died)
		enemy.hit_player.connect(_on_enemy_hit_player)
		_enemies.append(enemy)
	_enforce_player_safe_zone(player_pos, enemy_spawn_min_radius_from_player)
	_fill_enemy_count(player_pos, enemy_spawn_min_radius_from_player)
	_rebuild_enemy_list_from_scene()
	_spawn_sanitize_time_left = 1.2
	_spawn_damage_grace_left = spawn_damage_grace_time

func _find_enemy_spawn(player_pos: Vector3, ignore_enemy: Node3D, min_player_distance: float) -> Vector3:
	var clear_radius := maxf(maxf(player_safe_spawn_radius, guaranteed_clear_start_radius), min_player_distance)
	for _attempt in range(140):
		var max_radius := float(arena_radius - 2)
		var radius := randf_range(clear_radius, max_radius)
		var angle := randf_range(0.0, TAU)
		var spawn := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if _distance_xz(spawn, player_pos) < clear_radius:
			continue
		var too_close := false
		for node in actors.get_children():
			if node == player:
				continue
			if not (node is Node3D):
				continue
			var enemy := node as Node3D
			if not enemy.is_in_group("enemy"):
				continue
			if enemy == ignore_enemy:
				continue
			if _distance_xz(spawn, enemy.global_position) < 2.0:
				too_close = true
				break
		if too_close:
			continue
		return spawn
	return Vector3.INF

func _enforce_player_safe_zone(player_pos: Vector3, min_player_distance: float) -> void:
	var clear_radius := maxf(maxf(player_safe_spawn_radius, guaranteed_clear_start_radius), min_player_distance)
	var tracked: Array[Node3D] = []
	for node in actors.get_children():
		if node == player:
			continue
		if not (node is Node3D):
			continue
		var enemy := node as Node3D
		if not enemy.is_in_group("enemy"):
			continue
		tracked.append(enemy)
		if _distance_xz(enemy.global_position, player_pos) >= clear_radius:
			continue
		var new_spawn := _find_enemy_spawn(player_pos, enemy, min_player_distance)
		if new_spawn != Vector3.INF:
			enemy.global_position = new_spawn
		else:
			enemy.free()

	# Keep only valid and safe enemies after relocation.
	var kept: Array[Node3D] = []
	for enemy in tracked:
		if not is_instance_valid(enemy):
			continue
		if _distance_xz(enemy.global_position, player_pos) < clear_radius:
			enemy.free()
			continue
		kept.append(enemy)
	_enemies = kept

func _fill_enemy_count(player_pos: Vector3, min_player_distance: float) -> void:
	while _enemies.size() < enemy_count:
		var spawn := _find_enemy_spawn(player_pos, null, min_player_distance)
		if spawn == Vector3.INF:
			break
		var enemy := ENEMY_SCENE.instantiate()
		actors.add_child(enemy)
		enemy.global_position = spawn
		enemy.setup(player)
		enemy.died.connect(_on_enemy_died)
		enemy.hit_player.connect(_on_enemy_hit_player)
		_enemies.append(enemy)

func _rebuild_enemy_list_from_scene() -> void:
	var rebuilt: Array[Node3D] = []
	for node in actors.get_children():
		if node != player and node.is_in_group("enemy"):
			rebuilt.append(node)
	_enemies = rebuilt

func _distance_xz(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return sqrt(dx * dx + dz * dz)

func _on_attack_started() -> void:
	combo_label.text = "Slash"

func _on_attack_hit(target: Node3D, damage: int, knockback: float, direction: Vector3) -> void:
	if target and target.has_method("take_hit"):
		target.take_hit(damage, knockback, direction)
		_combo_hits += 1
		_combo_timer = 1.2
		combo_label.text = "COMBO x%d" % _combo_hits

func _on_enemy_hit_player(damage: int, from_position: Vector3) -> void:
	if _is_dead:
		return
	if _spawn_damage_grace_left > 0.0:
		return
	var dir := (player.global_position - from_position).normalized()
	player.take_damage(damage, dir, 5.5)

func _on_enemy_died(enemy: Node3D) -> void:
	_enemies.erase(enemy)
	_kills += 1
	_refresh_status()
	if _enemies.is_empty():
		status_label.text = "Clear! Press R to restart."

func _on_hp_changed(current: int, maximum: int) -> void:
	if _is_dead:
		return
	status_label.text = "HP %d/%d  |  Kills %d  |  Enemies %d" % [current, maximum, _kills, _enemies.size()]

func _on_player_died() -> void:
	_is_dead = true
	status_label.text = "Defeated. Press R to restart."
	combo_label.text = ""

func _refresh_status() -> void:
	status_label.text = "HP %d/%d  |  Kills %d  |  Enemies %d" % [player.get_hp(), player.max_hp, _kills, _enemies.size()]

func _reset_run() -> void:
	_spawn_wave()
	_refresh_status()

func _remove_all_enemy_nodes_immediately() -> void:
	for node in actors.get_children():
		if node != player and node.is_in_group("enemy"):
			node.free()
