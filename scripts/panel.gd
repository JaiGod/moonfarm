extends RefCounted
## Side/bottom management panel plus modal overlays, drawn immediate-mode
## through the main scene's draw helpers (button/txt/box/bar).

const Sim = preload("res://scripts/sim.gd")
const Art = preload("res://scripts/art.gd")
const TABS := [["base", "BASE"], ["crew", "CREW"], ["lab", "LAB"], ["goals", "GOALS"], ["trade", "TRADE"]]

var m

func _init(main) -> void:
	m = main

func draw_panel() -> void:
	var r: Rect2 = m.L["panel"]
	m.box(r, m.C_PANEL, m.C_LINE)
	var tw := (r.size.x - 8) / TABS.size()
	for i in TABS.size():
		var id: String = TABS[i][0]
		var label: String = TABS[i][1]
		if id == "trade" and m.sim.docked():
			label = "TRADE!"
		var acc := Color("3a5ea8") if m.tab == id else Color("1b2742")
		if id == "trade" and m.sim.docked() and m.tab != id and fmod(m.tm, 1.0) < 0.5:
			acc = Color("7a5a1a")
		m.button(Rect2(r.position.x + 4 + i * tw, r.position.y + 4, tw - 3, 20), label, func(): m.tab = id, true, acc, 9)
	var c := Rect2(r.position.x + 8, r.position.y + 30, r.size.x - 16, r.size.y - 36)
	match m.tab:
		"base": _base(c)
		"crew": _crew(c)
		"lab": _lab(c)
		"goals": _goals(c)
		"trade": _trade(c)

func _h(p: Vector2, s: String, w: float) -> void:
	m.txt(p, s, 12, m.C_GOLD)
	m.draw_rect(Rect2(p.x, p.y + 16, w, 1), m.C_LINE)

func _cost(c: Array) -> String:
	return "%dcr %dreg" % [c[0], c[1]]

# ------------------------------------------------------------ BASE
func _base(c: Rect2) -> void:
	var s = m.sim
	var x := c.position.x
	var y := c.position.y
	var w := c.size.x
	if m.sel < 0:
		_h(Vector2(x, y), "Tranquil Basin Base", w)
		y += 22
		m.wrap(Vector2(x, y), "Tap a module on the map to manage it, or tap an empty plot to build.", w, 9, m.C_DIM)
		y += 30
		var lines := [
			"Solar %.1f kW  ·  Use %.1f kW%s" % [s.gen_now, s.use_now, "" if s.powered else "  BROWNOUT"],
			"Battery %d / %d kWh" % [int(s.power), int(s.battery_cap())],
			"Oxygen %d / %d   Water %d / %d" % [int(s.o2), int(s.o2_cap()), int(s.water), int(s.water_cap())],
			"Pantry %d food  ·  Crates %d" % [int(s.food), s.total_crates()],
			"Rovers %d  ·  Crew morale %d%%" % [s.rovers.size(), int(s.avg_morale())],
		]
		for l in lines:
			m.txt(Vector2(x, y), l, 9, Color("ff8a7a") if "BROWNOUT" in l else m.C_INK)
			y += 14
		y += 6
		var rd: int = s.ready_trays()
		m.button(Rect2(x, y, w, 22), "Harvest all ready (%d)" % rd, func(): s.harvest_all(), rd > 0, Color("2f7a4a"))
		y += 28
		if s.mission < Sim.MISSIONS.size():
			m.box(Rect2(x, y, w, 40), Color("0c1424"))
			m.txt(Vector2(x + 6, y + 4), "Goal: " + Sim.MISSIONS[s.mission]["goal"], 9, m.C_GOLD)
			m.txt(Vector2(x + 6, y + 20), s.mission_progress(), 9, m.C_DIM)
		return
	var md = s.grid[m.sel]
	if md == null:
		_build_list(Rect2(x, y, w, c.size.y))
		return
	var def: Dictionary = Sim.MODULES[md["type"]]
	var lvl := int(md["lvl"])
	_h(Vector2(x, y), "%s  Lv %d" % [def["name"], lvl], w)
	y += 20
	m.wrap(Vector2(x, y), def["desc"], w, 9, m.C_DIM, 2)
	y += 26
	var uc: Array = s.upgrade_cost(m.sel)
	var half := (w - 4) * 0.5
	if lvl < Sim.MAX_LVL:
		m.button(Rect2(x, y, half, 20), "Upgrade " + _cost(uc), func(): s.upgrade(m.sel), s.can_afford(uc), Color("2b4a86"), 8)
	else:
		m.button(Rect2(x, y, half, 20), "Max level", func(): pass, false)
	var fixed: bool = md["type"] == "hub" or md["type"] == "pad"
	m.button(Rect2(x + half + 4, y, half, 20), "Recycle module", func(): s.demolish(m.sel), not fixed, Color("6a2a32"), 8)
	y += 28
	match md["type"]:
		"greenhouse": _greenhouse(Rect2(x, y, w, c.end.y - y), md)
		"roverbay": _roverbay(Rect2(x, y, w, c.end.y - y))
		"pad":
			var st: String = s.rocket.get("state", "away")
			var info := "Next supply rocket in %ds" % int(s.rocket["t"]) if st == "away" else "Rocket %s (%ds)" % [st, int(s.rocket["t"])]
			m.txt(Vector2(x, y), info, 10)
			y += 18
			m.button(Rect2(x, y, w, 22), "Open TRADE", func(): m.tab = "trade")
		"lab":
			m.txt(Vector2(x, y), "Research points: %.1f" % s.rp, 10)
			y += 18
			m.button(Rect2(x, y, w, 22), "Open LAB", func(): m.tab = "lab")
		"solar":
			m.txt(Vector2(x, y), "Output now: %.1f kW (sunlight %d%%)" % [5.0 * lvl * s.light(), int(s.light() * 100)], 9)
		"battery":
			m.txt(Vector2(x, y), "Stored: %d / %d kWh" % [int(s.power), int(s.battery_cap())], 9)
		"electrolyzer":
			m.txt(Vector2(x, y), "Makes %.1f O2/s, drinks %.2f water/s" % [1.0 * lvl, 0.25 * lvl], 9)
		"recycler":
			m.txt(Vector2(x, y), "Ice in storage: %d (melts into water)" % int(s.ice), 9)
		"quarters":
			m.txt(Vector2(x, y), "Average crew morale: %d%%" % int(s.avg_morale()), 9)
		"hub":
			m.txt(Vector2(x, y), "Sol %d. All systems %s." % [s.sol(), "nominal" if s.powered else "on low power"], 9)

