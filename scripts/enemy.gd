class_name Enemy
extends CharacterBody3D

const SPEED := 3.0
const STUNNED_SPEED := 1.0
const KILL_DISTANCE := 0.8

enum State { CHASING, STUNNED, FALLEN }

@onready var _visual: Node3D = $Visual

var state := State.CHASING
var _stun_timer := 0.0
var _hit_cooldown := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _player: Player = null

func _ready() -> void:
	call_deferred("_find_player")
	var upper := get_node_or_null("UpperHitbox") as Area3D
	if upper:
		upper.body_entered.connect(_on_upper_hit)
	var lower := get_node_or_null("LowerHitbox") as Area3D
	if lower:
		lower.body_entered.connect(_on_lower_hit)

func _find_player() -> void:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		_player = nodes[0] as Player

func _physics_process(delta: float) -> void:
	if state == State.FALLEN:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta

	if state == State.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			state = State.CHASING

	if _player:
		var diff3d := _player.global_position - global_position
		var diff := diff3d
		diff.y = 0.0
		var dist := diff.length()

		if diff3d.length() < KILL_DISTANCE and state == State.CHASING:
			_player.die(global_position)
		elif dist > 0.01:
			var speed := STUNNED_SPEED if state == State.STUNNED else SPEED
			var dir := diff.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			rotation.y = atan2(-dir.x, -dir.z)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()

func _on_upper_hit(body: Node3D) -> void:
	if not body.is_in_group("thrown_item") or state == State.FALLEN or _hit_cooldown > 0.0:
		return
	var rb := body as RigidBody3D
	if rb and rb.linear_velocity.length() < 1.5:
		return
	_hit_cooldown = 0.5
	_bounce_item(body)
	_stun()

func _on_lower_hit(body: Node3D) -> void:
	if not body.is_in_group("thrown_item") or state == State.FALLEN or _hit_cooldown > 0.0:
		return
	var rb := body as RigidBody3D
	var is_resting := rb != null and rb.linear_velocity.length() < 1.5
	if is_resting:
		var item := body as Item
		if item == null or not item.can_trip_enemy or state == State.STUNNED:
			return
	else:
		_bounce_item(body)
	_hit_cooldown = 0.5
	_knockdown()

func _bounce_item(body: Node3D) -> void:
	var rb := body as RigidBody3D
	if not rb:
		return
	var away := (rb.global_position - global_position).normalized()
	away.y = maxf(away.y, 0.3)
	rb.linear_velocity = away.normalized() * rb.linear_velocity.length() * 0.3

func _stun() -> void:
	state = State.STUNNED
	_stun_timer = 2.0

func _knockdown() -> void:
	state = State.FALLEN
	var t1 := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t1.tween_property(_visual, "rotation:x", -PI / 2.0, 0.3)
	await get_tree().create_timer(4.0).timeout
	var t2 := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t2.tween_property(_visual, "rotation:x", 0.0, 0.5)
	await t2.finished
	if state == State.FALLEN:
		state = State.CHASING

func set_target(_pos: Vector3) -> void:
	pass
