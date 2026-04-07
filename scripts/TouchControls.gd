## Virtual joystick + touch controls for mobile/web
extends Control

@export var speed: float = 200.0
@export var joystick_size: float = 120.0
@export var deadzone: float = 15.0

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _direction := Vector2.ZERO
var _attacking := false

signal move(direction: Vector2)
signal attack()
signal dash()

func _ready() -> void:
	# Make this fill the screen
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# Left side = joystick, Right side = attack/dash
			if touch.position.x < get_viewport_rect().size.x * 0.5:
				_touch_index = touch.index
				_origin = touch.position
			else:
				if touch.position.y < get_viewport_rect().size.y * 0.5:
					dash.emit()
				else:
					_attacking = true
					attack.emit()
		else:
			if touch.index == _touch_index:
				_touch_index = -1
				_direction = Vector2.ZERO
				move.emit(Vector2.ZERO)
			if _attacking:
				_attacking = false

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			var diff := drag.position - _origin
			if diff.length() > deadzone:
				_direction = diff.normalized()
			else:
				_direction = Vector2.ZERO
			move.emit(_direction)

func _draw() -> void:
	# Draw joystick base
	if _touch_index >= 0:
		draw_circle(_origin, joystick_size / 2.0, Color(1, 1, 1, 0.15))
		draw_circle(_origin, joystick_size / 2.0, Color(1, 1, 1, 0.3), 2.0)
		# Thumb
		var thumb_pos = _origin + _direction * (joystick_size / 3.0)
		draw_circle(thumb_pos, joystick_size / 5.0, Color(1, 1, 1, 0.5))
	else:
		# Hint circles
		var screen_size = get_viewport_rect().size
		var left_pos = Vector2(screen_size.x * 0.15, screen_size.y * 0.7)
		draw_circle(left_pos, joystick_size / 2.0, Color(1, 1, 1, 0.05))
		draw_circle(left_pos, joystick_size / 2.0, Color(1, 1, 1, 0.1), 1.5)
