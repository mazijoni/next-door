class_name Enemy
extends CharacterBody3D

const PATROL_SPEED     := 2.0
const SPEED            := 3.5
const PREDICT_SPEED    := 4.2
const KILL_DISTANCE    := 0.8
const DETECTION_RANGE  := 12.0
const FOV_HALF_DEG     := 65.0
const PREDICT_TIME     := 1.5    # seconds of player movement to project
const PREDICT_MAX_DIST := 7.0    # metres, hard cap on projection
const PREDICT_TIMEOUT  := 10.0   # hard-cap safety: give up predicting after this long
const SEARCH_TIMEOUT   := 14.0   # seconds to spend searching before resuming patrol
const PATROL_ARRIVE    := 1.5    # 2-D metres to consider a patrol waypoint reached
const PREDICT_ARRIVE   := 1.0
const SEARCH_ARRIVE    := 1.5
const MEMORY_BLEND     := 0.4
const SIGHT_CONFIRM      := 0.2   # LOS flicker guard — brief raycast misses
const TRACK_MEMORY       := 5.0   # extra secs enemy chases last-seen spot before predicting
const RELAY_RUN_SPEED    := 2.5   # player must have been moving faster than this to relay
const MAX_RELAYS         := 2     # max number of relay prediction steps when player runs
const SCAN_SPEED         := 1.2   # rad/s rotation while scanning in search mode
const STUCK_SAMPLE_SECS  := 1.5   # how often to sample position for stuck detection
const STUCK_MIN_TRAVEL   := 0.5   # metres — must travel this far per sample or it's stuck
const STUCK_LIMIT_PRED   := 3.5   # accumulated stuck-secs before giving up on a prediction
const STUCK_LIMIT_SRCH   := 4.5   # accumulated stuck-secs before giving up on a search
const SEARCH_SCAN_TIME   := 1.4   # seconds to scan at each search waypoint (sweeps left→right)
const HEAR_RANGE_WALK    := 4.0   # metres, walking footstep audible range
const HEAR_RANGE_SPRINT  := 9.0   # metres, sprinting footstep audible range
const HEAR_NOISE_RADIUS  := 2.5   # random offset so enemy only pinpoints general area
const DOOR_OPEN_DIST     := 1.6   # metres — open door when this close
const DOOR_CLOSE_DIST    := 2.5   # metres past door before closing it (patrol only)
const CHAIR_REACH_DIST   := 1.2   # metres — close enough to remove a bracing chair

enum State { PATROLLING, ALERT, PREDICTING, SEARCHING, STUNNED, FALLEN, UNBLOCKING }

@onready var _visual:   Node3D            = $Visual
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@export var patrol_points: Array[Node3D] = []

var state         := State.PATROLLING
var _stun_timer   := 0.0
var _hit_cooldown := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _player: Player = null

var _last_seen_position:   Vector3
var _player_last_velocity: Vector3
var _predicted_position:   Vector3
var _search_timer    := 0.0
var _search_points:  Array[Vector3] = []
var _search_pt_idx:  int   = 0
var _search_scan_t:  float = 0.0
var _predict_timer   := 0.0
var _patrol_index    := 0
var _sight_lost_time  := 0.0  # how long we've continuously failed to see the player
var _stuck_timer      := 0.0  # accumulated "not making progress" time
var _stuck_check_t    := 0.0  # time since last position sample
var _stuck_check_pos  := Vector3.ZERO  # position at last sample
var _wall_push_timer  := 0.0           # time pressing into a wall while slow
var _predict_relay   := 0              # how many relay steps used in current prediction chain

var _has_memory      := false
var _memory_position: Vector3

var _footstep_player: AudioStreamPlayer3D
var _footstep_sounds: Array = []
var _footstep_timer  := 0.0
var _hear_cooldown   := 0.0
var _audio_occlusion_db := 0.0

var _last_opened_door: Node3D = null
var _door_check_t:     float  = 0.0
var _chair_to_remove:  Node3D = null
var _blocking_door:    Node3D = null
var _return_state:     State  = State.PATROLLING
var _blocked_doors:    Array[Node3D] = []

@export var debug_enabled         := false
@export var hearing_debug_enabled := false
@export var ghost_enabled         := false
var _debug_step_pos:      Vector3 = Vector3.ZERO
var _debug_step_heard:    bool    = false
var _debug_step_age:      float   = 1e9
var _debug_occluded:        bool    = false
var _debug_occlude_is_floor: bool  = false
var _debug_occlusion_hit:   Vector3 = Vector3.ZERO
var _debug_label:          Label3D         = null
var _debug_path_instance:  MeshInstance3D  = null
var _debug_path_mesh:      ImmediateMesh   = null
var _debug_shapes_instance: MeshInstance3D = null
var _debug_shapes_mesh:    ImmediateMesh   = null
var _ghost:                MeshInstance3D  = null

# ---------------------------------------------------------------------------

func _ready() -> void:
	floor_snap_length = 0.4
	floor_max_angle   = deg_to_rad(55.0)
	call_deferred("_find_player")
	_setup_debug()
	var upper := get_node_or_null("UpperHitbox") as Area3D
	if upper:
		upper.body_entered.connect(_on_upper_hit)
	var lower := get_node_or_null("LowerHitbox") as Area3D
	if lower:
		lower.body_entered.connect(_on_lower_hit)
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	_footstep_player.unit_size = 1.5
	_footstep_player.max_distance = 20.0
	_footstep_player.volume_db = 8.0
	add_child(_footstep_player)
	for i in range(1, 22):
		var s: AudioStream = load("res://audio/FootSteps/Wood/Steps_wood-%03d.ogg" % i)
		if s:
			_footstep_sounds.append(s)

