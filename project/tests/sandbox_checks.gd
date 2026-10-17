extends RefCounted

var host
var world
var player
var dummy
var abilities
var completed: bool = false

func run(test_host) -> void:
	host = test_host
	world = load("res://main.tscn").instantiate()
	host.root.add_child(world)
	player = world.player
	dummy = world.dummy
	abilities = world.abilities
	player.test_control = true
	await host.tick(8)
	await test_arena()
	await test_movement()
	await test_defence_recovery()
	await test_live_inputs()
	await test_swords()
	await test_specials()
	await test_dummy_and_resets()
	await test_pause_and_unplug()
	release_inputs()
	host.paused = false
	world.queue_free()
	await host.tick(2)
	completed = true

func check(condition: bool, description: String) -> void:
	host.check(condition, description)

func release_inputs() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)

func fixture(point: Vector2 = Vector2(150,542)) -> void:
	release_inputs()
	player.set_physics_process(true)
	dummy.set_physics_process(true)
	player.test_control = true
	player.test_axis = 0.0
	player.test_vertical = 0.0
	player.test_jump_held = false
	player.test_block_held = false
	world.reset_room()
	player.reset_at(point)
	player.facing = 1.0
	await host.tick(5)

func place(point: Vector2, frames: int = 4) -> void:
	player.test_axis = 0.0
	player.test_vertical = 0.0
	player.test_jump_held = false
	player.test_block_held = false
	player.reset_at(point)
	await host.tick(frames)

func frozen_target(point: Vector2) -> void:
	dummy.reset_dummy()
	dummy.set_physics_process(false)
	dummy.position = point
	await host.tick(2)

func jump_height(held_frames: int) -> float:
	await fixture()
	var start: float = player.position.y
	var highest: float = start
	player.test_jump_pressed = true
	player.test_jump_held = true
	for index in range(125):
		if index == held_frames:
			player.test_jump_held = false
		await host.tick(1)
		highest = minf(highest, player.position.y)
	return start - highest

func joy_button(code: JoyButton, pressed: bool, device: int = 31) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)

