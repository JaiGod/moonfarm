extends RefCounted
## Moonfarm simulation: resources, modules, crops, crew, rovers, rockets,
## research and story missions. Pure logic (no nodes) so it can be
## smoke-tested headless and saved as plain JSON.

const SOL_LEN := 180.0          # seconds of game time per lunar "sol" (compressed)
const COLS := 8
const ROWS := 4
const MAX_LVL := 3
const TRAYS := 4

const MODULES := {
	"greenhouse": {"name": "Greenhouse Dome", "cr": 40, "reg": 15, "pw": 1.2, "desc": "Hydroponic dome with 4 crop trays. Crops also make O2."},
	"solar": {"name": "Solar Array", "cr": 20, "reg": 10, "pw": 0.0, "desc": "+5 kW per level while the Sun is up."},
	"battery": {"name": "Battery Bank", "cr": 30, "reg": 10, "pw": 0.0, "desc": "+150 kWh storage per level for the lunar night."},
	"recycler": {"name": "Water Recycler", "cr": 40, "reg": 20, "pw": 1.0, "desc": "Reclaims used water and melts rover ice."},
	"electrolyzer": {"name": "O2 Electrolyzer", "cr": 45, "reg": 15, "pw": 2.0, "desc": "Splits water into breathable oxygen."},
	"quarters": {"name": "Crew Quarters", "cr": 35, "reg": 20, "pw": 0.5, "desc": "Boosts morale and adds O2 storage."},
	"roverbay": {"name": "Rover Bay", "cr": 50, "reg": 25, "pw": 0.5, "desc": "Houses 1 rover per level to haul ice and regolith."},
	"lab": {"name": "Research Lab", "cr": 60, "reg": 30, "pw": 1.5, "desc": "Generates research points (RP)."},
	"pad": {"name": "Launch Pad", "cr": 0, "reg": 0, "pw": 0.0, "desc": "Supply rockets land here to trade."},
	"hub": {"name": "Command Hub", "cr": 0, "reg": 0, "pw": 0.3, "desc": "Heart of the base. Comms with Mission Control."},
}
const BUILD_ORDER := ["greenhouse", "solar", "battery", "electrolyzer", "recycler", "quarters", "roverbay", "lab"]

const CROPS := {
	"lettuce": {"name": "Lettuce", "time": 30.0, "food": 4, "price": 6, "seed": 2, "unlock": ""},
	"radish": {"name": "Radish", "time": 40.0, "food": 5, "price": 8, "seed": 3, "unlock": ""},
	"potato": {"name": "Potato", "time": 70.0, "food": 10, "price": 13, "seed": 5, "unlock": ""},
	"tomato": {"name": "Tomato", "time": 60.0, "food": 7, "price": 15, "seed": 5, "unlock": ""},
	"soy": {"name": "Soybean", "time": 75.0, "food": 9, "price": 14, "seed": 4, "unlock": "soy"},
	"wheat": {"name": "Dwarf Wheat", "time": 85.0, "food": 12, "price": 16, "seed": 4, "unlock": "wheat"},
	"moonberry": {"name": "Moonberry", "time": 100.0, "food": 8, "price": 40, "seed": 10, "unlock": "berry"},
}
const CROP_ORDER := ["lettuce", "radish", "potato", "tomato", "soy", "wheat", "moonberry"]

const RESEARCH := [
	{"id": "led", "name": "LED Spectrum Tuning", "cost": 20, "desc": "Crops grow 25% faster."},
	{"id": "soy", "name": "Soy Protein Line", "cost": 20, "desc": "Unlocks Soybean seeds."},
	{"id": "wheat", "name": "Dwarf Wheat Genome", "cost": 25, "desc": "Unlocks Dwarf Wheat seeds."},
	{"id": "drill", "name": "Ice Drill Bits", "cost": 30, "desc": "Rovers haul 50% more."},
	{"id": "loop", "name": "Closed-Loop Water", "cost": 35, "desc": "Recyclers reclaim 10% more water."},
	{"id": "shield", "name": "Dust-Shield Panels", "cost": 35, "desc": "Storms hurt solar far less."},
	{"id": "well", "name": "Crew Wellness Program", "cost": 40, "desc": "+10 morale for everyone."},
	{"id": "berry", "name": "Moonberry Hybrid", "cost": 50, "desc": "Unlocks the luxury Moonberry."},
]