func _build_list(c: Rect2) -> void:
	var s = m.sim
	_h(c.position, "Build on this plot", c.size.x)
	var y := c.position.y + 22
	var rh := minf(26.0, (c.size.y - 26) / Sim.BUILD_ORDER.size())
	for i in Sim.BUILD_ORDER.size():
		var ty: String = Sim.BUILD_ORDER[i]
		var d: Dictionary = Sim.MODULES[ty]
		var cost: Array = s.build_cost(ty)
		var acc := Color("2b4a86") if not (m.kb_used and m.build_hl == i) else Color("4a6ec0")
		var label := "%s   %s" % [d["name"], _cost(cost)]
		m.button(Rect2(c.position.x, y, c.size.x, rh - 3), label, func(): s.build(ty, m.sel), s.can_afford(cost), acc, 9)
		y += rh

func _greenhouse(c: Rect2, md: Dictionary) -> void:
	var s = m.sim
	var x := c.position.x
	var y := c.position.y
	var w := c.size.x
	m.txt(Vector2(x, y), "Seed:", 9, m.C_DIM)
	y += 15 if m.portrait else 13
	var opts := []
	for cr in Sim.CROP_ORDER:
		if s.crop_unlocked(cr):
			opts.append(cr)
	var cols := 4
	var cw := (w - (cols - 1) * 3) / cols
	for i in opts.size():
		var cr: String = opts[i]
		var r := Rect2(x + (i % cols) * (cw + 3), y + (i / cols) * 22, cw, 19)
		var acc := Color("3f8a52") if m.seed_choice == cr else Color("1b2742")
		var nm: String = Sim.CROPS[cr]["name"].split(" ")[-1]
		m.button(r, "%s %d" % [nm, Sim.CROPS[cr]["seed"]], func(): m.seed_choice = cr, true, acc, 8)
	y += ceili(opts.size() / float(cols)) * 22 + 2
	var sc: Dictionary = Sim.CROPS[m.seed_choice]
	m.txt(Vector2(x, y), "%s: %ds grow · %d food · sells ~%dcr" % [sc["name"], int(sc["time"]), sc["food"], sc["price"]], 8, m.C_DIM)
	y += 14
	var trays: Array = md["trays"]
	for k in trays.size():
		var tr: Dictionary = trays[k]
		var r := Rect2(x, y, w, 20)
		var kk: int = k
		if tr["c"] == "":
			m.button(r, "Tray %d: empty · plant %s" % [k + 1, sc["name"]], func(): s.plant(m.sel, kk, m.seed_choice), s.credits >= sc["seed"], Color("1b2742"), 9)
		elif float(tr["g"]) >= 1.0:
			m.button(r, "Tray %d: %s READY · harvest" % [k + 1, Sim.CROPS[tr["c"]]["name"]], func(): s.harvest(m.sel, kk), true, Color("2f7a4a"), 9)
		else:
			m.box(r, Color("0c1424"))
			m.bar(Rect2(x + 2, y + 15, w - 4, 3), float(tr["g"]), m.C_MINT)
			var why := "" if s.powered and s.water > 0 else "  (paused: no %s)" % ("power" if not s.powered else "water")
			m.txt(Vector2(x + 6, y + 2), "Tray %d: %s %d%%%s" % [k + 1, Sim.CROPS[tr["c"]]["name"], int(float(tr["g"]) * 100), why], 9, m.C_INK if why == "" else Color("ff8a7a"))
		y += 23
	var half := (w - 4) * 0.5
	var empty := 0
	for tr in trays:
		if tr["c"] == "":
			empty += 1
	m.button(Rect2(x, y, half, 20), "Plant all (%dcr)" % (empty * int(sc["seed"])), func(): s.plant_all(m.sel, m.seed_choice), empty > 0 and s.credits >= sc["seed"], Color("3f8a52"), 9)
	m.button(Rect2(x + half + 4, y, half, 20), "Harvest dome", func(): s.harvest_all(m.sel), true, Color("2f7a4a"), 9)