func joy_axis(axis: JoyAxis, value: float, device: int = 31) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func names_of_properties(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property in object.get_property_list():
		names.append(property.name)
	return names

func test_arena() -> void:
	check(player.is_on_floor() and absf(player.position.y-542.0)<1.0, "Player spawn settles on the continuous floor")
	check(dummy.is_on_floor() and absf(dummy.position.y-538.0)<1.0, "Training dummy settles on the same floor")
	var platforms: int = 0
	var solid_bodies: int = 0
	for child in world.get_children():
		if child is StaticBody2D:
			if child.get_collision_layer_value(2):
				platforms += 1
				check(child.get_child(0).one_way_collision, "Practice platform permits upward passage")
			else:
				solid_bodies += 1
	check(platforms == 3 and solid_bodies == 3, "Arena contains only three platforms, floor and two edge walls")
	var properties := names_of_properties(world)
	check(not properties.has("stone") and not properties.has("solved") and not properties.has("gate") and not properties.has("enemy_defeated"), "Retired weight, relay, gate and enemy progression have no live state")
	check(host.get_nodes_in_group("training_targets").size()==4, "Exactly four inert practice targets exist")
	await fixture(Vector2(20,542))
	player.test_axis = -1.0
	await host.tick(60)
	check(player.position.x>=10.8, "West edge wall blocks actual movement")
	await place(Vector2(1580,542))
	player.test_axis = 1.0
	await host.tick(60)
	check(player.position.x<=1589.2, "East edge wall blocks actual movement")
	world.camera.force_update_scroll()
	var center: Vector2 = world.camera.get_screen_center_position()
	check(center.x<=1024.1 and center.x>=1023.0, "Camera reaches eastern practice space within arena bounds")
	var screen: Vector2 = world.get_viewport().get_canvas_transform()*player.position
	check(screen.y-18>216 and screen.y+18<648, "Floor-level character remains visible below fixed controls and status")
	await fixture(Vector2(620,-160))
	world.camera.force_update_scroll()
	center = world.camera.get_screen_center_position()
	screen = world.get_viewport().get_canvas_transform()*player.position
	check(center.y>=world.camera.limit_top+324.0 and screen.y-18>216 and screen.y+18<648, "Upper-air camera keeps high recovery movement visible below the fixed HUD")
	await fixture(Vector2(800,542))
	await host.tick(360)
	check(dummy.percent==0.0 and dummy.hit_count==0 and dummy.position.distance_to(world.DUMMY_START)<1.0, "Dummy remains inert and no pursuing enemies spawn during idle practice")
	check(player.position.distance_to(Vector2(800,542))<1.0, "Idle practice has no objective timer, hazard damage or forced progression")

func test_movement() -> void:
	await fixture()
	player.test_axis = 1.0
	await host.tick(24)
	check(absf(player.velocity.x-400.0)<0.1, "Full horizontal input accelerates to 400 px/s")
	player.test_axis = 0.0
	await host.tick(12)
	check(absf(player.velocity.x)<0.1, "Ground release brakes to a stable stop")
	player.test_axis = 0.5
	await host.tick(15)
	check(absf(player.velocity.x-200.0)<0.1, "Half analog input produces controllable 200 px/s movement")
	var full: float = await jump_height(125)
	var short: float = await jump_height(3)
	check(full>128.0 and full<145.0, "Held grounded jump reaches the lower platforms: %.2f px" % full)
	check(short>25.0 and short<65.0 and short<full*0.55, "Release cuts the grounded jump into a distinct short hop: %.2f px" % short)
	await fixture()
	player.test_jump_pressed = true
	player.test_jump_held = true
	await host.tick(23)
	check(player.jump_count==1 and player.jumps_remaining==1 and player.velocity.y<0, "Ground jump consumes the first jump")
	player.test_jump_pressed = true
	await host.tick(2)
	check(player.jump_count==2 and player.jumps_remaining==0 and player.velocity.y < -480, "Second press creates a separate upward air jump")
	player.test_jump_pressed = true
	await host.tick(18)
	check(player.jump_count==2, "Third airborne jump press cannot create a third jump")
	player.test_jump_held = false
	await host.tick(180)
	check(player.is_on_floor() and player.jumps_remaining==2, "Landing restores both jumps without replaying an expired buffer")
	await fixture(Vector2(530,414))
	player.test_axis = 1.0
	for index in range(50):
		await host.tick(1)
		if not player.is_on_floor():
			break
	await host.tick(3)
	player.test_jump_pressed = true
	player.test_jump_held = true
	await host.tick(2)
	check(player.jump_count==1 and player.velocity.y < -500 and player.jumps_remaining==1, "Coyote jump after leaving a platform retains the separate air jump")
	await fixture(Vector2(620,485))
	player.jumps_remaining = 0
	player.velocity.y = 500.0
	player.test_jump_pressed = true
	player.test_jump_held = true
	await host.tick(17)
	check(player.jump_count==1 and player.velocity.y<0.0, "Jump buffered with exhausted air jumps fires on the nearby landing")
	await fixture(Vector2(150,150))
	player.jumps_remaining = 0
	player.test_jump_pressed = true
	await host.tick(160)
	check(player.jump_count==0 and player.is_on_floor(), "Expired buffered press is not replayed on a much later landing")
	await fixture(Vector2(430,542))
	player.test_jump_pressed = true
	player.test_jump_held = true
	var rose_above: bool = false
	for index in range(125):
		await host.tick(1)
		rose_above = rose_above or player.position.y+18<432.0
	check(rose_above and player.is_on_floor() and absf(player.position.y-414.0)<1.0, "Actual jump passes through a one-way platform and lands on its top")
	player.test_vertical = 1.0
	player.test_jump_pressed = true
	await host.tick(8)
	check(player.position.y>420.0 and not player.get_collision_mask_value(2), "Down plus jump drops through the platform instead of jumping")
	await host.tick(60)
	check(player.is_on_floor() and absf(player.position.y-542.0)<1.0 and player.get_collision_mask_value(2), "Drop-through restores platform collision and lands on the uninterrupted floor")
	await fixture(Vector2(620,230))
	player.velocity.y = 80.0
	player.test_vertical = 1.0
	await host.tick(2)
	check(player.fastfall and player.velocity.y>=1090, "Fresh downward input while descending engages fast fall")
	await host.tick(70)
	check(player.is_on_floor() and not player.fastfall, "Fast fall stops on landing without damage or lost practice lives")
	await fixture(Vector2(620,180))
	player.velocity.y = -100.0
	player.test_vertical = 1.0
	await host.tick(2)
	check(not player.fastfall and player.velocity.y<0, "Down during ascent does not prematurely fast fall")
	player.test_vertical = 0.0
	player.test_axis = 1.0
	await host.tick(20)
	check(absf(player.velocity.x-300.0)<20.1, "Air steering accelerates toward a separate controllable air speed")

func test_defence_recovery() -> void:
	await fixture()
	player.test_block_held = true
	await host.tick(3)
	check(player.blocking and not player.rolling and absf(player.velocity.x)<0.1, "Neutral grounded shoulder input holds a stationary shield")
	check(not abilities.start_attack(Vector2.RIGHT) and not abilities.start_special(Vector2.ZERO), "Shield blocks starting sword and special attacks")
	player.test_jump_pressed = true
	player.test_jump_held = true
	await host.tick(2)
	check(not player.is_on_floor() and not player.blocking and player.jump_count==1, "Jump can leave shield directly")
	await fixture()
	check(player.request_dodge(Vector2.RIGHT), "Grounded directional defence starts a roll")
	var roll_x: float = player.position.x
	await host.tick(20)
	check(player.rolling and player.position.x-roll_x>80.0 and player.position.x-roll_x<95.0, "Ground roll travels at its committed speed through real collision movement")
	check(not abilities.start_attack(Vector2.RIGHT), "Committed roll rejects attacking")
	await host.tick(24)
	check(not player.rolling and player.can_act(), "Ground roll has finite recovery and returns to ordinary actions")
	await fixture(Vector2(620,180))
	check(player.request_dodge(Vector2(1,-1)), "Air defence starts a directional air dodge")
	check(not player.dodge_available and not player.request_dodge(Vector2.LEFT), "Air dodge is consumed once and cannot stack")
	var dodge_start: Vector2 = player.position
	await host.tick(18)
	check(player.is_dodging and player.position.x>dodge_start.x+40 and player.position.y<dodge_start.y-40, "Diagonal dodge produces physical movement in both chosen directions")
	await host.tick(12)
	check(not player.is_dodging and not player.can_act(), "Air dodge includes a vulnerable action recovery after motion ends")
	await host.tick(20)
	check(player.can_act() and not player.request_dodge(Vector2.RIGHT), "Finished air dodge still cannot be reused before landing")
	await host.tick(200)
	check(player.is_on_floor() and player.dodge_available, "Landing rearms the air dodge")
	await fixture(Vector2(620,150))
	check(player.request_dodge(Vector2.ZERO), "Neutral air dodge is available")
	var neutral_start: Vector2 = player.position
	await host.tick(18)
	check(player.position.distance_to(neutral_start)<0.2, "Neutral air dodge avoids forced drift during its committed window")
	await fixture(Vector2(620,160))
	check(not abilities.start_special(Vector2.UP) and not player.recovery_used and not abilities.move_spin, "Removed up-special cannot create a recovery spin or spend movement resources")
	await fixture()
	check(not abilities.start_special(Vector2.UP) and player.can_act(), "Removed grounded up-special leaves ordinary actions available")

func test_live_inputs() -> void:
	await fixture()
	player.test_control = false
	joy_axis(JOY_AXIS_LEFT_X,0.15)
	await host.tick(12)
	check(absf(player.velocity.x)<0.1, "Injected gamepad input below deadzone produces no walking")
	joy_axis(JOY_AXIS_LEFT_X,0.60)
	await host.tick(20)
	check(player.velocity.x>100 and player.velocity.x<300, "Injected partial stick tilt retains proportional movement")
	joy_axis(JOY_AXIS_LEFT_X,0.0)
	joy_axis(JOY_AXIS_LEFT_Y,-1.0)
	await host.tick(10)
	check(player.jump_count==0 and player.is_on_floor(), "Up-stick direction aims without triggering jump")
	joy_axis(JOY_AXIS_LEFT_Y,0.0)
	joy_button(JOY_BUTTON_A,true)
	await host.tick(3)
	check(player.jump_count==1 and player.velocity.y<0, "Actual gamepad A button starts the first jump")
	joy_button(JOY_BUTTON_A,false)
	await host.tick(2)
	joy_button(JOY_BUTTON_A,true)
	await host.tick(3)
	check(player.jump_count==2 and player.velocity.y<0, "Releasing and pressing A again starts the separate air jump")
	joy_button(JOY_BUTTON_A,false)
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1015,538))
	player.test_control = false
	joy_button(JOY_BUTTON_X,true)
	await host.tick(25)
	check(dummy.hit_count==1 and is_equal_approx(dummy.percent,5.0), "Actual X button creates one sword hit while held")
	joy_button(JOY_BUTTON_X,false)
	await host.tick(10)
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await host.tick(10)
	check(abilities.charging and player.jump_count==0, "Actual RT trigger charges the selected Bow independently of jumping")
	joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await host.tick(3)
	check(not abilities.charging, "Releasing actual RT trigger fires the charged Bow")
	await fixture()
	player.test_control = false
	joy_axis(JOY_AXIS_RIGHT_X,0.60)
	await host.tick(3)
	check(abilities.active_move.is_empty(), "Right stick below smash threshold does not start heavy attack")
	joy_axis(JOY_AXIS_RIGHT_X,0.70)
	await host.tick(2)
	check(abilities.move_heavy and abilities.windup_time>0, "Right stick just past threshold starts a directional heavy windup")
	await host.tick(100)
	check(abilities.active_move.is_empty() and abilities.cooldown==0, "Holding right stick starts only one heavy attack per tilt")
	joy_axis(JOY_AXIS_RIGHT_X,0.0)
	await host.tick(3)
	joy_axis(JOY_AXIS_RIGHT_Y,-1.0)
	await host.tick(2)
	check(abilities.move_heavy and abilities.move_direction==Vector2.UP, "Re-centering and a new upward tilt starts an up smash")
	joy_axis(JOY_AXIS_RIGHT_Y,0.0)
	await fixture()
	player.test_control = false
	key(KEY_W,true)
	await host.tick(5)
	check(player.jump_count==0 and player.is_on_floor(), "Keyboard W is directional aim rather than jump")
	key(KEY_W,false)
	key(KEY_SPACE,true)
	await host.tick(3)
	check(player.jump_count==1, "Keyboard Space remains a separate live jump input")
	key(KEY_SPACE,false)
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1015,538))
	player.test_control = false
	key(KEY_J,true)
	await host.tick(25)
	check(dummy.hit_count==1, "Keyboard J remains a one-press sword attack")
	key(KEY_J,false)
	await host.tick(7)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await host.tick(25)
	check(dummy.hit_count==2, "Mouse click remains a separate sword attack")
	mouse.pressed = false
	Input.parse_input_event(mouse)
	joy_axis(JOY_AXIS_LEFT_X,0.0)
	joy_axis(JOY_AXIS_LEFT_Y,0.0)
	joy_axis(JOY_AXIS_RIGHT_X,0.0)
	joy_axis(JOY_AXIS_RIGHT_Y,0.0)

