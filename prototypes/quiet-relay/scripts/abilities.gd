extends Node2D

# Sword direction is sampled when a move begins. Ranged launches sample the
# current selected target or manual aim, then travel without homing.
const PROJECTILE = preload("res://scripts/projectile.gd")
const BOOMERANG_FORM = preload("res://scripts/boomerang_form.gd")
const NORMAL_DAMAGE: float = 5.0
const HEAVY_DAMAGE: float = 12.0
const ORB_DAMAGE: float = 14.0
const ORB_RADIUS: float = 88.0
const MAX_CHARGE: float = 1.0
const SWORD_DASH_DAMAGE: float = 8.0
const SWORD_DASH_ACTIVE: float = 0.18
const SWORD_DASH_COOLDOWN: float = 0.40

var weapon_names: Array[String] = ["Bow", "Boomerang", "Bomb"]
var selected_weapon: int = 0
var ranged_requires_release: bool = false
var _ranged_held: bool = false

var world
var player
var active_move: String = ""
var cooldown: float = 0.0
var charging: bool = false
var charge_time: float = 0.0
var projectiles: Array = []
var orb
var boomerang
var active_time: float = 0.0
var windup_time: float = 0.0
var move_direction: Vector2 = Vector2.RIGHT
var move_heavy: bool = false
var move_spin: bool = false
var move_dash: bool = false
var current_damage: float = NORMAL_DAMAGE
var hit_targets: Dictionary = {}
var effect_time: float = 0.0
var effect_position: Vector2 = Vector2.ZERO
var _bow_facing: float = 1.0
var _generation: int = 0

func handle_input(direction: Vector2, attack_pressed: bool, special_pressed: bool, special_held: bool, heavy_direction: Vector2) -> void:
	if not is_instance_valid(player):
		return
	if charging:
		if player.blocking or player.helpless or player.is_dodging:
			_cancel_charge()
		elif not special_held:
			release_special()
		return
	if heavy_direction.length() >= 0.35:
		start_attack(heavy_direction,true)
	elif attack_pressed:
		start_attack(direction)
	elif special_pressed:
		start_special(direction)

func _can_start() -> bool:
	return is_instance_valid(player) and player.can_act() and not player.is_dashing and cooldown <= 0.0 and active_time <= 0.0 and windup_time <= 0.0 and not charging

func _aim_held() -> bool:
	return is_instance_valid(world) and is_instance_valid(world.aim) and world.aim.held

func _bow_direction() -> Vector2:
	if is_instance_valid(world) and is_instance_valid(world.aim):
		var ranged_direction: Vector2 = world.aim.ranged_direction()
		if not ranged_direction.is_zero_approx():
			return ranged_direction.normalized()
	return Vector2(float(player.facing), 0.0)

func boomerang_active() -> bool:
	return is_instance_valid(boomerang) and not boomerang.is_queued_for_deletion() and not boomerang.finished

func cancel_boomerang() -> void:
	if boomerang_active():
		boomerang.cancel()

func boomerang_finished(form, cancelled: bool) -> void:
	if boomerang == form:
		boomerang = null
	if _ranged_held:
		ranged_requires_release = true
	cooldown = maxf(cooldown, 0.42)
	active_move = "" if cancelled else "Boomerang returned"
	queue_redraw()

func selected_weapon_name() -> String:
	return weapon_names[posmod(selected_weapon, weapon_names.size())]

func cycle_ranged() -> bool:
	if not is_instance_valid(player):
		return false
	# Switching does not discard a returning throw or an already placed bomb.
	# A held trigger must be released, so switching never silently fires it.
	if charging or _ranged_held:
		ranged_requires_release = true
	if charging:
		_cancel_charge()
	selected_weapon = posmod(selected_weapon + 1, weapon_names.size())
	_notify("Ranged: %s" % selected_weapon_name())
	queue_redraw()
	return true

