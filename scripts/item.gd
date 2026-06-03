class_name Item
extends RigidBody3D

@export var item_name: String = "Item"
@export var icon: Texture2D
@export var can_trip_enemy: bool = false

func _ready() -> void:
	add_to_group("thrown_item")

func can_pick_up() -> bool:
	return true

func interact(_from: Vector3, _crouch: bool = false) -> void:
	pass
