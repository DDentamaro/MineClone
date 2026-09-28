class_name Loot
extends RefCounted
## Rarita' e affissi dell'equipaggiamento (M5).
## Comune (nessun affisso), Non comune (1), Raro (2), Epico (3).

const RARITY_NAMES := ["Comune", "Non comune", "Raro", "Epico"]
const RARITY_COLORS := [Color(0.85, 0.85, 0.82), Color(0.45, 0.85, 0.45), Color(0.40, 0.65, 1.0), Color(0.78, 0.45, 1.0)]
## Affisso: [min, max, dove si puo' trovare, suffisso del nome, descrizione].
const AFFIXES := {
	"strength": [0.08, 0.20, ["weapon", "armor"], "del Forte", "+%d%% danno corpo a corpo"],
	"crit": [0.04, 0.10, ["weapon", "armor"], "della Precisione", "+%d%% critico"],
	"mana_max": [10.0, 25.0, ["weapon", "armor"], "della Mente", "+%d mana"],
	"mana_regen": [1.0, 3.0, ["weapon", "armor"], "del Flusso", "+%d mana/s"],
	"arcane": [0.08, 0.20, ["weapon", "armor"], "dell'Arcano", "+%d%% danno delle magie"],
	"dig": [0.10, 0.30, ["tool", "armor"], "del Minatore", "+%d%% velocità di scavo"],
	"speed": [0.04, 0.10, ["armor"], "del Vento", "+%d%% velocità"],
	"tough": [0.20, 0.50, ["tool", "weapon"], "della Tempra", "+%d%% resistenza"],
}


static func roll_rarity(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return 0


static func _family(d: ItemDefinition) -> String:
	match d.kind:
		ItemDefinition.Kind.WEAPON:
			return "weapon"
		ItemDefinition.Kind.ARMOR:
			return "armor"
		ItemDefinition.Kind.TOOL:
			return "tool"
	return ""


## Crea un'istanza di equipaggiamento con rarita' e affissi.
static func make_equipment(id: StringName, rarity: int, rng: RandomNumberGenerator) -> ItemStack:
	var d := ItemLibrary.get_item(id)
	var s := ItemStack.new(id, 1)
	if d == null or not d.is_equipment():
		return s
	var fam := _family(d)
	var pool: Array[String] = []
	for k: String in AFFIXES:
		if (AFFIXES[k][2] as Array).has(fam):
			pool.append(k)
	var mods := {}
	var n := mini(rarity, pool.size())
	for i in n:
		var k: String = pool[rng.randi() % pool.size()]
		pool.erase(k)
		var a: Array = AFFIXES[k]
		var v := lerpf(float(a[0]), float(a[1]), rng.randf())
		mods[k] = snappedf(v, 0.01 if float(a[1]) < 1.0 else 1.0)
	var data := {}
	if rarity > 0:
		data["rarity"] = rarity
		data["mods"] = mods
	if d.durability > 0:
		var dur := d.durability * (1.0 + float(mods.get("tough", 0.0)))
		data["max_wear"] = int(dur)
		data["wear"] = int(dur)
	s.data = data
	return s


## Nome completo, per esempio "Spada di ferro della Mente".
static func full_name(s: ItemStack) -> String:
	var d := s.def()
	var n := d.display_name
	var mods: Dictionary = s.data.get("mods", {})
	if not mods.is_empty():
		var best := ""
		var bv := -1.0
		for k: String in mods:
			var a: Array = AFFIXES[k]
			var rel := (float(mods[k]) - float(a[0])) / maxf(1e-4, float(a[1]) - float(a[0]))
			if rel > bv:
				bv = rel
				best = k
		n += " " + String(AFFIXES[best][3])
	return n


## Righe di descrizione degli affissi.
static func describe(s: ItemStack) -> Array[String]:
	var out: Array[String] = []
	var d := s.def()
	if d.kind == ItemDefinition.Kind.WEAPON:
		out.append("danno ×%.2f" % d.damage)
	elif d.kind == ItemDefinition.Kind.ARMOR:
		out.append("difesa %.1f" % d.defense)
	elif d.kind == ItemDefinition.Kind.TOOL:
		out.append("velocità %.1f · livello %d" % [d.speed, d.tier])
	var mods: Dictionary = {}
	mods.merge(d.base_mods)
	mods.merge(s.data.get("mods", {}), true)
	for k: String in mods:
		var a: Array = AFFIXES.get(k, [0, 0, [], "", k + " %d"])
		var v := float(mods[k])
		out.append(String(a[4]) % (roundi(v * 100.0) if v < 1.0 and k != "mana_regen" else roundi(v)))
	if s.data.has("wear"):
		out.append("usura %d/%d" % [int(s.data["wear"]), int(s.data.get("max_wear", d.durability))])
	return out