func _find_player() -> void:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		_player = nodes[0] as Player
		_player.footstep_made.connect(_on_player_footstep)

# --- Footsteps & hearing ---------------------------------------------------

func _update_enemy_footsteps(delta: float) -> void:
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if _footstep_sounds.is_empty() or h_speed < 0.5 or state in [State.STUNNED, State.FALLEN]:
		_footstep_timer = 0.0
		return
	var interval: float = clamp(0.55 * (PATROL_SPEED / h_speed), 0.3, 0.7)
	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		_footstep_player.stream = _footstep_sounds[randi() % _footstep_sounds.size()]
		_footstep_player.pitch_scale = randf_range(0.85, 1.05)
		_footstep_player.play()

func _update_audio_occlusion(delta: float) -> void:
	var target_db := 0.0
	_debug_occluded = false
	_debug_occlude_is_floor = false
	if _player and not _player._dead:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 1.2,
			_player.global_position + Vector3.UP * 1.2
		)
		query.exclude        = [get_rid(), _player.get_rid()]
		query.collision_mask = 1
		var result := space.intersect_ray(query)
		if not result.is_empty():
			target_db              = -14.0
			_debug_occluded        = true
			_debug_occlusion_hit   = result.get("position")
			_debug_occlude_is_floor = abs((result.get("normal") as Vector3).y) >= 0.5
	_audio_occlusion_db = lerpf(_audio_occlusion_db, target_db, delta * 6.0)
	_footstep_player.volume_db = 8.0 + _audio_occlusion_db

func _on_player_footstep(pos: Vector3, loud: bool) -> void:
	var range_val := HEAR_RANGE_SPRINT if loud else HEAR_RANGE_WALK
	# Walls muffle the player's footsteps — only horizontal-normal hits count as walls
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.2,
		pos + Vector3.UP * 1.2
	)
	query.exclude        = [get_rid(), _player.get_rid()]
	query.collision_mask = 1
	var occlude_result := space.intersect_ray(query)
	if not occlude_result.is_empty():
		range_val *= 0.35
	var in_range  := global_position.distance_to(pos) <= range_val
	var can_react := _hear_cooldown <= 0.0 and state not in [State.ALERT, State.STUNNED, State.FALLEN]
	_debug_step_pos   = pos
	_debug_step_heard = in_range and can_react
	_debug_step_age   = 0.0
	if not in_range or not can_react:
		return
	var angle := randf() * TAU
	var dist  := randf() * HEAR_NOISE_RADIUS
	var noise := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	_last_seen_position   = _snap_to_navmesh(pos + noise)
	_player_last_velocity = Vector3.ZERO
	_hear_cooldown        = 2.0
	_begin_searching()

# --- Door interaction ------------------------------------------------------

func _try_open_door_ahead() -> void:
	if state == State.UNBLOCKING:
		return
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for node in get_tree().get_nodes_in_group("door"):
		var door := node as Node3D
		if not door or door.get("state") == 2:
			continue
		if global_position.distance_to(door.global_position) > DOOR_OPEN_DIST:
			continue
		var to_door := Vector3(
			door.global_position.x - global_position.x,
			0.0,
			door.global_position.z - global_position.z)
		if to_door.length_squared() < 0.001:
			continue
		if forward.dot(to_door.normalized()) < 0.1:
			continue
		if door.get("locked"):
			if not (door in _blocked_doors):
				_handle_braced_door(door)
			# Whether newly handled or already known blocked, stop here.
			break
		# Door is unlocked — if it was previously blocked it's now cleared.
		_blocked_doors.erase(door)
		door.call("interact", global_position)
		if state == State.PATROLLING:
			_last_opened_door = door
		break

func _try_close_passed_door() -> void:
	if not is_instance_valid(_last_opened_door):
		_last_opened_door = null
		return
	if global_position.distance_to(_last_opened_door.global_position) < DOOR_CLOSE_DIST:
		return
	if _last_opened_door.get("state") != 0:
		_last_opened_door.call("interact", global_position)
	_last_opened_door = null

# Called when a door is locked and not already in _blocked_doors.
# Finds the bracing chair, checks which side it's on, and either enters
# UNBLOCKING (chair on our side) or marks the door as impassable (far side).
func _handle_braced_door(door: Node3D) -> void:
	var bracing_chair: Chair = null
	for node in get_tree().get_nodes_in_group("chair"):
		var c := node as Chair
		if c == null or c.can_pick_up():
			continue
		if c.get("_bracing_door") != door:
			continue
		bracing_chair = c
		break

	if bracing_chair == null:
		# Locked by game logic, no chair — remember and reroute.
		_blocked_doors.append(door)
		_reroute_around_door(door)
		return

	# Positive/negative Z in door-local space corresponds to each face.
	var chair_z := door.to_local(bracing_chair.global_position).z
	var enemy_z := door.to_local(global_position).z

	if signf(chair_z) == signf(enemy_z):
		# Chair is on our side — go remove it.
		_chair_to_remove = bracing_chair
		_blocking_door   = door
		_return_state    = state
		state            = State.UNBLOCKING
	else:
		# Chair is on the far side — can't reach it, remember this route is blocked.
		_blocked_doors.append(door)
		_reroute_around_door(door)

# Skip the current waypoint/patrol point so the enemy naturally tries a different route.
func _reroute_around_door(_door: Node3D) -> void:
	match state:
		State.SEARCHING:
			_search_pt_idx += 1
			_reset_stuck()
		State.PATROLLING:
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
		# ALERT / PREDICTING: let existing movement + stuck-detection handle the detour.

