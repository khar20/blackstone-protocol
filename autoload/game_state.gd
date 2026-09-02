extends Node
## Persistent run state. Survives respawns; world state (settlements, boss
## zones, mining nodes) lives on the World node instead. Formulas mirror the
## JS player object / recomputeStats() in sample.html.

const MAX_CHAMBER: int = 6
const RELOAD_TIME_BASE: float = 2.8
const RELOAD_TIME_MIN: float = 1.1

var hull: float = 100.0
var max_hull: float = 100.0
var heat: float = 0.0
var inventory: Dictionary = { 'amber': 0.0, 'obsidian': 0.0, 'prism': 0.0 }
var cargo: float = 0.0

var cannon_level: int = 0
var armor_level: int = 0
var drift_level: int = 0
var reload_level: int = 0
var mining_level: int = 0
var arc_level: int = 0
var turret_level: int = 0
var cooling_level: int = 0

var reload_time: float = RELOAD_TIME_BASE
var sweet_start: float = 0.58
var sweet_end: float = 0.8
var arc_limit: float = 45.0 * PI / 180.0
var turret_slew_rate: float = 2.2
var max_heat: float = 100.0
var heat_cool_rate: float = 20.0
var max_speed: float = 24.0

var mission_phase: String = 'intro'
var mission_warn_timer: float = 0.0
var mission_was_outside: bool = false
var compass_angle: float = 0.0
var state: String = 'TITLE'

func recompute_stats() -> void:
	max_hull = 100.0 + armor_level * 25.0
	reload_time = maxf(RELOAD_TIME_MIN, RELOAD_TIME_BASE - reload_level * 0.34)
	sweet_start = maxf(0.35, 0.58 - reload_level * 0.04)
	sweet_end = minf(0.92, 0.8 + reload_level * 0.03)
	arc_limit = (45.0 + arc_level * 12.0) * PI / 180.0
	turret_slew_rate = 2.2 + arc_level * 0.35
	max_heat = 100.0 + cooling_level * 25.0
	heat_cool_rate = 20.0 + cooling_level * 7.0
	max_speed = 24.0 + drift_level * 2.5

func reset_combat() -> void:
	hull = max_hull
	heat = 0.0

func reset_run() -> void:
	cannon_level = 0
	armor_level = 0
	drift_level = 0
	reload_level = 0
	mining_level = 0
	arc_level = 0
	turret_level = 0
	cooling_level = 0
	inventory = { 'amber': 0.0, 'obsidian': 0.0, 'prism': 0.0 }
	cargo = 0.0
	recompute_stats()
	reset_combat()

func upgrade_cost(level: int, base: float) -> int:
	return roundi(base * (1.0 + level * 1.4))

func upgrade_maxed(level: int) -> bool:
	return level >= 5