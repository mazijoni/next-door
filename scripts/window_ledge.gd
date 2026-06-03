@tool
class_name WindowLedge
extends Node3D

@export var has_glass: bool = true:
	set(v):
		has_glass = v
		_update_glass()

var _glass_broken := false

func _ready() -> void:
	_update_glass()
	if Engine.is_editor_hint():
		return
	add_to_group("window_ledge")
	if has_glass:
		var detector := get_node_or_null("Glass/BreakDetector") as Area3D
		if detector:
			detector.body_entered.connect(_on_impact)

func _update_glass() -> void:
	var glass := get_node_or_null("Glass") as Node3D
	if not glass:
		return
	glass.visible = has_glass
	var col := glass.get_node_or_null("GlassBody/CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = not has_glass
	var det_col := glass.get_node_or_null("BreakDetector/CollisionShape3D") as CollisionShape3D
	if det_col:
		det_col.disabled = not has_glass

func can_climb() -> bool:
	return not has_glass or _glass_broken

func get_climb_top(from_global: Vector3) -> Vector3:
	var m := get_node_or_null("LedgeTop") as Marker3D
	var lp := m.position if m else Vector3(0.0, 0.2, -0.15)
	if to_local(from_global).z < 0:
		lp.z = -lp.z
	return to_global(lp)

func get_climb_exit(from_global: Vector3) -> Vector3:
	var m := get_node_or_null("ClimbExit") as Marker3D
	var lp := m.position if m else Vector3(0.0, 0.0, -0.8)
	if to_local(from_global).z < 0:
		lp.z = -lp.z
	return to_global(lp)

func interact(_from: Vector3, _crouch: bool = false) -> void:
	pass

func _on_impact(body: Node3D) -> void:
	if body.is_in_group("thrown_item"):
		_break_glass()

func _break_glass() -> void:
	if _glass_broken:
		return
	_glass_broken = true
	var glass := get_node_or_null("Glass") as Node3D
	if not glass:
		return
	glass.visible = false
	var col := glass.get_node_or_null("GlassBody/CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = true
	var det_col := glass.get_node_or_null("BreakDetector/CollisionShape3D") as CollisionShape3D
	if det_col:
		det_col.disabled = true