# Navigate to the bracing chair and remove it, then return to the prior state.
func _update_unblocking(delta: float) -> void:
	# Player spotted — drop the chair task and give chase.
	if _can_see_player():
		_chair_to_remove      = null
		_last_seen_position   = _player.global_position
		_player_last_velocity = _player.velocity
		_sight_lost_time      = 0.0
		state = State.ALERT
		return

	# Chair may have been removed by the player in the meantime.
	if not is_instance_valid(_chair_to_remove) or _chair_to_remove.can_pick_up():
		_chair_to_remove = null
		_blocking_door   = null
		_reset_stuck()
		state = _return_state
		return

	nav_agent.target_position = _chair_to_remove.global_position

	if global_position.distance_to(_chair_to_remove.global_position) < CHAIR_REACH_DIST:
		_chair_to_remove.call("interact", global_position)
		_chair_to_remove = null
		_blocking_door   = null
		_reset_stuck()
		state = _return_state
		return

	_update_stuck_timer(delta)
	if _stuck_timer >= STUCK_LIMIT_SRCH:
		# Couldn't reach the chair — treat the door as blocked and move on.
		if is_instance_valid(_blocking_door) and not (_blocking_door in _blocked_doors):
			_blocked_doors.append(_blocking_door)
		_chair_to_remove = null
		_blocking_door   = null
		_reset_stuck()
		state = _return_state
		return

	_move_toward_nav_target(SPEED, delta)

# --- Detection -------------------------------------------------------------

func _can_see_player() -> bool:
	if not _player or _player._dead:
		return false
	if _player.collision_layer == 0:
		return false
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist > DETECTION_RANGE:
		return false
	if state != State.ALERT:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		var dir2d := Vector3(to_player.x, 0.0, to_player.z)
		if forward.length_squared() > 0.001 and dir2d.length_squared() > 0.001:
			if forward.normalized().dot(dir2d.normalized()) < cos(deg_to_rad(FOV_HALF_DEG)):
				return false
	# In ALERT the enemy is actively chasing — allow cross-floor tracking so it
	# can follow the player up/down stairs.  The FOV cone is already disabled in
	# ALERT for the same reason.  In all other states the floor check prevents
	# initial detection through solid ceilings.
	if state != State.ALERT and _on_different_floors():
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5,
		_player.global_position + Vector3.UP * 1.2
	)
	query.exclude        = [get_rid()]
	query.collision_mask = 0xFFFFFFFF
	var result := space.intersect_ray(query)
	return result.is_empty() or result.get("collider") == _player

# --- Main loop -------------------------------------------------------------

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
	if _hear_cooldown > 0.0:
		_hear_cooldown -= delta

	if state == State.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			state = State.PATROLLING
		velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
		move_and_slide()
		_update_debug(0.0, delta)
		return

	match state:
		State.PATROLLING:  _update_patrol(delta)
		State.ALERT:       _update_alert(delta)
		State.PREDICTING:  _update_predicting(delta)
		State.SEARCHING:   _update_searching(delta)
		State.UNBLOCKING:  _update_unblocking(delta)

	move_and_slide()
	_update_enemy_footsteps(delta)
	_update_audio_occlusion(delta)
	_door_check_t += delta
	if _door_check_t >= 0.2:
		_door_check_t = 0.0
		_try_open_door_ahead()
		if state == State.PATROLLING:
			_try_close_passed_door()
	_try_wall_push(delta)
	_update_debug(_player.global_position.distance_to(global_position) if _player else 0.0, delta)

# --- State behaviours ------------------------------------------------------

func _update_patrol(delta: float) -> void:
	if _can_see_player():
		_last_seen_position   = _player.global_position
		_player_last_velocity = _player.velocity
		_sight_lost_time      = 0.0
		_last_opened_door     = null
		_blocked_doors.clear()
		state = State.ALERT
		return

	if patrol_points.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var target_pos := patrol_points[_patrol_index].global_position
	nav_agent.target_position = target_pos

	if _flat_dist(global_position, target_pos) < PATROL_ARRIVE or nav_agent.is_navigation_finished():
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		return

	_move_toward_nav_target(PATROL_SPEED, delta)

func _update_alert(delta: float) -> void:
	if not _player:
		state = State.PATROLLING
		return

	if global_position.distance_to(_player.global_position) < KILL_DISTANCE:
		_player.die(global_position)
		return

	if _can_see_player():
		_last_seen_position   = _player.global_position
		_player_last_velocity = _player.velocity
		nav_agent.target_position = _player.global_position
		_move_toward_nav_target(SPEED, delta)
		_sight_lost_time = 0.0
	else:
		# Keep charging toward (and past) the last-seen position so the enemy
		# doesn't freeze in place after arriving there while TRACK_MEMORY is still
		# ticking.  Push the nav target 3 m beyond in the player's last direction.
		_sight_lost_time += delta
		var vel_flat := Vector3(_player_last_velocity.x, 0.0, _player_last_velocity.z)
		var chase_target: Vector3
		if vel_flat.length_squared() > 0.3:
			chase_target = _last_seen_position + vel_flat.normalized() * 3.0
		else:
			chase_target = _last_seen_position
		nav_agent.target_position = _snap_to_navmesh(chase_target)
		_move_toward_nav_target(SPEED, delta)
		if _sight_lost_time >= SIGHT_CONFIRM + TRACK_MEMORY:
			_begin_predicting()

func _begin_predicting() -> void:
	_predict_relay = 0
	_do_prediction_step()