func reset_loadout() -> void:
	selected_weapon = 0
	cancel_charge()
	queue_redraw()

func handle_ranged(pressed: bool, held: bool) -> void:
	_ranged_held = held
	if not is_instance_valid(player):
		return
	if ranged_requires_release:
		if not held and _ranged_trigger_released():
			ranged_requires_release = false
		return
	if charging:
		if player.blocking or player.helpless or player.is_dodging or player.rolling or player.is_dashing:
			ranged_requires_release = held
			_cancel_charge()
		elif not held:
			release_special()
		return
	if pressed:
		fire_ranged()

func _ranged_trigger_released() -> bool:
	# Gameplay action state can be cleared by a menu while the real trigger
	# remains down. Rearm only after that physical input has also released.
	if is_instance_valid(world) and is_instance_valid(world.controls) and world.controls.has_method("ranged_is_physically_held"):
		return not world.controls.ranged_is_physically_held()
	return true

func fire_ranged() -> bool:
	# Direction affects the sword and movement, never which ranged weapon fires.
	if ranged_requires_release or not _can_start():
		return false
	match posmod(selected_weapon, weapon_names.size()):
		0:
			return _start_bow()
		1:
			return _throw_boomerang(float(player.facing))
		2:
			return _use_bomb()
	return false

func _cardinal(direction: Vector2) -> Vector2:
	if direction.length() < 0.35:
		return Vector2(float(player.facing),0.0)
	if absf(direction.y) > absf(direction.x):
		return Vector2(0.0,signf(direction.y))
	return Vector2(signf(direction.x),0.0)

func start_attack(direction: Vector2, heavy: bool = false) -> bool:
	# The sword remains the same after every ranged swap. Melee may put away
	# a charging bow, but cannot turn that interrupted charge into a shot.
	if charging and is_instance_valid(player):
		ranged_requires_release = _ranged_held
		_cancel_charge()
		if player.action_lock_time <= 0.08:
			player.action_lock_time = 0.0
	if not _can_start():
		return false
	_generation += 1
	move_direction = _cardinal(direction)
	move_heavy = heavy
	move_spin = false
	move_dash = false
	current_damage = HEAVY_DAMAGE if heavy else NORMAL_DAMAGE
	hit_targets.clear()
	windup_time = 0.16 if heavy else 0.0
	active_time = 0.0 if heavy else 0.13
	cooldown = 0.48 if heavy else 0.22
	player.action_lock_time = maxf(player.action_lock_time,0.32 if heavy else 0.12)
	if move_direction.x != 0.0:
		player.facing = move_direction.x
	var aerial: bool = not player.is_on_floor()
	if heavy:
		active_move = "Rising smash" if move_direction.y < 0.0 else ("Low smash" if move_direction.y > 0.0 else "Side smash")
	elif move_direction.y < 0.0:
		active_move = "Up aerial" if aerial else "Up slash"
	elif move_direction.y > 0.0:
		active_move = "Down aerial" if aerial else "Low slash"
	else:
		active_move = "Aerial slash" if aerial else "Sword slash"
	_notify(active_move)
	queue_redraw()
	return true

func start_sword_dash() -> bool:
	if not is_instance_valid(player) or player.boomerang_form or not player.is_dashing or player.helpless or player.blocking or player.hitstop_time > 0.0:
		return false
	if charging:
		ranged_requires_release = _ranged_held
		_cancel_charge()
	# Root input accepts the two buttons within 80ms in either order. If the
	# normal slash has already touched a target, retain its registry on upgrade.
	var upgrade: bool = active_time > 0.0 and not move_heavy and not move_spin and not move_dash and windup_time <= 0.0 and active_time >= 0.13 - 0.08
	if move_dash and active_time > 0.0:
		return false
	if not upgrade and (cooldown > 0.0 or active_time > 0.0 or windup_time > 0.0):
		return false
	_generation += 1
	if not upgrade:
		hit_targets.clear()
	move_direction = player.dash_direction.normalized()
	if move_direction.is_zero_approx():
		move_direction = Vector2(float(player.facing), 0.0)
	move_heavy = false
	move_spin = false
	move_dash = true
	windup_time = 0.0
	active_time = SWORD_DASH_ACTIVE
	cooldown = maxf(cooldown, SWORD_DASH_COOLDOWN)
	current_damage = SWORD_DASH_DAMAGE
	active_move = "Sword dash"
	player.action_lock_time = maxf(player.action_lock_time, SWORD_DASH_ACTIVE)
	_notify(active_move)
	queue_redraw()
	return true

