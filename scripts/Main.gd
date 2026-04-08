extends Node2D

@onready var world: Node2D = $World
@onready var player = $World/Actors/Player
@onready var actor_layer: Node2D = $World/Actors
@onready var camera: Camera2D = $Camera2D
@onready var floor_layer: TileMapLayer = $World/Floor
@onready var wall_layer: TileMapLayer = $World/Walls
@onready var touch_controls: Control = $TouchControls
@onready var status_label: Label = $HUD/BottomBar/StatusLabel
@onready var combo_label: Label = $HUD/BottomBar/ComboLabel

@export var camera_look_ahead_distance: float = 52.0
@export var camera_look_ahead_smoothing: float = 7.0

var _dungeon: Node2D
var _rooms: Array = []
var _enemies: Array[Node2D] = []
var _kills: int = 0
var _combo_hits: int = 0
var _combo_timer: float = 0.0
var _player_dead: bool = false
var _camera_offset := Vector2.ZERO
var _hit_stop_active: bool = false

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

func _ready() -> void:
	# Connect touch signals
	if touch_controls:
		touch_controls.move.connect(_on_touch_move)
		touch_controls.attack.connect(_on_touch_attack)
		touch_controls.dash.connect(_on_touch_dash)
	if player:
		player.attack_started.connect(_on_player_attack_started)
		player.attack_hit.connect(_on_player_attack_hit)
		player.attack_finished.connect(_on_player_attack_finished)
		player.hp_changed.connect(_on_player_hp_changed)
		player.died.connect(_on_player_died)

	Engine.time_scale = 1.0
	
	_generate_dungeon()

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	# Keep camera locked to player position
	camera.global_position = player.global_position

	# Lookahead: nudge the camera offset in the direction of travel
	var player_speed: float = maxf(player.speed, 1.0)
	var speed_ratio: float = clampf(player.velocity.length() / player_speed, 0.0, 1.0)
	var target_offset: Vector2 = player.velocity.normalized() * camera_look_ahead_distance * speed_ratio
	var t: float = clampf(delta * camera_look_ahead_smoothing, 0.0, 1.0)
	_camera_offset = _camera_offset.lerp(target_offset, t)
	camera.offset = _camera_offset

func _physics_process(delta: float) -> void:
	if _combo_timer > 0:
		_combo_timer -= delta
	else:
		_combo_hits = 0
		combo_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_R:
			_generate_dungeon()

func _on_touch_move(dir: Vector2) -> void:
	if player:
		player.set_touch_direction(dir)

func _on_touch_attack() -> void:
	if player:
		player.trigger_attack()

func _on_touch_dash() -> void:
	if player:
		player.trigger_dash()

func _generate_dungeon() -> void:
	if _dungeon:
		_dungeon.queue_free()
	
	_dungeon = Node2D.new()
	_dungeon.name = "DungeonGenerator"
	add_child(_dungeon)
	
	var gen_script = preload("res://scripts/DungeonGenerator.gd")
	_dungeon.set_script(gen_script)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_clear_enemies()
	_kills = 0
	_combo_hits = 0
	_combo_timer = 0.0
	_player_dead = false
	_hit_stop_active = false
	Engine.time_scale = 1.0
	_camera_offset = Vector2.ZERO
	camera.offset = Vector2.ZERO
	combo_label.text = ""

	generate_dungeon()

func generate_dungeon() -> void:
	var gen = $DungeonGenerator
	if not gen.dungeon_generated.is_connected(_on_dungeon_generated):
		gen.dungeon_generated.connect(_on_dungeon_generated)

	# 2.5D oblique projection: tiles are 2:1 width:height (same as Diablo / 地城之光)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(64, 32)
	tileset.add_physics_layer(0)

	var floor_source := TileSetAtlasSource.new()
	floor_source.texture = _make_floor_texture()
	floor_source.texture_region_size = Vector2i(64, 32)
	floor_source.create_tile(Vector2i(0, 0))

	# Wall tile is 64×64: top 32px = roof face, bottom 32px = front face
	var wall_source := TileSetAtlasSource.new()
	wall_source.texture = _make_wall_texture()
	wall_source.texture_region_size = Vector2i(64, 64)
	wall_source.create_tile(Vector2i(0, 0))

	# Solid collision on the wall tile (covers the 64×32 footprint)
	var tile_data: TileData = wall_source.get_tile_data(Vector2i(0, 0), 0)
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-32, -16), Vector2(32, -16), Vector2(32, 16), Vector2(-32, 16)
	]))

	tileset.add_source(floor_source, 0)
	tileset.add_source(wall_source, 1)

	floor_layer.tile_set = tileset
	wall_layer.tile_set = tileset

	gen.generate(floor_layer)

func _make_floor_texture() -> ImageTexture:
	const W := 64
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.18, 0.15, 0.12))
	# Tile grid lines
	for i in range(W):
		img.set_pixel(i, 0, Color(0.10, 0.08, 0.06))
		img.set_pixel(i, H - 1, Color(0.24, 0.20, 0.17))
	for i in range(H):
		img.set_pixel(0, i, Color(0.10, 0.08, 0.06))
		img.set_pixel(W - 1, i, Color(0.24, 0.20, 0.17))
	# Subtle highlight on top-left corner (light source illusion)
	img.set_pixel(1, 1, Color(0.26, 0.22, 0.18))
	return ImageTexture.create_from_image(img)