func _roverbay(c: Rect2) -> void:
	var s = m.sim
	var x := c.position.x
	var y := c.position.y
	var w := c.size.x
	for i in s.rovers.size():
		var r: Dictionary = s.rovers[i]
		var st := "parked" if r["s"] == "idle" else ("hauling %s %d%%" % [r["tg"], int(float(r["p"]) * 100)])
		if s.storm > 0.0 and r["s"] != "idle":
			st += " (storm hold)"
		m.txt(Vector2(x, y), "Rover %d: %s" % [i + 1, st], 9)
		y += 14
	y += 4
	var half := (w - 4) * 0.5
	var free := false
	for r in s.rovers:
		if r["s"] == "idle":
			free = true
	m.button(Rect2(x, y, half, 22), "Send to Ice", func(): s.dispatch_any("ice"), free and s.storm <= 0.0, Color("2b6a96"), 9)
	m.button(Rect2(x + half + 4, y, half, 22), "Send to Regolith", func(): s.dispatch_any("reg"), free and s.storm <= 0.0, Color("7a6a4a"), 9)
	y += 28
	var nxt := {"": "ice", "ice": "reg", "reg": ""}
	var lab := {"": "Off", "ice": "Ice", "reg": "Regolith"}
	m.button(Rect2(x, y, w, 22), "Auto-dispatch: " + lab[s.rover_auto], func(): s.rover_auto = nxt[s.rover_auto], true, Color("3a5ea8") if s.rover_auto != "" else Color("1b2742"), 9)
	y += 28
	m.wrap(Vector2(x, y), "Trips take 24s. Ice feeds the Water Recycler; regolith builds modules. Upgrade the bay for more rovers.", w, 8, m.C_DIM)

