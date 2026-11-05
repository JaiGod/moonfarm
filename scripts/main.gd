extends Node2D
## Moonfarm main scene: screens, world rendering, immediate-mode UI and input.

const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const PanelUI = preload("res://scripts/panel.gd")
const SAVE_PATH := "user://moonfarm_save.json"
const META_PATH := "user://moonfarm_meta.json"
const TILE := 48.0
const C_BG := Color("070912")
const C_PANEL := Color("111a2e")
const C_LINE := Color("2c3b5e")
const C_INK := Color("e8eefc")
const C_DIM := Color("8d9bbd")
const C_GOLD := Color("f6c344")
const C_MINT := Color("7fe08a")
const C_RED := Color("f05a4a")
const C_CYAN := Color("6cc6ff")

var sim
var sfx
var font: Font
var screen := "title"
var paused := false
var menu_open := false
var speed := 1.0
var tab := "base"
var sel := -1
var build_hl := 0
var seed_choice := "lettuce"
var cursor := Vector2i(2, 1)
var kb_used := false
var msgs: Array = []
var particles: Array = []
var floaters: Array = []
var shake := 0.0
var tile_pop := {}
var btns: Array = []
var mouse := Vector2.ZERO
var tm := 0.0
var autosave_t := 0.0
var alert_t := 0.0
var meta := {"best_sol": 0, "festivals": 0, "sound": true, "fastest": 0}
var stars: Array = []
var ground_tex: ImageTexture
var has_save := false
var vs := Vector2(640, 360)
var portrait := false
var L := {}
var toast := ""
var toast_t := 0.0
var walkers: Array = []
var win_open := false
var win_seen := false
var panel_ui

func _ready() -> void:
	font = ThemeDB.fallback_font
	sim = Sim.new()
	sfx = SfxScript.new()
	add_child(sfx)
	panel_ui = PanelUI.new(self)
	_load_meta()
	sfx.enabled = bool(meta.get("sound", true))
	has_save = FileAccess.file_exists(SAVE_PATH)
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for i in 90:
		stars.append([Vector2(r.randf(), r.randf()), r.randf() * TAU, r.randf_range(0.5, 1.5)])
	for i in 4:
		walkers.append({"x": r.randf_range(0.1, 0.9), "v": r.randf_range(8.0, 14.0) * (1 if i % 2 == 0 else -1)})
	_make_ground()
	get_window().size_changed.connect(_apply_scale)
	_apply_scale()
	if OS.has_feature("web"):
		var h = JavaScriptBridge.eval("location.hash", true)
		if typeof(h) == TYPE_STRING and h.begins_with("#demo"):
			_demo(h)

## Attract/demo mode (used for README screenshots): play a quick scripted
## base-building run, e.g. play/#demo-night or play/#demo-crew.
func _demo(h: String) -> void:
	sim.new_game(7)
	sim.credits += 700.0
	sim.regolith += 400.0
	var plan := [["electrolyzer", 13], ["recycler", 14], ["battery", 4], ["solar", 1], ["lab", 21], ["greenhouse", 9], ["solar", 0],
		["greenhouse", 18], ["battery", 5], ["greenhouse", 17], ["solar", 6], ["roverbay", 19], ["quarters", 22]]
	var target := Sim.SOL_LEN * (3.64 if "night" in h else 3.3)
	var rot := 0
	while sim.t < target:
		sim.tick(1.0)
		sim.harvest_all()
		var opts := []
		for c in Sim.CROP_ORDER:
			if sim.crop_unlocked(c):
				opts.append(c)
		for i in sim.grid.size():
			if sim.grid[i] != null and sim.grid[i]["type"] == "greenhouse":
				rot += 1
				sim.plant_all(i, opts[rot % opts.size()])
		if plan.size() > 0 and sim.build(plan[0][0], plan[0][1]):
			plan.pop_front()
		elif plan.is_empty():
			for i in [4, 5, 9, 10]:
				sim.upgrade(i)
		sim.rover_auto = "ice" if sim.ice < 30 else "reg"
		for r in Sim.RESEARCH:
			sim.research(r["id"])
		if sim.docked():
			for c in Sim.CROP_ORDER:
				if int(sim.stock[c]) > 2:
					sim.sell(c, int(sim.stock[c]) - 2)
		if sim.avg_morale() < 75.0:
			sim.movie_night()
		sim.events.clear()
	sim.power = sim.battery_cap() * 0.8
	_enter_play()
	if "crew" in h:
		tab = "crew"
	elif "lab" in h:
		tab = "lab"
	else:
		sel = 9

func _apply_scale() -> void:
	var ws := Vector2(get_window().size)
	if ws.y > ws.x * 1.05:
		get_tree().root.content_scale_size = Vector2i(400, 720)
	else:
		get_tree().root.content_scale_size = Vector2i(640, 360)
	vs = get_viewport_rect().size
	_layout()