func _make_wall_texture() -> ImageTexture:
	const W := 64
	const TH := 32  # top face height (matches tile_size.y)
	const FH := 32  # front face height
	var img := Image.create(W, TH + FH, false, Image.FORMAT_RGBA8)

	# Top face — slightly lighter, seen from above
	for y in range(TH):
		for x in range(W):
			var t := float(y) / TH
			var c := Color(0.40, 0.35, 0.27).lerp(Color(0.30, 0.26, 0.20), t)
			img.set_pixel(x, y, c)

	# Front face — darker stone, lit from top-left
	for y in range(FH):
		for x in range(W):
			var shade := 1.0 - float(y) / FH * 0.35          # darker toward bottom
			var edge  := 1.0 - float(x) / W * 0.15            # slightly darker right edge
			var c := Color(0.46 * shade * edge, 0.40 * shade * edge, 0.30 * shade * edge)
			img.set_pixel(x, TH + y, c)

	# Edge highlights
	for x in range(W):
		img.set_pixel(x, 0,        Color(0.60, 0.54, 0.44))  # bright top cap
		img.set_pixel(x, TH,       Color(0.22, 0.18, 0.14))  # shadow at top/front seam
		img.set_pixel(x, TH + FH - 1, Color(0.12, 0.10, 0.07))  # dark base
	for y in range(TH + FH):
		img.set_pixel(0,     y, Color(0.20, 0.17, 0.13))
		img.set_pixel(W - 1, y, Color(0.18, 0.15, 0.11))

	return ImageTexture.create_from_image(img)

func _on_dungeon_generated(floor_cells: Array, wall_cells: Array, rooms: Array) -> void:
	_rooms = rooms
	for cell in floor_cells:
		floor_layer.set_cell(cell, 0, Vector2i(0, 0))
	for cell in wall_cells:
		wall_layer.set_cell(cell, 1, Vector2i(0, 0))

	if rooms.size() > 0:
		var spawn := Vector2i(rooms[0].position.x + rooms[0].size.x / 2, rooms[0].position.y + rooms[0].size.y / 2)
		player.position = _grid_to_world(spawn)
		camera.global_position = player.global_position
		camera.offset = Vector2.ZERO
		_camera_offset = Vector2.ZERO

	_spawn_enemies(rooms)
	_refresh_status()

	print("✅ Dungeon rendered — Player at: ", player.position)

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	# 2.5D oblique: 64px wide × 32px tall per grid cell
	return Vector2(grid_pos.x * 64.0, grid_pos.y * 32.0)

func _on_player_attack_started(_facing: Vector2, combo_step: int) -> void:
	combo_label.text = "Slash %d" % combo_step

func _on_player_attack_hit(target: Node2D, damage: int, knockback: float, hit_direction: Vector2) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("take_hit"):
		target.take_hit(damage, knockback, hit_direction)
		_apply_hit_stop()
		_combo_hits += 1
		_combo_timer = 1.2
		combo_label.text = "COMBO x%d" % _combo_hits

func _on_player_attack_finished() -> void:
	pass

func _spawn_enemies(rooms: Array) -> void:
	if rooms.is_empty():
		return
	# Player spawn grid cell — no enemies within this many tiles
	const MIN_SAFE_DISTANCE := 12
	var player_grid := Vector2i(
		rooms[0].position.x + rooms[0].size.x / 2,
		rooms[0].position.y + rooms[0].size.y / 2
	)

	for i in range(1, rooms.size()):
		var room: Rect2i = rooms[i]
		var room_center := Vector2i(
			room.position.x + room.size.x / 2,
			room.position.y + room.size.y / 2
		)
		# Skip rooms whose center is too close to the player spawn
		if room_center.distance_to(player_grid) < MIN_SAFE_DISTANCE:
			continue

		var spawn_count := clampi((room.size.x * room.size.y) / 32, 1, 3)
		for j in range(spawn_count):
			var enemy := ENEMY_SCENE.instantiate()
			if enemy == null:
				continue
			enemy.global_position = _grid_to_world(_random_room_point(room, j))
			enemy.setup(player)
			enemy.died.connect(_on_enemy_died)
			enemy.hit_player.connect(_on_enemy_hit_player)
			actor_layer.add_child(enemy)
			_enemies.append(enemy)

func _random_room_point(room: Rect2i, seed_offset: int) -> Vector2i:
	var min_x: int = room.position.x + 1
	var max_x: int = maxi(room.end.x - 2, min_x)
	var min_y: int = room.position.y + 1
	var max_y: int = maxi(room.end.y - 2, min_y)
	return Vector2i(
		randi_range(min_x, max_x) + (seed_offset % 2),
		randi_range(min_y, max_y)
	)

func _on_enemy_hit_player(damage: int, from_position: Vector2) -> void:
	if _player_dead:
		return
	var dir: Vector2 = (player.global_position - from_position).normalized()
	player.take_damage(damage, dir, 210.0)

func _on_enemy_died(enemy: Node2D) -> void:
	_enemies.erase(enemy)
	_kills += 1
	_refresh_status()
	if _enemies.is_empty() and not _player_dead:
		status_label.text = "Room cleared! Press R for a new run."

func _on_player_hp_changed(current: int, maximum: int) -> void:
	if _player_dead:
		return
	status_label.text = "HP %d/%d  |  Kills %d  |  Enemies %d" % [current, maximum, _kills, _enemies.size()]

func _on_player_died() -> void:
	_player_dead = true
	Engine.time_scale = 1.0
	_hit_stop_active = false
	status_label.text = "You are down. Press R to restart."
	combo_label.text = ""

func _refresh_status() -> void:
	if _player_dead:
		return
	status_label.text = "HP %d/%d  |  Kills %d  |  Enemies %d" % [player.get_hp(), player.max_hp, _kills, _enemies.size()]

func _clear_enemies() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()

func _apply_hit_stop(duration: float = 0.045, slow_scale: float = 0.18) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = slow_scale
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
		_hit_stop_active = false
	)
