class_name GameIcons
extends RefCounted
## Silhouette vettoriali: nessuna texture raster o sigla da decifrare.
## Coordinate locali 0..1; tutte le icone condividono bordi e proporzioni.


static func _poly(c: CanvasItem, r: Rect2, points: Array, color: Color) -> void:
	var vertices := PackedVector2Array()
	for p: Vector2 in points:
		vertices.append(r.position + p * r.size)
	c.draw_colored_polygon(vertices, color)
	vertices.append(vertices[0])
	c.draw_polyline(vertices, color.darkened(0.45), maxf(1.0, r.size.x * 0.025), true)


static func _line(c: CanvasItem, r: Rect2, a: Vector2, b: Vector2, color: Color, width: float = 0.06) -> void:
	c.draw_line(r.position + a * r.size, r.position + b * r.size, color, maxf(1.2, r.size.x * width), true)


static func _cube(c: CanvasItem, r: Rect2, color: Color) -> void:
	_poly(c, r, [Vector2(.5, .08), Vector2(.91, .29), Vector2(.5, .5), Vector2(.09, .29)], color.lightened(.22))
	_poly(c, r, [Vector2(.09, .29), Vector2(.5, .5), Vector2(.5, .94), Vector2(.09, .72)], color.darkened(.12))
	_poly(c, r, [Vector2(.5, .5), Vector2(.91, .29), Vector2(.91, .72), Vector2(.5, .94)], color.darkened(.3))


static func action(c: CanvasItem, r: Rect2, id: StringName, color: Color = GamePalette.INK) -> void:
	match id:
		&"attack", &"heavy":
			_poly(c, r, [Vector2(.32, .6), Vector2(.68, .13), Vector2(.9, .08), Vector2(.85, .3), Vector2(.43, .7)], color)
			_line(c, r, Vector2(.16, .55), Vector2(.54, .85), GamePalette.ACCENT, .09)
			_line(c, r, Vector2(.3, .73), Vector2(.13, .94), color, .1)
			if id == &"heavy":
				_line(c, r, Vector2(.05, .24), Vector2(.24, .39), color, .045)
				_line(c, r, Vector2(.28, .08), Vector2(.34, .26), color, .045)
		&"jump":
			_line(c, r, Vector2(.5, .8), Vector2(.5, .16), color, .11)
			_line(c, r, Vector2(.23, .43), Vector2(.5, .16), color, .11)
			_line(c, r, Vector2(.77, .43), Vector2(.5, .16), color, .11)
			_line(c, r, Vector2(.25, .95), Vector2(.75, .95), GamePalette.ACCENT, .045)
		&"dodge":
			c.draw_arc(r.get_center(), r.size.x * .34, -.8, 3.8, 24, color, maxf(1.5, r.size.x * .07), true)
			_poly(c, r, [Vector2(.78, .1), Vector2(.98, .48), Vector2(.58, .37)], color)
		&"lock":
			for p: Vector2 in [Vector2(.12, .12), Vector2(.88, .12), Vector2(.12, .88), Vector2(.88, .88)]:
				var d := (Vector2(.5, .5) - p).sign()
				_line(c, r, p, p + Vector2(d.x * .2, 0), color)
				_line(c, r, p, p + Vector2(0, d.y * .2), color)
			c.draw_circle(r.get_center(), r.size.x * .08, GamePalette.ACCENT)
		&"menu":
			for y in [.25, .5, .75]:
				_line(c, r, Vector2(.15, y), Vector2(.85, y), color)
		&"bag":
			_poly(c, r, [Vector2(.2, .32), Vector2(.8, .32), Vector2(.88, .9), Vector2(.12, .9)], color)
			c.draw_arc(r.position + r.size * Vector2(.5, .34), r.size.x * .2, PI, TAU, 14, color, maxf(1.5, r.size.x * .06), true)
			_line(c, r, Vector2(.33, .6), Vector2(.67, .6), GamePalette.PANEL)
		&"camera":
			_poly(c, r, [Vector2(.1, .3), Vector2(.3, .3), Vector2(.35, .17), Vector2(.65, .17), Vector2(.7, .3), Vector2(.9, .3), Vector2(.9, .83), Vector2(.1, .83)], color)
			c.draw_circle(r.position + r.size * Vector2(.5, .56), r.size.x * .18, GamePalette.PANEL)
			c.draw_circle(r.position + r.size * Vector2(.5, .56), r.size.x * .11, color)
		&"hero":
			c.draw_circle(r.position + r.size * Vector2(.5, .28), r.size.x * .2, color)
			_poly(c, r, [Vector2(.1, .94), Vector2(.2, .62), Vector2(.5, .52), Vector2(.8, .62), Vector2(.9, .94)], color)