const MISSIONS := [
	{"title": "First Sprouts", "goal": "Plant 3 crops in the greenhouse", "reward": 30,
		"msg": "Welcome to Tranquil Basin, crew! Your hydroponic dome is ready. Tap it, pick a seed and plant 3 trays. Fresh food keeps morale up and plants make oxygen."},
	{"title": "Breathe Easy", "goal": "Build an O2 Electrolyzer", "reward": 25,
		"msg": "Good work! Your oxygen tank is draining though. Build an O2 Electrolyzer: it splits water into air. Keep an eye on the O2 gauge!"},
	{"title": "Ice Hunters", "goal": "Haul 15 ice with rovers", "reward": 30,
		"msg": "Electrolyzers drink water. Send a rover from the Rover Bay to the ice crater, and build a Water Recycler to melt the ice."},
	{"title": "Green Thumb", "goal": "Harvest 8 crops", "reward": 35,
		"msg": "The crew is craving salad. Harvest 8 crops. Tip: crates go to storage, and the galley cooks them when the pantry runs low."},
	{"title": "Night Shift", "goal": "Build a Battery Bank and reach Sol 2", "reward": 40,
		"msg": "The lunar night is long and dark, with no solar power. Build a Battery Bank so the domes stay lit until sunrise."},
	{"title": "Trade Winds", "goal": "Sell crates to a supply rocket", "reward": 40,
		"msg": "A supply rocket lands on your pad every sol or so. Open the TRADE tab while it is docked and sell some crates."},
	{"title": "Science!", "goal": "Build a Lab and finish 2 research projects", "reward": 50,
		"msg": "Earth wants data. Build a Research Lab and complete 2 projects. New seeds mean a happier, healthier crew."},
	{"title": "Happy Crew", "goal": "Run 2 greenhouses with average morale 70+", "reward": 50,
		"msg": "Morale is mission-critical. Expand to two greenhouses, upgrade quarters and keep the menu varied."},
	{"title": "Storm Chaser", "goal": "Weather a dust storm", "reward": 60,
		"msg": "Heads up! Our satellites see a dust storm rolling in. Solar output will drop and rovers will park. Charge your batteries now!"},
	{"title": "Harvest Festival", "goal": "Harvest 5 crop types and hold 12 crates", "reward": 100,
		"msg": "Final objective: the First Lunar Harvest Festival! Harvest 5 different crops and store 12 crates for the feast. All of Earth will be watching."},
]

const CREW_DEF := [
	{"name": "Cmdr. Ada Okoro", "role": "Commander", "perk": "+20% mission rewards", "visor": "f6c344", "suit": "e35d5d"},
	{"name": "Ravi Menon", "role": "Botanist", "perk": "+15% crop growth", "visor": "7fe08a", "suit": "4fa36b"},
	{"name": "Lena Sorensen", "role": "Engineer", "perk": "+20% solar & rover haul", "visor": "6cc6ff", "suit": "f09a3e"},
	{"name": "Tomas Reyes", "role": "Medic", "perk": "Crew health & morale recover faster", "visor": "d59cff", "suit": "6a7bdc"},
]

var rng := RandomNumberGenerator.new()
var t := 0.0
var power := 40.0
var o2 := 100.0
var water := 120.0
var food := 40.0
var ice := 0.0
var regolith := 40.0
var credits := 160.0
var rp := 0.0
var grid: Array = []
var crew: Array = []
var stock := {}
var research_done: Array = []
var mission := 0
var stats := {}
var rovers: Array = []
var rover_auto := ""
var storm := 0.0
var next_storm := 0.0
var rocket := {}
var o2_zero := 0.0
var low_morale := 0.0
var game_over := ""
var festival := false
var movie_cd := 0.0
var powered := true
var gen_now := 0.0
var use_now := 0.0
var recent_meals: Array = []
var events: Array = []