func test_swords() -> void:
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1015,538))
	check(abilities.start_attack(Vector2.RIGHT), "Directional grounded side slash starts")
	await host.tick(5)
	check(dummy.hit_count==1 and dummy.percent==5.0 and dummy.last_impulse.x>0, "Side slash reaches the real target area and launches away from the sword")
	check(not abilities.start_attack(Vector2.RIGHT), "Active slash rejects a simultaneous second swing")
	await host.tick(35)
	check(dummy.hit_count==1, "Persistent sword overlap applies only one hit per move")
	check(abilities.start_attack(Vector2.LEFT), "A fresh slash can aim in the opposite direction")
	await host.tick(35)
	check(dummy.hit_count==1, "Opposite-facing slash misses a target behind its hit volume")
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(950,478))
	abilities.start_attack(Vector2.UP)
	await host.tick(6)
	check(dummy.hit_count==1 and dummy.last_impulse.y<0 and dummy.last_move=="Up slash", "Grounded up attack reaches above and launches upward")
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1012,538))
	abilities.start_attack(Vector2.DOWN)
	await host.tick(6)
	check(dummy.hit_count==1 and dummy.last_move=="Low slash", "Grounded down attack uses the forward low slash instead of hitting below the floor")
	await fixture(Vector2(950,340))
	await frozen_target(player.position+Vector2(0,66))
	abilities.start_attack(Vector2.DOWN)
	await host.tick(5)
	check(dummy.hit_count==1 and dummy.last_move=="Down aerial" and dummy.last_impulse.y>0, "Down aerial reaches below the airborne player and spikes downward")
	await fixture(Vector2(950,340))
	await frozen_target(player.position+Vector2(62,0))
	abilities.start_attack(Vector2.RIGHT)
	await host.tick(5)
	check(dummy.hit_count==1 and dummy.last_move=="Aerial slash", "Horizontal sword input selects an aerial move while airborne")
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1030,538))
	check(abilities.start_attack(Vector2.RIGHT,true), "Heavy side attack begins its readable windup")
	await host.tick(13)
	check(dummy.hit_count==0 and abilities.windup_time>0, "Heavy windup cannot hit before its warning completes")
	await host.tick(12)
	check(dummy.hit_count==1 and dummy.percent==12 and dummy.last_impulse.x>450, "Heavy strike applies stronger damage and knockback after windup")
	check(not abilities.start_attack(Vector2.RIGHT,true), "Heavy recovery rejects immediate repeat")
	await host.tick(55)
	check(dummy.hit_count==1 and abilities.start_attack(Vector2.RIGHT,true), "Heavy overlap hits once and a later press can begin the next heavy")
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1030,538))
	var wall = world.make_surface(Rect2(995,450,10,110),false)
	await host.tick(2)
	abilities.start_attack(Vector2.RIGHT,true)
	await host.tick(45)
	check(dummy.hit_count==0, "Solid obstacle line of sight prevents sword hits through walls")
	wall.queue_free()
	await host.tick(2)

