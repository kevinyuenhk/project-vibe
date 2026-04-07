## Dungeon Generator — BSP-based random room placement
extends Node2D

const TILE_SIZE := Vector2i(64, 32)  # isometric tile
const MIN_ROOM_SIZE := 4
const MAX_ROOM_SIZE := 10
const ROOM_MARGIN := 1
const DUNGEON_WIDTH := 40
const DUNGEON_HEIGHT := 40
const MAX_ROOMS := 15

var _floor_positions: Array[Vector2i] = []
var _wall_positions: Array[Vector2i] = []
var _rooms: Array[Rect2i] = []
var _tile_map: TileMapLayer

signal dungeon_generated(floor_cells: Array[Vector2i], wall_cells: Array[Vector2i], rooms: Array[Rect2i])


func generate(tile_map_layer: TileMapLayer) -> void:
	_tile_map = tile_map_layer
	_floor_positions.clear()
	_wall_positions.clear()
	_rooms.clear()
	
	# Clear existing
	_tile_map.clear()
	
	# Generate rooms with BSP-like random placement
	var attempts := 0
	while _rooms.size() < MAX_ROOMS and attempts < 200:
		var w := randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var h := randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var x := randi_range(1, DUNGEON_WIDTH - w - 1)
		var y := randi_range(1, DUNGEON_HEIGHT - h - 1)
		var room := Rect2i(x, y, w, h)
		
		var overlaps := false
		for existing in _rooms:
			if room.grow(ROOM_MARGIN * 2).intersects(existing):
				overlaps = true
				break
		
		if not overlaps:
			_rooms.append(room)
		attempts += 1
	
	# Sort rooms by position for corridor connection
	_rooms.sort_custom(func(a, b): return (a.position.x + a.position.y) < (b.position.x + b.position.y))
	
	# Carve rooms
	for room in _rooms:
		_carve_room(room)
	
	# Connect rooms with corridors (L-shaped)
	for i in range(_rooms.size() - 1):
		_carve_corridor(_room_center(_rooms[i]), _room_center(_rooms[i + 1]))
	
	dungeon_generated.emit(_floor_positions, _wall_positions, _rooms)
	print("Dungeon generated: %d rooms, %d floor tiles, %d wall tiles" % [_rooms.size(), _floor_positions.size(), _wall_positions.size()])


func _carve_room(room: Rect2i) -> void:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			var pos := Vector2i(x, y)
			_floor_positions.append(pos)
			# Add walls around edges
			if x == room.position.x or x == room.end.x - 1 or y == room.position.y or y == room.end.y - 1:
				_wall_positions.append(pos)


func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var current := from
	# L-shape: horizontal first, then vertical
	while current.x != to.x:
		current.x += 1 if to.x > current.x else -1
		if current not in _floor_positions:
			_floor_positions.append(current)
	while current.y != to.y:
		current.y += 1 if to.y > current.y else -1
		if current not in _floor_positions:
			_floor_positions.append(current)


func _room_center(room: Rect2i) -> Vector2i:
	return Vector2i(
		room.position.x + room.size.x / 2,
		room.position.y + room.size.y / 2
	)


func _room_at_position(grid_pos: Vector2i) -> Rect2i:
	for room in _rooms:
		if room.abs().has_point(grid_pos):
			return room
	return Rect2i()


func get_player_spawn() -> Vector2i:
	if _rooms.is_empty():
		return Vector2i.ZERO
	return _room_center(_rooms[0])


func get_boss_spawn() -> Vector2i:
	if _rooms.is_empty():
		return Vector2i.ZERO
	return _room_center(_rooms[_rooms.size() - 1])