# ------------------------------------------------------------ CREW
func _crew(c: Rect2) -> void:
	var s = m.sim
	var x := c.position.x
	var y := c.position.y
	var w := c.size.x
	var ch := minf(62.0, (c.size.y - 30) / 4.0)
	for i in s.crew.size():
		var d: Dictionary = Sim.CREW_DEF[i]
		var cr: Dictionary = s.crew[i]
		var r := Rect2(x, y, w, ch - 4)
		m.box(r, Color("0c1424"))
		Art.astronaut(m, r.position + Vector2(6, 8), Color(d["visor"]), Color(d["suit"]), int(m.tm * 2.0 + i) if cr["morale"] > 50 else 0, 1.4)
		var tx := x + 34
		m.txt(Vector2(tx, y + 3), "%s · %s" % [d["name"], d["role"]], 9)
		m.txt(Vector2(tx, y + 15), d["perk"] + (" (active)" if s.perk(i) else " (needs 75% morale)"), 7, m.C_DIM)
		var bw := w - 34 - 70
		m.txt(Vector2(tx, y + 25), "Morale", 7, m.C_DIM)
		m.bar(Rect2(tx + 34, y + 28, bw - 34, 4), cr["morale"] / 100.0, m.C_MINT if cr["morale"] > 50 else (m.C_GOLD if cr["morale"] > 25 else m.C_RED))
		m.txt(Vector2(tx, y + 35), "Health", 7, m.C_DIM)
		m.bar(Rect2(tx + 34, y + 38, bw - 34, 4), cr["health"] / 100.0, Color("ff7b8b"))
		var ii: int = i
		var cd := float(cr["cd"])
		m.button(Rect2(r.end.x - 66, y + 24, 62, 18), "Call home" if cd <= 0 else "%ds" % int(cd), func(): s.call_home(ii), cd <= 0.0, Color("2b4a86"), 8)
		y += ch
	var mv: float = s.movie_cd
	m.button(Rect2(x, y + 2, w, 22), "Movie night (-6 food, +15 morale)" if mv <= 0 else "Movie night in %ds" % int(mv), func(): s.movie_night(), mv <= 0.0 and s.food >= 6.0, Color("6a3a86"), 9)

# ------------------------------------------------------------ LAB
func _lab(c: Rect2) -> void:
	var s = m.sim
	var x := c.position.x
	var y := c.position.y
	var w := c.size.x
	var labs: int = s.levels("lab")
	_h(Vector2(x, y), "Research  ·  %.1f RP%s" % [s.rp, "" if labs > 0 else " (build a Lab)"], w)
	y += 22
	var rh := minf(32.0, (c.size.y - 24) / Sim.RESEARCH.size())
	for r in Sim.RESEARCH:
		var id: String = r["id"]
		var done: bool = s.has(id)
		m.txt(Vector2(x, y), r["name"], 9, m.C_MINT if done else m.C_INK)
		m.txt(Vector2(x, y + 12), r["desc"], 7, m.C_DIM)
		var bl := "Done" if done else "%d RP" % r["cost"]
		m.button(Rect2(x + w - 58, y + 2, 58, rh - 8), bl, func(): s.research(id), not done and labs > 0 and s.rp >= float(r["cost"]), Color("6a3a86"), 9)
		y += rh

# ------------------------------------------------------------ GOALS
func _goals(c: Rect2) -> void:
	var s = m.sim
	var x := c.position.x
	var y := c.position.y
	var w := c.size.x
	if s.mission < Sim.MISSIONS.size():
		var md: Dictionary = Sim.MISSIONS[s.mission]
		m.box(Rect2(x, y, w, 62), Color("0c1424"), m.C_GOLD)
		m.txt(Vector2(x + 6, y + 4), "Mission %d/%d: %s" % [s.mission + 1, Sim.MISSIONS.size(), md["title"]], 11, m.C_GOLD)
		m.wrap(Vector2(x + 6, y + 20), md["goal"], w - 12, 9, m.C_INK, 2)
		m.txt(Vector2(x + 6, y + 46), "%s  ·  reward %dcr" % [s.mission_progress(), md["reward"]], 8, m.C_MINT)
	else:
		m.box(Rect2(x, y, w, 62), Color("0c1424"), m.C_MINT)
		m.txt(Vector2(x + 6, y + 6), "Festival held! Sandbox mode", 11, m.C_MINT)
		m.wrap(Vector2(x + 6, y + 24), "Keep expanding Tranquil Basin. Every crop counts.", w - 12, 9, m.C_DIM)
	y += 68
	var lh := minf(16.0, (c.end.y - y - 30) / Sim.MISSIONS.size())
	for i in Sim.MISSIONS.size():
		var done: bool = i < s.mission
		var cur: bool = i == s.mission
		var col: Color = m.C_MINT if done else (m.C_GOLD if cur else m.C_DIM)
		m.draw_rect(Rect2(x, y + 3, 7, 7), col if done else Color(col, 0.3))
		m.txt(Vector2(x + 12, y), "%d. %s" % [i + 1, Sim.MISSIONS[i]["title"]], 8, col)
		y += lh
	y += 4
	var st: Dictionary = s.stats
	m.txt(Vector2(x, y), "Planted %d · Harvested %d · Ice %d · Storms %d" % [st["planted"], st["harvested"], st["ice"], st["storms"]], 7, m.C_DIM)

