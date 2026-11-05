extends RefCounted
## All Moonfarm art is drawn here in code, as chunky 2x2 "art pixels".
## Every function takes the CanvasItem to draw on and an origin in base px.

const P := 2.0

static func px(ci: CanvasItem, o: Vector2, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(o.x + x * P, o.y + y * P, w * P, h * P), c)

static func col(h: String) -> Color:
	return Color.html(h)

# ------------------------------------------------------------ base modules
static func foundation(ci: CanvasItem, o: Vector2) -> void:
	px(ci, o, 1, 20, 22, 3, col("4a4f5c"))
	px(ci, o, 1, 20, 22, 1, col("6d7383"))
	px(ci, o, 2, 23, 20, 1, Color(0, 0, 0, 0.35))

static func dome(ci: CanvasItem, o: Vector2, r: int, cx: int, base_y: int, glass: Color, frame: Color) -> void:
	for y in r:
		var hw := int(round(sqrt(float(r * r - (r - y) * (r - y)))))
		var yy := base_y - r + y
		px(ci, o, cx - hw, yy, hw * 2, 1, glass)
		px(ci, o, cx - hw, yy, 1, 1, frame)
		px(ci, o, cx + hw - 1, yy, 1, 1, frame)
	px(ci, o, cx - 1, base_y - r, 2, r, Color(frame, 0.55))
	px(ci, o, cx - r, base_y - 4, r * 2, 1, Color(frame, 0.55))