# Shared by the initial prediction and each relay step.  Advances the
# predicted position one step further along the player's last movement vector.
func _do_prediction_step() -> void:
	var vel_flat := Vector3(_player_last_velocity.x, 0.0, _player_last_velocity.z)
	var raw_target: Vector3
	if vel_flat.length_squared() > 1.0:
		var dist := minf(vel_flat.length() * PREDICT_TIME, PREDICT_MAX_DIST)
		raw_target = _last_seen_position + vel_flat.normalized() * dist
	else:
		raw_target = _last_seen_position
	# Blend memory only on the first step — relays already track the right direction.
	if _has_memory and _predict_relay == 0:
		raw_target = raw_target.lerp(_memory_position, MEMORY_BLEND)
	_predicted_position       = _snap_to_navmesh(raw_target)
	nav_agent.target_position = _predicted_position
	_predict_timer            = 0.0
	_reset_stuck()
	state = State.PREDICTING

func _update_predicting(delta: float) -> void:
	_predict_timer += delta
	nav_agent.target_position = _predicted_position

	if _can_see_player():
		_last_seen_position   = _player.global_position
		_player_last_velocity = _player.velocity
		state = State.ALERT
		return

	# Arrived at predicted spot.  If the player was clearly running, chase one
	# more step in the same direction before giving up to search.
	if _flat_dist(global_position, _predicted_position) < PREDICT_ARRIVE:
		var run_spd := Vector2(_player_last_velocity.x, _player_last_velocity.z).length()
		if run_spd >= RELAY_RUN_SPEED and _predict_relay < MAX_RELAYS:
			_predict_relay += 1
			_last_seen_position = _predicted_position   # relay from here
			_do_prediction_step()
		else:
			_begin_searching()
		return

	# Position-sampled stuck detection: only give up if the enemy has genuinely
	# made no progress for STUCK_LIMIT_PRED seconds (not just briefly slowed at
	# a corner).  Hard timeout is the final backstop.
	_update_stuck_timer(delta)
	if _stuck_timer >= STUCK_LIMIT_PRED or _predict_timer >= PREDICT_TIMEOUT:
		_begin_searching()
		return

	_move_toward_nav_target(PREDICT_SPEED, delta)

func _begin_searching() -> void:
	_memory_position = _last_seen_position
	_has_memory      = true
	_search_timer    = SEARCH_TIMEOUT
	_reset_stuck()
	_generate_search_points()
	state = State.SEARCHING

# Build an ordered list of waypoints covering where the player likely went.
# Prioritises nearby doors (likely escape routes) before geometric projections.
func _generate_search_points() -> void:
	_search_points.clear()
	_search_pt_idx = 0
	_search_scan_t = SEARCH_SCAN_TIME

	# Start right at the last known spot.
	_search_points.append(_snap_to_navmesh(_last_seen_position))

	var vel_flat := Vector3(_player_last_velocity.x, 0.0, _player_last_velocity.z)
	var has_vel  := vel_flat.length_squared() > 0.5
	var dir      := vel_flat.normalized() if has_vel else Vector3.ZERO

	# Find the closest nearby door that's in roughly the player's travel direction.
	# A fleeing player almost certainly went through a door, so check it first.
	var best_door_dist := INF
	var best_door_pos  := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("door"):
		var door := node as Node3D
		if not door: continue
		var d := door.global_position.distance_to(_last_seen_position)
		if d > 7.0: continue
		if has_vel:
			var to_door := door.global_position - _last_seen_position
			to_door.y = 0.0
			if to_door.length_squared() > 0.001 and dir.dot(to_door.normalized()) < -0.15:
				continue  # door is mostly behind the player's travel direction
		if d < best_door_dist:
			best_door_dist = d
			best_door_pos  = door.global_position

	if best_door_dist < INF:
		_search_points.append(_snap_to_navmesh(best_door_pos))

	if has_vel:
		# Follow movement direction; skip the close step if we already placed a door there.
		var mid := _snap_to_navmesh(_last_seen_position + dir * 4.5)
		if best_door_dist > 4.0:  # door was far or absent — add the mid-point
			_search_points.append(mid)
		_search_points.append(_snap_to_navmesh(_last_seen_position + dir * 8.0))
		# Randomise which perpendicular side to check so behaviour isn't predictable.
		var perp := Vector3(-dir.z, 0.0, dir.x) * (1.0 if randf() > 0.5 else -1.0)
		_search_points.append(_snap_to_navmesh(_last_seen_position + perp * 3.0))
	else:
		# No velocity — fan out in three random directions.
		var base_angle := randf() * TAU
		for i in 3:
			var ang := base_angle + float(i) / 3.0 * TAU
			_search_points.append(_snap_to_navmesh(_last_seen_position + Vector3(cos(ang) * 4.0, 0.0, sin(ang) * 4.0)))

func _update_searching(delta: float) -> void:
	if _can_see_player():
		_last_seen_position   = _player.global_position
		_player_last_velocity = _player.velocity
		state = State.ALERT
		return

	_search_timer -= delta
	if _search_timer <= 0.0 or _search_pt_idx >= _search_points.size():
		state = State.PATROLLING
		return

	var target := _search_points[_search_pt_idx]
	nav_agent.target_position = target

	if _flat_dist(global_position, target) < SEARCH_ARRIVE:
		# Arrived — sweep left then right like a human checking both sides.
		# sin goes: 0 → -peak → 0 → +peak → 0 over the scan window, giving a
		# natural "look one way, pause, look the other" cadence.
		var scan_frac := _search_scan_t / SEARCH_SCAN_TIME
		rotation.y   += SCAN_SPEED * sin(scan_frac * PI * 2.0) * delta
		velocity.x    = 0.0
		velocity.z    = 0.0
		_search_scan_t -= delta
		if _search_scan_t <= 0.0:
			_search_pt_idx += 1
			_search_scan_t  = SEARCH_SCAN_TIME
			_reset_stuck()
		return

	_update_stuck_timer(delta)
	if _stuck_timer >= STUCK_LIMIT_SRCH:
		_search_pt_idx += 1
		_reset_stuck()
		return

	# Slow to a cautious walk as we close in on each waypoint so the enemy
	# doesn't blow past interesting spots at full sprint speed.
	var dist_to_target  := _flat_dist(global_position, target)
	var cautious_speed  := lerpf(PATROL_SPEED, SPEED, clampf((dist_to_target - SEARCH_ARRIVE) / 3.0, 0.0, 1.0))
	_move_toward_nav_target(cautious_speed, delta)