func new_game(seed_v: int = -1) -> void:
	if seed_v >= 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	t = 0.0; power = 40.0; o2 = 100.0; water = 120.0; food = 40.0; ice = 0.0
	regolith = 40.0; credits = 160.0; rp = 0.0; mission = 0; storm = 0.0
	next_storm = SOL_LEN * rng.randf_range(1.4, 2.0)
	o2_zero = 0.0; low_morale = 0.0; game_over = ""; festival = false; movie_cd = 0.0
	research_done = []; rover_auto = ""; recent_meals = []; events = []
	stats = {"planted": 0, "harvested": 0, "ice": 0, "trades": 0, "types": {}, "storms": 0, "research": 0}
	stock = {}
	for c in CROP_ORDER:
		stock[c] = 0
	grid = []
	grid.resize(COLS * ROWS)
	_place("hub", 11); _place("greenhouse", 10); _place("solar", 2); _place("solar", 3)
	_place("quarters", 12); _place("roverbay", 20); _place("pad", 15)
	crew = []
	for d in CREW_DEF:
		crew.append({"morale": 65.0, "health": 100.0, "cd": 0.0})
	_sync_rovers()
	rocket = {"state": "away", "t": SOL_LEN * 0.55, "prices": {}}
	_say(MISSIONS[0]["msg"], "Mission 1: " + MISSIONS[0]["title"])

func _place(type: String, idx: int) -> void:
	var m := {"type": type, "lvl": 1}
	if type == "greenhouse":
		m["trays"] = _empty_trays()
	grid[idx] = m

func _empty_trays() -> Array:
	var a := []
	for i in TRAYS:
		a.append({"c": "", "g": 0.0})
	return a

func _say(text: String, title: String = "Mission Control") -> void:
	events.append({"k": "msg", "title": title, "text": text})

func _ev(k: String, data: Dictionary = {}) -> void:
	var e := data.duplicate()
	e["k"] = k
	events.append(e)

# ---------------------------------------------------------------- queries
func sol() -> int:
	return int(t / SOL_LEN) + 1

func day_phase() -> float:
	return fmod(t, SOL_LEN) / SOL_LEN

func light() -> float:
	# Day for the first 55% of a sol; smooth dawn/dusk.
	var p := day_phase()
	if p < 0.55:
		return clampf(sin(p / 0.55 * PI) * 1.6, 0.0, 1.0)
	return 0.0

func is_night() -> bool:
	return day_phase() >= 0.55

func count(type: String) -> int:
	var n := 0
	for m in grid:
		if m != null and m["type"] == type:
			n += 1
	return n

func levels(type: String) -> int:
	var n := 0
	for m in grid:
		if m != null and m["type"] == type:
			n += int(m["lvl"])
	return n

func has(id: String) -> bool:
	return research_done.has(id)

func crop_unlocked(c: String) -> bool:
	var u: String = CROPS[c]["unlock"]
	return u == "" or has(u)

func battery_cap() -> float:
	return 60.0 + levels("battery") * 150.0

func o2_cap() -> float:
	return 100.0 + levels("quarters") * 40.0

func water_cap() -> float:
	return 150.0 + levels("recycler") * 50.0

func avg_morale() -> float:
	var s := 0.0
	for c in crew:
		s += float(c["morale"])
	return s / maxf(1.0, crew.size())

func morale_mult(i: int) -> float:
	var m: float = crew[i]["morale"]
	return 0.6 + 0.6 * clampf(m / 100.0, 0.0, 1.0)

func perk(i: int) -> bool:
	return float(crew[i]["morale"]) >= 75.0

func growing_trays() -> int:
	var n := 0
	for m in grid:
		if m != null and m["type"] == "greenhouse":
			for tr in m["trays"]:
				if tr["c"] != "" and float(tr["g"]) < 1.0:
					n += 1
	return n

func ready_trays() -> int:
	var n := 0
	for m in grid:
		if m != null and m["type"] == "greenhouse":
			for tr in m["trays"]:
				if tr["c"] != "" and float(tr["g"]) >= 1.0:
					n += 1
	return n

func total_crates() -> int:
	var n := 0
	for c in stock:
		n += int(stock[c])
	return n

func build_cost(type: String) -> Array:
	return [int(MODULES[type]["cr"]), int(MODULES[type]["reg"])]

func upgrade_cost(idx: int) -> Array:
	var m: Dictionary = grid[idx]
	var l := int(m["lvl"])
	if m["type"] == "pad" or m["type"] == "hub":
		return [60 * l, 30 * l]
	var b := build_cost(m["type"])
	return [int(b[0] * (l + 1) * 0.75), int(b[1] * (l + 1) * 0.75)]

func can_afford(c: Array) -> bool:
	return credits >= c[0] and regolith >= c[1]

