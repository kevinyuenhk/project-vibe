extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls

var _dungeon: Node2D

func _ready() -> void:
	_generate_dungeon()


func _generate_dungeon() -> void:
	# Remove old dungeon
	if _dungeon:
		_dungeon.queue_free()
	
	_dungeon = Node2D.new()
	_dungeon.name = "DungeonGenerator"
	add_child(_dungeon)
	
	var gen_script = preload("res://scripts/DungeonGenerator.gd")
	_dungeon.set_script(gen_script)
	var gen = _dungeon as Node2D
	
	# Wait a frame for script to attach
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Generate
	generate_dungeon(gen)


func generate_dungeon(gen: Node2D) -> void:
	# Connect signal
	if not gen.dungeon_generated.is_connected(_on_dungeon_generated):
		gen.dungeon_generated.connect(_on_dungeon_generated)
	
	# Create tileset source from our placeholder tiles
	var tileset = TileSet.new()
	var floor_source = TileSetAtlasSource.new()
	var wall_source = TileSetAtlasSource.new()
	
	# Floor tile
	var floor_tex = load("res://assets/tilesets/floor_tile.png")
	floor_source.texture = floor_tex
	floor_source.texture_region_size = Vector2i(64, 32)
	floor_source.create_tile(Vector2i(0, 0))
	
	# Wall tile
	var wall_tex = load("res://assets/tilesets/wall_tile.png")
	wall_source.texture = wall_tex
	wall_source.texture_region_size = Vector2i(64, 32)
	wall_source.create_tile(Vector2i(0, 0))
	
	tileset.add_source(floor_source, 0)  # source_id 0 = floor
	tileset.add_source(wall_source, 1)   # source_id 1 = wall
	
	# Physics layers for wall collision
	var physics_layer = TileSetPhysicsLayer.new()
	var poly = ConvexPolygonShape2D.new()
	var isometric_shape := PackedVector2Array([
		Vector2(-32, 0), Vector2(0, -16), Vector2(32, 0), Vector2(0, 16)
	])
	poly.set_point_cloud(isometric_shape)
	physics_layer.collision_polygon_one_way = false
	tileset.physics_layers_internal = []
	tileset.add_physics_layer(physics_layer)
	# We can't easily set per-tile collision via script, so we handle it differently
	
	floor_layer.tile_set = tileset
	wall_layer.tile_set = tileset
	
	# Generate!
	gen.generate(floor_layer)


func _on_dungeon_generated(floor_cells: Array, wall_cells: Array, rooms: Array) -> void:
	var tileset = floor_layer.tile_set
	var wall_layer_ref = $Walls
	
	# Draw floor
	for cell in floor_cells:
		floor_layer.set_cell(cell, 0, Vector2i(0, 0))
	
	# Draw walls (on wall layer)
	for cell in wall_cells:
		wall_layer_ref.set_cell(cell, 1, Vector2i(0, 0))
	
	# Spawn player in first room center
	var gen = $DungeonGenerator
	if rooms.size() > 0:
		var spawn = Vector2i(rooms[0].position.x + rooms[0].size.x / 2, rooms[0].position.y + rooms[0].size.y / 2)
		# Convert grid to isometric world position
		player.position = _grid_to_world(spawn)
		
		# Camera snap to player
		camera.position_smoothing_enabled = false
		camera.global_position = player.global_position
		await get_tree().process_frame
		camera.position_smoothing_enabled = true
	
	print("✅ Dungeon rendered — Player at: ", player.position)


func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Standard isometric conversion: (x - y) * tile_half_width, (x + y) * tile_half_height
	var tile_w = 64.0
	var tile_h = 32.0
	return Vector2(
		(grid_pos.x - grid_pos.y) * (tile_w / 2.0),
		(grid_pos.x + grid_pos.y) * (tile_h / 2.0)
	)
