class_name Player
extends CharacterBody3D

const WALK_SPEED := 4.0
const SPRINT_SPEED := 8.0
const SNEAK_SPEED := 1.5
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003

const NORMAL_CAM_Y := 1.6
const SNEAK_CAM_Y := 0.75
const CRAWL_CAM_Y := 0.25

const NORMAL_COL_HEIGHT := 1.8
const SNEAK_COL_HEIGHT := 1.0
const CRAWL_COL_HEIGHT := 0.7

const NORMAL_COL_Y := 0.9
const SNEAK_COL_Y := 0.5
const CRAWL_COL_Y := 0.35

const THROW_SPEED := 12.0

const SLOT_COUNT := 4
const SLOT_SIZE := 64.0
const SLOT_GAP := 4.0

@onready var head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _death_screen: CanvasLayer = $DeathScreen
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var ceiling_ray: RayCast3D = $CeilingRay
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var cross_h: ColorRect = $HUD/CrossH
@onready var cross_v: ColorRect = $HUD/CrossV
@onready var _hand: Node3D = $Head/Camera3D/HandPosition

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _aimed_interactable: Node = null
var _hiding_spot: HidingSpot = null
var _pre_hide_position: Vector3
var _transitioning := false
var _transition_target: Vector3
var _transition_posture := HidingSpot.Type.STANDING
var _saved_collision_layer: int
var _saved_collision_mask: int
var _camera_tween: Tween

var _inventory: Array = []
var _selected_slot := 0
var _climbing := false
var _climb_exit: Vector3
var _rmb_held_time := 0.0
var _rmb_pressed := false
var _spawn_position: Vector3
var _dead := false

@onready var _slot_panels: Array[Panel] = [
	$HUD/InventoryBar/Slot0,
	$HUD/InventoryBar/Slot1,
	$HUD/InventoryBar/Slot2,
	$HUD/InventoryBar/Slot3,
]
@onready var _slot_icons: Array[TextureRect] = [
	$HUD/InventoryBar/Slot0/Icon,
	$HUD/InventoryBar/Slot1/Icon,
	$HUD/InventoryBar/Slot2/Icon,
	$HUD/InventoryBar/Slot3/Icon,
]

func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ray.add_exception(self)
	ray.collide_with_areas = true
	ceiling_ray.add_exception(self)
	_update_inventory_hud()

func _update_inventory_hud() -> void:
	for i in SLOT_COUNT:
		var panel := _slot_panels[i]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		style.border_width_left = 2; style.border_width_right = 2
		style.border_width_top = 2; style.border_width_bottom = 2
		style.border_color = Color(0.8, 0.8, 0.2) if i == _selected_slot else Color(0.5, 0.5, 0.5)
		panel.add_theme_stylebox_override("panel", style)
		var item: Item = _inventory[i] if i < _inventory.size() else null
		_slot_icons[i].texture = item.icon if item else null

func _pick_up_item(item: Item) -> void:
	if _inventory.size() >= SLOT_COUNT:
		return
	item.freeze = true
	item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	item.collision_layer = 0
	item.collision_mask = 0
	var area := item.get_node_or_null("Area3D") as Area3D
	if area:
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = false
	item.get_parent().remove_child(item)
	_hand.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	_inventory.append(item)
	_update_inventory_hud()
	_update_held_item()

func _update_held_item() -> void:
	for i in _inventory.size():
		(_inventory[i] as Item).visible = (i == _selected_slot)

func _find_interactable(collider: Node) -> Node:
	var node := collider
	while node:
		if node is HidingSpot or node.has_method("interact"):
			return node
		node = node.get_parent()
	return null

func _process(delta: float) -> void:
	if _rmb_pressed:
		_rmb_held_time += delta
	var interactable: Node = null
	if ray.is_colliding():
		interactable = _find_interactable(ray.get_collider())
	if interactable != _aimed_interactable:
		_aimed_interactable = interactable
		_set_crosshair(_aimed_interactable != null)