func test_specials() -> void:
	await fixture(Vector2(950,542))
	check(abilities.start_special(Vector2.ZERO) and abilities.release_special(), "Uncharged neutral special can be released immediately")
	var arrow = abilities.projectiles[0]
	check(arrow.kind=="arrow" and arrow.damage==4 and absf(arrow.velocity.x-700)<0.1, "Immediate bow release produces the weak fast projectile")
	check(not abilities.release_special() and abilities.projectiles.size()==1, "One charge release produces one projectile rather than duplicate arrows")
	await fixture(Vector2(950,542))
	abilities.start_special(Vector2.ZERO)
	player.facing = -1.0
	abilities.release_special()
	check(abilities.projectiles[0].velocity.x<0, "Un-aimed bow release follows the player's current horizontal facing")
	await fixture(Vector2(950,542))
	Input.action_press("ranged")
	abilities.start_special(Vector2.ZERO)
	await host.tick(140)
	check(abilities.charging and is_equal_approx(abilities.charge_time,1.0), "Holding bow reaches and clamps maximum charge")
	Input.action_release("ranged")
	await host.tick(1)
	var charged = abilities.projectiles[0] if not abilities.projectiles.is_empty() else null
	check(is_instance_valid(charged) and charged.damage==10 and absf(charged.velocity.x-1180)<0.1, "Full held charge releases a stronger faster arrow through the input path")
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(990,538))
	abilities._spawn_projectile("arrow",Vector2(950,533),Vector2(12000,0),4.0,"Sweep fixture")
	await host.tick(2)
	check(dummy.hit_count==1 and dummy.percent==4 and abilities.projectiles.is_empty(), "Swept projectile hits a target narrower than one frame of travel and is consumed")
	await fixture(Vector2(950,542))
	for index in range(3):
		abilities._spawn_projectile("arrow",Vector2(150+index*30,200),Vector2.ZERO,4.0,"Capacity fixture")
	check(not abilities.start_special(Vector2.ZERO) and not abilities.charging, "Three active arrows cap further bow starts")
	await host.tick(190)
	check(abilities.projectiles.is_empty() and abilities.start_special(Vector2.ZERO), "Projectile expiry releases bow capacity")
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1030,538))
	var wall = world.make_surface(Rect2(995,450,10,110),false)
	await host.tick(2)
	abilities.start_special(Vector2.ZERO)
	abilities.release_special()
	await host.tick(25)
	check(dummy.hit_count==0 and abilities.projectiles.is_empty(), "Arrow collides with solid geometry before a target behind it")
	wall.queue_free()
	await host.tick(2)
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1010,538))
	check(abilities.start_special(Vector2.RIGHT), "Boomerang transforms the player into one returning form")
	var crescent = abilities.boomerang
	await host.tick(25)
	check(dummy.hit_count==1 and dummy.percent==5, "Returning throw's outward pass strikes the target once")
	await host.tick(140)
	check(is_instance_valid(crescent) and crescent.returning, "Boomerang form begins returning after its 1.2-second outward window")
	check(not abilities.start_special(Vector2.RIGHT), "One active returning throw prevents another simultaneous throw")
	await host.tick(170)
	check(dummy.hit_count==2 and dummy.percent==10 and abilities.projectiles.is_empty() and not player.boomerang_form, "Returning pass strikes once more and restores the player at the launch position")
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1080,538))
	check(abilities.start_special(Vector2.DOWN) and is_instance_valid(abilities.orb), "Down special deploys a single remote orb without contact damage")
	check(dummy.hit_count==0, "Orb deployment alone does not explode or damage the dummy")
	await host.tick(55)
	abilities.orb.position = Vector2(1040,538)
	abilities.orb.velocity = Vector2.ZERO
	abilities.orb.settled = true
	await host.tick(2)
	check(abilities.start_special(Vector2.DOWN), "Second down-special press detonates the existing orb")
	check(dummy.hit_count==1 and dummy.percent==14 and not is_instance_valid(abilities.orb), "Remote orb blast uses real area collision, applies one strong hit and consumes the orb")
	check(host.get_nodes_in_group("training_targets").size()==4, "Special abilities retain only the four practice targets without enemy progression")
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1080,538))
	abilities.start_special(Vector2.DOWN)
	await host.tick(40)
	abilities.orb.position = Vector2(1040,538)
	abilities.orb.velocity = Vector2.ZERO
	abilities.orb.settled = true
	wall = world.make_surface(Rect2(1055,450,10,110),false)
	await host.tick(2)
	abilities.start_special(Vector2.DOWN)
	check(dummy.hit_count==0, "Orb blast respects solid-wall line of sight even inside blast radius")
	wall.queue_free()
	await host.tick(2)
	await fixture(Vector2(950,542))
	abilities.start_special(Vector2.DOWN)
	await host.tick(150)
	check(is_instance_valid(abilities.orb) and abilities.orb.settled and abilities.orb.position.y>545 and abilities.orb.position.y<555, "Orb falls with gravity and settles safely above the floor")
	await fixture(Vector2(430,350))
	abilities._spawn_projectile("orb",Vector2(430,450),Vector2(0,-360),0.0,"Platform fixture")
	var platform_orb = abilities.projectiles[0]
	await host.tick(12)
	check(not platform_orb.settled and platform_orb.position.y<432, "Ascending orb can pass upward through a one-way platform")
	await host.tick(100)
	check(is_instance_valid(platform_orb) and platform_orb.settled and absf(platform_orb.position.y-423)<1, "Descending orb rests on the top of a one-way practice platform")