# ------------------------------------------------------------ TRADE
func _trade(c: Rect2) -> void:
	var s = m.sim
	var x := c.position.x
	var y := c.position.y
	var w := c.size.x
	var dock: bool = s.docked()
	if dock:
		_h(Vector2(x, y), "Supply rocket docked · leaves in %ds" % int(s.rocket["t"]), w)
	else:
		var st: String = s.rocket.get("state", "away")
		_h(Vector2(x, y), "Next rocket in %ds" % int(s.rocket["t"]) if st == "away" else "Rocket %s..." % st, w)
	y += 22
	var pr: Dictionary = s.rocket.get("prices", {})
	var any := false
	for cr in Sim.CROP_ORDER:
		var n := int(s.stock[cr])
		if n <= 0:
			continue
		any = true
		var price := int(pr.get(cr, Sim.CROPS[cr]["price"]))
		m.txt(Vector2(x, y + 3), "%s x%d  @%dcr" % [Sim.CROPS[cr]["name"], n, price], 9)
		var crr: String = cr
		m.button(Rect2(x + w - 92, y, 42, 18), "Sell 1", func(): s.sell(crr, 1), dock, Color("7a5a1a"), 8)
		m.button(Rect2(x + w - 46, y, 46, 18), "Sell all", func(): s.sell(crr, 999), dock, Color("7a5a1a"), 8)
		y += 21
	if not any:
		m.txt(Vector2(x, y), "No crates in storage. Harvest crops first!", 9, m.C_DIM)
		y += 16
	y += 6
	m.txt(Vector2(x, y), "Rocket manifest", 10, m.C_GOLD)
	y += 16
	var deals := [["ice", "Buy 10 ice (15cr)"], ["water", "Buy 25 water (20cr)"], ["o2", "Buy 40 O2 canister (30cr)"], ["regolith", "Sell 10 regolith (+6cr)"]]
	var half := (w - 4) * 0.5
	for i in deals.size():
		var dk: String = deals[i][0]
		m.button(Rect2(x + (i % 2) * (half + 4), y + (i / 2) * 24, half, 20), deals[i][1], func(): s.trade(dk), dock, Color("2b4a86"), 8)
	if not dock:
		m.wrap(Vector2(x, y + 52), "Trading opens while a rocket is docked on the Launch Pad. Prices change every visit.", w, 8, m.C_DIM)

# ------------------------------------------------------------ overlays
func _modal() -> void:
	m.btns.clear()
	m.draw_rect(Rect2(Vector2.ZERO, m.vs), Color(0, 0, 0, 0.55))

func _card(w: float, h: float) -> Rect2:
	w = minf(w, m.vs.x - 24)
	var r := Rect2((m.vs.x - w) * 0.5, (m.vs.y - h) * 0.5, w, h)
	m.box(r, Color("0f1730"), m.C_GOLD)
	return r

func draw_msg(e: Dictionary) -> void:
	_modal()
	m.btns.append({"r": Rect2(Vector2.ZERO, m.vs), "f": m.dismiss_msg, "en": true})
	var r := _card(380, 150)
	m.draw_rect(Rect2(r.position + Vector2(10, 10), Vector2(40, 40)), Color("1d2f6b"))
	Art.astronaut(m, r.position + Vector2(17, 13), Color("ffd56b"), Color("3a5ea8"), 0, 1.4)
	m.txt(r.position + Vector2(58, 10), e.get("title", "Mission Control"), 12, m.C_GOLD)
	m.txt(r.position + Vector2(58, 28), "Flight Director Imani Clarke, Earth", 8, m.C_DIM)
	m.wrap(r.position + Vector2(12, 56), e["text"], r.size.x - 24, 10, m.C_INK, 5)
	m.button(Rect2(r.end.x - 92, r.end.y - 28, 80, 20), "Roger that", m.dismiss_msg, true, Color("2f7a4a"))