func mission_progress() -> String:
	if mission >= MISSIONS.size():
		return "All missions complete!"
	match mission:
		0: return "%d / 3 planted" % mini(3, stats["planted"])
		1: return "%d / 1 built" % mini(1, count("electrolyzer"))
		2: return "%d / 15 ice" % mini(15, stats["ice"])
		3: return "%d / 8 harvested" % mini(8, stats["harvested"])
		4: return "Battery %d/1 · Sol %d/2" % [mini(1, count("battery")), mini(2, sol())]
		5: return "%d / 1 trades" % mini(1, stats["trades"])
		6: return "Lab %d/1 · Research %d/2" % [mini(1, count("lab")), mini(2, research_done.size())]
		7: return "Domes %d/2 · Morale %d/70" % [mini(2, count("greenhouse")), int(avg_morale())]
		8: return "%d / 1 storms weathered" % mini(1, stats["storms"])
		9: return "Types %d/5 · Crates %d/12" % [mini(5, stats["types"].size()), mini(12, total_crates())]
	return ""

func _mission_done() -> bool:
	match mission:
		0: return stats["planted"] >= 3
		1: return count("electrolyzer") >= 1
		2: return stats["ice"] >= 15
		3: return stats["harvested"] >= 8
		4: return count("battery") >= 1 and sol() >= 2
		5: return stats["trades"] >= 1
		6: return count("lab") >= 1 and research_done.size() >= 2
		7: return count("greenhouse") >= 2 and avg_morale() >= 70.0
		8: return stats["storms"] >= 1
		9: return stats["types"].size() >= 5 and total_crates() >= 12
	return false

# ---------------------------------------------------------------- simulation
func tick(dt: float) -> void:
	if game_over != "":
		return
	t += dt
	movie_cd = maxf(0.0, movie_cd - dt)
	var n_crew := crew.size()
	# --- weather
	if storm > 0.0:
		storm -= dt
		if storm <= 0.0:
			storm = 0.0
			stats["storms"] += 1
			_ev("storm_end")
			next_storm = t + SOL_LEN * rng.randf_range(1.3, 2.2)
	elif t >= next_storm:
		storm = rng.randf_range(30.0, 42.0)
		_ev("storm")
	# --- power
	var eng := perk(2)
	var storm_mult := 1.0
	if storm > 0.0:
		storm_mult = 0.65 if has("shield") else 0.2
	gen_now = levels("solar") * 5.0 * light() * storm_mult * (1.2 if eng else 1.0)
	var grows := growing_trays()
	use_now = 0.0
	for m in grid:
		if m == null:
			continue
		var pw: float = MODULES[m["type"]]["pw"]
		if m["type"] == "greenhouse":
			var active := 0
			for tr in m["trays"]:
				if tr["c"] != "" and float(tr["g"]) < 1.0:
					active += 1
			pw = pw * (0.25 + 0.75 * active / float(TRAYS))
		use_now += pw * (1.0 + 0.5 * (int(m["lvl"]) - 1))
	power += (gen_now - use_now) * dt
	var cap := battery_cap()
	if power > cap:
		power = cap
	powered = true
	if power <= 0.0:
		power = 0.0
		powered = gen_now >= use_now
	# --- water & oxygen
	var crew_water := 0.1 * n_crew
	var crop_water := 0.03 * grows if powered else 0.0
	water -= (crew_water + crop_water) * dt
	o2 -= 0.12 * n_crew * dt
	if powered:
		var rec := levels("recycler")
		if rec > 0:
			var eff := minf(0.95, 0.7 + 0.08 * rec + (0.1 if has("loop") else 0.0))
			water += (crew_water + crop_water) * eff * dt
			var melt := minf(ice, 0.4 * rec * dt)
			ice -= melt
			water += melt * 1.5
		var el := levels("electrolyzer")
		if el > 0 and water > 0.5:
			o2 += 1.0 * el * dt
			water -= 0.25 * el * dt
		if water > 0.0:
			o2 += 0.05 * grows * dt
	water = clampf(water, 0.0, water_cap())
	o2 = clampf(o2, 0.0, o2_cap())
	# --- crops
	var gmult := (1.25 if has("led") else 1.0) * (1.15 if perk(1) else 1.0)
	if powered and water > 0.0:
		for i in grid.size():
			var m = grid[i]
			if m == null or m["type"] != "greenhouse":
				continue
			var lm := 1.0 + 0.25 * (int(m["lvl"]) - 1)
			for tr in m["trays"]:
				if tr["c"] != "" and float(tr["g"]) < 1.0:
					tr["g"] = float(tr["g"]) + dt / float(CROPS[tr["c"]]["time"]) * gmult * lm
					if float(tr["g"]) >= 1.0:
						tr["g"] = 1.0
						_ev("ripe", {"i": i})
	# --- galley: eat and auto-cook
	food -= 0.05 * n_crew * dt
	if food < 25.0:
		var best := ""
		for c in CROP_ORDER:
			if int(stock[c]) > 0 and (best == "" or int(stock[c]) > int(stock[best])):
				best = c
		if best != "":
			stock[best] = int(stock[best]) - 1
			food += float(CROPS[best]["food"])
			recent_meals.append([best, t])
	food = maxf(food, 0.0)
	while recent_meals.size() > 0 and t - float(recent_meals[0][1]) > SOL_LEN:
		recent_meals.pop_front()
	# --- research
	var lab := levels("lab")
	if lab > 0 and powered:
		rp += 0.2 * lab * (0.6 + 0.4 * avg_morale() / 100.0) * dt
	# --- crew
	_tick_crew(dt)
	# --- rovers & rocket
	_tick_rovers(dt)
	_tick_rocket(dt)
	# --- failure states
	if o2 <= 0.0:
		o2_zero += dt
		if o2_zero > 25.0:
			game_over = "o2"
			_ev("over")
	else:
		o2_zero = maxf(0.0, o2_zero - dt * 2.0)
	if avg_morale() < 8.0:
		low_morale += dt
		if low_morale > 45.0:
			game_over = "morale"
			_ev("over")
	else:
		low_morale = 0.0
	# --- missions
	if mission < MISSIONS.size() and _mission_done():
		_complete_mission()