func _layout() -> void:
	vs = get_viewport_rect().size
	portrait = vs.y > vs.x * 1.05
	if portrait:
		L["top"] = Rect2(0, 0, vs.x, 44)
		L["map"] = Rect2(0, 44, vs.x, 352)
		L["panel"] = Rect2(0, 396, vs.x, vs.y - 396)
	else:
		var pw := clampf(vs.x * 0.38, 240.0, 340.0)
		L["top"] = Rect2(0, 0, vs.x, 24)
		L["map"] = Rect2(0, 24, vs.x - pw, vs.y - 24)
		L["panel"] = Rect2(vs.x - pw, 24, pw, vs.y - 24)
	var m: Rect2 = L["map"]
	var gw := TILE * Sim.COLS
	L["grid"] = Vector2(m.position.x + floor((m.size.x - gw) * 0.5), m.position.y + 58)
	L["surface"] = L["grid"].y + TILE * Sim.ROWS + 4

func _make_ground() -> void:
	var w := 320
	var h := 200
	var img := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 1969
	var base := Color("8b8d93")
	for y in h:
		for x in w:
			var n := r.randf_range(-0.05, 0.05)
			var c := base.lightened(n) if n > 0 else base.darkened(-n)
			if r.randf() < 0.02:
				c = c.darkened(0.18)
			img.fill_rect(Rect2i(x * 2, y * 2, 2, 2), c)
	for k in 14:
		var cx := r.randi_range(20, w - 20)
		var cy := r.randi_range(14, h - 14)
		var rad := r.randi_range(4, 11)
		for y in range(-rad, rad + 1):
			for x in range(-rad, rad + 1):
				var d := sqrt(x * x + y * y)
				if d <= rad:
					var c: Color = img.get_pixel((cx + x) * 2, (cy + y) * 2)
					c = c.darkened(0.16) if (x + y) < 0 else c.lightened(0.08)
					if d > rad - 1.2:
						c = c.lightened(0.15) if y > 0 else c.darkened(0.25)
					img.fill_rect(Rect2i((cx + x) * 2, (cy + y) * 2, 2, 2), c)
	ground_tex = ImageTexture.create_from_image(img)

# ------------------------------------------------------------ persistence
func _load_meta() -> void:
	if FileAccess.file_exists(META_PATH):
		var f := FileAccess.open(META_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				meta.merge(d, true)

func _save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))

func save_game() -> void:
	if screen != "play" or sim.game_over != "":
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(sim.to_dict()))
		f.close()
		has_save = true
	meta["best_sol"] = maxi(int(meta["best_sol"]), sim.sol())
	_save_meta()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	return sim.from_dict(d)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if screen == "play":
			save_game()

# ------------------------------------------------------------ flow
func start_new() -> void:
	sim.new_game()
	_enter_play()

func continue_game() -> void:
	if load_game():
		_enter_play()
	else:
		start_new()

func _enter_play() -> void:
	screen = "play"
	paused = false; menu_open = false; speed = 1.0; tab = "base"; sel = -1
	win_open = false; win_seen = sim.festival
	msgs.clear(); particles.clear(); floaters.clear()
	sfx.start_music()
	_drain_events()

func to_title() -> void:
	save_game()
	screen = "title"
	menu_open = false

func toggle_sound() -> void:
	sfx.set_enabled(not sfx.enabled)
	meta["sound"] = sfx.enabled
	_save_meta()
	sfx.play("click")

func say_toast(s: String) -> void:
	toast = s
	toast_t = 3.0

# ------------------------------------------------------------ update
func _process(delta: float) -> void:
	tm += delta
	shake = maxf(0.0, shake - delta * 12.0)
	toast_t = maxf(0.0, toast_t - delta)
	if screen == "play" and not paused and not menu_open and msgs.is_empty() and not win_open:
		var left := delta * speed
		while left > 0.0:
			var step := minf(left, 0.2)
			sim.tick(step)
			left -= step
		_drain_events()
		autosave_t += delta
		if autosave_t > 20.0:
			autosave_t = 0.0
			save_game()
		if sim.o2 < sim.o2_cap() * 0.2:
			alert_t -= delta
			if alert_t <= 0.0:
				alert_t = 4.0
				sfx.play("alert")
		for w in walkers:
			w["x"] += w["v"] * delta / maxf(100.0, L["map"].size.x)
			if w["x"] > 0.95 or w["x"] < 0.05:
				w["v"] = -w["v"]
		for i in sim.rovers.size():
			var r: Dictionary = sim.rovers[i]
			if r["s"] == "out" and sim.storm <= 0.0 and abs(float(r["p"]) - 0.5) < 0.1 and randf() < 0.3:
				_burst(_rover_pos(i), Color("b9b2a6"), 1, 20.0)
	for p in particles:
		p["life"] -= delta
		p["v"].y += p.get("g", 40.0) * delta
		p["p"] += p["v"] * delta
	particles = particles.filter(func(p): return p["life"] > 0.0)
	for f in floaters:
		f["life"] -= delta
		f["p"].y -= 18.0 * delta
	floaters = floaters.filter(func(f): return f["life"] > 0.0)
	for k in tile_pop.keys():
		tile_pop[k] += delta
		if tile_pop[k] > 0.5:
			tile_pop.erase(k)
	if screen == "win" or win_open:
		if randf() < 0.12:
			_firework()
	if screen == "play" and sim.storm > 0.0 and randf() < 0.6:
		var m: Rect2 = L["map"]
		particles.append({"p": Vector2(m.position.x - 10, randf_range(m.position.y, m.end.y)), "v": Vector2(randf_range(160, 260), randf_range(-10, 10)), "life": 2.5, "c": Color(0.8, 0.65, 0.45, 0.5), "s": 2.0, "g": 0.0})
	mouse = get_global_mouse_position()
	queue_redraw()