# --- Movement / utility ----------------------------------------------------

func _move_toward_nav_target(speed: float, delta: float) -> void:
	var next_pos := nav_agent.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0
	if dir.length() > 0.1:
		dir = dir.normalized()
		# Blend in any wall normals from the current frame's slide collisions so
		# the desired direction steers away from the wall instead of fighting it.
		var avoid := Vector3.ZERO
		for i in get_slide_collision_count():
			var n := get_slide_collision(i).get_normal()
			n.y = 0.0
			if n.length_squared() > 0.5:
				avoid += n.normalized()
		if avoid.length_squared() > 0.001:
			dir = (dir + avoid.normalized() * 0.6).normalized()
		velocity.x = lerp(velocity.x, dir.x * speed, minf(delta * 28.0, 1.0))
		velocity.z = lerp(velocity.z, dir.z * speed, minf(delta * 28.0, 1.0))
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(delta * 10.0, 1.0))
	else:
		velocity.x = lerp(velocity.x, 0.0, minf(delta * 8.0, 1.0))
		velocity.z = lerp(velocity.z, 0.0, minf(delta * 8.0, 1.0))

# Fires a short downward ray from each character to find the floor surface they
# are standing on.  Comparing those floor-Y values is more reliable than the
# navmesh closest-point trick because it works even where the navmesh has gaps.
func _on_different_floors() -> bool:
	var space := get_world_3d().direct_space_state
	var eq := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.5,
		global_position + Vector3.DOWN * 3.0
	)
	eq.exclude        = [get_rid()]
	eq.collision_mask = 0xFFFFFFFF
	var e_hit := space.intersect_ray(eq)
	var pq := PhysicsRayQueryParameters3D.create(
		_player.global_position + Vector3.UP * 0.5,
		_player.global_position + Vector3.DOWN * 3.0
	)
	pq.exclude        = [_player.get_rid()]
	pq.collision_mask = 0xFFFFFFFF
	var p_hit := space.intersect_ray(pq)
	if e_hit and p_hit:
		return abs(e_hit["position"].y - p_hit["position"].y) > 1.8
	return abs(_player.global_position.y - global_position.y) > 2.0

# Snaps a world position to the nearest point on the navigation mesh.
# Prevents the enemy from targeting inside-wall positions that the nav agent
# would silently remap, breaking the flat-distance arrival check.
func _snap_to_navmesh(pos: Vector3) -> Vector3:
	var map := nav_agent.get_navigation_map()
	if not map.is_valid():
		return pos
	return NavigationServer3D.map_get_closest_point(map, pos)

# When the enemy is slow AND pressing into a wall, fire a velocity push away
# from the wall so it stops getting wedged on corners and doorframes.
func _try_wall_push(delta: float) -> void:
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if get_slide_collision_count() > 0 and h_speed < 1.0:
		_wall_push_timer += delta
		if _wall_push_timer >= 0.4:
			var push := Vector3.ZERO
			for i in get_slide_collision_count():
				push += get_slide_collision(i).get_normal()
			push.y = 0.0
			if push.length_squared() > 0.001:
				var spd := maxf(SPEED, PREDICT_SPEED)
				velocity.x = push.normalized().x * spd
				velocity.z = push.normalized().z * spd
			_wall_push_timer = 0.0
	else:
		_wall_push_timer = 0.0

# Horizontal-only distance — ignores y so marker height never causes false
# "arrived" triggers.
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Position-sampled stuck detection.  Samples the enemy's position every
# STUCK_SAMPLE_SECS seconds.  If it moved < STUCK_MIN_TRAVEL it adds the
# interval to _stuck_timer; otherwise it resets.  This is immune to brief
# slowdowns at corners that tricked the old velocity-threshold approach.
func _reset_stuck() -> void:
	_stuck_timer     = 0.0
	_stuck_check_t   = 0.0
	_stuck_check_pos = global_position

func _update_stuck_timer(delta: float) -> void:
	_stuck_check_t += delta
	if _stuck_check_t < STUCK_SAMPLE_SECS:
		return
	var traveled := _flat_dist(global_position, _stuck_check_pos)
	_stuck_check_pos = global_position
	_stuck_check_t   = 0.0
	if traveled < STUCK_MIN_TRAVEL:
		_stuck_timer += STUCK_SAMPLE_SECS
	else:
		_stuck_timer = 0.0

# --- Hit reactions ---------------------------------------------------------

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
		state = State.PATROLLING

# --- Debug -----------------------------------------------------------------

