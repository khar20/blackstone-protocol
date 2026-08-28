extends Node
## Placeholder audio removed. All SFX.* no-op until proper sound effects land.
## Signatures stay so call sites keep working; drop in real AudioStreamPlayers
## later without touching the rest of the game.

func cannon_fire() -> void:
	pass

func turret_shot() -> void:
	pass

func impact() -> void:
	pass

func reload_start() -> void:
	pass

func reload_success(_rel: float) -> void:
	pass

func reload_fail(_rel: float) -> void:
	pass

func node_depleted() -> void:
	pass

func monolith_neutralized() -> void:
	pass

func panel_open() -> void:
	pass

func panel_close() -> void:
	pass

func ui_blip() -> void:
	pass

func ui_move() -> void:
	pass

func unaffordable() -> void:
	pass

func overheat() -> void:
	pass

func weapon_switch() -> void:
	pass

func shard_impact() -> void:
	pass

func shockwave_slam() -> void:
	pass

func drift_skid() -> void:
	pass