func _drain_events() -> void:
	for e in sim.events:
		var k: String = e["k"]
		match k:
			"msg": msgs.append(e)
			"ripe": _burst(tile_center(int(e["i"])) + Vector2(0, -8), Color(1, 1, 0.6), 3, 30.0)
			"harvest":
				sfx.play("harvest")
				_burst(tile_center(int(e["i"])), Color("7fe08a"), 8, 60.0)
				floater(tile_center(int(e["i"])), "+1 " + Sim.CROPS[e["c"]]["name"], C_MINT)
			"plant":
				sfx.play("plant")
				_burst(tile_center(int(e["i"])) + Vector2(0, 10), Color("8a6a4a"), 5, 40.0)
			"built", "demolish":
				sfx.play("build")
				shake = 4.0
				tile_pop[int(e["i"])] = 0.0
				_burst(tile_center(int(e["i"])) + Vector2(0, 16), Color("b9b2a6"), 14, 70.0)
			"storm":
				sfx.play("alert"); shake = 7.0
				say_toast("DUST STORM! Solar output down, rovers parked")
			"storm_end": say_toast("The storm has passed. Clear skies!")
			"haul":
				sfx.play("coin")
				floater(_bay_pos(), "+%d %s" % [e["n"], e["what"]], C_CYAN)
			"rover": sfx.play("rover")
			"rocket_in":
				sfx.play("rocket"); say_toast("Supply rocket on approach")
			"docked": say_toast("Rocket docked: TRADE tab is open")
			"rocket_out": sfx.play("rocket")
			"sell":
				sfx.play("coin")
				if int(e["n"]) > 0:
					floater(_pad_pos() + Vector2(0, -30), "+%d cr" % e["n"], C_GOLD)
			"research":
				sfx.play("research"); say_toast("Research complete: " + e["name"])
			"mission":
				sfx.play("mission"); shake = 3.0
				say_toast("Mission complete: %s  (+%d cr)" % [e["title"], e["reward"]])
				for i in 30:
					_burst(Vector2(vs.x * 0.5, 60), Color.from_hsv(randf(), 0.6, 1.0), 1, 160.0)
			"festival":
				sfx.play("fest"); win_open = true; win_seen = true
				meta["festivals"] = int(meta["festivals"]) + 1
				if int(meta["fastest"]) == 0 or sim.sol() < int(meta["fastest"]):
					meta["fastest"] = sim.sol()
				save_game()
			"cheer": sfx.play("harvest")
			"over":
				sfx.play("error"); shake = 8.0
				screen = "over"
				meta["best_sol"] = maxi(int(meta["best_sol"]), sim.sol())
				_save_meta()
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
				has_save = false
	sim.events.clear()

func _burst(at: Vector2, c: Color, n: int, spd: float) -> void:
	for i in n:
		var a := randf() * TAU
		particles.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(0.3, 1.0) * spd, "life": randf_range(0.4, 0.9), "c": c, "s": 2.0})

func _firework() -> void:
	var at := Vector2(randf_range(vs.x * 0.15, vs.x * 0.85), randf_range(40, vs.y * 0.4))
	var c := Color.from_hsv(randf(), 0.7, 1.0)
	for i in 24:
		var a := i / 24.0 * TAU
		particles.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(50, 90), "life": 1.2, "c": c, "s": 2.0, "g": 30.0})

func floater(at: Vector2, s: String, c: Color) -> void:
	floaters.append({"p": at, "s": s, "c": c, "life": 1.4})

# ------------------------------------------------------------ geometry
func tile_rect(i: int) -> Rect2:
	var g: Vector2 = L["grid"]
	return Rect2(g.x + (i % Sim.COLS) * TILE, g.y + (i / Sim.COLS) * TILE, TILE, TILE)

func tile_center(i: int) -> Vector2:
	return tile_rect(i).get_center()

func _first(type: String) -> int:
	for i in sim.grid.size():
		if sim.grid[i] != null and sim.grid[i]["type"] == type:
			return i
	return -1

func _bay_pos() -> Vector2:
	var i := _first("roverbay")
	return tile_rect(i).position + Vector2(24, 40) if i >= 0 else Vector2(L["map"].get_center().x, L["surface"])