func _set_crosshair(interactable: bool) -> void:
	var half_len := 10.0 if interactable else 8.0
	var half_thick := 2.5 if interactable else 1.0
	cross_h.offset_left   = -half_len;   cross_h.offset_right  = half_len
	cross_h.offset_top    = -half_thick; cross_h.offset_bottom = half_thick
	cross_v.offset_left   = -half_thick; cross_v.offset_right  = half_thick
	cross_v.offset_top    = -half_len;   cross_v.offset_bottom = half_len

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event is InputEventMouseMotion:
		if _camera_tween:
			_camera_tween.kill()
			_camera_tween = null
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -PI / 2.0, PI / 2.0)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("interact"):
		if _hiding_spot:
			_stop_hiding()
		elif not _transitioning and _aimed_interactable is HidingSpot:
			_start_hiding(_aimed_interactable as HidingSpot)
		elif not _hiding_spot and not _transitioning and _aimed_interactable is Item:
			var item := _aimed_interactable as Item
			if not item.can_pick_up():
				item.interact(global_position, Input.is_action_pressed("sneak"))
			if item.can_pick_up():
				_pick_up_item(item)
		elif not _hiding_spot and not _transitioning and _aimed_interactable != null:
			_aimed_interactable.interact(global_position, Input.is_action_pressed("sneak"))

	for i in SLOT_COUNT:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			_selected_slot = i
			_update_inventory_hud()
			_update_held_item()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not _transitioning and not _hiding_spot:
				var sel: Item = _inventory[_selected_slot] if _selected_slot < _inventory.size() else null
				if sel is Chair and _aimed_interactable != null and _aimed_interactable.has_method("set_locked") and not _aimed_interactable.get("locked") and _aimed_interactable.call("can_be_locked"):
					_place_chair_against_door(sel as Chair, _aimed_interactable)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if not _transitioning and not _hiding_spot:
					_rmb_pressed = true
					_rmb_held_time = 0.0
			else:
				if _rmb_pressed:
					_rmb_pressed = false
					if _rmb_held_time >= 0.3:
						_throw_item()
					else:
						_drop_item()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_selected_slot = (_selected_slot - 1 + SLOT_COUNT) % SLOT_COUNT
			_update_inventory_hud()
			_update_held_item()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_selected_slot = (_selected_slot + 1) % SLOT_COUNT
			_update_inventory_hud()
			_update_held_item()

func _start_hiding(spot: HidingSpot) -> void:
	_pre_hide_position = global_position
	_hiding_spot = spot
	spot.is_occupied = true
	_transitioning = true
	_transition_target = spot.get_entry_position()
	_transition_posture = spot.type
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_camera_tween.tween_property(self, "rotation:y", spot.get_entry_rotation_y(), 0.4)