static func item(c: CanvasItem, r: Rect2, d: ItemDefinition) -> void:
	if d == null:
		return
	var color := d.color
	var name := String(d.id)
	if d.kind == ItemDefinition.Kind.BLOCK and d.id != &"torch":
		_cube(c, r, color)
		if d.id == &"wood":
			for y in [.43, .61]:
				_line(c, r, Vector2(.18, y), Vector2(.41, y + .12), color.lightened(.22), .025)
	elif d.kind == ItemDefinition.Kind.TOOL or d.kind == ItemDefinition.Kind.WEAPON:
		var kind := String(d.weapon) if d.kind == ItemDefinition.Kind.WEAPON else d.tool_type
		if kind in ["sword", "greatsword"]:
			action(c, r, &"heavy" if kind == "greatsword" else &"attack", color)
		else:
			_line(c, r, Vector2(.27, .93), Vector2(.62, .19), Color("#b68a52"), .1)
			match kind:
				"spear":
					_poly(c, r, [Vector2(.49, .33), Vector2(.72, .02), Vector2(.74, .38)], color)
				"pick":
					_poly(c, r, [Vector2(.15, .26), Vector2(.44, .08), Vector2(.75, .18), Vector2(.94, .5), Vector2(.64, .31), Vector2(.41, .23)], color)
				"axe":
					_poly(c, r, [Vector2(.52, .12), Vector2(.82, .12), Vector2(.96, .43), Vector2(.75, .58), Vector2(.48, .37)], color)
				"hammer":
					_poly(c, r, [Vector2(.3, .06), Vector2(.94, .25), Vector2(.85, .58), Vector2(.2, .4)], color)
				"shovel":
					_poly(c, r, [Vector2(.55, .08), Vector2(.89, .19), Vector2(.83, .42), Vector2(.56, .52), Vector2(.42, .3)], color)
	elif d.kind == ItemDefinition.Kind.ARMOR:
		match d.slot:
			"head":
				_poly(c, r, [Vector2(.13, .85), Vector2(.16, .25), Vector2(.5, .06), Vector2(.84, .25), Vector2(.87, .85), Vector2(.62, .7), Vector2(.62, .49), Vector2(.38, .49), Vector2(.38, .7)], color)
			"chest":
				_poly(c, r, [Vector2(.04, .28), Vector2(.32, .11), Vector2(.5, .25), Vector2(.68, .11), Vector2(.96, .28), Vector2(.85, .5), Vector2(.73, .45), Vector2(.76, .91), Vector2(.24, .91), Vector2(.27, .45), Vector2(.15, .5)], color)
			"legs":
				_poly(c, r, [Vector2(.2, .1), Vector2(.8, .1), Vector2(.85, .93), Vector2(.57, .93), Vector2(.5, .46), Vector2(.43, .93), Vector2(.15, .93)], color)
			"feet":
				for x in [.06, .51]:
					_poly(c, r, [Vector2(x, .15), Vector2(x + .28, .15), Vector2(x + .28, .64), Vector2(x + .41, .75), Vector2(x + .4, .93), Vector2(x, .93)], color)
	elif d.kind == ItemDefinition.Kind.SCROLL:
		_poly(c, r, [Vector2(.2, .1), Vector2(.87, .1), Vector2(.76, .9), Vector2(.09, .9)], Color("#e3ce99"))
		for y in [.32, .47, .62]:
			_line(c, r, Vector2(.3, y), Vector2(.65, y), color.darkened(.45), .04)
	elif d.id == &"torch" or d.id == &"campfire":
		_line(c, r, Vector2(.35, .93), Vector2(.57, .47), Color("#bc915b"), .14)
		if d.id == &"campfire":
			_line(c, r, Vector2(.12, .91), Vector2(.88, .72), Color("#bc915b"), .12)
			_line(c, r, Vector2(.12, .72), Vector2(.88, .91), Color("#bc915b"), .12)
		_poly(c, r, [Vector2(.33, .5), Vector2(.38, .23), Vector2(.55, .06), Vector2(.59, .3), Vector2(.75, .22), Vector2(.8, .48), Vector2(.57, .65)], Color("#f1a74e"))
	elif d.id == &"workbench":
		_poly(c, r, [Vector2(.08, .17), Vector2(.92, .17), Vector2(.92, .43), Vector2(.08, .43)], color.lightened(.15))
		_line(c, r, Vector2(.23, .42), Vector2(.2, .94), color, .12)
		_line(c, r, Vector2(.77, .42), Vector2(.8, .94), color, .12)
	elif d.id == &"chest" or d.id == &"furnace":
		_cube(c, r, color)
		if d.id == &"chest":
			_line(c, r, Vector2(.1, .5), Vector2(.5, .69), GamePalette.ACCENT, .055)
			_line(c, r, Vector2(.5, .69), Vector2(.91, .49), GamePalette.ACCENT, .055)
		else:
			_poly(c, r, [Vector2(.6, .55), Vector2(.8, .45), Vector2(.8, .71), Vector2(.6, .81)], GamePalette.PANEL)
	elif d.id == &"stick":
		_line(c, r, Vector2(.23, .92), Vector2(.75, .09), color.lightened(.25), .12)
	elif name.ends_with("_ingot"):
		_poly(c, r, [Vector2(.25, .24), Vector2(.75, .24), Vector2(.96, .74), Vector2(.04, .74)], color)
		_line(c, r, Vector2(.27, .36), Vector2(.74, .36), color.lightened(.35), .04)
	else:
		_poly(c, r, [Vector2(.12, .7), Vector2(.22, .24), Vector2(.6, .09), Vector2(.9, .35), Vector2(.88, .8), Vector2(.5, .93)], color)
		_line(c, r, Vector2(.3, .3), Vector2(.59, .23), color.lightened(.4), .09)