func _setup_debug() -> void:
	# Floating text label
	_debug_label = Label3D.new()
	_debug_label.position = Vector3(0, 2.5, 0)
	_debug_label.font_size = 44
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.no_depth_test = true
	_debug_label.render_priority = 2
	_debug_label.visible = debug_enabled
	add_child(_debug_label)

	# Yellow lines: nav path
	_debug_path_mesh = ImmediateMesh.new()
	_debug_path_instance = MeshInstance3D.new()
	_debug_path_instance.mesh = _debug_path_mesh
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = Color.YELLOW
	path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_mat.no_depth_test = true
	path_mat.render_priority = 1
	_debug_path_instance.material_override = path_mat
	_debug_path_instance.visible = debug_enabled
	add_child(_debug_path_instance)

	# Vertex-coloured lines: FOV cone, position markers, velocity
	_debug_shapes_mesh = ImmediateMesh.new()
	_debug_shapes_instance = MeshInstance3D.new()
	_debug_shapes_instance.mesh = _debug_shapes_mesh
	var shapes_mat := StandardMaterial3D.new()
	shapes_mat.vertex_color_use_as_albedo = true
	shapes_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shapes_mat.no_depth_test = true
	shapes_mat.render_priority = 2
	_debug_shapes_instance.material_override = shapes_mat
	_debug_shapes_instance.visible = debug_enabled
	add_child(_debug_shapes_instance)

	# Semi-transparent ghost capsule
	var ghost_mesh := CapsuleMesh.new()
	ghost_mesh.radius = 0.36
	ghost_mesh.height = 1.75
	_ghost = MeshInstance3D.new()
	_ghost.mesh = ghost_mesh
	_ghost.position = Vector3(0, 0.875, 0)
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.35)
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.no_depth_test = true
	ghost_mat.render_priority = 1
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost.material_override = ghost_mat
	_ghost.visible = ghost_enabled
	add_child(_ghost)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_F3:
		debug_enabled = not debug_enabled
		ghost_enabled = debug_enabled
		_debug_label.visible = debug_enabled
		_debug_path_instance.visible = debug_enabled
		_ghost.visible = ghost_enabled
		_debug_shapes_instance.visible = debug_enabled or hearing_debug_enabled
	elif event.keycode == KEY_F4:
		hearing_debug_enabled = not hearing_debug_enabled
		_debug_shapes_instance.visible = debug_enabled or hearing_debug_enabled

