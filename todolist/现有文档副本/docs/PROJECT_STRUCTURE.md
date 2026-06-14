# Project Structure

Infinity Kingdom is a Godot 4 action prototype centered on a short town boss-rush loop.

## Runtime Flow

1. `world.tscn` loads the title UI, audio managers, HUD, character select, and accessory choice UI.
2. The player selects Knight, Ranger, or Mage.
3. `AccessoryManager` resets the run and opens the first relic choice.
4. Encounters advance in order: a variable town enemy sweep, Judicator, Royal Guard Formation, Twin Princes.
5. `RunDirector` awards gold, then deals a short event deck of shop plus shuffled rest/training/pact/attunement branches.

## Main Folders

- `characters/`: playable character scenes, controllers, and state machines.
- `actors/`: enemy units, encounter controllers with variable waves, and town bosses.
- `combat/`: shared health and defense logic.
- `effects/`: damage numbers and projectile scenes.
- `systems/accessories/`: relic data, choice generation, stat application, and equipped state.
- `systems/run/`: run state, gold rewards, event sequencing, and event stat effects.
- `systems/feedback/`: combat feedback helpers such as hitstop.
- `ui/`: HUD, character selection, accessory choice, audio panel, and skin helpers.
- `assets/`: committed UI art, portraits, icons, bars, frames, and backgrounds.
- `audio/`: music/SFX managers, generated placeholder audio, and generation prompts.
- `tests/`: headless smoke tests for project boot and accessory flow.

## Accessory System

`systems/accessories/accessory_manager.gd` owns the accessory catalogue and current run state.
Accessories apply additive or percentage-based modifiers to actor stats, then resync health,
defense, inspiration, and HUD signals. `ui/accessory_choice.tscn` displays the generated choices
and emits the selected relic back to `world.gd`.

Accessory data lives in `systems/accessories/accessories.json`. The manager validates the JSON at
load time and falls back to its built-in catalog if the file is missing or malformed.

## Run Events

`systems/run/run_director.gd` tracks gold, cleared encounters, and the remaining event deck.
`ui/run_event_panel.tscn` offers shop, rest, training, relic resonance, and pact choices;
`systems/run/run_effects.gd` applies the selected reward or tradeoff to the current character.
