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
		var vel := (body as RigidBody3D).linear_velocity if body is RigidBody3D else Vector3.ZERO
		_break_glass(vel)

func _break_glass(impact_velocity: Vector3 = Vector3.ZERO) -> void:
	if _glass_broken:
		return
	_glass_broken = true
	var glass := get_node_or_null("Glass") as Node3D
	if not glass:
		return
	_spawn_shards(glass, impact_velocity)
	glass.visible = false
	var col := glass.get_node_or_null("GlassBody/CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = true
	var det_col := glass.get_node_or_null("BreakDetector/CollisionShape3D") as CollisionShape3D
	if det_col:
		det_col.disabled = true

func _spawn_shards(glass: Node3D, impact_velocity: Vector3) -> void:
	const GLASS_W := 0.85
	const GLASS_H := 1.5
	const GLASS_D := 0.04
	const COLS := 4
	const ROWS := 5

	var impact_dir := impact_velocity.normalized() if impact_velocity.length() > 0.5 \
		else glass.global_transform.basis.z

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.92, 1.0, 0.55)
	mat.roughness = 0.0
	mat.metallic = 0.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Build jittered grid: interior corners are randomly offset so each
	# quad becomes an irregular polygon, giving a natural fracture look.
	var jx := (GLASS_W / COLS) * 0.32
	var jy := (GLASS_H / ROWS) * 0.32
	var pts := []
	for row in ROWS + 1:
		for col in COLS + 1:
			var x := float(col) / COLS * GLASS_W - GLASS_W * 0.5
			var y := float(row) / ROWS * GLASS_H - GLASS_H * 0.5
			if col > 0 and col < COLS and row > 0 and row < ROWS:
				x += randf_range(-jx, jx)
				y += randf_range(-jy, jy)
			pts.append(Vector2(x, y))

	for row in ROWS:
		for col in COLS:
			var bl: Vector2 = pts[row * (COLS + 1) + col]
			var br: Vector2 = pts[row * (COLS + 1) + col + 1]
			var tr: Vector2 = pts[(row + 1) * (COLS + 1) + col + 1]
			var tl: Vector2 = pts[(row + 1) * (COLS + 1) + col]

			# Shard origin at centroid so mesh vertices are relative to it.
			var cx := (bl.x + br.x + tr.x + tl.x) * 0.25
			var cy := (bl.y + br.y + tr.y + tl.y) * 0.25
			var v0 := Vector3(bl.x - cx, bl.y - cy, 0.0)
			var v1 := Vector3(br.x - cx, br.y - cy, 0.0)
			var v2 := Vector3(tr.x - cx, tr.y - cy, 0.0)
			var v3 := Vector3(tl.x - cx, tl.y - cy, 0.0)

			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_normal(Vector3.BACK)
			st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
			st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)

			var shard := RigidBody3D.new()
			shard.collision_layer = 0
			shard.collision_mask = 1

			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat
			shard.add_child(mi)

			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(abs(br.x - bl.x), abs(tr.y - br.y), GLASS_D)
			cs.shape = bs
			shard.add_child(cs)

			get_tree().current_scene.add_child(shard)
			shard.global_transform = Transform3D(
				glass.global_transform.basis,
				glass.global_transform * Vector3(cx, cy, 0.0)
			)

			var spread := Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 2.0), randf_range(-1.5, 1.5))
			shard.linear_velocity = impact_dir * randf_range(1.5, 4.5) + spread
			shard.angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))

			get_tree().create_timer(4.0).timeout.connect(shard.queue_free)