func start_special(direction: Vector2) -> bool:
	if not _can_start():
		return false
	if direction.y < -0.35 and absf(direction.y) >= absf(direction.x):
		# Recovery spin is intentionally absent from this control revision.
		return false
	elif direction.y > 0.35 and absf(direction.y) >= absf(direction.x):
		return _use_bomb()
	elif absf(direction.x) >= 0.35:
		return _throw_boomerang(signf(direction.x))
	else:
		return _start_bow()

func _start_bow() -> bool:
	if _projectile_count("arrow") >= 3:
		return false
	charging = true
	charge_time = 0.0
	_bow_facing = float(player.facing)
	active_move = "Charged bow"
	player.action_lock_time = maxf(player.action_lock_time, 0.08)
	_notify("Hold ranged to charge; release to shoot")
	queue_redraw()
	return true

func _throw_boomerang(facing: float) -> bool:
	if boomerang_active():
		return false
	player.facing = facing
	var form = BOOMERANG_FORM.new()
	add_child(form)
	boomerang = form
	var aimed: bool = _aim_held()
	var heading: Vector2 = world.aim.raw_direction if aimed else _bow_direction()
	if not form.begin(self, player, facing, aimed, heading):
		boomerang = null
		form.queue_free()
		return false
	active_move = "Boomerang form"
	cooldown = 0.42
	_notify(active_move)
	queue_redraw()
	return true

func _use_bomb() -> bool:
	if is_instance_valid(orb):
		if not detonate_orb():
			return false
	else:
		var launch: Dictionary = world.aim.bomb_launch() if is_instance_valid(world) and is_instance_valid(world.aim) else {}
		var target = world.selected_target() if is_instance_valid(world) and world.has_method("selected_target") else null
		var targeted: bool = not _aim_held() and is_instance_valid(target)
		if targeted:
			if not is_instance_valid(world.aim):
				_notify("Targeted bomb aiming unavailable")
				return false
			# Preview may cache nearby poses; firing must anchor the capped
			# trajectory to the character's exact current launch position.
			launch = world.aim.targeted_bomb_launch(target, true)
			if not bool(launch.get("valid", false)):
				_notify(str(launch.get("reason", "No clear bomb landing for this target")))
				return false
		var origin: Vector2 = launch.get("origin", player.global_position + Vector2(float(player.facing) * 24.0, -12.0))
		var velocity: Vector2 = launch.get("velocity", Vector2(float(player.facing) * 220.0, -230.0))
		if not _aim_held() and not targeted:
			origin = player.global_position + Vector2(float(player.facing) * 24.0, -12.0)
			velocity = Vector2(float(player.facing) * 220.0, -230.0)
		orb = _spawn_projectile("orb", origin, velocity, 0.0, "Remote bomb", launch)
		active_move = "Remote bomb deployed"
		_notify("Bomb placed: use Bomb again to detonate")
	cooldown = 0.30
	player.action_lock_time = maxf(player.action_lock_time, 0.15)
	queue_redraw()
	return true