func _pad_pos() -> Vector2:
	var i := _first("pad")
	return tile_rect(i).position + Vector2(24, 36) if i >= 0 else Vector2.ZERO

func _site(tg: String) -> Vector2:
	var m: Rect2 = L["map"]
	var y: float = L["surface"] + 34
	return Vector2(m.position.x + 38, y) if tg == "ice" else Vector2(m.end.x - 38, y)

func _rover_pos(i: int) -> Vector2:
	var r: Dictionary = sim.rovers[i]
	var p := float(r["p"])
	var a := _bay_pos()
	var road := Vector2(a.x, L["surface"] + 16)
	var b := _site(r["tg"])
	var leg := p / 0.4 if p < 0.4 else (1.0 if p < 0.6 else (1.0 - p) / 0.4)
	leg = clampf(leg, 0.0, 1.0)
	if leg < 0.25:
		return a.lerp(road, leg / 0.25)
	return road.lerp(b, (leg - 0.25) / 0.75)

func hit_tile(p: Vector2) -> int:
	var g: Vector2 = L["grid"]
	var x := int(floor((p.x - g.x) / TILE))
	var y := int(floor((p.y - g.y) / TILE))
	if x < 0 or y < 0 or x >= Sim.COLS or y >= Sim.ROWS:
		return -1
	return y * Sim.COLS + x

# ------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		kb_used = false
		_click(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)

func _click(p: Vector2) -> void:
	for i in range(btns.size() - 1, -1, -1):
		var b: Dictionary = btns[i]
		if b["r"].has_point(p):
			if b["en"]:
				sfx.play("click")
				b["f"].call()
				_drain_events()
			else:
				sfx.play("error")
			return
	if screen == "play" and msgs.is_empty() and not menu_open and not win_open:
		var t := hit_tile(p)
		if t >= 0:
			tile_action(t)
		elif L["map"].has_point(p):
			sel = -1

func tile_action(t: int) -> void:
	cursor = Vector2i(t % Sim.COLS, t / Sim.COLS)
	var m = sim.grid[t]
	tab = "base"
	if m != null and m["type"] == "greenhouse" and sel == t:
		if sim.harvest_all(t) == 0:
			sim.plant_all(t, seed_choice)
		_drain_events()
	elif m != null and m["type"] == "greenhouse" and sim.harvest_all(t) > 0:
		_drain_events()
	sel = t
	sfx.play("click")

func _key(k: int) -> void:
	_key_inner(k)
	_drain_events()

func _key_inner(k: int) -> void:
	kb_used = true
	if not msgs.is_empty():
		if k in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_KP_ENTER, KEY_E]:
			dismiss_msg()
		return
	if win_open:
		if k in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			win_open = false
		return
	match screen:
		"title":
			if k in [KEY_ENTER, KEY_SPACE]:
				if has_save:
					continue_game()
				else:
					start_new()
			elif k == KEY_H:
				screen = "howto"
			elif k == KEY_M:
				toggle_sound()
			return
		"howto":
			screen = "title"
			return
		"over":
			if k in [KEY_ENTER, KEY_SPACE, KEY_R]:
				start_new()
			elif k == KEY_ESCAPE:
				screen = "title"
			return
	if k == KEY_ESCAPE or k == KEY_P:
		menu_open = not menu_open
		if menu_open:
			save_game()
		return
	if menu_open:
		return
	match k:
		KEY_SPACE: paused = not paused
		KEY_F: cycle_speed()
		KEY_M: toggle_sound()
		KEY_H: sim.harvest_all()
		KEY_1: tab = "base"
		KEY_2: tab = "crew"
		KEY_3: tab = "lab"
		KEY_4: tab = "goals"
		KEY_5: tab = "trade"
		KEY_LEFT, KEY_A: _move_cursor(-1, 0)
		KEY_RIGHT, KEY_D: _move_cursor(1, 0)
		KEY_UP, KEY_W: _move_cursor(0, -1)
		KEY_DOWN, KEY_S: _move_cursor(0, 1)
		KEY_Q: _cycle(-1)
		KEY_E: _cycle(1)
		KEY_ENTER, KEY_KP_ENTER:
			var t := cursor.y * Sim.COLS + cursor.x
			if sel == t and sim.grid[t] == null:
				var ty: String = Sim.BUILD_ORDER[build_hl]
				if not sim.build(ty, t):
					sfx.play("error")
				_drain_events()
			else:
				tile_action(t)
		KEY_U:
			if sel >= 0 and sim.grid[sel] != null and not sim.upgrade(sel):
				sfx.play("error")
			_drain_events()

func _move_cursor(dx: int, dy: int) -> void:
	cursor.x = clampi(cursor.x + dx, 0, Sim.COLS - 1)
	cursor.y = clampi(cursor.y + dy, 0, Sim.ROWS - 1)
	sel = cursor.y * Sim.COLS + cursor.x
	tab = "base"