func test_dummy_and_resets() -> void:
	await fixture()
	check(dummy.accept_hit(12.5,Vector2(200,-250),"Fraction fixture"), "Dummy accepts fractional training damage")
	check(dummy.percent==12.5 and dummy.hit_count==1 and dummy.last_move=="Fraction fixture" and dummy.last_damage==12.5, "Dummy preserves exact damage, hit count and move readout")
	check(dummy.velocity.x>200 and dummy.velocity.y<-250, "Accumulated percent scales physical knockback")
	var home: Vector2 = dummy.position
	await host.tick(25)
	check(dummy.position.x>home.x+20 and dummy.position.y<home.y-15, "Hit launches the dummy through real physics without making it attack")
	await host.tick(330)
	check(dummy.position.distance_to(world.DUMMY_START)<1 and dummy.percent==12.5 and dummy.hit_count==1, "Automatic dummy return retains accumulated practice results")
	check(not dummy.accept_hit(-1,Vector2.ONE,"Invalid") and not dummy.accept_hit(INF,Vector2.ONE,"Invalid") and dummy.percent==12.5, "Invalid damage cannot corrupt the dummy's readout")
	world.reset_dummy()
	check(dummy.percent==0 and dummy.hit_count==0 and dummy.velocity==Vector2.ZERO and dummy.last_move=="No hits yet", "Manual dummy reset clears results and motion")
	dummy.accept_hit(5,Vector2(100,-100),"Retained")
	abilities.start_special(Vector2.DOWN)
	player.recovery_used = true
	player.dodge_available = false
	player.helpless = true
	player.jumps_remaining = 0
	world.respawn()
	check(dummy.percent==5 and dummy.hit_count==1 and abilities.projectiles.is_empty(), "Player reset retains dummy results and removes all projectiles")
	check(player.position==world.START and player.jumps_remaining==2 and player.dodge_available and not player.recovery_used and not player.helpless, "Player reset restores movement resources and the practice spawn")
	await host.tick(5)
	abilities.start_attack(Vector2.RIGHT,true)
	world.reset_dummy()
	check(abilities.windup_time==0 and abilities.active_time==0 and dummy.hit_count==0, "Dummy reset cancels in-flight sword windup as well as the dummy's results")
	await host.tick(5)
	Input.action_press("ranged")
	abilities.start_special(Vector2.ZERO)
	world.reset_room()
	Input.action_release("ranged")
	await host.tick(30)
	check(not abilities.charging and abilities.projectiles.is_empty() and dummy.percent==0 and player.jump_count==0, "Full training reset cancels bow charge without leaking a release projectile or jump")
	player.position = Vector2(800,900)
	await host.tick(5)
	check(player.position.distance_to(world.START)<2 and world.respawn_count==1, "Out-of-bounds practice fall returns to spawn once without lives or damage")

