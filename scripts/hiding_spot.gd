@tool
class_name HidingSpot
extends Node3D

enum Type { STANDING, CROUCHING, CRAWLING }

@export var type: Type = Type.STANDING

var is_occupied := false

func _ready() -> void:
	if not Engine.is_editor_hint():
		var preview := get_node_or_null("Preview") as MeshInstance3D
		if preview:
			preview.visible = false

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var col := get_node_or_null("Area/CollisionShape3D") as CollisionShape3D
	if not col or not col.shape is BoxShape3D:
		return
	var shape_size := (col.shape as BoxShape3D).size
	var preview := get_node_or_null("Preview") as MeshInstance3D
	if not preview:
		return
	if preview.mesh is BoxMesh and (preview.mesh as BoxMesh).size.is_equal_approx(shape_size):
		return
	var box := BoxMesh.new()
	box.size = shape_size
	preview.mesh = box
	preview.position.y = col.position.y

func get_entry_position() -> Vector3:
	var marker := get_node_or_null("HidePosition") as Marker3D
	return marker.global_position if marker else global_position

func get_entry_rotation_y() -> float:
	var marker := get_node_or_null("HidePosition") as Marker3D
	return marker.global_rotation.y if marker else global_rotation.y