func _cycle(d: int) -> void:
	if sel >= 0 and sim.grid[sel] == null:
		build_hl = posmod(build_hl + d, Sim.BUILD_ORDER.size())
	else:
		var opts := []
		for c in Sim.CROP_ORDER:
			if sim.crop_unlocked(c):
				opts.append(c)
		seed_choice = opts[posmod(opts.find(seed_choice) + d, opts.size())]

func open_menu() -> void:
	menu_open = true
	save_game()

func cycle_speed() -> void:
	speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
	paused = false

func dismiss_msg() -> void:
	if not msgs.is_empty():
		msgs.pop_front()
		sfx.play("click")

# ------------------------------------------------------------ draw helpers
func fs(size: int) -> int:
	return size + (2 if portrait and size < 14 and screen != "title" else 0)

func txt(p: Vector2, s: String, size: int = 10, c: Color = C_INK, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	size = fs(size)
	draw_string(font, Vector2(p.x, p.y + font.get_ascent(size)), s, align, w, size, c)

func wrap(p: Vector2, s: String, w: float, size: int = 10, c: Color = C_INK, lines: int = -1) -> void:
	size = fs(size)
	draw_multiline_string(font, Vector2(p.x, p.y + font.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, lines, c)

func box(r: Rect2, fill: Color, line: Color = C_LINE) -> void:
	draw_rect(r, fill)
	draw_rect(r, line, false, 1.0)

func button(r: Rect2, label: String, f: Callable, en: bool = true, accent: Color = Color("2b4a86"), size: int = 10) -> void:
	var hov := r.has_point(mouse) and en
	var fill := accent if en else Color("232a3a")
	if hov:
		fill = fill.lightened(0.18)
	draw_rect(Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.18 if en else 0.05))
	draw_rect(r, fill.lightened(0.3) if en else Color("343c50"), false, 1.0)
	var c := C_INK if en else Color("6b7488")
	txt(Vector2(r.position.x, r.position.y + (r.size.y - font.get_height(fs(size))) * 0.5), label, size, c, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	btns.append({"r": r, "f": f, "en": en})

func bar(r: Rect2, f: float, c: Color) -> void:
	draw_rect(r, Color("0a0f1c"))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y)), c)
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)

