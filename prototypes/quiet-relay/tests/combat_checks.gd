extends RefCounted

# Focused combat fixtures keep actor locomotion still, while the real weapon,
# player controller, world recovery and collision queries continue to process.
# The guard-awareness check separately leaves full enemy movement enabled.
var h
var world
var player
var enemy
var temporary_wall: Node2D

func run(harness) -> void:
	h = harness
	world = h.world
	player = h.player
	enemy = world.dummy
	var original_ai: bool = enemy.ai_enabled
	var original_processing: bool = enemy.is_physics_processing()
	var original_test_control: bool = player.test_control
	var original_motion: Array[bool] = []
	for platform in world.moving_platforms:
		original_motion.append(platform.motion_enabled)
	player.test_control = true
	await _guard_awareness()
	await _locked_cradle()
	await _strike_timing()
	await _dodge_and_walls()
	await _invulnerability_and_death()
	await _defeat_and_reset_rules()
	await _remove_wall()
	world.reset_room()
	player.test_axis = 0.0
	player.test_jump_pressed = false
	player.test_jump_held = false
	player.test_control = original_test_control
	enemy.ai_enabled = original_ai
	enemy.set_physics_process(original_processing)
	for index in range(world.moving_platforms.size()):
		world.moving_platforms[index].motion_enabled = original_motion[index]
	await h.tick(3)

func _guard_awareness() -> void:
	world.reset_room()
	world.set_platform_motion(false,true)
	enemy.ai_enabled = true
	enemy.set_physics_process(true)
	await h.place(world.START)
	await h.tick(180)
	h.check(not enemy.alerted and enemy.position.distance_to(world.ENEMY_START)<2 and enemy.jump_count==0 and enemy.weapon.attack_count==0,"Combat: distant guard remains idle beside the eastern weight")
	await h.place(Vector2(2170,548))
	var initial_distance: float = absf(enemy.position.x-player.position.x)
	await h.tick(45)
	h.check(enemy.alerted and enemy.position.x>world.ENEMY_START.x+20 and absf(enemy.position.x-player.position.x)<initial_distance-15,"Combat: approaching the guard alerts it and starts actual pursuit")
	h.check(enemy.weapon.attack_count>0,"Combat: pursuing guard starts its own melee windup in range")

func _arena(active_enemy: bool = true) -> void:
	await _remove_wall()
	world.reset_room()
	world.set_platform_motion(false,true)
	enemy.set_physics_process(false)
	enemy.ai_enabled = active_enemy
	enemy.alerted = active_enemy
	enemy.position = Vector2(160,548)
	enemy.velocity = Vector2.ZERO
	enemy.facing = 1.0
	enemy.weapon.cancel()
	await h.place(Vector2(205,548))
	player.facing = 1.0
	world.combat_invulnerability = 0.0

func _locked_cradle() -> void:
	await _arena(false)
	await h.place(world.socket_position()+Vector2(0,-5))
	player.carrying = true
	await h.tick(1)
	world.interact()
	await h.tick(2)
	h.check(not world.solved and player.carrying and world.stone.distance_to(player.position+Vector2(0,-34))<3,"Combat: locked cradle rejects E without dropping the carried weight")
	await h.place(Vector2(200,548))
	world.interact()
	await h.tick(2)
	h.check(not player.carrying and not world.solved and world.stone.distance_to(player.position)<12,"Combat: E away from the cradle still drops the weight for fighting")

func _strike_timing() -> void:
	await _arena()
	h.check(enemy.weapon.try_attack(),"Combat: nearby visible player starts an enemy swing")
	await h.tick(20)
	h.check(world.health==5 and enemy.weapon.hit_count==0 and enemy.weapon.is_committed(),"Combat: enemy windup gives warning without causing damage")
	player.carrying = true
	await h.tick(22)
	h.check(world.health==4 and enemy.weapon.hit_count==1,"Combat: active enemy swing deals exactly one heart")
	h.check(not player.carrying and player.knockback_time>0 and player.velocity.x>0 and world.combat_invulnerability>0,"Combat: accepted strike knocks the player back, drops the weight and grants brief protection")
	await h.tick(12)
	h.check(world.health==4 and enemy.weapon.hit_count==1,"Combat: continued swing overlap cannot damage the player again")
	h.check(not enemy.weapon.try_attack(),"Combat: recovery rejects an immediate second swing")
	await h.tick(110)
	await h.place(Vector2(205,548))
	h.check(enemy.weapon.try_attack(),"Combat: enemy can start a new swing after recovery")
	await h.tick(45)
	h.check(world.health==3 and enemy.weapon.hit_count==2,"Combat: a later enemy swing causes one fresh heart of damage")

func _dodge_and_walls() -> void:
	await _arena()
	enemy.weapon.try_attack()
	player.test_axis = 1.0
	await h.tick(65)
	player.test_axis = 0.0
	h.check(player.position.x>enemy.position.x+enemy.weapon.reach and world.health==5 and enemy.weapon.hit_count==0,"Combat: real player movement retreats out of range during windup")
	await _arena()
	await _add_wall()
	h.check(not enemy.weapon.try_attack(),"Combat: solid wall prevents an enemy windup through the player")
	player.facing = -1.0
	world.attack()
	await h.tick(20)
	h.check(enemy.health==5 and enemy.hit_count==0,"Combat: player melee also cannot hit through a solid wall")
	await _remove_wall()
	enemy.weapon.cancel()
	world.combat_invulnerability = 0.0
	enemy.weapon.try_attack()
	await h.tick(20)
	await _add_wall()
	await h.tick(40)
	h.check(world.health==5 and enemy.weapon.hit_count==0,"Combat: a wall appearing during windup also blocks the active strike")
	await _remove_wall()

