extends Node2D
var world

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(22,117,900,99),Color(0.025,0.044,0.063,0.92))
	var chosen = world.selected_target()
	if world.aim.held and is_instance_valid(world.aim.assisted_target):
		chosen = world.aim.assisted_target
	elif not is_instance_valid(chosen):
		chosen = world.dummy
	var target_name: String = chosen.target_name if is_instance_valid(chosen) else "None"
	var loadout: String = "SWORD | RANGED: %s" % world.abilities.selected_weapon_name().to_upper()
	if world.aim.held:
		loadout += " | AIM ASSIST: %s" % (world.aim.assisted_target.target_name if is_instance_valid(world.aim.assisted_target) else "FREE AIM")
	else:
		var selected = world.selected_target()
		loadout += " | TARGET: %s" % (selected.target_name if is_instance_valid(selected) else "FREE")
	if world.abilities.ranged_requires_release:
		loadout += " | RELEASE %s TO REARM" % world.controls.button("ranged")
	draw_string(font,Vector2(30,138),loadout,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e4c997"))
	var resources: String = "JUMPS %d | AIR DODGE %s | AIR DASH %s" % [world.player.jumps_remaining,"READY" if world.player.dodge_available else "USED","READY" if world.player.dash_available else "USED"]
	if world.abilities.boomerang_active():
		resources += " | RETURNING FORM" if world.abilities.boomerang.returning else " | BOOMERANG FORM"
	elif world.player.is_dashing:
		resources += " | SWORD DASH" if world.abilities.move_dash else " | DASHING"
	elif world.player.blocking:
		resources += " | BLOCK"
	elif world.player.is_dodging or world.player.rolling:
		resources += " | DODGING"
	elif world.player.fastfall:
		resources += " | FAST FALL"
	elif world.player.dash_cooldown > 0.0:
		resources += " | DASH RECOVERY %.1fs" % world.player.dash_cooldown
	draw_string(font,Vector2(30,161),resources,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b8e0dc"))
	var training: String = "%s %.0f%% | HITS %d" % [target_name,chosen.percent,chosen.hit_count] if is_instance_valid(chosen) else "No target available"
	draw_string(font,Vector2(30,184),training+" / "+world.abilities.combat_summary(),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffdbad"))
	var message: String = world.feedback if world.feedback_time > 0.0 else "Tap %s to select. Hold to aim freely while moving." % world.controls.button("target")
	draw_string(font,Vector2(30,207),message,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("a2bbb2"))