# ------------------------------------------------------------ draw
func _draw() -> void:
	btns.clear()
	draw_rect(Rect2(Vector2.ZERO, vs), C_BG)
	var off := Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.0 else Vector2.ZERO
	draw_set_transform(off)
	match screen:
		"title", "howto":
			_draw_title()
		_:
			_draw_world()
			draw_set_transform(Vector2.ZERO)
			_draw_top()
			panel_ui.draw_panel()
	draw_set_transform(Vector2.ZERO)
	for p in particles:
		draw_rect(Rect2(p["p"] - Vector2.ONE * p["s"] * 0.5, Vector2.ONE * p["s"]), Color(p["c"], clampf(p["life"] * 2.0, 0.0, 1.0) * p["c"].a))
	for f in floaters:
		txt(f["p"] + Vector2(-60, 1), f["s"], 10, Color(0, 0, 0, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 120)
		txt(f["p"] + Vector2(-60, 0), f["s"], 10, Color(f["c"], clampf(f["life"], 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 120)
	if screen == "play":
		if toast_t > 0.0:
			var w := minf(vs.x - 20, 360.0)
			var r := Rect2(L["map"].get_center().x - w * 0.5, L["map"].position.y + (28 if portrait else 6), w, 20)
			r.position.x = clampf(r.position.x, 10, vs.x - w - 10)
			box(r, Color(0.05, 0.08, 0.16, 0.92), C_GOLD)
			txt(r.position + Vector2(0, 4), toast, 10, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
		if not msgs.is_empty():
			panel_ui.draw_msg(msgs[0])
		elif win_open:
			panel_ui.draw_win()
		elif menu_open:
			panel_ui.draw_menu()
	elif screen == "over":
		panel_ui.draw_over()
	if screen == "howto":
		panel_ui.draw_howto()

func _draw_sky(r: Rect2, earth_pos: Vector2) -> void:
	draw_rect(r, Color("05060d"))
	for s in stars:
		var p := r.position + Vector2(s[0].x * r.size.x, s[0].y * r.size.y)
		var a: float = 0.4 + 0.6 * absf(sin(tm * s[2] + s[1]))
		draw_rect(Rect2(p, Vector2(1, 1) * (2 if s[2] > 1.3 else 1)), Color(1, 1, 1, a))
	Art.earth(self, earth_pos, 11)

func _draw_world() -> void:
	var m: Rect2 = L["map"]
	var g: Vector2 = L["grid"]
	var surf: float = L["surface"]
	var horizon: float = g.y - 18
	_draw_sky(Rect2(m.position, Vector2(m.size.x, horizon - m.position.y + 2)), Vector2(m.position.x + 30, m.position.y + 22))
	# sun arc
	var lt: float = sim.light()
	if not sim.is_night():
		var ph: float = sim.day_phase() / 0.55
		var sp := Vector2(m.position.x + 60 + ph * (m.size.x - 120), horizon - 6 - sin(ph * PI) * 28)
		draw_circle(sp, 11, Color(1, 0.95, 0.7, 0.18))
		draw_circle(sp, 6, Color("fff3c4"))
	# ground
	var gr := Rect2(m.position.x, horizon, m.size.x, m.end.y - horizon)
	draw_texture_rect(ground_tex, gr, true)
	draw_rect(Rect2(m.position.x, horizon, m.size.x, 2), Color("b9bcc4"))
	for k in 6:
		var hx := m.position.x + k * m.size.x / 5.0
		draw_rect(Rect2(hx - 30, horizon - 4 + (k % 2) * 2, 60, 4), Color("6d7078"))
	draw_rect(gr, Color(0.03, 0.04, 0.12, 0.55 * (1.0 - lt)))
	# sites: ice crater and regolith mound
	var ice_p := _site("ice")
	draw_circle(ice_p, 18, Color("5b6170"))
	draw_circle(ice_p, 14, Color("9fd4ef"))
	draw_circle(ice_p + Vector2(-4, -3), 5, Color("e6f7ff"))
	txt(ice_p + Vector2(-30, 18), "ICE CRATER", 8, C_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 60)
	var reg_p := _site("reg")
	draw_colored_polygon(PackedVector2Array([reg_p + Vector2(-20, 10), reg_p + Vector2(-6, -12), reg_p + Vector2(8, -6), reg_p + Vector2(22, 10)]), Color("a49a8a"))
	draw_rect(Rect2(reg_p + Vector2(-20, 8), Vector2(42, 3)), Color("7c7366"))
	txt(reg_p + Vector2(-30, 18), "REGOLITH", 8, Color("e0cfae"), HORIZONTAL_ALIGNMENT_CENTER, 60)
	# road
	draw_rect(Rect2(m.position.x + 38, surf + 14, m.size.x - 76, 4), Color(0.25, 0.26, 0.3, 0.6))
	# plots and modules
	var ctx := {"time": tm, "night": sim.is_night(), "powered": sim.powered, "storm": sim.storm,
		"battery": sim.power / sim.battery_cap()}
	var idle := 0
	for r in sim.rovers:
		if r["s"] == "idle":
			idle += 1
	ctx["idle_rovers"] = idle
	for i in sim.grid.size():
		if sim.grid[i] == null:
			continue
		var tp := tile_rect(i).position
		if i % Sim.COLS < Sim.COLS - 1 and sim.grid[i + 1] != null:
			draw_rect(Rect2(tp + Vector2(36, 32), Vector2(24, 7)), Color("aeb5c2"))
			draw_rect(Rect2(tp + Vector2(36, 32), Vector2(24, 2)), Color("e1e5ec"))
			draw_rect(Rect2(tp + Vector2(47, 32), Vector2(2, 7)), Color("6d7383"))
		if i + Sim.COLS < sim.grid.size() and sim.grid[i + Sim.COLS] != null:
			draw_rect(Rect2(tp + Vector2(20, 44), Vector2(8, 10)), Color("aeb5c2"))
			draw_rect(Rect2(tp + Vector2(20, 44), Vector2(2, 10)), Color("e1e5ec"))
	for i in sim.grid.size():
		var tr := tile_rect(i)
		var md = sim.grid[i]
		if md == null:
			var c := Color(0.0, 0.0, 0.05, 0.16)
			var q := tr.grow(-5)
			draw_rect(q, c)
			var lc := Color(1, 1, 1, 0.22)
			var x0 := q.position.x
			var y0 := q.position.y
			var x1 := q.end.x
			var y1 := q.end.y
			for seg in [Rect2(x0, y0, 6, 1), Rect2(x0, y0, 1, 6), Rect2(x1 - 6, y0, 6, 1), Rect2(x1 - 1, y0, 1, 6),
					Rect2(x0, y1 - 1, 6, 1), Rect2(x0, y1 - 6, 1, 6), Rect2(x1 - 6, y1 - 1, 6, 1), Rect2(x1 - 1, y1 - 6, 1, 6)]:
				draw_rect(seg, lc)
			continue
		var o := tr.position
		if tile_pop.has(i):
			var a: float = tile_pop[i]
			o.y -= sin(a / 0.5 * PI) * 6.0
		if md["type"] == "greenhouse":
			ctx["trays"] = md["trays"]
		Art.module(self, md["type"], o, int(md["lvl"]), ctx)
	# rocket
	var pad := _first("pad")
	if pad >= 0 and sim.rocket.get("state", "away") != "away":
		var rp := _pad_pos()
		var st: String = sim.rocket["state"]
		var rt: float = sim.rocket["t"]
		var alt := 0.0
		if st == "landing":
			alt = pow(rt / 4.0, 2.0) * 260.0
		elif st == "launching":
			alt = pow(1.0 - rt / 4.0, 2.0) * 320.0
		var thrust := st != "docked"
		Art.rocket(self, rp + Vector2(0, -alt), tm, thrust)
		if thrust and alt < 40.0:
			_burst(rp + Vector2(randf_range(-16, 16), 4), Color("c9c2b4"), 1, 50.0)
	# rovers
	for i in sim.rovers.size():
		var r: Dictionary = sim.rovers[i]
		if r["s"] == "out":
			var p := float(r["p"])
			var flip: bool = (r["tg"] == "ice") == (p < 0.5)
			Art.rover(self, _rover_pos(i), flip, tm)
	# crew walking outside on EVA during the day
	if not sim.is_night():
		for i in walkers.size():
			var w: Dictionary = walkers[i]
			var d: Dictionary = Sim.CREW_DEF[i]
			var wp := Vector2(m.position.x + w["x"] * m.size.x, surf + 2 + i % 2 * 4)
			Art.astronaut(self, wp, Color(d["visor"]), Color(d["suit"]), int(tm * 6.0 + i), 0.7)
	# lighting overlays
	draw_rect(Rect2(m.position.x, horizon, m.size.x, m.end.y - horizon), Color(0.03, 0.04, 0.14, 0.25 * (1.0 - lt)))
	if sim.storm > 0.0:
		draw_rect(m, Color(0.55, 0.4, 0.25, 0.28 + 0.05 * sin(tm * 3.0)))
	if sim.o2 < sim.o2_cap() * 0.2 and fmod(tm, 1.0) < 0.5:
		draw_rect(m, C_RED, false, 3.0)
	# selection & cursor
	if sel >= 0:
		var sr := tile_rect(sel).grow(-1)
		var pulse := 0.6 + 0.4 * sin(tm * 6.0)
		draw_rect(sr, Color(C_GOLD, pulse), false, 2.0)
		if sim.grid[sel] == null:
			txt(sr.position + Vector2(0, 14), "+", 18, Color(C_GOLD, pulse), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x)
	if kb_used:
		draw_rect(tile_rect(cursor.y * Sim.COLS + cursor.x).grow(-3), Color(1, 1, 1, 0.6), false, 1.0)
	var ready: int = sim.ready_trays()
	if ready > 0:
		for i in sim.grid.size():
			var md = sim.grid[i]
			if md != null and md["type"] == "greenhouse":
				for tr in md["trays"]:
					if tr["c"] != "" and float(tr["g"]) >= 1.0:
						var bp := tile_rect(i).position + Vector2(36, -2 + sin(tm * 4.0) * 2)
						draw_circle(bp + Vector2(4, 4), 6, C_MINT)
						txt(bp + Vector2(0, -2), "!", 10, Color("0b2a14"), HORIZONTAL_ALIGNMENT_CENTER, 8)
						break
	# status line at bottom of map
	var info := "Sol %d · %s · %s" % [sim.sol(), "Night" if sim.is_night() else "Day", "PAUSED" if paused else "%dx" % int(speed)]
	txt(Vector2(m.position.x + 6, m.end.y - 14), info, 9, C_DIM)

func _draw_top() -> void:
	var r: Rect2 = L["top"]
	box(r, Color("0c1222"), C_LINE)
	var items := [
		["O2", sim.o2, sim.o2_cap(), C_CYAN], ["H2O", sim.water, sim.water_cap(), Color("4f8fe8")],
		["PWR", sim.power, sim.battery_cap(), C_GOLD], ["FOOD", sim.food, 100.0, C_MINT],
		["ICE", sim.ice, -1.0, Color("c8ecff")], ["REG", sim.regolith, -1.0, Color("c9b28f")],
		["CR", sim.credits, -1.0, Color("ffd56b")], ["RP", sim.rp, -1.0, Color("c9a2ff")],
	]
	var ctrl_w := 4 * 26.0
	var row_w := r.size.x - (0.0 if portrait else ctrl_w)
	var per := 4 if portrait else 8
	var iw := row_w / per
	for i in items.size():
		var it: Array = items[i]
		var x := r.position.x + (i % per) * iw + 4
		var y := r.position.y + 3 + (i / per) * 20 if portrait else r.position.y + 3
		if portrait and i >= 4:
			y = r.position.y + 23
		var low: bool = it[2] > 0 and float(it[1]) < float(it[2]) * 0.2
		var c: Color = it[3]
		if low and fmod(tm, 0.8) < 0.4:
			c = C_RED
		draw_rect(Rect2(x, y + 2, 6, 6), c)
		txt(Vector2(x + 9, y), "%s %d" % [it[0], int(it[1])], 9, C_INK if not low else C_RED)
		if it[2] > 0:
			bar(Rect2(x + 9, y + 13, iw - 18, 3), float(it[1]) / float(it[2]), c)
	# controls (landscape: right of top bar; portrait: overlaid on the map's top-right)
	var cx: float = r.end.x - ctrl_w if not portrait else L["map"].end.x - ctrl_w - 2
	var cy: float = r.position.y + 2 if not portrait else L["map"].position.y + 2
	var bw := 24.0
	button(Rect2(cx, cy, bw, 20), "", func(): paused = not paused)
	_icon_pause(Rect2(cx, cy, bw, 20))
	button(Rect2(cx + 26, cy, bw, 20), "%dx" % int(speed), cycle_speed)
	button(Rect2(cx + 52, cy, bw, 20), "", toggle_sound)
	_icon_sound(Rect2(cx + 52, cy, bw, 20))
	button(Rect2(cx + 78, cy, bw, 20), "", open_menu)
	var mr := Rect2(cx + 78, cy, bw, 20)
	for k in 3:
		draw_rect(Rect2(mr.position + Vector2(7, 6 + k * 3), Vector2(10, 1.5)), C_INK)

func _icon_pause(r: Rect2) -> void:
	var c := r.get_center()
	if paused:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -5), c + Vector2(5, 0), c + Vector2(-3, 5)]), C_MINT)
	else:
		draw_rect(Rect2(c + Vector2(-4, -5), Vector2(3, 10)), C_INK)
		draw_rect(Rect2(c + Vector2(1, -5), Vector2(3, 10)), C_INK)

