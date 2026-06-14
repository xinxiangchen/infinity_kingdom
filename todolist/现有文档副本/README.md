# Infinity Kingdom

Godot 4 action prototype with three playable families, a town boss rush, custom UI art, audio mix controls, and an accessory relic system.

![Infinity Kingdom title art](assets/ui/background/title_screen_bg.png)

## Features

- Three playable families: Knight, Ranger, and Mage.
- Boss-rush loop with town mobs, elite bosses, cleaner victory/defeat flow, and no dead-end post-boss event.
- Accessory relic system with generated choices, current relic display, and stat modifiers.
- Mid-run event deck with shop, relic resonance, rest, training, and high-risk pact branches.
- Variable town enemy sweep waves instead of a single fixed opener every run.
- Custom UI art library for buttons, panels, icons, bars, portraits, and relic cards.
- Layered music, ambience, SFX, and an in-game audio mix panel.
- Headless smoke test for project boot and accessory selection flow.

## Run

1. Open `project.godot` with Godot 4.6 or newer.
2. Launch the project and enter through the title menu in `app_entry.tscn`.
3. Pick Knight, Ranger, or Mage.
4. Choose an accessory at the start and after each cleared encounter.

On Windows, double-click `start_game.bat` to launch the game with the bundled local Godot copy if present. The script refreshes Godot imports first, so a freshly synced archive can start without opening the editor once by hand.

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
- `` ` ``: debug panel
- Gamepad: left stick move, south button attack, west/north/east buttons skills

## Test

```powershell
.\start_game.bat -Test
```

GitHub Actions runs the same smoke checks on every push and pull request.

## Optional C++ Extension Scaffold

The `src/`, `SConstruct`, and `demo/coursework_extension.gdextension.example` files are a scaffold for the later Godot C++ coursework extension. Normal gameplay, UI work, and smoke tests do not require compiling it.

If you want to work on the C++ side:

```powershell
git submodule update --init --recursive
Copy-Item demo\coursework_extension.gdextension.example demo\coursework_extension.gdextension
```

Then build the library with SCons as described in `docs/cpp-workflow.md`.

## Export

Export presets are committed for:

- Windows Desktop: `build/windows/InfinityKingdom.exe`
- Web: `build/web/index.html`

Install the matching Godot export templates, then export from the Godot editor or CLI.

On Windows:

```powershell
.\export_game.bat
.\export_game.bat -Preset Web
```

## Structure

- `characters/`: playable character scenes and state machines
- `actors/`: enemies, encounters, and town bosses
- `combat/`: shared health and defense component
- `effects/`: damage numbers and projectiles
- `systems/accessories/`: accessory data, equip logic, and stat application
- `systems/run/`: run rewards, event sequencing, and run event effects
- `systems/feedback/`: combat feedback helpers such as hitstop
- `ui/`: HUD, character select, accessory choice, and UI skin helpers
- `assets/`: committed gameplay and UI art assets
- `audio/`: music, ambience, SFX managers, generated placeholder audio

See `docs/PROJECT_STRUCTURE.md` for the runtime flow and accessory system notes.

## License

Public source repository. All rights reserved; see `LICENSE`.