static func module(ci: CanvasItem, type: String, o: Vector2, lvl: int, ctx: Dictionary) -> void:
	var tm: float = ctx.get("time", 0.0)
	var night: bool = ctx.get("night", false)
	var on: bool = ctx.get("powered", true)
	foundation(ci, o)
	match type:
		"greenhouse":
			if night and on:
				ci.draw_circle(o + Vector2(24, 26), 26, Color(0.9, 0.4, 1.0, 0.10))
			px(ci, o, 2, 18, 20, 2, col("8a90a0"))
			dome(ci, o, 10, 12, 19, Color(0.62, 0.9, 1.0, 0.22), col("d7e3ee"))
			var trays: Array = ctx.get("trays", [])
			for k in trays.size():
				var tx := 3 + k * 5
				px(ci, o, tx, 17, 4, 2, col("3b6e8f"))
				var tr: Dictionary = trays[k]
				if tr["c"] != "":
					crop(ci, o + Vector2(tx * P, 17 * P), tr["c"], float(tr["g"]), tm + k)
			# glass glint
			px(ci, o, 7, 11, 1, 3, Color(1, 1, 1, 0.5))
			px(ci, o, 8, 10, 2, 1, Color(1, 1, 1, 0.5))
		"solar":
			var tilt := 0.0 if night else sin(tm * 0.1) * 0.5
			px(ci, o, 11, 13, 2, 7, col("9aa1b0"))
			for k in 2:
				var yo := 4 + k * 5 + int(tilt)
				px(ci, o, 2, yo, 20, 4, col("1d2f6b"))
				for cx in 5:
					px(ci, o, 3 + cx * 4, yo + 1, 3, 2, col("2f56b8"))
				px(ci, o, 2, yo, 20, 1, col("8fa8e8"))
			if not night and ctx.get("storm", 0.0) <= 0.0:
				var g := fmod(tm * 0.5 + o.x * 0.01, 3.0)
				if g < 1.0:
					px(ci, o, 3 + int(g * 16), 5, 2, 1, Color(1, 1, 1, 0.9))
		"battery":
			px(ci, o, 4, 6, 16, 14, col("dfe4ea"))
			px(ci, o, 4, 6, 16, 2, col("a9b2bd"))
			px(ci, o, 9, 4, 6, 2, col("a9b2bd"))
			var f: float = ctx.get("battery", 0.5)
			var bars := int(ceil(f * 4.0))
			for b in 4:
				var c := col("4fd16b") if b < bars else col("3a3f4a")
				if f < 0.2 and b < bars:
					c = col("f05a4a")
				px(ci, o, 6, 17 - b * 3, 12, 2, c)
		"recycler":
			for k in 2:
				var x := 3 + k * 10
				px(ci, o, x, 7, 8, 13, col("3c7fc4"))
				px(ci, o, x, 6, 8, 2, col("7fb7ea"))
				px(ci, o, x + 1, 9, 1, 9, Color(1, 1, 1, 0.35))
				var lvl_w := 5 + int(3 * sin(tm + k))
				px(ci, o, x + 5, 19 - lvl_w, 2, lvl_w, col("9fe4ff"))
			px(ci, o, 11, 10, 2, 2, col("c8ccd3"))
		"electrolyzer":
			px(ci, o, 5, 5, 14, 15, col("e9edf2"))
			px(ci, o, 5, 5, 14, 2, col("b9c1cc"))
			px(ci, o, 7, 9, 10, 8, col("1c3f66"))
			if on:
				for b in 4:
					var by := 16.0 - fmod(tm * 4.0 + b * 2.0, 7.0)
					px(ci, o, 8 + b * 2, by, 1, 1, col("bff2ff"))
			px(ci, o, 9, 2, 2, 3, col("9aa1b0"))
			px(ci, o, 8, 1, 4, 1, col("6cc6ff"))
		"quarters":
			px(ci, o, 1, 9, 22, 11, col("eef1f5"))
			px(ci, o, 1, 9, 22, 2, col("ffffff"))
			px(ci, o, 0, 11, 1, 7, col("b9c1cc"))
			px(ci, o, 23, 11, 1, 7, col("b9c1cc"))
			px(ci, o, 1, 16, 22, 1, col("e35d5d"))
			for w in 3:
				var wc := col("ffd56b") if night and on else col("6a8fb5")
				px(ci, o, 4 + w * 6, 12, 3, 3, wc)
				if night and on:
					ci.draw_circle(o + Vector2((5.5 + w * 6) * P, 13.5 * P), 6, Color(1, 0.85, 0.4, 0.15))
		"roverbay":
			px(ci, o, 2, 8, 20, 12, col("aeb5c2"))
			px(ci, o, 2, 7, 20, 2, col("d6dbe3"))
			px(ci, o, 5, 11, 14, 9, col("2a2e38"))
			for s in 7:
				px(ci, o, 5 + s * 2, 11, 1, 1, col("f6c344"))
			var idle: int = ctx.get("idle_rovers", 0)
			if idle > 0:
				rover(ci, o + Vector2(9 * P, 15 * P), false, tm, 1.0)
		"lab":
			px(ci, o, 3, 12, 18, 8, col("dfe4ea"))
			dome(ci, o, 7, 12, 13, col("8f7bd6"), col("c9bcff"))
			px(ci, o, 18, 3, 1, 9, col("9aa1b0"))
			var a := sin(tm * 0.8) * 2.0
			px(ci, o, 15 + a, 2, 7, 2, col("e9edf2"))
			if on and fmod(tm, 1.4) < 0.7:
				px(ci, o, 18, 1, 1, 1, col("ff6b8b"))
			px(ci, o, 6, 15, 3, 2, col("6cc6ff"))
			px(ci, o, 15, 15, 3, 2, col("6cc6ff"))
		"pad":
			px(ci, o, 1, 17, 22, 4, col("5b606d"))
			px(ci, o, 3, 18, 18, 2, col("6d7383"))
			px(ci, o, 7, 18, 1, 2, col("f6c344"))
			px(ci, o, 16, 18, 1, 2, col("f6c344"))
			px(ci, o, 7, 18, 10, 1, Color(col("f6c344"), 0.5))
			for k in 2:
				var lit := fmod(tm + k * 0.5, 1.0) < 0.5
				px(ci, o, 1 + k * 21, 15, 1, 2, col("ff5a4a") if lit else col("5a2a2a"))
		"hub":
			px(ci, o, 3, 10, 18, 10, col("e9edf2"))
			dome(ci, o, 8, 12, 11, col("dfe4ea"), col("ffffff"))
			px(ci, o, 11, 0, 2, 4, col("9aa1b0"))
			ci.draw_arc(o + Vector2(12 * P, 1 * P), 5, PI * 0.1, PI * 0.9, 6, col("d7e3ee"), 2.0)
			# moon + sprout emblem (original insignia)
			ci.draw_circle(o + Vector2(12 * P, 15 * P), 7, col("1d2f6b"))
			ci.draw_circle(o + Vector2(12 * P, 15 * P), 4, col("d7dbe3"))
			px(ci, o, 12, 12, 1, 3, col("4fd16b"))
			px(ci, o, 13, 12, 2, 1, col("7fe08a"))
	# level pips
	for l in lvl:
		px(ci, o, 1 + l * 3, 1, 2, 2, col("f6c344"))
	if not on and type != "solar" and type != "battery" and type != "pad":
		if fmod(tm, 1.0) < 0.6:
			px(ci, o, 19, 1, 4, 4, col("f05a4a"))
			px(ci, o, 20.5, 1.5, 1, 2, Color.WHITE)
			px(ci, o, 20.5, 4.0, 1, 0.5, Color.WHITE)