func _tick_crew(dt: float) -> void:
	var variety := {}
	for r in recent_meals:
		variety[r[0]] = true
	var target := 52.0 + minf(24.0, levels("quarters") * 7.0) + minf(12.0, variety.size() * 4.0)
	if has("well"):
		target += 10.0
	if food <= 0.0:
		target -= 30.0
	if o2 < o2_cap() * 0.15:
		target -= 30.0
	if storm > 0.0:
		target -= 8.0
	if not powered:
		target -= 10.0
	if festival:
		target += 15.0
	var medic := perk(3)
	for c in crew:
		c["cd"] = maxf(0.0, float(c["cd"]) - dt)
		var m: float = c["morale"]
		var rate := (0.8 if medic else 0.5) * dt
		if m < target:
			m = minf(target, m + rate)
		else:
			m = maxf(target, m - rate * 0.6)
		c["morale"] = clampf(m, 0.0, 100.0)
		var h: float = c["health"]
		if o2 <= 0.0 or food <= 0.0:
			h -= 1.5 * dt
		else:
			h += (1.0 if medic else 0.5) * dt
		c["health"] = clampf(h, 0.0, 100.0)
		if h <= 0.0:
			c["morale"] = maxf(0.0, float(c["morale"]) - 2.0 * dt)

func _sync_rovers() -> void:
	var want := levels("roverbay")
	while rovers.size() < want:
		rovers.append({"s": "idle", "tg": "", "p": 0.0})
	while rovers.size() > want:
		rovers.pop_back()

func _tick_rovers(dt: float) -> void:
	for i in rovers.size():
		var r: Dictionary = rovers[i]
		if r["s"] == "idle":
			if rover_auto != "" and storm <= 0.0:
				dispatch(i, rover_auto)
			continue
		if storm > 0.0:
			continue
		r["p"] = float(r["p"]) + dt / 24.0
		if float(r["p"]) >= 1.0:
			var mult := (1.5 if has("drill") else 1.0) * (1.2 if perk(2) else 1.0)
			if r["tg"] == "ice":
				var a := int(round(6 * mult))
				ice += a
				stats["ice"] += a
				_ev("haul", {"what": "ice", "n": a})
			else:
				var b := int(round(10 * mult))
				regolith += b
				_ev("haul", {"what": "regolith", "n": b})
			r["s"] = "idle"; r["p"] = 0.0; r["tg"] = ""

func dispatch(i: int, target: String) -> bool:
	if i < 0 or i >= rovers.size() or rovers[i]["s"] != "idle" or storm > 0.0:
		return false
	rovers[i] = {"s": "out", "tg": target, "p": 0.0}
	_ev("rover")
	return true