func _update_debug(dist: float, delta: float) -> void:
	_debug_path_mesh.clear_surfaces()
	_debug_shapes_mesh.clear_surfaces()
	_debug_step_age += delta
	if not debug_enabled and not hearing_debug_enabled:
		return

	var h_speed := Vector2(velocity.x, velocity.z).length()

	# --- F3: AI label + nav path ---
	if debug_enabled:
		var push_str := " push=%.2f" % _wall_push_timer if _wall_push_timer > 0.05 else ""
		var extra := ""
		match state:
			State.PREDICTING:
				extra = "\nPred t=%.1fs stuck=%.1f relay=%d%s" % [_predict_timer, _stuck_timer, _predict_relay, push_str]
			State.SEARCHING:
				extra = "\nSearch %.1fs pt %d/%d stuck=%.1f%s" % [_search_timer, _search_pt_idx + 1, _search_points.size(), _stuck_timer, push_str]
			State.PATROLLING:
				extra = "\nPatrol[%d/%d]%s" % [_patrol_index, patrol_points.size(), push_str]
			State.ALERT:
				var mem_left := maxf(0.0, SIGHT_CONFIRM + TRACK_MEMORY - _sight_lost_time)
				extra = "\nLostSight=%.2fs mem=%.1fs%s" % [_sight_lost_time, mem_left, push_str]
			State.UNBLOCKING:
				var chair_dist := global_position.distance_to(_chair_to_remove.global_position) if is_instance_valid(_chair_to_remove) else -1.0
				extra = "\nUnblocking chair dist=%.1f stuck=%.1f%s" % [chair_dist, _stuck_timer, push_str]
		var nav_path := nav_agent.get_current_navigation_path()
		var hear_str := " ear=%.1fs" % _hear_cooldown if _hear_cooldown > 0.0 else ""
		_debug_label.text = (
			"State: %s\nDist: %.1f  Spd: %.1f\nPath: %d pts%s%s%s"
			% [State.keys()[state], dist, h_speed, nav_path.size(),
			   "  [MEM]" if _has_memory else "", extra, hear_str]
		)
		if nav_path.size() > 1:
			_debug_path_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			for i in range(nav_path.size() - 1):
				_debug_path_mesh.surface_add_vertex(to_local(nav_path[i])     + Vector3(0, 0.12, 0))
				_debug_path_mesh.surface_add_vertex(to_local(nav_path[i + 1]) + Vector3(0, 0.12, 0))
			_debug_path_mesh.surface_end()

	# --- Shapes (vertex-coloured) ---
	_debug_shapes_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	if debug_enabled:
		var fov_col: Color
		match state:
			State.PATROLLING:  fov_col = Color(0.2, 1.0, 0.2)
			State.ALERT:       fov_col = Color(1.0, 0.15, 0.15)
			State.PREDICTING:  fov_col = Color(0.2, 0.8, 1.0)
			State.SEARCHING:   fov_col = Color(1.0, 0.6, 0.0)
			State.UNBLOCKING:  fov_col = Color(0.9, 0.9, 0.1)
			_:                 fov_col = Color.WHITE

		if state == State.ALERT:
			# 3-D cylinder cage for 360° detection range
			const CIRC := 16
			for h in [0.3, 1.2, 2.0]:
				for i in CIRC:
					var a := float(i)     / CIRC * TAU
					var b := float(i + 1) / CIRC * TAU
					_debug_shapes_mesh.surface_set_color(fov_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(cos(a), h, sin(a)) * DETECTION_RANGE)
					_debug_shapes_mesh.surface_set_color(fov_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(cos(b), h, sin(b)) * DETECTION_RANGE)
			for i in range(0, CIRC, 4):
				var a := float(i) / CIRC * TAU
				_debug_shapes_mesh.surface_set_color(fov_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(cos(a), 0.3, sin(a)) * DETECTION_RANGE)
				_debug_shapes_mesh.surface_set_color(fov_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(cos(a), 2.0, sin(a)) * DETECTION_RANGE)
		else:
			# 3-D FOV wedge: two edge lines + curved far arc, drawn at 3 heights
			var fov_rad := deg_to_rad(FOV_HALF_DEG)
			const ARC_SEGS := 10
			for h in [0.3, 1.2, 2.0]:
				# Two straight edges
				for sign in [-1.0, 1.0]:
					var edge := Vector3(sin(sign * fov_rad) * DETECTION_RANGE, h, -cos(sign * fov_rad) * DETECTION_RANGE)
					_debug_shapes_mesh.surface_set_color(fov_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(0, h, 0))
					_debug_shapes_mesh.surface_set_color(fov_col)
					_debug_shapes_mesh.surface_add_vertex(edge)
				# Arc connecting the tips
				for i in ARC_SEGS:
					var a0 := -fov_rad + float(i)     / ARC_SEGS * (2.0 * fov_rad)
					var a1 := -fov_rad + float(i + 1) / ARC_SEGS * (2.0 * fov_rad)
					_debug_shapes_mesh.surface_set_color(fov_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(sin(a0) * DETECTION_RANGE, h, -cos(a0) * DETECTION_RANGE))
					_debug_shapes_mesh.surface_set_color(fov_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(sin(a1) * DETECTION_RANGE, h, -cos(a1) * DETECTION_RANGE))
			# Vertical edges at the FOV sides connecting all 3 heights
			for sign in [-1.0, 1.0]:
				var ex := sin(sign * fov_rad) * DETECTION_RANGE
				var ez := -cos(sign * fov_rad) * DETECTION_RANGE
				_debug_shapes_mesh.surface_set_color(fov_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(ex, 0.3, ez))
				_debug_shapes_mesh.surface_set_color(fov_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(ex, 2.0, ez))

		# Velocity vector (white arrow at head height)
		if h_speed > 0.1:
			var vel_local := to_local(global_position + Vector3(velocity.x, 0, velocity.z).normalized() * 2.0)
			_debug_shapes_mesh.surface_set_color(Color.WHITE)
			_debug_shapes_mesh.surface_add_vertex(Vector3(0, 1.2, 0))
			_debug_shapes_mesh.surface_set_color(Color.WHITE)
			_debug_shapes_mesh.surface_add_vertex(vel_local + Vector3(0, 1.2, 0))

		# Position markers
		if _has_memory:
			_draw_debug_marker(_memory_position, Color(0.9, 0.1, 0.9), 0.5)
		if state in [State.PREDICTING, State.SEARCHING, State.ALERT]:
			_draw_debug_marker(_last_seen_position, Color(1.0, 0.5, 0.0), 0.6)
		if state == State.PREDICTING:
			_draw_debug_marker(_predicted_position, Color(0.2, 1.0, 1.0), 0.7)
		# Search waypoints — current in bright yellow, pending in dim, done in very dim
		if state == State.SEARCHING:
			for i in _search_points.size():
				var pt_col: Color
				if i == _search_pt_idx:
					pt_col = Color(1.0, 1.0, 0.0)
				elif i > _search_pt_idx:
					pt_col = Color(0.5, 0.5, 0.0)
				else:
					pt_col = Color(0.2, 0.2, 0.0)
				_draw_debug_marker(_search_points[i], pt_col, 0.3)

	if hearing_debug_enabled:
		# Occlusion tint: green=clear  red=wall  blue=floor/ceiling
		var occ_col := Color(0.2, 0.9, 0.2)
		if _debug_occluded:
			occ_col = Color(0.3, 0.4, 1.0) if _debug_occlude_is_floor else Color(1.0, 0.2, 0.2)

		# 3-D cylinder cages for hearing ranges.
		# Bottom ring (y=0.1) + top ring (y=2.2) + vertical pillars every 8 segments.
		const HR_SEGS := 24
		var walk_col   := Color(0.15, 0.5, 0.15) if _debug_occluded else Color(0.2, 0.9, 0.2)
		var sprint_col := Color(0.4, 0.25, 0.05) if _debug_occluded else Color(1.0, 0.55, 0.0)
		for i in HR_SEGS:
			var a := float(i)     / HR_SEGS * TAU
			var b := float(i + 1) / HR_SEGS * TAU
			# Walk cylinder — bottom + top rings
			for h in [0.1, 2.2]:
				_debug_shapes_mesh.surface_set_color(walk_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(cos(a) * HEAR_RANGE_WALK, h, sin(a) * HEAR_RANGE_WALK))
				_debug_shapes_mesh.surface_set_color(walk_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(cos(b) * HEAR_RANGE_WALK, h, sin(b) * HEAR_RANGE_WALK))
			# Sprint cylinder — bottom + top rings
			for h in [0.1, 2.2]:
				_debug_shapes_mesh.surface_set_color(sprint_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(cos(a) * HEAR_RANGE_SPRINT, h, sin(a) * HEAR_RANGE_SPRINT))
				_debug_shapes_mesh.surface_set_color(sprint_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(cos(b) * HEAR_RANGE_SPRINT, h, sin(b) * HEAR_RANGE_SPRINT))
			# Vertical pillars every 8 segments
			if i % 8 == 0:
				var ca := cos(a)
				var sa := sin(a)
				_debug_shapes_mesh.surface_set_color(walk_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(ca * HEAR_RANGE_WALK, 0.1, sa * HEAR_RANGE_WALK))
				_debug_shapes_mesh.surface_set_color(walk_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(ca * HEAR_RANGE_WALK, 2.2, sa * HEAR_RANGE_WALK))
				_debug_shapes_mesh.surface_set_color(sprint_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(ca * HEAR_RANGE_SPRINT, 0.1, sa * HEAR_RANGE_SPRINT))
				_debug_shapes_mesh.surface_set_color(sprint_col)
				_debug_shapes_mesh.surface_add_vertex(Vector3(ca * HEAR_RANGE_SPRINT, 2.2, sa * HEAR_RANGE_SPRINT))

		# Occluded: draw bright reduced-range cylinders showing effective range (35%)
		if _debug_occluded:
			for i in HR_SEGS:
				var a := float(i)     / HR_SEGS * TAU
				var b := float(i + 1) / HR_SEGS * TAU
				for h in [0.1, 2.2]:
					_debug_shapes_mesh.surface_set_color(occ_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(cos(a) * HEAR_RANGE_WALK   * 0.35, h, sin(a) * HEAR_RANGE_WALK   * 0.35))
					_debug_shapes_mesh.surface_set_color(occ_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(cos(b) * HEAR_RANGE_WALK   * 0.35, h, sin(b) * HEAR_RANGE_WALK   * 0.35))
					_debug_shapes_mesh.surface_set_color(occ_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(cos(a) * HEAR_RANGE_SPRINT * 0.35, h, sin(a) * HEAR_RANGE_SPRINT * 0.35))
					_debug_shapes_mesh.surface_set_color(occ_col)
					_debug_shapes_mesh.surface_add_vertex(Vector3(cos(b) * HEAR_RANGE_SPRINT * 0.35, h, sin(b) * HEAR_RANGE_SPRINT * 0.35))

		# Occlusion ray: green=clear  red=wall  blue=floor
		if _player and not _player._dead:
			var ray_col := occ_col if _debug_occluded else Color(0.0, 1.0, 0.0)
			var p_local  := to_local(_player.global_position + Vector3.UP * 1.2)
			_debug_shapes_mesh.surface_set_color(ray_col)
			_debug_shapes_mesh.surface_add_vertex(Vector3(0, 1.2, 0))
			_debug_shapes_mesh.surface_set_color(ray_col)
			_debug_shapes_mesh.surface_add_vertex(p_local)
			if _debug_occluded:
				var hit_local := to_local(_debug_occlusion_hit)
				# 3-axis cross at the hit point
				for axis in [Vector3(0.35, 0, 0), Vector3(0, 0.35, 0), Vector3(0, 0, 0.35)]:
					_debug_shapes_mesh.surface_set_color(occ_col)
					_debug_shapes_mesh.surface_add_vertex(hit_local - axis)
					_debug_shapes_mesh.surface_set_color(occ_col)
					_debug_shapes_mesh.surface_add_vertex(hit_local + axis)
				# Vertical spike so it's visible from any angle
				_debug_shapes_mesh.surface_set_color(occ_col)
				_debug_shapes_mesh.surface_add_vertex(hit_local - Vector3(0, 0.5, 0))
				_debug_shapes_mesh.surface_set_color(occ_col)
				_debug_shapes_mesh.surface_add_vertex(hit_local + Vector3(0, 1.5, 0))

		# Hear-cooldown arc at head height (yellow ring, shrinks as timer expires)
		if _hear_cooldown > 0.0:
			var ratio    := _hear_cooldown / 2.0
			var arc_segs := int(HR_SEGS * ratio)
			for i in arc_segs:
				var a := float(i)     / HR_SEGS * TAU - PI * 0.5
				var b := float(i + 1) / HR_SEGS * TAU - PI * 0.5
				_debug_shapes_mesh.surface_set_color(Color(1.0, 1.0, 0.0))
				_debug_shapes_mesh.surface_add_vertex(Vector3(cos(a) * 0.6, 2.0, sin(a) * 0.6))
				_debug_shapes_mesh.surface_set_color(Color(1.0, 1.0, 0.0))
				_debug_shapes_mesh.surface_add_vertex(Vector3(cos(b) * 0.6, 2.0, sin(b) * 0.6))

		# Last footstep event — cyan=heard, grey=missed (fades over 3 s)
		if _debug_step_age < 3.0:
			var step_col := Color(0.0, 1.0, 1.0) if _debug_step_heard else Color(0.4, 0.4, 0.4)
			_draw_debug_marker(_debug_step_pos, step_col, 0.45)

	_debug_shapes_mesh.surface_end()

