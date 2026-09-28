class_name Harvest
extends RefCounted
## Regole di raccolta: BLOCK_INFO, breakTime e treeTime del prototipo (HTML
## 7108, 7760–7761, dormienti la') con i livelli dei minerali aggiunti (M5):
## rame da pietra in su, ferro da rame, oro da ferro.

const INFO := {
	BlockCatalog.GRASS: [.6, "shovel", 0], BlockCatalog.DIRT: [.5, "shovel", 0], BlockCatalog.SAND: [.5, "shovel", 0],
	BlockCatalog.STONE: [1.5, "pick", 1], BlockCatalog.SANDSTONE: [.8, "pick", 1], BlockCatalog.DARKSTONE: [2.5, "pick", 1],
	BlockCatalog.COPPER: [3.0, "pick", 2], BlockCatalog.IRON: [3.0, "pick", 3], BlockCatalog.GOLD: [3.0, "pick", 4],
	BlockCatalog.WOOD: [2.0, "axe", 0], BlockCatalog.LEAVES: [.2, "axe", 0], BlockCatalog.TORCH: [0.0, "shovel", 0],
}


## Tempo di rottura in secondi (INF = indistruttibile). `tool` puo' essere null (a mani nude).
static func break_time(id: int, tool: ItemDefinition, dig_mult: float = 1.0) -> float:
	if not INFO.has(id):
		return INF
	var bi: Array = INFO[id]
	var hard: float = bi[0]
	if hard == 0.0:
		return 0.05
	var speed := tool.speed if tool != null and tool.kind == ItemDefinition.Kind.TOOL else 1.0
	var right: bool = tool != null and tool.tool_type == String(bi[1])
	return hard * (1.5 if right else 5.0) / (speed * dig_mult)


## Il blocco rotto lascia l'oggetto? Serve l'attrezzo giusto e il livello del
## materiale (la terra e la sabbia si raccolgono anche a mani nude).
static func drops(id: int, tool: ItemDefinition) -> bool:
	if not INFO.has(id):
		return false
	var bi: Array = INFO[id]
	var level: int = bi[2]
	if level == 0 and bi[1] == "shovel":
		return true
	if tool == null or tool.tool_type != bi[1]:
		return level == 0 and bi[1] == "axe" and id == BlockCatalog.WOOD
	return tool.tier >= level


static func tree_time(scale: float, tool: ItemDefinition, dig_mult: float = 1.0) -> float:
	var speed := tool.speed if tool != null and tool.kind == ItemDefinition.Kind.TOOL else 1.0
	var axe := tool != null and tool.tool_type == "axe"
	return (4.0 + 3.0 * scale) * (1.0 if axe else 2.5) / (speed * dig_mult)


static func tree_wood(scale: float) -> int:
	return 2 + roundi(2.0 * scale)
