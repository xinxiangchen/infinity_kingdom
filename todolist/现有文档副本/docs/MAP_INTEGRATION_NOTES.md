# Map Integration Notes

Map assets found:

```text
F:\无尽王国\infinity_kingdom\infinity_kingdom\game
F:\无尽王国\infinity_kingdom\infinity_kingdom\game\godot_project
```

The `game` folder contains large PNG room illustrations. Several filenames are mojibake, so the first integration step copied the usable room images into stable English paths:

```text
res://assets/maps/stitched_demo/room_01_outer_entrance.png
res://assets/maps/stitched_demo/room_02_street_battle_1.png
res://assets/maps/stitched_demo/room_03_street_battle_2.png
res://assets/maps/stitched_demo/room_04_central_plaza.png
res://assets/maps/stitched_demo/room_09_elite_zone.png
res://assets/maps/stitched_demo/room_10_palace_hall.png
res://assets/maps/stitched_demo/room_11_palace_corridor.png
res://assets/maps/stitched_demo/room_12_king_gate.png
```

The `game/godot_project` folder also contains a greybox map prototype with room and corridor scenes. Its useful structure is:

```text
scenes/rooms/*.tscn
scenes/corridors/*.tscn
scripts/room_base.gd
scripts/room_loader.gd
```

Recommended final direction:

- Use room scenes as gameplay units.
- Keep room metadata on a room facade script.
- Let encounter systems query entrances, exits, and spawn points.
- Keep high-resolution room PNGs as visual backdrops.
- Add collisions/walk masks later, either by TileMap or by authored CollisionPolygon2D.

For now, `res://tools/map_browser_demo.tscn` is a browsing prototype. It stitches room PNGs into a long route and gives a placeholder player plus camera. Adjacent room images are placed edge-to-edge: each room's left edge is treated as an entrance and its right edge is treated as an exit.

The demo now uses the matching transparent prop layers under `res://assets/maps/stitched_demo/props/`. Each room has a set of visually checked prop candidates, and every run randomly chooses a few cover props per room. Generated cover props are `StaticBody2D` nodes with their own `CollisionShape2D`, so they can be used as temporary cover against bullets or melee attack traces.

Camera and room flow:

- The camera is locked to the active room and clamps inside that room's bounds.
- The camera zoom is intentionally closer than the old browser view, so a room is not shown all at once.
- The player cannot leave through the right exit until the active room is cleared.
- In this prototype, pressing `C` marks the active room as cleared. In the real integration, replace that with an enemy-death counter from the encounter system.
- After clearing, walking into the right exit transfers the player to the next room's left entrance.

Main flow mapping in `res://world.gd`:

```text
room_01_outer_entrance      -> town mob encounter
room_02_street_battle_1     -> town mob encounter
room_03_street_battle_2     -> town mob encounter
room_04_central_plaza       -> town mob encounter
room_09_elite_zone          -> town mob encounter
room_10_palace_hall         -> Judicator boss
room_11_palace_corridor     -> Royal Guard Formation
room_12_king_gate           -> Twin Princes boss
```

The first five rooms are treated as outside/approach rooms and use the six soldier enemy types. The first palace room uses the first boss. The king gate / throne-front room uses the final twin boss.

The same demo also places six enemy material previews on top of the stitched route:

```text
res://actors/enemy/textures/swordsman.png
res://actors/enemy/textures/shield.png
res://actors/enemy/textures/hunter.png
res://actors/enemy/textures/archer.png
res://actors/enemy/textures/arcanist.png
res://actors/enemy/textures/apprentice_mage.png
```

These are visual previews only. They do not run enemy AI or combat logic yet.