func draw_menu() -> void:
	_modal()
	var r := _card(220, 190)
	m.txt(r.position + Vector2(0, 10), "PAUSED", 16, m.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var bx := r.position.x + 30
	var bw := r.size.x - 60
	var y := r.position.y + 40
	m.button(Rect2(bx, y, bw, 22), "Resume", func(): m.menu_open = false, true, Color("2f7a4a"))
	m.button(Rect2(bx, y + 28, bw, 22), "Save game", _save_click)
	m.button(Rect2(bx, y + 56, bw, 22), "Sound: " + ("On" if m.sfx.enabled else "Off"), m.toggle_sound)
	m.button(Rect2(bx, y + 84, bw, 22), "How to play", _help_click)
	m.button(Rect2(bx, y + 112, bw, 22), "Save & quit to title", m.to_title, true, Color("6a2a32"))

func _save_click() -> void:
	m.save_game()
	m.say_toast("Game saved")
	m.menu_open = false

func _help_click() -> void:
	m.menu_open = false
	m.msgs.append({"title": "How to play", "text": HOWTO_SHORT})

const HOWTO_SHORT := "Tap domes to plant and harvest. Build on empty plots. Keep O2, water and power above zero: electrolyzers make O2, recyclers and rover ice make water, batteries carry you through the night. Sell crates to rockets and research new seeds. Keys: arrows move, Enter selects/builds, Q/E cycle, H harvest, 1-5 tabs, Space pause, F speed."

func draw_over() -> void:
	_modal()
	var r := _card(320, 170)
	var why := "Oxygen ran out. Mission Control ordered an evacuation." if m.sim.game_over == "o2" else "Crew morale collapsed. The crew requested a ride home."
	m.txt(r.position + Vector2(0, 12), "MISSION ABORTED", 18, m.C_RED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	m.wrap(r.position + Vector2(16, 42), why, r.size.x - 32, 10, m.C_INK)
	m.txt(r.position + Vector2(0, 80), "You lasted until Sol %d · best Sol %d" % [m.sim.sol(), int(m.meta["best_sol"])], 10, m.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var bw := (r.size.x - 44) * 0.5
	m.button(Rect2(r.position.x + 16, r.end.y - 40, bw, 24), "Try again", m.start_new, true, Color("2f7a4a"))
	m.button(Rect2(r.position.x + 28 + bw, r.end.y - 40, bw, 24), "Title", func(): m.screen = "title")

func draw_win() -> void:
	m.btns.clear()
	m.draw_rect(Rect2(Vector2.ZERO, m.vs), Color(0, 0, 0.05, 0.45))
	var r := _card(400, 190)
	var t := "FIRST LUNAR HARVEST FESTIVAL"
	m.txt(r.position + Vector2(0, 12), t, 15, m.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	for i in 4:
		var d: Dictionary = Sim.CREW_DEF[i]
		var hop := absf(sin(m.tm * 5.0 + i)) * 8.0
		Art.astronaut(m, r.position + Vector2(r.size.x * 0.5 - 90 + i * 48, 44 - hop), Color(d["visor"]), Color(d["suit"]), int(m.tm * 8.0 + i), 1.6)
	m.wrap(r.position + Vector2(16, 90), "The crew sets a table under the dome for a feast grown on the Moon. Earth is watching. Festival held on Sol %d!" % m.sim.sol(), r.size.x - 32, 10, m.C_INK, 3)
	m.button(Rect2(r.get_center().x - 70, r.end.y - 34, 140, 24), "Keep farming", func(): m.win_open = false, true, Color("2f7a4a"))

func draw_howto() -> void:
	_modal()
	var r := _card(460, minf(330, m.vs.y - 20))
	m.txt(r.position + Vector2(0, 10), "HOW TO PLAY", 15, m.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var tips := [
		"Grow: tap a Greenhouse Dome, choose a seed, plant trays. Tap a ready dome to harvest crates.",
		"Breathe: the crew uses O2 and water. Build an O2 Electrolyzer and a Water Recycler fed by rover ice.",
		"Power: solar works only in daylight. Batteries carry the base through the long lunar night and dust storms.",
		"Crew: food variety, quarters and movie nights keep morale high. 75%+ morale activates each specialist's perk.",
		"Trade & research: sell crates to supply rockets, build a Lab and unlock new seeds and upgrades.",
		"Story: follow Mission Control's 10 missions to hold the First Lunar Harvest Festival.",
		"Keys: arrows/WASD move · Enter select/build · Q/E cycle · U upgrade · H harvest · 1-5 tabs · Space pause · F speed · M sound · Esc menu",
	]
	var y := r.position.y + 34
	for tp in tips:
		m.wrap(Vector2(r.position.x + 16, y), "• " + tp, r.size.x - 32, 9, m.C_INK, 3)
		y += 36 if m.vs.x < 420 else 30
	m.button(Rect2(r.get_center().x - 50, r.end.y - 30, 100, 22), "Back", func(): m.screen = "title", true, Color("2f7a4a"))
