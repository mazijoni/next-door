extends Node3D

const SWING_TIME := 0.4
const CRACK_ANGLE := 20.0
const FULL_ANGLE := 90.0

enum State { CLOSED, CRACKED, OPEN }

@export_range(0.0, 1.0) var spawn_cracked_chance: float = 0.3

var state := State.CLOSED
var open_side := 1
var tween: Tween
var initial_y: float

func _ready() -> void:
	initial_y = rotation.y
	if randf() < spawn_cracked_chance:
		open_side = [-1, 1].pick_random()
		state = State.CRACKED
		rotation.y = initial_y + deg_to_rad(CRACK_ANGLE * open_side)

func interact(from_pos: Vector3, crouching: bool = false) -> void:
	var target_y := initial_y
	var side := 1 if to_local(from_pos).z >= 0.0 else -1

	if crouching:
		match state:
			State.CLOSED:
				open_side = side
				target_y = initial_y + deg_to_rad(CRACK_ANGLE * open_side)
				state = State.CRACKED
			State.CRACKED, State.OPEN:
				state = State.CLOSED
	else:
		match state:
			State.CLOSED, State.CRACKED:
				open_side = side
				target_y = initial_y + deg_to_rad(FULL_ANGLE * open_side)
				state = State.OPEN
			State.OPEN:
				state = State.CLOSED

	_swing(target_y)

func _swing(target_y: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "rotation:y", target_y, SWING_TIME)