func _invulnerability_and_death() -> void:
	await _arena()
	enemy.weapon.try_attack()
	await h.tick(34)
	world.combat_invulnerability = 0.07
	await h.tick(24)
	h.check(world.health==5 and enemy.weapon.hit_count==0 and enemy.weapon.hit_targets.size()==1 and world.combat_invulnerability<=0,"Combat: invulnerable contact consumes the swing even when protection expires during its active window")
	await _arena(false)
	var accepted: bool = world.receive_enemy_hit(1,enemy.position)
	var repeated: bool = world.receive_enemy_hit(1,enemy.position)
	await h.tick(45)
	var protected_later: bool = world.receive_enemy_hit(1,enemy.position)
	h.check(accepted and not repeated and not protected_later and world.health==4,"Combat: separate damage requests cannot bypass combat invulnerability")
	await h.tick(60)
	h.check(world.receive_enemy_hit(1,enemy.position) and world.health==3,"Combat: damage protection expires and permits a later hit")
	await _arena()
	world.checkpoint = Vector2(100,548)
	world.health = 1
	var previous_deaths: int = world.deaths
	enemy.weapon.try_attack()
	await h.tick(30)
	# Begin the player swing late in the warning so it is still active when
	# the lethal contact occurs, then carry a weight into that contact.
	world.attack()
	player.carrying = true
	await h.tick(15)
	h.check(world.deaths==previous_deaths+1 and world.health==5 and player.position.distance_to(world.checkpoint)<8,"Combat: a lethal enemy hit counts one death and restores five hearts at the checkpoint")
	h.check(not player.carrying and world.stone.distance_to(world.STONE_START)<1,"Combat: lethal strike recovers the carried weight at its eastern start")
	h.check(world.weapon.active_time==0 and enemy.weapon.is_ready() and world.combat_invulnerability>0.8,"Combat: respawn cancels both swings and grants spawn protection")
	await h.tick(60)
	h.check(world.deaths==previous_deaths+1 and world.health==5,"Combat: the canceled lethal swing cannot damage the respawn again")

func _defeat_with_melee() -> void:
	enemy.set_physics_process(false)
	enemy.ai_enabled = false
	enemy.position = Vector2(240,548)
	enemy.velocity = Vector2.ZERO
	enemy.weapon.cancel()
	await h.place(Vector2(185,548))
	player.carrying = false
	player.facing = 1.0
	world.weapon.cancel()
	for swing in range(5):
		world.attack()
		await h.tick(40)

func _defeat_and_reset_rules() -> void:
	await _arena(false)
	await _defeat_with_melee()
	h.check(enemy.health==0 and enemy.hit_count==5 and world.enemy_defeated,"Combat: five real melee swings defeat the five-health guard and unlock the cradle")
	world.respawn()
	await h.tick(3)
	h.check(world.enemy_defeated and enemy.health==0,"Combat: checkpoint restart preserves the guard's defeat")
	world.health = 1
	var previous_deaths: int = world.deaths
	world.take_damage("Combat recovery check")
	await h.tick(3)
	h.check(world.deaths==previous_deaths+1 and world.health==5 and world.enemy_defeated and enemy.health==0,"Combat: death recovery also preserves guard defeat")
	world.reset_dummy()
	await h.tick(3)
	h.check(not world.enemy_defeated and not world.solved and enemy.health==5 and enemy.hit_count==0 and enemy.position.distance_to(world.ENEMY_START)<1,"Combat: T reset restores the eastern guard and relocks an unsolved cradle")
	await h.place(world.socket_position()+Vector2(0,-5))
	player.carrying = true
	world.interact()
	h.check(not world.solved and player.carrying,"Combat: the reset guard makes cradle placement reject E again")
	await _defeat_with_melee()
	await h.place(world.socket_position()+Vector2(0,-5))
	player.carrying = true
	world.interact()
	await h.tick(3)
	h.check(world.solved and not player.carrying and not world.bridge.get_child(0).disabled and world.gate.get_child(0).disabled,"Combat: defeated guard permits real cradle interaction and restores bridge/gate collision")
	world.reset_dummy()
	await h.tick(3)
	h.check(world.solved and not world.enemy_defeated and enemy.health==5 and not world.bridge.get_child(0).disabled and world.gate.get_child(0).disabled,"Combat: T reset leaves an already restored relay open")
	world.reset_room()
	await h.tick(3)
	h.check(not world.solved and not world.won and not world.enemy_defeated and not world.checkpoint_active and not world.east_checkpoint_active and world.health==5 and enemy.health==5 and enemy.position.distance_to(world.ENEMY_START)<1 and world.stone.distance_to(world.STONE_START)<1,"Combat: full room reset restores the eastern guard, weight, hearts and progression")

func _add_wall() -> void:
	temporary_wall = world.make_solid(Rect2(184,500,6,70))
	await h.tick(3)

func _remove_wall() -> void:
	if is_instance_valid(temporary_wall):
		temporary_wall.queue_free()
		temporary_wall = null
		await h.tick(3)