func release_special() -> bool:
	if not charging or not is_instance_valid(player):
		return false
	var strength: float = clampf(charge_time/MAX_CHARGE,0.0,1.0)
	var heading: Vector2 = _bow_direction()
	var origin: Vector2 = player.global_position + Vector2(0.0, -9.0) + heading * 25.0
	if is_instance_valid(world) and is_instance_valid(world.aim):
		origin = world.aim.projectile_origin(heading, 25.0, 6.0)
	_spawn_projectile("arrow",origin,heading * lerpf(700.0,1180.0,strength),lerpf(4.0,10.0,strength),"Charged arrow")
	charging = false
	charge_time = 0.0
	active_move = "Arrow released"
	cooldown = 0.28
	player.action_lock_time = maxf(player.action_lock_time,0.16)
	_notify(active_move)
	queue_redraw()
	return true

func _cancel_charge() -> void:
	charging = false
	charge_time = 0.0
	active_move = ""
	queue_redraw()

func cancel_charge() -> void:
	if charging or _ranged_held:
		ranged_requires_release = true
	if charging:
		_cancel_charge()

func _spawn_projectile(kind: String, origin: Vector2, velocity: Vector2, damage: float, label: String, launch: Dictionary = {}):
	var shot = PROJECTILE.new()
	shot.abilities = self
	shot.kind = kind
	shot.velocity = velocity
	shot.damage = damage
	shot.move_name = label
	# Ready-time bomb caps must capture the real launch position, not the
	# abilities node's origin before the projectile is inserted into the tree.
	shot.position = to_local(origin)
	if kind == "orb" and not launch.is_empty():
		shot.launch_origin = launch.get("launch_origin", origin)
		shot.range_limit = launch.get("range_limit", 0.0)
	add_child(shot)
	shot.global_position = origin
	projectiles.append(shot)
	return shot

func _projectile_count(kind: String) -> int:
	var count: int = 1 if kind == "crescent" and boomerang_active() else 0
	for shot in projectiles:
		if is_instance_valid(shot) and not shot.is_queued_for_deletion() and shot.kind == kind:
			count += 1
	return count

func projectile_finished(shot: Node) -> void:
	projectiles.erase(shot)
	if orb == shot:
		orb = null

func detonate_orb() -> bool:
	if not is_instance_valid(orb) or orb.is_queued_for_deletion():
		return false
	var origin: Vector2 = orb.global_position
	var generation: int = _generation
	var seen: Dictionary = {}
	var shape := CircleShape2D.new()
	shape.radius = ORB_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0,origin)
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target = _target_body(result.collider)
		if not is_instance_valid(target) or seen.has(target.get_instance_id()) or not has_line_of_sight(origin,target.global_position):
			continue
		seen[target.get_instance_id()] = true
		var horizontal: float = signf(target.global_position.x-origin.x)
		if horizontal == 0.0:
			horizontal = float(player.facing)
		apply_hit(target,ORB_DAMAGE,Vector2(horizontal*340.0,-440.0),"Remote bomb")
		if generation != _generation:
			return false
	var spent = orb
	orb = null
	projectile_finished(spent)
	spent.queue_free()
	effect_position = origin
	effect_time = 0.22
	active_move = "Remote bomb burst"
	_notify(active_move)
	queue_redraw()
	return true

func _target_body(collider):
	if not is_instance_valid(collider):
		return null
	if collider.has_method("accept_hit"):
		return collider
	var parent = collider.get_parent()
	if is_instance_valid(parent) and parent.has_method("accept_hit"):
		return parent
	return null

