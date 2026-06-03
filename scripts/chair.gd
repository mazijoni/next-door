class_name Chair
extends Item

@export var brake: int = 1

var _bracing_door: Node3D = null

func can_pick_up() -> bool:
	return _bracing_door == null

func place_against_door(door: Node3D) -> void:
	_bracing_door = door
	door.set_locked(true)

func interact(_from: Vector3, _crouch: bool = false) -> void:
	if _bracing_door == null:
		return
	_bracing_door.set_locked(false)
	_bracing_door = null