# ------------------------------------------------------------ crops (4x? art px tray)
static func crop(ci: CanvasItem, o: Vector2, c: String, g: float, tm: float) -> void:
	var leaf := col("4fbf5b")
	var dark := col("2f8a44")
	var stage := 0 if g < 0.25 else (1 if g < 0.6 else (2 if g < 1.0 else 3))
	var sway := 1.0 if sin(tm * 2.0) > 0.6 else 0.0
	if stage == 0:
		px(ci, o, 1.5, -1, 1, 1, leaf)
		return
	if stage == 1:
		px(ci, o, 1, -2, 2, 2, leaf)
		px(ci, o, 0, -2, 1, 1, dark)
		return
	match c:
		"lettuce":
			px(ci, o, 0, -3, 4, 3, col("7ddc5c") if stage == 3 else leaf)
			px(ci, o, 1, -4, 2, 1, col("a8f07a"))
		"radish":
			px(ci, o, 1, -5 + sway * 0, 1, 3, leaf); px(ci, o, 2, -5, 1, 3, dark)
			if stage == 3:
				px(ci, o, 1, -2, 2, 2, col("e8476a"))
		"potato":
			px(ci, o, 0, -4, 4, 3, dark); px(ci, o, 1, -5, 2, 1, leaf)
			if stage == 3:
				px(ci, o, 0, -1, 1, 1, col("c99a5b")); px(ci, o, 3, -1, 1, 1, col("c99a5b"))
		"tomato":
			px(ci, o, 1.5, -7, 1, 7, dark); px(ci, o, 0, -6, 4, 2, leaf)
			if stage == 3:
				px(ci, o, 0, -4, 1.5, 1.5, col("f0463c")); px(ci, o, 2.5, -3, 1.5, 1.5, col("f0463c"))
		"soy":
			px(ci, o, 0, -5, 4, 4, col("8fcf6a"))
			if stage == 3:
				px(ci, o, 1, -4, 1, 2, col("d8e8a0")); px(ci, o, 3, -3, 1, 2, col("d8e8a0"))
		"wheat":
			for k in 3:
				px(ci, o, k * 1.5, -7 + sway, 1, 7, col("d9c25a") if stage == 3 else col("9bc25a"))
			if stage == 3:
				px(ci, o, 0, -8 + sway, 4, 2, col("f2d36b"))
		"moonberry":
			px(ci, o, 0, -5, 4, 4, col("3f7f8f"))
			if stage == 3:
				var gl := 0.6 + 0.4 * sin(tm * 3.0)
				px(ci, o, 0, -4, 1.5, 1.5, Color(0.6, 0.55, 1.0, gl)); px(ci, o, 2.5, -2, 1.5, 1.5, Color(0.6, 0.55, 1.0, gl))
				px(ci, o, 1.5, -6, 1.5, 1.5, Color(0.8, 0.6, 1.0, gl))
	if stage == 3 and fmod(tm * 1.3, 2.0) < 0.3:
		px(ci, o, 3, -8, 1, 1, Color(1, 1, 0.7, 0.9))

