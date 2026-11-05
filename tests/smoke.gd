extends SceneTree
## Headless smoke test: a bot plays the whole campaign through the Sim API,
## checks save/load round-trips, then boots the real main scene and pokes
## every screen. Prints "SMOKE OK" on success.
## Run: godot --headless --path . --script res://tests/smoke.gd

const Sim = preload("res://scripts/sim.gd")

var fails := 0

func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func _initialize() -> void:
	var s = Sim.new()
	s.new_game(7)
	check(s.grid[10]["type"] == "greenhouse", "starter greenhouse")
	check(s.plant_all(10, "lettuce") == 4, "plant 4 lettuce")
	var plan := [["electrolyzer", 13], ["recycler", 14], ["battery", 4], ["lab", 21], ["greenhouse", 9],
		["solar", 1], ["battery", 5], ["greenhouse", 18], ["solar", 0], ["electrolyzer", 22]]
	var step := 0
	var dt := 0.5
	var min_o2 := 999.0
	var last_mission := 0
	var rot := 0
	while s.sol() < 40 and not s.festival and s.game_over == "":
		s.tick(dt)
		step += 1
		min_o2 = minf(min_o2, s.o2)
		if step % 2 != 0:
			continue
		s.harvest_all()
		var opts := []
		for c in Sim.CROP_ORDER:
			if s.crop_unlocked(c):
				opts.append(c)
		for i in s.grid.size():
			var m = s.grid[i]
			if m != null and m["type"] == "greenhouse":
				rot += 1
				s.plant_all(i, opts[rot % opts.size()])
		if plan.size() > 0 and s.build(plan[0][0], plan[0][1]):
			plan.pop_front()
		elif plan.is_empty():
			for i in [12, 20, 10]:
				s.upgrade(i)
		s.rover_auto = "ice" if int(s.stats["ice"]) < 15 or (s.ice < 10 and s.water < 90.0) else "reg"
		for r in Sim.RESEARCH:
			s.research(r["id"])
		if s.docked():
			for c in Sim.CROP_ORDER:
				var keep := 3 if s.mission >= 9 else 1
				if int(s.stock[c]) > keep:
					s.sell(c, int(s.stock[c]) - keep)
			if s.water < 40.0:
				s.trade("water")
		if s.avg_morale() < 75.0:
			s.movie_night()
			for i in 4:
				s.call_home(i)
		if s.mission != last_mission:
			print("  mission ", last_mission + 1, " done at sol ", s.sol(), " t=", int(s.t))
			last_mission = s.mission
		s.events.clear()
	print("bot result: sol=", s.sol(), " mission=", s.mission, " festival=", s.festival, " over=", s.game_over, " min_o2=", int(min_o2), " credits=", int(s.credits))
	check(s.game_over == "", "bot survives")
	check(s.festival, "bot reaches festival")
	# save / load round trip through JSON
	var txt := JSON.stringify(s.to_dict())
	var s2 = Sim.new()
	check(s2.from_dict(JSON.parse_string(txt)), "load ok")
	check(s2.mission == s.mission and int(s2.credits) == int(s.credits), "load matches")
	s2.tick(1.0)
	# failure path: no oxygen production
	var s3 = Sim.new()
	s3.new_game(3)
	var guard := 0
	while s3.game_over == "" and guard < 20000:
		s3.tick(0.5)
		guard += 1
	check(s3.game_over == "o2", "o2 failure triggers (got '%s')" % s3.game_over)
	# boot the real scene
	var scene: PackedScene = load("res://main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start_new()
	for i in 30:
		await process_frame
	main.dismiss_msg()
	main.tile_action(10)
	for k in ["base", "crew", "lab", "goals", "trade"]:
		main.tab = k
		await process_frame
	main.tile_action(5)
	main.tab = "base"
	await process_frame
	main.open_menu()
	await process_frame
	main.menu_open = false
	main.save_game()
	main.to_title()
	await process_frame
	main.continue_game()
	await process_frame
	check(main.screen == "play", "continue works")
	main.sim.game_over = "o2"
	main.screen = "over"
	await process_frame
	main.screen = "howto"
	await process_frame
	main.screen = "title"
	main.win_open = true
	await process_frame
	print("SMOKE OK" if fails == 0 else "SMOKE FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)