func dispatch_any(target: String) -> bool:
	for i in rovers.size():
		if rovers[i]["s"] == "idle":
			return dispatch(i, target)
	return false

func _tick_rocket(dt: float) -> void:
	if count("pad") == 0:
		return
	rocket["t"] = float(rocket["t"]) - dt
	if float(rocket["t"]) > 0.0:
		return
	match rocket["state"]:
		"away":
			rocket["state"] = "landing"; rocket["t"] = 4.0
			var pr := {}
			for c in CROP_ORDER:
				pr[c] = int(round(CROPS[c]["price"] * rng.randf_range(0.85, 1.45)))
			rocket["prices"] = pr
			_ev("rocket_in")
		"landing":
			rocket["state"] = "docked"; rocket["t"] = 60.0 + 15.0 * (levels("pad") - 1)
			_ev("docked")
		"docked":
			rocket["state"] = "launching"; rocket["t"] = 4.0
			_ev("rocket_out")
		"launching":
			rocket["state"] = "away"; rocket["t"] = SOL_LEN * rng.randf_range(0.8, 1.2)

func docked() -> bool:
	return rocket.get("state", "") == "docked"

# ---------------------------------------------------------------- actions
func build(type: String, idx: int) -> bool:
	if idx < 0 or idx >= grid.size() or grid[idx] != null or not MODULES.has(type):
		return false
	var c := build_cost(type)
	if not can_afford(c):
		return false
	credits -= c[0]; regolith -= c[1]
	_place(type, idx)
	_sync_rovers()
	_ev("built", {"i": idx})
	return true

func upgrade(idx: int) -> bool:
	var m = grid[idx]
	if m == null or int(m["lvl"]) >= MAX_LVL:
		return false
	var c := upgrade_cost(idx)
	if not can_afford(c):
		return false
	credits -= c[0]; regolith -= c[1]
	m["lvl"] = int(m["lvl"]) + 1
	_sync_rovers()
	_ev("built", {"i": idx})
	return true

func demolish(idx: int) -> bool:
	var m = grid[idx]
	if m == null or m["type"] == "hub" or m["type"] == "pad":
		return false
	var c := build_cost(m["type"])
	regolith += int(c[1] * 0.5 * int(m["lvl"]))
	grid[idx] = null
	_sync_rovers()
	_ev("demolish", {"i": idx})
	return true

func plant(idx: int, tray: int, crop: String) -> bool:
	var m = grid[idx]
	if m == null or m["type"] != "greenhouse" or not CROPS.has(crop) or not crop_unlocked(crop):
		return false
	var tr: Dictionary = m["trays"][tray]
	if tr["c"] != "":
		return false
	var cost := int(CROPS[crop]["seed"])
	if credits < cost:
		return false
	credits -= cost
	tr["c"] = crop; tr["g"] = 0.0
	stats["planted"] += 1
	_ev("plant", {"i": idx})
	return true

func plant_all(idx: int, crop: String) -> int:
	var n := 0
	var m = grid[idx]
	if m == null or m["type"] != "greenhouse":
		return 0
	for k in TRAYS:
		if m["trays"][k]["c"] == "" and plant(idx, k, crop):
			n += 1
	return n

func harvest(idx: int, tray: int) -> bool:
	var m = grid[idx]
	if m == null or m["type"] != "greenhouse":
		return false
	var tr: Dictionary = m["trays"][tray]
	if tr["c"] == "" or float(tr["g"]) < 1.0:
		return false
	var c: String = tr["c"]
	stock[c] = int(stock[c]) + 1
	stats["harvested"] += 1
	stats["types"][c] = true
	tr["c"] = ""; tr["g"] = 0.0
	_ev("harvest", {"i": idx, "c": c})
	return true

func harvest_all(idx: int = -1) -> int:
	var n := 0
	for i in grid.size():
		if idx >= 0 and i != idx:
			continue
		var m = grid[i]
		if m != null and m["type"] == "greenhouse":
			for k in TRAYS:
				if harvest(i, k):
					n += 1
	return n

func research(id: String) -> bool:
	if has(id) or count("lab") == 0:
		return false
	for r in RESEARCH:
		if r["id"] == id and rp >= float(r["cost"]):
			rp -= float(r["cost"])
			research_done.append(id)
			stats["research"] += 1
			_ev("research", {"name": r["name"]})
			return true
	return false