func has_line_of_sight(origin: Vector2, target: Vector2) -> bool:
	if origin.distance_squared_to(target) < 0.01:
		return true
	var ray := PhysicsRayQueryParameters2D.create(origin,target,1)
	ray.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func apply_hit(target, damage: float, impulse: Vector2, label: String) -> bool:
	if not is_instance_valid(target) or not target.has_method("accept_hit"):
		return false
	var generation: int = _generation
	var accepted: bool = target.accept_hit(damage,impulse,label)
	if generation != _generation:
		return false
	if accepted and is_instance_valid(player):
		player.hitstop_time = maxf(player.hitstop_time,0.055 if damage >= HEAVY_DAMAGE else 0.035)
		_notify("%s  +%s%%" % [label,str(snappedf(damage,0.1))])
	return accepted

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if player.hitstop_time > 0.0:
		return
	cooldown = maxf(0.0,cooldown-delta)
	effect_time = maxf(0.0,effect_time-delta)
	if charging:
		charge_time = minf(MAX_CHARGE,charge_time+delta)
	elif windup_time > 0.0:
		windup_time = maxf(0.0,windup_time-delta)
		if windup_time <= 0.0:
			active_time = 0.16
	elif active_time > 0.0:
		_query_sword()
		active_time = maxf(0.0,active_time-delta)
	if not charging and not boomerang_active() and cooldown <= 0.0 and active_time <= 0.0 and windup_time <= 0.0:
		active_move = ""
	queue_redraw()

func _query_sword() -> void:
	var origin: Vector2 = player.global_position+Vector2(0.0,-5.0)
	var query := PhysicsShapeQueryParameters2D.new()
	if move_spin:
		var circle := CircleShape2D.new()
		circle.radius = 63.0
		query.shape = circle
		query.transform = Transform2D(0.0,origin)
	else:
		var reach: float = 94.0 if move_dash else (92.0 if move_heavy else 72.0)
		var box := RectangleShape2D.new()
		box.size = Vector2(reach,52.0 if move_dash else (48.0 if move_heavy else 40.0))
		query.shape = box
		if move_direction.y > 0.0 and player.is_on_floor() and not move_dash:
			# A low grounded slash travels in front along the floor. The
			# airborne version keeps its downward hit volume for a spike.
			query.transform = Transform2D(0.0,origin+Vector2(float(player.facing)*(18.0+reach/2.0),10.0))
		else:
			query.transform = Transform2D(move_direction.angle(),origin+move_direction*(18.0+reach/2.0))
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var generation: int = _generation
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var target = _target_body(result.collider)
		if not is_instance_valid(target) or hit_targets.has(target.get_instance_id()) or not has_line_of_sight(origin,target.global_position):
			continue
		hit_targets[target.get_instance_id()] = true
		var impulse: Vector2
		if move_dash:
			impulse = move_direction * 340.0 + Vector2(0.0, -130.0)
		elif move_spin:
			impulse = Vector2(signf(target.global_position.x-origin.x)*150.0,-410.0)
		elif move_direction.y < 0.0:
			impulse = Vector2(float(player.facing)*60.0,-570.0 if move_heavy else -350.0)
		elif move_direction.y > 0.0:
			impulse = Vector2(float(player.facing)*120.0,400.0 if not player.is_on_floor() else -170.0)
		else:
			impulse = Vector2(move_direction.x*(490.0 if move_heavy else 245.0),-260.0 if move_heavy else -140.0)
		apply_hit(target,current_damage,impulse,active_move)
		if generation != _generation:
			return

func cancel_sword_dash() -> void:
	if not move_dash:
		return
	_generation += 1
	active_time = 0.0
	windup_time = 0.0
	move_dash = false
	active_move = ""
	hit_targets.clear()
	queue_redraw()

func cancel_all() -> void:
	_generation += 1
	cancel_boomerang()
	if charging or _ranged_held:
		ranged_requires_release = true
	charging = false
	charge_time = 0.0
	active_move = ""
	cooldown = 0.0
	windup_time = 0.0
	active_time = 0.0
	effect_time = 0.0
	move_spin = false
	move_heavy = false
	move_dash = false
	hit_targets.clear()
	for shot in projectiles:
		if is_instance_valid(shot):
			shot.queue_free()
	projectiles.clear()
	orb = null
	queue_redraw()

