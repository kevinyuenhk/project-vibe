extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var touch_controls: Control = $TouchControls

var _dungeon: Node2D

func _ready() -> void:
	# Connect touch signals
	if touch_controls:
		touch_controls.move.connect(_on_touch_move)
		touch_controls.attack.connect(_on_touch_attack)
		touch_controls.dash.connect(_on_touch_dash)
	
	_generate_dungeon()

func _on_touch_move(dir: Vector2) -> void:
	if player:
		player.set_touch_direction(dir)

func _on_touch_attack() -> void:
	# TODO: trigger attack animation/action
	print("Attack!")

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
	
	generate_dungeon()

func generate_dungeon() -> void:
	var gen = $DungeonGenerator
	if not gen.dungeon_generated.is_connected(_on_dungeon_generated):
		gen.dungeon_generated.connect(_on_dungeon_generated)
	
	var tileset = TileSet.new()
	
	var floor_source = TileSetAtlasSource.new()
	floor_source.texture = load("res://assets/tilesets/floor_tile.png")
	floor_source.texture_region_size = Vector2i(64, 32)
	floor_source.create_tile(Vector2i(0, 0))
	
	var wall_source = TileSetAtlasSource.new()
	wall_source.texture = load("res://assets/tilesets/wall_tile.png")
	wall_source.texture_region_size = Vector2i(64, 32)
	wall_source.create_tile(Vector2i(0, 0))
	
	tileset.add_source(floor_source, 0)
	tileset.add_source(wall_source, 1)
	tileset.add_physics_layer(0)
	
	floor_layer.tile_set = tileset
	wall_layer.tile_set = tileset
	
	gen.generate(floor_layer)

func _on_dungeon_generated(floor_cells: Array, wall_cells: Array, rooms: Array) -> void:
	for cell in floor_cells:
		floor_layer.set_cell(cell, 0, Vector2i(0, 0))
	for cell in wall_cells:
		$Walls.set_cell(cell, 1, Vector2i(0, 0))
	
	if rooms.size() > 0:
		var spawn = Vector2i(rooms[0].position.x + rooms[0].size.x / 2, rooms[0].position.y + rooms[0].size.y / 2)
		player.position = _grid_to_world(spawn)
		camera.position_smoothing_enabled = false
		camera.global_position = player.global_position
		await get_tree().process_frame
		camera.position_smoothing_enabled = true
	
	print("✅ Dungeon rendered — Player at: ", player.position)

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		(grid_pos.x - grid_pos.y) * 32.0,
		(grid_pos.x + grid_pos.y) * 16.0
	)