func sell(crop: String, n: int) -> int:
	if not docked() or int(stock.get(crop, 0)) <= 0:
		return 0
	n = mini(n, int(stock[crop]))
	var price := int(rocket["prices"].get(crop, CROPS[crop]["price"]))
	stock[crop] = int(stock[crop]) - n
	credits += price * n
	stats["trades"] += 1
	_ev("sell", {"n": price * n})
	return price * n

func trade(kind: String) -> bool:
	if not docked():
		return false
	match kind:
		"ice":
			if credits < 15: return false
			credits -= 15; ice += 10
		"water":
			if credits < 20: return false
			credits -= 20; water = minf(water_cap(), water + 25.0)
		"o2":
			if credits < 30: return false
			credits -= 30; o2 = minf(o2_cap(), o2 + 40.0)
		"regolith":
			if regolith < 10: return false
			regolith -= 10; credits += 6
		_:
			return false
	stats["trades"] += 1
	_ev("sell", {"n": 0})
	return true

func movie_night() -> bool:
	if movie_cd > 0.0 or food < 6.0:
		return false
	food -= 6.0
	movie_cd = 90.0
	for c in crew:
		c["morale"] = minf(100.0, float(c["morale"]) + 15.0)
	_ev("cheer")
	return true

func call_home(i: int) -> bool:
	if i < 0 or i >= crew.size() or float(crew[i]["cd"]) > 0.0:
		return false
	crew[i]["cd"] = 120.0
	crew[i]["morale"] = minf(100.0, float(crew[i]["morale"]) + 12.0)
	_ev("cheer")
	return true

func _complete_mission() -> void:
	var m: Dictionary = MISSIONS[mission]
	var reward := int(m["reward"] * (1.2 if perk(0) else 1.0))
	credits += reward
	_ev("mission", {"title": m["title"], "reward": reward})
	mission += 1
	if mission >= MISSIONS.size():
		festival = true
		for c in crew:
			c["morale"] = 100.0
		_ev("festival")
		return
	if mission == 8 and storm <= 0.0:
		next_storm = minf(next_storm, t + 25.0)
	_say(MISSIONS[mission]["msg"], "Mission %d: %s" % [mission + 1, MISSIONS[mission]["title"]])

# ---------------------------------------------------------------- save / load
func to_dict() -> Dictionary:
	return {"v": 1, "t": t, "power": power, "o2": o2, "water": water, "food": food, "ice": ice,
		"regolith": regolith, "credits": credits, "rp": rp, "grid": grid, "crew": crew,
		"stock": stock, "research": research_done, "mission": mission, "stats": stats,
		"rovers": rovers, "auto": rover_auto, "storm": storm, "next_storm": next_storm,
		"rocket": rocket, "festival": festival, "movie_cd": movie_cd, "meals": recent_meals}

func from_dict(d: Dictionary) -> bool:
	if int(d.get("v", 0)) != 1:
		return false
	rng.randomize()
	t = float(d["t"]); power = float(d["power"]); o2 = float(d["o2"]); water = float(d["water"])
	food = float(d["food"]); ice = float(d["ice"]); regolith = float(d["regolith"])
	credits = float(d["credits"]); rp = float(d["rp"])
	grid = []
	for m in d["grid"]:
		if m == null:
			grid.append(null)
		else:
			m["lvl"] = int(m["lvl"])
			grid.append(m)
	crew = d["crew"]
	stock = {}
	for c in CROP_ORDER:
		stock[c] = int(d["stock"].get(c, 0))
	research_done = d["research"]
	mission = int(d["mission"]); stats = d["stats"]
	for k in ["planted", "harvested", "ice", "trades", "storms", "research"]:
		stats[k] = int(stats.get(k, 0))
	if typeof(stats.get("types")) != TYPE_DICTIONARY:
		stats["types"] = {}
	rovers = d["rovers"]; rover_auto = str(d.get("auto", ""))
	storm = float(d["storm"]); next_storm = float(d["next_storm"]); rocket = d["rocket"]
	festival = bool(d["festival"]); movie_cd = float(d.get("movie_cd", 0.0))
	recent_meals = d.get("meals", [])
	game_over = ""; o2_zero = 0.0; low_morale = 0.0; events = []
	_sync_rovers()
	return true