func combat_summary() -> String:
	if boomerang_active():
		return "Boomerang form: %s  |  Ranged: %s" % ["returning" if boomerang.returning else "outward", selected_weapon_name()]
	if charging:
		return "Bow  %d%% charge" % int(charge_time/MAX_CHARGE*100.0)
	if is_instance_valid(orb):
		return "%s  |  Ranged: %s  |  Bomb placed" % [active_move if not active_move.is_empty() else "Ready", selected_weapon_name()]
	return "%s  |  Ranged: %s" % [active_move if not active_move.is_empty() else "Ready", selected_weapon_name()]

func _notify(message: String) -> void:
	if is_instance_valid(world) and world.has_method("set_feedback"):
		world.set_feedback(message)

func _draw() -> void:
	if not is_instance_valid(player) or player.boomerang_form:
		return
	var center: Vector2 = to_local(player.global_position)+Vector2(0.0,-5.0)
	if charging:
		var strength: float = charge_time/MAX_CHARGE
		var heading: Vector2 = _bow_direction()
		var side := Vector2(-heading.y, heading.x)
		var bow_center: Vector2 = center + heading * 22.0
		var angle: float = heading.angle()
		draw_arc(bow_center,21.0,angle-1.15,angle+1.15,24,Color("f4da91"),3.0)
		var drawstring: Vector2 = bow_center - heading * (6.0 + strength * 9.0)
		draw_line(bow_center + heading * 8.0 - side * 19.0, drawstring,Color("d8f5df"),1.5)
		draw_line(drawstring, bow_center + heading * 8.0 + side * 19.0,Color("d8f5df"),1.5)
		draw_line(bow_center - heading * 20.0, bow_center + heading * 18.0,Color("ffedb2"),2.5)
		draw_circle(bow_center,4.0+strength*4.0,Color(0.6,1.0,0.78,0.35+strength*0.3))
	elif active_time > 0.0 or windup_time > 0.0:
		var color := Color("ffb65d") if move_dash else (Color("ffc87d") if move_heavy else Color("e9f8cc"))
		var reach: float = 90.0 if move_dash else (87.0 if move_heavy else 68.0)
		if windup_time > 0.0:
			color.a = 0.4+(1.0-windup_time/0.16)*0.4
		if move_spin:
			draw_arc(center,61.0,0.0,TAU,42,Color("b3f2cf"),4.0)
			var spin_angle: float = (0.30-active_time)*32.0
			draw_line(center,center+Vector2.from_angle(spin_angle)*61.0,Color("f3e5ba"),5.0)
		else:
			var angle: float = move_direction.angle()
			if move_dash:
				var side := Vector2(-move_direction.y, move_direction.x)
				draw_line(center - move_direction * 42.0 + side * 12.0, center + move_direction * 14.0 + side * 12.0, Color(1.0, 0.64, 0.24, 0.5), 4.0)
				draw_line(center - move_direction * 65.0 - side * 9.0, center + move_direction * 8.0 - side * 9.0, Color(1.0, 0.72, 0.38, 0.3), 3.0)
			if move_direction.y > 0.0 and player.is_on_floor() and not move_dash:
				angle = Vector2(float(player.facing),0.22).angle()
			draw_arc(center,reach,angle-0.80 if move_dash else angle-0.66,angle+0.80 if move_dash else angle+0.66,24,color,5.0 if move_heavy or move_dash else 3.0)
			var blade: Vector2 = Vector2.from_angle(angle)
			draw_line(center+blade*12.0,center+blade*reach,color,6.0 if move_heavy or move_dash else 4.0)
	else:
		var facing: float = float(player.facing)
		draw_line(center+Vector2(facing*11.0,4.0),center+Vector2(facing*22.0,23.0),Color("c4d7c2"),3.0)
	if effect_time > 0.0:
		var progress: float = 1.0-effect_time/0.22
		var blast: Vector2 = to_local(effect_position)
		draw_circle(blast,ORB_RADIUS*progress,Color(0.3,0.85,0.96,(1.0-progress)*0.2))
		draw_arc(blast,ORB_RADIUS*progress,0.0,TAU,48,Color(0.65,0.96,1.0,1.0-progress),4.0)
