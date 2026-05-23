# Infinity Kingdom

Godot 4 action prototype with three playable families, a town boss rush, custom UI art, audio mix controls, and an accessory relic system.

![Infinity Kingdom title art](assets/ui/background/title_screen_bg.png)

## Features

- Three playable families: Knight, Ranger, and Mage.
- Boss-rush loop with town mobs, elite bosses, and victory/defeat flow.
- Accessory relic system with generated choices, current relic display, and stat modifiers.
- Custom UI art library for buttons, panels, icons, bars, portraits, and relic cards.
- Layered music, ambience, SFX, and an in-game audio mix panel.
- Headless smoke test for project boot and accessory selection flow.

## Run

1. Open `project.godot` with Godot 4.6 or newer.
2. Run `world.tscn`.
3. Pick Knight, Ranger, or Mage.
4. Choose an accessory at the start and after each cleared encounter.

On Windows, double-click `start_game.bat` to launch the game with the bundled local Godot copy if present.

Useful script options:

```powershell
.\start_game.bat
.\start_game.bat -Editor
.\start_game.bat -Test
```

## Controls

- `WASD`: move
- `J` or left mouse: attack
- `K`, `L`, `I`: skills
- `F10`: audio mix panel
- `Esc`: close audio panel

## Test

```powershell
godot --headless --path . --quit --verbose
godot --headless --path . --script res://tests/smoke_accessory_flow.gd
godot --headless --path . --script res://tests/smoke_ui_screens.gd
```

GitHub Actions runs the same smoke checks on every push and pull request.

## Export

Export presets are committed for:

- Windows Desktop: `build/windows/InfinityKingdom.exe`
- Web: `build/web/index.html`

Install the matching Godot export templates, then export from the Godot editor or CLI.

## Structure

- `characters/`: playable character scenes and state machines
- `actors/`: enemies, encounters, and town bosses
- `combat/`: shared health and defense component
- `effects/`: damage numbers and projectiles
- `systems/accessories/`: accessory data, equip logic, and stat application
- `ui/`: HUD, character select, accessory choice, and UI skin helpers
- `assets/`: committed gameplay and UI art assets
- `audio/`: music, ambience, SFX managers, generated placeholder audio

See `docs/PROJECT_STRUCTURE.md` for the runtime flow and accessory system notes.

## License

Public source repository. All rights reserved; see `LICENSE`.
