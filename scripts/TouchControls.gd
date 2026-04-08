## Virtual joystick + touch controls — web/mobile compatible
## Uses _unhandled_input so UI panels don't eat touch events
extends Control

@export var joystick_radius: float = 60.0
@export var deadzone: float = 12.0

var _joystick_touch: int = -1
var _joystick_origin: Vector2 = Vector2.ZERO
var _joystick_dir := Vector2.ZERO

signal move(direction: Vector2)
signal attack()
signal dash()

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100  # above everything

func _unhandled_input(event: InputEvent) -> void:
	var viewport_w = get_viewport().get_visible_rect().size.x
	var viewport_h = get_viewport().get_visible_rect().size.y

	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.x < viewport_w * 0.4:
				# Left side → joystick
				_joystick_touch = t.index
				_joystick_origin = t.position
			elif t.position.y < viewport_h * 0.5:
				# Right-top → dash
				dash.emit()
			else:
				# Right-bottom → attack
				attack.emit()
		else:
			if t.index == _joystick_touch:
				_joystick_touch = -1
				_joystick_dir = Vector2.ZERO
				move.emit(Vector2.ZERO)
				queue_redraw()

	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joystick_touch:
			var diff := d.position - _joystick_origin
			if diff.length() > deadzone:
				_joystick_dir = diff.normalized()
			else:
				_joystick_dir = Vector2.ZERO
			move.emit(_joystick_dir)
			queue_redraw()

func _draw() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var base_pos = Vector2(viewport_size.x * 0.15, viewport_size.y * 0.7)

	if _joystick_touch >= 0:
		# Active joystick
		draw_circle(_joystick_origin, joystick_radius, Color(1, 1, 1, 0.12))
		draw_circle(_joystick_origin, joystick_radius, Color(1, 1, 1, 0.25), 2.0)
		var thumb = _joystick_origin + _joystick_dir * joystick_radius * 0.6
		draw_circle(thumb, 22.0, Color(1, 1, 1, 0.4))
	else:
		# Hint ring
		draw_circle(base_pos, joystick_radius, Color(1, 1, 1, 0.04))
		draw_circle(base_pos, joystick_radius, Color(1, 1, 1, 0.08), 1.5)

	# Attack button hint (right-bottom)
	var atk_pos = Vector2(viewport_size.x * 0.82, viewport_size.y * 0.72)
	draw_circle(atk_pos, 36.0, Color(1, 0.4, 0.3, 0.12))
	draw_circle(atk_pos, 36.0, Color(1, 0.4, 0.3, 0.25), 2.0)

	# Dash button hint (right-top)
	var dash_pos = Vector2(viewport_size.x * 0.82, viewport_size.y * 0.45)
	draw_circle(dash_pos, 28.0, Color(0.3, 0.6, 1, 0.10))
	draw_circle(dash_pos, 28.0, Color(0.3, 0.6, 1, 0.20), 2.0)