func _stop_hiding() -> void:
	_hiding_spot.is_occupied = false
	_hiding_spot = null
	_transitioning = true
	_transition_target = _pre_hide_position
	_transition_posture = HidingSpot.Type.STANDING

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _transitioning:
		global_position = global_position.lerp(_transition_target, delta * 10.0)
		if global_position.distance_to(_transition_target) < 0.05:
			global_position = _transition_target
			if _climbing:
				_climbing = false
				_transition_target = _climb_exit
			else:
				_transitioning = false
				if not _hiding_spot:
					collision_layer = _saved_collision_layer
					collision_mask = _saved_collision_mask
		_update_body_shape(_transition_posture, delta)
		return

	if _hiding_spot:
		_update_body_shape(_hiding_spot.type, delta)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		var ledge := _nearest_climbable_ledge()
		if ledge:
			_start_climbing(ledge)
		else:
			velocity.y = JUMP_VELOCITY

	var ceiling_blocked := ceiling_ray.is_colliding() and is_on_floor()
	var sneaking := Input.is_action_pressed("sneak")
	var sprinting := Input.is_action_pressed("sprint") and not sneaking and not ceiling_blocked
	var speed := SNEAK_SPEED if sneaking else SPRINT_SPEED if sprinting else WALK_SPEED
	_update_body_shape(HidingSpot.Type.CROUCHING if (sneaking or ceiling_blocked) else HidingSpot.Type.STANDING, delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()

	if global_position.y < -10.0:
		die()

func die(killer_pos := Vector3.ZERO) -> void:
	if _dead:
		return
	_dead = true
	_death_screen.visible = true
	var to_killer := (killer_pos - global_position)
	to_killer.y = 0.0
	if to_killer.length_squared() > 0.1:
		var target_y := atan2(-to_killer.x, -to_killer.z)
		var cam_tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		cam_tween.tween_property(self, "rotation:y", target_y, 0.25)
	await get_tree().create_timer(3.0).timeout
	_do_respawn()
	_death_screen.visible = false
	_dead = false

func _do_respawn() -> void:
	if _hiding_spot:
		_hiding_spot.is_occupied = false
		_hiding_spot = null
	_transitioning = false
	_climbing = false
	_rmb_pressed = false
	collision_layer = 1
	collision_mask = 3
	velocity = Vector3.ZERO
	global_position = _spawn_position

func _drop_item() -> void:
	if _selected_slot >= _inventory.size():
		return
	var item: Item = _inventory[_selected_slot]
	_hand.remove_child(item)
	get_tree().current_scene.add_child(item)
	item.global_position = global_position + Vector3.UP * 1.0 + (-transform.basis.z) * 0.8
	item.freeze = false
	item.collision_layer = 2
	item.collision_mask = 3
	var area := item.get_node_or_null("Area3D") as Area3D
	if area:
		area.collision_layer = 1
		area.collision_mask = 0
		area.monitoring = true
		area.monitorable = true
	item.linear_velocity = Vector3.ZERO
	_inventory.remove_at(_selected_slot)
	_selected_slot = clamp(_selected_slot, 0, max(0, _inventory.size() - 1))
	_update_inventory_hud()
	_update_held_item()

func _place_chair_against_door(chair: Chair, door: Node3D) -> void:
	_hand.remove_child(chair)
	get_tree().current_scene.add_child(chair)

	# Use the door's actual surface normal so the chair faces square to the door
	# regardless of where the player is standing relative to the hinge.
	var door_normal := door.global_transform.basis.z
	if (global_position - door.global_position).dot(door_normal) < 0.0:
		door_normal = -door_normal
	door_normal.y = 0.0
	door_normal = door_normal.normalized()

	# For double doors place the chair between the two handles; otherwise at this door's handle.
	var handle_world: Vector3
	var partner: Node3D = door.call("get_partner")
	if partner:
		var handle_a := door.global_transform * Vector3(0.84, 0.0, 0.0)
		var handle_b := partner.global_transform * Vector3(0.84, 0.0, 0.0)
		handle_world = (handle_a + handle_b) * 0.5
	else:
		handle_world = door.global_transform * Vector3(0.84, 0.0, 0.0)
	handle_world.y = global_position.y

	# Offset toward the hinge using the door's own X axis — consistent from both sides.
	var toward_hinge := -door.global_transform.basis.x.normalized()
	var chair_pos := handle_world + door_normal * 0.6 + toward_hinge * 0.2
	chair.global_position = chair_pos
	chair.rotation = Vector3(deg_to_rad(-20.0), atan2(door_normal.x, door_normal.z), 0.0)

	chair.freeze = true
	chair.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	chair.collision_layer = 2
	chair.collision_mask = 3
	var area := chair.get_node_or_null("Area3D") as Area3D
	if area:
		area.collision_layer = 1
		area.collision_mask = 0
		area.monitoring = true
		area.monitorable = true

	_inventory.remove_at(_selected_slot)
	_selected_slot = clamp(_selected_slot, 0, max(0, _inventory.size() - 1))
	_update_inventory_hud()
	_update_held_item()
	chair.place_against_door(door)

func _throw_item() -> void:
	if _selected_slot >= _inventory.size():
		return
	var item: Item = _inventory[_selected_slot]
	_hand.remove_child(item)
	get_tree().current_scene.add_child(item)
	item.global_position = _camera.global_position + (-_camera.global_transform.basis.z) * 0.5
	item.freeze = false
	item.collision_layer = 2
	item.collision_mask = 3
	var area := item.get_node_or_null("Area3D") as Area3D
	if area:
		area.collision_layer = 1
		area.collision_mask = 0
		area.monitoring = true
		area.monitorable = true
	item.linear_velocity = -_camera.global_transform.basis.z * THROW_SPEED
	_inventory.remove_at(_selected_slot)
	_selected_slot = clamp(_selected_slot, 0, max(0, _inventory.size() - 1))
	_update_inventory_hud()
	_update_held_item()

func _nearest_climbable_ledge() -> WindowLedge:
	var forward := -transform.basis.z
	for node in get_tree().get_nodes_in_group("window_ledge"):
		var ledge := node as WindowLedge
		if not ledge or not ledge.can_climb():
			continue
		if global_position.distance_to(ledge.global_position) >= 1.5:
			continue
		var to_ledge := (ledge.global_position - global_position).normalized()
		if forward.dot(to_ledge) > 0.3:
			return ledge
	return null

func _start_climbing(ledge: WindowLedge) -> void:
	velocity = Vector3.ZERO
	_climbing = true
	_transitioning = true
	_transition_target = ledge.get_climb_top(global_position)
	_climb_exit = ledge.get_climb_exit(global_position)
	_transition_posture = HidingSpot.Type.STANDING
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	collision_layer = 0
	collision_mask = 0

func _update_body_shape(posture: HidingSpot.Type, delta: float) -> void:
	var target_cam_y: float
	var target_col_height: float
	var target_col_y: float
	match posture:
		HidingSpot.Type.STANDING:
			target_cam_y = NORMAL_CAM_Y
			target_col_height = NORMAL_COL_HEIGHT
			target_col_y = NORMAL_COL_Y
		HidingSpot.Type.CROUCHING:
			target_cam_y = SNEAK_CAM_Y
			target_col_height = SNEAK_COL_HEIGHT
			target_col_y = SNEAK_COL_Y
		HidingSpot.Type.CRAWLING:
			target_cam_y = CRAWL_CAM_Y
			target_col_height = CRAWL_COL_HEIGHT
			target_col_y = CRAWL_COL_Y
	head.position.y = lerpf(head.position.y, target_cam_y, delta * 10.0)
	var capsule := collision.shape as CapsuleShape3D
	capsule.height = lerpf(capsule.height, target_col_height, delta * 10.0)
	collision.position.y = lerpf(collision.position.y, target_col_y, delta * 10.0)