# ------------------------------------------------------------ characters & vehicles
static func astronaut(ci: CanvasItem, o: Vector2, visor: Color, suit: Color, frame: int, s: float = 1.0) -> void:
	var q := P * s
	var r := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		ci.draw_rect(Rect2(o.x + x * q, o.y + y * q, w * q, h * q), c)
	var white := col("f2f4f7")
	var shade := col("b9c1cc")
	r.call(1, 0, 5, 5, white)
	r.call(2, 1, 3, 2, visor)
	r.call(2, 1, 1, 1, Color(1, 1, 1, 0.7))
	r.call(0, 5, 7, 4, white)
	r.call(0, 5, 1, 4, shade)
	r.call(2, 6, 3, 1, suit)
	r.call(-1, 5, 1, 3, suit)
	r.call(7, 5, 1, 3, suit)
	var lf := 1 if frame % 2 == 0 else 0
	r.call(1, 9, 2, 2 + lf, white)
	r.call(4, 9, 2, 3 - lf, white)

static func rover(ci: CanvasItem, o: Vector2, flip: bool, tm: float, s: float = 1.0) -> void:
	var q := P * s
	var r := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		var xx := (8 - x - w) if flip else x
		ci.draw_rect(Rect2(o.x - 4 * q + xx * q, o.y - 4 * q + y * q, w * q, h * q), c)
	r.call(0, 1, 8, 2, col("eef1f5"))
	r.call(0, 1, 8, 1, col("f09a3e"))
	r.call(5, -1, 1, 2, col("9aa1b0"))
	r.call(4, -2, 3, 1, col("d7e3ee"))
	var spin := 1 if fmod(tm * 8.0, 2.0) < 1.0 else 0
	for w in 3:
		r.call(w * 3, 3, 2, 2, col("2a2e38"))
		r.call(w * 3 + spin, 3 + spin, 1, 1, col("6d7383"))

static func rocket(ci: CanvasItem, o: Vector2, tm: float, thrust: bool) -> void:
	var r := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		ci.draw_rect(Rect2(o.x + (x - 5) * P, o.y + (y - 26) * P, w * P, h * P), c)
	if thrust:
		var f := 4 + int(fmod(tm * 30.0, 3.0))
		r.call(3, 24, 4, f, col("ffd56b"))
		r.call(4, 24, 2, f + 3, col("ff7b3a"))
	r.call(3, 2, 4, 2, col("e35d5d"))
	r.call(4, 0, 2, 2, col("e35d5d"))
	r.call(2, 4, 6, 18, col("f2f4f7"))
	r.call(2, 4, 1, 18, col("c9ced6"))
	r.call(4, 7, 2, 2, col("6cc6ff"))
	r.call(2, 14, 6, 1, col("1d2f6b"))
	r.call(0, 18, 2, 6, col("e35d5d"))
	r.call(8, 18, 2, 6, col("e35d5d"))
	r.call(3, 22, 4, 2, col("6d7383"))

static func earth(ci: CanvasItem, c: Vector2, rad: float) -> void:
	ci.draw_circle(c, rad + 2, Color(0.4, 0.7, 1.0, 0.25))
	ci.draw_circle(c, rad, col("2f6fd6"))
	var land := col("4fbf5b")
	ci.draw_rect(Rect2(c.x - rad * 0.5, c.y - rad * 0.4, rad * 0.5, rad * 0.45), land)
	ci.draw_rect(Rect2(c.x + rad * 0.1, c.y + rad * 0.05, rad * 0.4, rad * 0.5), land)
	ci.draw_rect(Rect2(c.x - rad * 0.3, c.y - rad * 0.9, rad * 0.6, rad * 0.2), Color.WHITE)
	ci.draw_circle(c + Vector2(rad * 0.35, rad * 0.2), rad * 0.9, Color(0, 0, 0.1, 0.0))