func test_pause_and_unplug() -> void:
	await fixture(Vector2(950,542))
	await frozen_target(Vector2(1015,538))
	player.test_control = false
	Input.action_press("ranged")
	abilities.start_special(Vector2.ZERO)
	await host.tick(8)
	world.pause_game()
	var position_before: Vector2 = player.position
	var charge_before: float = abilities.charge_time
	await host.tick(30)
	check(host.paused and player.position==position_before and abilities.charge_time==charge_before, "Pause freezes player movement, bow charge and ability physics")
	joy_button(JOY_BUTTON_A,true)
	await host.tick(6)
	joy_button(JOY_BUTTON_A,false)
	joy_button(JOY_BUTTON_B,false)
	await host.tick(30)
	check(not host.paused and dummy.hit_count==0 and not abilities.charging and abilities.projectiles.is_empty() and player.jump_count==0, "A-menu resume consumes the jump button and cancels stale bow release without combat leakage")
	await fixture()
	player.test_control = false
	world.pause_game()
	joy_button(JOY_BUTTON_X,true)
	await host.tick(5)
	joy_button(JOY_BUTTON_X,false)
	await host.tick(25)
	check(not host.paused and player.jump_count==0 and dummy.hit_count==0, "X-menu dummy reset does not leak its normal sword action on resume")
	await fixture()
	dummy.accept_hit(5,Vector2.ZERO,"Menu safety")
	Input.action_press("menu_room")
	world.pause_game()
	await host.tick(150)
	check(host.paused and dummy.percent==5, "Training-reset button held before pause cannot accidentally confirm a full reset")
	Input.action_release("menu_room")
	await host.tick(3)
	Input.action_press("menu_room")
	await host.tick(75)
	check(host.paused and dummy.percent==5, "Fresh training-reset hold shorter than one second stays unconfirmed")
	await host.tick(60)
	Input.action_release("menu_room")
	await host.tick(5)
	check(not host.paused and dummy.percent==0 and player.jump_count==0, "A full fresh hold confirms training reset and resumes without leaked movement")
	await fixture()
	player.test_control = false
	Input.action_press("ranged")
	abilities.start_special(Vector2.ZERO)
	world.controls.use_controller(31,"Xbox Controller")
	world.controls.on_connection_changed(30,false)
	check(not host.paused and abilities.charging, "Unrelated device disconnection does not interrupt the active controller")
	world.controls.on_connection_changed(31,false)
	await host.tick(3)
	check(host.paused and world.controls.family=="keyboard" and world.controls.active_device==-1 and not Input.is_action_pressed("ranged"), "Active controller unplug releases held input and pauses with keyboard fallback")
	var overlay = world.ui_canvas.get_node("Pause")
	overlay.resume()
	await host.tick(20)
	check(not abilities.charging and abilities.projectiles.is_empty() and player.jump_count==0, "Hot-unplug resume cancels charged specials rather than firing phantom projectiles")

