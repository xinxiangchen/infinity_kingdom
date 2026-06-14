# Character Module API

This document is the contract between the character team and the integration team.

The short version: character code may change internally, but external systems should only call the public methods and listen to the public signals listed here. This keeps the GDScript prototype ready for a later C++/GDExtension rewrite.

## Module Boundary

The character module owns:

- Movement input interpretation for the active player actor.
- Character state machine and state transitions.
- Normal attack and skill execution.
- Character-local cooldowns, resource consumption, invulnerability, control effects, and death.
- Character visual presentation: body sprite, weapon sprite, attack arcs, local VFX, damage numbers.

The character module must not own:

- Run progression, rewards, relic choice, or level flow.
- Encounter spawning or wave sequencing.
- HUD layout or menu behavior.
- Enemy AI decisions.
- Global audio routing.

## Public Signals

Every playable character must expose these signals:

```gdscript
signal attack_started(attack_name: StringName)
signal attack_hit(attack_name: StringName, target: Node)
signal attack_finished(attack_name: StringName)
signal skill_used(skill_name: StringName)
signal hp_changed(current_hp: float, max_hp_value: float)
signal inspiration_changed(current_inspiration: float, max_inspiration_value: float)
signal took_damage(amount: float, remaining_hp: float)
signal shield_changed(current_shield: float)
signal defense_changed(current_defense: float, max_defense_value: float)
signal control_status_changed(summary: String)
signal died
```

Optional, if the character supports build-time upgrades:

```gdscript
signal upgrades_changed
```

## Public Methods

Every playable character must expose these methods:

```gdscript
func get_character_name() -> String
func emit_stat_signals() -> void

func receive_hit(payload: Dictionary) -> void
func heal(amount: float) -> void

func gain_inspiration(amount: float) -> void
func can_cast_skill(skill_name: StringName) -> bool

func apply_control_effects(payload: Dictionary) -> void
func clear_control_effects(clear_silence: bool = false, clear_root: bool = true, clear_slow: bool = true) -> void
func get_control_status_text() -> String
func get_effective_move_speed() -> float
func is_silenced() -> bool
func is_rooted() -> bool
func is_slowed() -> bool
```

Optional upgrade API:

```gdscript
func get_upgrade_sections() -> Array
func is_upgrade_enabled(upgrade_id: String) -> bool
func set_upgrade_enabled(upgrade_id: String, enabled: bool) -> void
func clear_all_upgrades() -> void
```

## Required Public Properties

Integration code may read these properties for HUD and run systems:

```gdscript
var hp: float
var max_hp: float
var inspiration: float
var max_inspiration: float
var defense: float
var max_defense: float
var shield: float
var move_speed: float
var attack_damage: float
var attack_interval: float
var crit_rate: float
var cooldowns: Dictionary
```

If C++/GDExtension replaces the GDScript character, these properties should remain exposed through Godot property binding.

## Hit Payload Contract

Characters receive damage through:

```gdscript
receive_hit(payload: Dictionary)
```

The common payload keys are:

```gdscript
{
  "source": Node,
  "damage": float,
  "crit_rate": float,
  "damage_multiplier": float,
  "damage_multiplier_duration": float,
  "silence_duration": float,
  "root_duration": float,
  "slow_duration": float,
  "slow_multiplier": float
}
```

Unknown keys must be ignored by the receiver. This lets relics, enemies, and later C++ systems add effects without breaking older characters.

## Character Team Rules

- Keep each character scene root as `CharacterBody2D`.
- Keep the root node in group `player`.
- Keep `HealthComponent` as the authority for HP, defense, shield, and death unless a replacement component exposes the same methods and signals.
- Do not make UI nodes children of a character.
- Do not directly control run flow from character code.
- Do not assume a specific HUD exists.
- Use signals for events that other modules need.
- Prefer helper components/scripts for visuals, skills, and payload construction instead of growing one huge character file.

Recommended future split:

```text
characters/<hero>/
  <hero>.tscn
  <hero>.gd                  # public facade and high-level orchestration
  state_machine.gd
  states/*.gd
  components/
    character_combat.gd      # hit payloads, target selection, damage dispatch
    character_controls.gd    # silence/root/slow
    character_visuals.gd     # body, weapon, death texture, local VFX
    skill_controller.gd      # skill cooldowns/costs/requests
```

## Integration Team Rules

- Spawn characters only from their `.tscn`.
- Bind HUD by signals and public properties.
- Apply relic/stat effects through `AccessoryManager` or a future combat-effect service.
- Do not reach into a character state node directly.
- Do not edit character internals from world/encounter scripts.
- Check for optional APIs with `has_method()` when possible.

## C++/GDExtension Migration Target

When moving to C++/GDExtension, keep the Godot-facing facade stable:

- Same root scene path.
- Same signal names.
- Same method names.
- Same property names.
- Same payload dictionary keys.

The implementation behind those APIs can move from GDScript to C++ without requiring the world, HUD, encounter, and relic modules to change.
