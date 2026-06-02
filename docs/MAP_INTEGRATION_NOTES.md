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

For now, `res://tools/map_browser_demo.tscn` is only a browsing prototype. It stitches room PNGs into a long route and gives a placeholder player plus camera.