func _icon_sound(r: Rect2) -> void:
	var c := r.get_center()
	draw_rect(Rect2(c + Vector2(-6, -2), Vector2(3, 4)), C_INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -2), c + Vector2(1, -5), c + Vector2(1, 5), c + Vector2(-3, 2)]), C_INK)
	if sfx.enabled:
		draw_arc(c + Vector2(1, 0), 4, -0.9, 0.9, 6, C_INK, 1.0)
	else:
		draw_line(c + Vector2(3, -3), c + Vector2(7, 3), C_RED, 1.5)
		draw_line(c + Vector2(7, -3), c + Vector2(3, 3), C_RED, 1.5)

func _draw_title() -> void:
	_draw_sky(Rect2(Vector2.ZERO, vs), Vector2(vs.x * 0.78, vs.y * 0.22))
	var hz := vs.y * 0.68
	draw_texture_rect(ground_tex, Rect2(0, hz, vs.x, vs.y - hz), true)
	draw_rect(Rect2(0, hz, vs.x, 2), Color("c9ccd4"))
	draw_rect(Rect2(0, hz, vs.x, vs.y - hz), Color(0.02, 0.03, 0.1, 0.35))
	# a little base on the horizon
	var bx := vs.x * 0.5 - 96
	var demo := [{"c": "lettuce", "g": 1.0}, {"c": "tomato", "g": 0.8}, {"c": "moonberry", "g": 1.0}, {"c": "wheat", "g": 1.0}]
	var ctx := {"time": tm, "night": true, "powered": true, "trays": demo, "battery": 0.8, "idle_rovers": 1}
	var row := ["solar", "greenhouse", "hub", "greenhouse", "quarters"]
	for i in row.size():
		Art.module(self, row[i], Vector2(bx + i * TILE - 24, hz - 40), 1, ctx)
	Art.rocket(self, Vector2(bx + 5 * TILE + 8, hz + 4 - absf(sin(tm * 0.4)) * 6.0), tm, true)
	var ty := vs.y * (0.2 if portrait else 0.12)
	var title_size := 40 if vs.x > 420 else 34
	for k in 2:
		var o := Vector2(3, 3) if k == 0 else Vector2.ZERO
		var c := Color("1d2f6b") if k == 0 else C_MINT
		txt(Vector2(0, ty) + o, "MOONFARM", title_size, c, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	txt(Vector2(0, ty + title_size + 6), "Grow the first garden on the Moon", 11, C_INK, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if screen == "howto":
		return
	var bw := 210.0 if portrait else 150.0
	var bh := 32.0 if portrait else 22.0
	var gap := bh + 8.0
	var bs := 14 if portrait else 11
	var x := vs.x * 0.5 - bw * 0.5
	var y := ty + title_size + 30
	if has_save:
		button(Rect2(x, y, bw, bh + 2), "Continue", continue_game, true, Color("2f7a4a"), bs)
		y += gap + 2
		button(Rect2(x, y, bw, bh), "New game", start_new, true, Color("2b4a86"), bs)
	else:
		button(Rect2(x, y, bw, bh + 2), "Start mission", start_new, true, Color("2f7a4a"), bs)
		y += 2
	y += gap
	button(Rect2(x, y, bw, bh), "How to play", func(): screen = "howto", true, Color("2b4a86"), bs)
	y += gap
	button(Rect2(x, y, bw, bh), "Sound: " + ("On" if sfx.enabled else "Off"), toggle_sound, true, Color("2b4a86"), bs)
	var best := "Best: Sol %d" % int(meta["best_sol"])
	if int(meta["festivals"]) > 0:
		best += " · Festivals held: %d (fastest Sol %d)" % [int(meta["festivals"]), int(meta["fastest"])]
	txt(Vector2(0, vs.y - 30), best, 11 if portrait else 9, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	txt(Vector2(0, vs.y - 16), "Made by Jaineil Rana (JaKing) · JaiGod", 11 if portrait else 9, C_DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