# Draws a flat ring + vertical stake at a world position into _debug_shapes_mesh.
# Call only between surface_begin / surface_end.
func _draw_debug_marker(world_pos: Vector3, col: Color, radius: float) -> void:
	var lp := to_local(world_pos)
	# Vertical stake from ground to above head
	_debug_shapes_mesh.surface_set_color(col)
	_debug_shapes_mesh.surface_add_vertex(lp)
	_debug_shapes_mesh.surface_set_color(col)
	_debug_shapes_mesh.surface_add_vertex(lp + Vector3(0, 2.4, 0))
	# Two rings: ground (y=0.1) and eye height (y=1.2) so it's visible from FPS
	const SEGS := 12
	for h in [0.1, 1.2]:
		for i in SEGS:
			var a := float(i)     / SEGS * TAU
			var b := float(i + 1) / SEGS * TAU
			_debug_shapes_mesh.surface_set_color(col)
			_debug_shapes_mesh.surface_add_vertex(lp + Vector3(cos(a) * radius, h, sin(a) * radius))
			_debug_shapes_mesh.surface_set_color(col)
			_debug_shapes_mesh.surface_add_vertex(lp + Vector3(cos(b) * radius, h, sin(b) * radius))

func set_target(_pos: Vector3) -> void:
	pass
