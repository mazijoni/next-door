class_name ThrownItem
extends RigidBody3D

func _ready() -> void:
	add_to_group("thrown_item")
	get_tree().create_timer(30.0).timeout.connect(queue_free)
