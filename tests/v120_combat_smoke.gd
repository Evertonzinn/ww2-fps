extends SceneTree

# v0.12 integration smoke. Run:
# godot --headless --path PROJECT --script res://tests/v120_combat_smoke.gd
# Loads the real scene, checks combat presence and health/HUD/death contracts.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var error: Error = change_scene_to_file("res://main.tscn")
	if error != OK:
		push_error("WW2 v0.12 SMOKE: could not load main.tscn")
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame
	var world: Node = current_scene
	if world == null:
		push_error("WW2 v0.12 SMOKE: no active World")
		quit(1)
		return
	var soldier: Node = world.get_node_or_null("EnemySoldierTest")
	var combat: Node = world.get_node_or_null("EnemySoldierTest/EnemyCombat")
	var player: Node = world.get_node_or_null("Player")
	var hud: Node = world.get_node_or_null("HUD")
	if soldier == null or combat == null or player == null or hud == null:
		push_error("WW2 v0.12 SMOKE: missing enemy, combat, player or HUD")
		quit(1)
		return
	if not combat.has_method("is_engaged") or not player.has_method("take_damage"):
		push_error("WW2 v0.12 SMOKE: enemy/player contract unavailable")
		quit(1)
		return
	print("PASS enemy combat node and player damage contract")
	player.call("take_damage", 13)
	if int(player.get("health")) != 87:
		push_error("WW2 v0.12 SMOKE: 13 damage did not leave 87 HP")
		quit(1)
		return
	var health_ui: Label = hud.get_node_or_null("HealthDisplay") as Label
	if health_ui == null or not health_ui.text.contains("87 / 100"):
		push_error("WW2 v0.12 SMOKE: health HUD incorrect")
		quit(1)
		return
	print("PASS player 13 damage and HUD 87/100")
	player.call("take_damage", 87)
	if int(player.get("health")) != 0 or not bool(player.get("is_dead")):
		push_error("WW2 v0.12 SMOKE: player death not applied")
		quit(1)
		return
	var death_ui: Control = hud.get_node_or_null("DeathPanel") as Control
	if death_ui == null or not death_ui.visible:
		push_error("WW2 v0.12 SMOKE: death screen not visible")
		quit(1)
		return
	player.call("take_damage", 50)
	if int(player.get("health")) != 0:
		push_error("WW2 v0.12 SMOKE: dead player still takes damage")
		quit(1)
		return
	print("PASS death overlay and damage lockout")
	print("WW2 FPS v0.12 COMBAT SMOKE: PASS")
	quit(0)
