extends Node2D

const ROOM_PATHS := [
	"res://assets/maps/stitched_demo/room_01_outer_entrance.png",
	"res://assets/maps/stitched_demo/room_02_street_battle_1.png",
	"res://assets/maps/stitched_demo/room_03_street_battle_2.png",
	"res://assets/maps/stitched_demo/room_04_central_plaza.png",
	"res://assets/maps/stitched_demo/room_05_church.png",
	"res://assets/maps/stitched_demo/room_06_armory.png",
	"res://assets/maps/stitched_demo/room_07_shop.png",
	"res://assets/maps/stitched_demo/room_08_inner_gate.png",
	"res://assets/maps/stitched_demo/room_09_elite_zone.png",
	"res://assets/maps/stitched_demo/room_10_palace_hall.png",
	"res://assets/maps/stitched_demo/room_11_palace_corridor.png",
	"res://assets/maps/stitched_demo/room_12_king_gate.png",
	"res://assets/maps/stitched_demo/room_13_throne_room.png"
]

static func room_path_for_index(index: int) -> String:
	if index < 0 or index >= ROOM_PATHS.size():
		return ""
	return String(ROOM_PATHS[index])

const ROOM_TITLES := [
	"01 Outer Entrance",
	"02 Street Battle 1",
	"03 Street Battle 2",
	"04 Central Plaza",
	"05 Church",
	"06 Armory",
	"07 Shop",
	"08 Inner Gate",
	"09 Elite Zone",
	"10 Palace Hall",
	"11 Palace Corridor",
	"12 King Gate",
	"13 Throne Room"
]

const ROOM_PROP_LAYER_PATHS := [
	"res://assets/maps/stitched_demo/props/room_01_props.png",
	"res://assets/maps/stitched_demo/props/room_02_props.png",
	"res://assets/maps/stitched_demo/props/room_03_props.png",
	"res://assets/maps/stitched_demo/props/room_04_props.png",
	"res://assets/maps/stitched_demo/props/room_05_props.png",
	"res://assets/maps/stitched_demo/props/room_06_props.png",
	"res://assets/maps/stitched_demo/props/room_07_props.png",
	"res://assets/maps/stitched_demo/props/room_08_props.png",
	"res://assets/maps/stitched_demo/props/room_09_props.png",
	"res://assets/maps/stitched_demo/props/room_10_props.png",
	"res://assets/maps/stitched_demo/props/room_11_props.png",
	"res://assets/maps/stitched_demo/props/room_12_props.png",
	"res://assets/maps/stitched_demo/props/room_13_props.png"
]

const ENEMY_PREVIEWS := [
	{
		"name": "Swordsman",
		"texture": "res://actors/enemy/textures/swordsman.png",
		"room": 1,
		"offset_ratio": Vector2(0.46, 0.70)
	},
	{
		"name": "Shield",
		"texture": "res://actors/enemy/textures/shield.png",
		"room": 2,
		"offset_ratio": Vector2(0.34, 0.68)
	},
	{
		"name": "Hunter",
		"texture": "res://actors/enemy/textures/hunter.png",
		"room": 2,
		"offset_ratio": Vector2(0.62, 0.66)
	},
	{
		"name": "Archer",
		"texture": "res://actors/enemy/textures/archer.png",
		"room": 3,
		"offset_ratio": Vector2(0.50, 0.70)
	},
	{
		"name": "Arcanist",
		"texture": "res://actors/enemy/textures/arcanist.png",
		"room": 4,
		"offset_ratio": Vector2(0.42, 0.66)
	},
	{
		"name": "Apprentice Mage",
		"texture": "res://actors/enemy/textures/apprentice_mage.png",
		"room": 4,
		"offset_ratio": Vector2(0.64, 0.66)
	}
]

const ROOM_GAP := 0.0
const PLAYER_SPEED := 520.0
const PLAYER_RADIUS := 22.0
const CAMERA_ZOOM := Vector2(1.7, 1.7)
const ROOM_EXIT_MARGIN := 26.0
const ENEMY_PREVIEW_SCALE := Vector2(0.82, 0.82)
const COLLISION_DEBUG_VISIBLE := false
const PROP_COLLISION_DEBUG_VISIBLE := true
const PROP_ALPHA_COLLISION_PADDING := Vector2(8.0, 6.0)
const PROP_ALPHA_THRESHOLD := 0.08
const GENERATED_PROP_MANIFEST_PATH := "res://assets/maps/stitched_demo/generated_props/manifest.json"
const RANDOM_PROP_MIN_PER_ROOM := 2
const RANDOM_PROP_MAX_PER_ROOM := 4
const RANDOM_PROP_PLACEMENT_ATTEMPTS := 56
const RANDOM_PROP_WORLD_SCALE := 0.70
const GENERATED_PROP_SCALE_MULTIPLIERS := {
	"0:Room01Prop01": 0.50,
	"0:Room01Prop03": 0.50,
	"0:Room01Prop07": 0.50,
	"1:Room02Prop13": 0.50,
	"1:Room02Prop15": 0.50,
	"3:Room04Prop01": 1.20,
	"3:Room04Prop02": 1.20
}
const GENERATED_PROP_WALKABLE := {
	"3:Room04Prop35": true,
	"3:Room04Prop36": true,
	"3:Room04Prop37": true
}
const GENERATED_PROP_FOOTPRINTS := {
	"3:Room04Prop01": Rect2(0.08, 0.70, 0.84, 0.24),
	"3:Room04Prop02": Rect2(0.08, 0.70, 0.84, 0.24)
}
const RANDOM_PROP_MIN_WIDTH_RATIO := 0.045
const RANDOM_PROP_MIN_HEIGHT_RATIO := 0.050
const RANDOM_PROP_MIN_AREA_RATIO := 0.0040
const RANDOM_PROP_MAX_WIDTH_RATIO := 0.205
const RANDOM_PROP_MAX_HEIGHT_RATIO := 0.220
const RANDOM_PROP_MAX_AREA_RATIO := 0.030
const RANDOM_PROP_MAX_ASPECT_RATIO := 2.65
const RANDOM_PROP_MAIN_LANE_HEIGHT_RATIO := 0.38
const RANDOM_PROP_DOOR_LANE_WIDTH_RATIO := 0.22
const RANDOM_PROP_SAFE_RADIUS := 92.0

const WALKABLE_AREAS := [
	Rect2(0.035, 0.08, 0.93, 0.82),
	Rect2(0.06, 0.16, 0.88, 0.60),
	Rect2(0.06, 0.15, 0.88, 0.61),
	Rect2(0.06, 0.16, 0.84, 0.60),
	Rect2(0.06, 0.16, 0.88, 0.68),
	Rect2(0.06, 0.16, 0.88, 0.68),
	Rect2(0.06, 0.16, 0.88, 0.68),
	Rect2(0.06, 0.16, 0.86, 0.68),
	Rect2(0.06, 0.16, 0.86, 0.68),
	Rect2(0.06, 0.17, 0.86, 0.66),
	Rect2(0.06, 0.17, 0.86, 0.66),
	Rect2(0.06, 0.17, 0.86, 0.66),
	Rect2(0.05, 0.19, 0.70, 0.64)
]

const ROOM_WALL_COLLISIONS := [
	[
		Rect2(0.00, 0.00, 1.00, 0.08),
		Rect2(0.00, 0.90, 1.00, 0.10),
		Rect2(0.00, 0.00, 0.035, 0.42),
		Rect2(0.00, 0.58, 0.035, 0.42),
		Rect2(0.965, 0.00, 0.035, 0.42),
		Rect2(0.965, 0.58, 0.035, 0.42)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.16),
		Rect2(0.00, 0.76, 1.00, 0.24),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.94, 0.00, 0.06, 0.42),
		Rect2(0.94, 0.58, 0.06, 0.42)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.16),
		Rect2(0.00, 0.76, 1.00, 0.24),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.94, 0.00, 0.06, 0.42),
		Rect2(0.94, 0.58, 0.06, 0.42)
	],
	[
		Rect2(0.00, 0.00, 0.08, 0.42),
		Rect2(0.00, 0.58, 0.08, 0.42),
		Rect2(0.08, 0.00, 0.76, 0.16),
		Rect2(0.08, 0.76, 0.76, 0.24),
		Rect2(0.88, 0.00, 0.06, 0.32),
		Rect2(0.88, 0.68, 0.06, 0.32)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.15),
		Rect2(0.00, 0.84, 1.00, 0.16),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.945, 0.00, 0.055, 0.42),
		Rect2(0.945, 0.58, 0.055, 0.42),
		Rect2(0.15, 0.25, 0.10, 0.08),
		Rect2(0.29, 0.25, 0.14, 0.08),
		Rect2(0.60, 0.25, 0.14, 0.08),
		Rect2(0.76, 0.25, 0.10, 0.08),
		Rect2(0.46, 0.45, 0.12, 0.13),
		Rect2(0.15, 0.66, 0.10, 0.08),
		Rect2(0.29, 0.66, 0.14, 0.08),
		Rect2(0.60, 0.66, 0.14, 0.08),
		Rect2(0.76, 0.66, 0.10, 0.08)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.15),
		Rect2(0.00, 0.84, 1.00, 0.16),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.945, 0.00, 0.055, 0.42),
		Rect2(0.945, 0.58, 0.055, 0.42),
		Rect2(0.18, 0.25, 0.11, 0.09),
		Rect2(0.43, 0.25, 0.11, 0.09),
		Rect2(0.68, 0.25, 0.11, 0.09),
		Rect2(0.21, 0.62, 0.14, 0.11),
		Rect2(0.50, 0.62, 0.16, 0.11),
		Rect2(0.77, 0.62, 0.11, 0.10)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.15),
		Rect2(0.00, 0.84, 1.00, 0.16),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.945, 0.00, 0.055, 0.42),
		Rect2(0.945, 0.58, 0.055, 0.42),
		Rect2(0.12, 0.25, 0.24, 0.10),
		Rect2(0.42, 0.23, 0.12, 0.12),
		Rect2(0.64, 0.23, 0.12, 0.12),
		Rect2(0.70, 0.56, 0.18, 0.16)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.16),
		Rect2(0.00, 0.84, 1.00, 0.16),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.94, 0.00, 0.06, 0.42),
		Rect2(0.94, 0.58, 0.06, 0.42),
		Rect2(0.74, 0.36, 0.10, 0.18)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.15),
		Rect2(0.00, 0.84, 1.00, 0.16),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.945, 0.00, 0.055, 0.42),
		Rect2(0.945, 0.58, 0.055, 0.42),
		Rect2(0.18, 0.26, 0.07, 0.10),
		Rect2(0.40, 0.26, 0.07, 0.10),
		Rect2(0.63, 0.26, 0.07, 0.10),
		Rect2(0.75, 0.57, 0.12, 0.10)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.16),
		Rect2(0.00, 0.84, 1.00, 0.16),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.945, 0.00, 0.055, 0.42),
		Rect2(0.945, 0.58, 0.055, 0.42),
		Rect2(0.12, 0.22, 0.08, 0.17),
		Rect2(0.72, 0.22, 0.08, 0.17),
		Rect2(0.08, 0.46, 0.16, 0.09),
		Rect2(0.74, 0.47, 0.12, 0.08)
	],
	[
		Rect2(0.00, 0.00, 1.00, 0.16),
		Rect2(0.00, 0.84, 1.00, 0.16),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.945, 0.00, 0.055, 0.42),
		Rect2(0.945, 0.58, 0.055, 0.42),
		Rect2(0.12, 0.22, 0.08, 0.17),
		Rect2(0.34, 0.22, 0.08, 0.17),
		Rect2(0.57, 0.22, 0.08, 0.17),
		Rect2(0.78, 0.22, 0.08, 0.17),
		Rect2(0.12, 0.65, 0.08, 0.14),
		Rect2(0.34, 0.65, 0.08, 0.14),
		Rect2(0.57, 0.65, 0.08, 0.14),
		Rect2(0.78, 0.65, 0.08, 0.14)
	],
	[
		Rect2(0.00, 0.00, 0.86, 0.17),
		Rect2(0.00, 0.86, 0.86, 0.14),
		Rect2(0.00, 0.00, 0.055, 0.42),
		Rect2(0.00, 0.58, 0.055, 0.42),
		Rect2(0.90, 0.00, 0.10, 0.35),
		Rect2(0.90, 0.65, 0.10, 0.35),
		Rect2(0.79, 0.33, 0.10, 0.12),
		Rect2(0.79, 0.57, 0.10, 0.12)
	],
	[
		Rect2(0.00, 0.00, 0.77, 0.18),
		Rect2(0.00, 0.85, 0.77, 0.15),
		Rect2(0.00, 0.00, 0.045, 0.43),
		Rect2(0.00, 0.58, 0.045, 0.42),
		Rect2(0.78, 0.04, 0.22, 0.34),
		Rect2(0.78, 0.40, 0.22, 0.21),
		Rect2(0.78, 0.64, 0.22, 0.30),
		Rect2(0.71, 0.32, 0.055, 0.075),
		Rect2(0.71, 0.62, 0.055, 0.075)
	]
]

const ROOM_CIRCLE_COLLISIONS := {
	3: [
		{"center": Vector2(0.455, 0.49), "radius": 0.105}
	]
}

const PROP_CANDIDATES := []

const LEGACY_PROP_CANDIDATES := [
	{"room": 0, "name": "WoodCrateLeft", "source": Rect2(0.07, 0.07, 0.17, 0.18), "position": Vector2(0.16, 0.61), "collision": Vector2(0.10, 0.07)},
	{"room": 0, "name": "WoodBench", "source": Rect2(0.35, 0.35, 0.23, 0.11), "position": Vector2(0.45, 0.63), "collision": Vector2(0.19, 0.06)},
	{"room": 0, "name": "FireBrazier", "source": Rect2(0.48, 0.50, 0.10, 0.16), "position": Vector2(0.52, 0.70), "collision": Vector2(0.07, 0.06)},
	{"room": 0, "name": "StoneRubble", "source": Rect2(0.34, 0.75, 0.16, 0.12), "position": Vector2(0.40, 0.79), "collision": Vector2(0.13, 0.06)},
	{"room": 0, "name": "RightBarricade", "source": Rect2(0.75, 0.33, 0.15, 0.18), "position": Vector2(0.79, 0.62), "collision": Vector2(0.11, 0.08)},
	{"room": 1, "name": "SpikeFence", "source": Rect2(0.07, 0.34, 0.21, 0.13), "position": Vector2(0.18, 0.61), "collision": Vector2(0.18, 0.07)},
	{"room": 1, "name": "StreetBench", "source": Rect2(0.36, 0.36, 0.22, 0.10), "position": Vector2(0.45, 0.63), "collision": Vector2(0.19, 0.06)},
	{"room": 1, "name": "WoodBarricade", "source": Rect2(0.62, 0.33, 0.18, 0.14), "position": Vector2(0.66, 0.62), "collision": Vector2(0.14, 0.08)},
	{"room": 1, "name": "CampfirePile", "source": Rect2(0.78, 0.32, 0.16, 0.16), "position": Vector2(0.80, 0.62), "collision": Vector2(0.11, 0.07)},
	{"room": 1, "name": "BottomRubble", "source": Rect2(0.16, 0.73, 0.18, 0.12), "position": Vector2(0.21, 0.76), "collision": Vector2(0.13, 0.06)},
	{"room": 2, "name": "RoundWellLeft", "source": Rect2(0.05, 0.17, 0.14, 0.13), "position": Vector2(0.15, 0.56), "collision": Vector2(0.11, 0.07)},
	{"room": 2, "name": "RoundWellCenter", "source": Rect2(0.26, 0.14, 0.18, 0.14), "position": Vector2(0.38, 0.55), "collision": Vector2(0.14, 0.08)},
	{"room": 2, "name": "StoneBlock", "source": Rect2(0.50, 0.17, 0.14, 0.15), "position": Vector2(0.55, 0.56), "collision": Vector2(0.10, 0.08)},
	{"room": 2, "name": "BrokenWood", "source": Rect2(0.31, 0.65, 0.21, 0.11), "position": Vector2(0.38, 0.70), "collision": Vector2(0.16, 0.07)},
	{"room": 2, "name": "RockPile", "source": Rect2(0.63, 0.52, 0.14, 0.09), "position": Vector2(0.67, 0.65), "collision": Vector2(0.11, 0.06)},
	{"room": 3, "name": "LeftFountain", "source": Rect2(0.07, 0.44, 0.19, 0.20), "position": Vector2(0.20, 0.63), "collision": Vector2(0.16, 0.09)},
	{"room": 3, "name": "CenterFountain", "source": Rect2(0.30, 0.42, 0.20, 0.20), "position": Vector2(0.40, 0.62), "collision": Vector2(0.16, 0.10)},
	{"room": 3, "name": "BarrelCluster", "source": Rect2(0.10, 0.28, 0.20, 0.08), "position": Vector2(0.20, 0.53), "collision": Vector2(0.16, 0.06)},
	{"room": 3, "name": "StatueLine", "source": Rect2(0.59, 0.44, 0.19, 0.12), "position": Vector2(0.65, 0.61), "collision": Vector2(0.15, 0.07)},
	{"room": 3, "name": "RightPot", "source": Rect2(0.82, 0.44, 0.08, 0.11), "position": Vector2(0.84, 0.62), "collision": Vector2(0.06, 0.06)},
	{"room": 4, "name": "StonePillarLeft", "source": Rect2(0.17, 0.43, 0.08, 0.16), "position": Vector2(0.21, 0.61), "collision": Vector2(0.06, 0.08)},
	{"room": 4, "name": "StonePillarCenter", "source": Rect2(0.40, 0.42, 0.08, 0.17), "position": Vector2(0.43, 0.61), "collision": Vector2(0.06, 0.08)},
	{"room": 4, "name": "Altar", "source": Rect2(0.48, 0.56, 0.16, 0.13), "position": Vector2(0.53, 0.70), "collision": Vector2(0.13, 0.07)},
	{"room": 4, "name": "StoneBasin", "source": Rect2(0.73, 0.60, 0.13, 0.10), "position": Vector2(0.78, 0.70), "collision": Vector2(0.10, 0.06)},
	{"room": 5, "name": "PalaceColumnLeft", "source": Rect2(0.11, 0.07, 0.09, 0.30), "position": Vector2(0.17, 0.56), "collision": Vector2(0.07, 0.09)},
	{"room": 5, "name": "PalaceColumnRight", "source": Rect2(0.70, 0.07, 0.09, 0.30), "position": Vector2(0.76, 0.56), "collision": Vector2(0.07, 0.09)},
	{"room": 5, "name": "FireLine", "source": Rect2(0.07, 0.43, 0.23, 0.13), "position": Vector2(0.19, 0.62), "collision": Vector2(0.17, 0.07)},
	{"room": 5, "name": "StoneBowl", "source": Rect2(0.74, 0.46, 0.12, 0.10), "position": Vector2(0.78, 0.63), "collision": Vector2(0.09, 0.06)},
	{"room": 6, "name": "TopTableLeft", "source": Rect2(0.11, 0.03, 0.20, 0.14), "position": Vector2(0.20, 0.55), "collision": Vector2(0.16, 0.07)},
	{"room": 6, "name": "TopTableCenter", "source": Rect2(0.38, 0.03, 0.17, 0.14), "position": Vector2(0.45, 0.55), "collision": Vector2(0.14, 0.07)},
	{"room": 6, "name": "CurtainBarrier", "source": Rect2(0.48, 0.51, 0.28, 0.12), "position": Vector2(0.60, 0.70), "collision": Vector2(0.22, 0.06)},
	{"room": 6, "name": "LowerFires", "source": Rect2(0.18, 0.76, 0.19, 0.12), "position": Vector2(0.27, 0.78), "collision": Vector2(0.14, 0.06)},
	{"room": 7, "name": "ThroneLeftColumn", "source": Rect2(0.18, 0.57, 0.10, 0.16), "position": Vector2(0.24, 0.65), "collision": Vector2(0.07, 0.08)},
	{"room": 7, "name": "ThroneCenterCrate", "source": Rect2(0.45, 0.61, 0.10, 0.10), "position": Vector2(0.51, 0.68), "collision": Vector2(0.08, 0.06)},
	{"room": 7, "name": "ThroneRightColumn", "source": Rect2(0.69, 0.57, 0.10, 0.16), "position": Vector2(0.74, 0.65), "collision": Vector2(0.07, 0.08)},
	{"room": 7, "name": "BannerStand", "source": Rect2(0.83, 0.18, 0.12, 0.32), "position": Vector2(0.85, 0.61), "collision": Vector2(0.08, 0.09)}
]

var player: CharacterBody2D
var camera: Camera2D
var hud_label: Label
var map_bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
var room_rects: Array[Rect2] = []
var walkable_rects: Array[Rect2] = []
var room_cleared: Array[bool] = []
var active_room_index := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_build_map()
	_build_player()
	_build_camera()
	_build_help_label()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if Input.is_key_pressed(KEY_C):
		_mark_current_room_cleared()
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		input = _fallback_keyboard_vector()
	player.velocity = input * PLAYER_SPEED
	player.move_and_slide()
	_apply_room_bounds()
	_update_camera_position()

func _build_map() -> void:
	var map_root := Node2D.new()
	map_root.name = "StitchedMap"
	add_child(map_root)

	room_rects.clear()
	walkable_rects.clear()
	room_cleared.clear()
	var x_cursor := 0.0
	var max_height := 0.0
	for index in range(ROOM_PATHS.size()):
		var texture := load(ROOM_PATHS[index]) as Texture2D
		if texture == null:
			push_warning("Map room texture missing: %s" % ROOM_PATHS[index])
			continue

		var room := Sprite2D.new()
		room.name = "Room%02d" % [index + 1]
		room.texture = texture
		room.centered = false
		room.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		room.position = Vector2(x_cursor, 0.0)
		map_root.add_child(room)

		var size := Vector2(float(texture.get_width()), float(texture.get_height()))
		var room_rect := Rect2(room.position, size)
		room_rects.append(room_rect)
		walkable_rects.append(_get_walkable_rect(index, room_rect))
		room_cleared.append(false)
		_add_room_label(map_root, ROOM_TITLES[index], room.position + Vector2(24.0, 24.0))
		_add_room_portals(map_root, index, room_rect, walkable_rects[index])

		x_cursor += size.x + ROOM_GAP
		max_height = maxf(max_height, size.y)

	map_bounds = Rect2(Vector2.ZERO, Vector2(maxf(x_cursor - ROOM_GAP, 0.0), max_height))
	_add_bounds_outline(map_root)
	_add_collision_boxes(map_root)
	_add_random_cover_props(map_root)
	_add_enemy_previews(map_root)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "PlaceholderPlayer"
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = _get_player_spawn()
	add_child(player)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	collision.shape = circle
	player.add_child(collision)

	var body := Polygon2D.new()
	body.name = "Body"
	body.color = Color(0.18, 0.82, 0.96, 0.96)
	body.polygon = PackedVector2Array([
		Vector2(0.0, -PLAYER_RADIUS),
		Vector2(PLAYER_RADIUS * 0.86, PLAYER_RADIUS * 0.55),
		Vector2(0.0, PLAYER_RADIUS * 0.25),
		Vector2(-PLAYER_RADIUS * 0.86, PLAYER_RADIUS * 0.55)
	])
	player.add_child(body)

	var ring := Line2D.new()
	ring.name = "GroundRing"
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(1.0, 1.0, 1.0, 0.82)
	for point_index in range(24):
		var angle := TAU * float(point_index) / 24.0
		ring.add_point(Vector2.RIGHT.rotated(angle) * (PLAYER_RADIUS + 6.0))
	player.add_child(ring)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.zoom = CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	add_child(camera)
	_update_camera_position()

func _build_help_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	hud_label = Label.new()
	hud_label.position = Vector2(24.0, 18.0)
	hud_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	hud_label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(hud_label)
	_update_hud()

func _get_walkable_rect(index: int, room_rect: Rect2) -> Rect2:
	var ratio: Rect2 = WALKABLE_AREAS[min(index, WALKABLE_AREAS.size() - 1)]
	return Rect2(
		room_rect.position + Vector2(room_rect.size.x * ratio.position.x, room_rect.size.y * ratio.position.y),
		Vector2(room_rect.size.x * ratio.size.x, room_rect.size.y * ratio.size.y)
	)

func _get_player_spawn() -> Vector2:
	if walkable_rects.is_empty():
		return Vector2(180.0, 560.0)
	var first_walkable := walkable_rects[0]
	return first_walkable.position + Vector2(first_walkable.size.x * 0.12, first_walkable.size.y * 0.5)

func _apply_room_bounds() -> void:
	if walkable_rects.is_empty():
		return
	var walk_rect := walkable_rects[active_room_index]
	var min_x := walk_rect.position.x + PLAYER_RADIUS
	var max_x := walk_rect.end.x - PLAYER_RADIUS
	var min_y := walk_rect.position.y + PLAYER_RADIUS
	var max_y := walk_rect.end.y - PLAYER_RADIUS
	if player.position.x >= max_x - ROOM_EXIT_MARGIN and _is_current_room_cleared() and active_room_index < walkable_rects.size() - 1:
		_transition_to_room(active_room_index + 1)
		return
	player.position.x = clampf(player.position.x, min_x, max_x)
	player.position.y = clampf(player.position.y, min_y, max_y)

func _transition_to_room(next_room_index: int) -> void:
	active_room_index = clampi(next_room_index, 0, walkable_rects.size() - 1)
	var walk_rect := walkable_rects[active_room_index]
	player.position = walk_rect.position + Vector2(PLAYER_RADIUS + 36.0, walk_rect.size.y * 0.5)
	player.velocity = Vector2.ZERO
	_update_camera_position(true)
	_update_hud()

func _mark_current_room_cleared() -> void:
	if active_room_index < 0 or active_room_index >= room_cleared.size() or room_cleared[active_room_index]:
		return
	room_cleared[active_room_index] = true
	_update_hud()

func _is_current_room_cleared() -> bool:
	return active_room_index >= 0 and active_room_index < room_cleared.size() and room_cleared[active_room_index]

func _update_camera_position(force: bool = false) -> void:
	if camera == null or player == null or room_rects.is_empty():
		return
	var target := _get_clamped_camera_position(active_room_index, player.position)
	if force:
		camera.position_smoothing_enabled = false
		camera.global_position = target
		camera.position_smoothing_enabled = true
	else:
		camera.global_position = target

func _get_clamped_camera_position(room_index: int, target: Vector2) -> Vector2:
	var room_rect := room_rects[room_index]
	var viewport_size := Vector2(get_viewport_rect().size)
	var visible_size := Vector2(viewport_size.x / CAMERA_ZOOM.x, viewport_size.y / CAMERA_ZOOM.y)
	var half_size := visible_size * 0.5
	var min_x := room_rect.position.x + half_size.x
	var max_x := room_rect.end.x - half_size.x
	var min_y := room_rect.position.y + half_size.y
	var max_y := room_rect.end.y - half_size.y
	var clamped := target
	clamped.x = room_rect.get_center().x if min_x > max_x else clampf(target.x, min_x, max_x)
	clamped.y = room_rect.get_center().y if min_y > max_y else clampf(target.y, min_y, max_y)
	return clamped

func _update_hud() -> void:
	if hud_label == null:
		return
	var status := "CLEARED - walk to OUT" if _is_current_room_cleared() else "LOCKED - press C to simulate all enemies defeated"
	hud_label.text = "Room %d/%d | %s | WASD/Arrow move | Camera locked to current room" % [
		active_room_index + 1,
		room_rects.size(),
		status
	]

func _add_room_label(parent: Node, text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.z_index = 10
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 30)
	parent.add_child(label)

func _add_room_portals(parent: Node, index: int, room_rect: Rect2, walk_rect: Rect2) -> void:
	var portal_height: float = min(walk_rect.size.y * 0.72, 220.0)
	var portal_center_y: float = walk_rect.get_center().y
	var left_text: String = "START" if index == 0 else "IN"
	var right_text: String = "EXIT" if index == ROOM_PATHS.size() - 1 else "OUT"
	_add_portal_marker(parent, "%s%02d" % [left_text, index + 1], Vector2(room_rect.position.x, portal_center_y), portal_height, left_text, true)
	_add_portal_marker(parent, "%s%02d" % [right_text, index + 1], Vector2(room_rect.end.x, portal_center_y), portal_height, right_text, false)

func _add_portal_marker(parent: Node, marker_name: String, position: Vector2, height: float, text: String, label_on_left: bool) -> void:
	var marker := Node2D.new()
	marker.name = "%sPortal" % marker_name
	marker.position = position
	marker.z_index = 25
	parent.add_child(marker)

	var line := Line2D.new()
	line.name = "DoorLine"
	line.width = 7.0
	line.default_color = Color(0.42, 1.0, 0.78, 0.88)
	line.add_point(Vector2(0.0, -height * 0.5))
	line.add_point(Vector2(0.0, height * 0.5))
	marker.add_child(line)

	var label := Label.new()
	label.name = "DoorLabel"
	label.text = text
	label.size = Vector2(92.0, 28.0)
	label.position = Vector2(-106.0, -height * 0.5 - 34.0) if label_on_left else Vector2(14.0, -height * 0.5 - 34.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.66, 1.0, 0.84, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 18)
	marker.add_child(label)

func _add_bounds_outline(parent: Node) -> void:
	var outline := Line2D.new()
	outline.name = "MapBounds"
	outline.width = 5.0
	outline.default_color = Color(0.72, 0.88, 1.0, 0.42)
	outline.closed = true
	outline.add_point(map_bounds.position)
	outline.add_point(Vector2(map_bounds.end.x, map_bounds.position.y))
	outline.add_point(map_bounds.end)
	outline.add_point(Vector2(map_bounds.position.x, map_bounds.end.y))
	outline.z_index = 30
	parent.add_child(outline)

func _add_collision_boxes(parent: Node) -> void:
	var collision_root := Node2D.new()
	collision_root.name = "RoomBoundaryCollision"
	collision_root.z_index = 35
	parent.add_child(collision_root)

	for index in range(room_rects.size()):
		var room_rect := room_rects[index]
		var wall_rects := get_room_wall_rects(index, room_rect)
		for wall_index in range(wall_rects.size()):
			_add_blocker(collision_root, "Room%02dWall%02d" % [index + 1, wall_index + 1], wall_rects[wall_index])
		var circle_collisions := get_room_circle_collisions(index, room_rect)
		for circle_index in range(circle_collisions.size()):
			_add_circle_blocker(collision_root, "Room%02dCircle%02d" % [index + 1, circle_index + 1], circle_collisions[circle_index])

func _add_blocker(parent: Node, blocker_name: String, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var body := StaticBody2D.new()
	body.name = blocker_name
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = rect.get_center()
	parent.add_child(body)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)

	if COLLISION_DEBUG_VISIBLE:
		var visual := Polygon2D.new()
		visual.name = "DebugFill"
		visual.color = Color(1.0, 0.22, 0.14, 0.16)
		visual.polygon = PackedVector2Array([
			Vector2(-rect.size.x * 0.5, -rect.size.y * 0.5),
			Vector2(rect.size.x * 0.5, -rect.size.y * 0.5),
			Vector2(rect.size.x * 0.5, rect.size.y * 0.5),
			Vector2(-rect.size.x * 0.5, rect.size.y * 0.5)
		])
		body.add_child(visual)

func _add_circle_blocker(parent: Node, blocker_name: String, data: Dictionary) -> void:
	var radius := float(data.get("radius", 0.0))
	if radius <= 0.0:
		return
	var body := StaticBody2D.new()
	body.name = blocker_name
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = data.get("center", Vector2.ZERO) as Vector2
	parent.add_child(body)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)

func _add_random_cover_props(parent: Node) -> void:
	var prop_root := Node2D.new()
	prop_root.name = "RandomCoverProps"
	prop_root.z_index = 38
	parent.add_child(prop_root)

	var manifest := load_generated_prop_manifest()
	for room_index in range(room_rects.size()):
		var candidates := get_generated_prop_candidates(manifest, room_index)
		if candidates.is_empty():
			continue
		candidates.shuffle()
		var count: int = min(rng.randi_range(RANDOM_PROP_MIN_PER_ROOM, RANDOM_PROP_MAX_PER_ROOM), candidates.size())
		var placed_rects: Array[Rect2] = []
		var placed := 0
		for candidate in candidates:
			if placed >= count:
				break
			if _try_add_random_cover_prop(prop_root, room_index, candidate, placed_rects):
				placed += 1

func _get_prop_candidates_for_room(room_index: int) -> Array:
	var result := []
	for candidate in PROP_CANDIDATES:
		if int(candidate["room"]) == room_index:
			result.append(candidate)
	return result

func _try_add_random_cover_prop(parent: Node, room_index: int, candidate: Dictionary, placed_rects: Array[Rect2]) -> bool:
	if room_index < 0 or room_index >= room_rects.size() or room_index >= walkable_rects.size():
		return false
	var texture := load(String(candidate.get("path", ""))) as Texture2D
	if texture == null:
		return false
	var room_rect := room_rects[room_index]
	var source_size := candidate.get("source_size", [texture.get_width(), texture.get_height()]) as Array
	var source_width := maxf(1.0, float(source_size[0]))
	var source_height := maxf(1.0, float(source_size[1]))
	var texture_to_room_scale := Vector2(room_rect.size.x / source_width, room_rect.size.y / source_height)
	texture_to_room_scale *= RANDOM_PROP_WORLD_SCALE * generated_prop_scale_multiplier(candidate)
	var prop_size := Vector2(float(texture.get_width()) * texture_to_room_scale.x, float(texture.get_height()) * texture_to_room_scale.y)
	if not is_generated_prop_size_usable(prop_size, room_rect.size):
		return false

	for attempt in range(RANDOM_PROP_PLACEMENT_ATTEMPTS):
		var position := random_cover_position_for_room(rng, walkable_rects[room_index], prop_size)
		var prop_rect := Rect2(position - prop_size * 0.5, prop_size)
		if not is_cover_position_valid(prop_rect, walkable_rects[room_index], placed_rects, player_spawn_for_room_index(room_index), encounter_position_for_room_index(room_index)):
			continue
		placed_rects.append(prop_rect.grow(20.0))
		_add_generated_cover_prop(parent, candidate, texture, texture_to_room_scale, position)
		return true
	return false

func player_spawn_for_room_index(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= walkable_rects.size():
		return Vector2.ZERO
	var walk_rect := walkable_rects[room_index]
	return walk_rect.position + Vector2(walk_rect.size.x * 0.07, walk_rect.size.y * 0.54)

func encounter_position_for_room_index(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= walkable_rects.size():
		return Vector2.ZERO
	var walk_rect := walkable_rects[room_index]
	return walk_rect.position + Vector2(walk_rect.size.x * 0.62, walk_rect.size.y * 0.60)

func _add_generated_cover_prop(parent: Node, candidate: Dictionary, texture: Texture2D, texture_to_room_scale: Vector2, world_position: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "%sCover" % String(candidate.get("name", "GeneratedProp"))
	body.collision_layer = 1
	body.collision_mask = 2
	var walkable_prop := generated_prop_is_walkable(candidate)
	if walkable_prop:
		body.collision_layer = 0
		body.collision_mask = 0
	else:
		body.add_to_group("projectile_blocker")
	body.position = world_position
	body.set_meta("room_index", int(candidate.get("room", -1)))
	body.set_meta("prop_key", generated_prop_key(candidate))
	body.set_meta("prop_size", Vector2(float(texture.get_width()) * texture_to_room_scale.x, float(texture.get_height()) * texture_to_room_scale.y))
	body.set_meta("walkable_prop", walkable_prop)
	parent.add_child(body)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.scale = texture_to_room_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 1
	body.add_child(sprite)

	var polygons := build_generated_prop_collision_polygons(candidate, texture, texture_to_room_scale)
	for index in range(polygons.size()):
		var collision := CollisionPolygon2D.new()
		collision.name = "AlphaCollision%02d" % [index + 1]
		collision.polygon = polygons[index]
		body.add_child(collision)
		if PROP_COLLISION_DEBUG_VISIBLE:
			_add_collision_polygon_debug(body, polygons[index])

func _add_cover_prop(parent: Node, candidate: Dictionary) -> void:
	var room_index := int(candidate["room"])
	if room_index < 0 or room_index >= room_rects.size() or room_index >= ROOM_PROP_LAYER_PATHS.size():
		return

	var texture := load(String(ROOM_PROP_LAYER_PATHS[room_index])) as Texture2D
	if texture == null:
		push_warning("Prop layer texture missing: %s" % ROOM_PROP_LAYER_PATHS[room_index])
		return

	var room_rect := room_rects[room_index]
	var source_ratio: Rect2 = candidate["source"]
	var source_rect := Rect2(
		Vector2(float(texture.get_width()) * source_ratio.position.x, float(texture.get_height()) * source_ratio.position.y),
		Vector2(float(texture.get_width()) * source_ratio.size.x, float(texture.get_height()) * source_ratio.size.y)
	)
	var texture_to_room_scale := Vector2(room_rect.size.x / float(texture.get_width()), room_rect.size.y / float(texture.get_height()))
	var prop_position_ratio: Vector2 = candidate["position"]
	var world_position := room_rect.position + Vector2(room_rect.size.x * prop_position_ratio.x, room_rect.size.y * prop_position_ratio.y)
	var collision_rect := calculate_prop_collision_rect(texture, source_rect, texture_to_room_scale)

	var body := StaticBody2D.new()
	body.name = "%sCover" % String(candidate["name"])
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = world_position
	parent.add_child(body)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = source_rect
	sprite.scale = texture_to_room_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = 1
	body.add_child(sprite)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.position = collision_rect.get_center()
	var rectangle := RectangleShape2D.new()
	rectangle.size = collision_rect.size
	shape.shape = rectangle
	body.add_child(shape)

	if PROP_COLLISION_DEBUG_VISIBLE:
		_add_collision_debug_outline(body, collision_rect)

func _add_collision_polygon_debug(parent: Node, polygon: PackedVector2Array) -> void:
	var outline := Line2D.new()
	outline.name = "AlphaCollisionDebug"
	outline.width = 2.0
	outline.closed = true
	outline.default_color = Color(0.25, 0.9, 1.0, 0.82)
	outline.points = polygon
	parent.add_child(outline)

func _add_collision_debug_outline(parent: Node, rect: Rect2) -> void:
	var outline := Line2D.new()
	outline.name = "CollisionDebugOutline"
	outline.width = 3.0
	outline.closed = true
	outline.default_color = Color(0.25, 0.9, 1.0, 0.82)
	outline.add_point(rect.position)
	outline.add_point(Vector2(rect.end.x, rect.position.y))
	outline.add_point(rect.end)
	outline.add_point(Vector2(rect.position.x, rect.end.y))
	parent.add_child(outline)

static func get_room_wall_rects(room_index: int, room_rect: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if room_index < 0 or room_index >= ROOM_WALL_COLLISIONS.size():
		return result
	for ratio in ROOM_WALL_COLLISIONS[room_index]:
		var rect_ratio: Rect2 = ratio
		result.append(Rect2(
			room_rect.position + Vector2(room_rect.size.x * rect_ratio.position.x, room_rect.size.y * rect_ratio.position.y),
			Vector2(room_rect.size.x * rect_ratio.size.x, room_rect.size.y * rect_ratio.size.y)
		))
	return result

static func get_room_circle_collisions(room_index: int, room_rect: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var definitions := ROOM_CIRCLE_COLLISIONS.get(room_index, []) as Array
	for raw_definition in definitions:
		var definition := raw_definition as Dictionary
		var center_ratio := definition.get("center", Vector2.ZERO) as Vector2
		result.append({
			"center": room_rect.position + Vector2(room_rect.size.x * center_ratio.x, room_rect.size.y * center_ratio.y),
			"radius": minf(room_rect.size.x, room_rect.size.y) * float(definition.get("radius", 0.0))
		})
	return result

static func generated_prop_key(candidate: Dictionary) -> String:
	return "%d:%s" % [int(candidate.get("room", -1)), String(candidate.get("name", ""))]

static func generated_prop_scale_multiplier(candidate: Dictionary) -> float:
	return float(GENERATED_PROP_SCALE_MULTIPLIERS.get(generated_prop_key(candidate), 1.0))

static func generated_prop_is_walkable(candidate: Dictionary) -> bool:
	return bool(GENERATED_PROP_WALKABLE.get(generated_prop_key(candidate), false))

static func build_generated_prop_collision_polygons(candidate: Dictionary, texture: Texture2D, texture_to_room_scale: Vector2) -> Array[PackedVector2Array]:
	if generated_prop_is_walkable(candidate):
		return []
	var footprint = GENERATED_PROP_FOOTPRINTS.get(generated_prop_key(candidate), null)
	if footprint is Rect2 and texture != null:
		var ratio := footprint as Rect2
		var texture_size := Vector2(float(texture.get_width()), float(texture.get_height()))
		var top_left := (texture_size * ratio.position - texture_size * 0.5) * texture_to_room_scale
		var bottom_right := (texture_size * ratio.end - texture_size * 0.5) * texture_to_room_scale
		return [PackedVector2Array([
			top_left,
			Vector2(bottom_right.x, top_left.y),
			bottom_right,
			Vector2(top_left.x, bottom_right.y)
		])]
	return build_alpha_collision_polygons(texture, texture_to_room_scale)

static func load_generated_prop_manifest() -> Dictionary:
	if not FileAccess.file_exists(GENERATED_PROP_MANIFEST_PATH):
		return {}
	var file := FileAccess.open(GENERATED_PROP_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	return parsed

static func get_generated_prop_candidates(manifest: Dictionary, room_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rooms := manifest.get("rooms", []) as Array
	for raw_room in rooms:
		var room := raw_room as Dictionary
		if int(room.get("room", -1)) != room_index:
			continue
		var source_size := room.get("source_size", [1, 1]) as Array
		var props := room.get("props", []) as Array
		for raw_prop in props:
			var prop := (raw_prop as Dictionary).duplicate(true)
			prop["room"] = room_index
			prop["source_size"] = source_size
			result.append(prop)
		break
	return result

static func random_cover_position_for_room(rng: RandomNumberGenerator, walk_rect: Rect2, prop_size: Vector2) -> Vector2:
	var lane_height := walk_rect.size.y * RANDOM_PROP_MAIN_LANE_HEIGHT_RATIO
	var upper_band := Rect2(
		walk_rect.position + Vector2(prop_size.x * 0.55, prop_size.y * 0.55),
		Vector2(
			maxf(1.0, walk_rect.size.x - prop_size.x * 1.1),
			maxf(1.0, (walk_rect.size.y - lane_height) * 0.5 - prop_size.y * 0.8)
		)
	)
	var lower_y := walk_rect.get_center().y + lane_height * 0.5 + prop_size.y * 0.55
	var lower_band := Rect2(
		Vector2(walk_rect.position.x + prop_size.x * 0.55, lower_y),
		Vector2(
			maxf(1.0, walk_rect.size.x - prop_size.x * 1.1),
			maxf(1.0, walk_rect.end.y - lower_y - prop_size.y * 0.55)
		)
	)
	var band := upper_band if rng.randf() < 0.5 else lower_band
	if band.size.y <= 2.0:
		band = Rect2(
			walk_rect.position + prop_size * 0.55,
			Vector2(maxf(1.0, walk_rect.size.x - prop_size.x * 1.1), maxf(1.0, walk_rect.size.y - prop_size.y * 1.1))
		)
	return Vector2(
		rng.randf_range(band.position.x, band.end.x),
		rng.randf_range(band.position.y, band.end.y)
	)

static func is_cover_position_valid(prop_rect: Rect2, walk_rect: Rect2, placed_rects: Array[Rect2], player_spawn: Vector2, encounter_spawn: Vector2) -> bool:
	if not walk_rect.encloses(prop_rect):
		return false
	var main_lane := Rect2(
		Vector2(walk_rect.position.x, walk_rect.get_center().y - walk_rect.size.y * RANDOM_PROP_MAIN_LANE_HEIGHT_RATIO * 0.5),
		Vector2(walk_rect.size.x, walk_rect.size.y * RANDOM_PROP_MAIN_LANE_HEIGHT_RATIO)
	)
	if prop_rect.intersects(main_lane):
		return false
	var left_door_lane := Rect2(
		walk_rect.position,
		Vector2(walk_rect.size.x * RANDOM_PROP_DOOR_LANE_WIDTH_RATIO, walk_rect.size.y)
	)
	if prop_rect.intersects(left_door_lane):
		return false
	var right_door_lane := Rect2(
		Vector2(walk_rect.end.x - walk_rect.size.x * RANDOM_PROP_DOOR_LANE_WIDTH_RATIO, walk_rect.position.y),
		Vector2(walk_rect.size.x * RANDOM_PROP_DOOR_LANE_WIDTH_RATIO, walk_rect.size.y)
	)
	if prop_rect.intersects(right_door_lane):
		return false
	if prop_rect.grow(RANDOM_PROP_SAFE_RADIUS).has_point(player_spawn):
		return false
	if prop_rect.grow(RANDOM_PROP_SAFE_RADIUS).has_point(encounter_spawn):
		return false
	for rect in placed_rects:
		if prop_rect.intersects(rect):
			return false
	return true

static func is_generated_prop_size_usable(prop_size: Vector2, room_size: Vector2) -> bool:
	if prop_size.x <= 0.0 or prop_size.y <= 0.0 or room_size.x <= 0.0 or room_size.y <= 0.0:
		return false
	var width_ratio := prop_size.x / room_size.x
	var height_ratio := prop_size.y / room_size.y
	var area_ratio := (prop_size.x * prop_size.y) / (room_size.x * room_size.y)
	if width_ratio < RANDOM_PROP_MIN_WIDTH_RATIO or height_ratio < RANDOM_PROP_MIN_HEIGHT_RATIO:
		return false
	if area_ratio < RANDOM_PROP_MIN_AREA_RATIO:
		return false
	if width_ratio > RANDOM_PROP_MAX_WIDTH_RATIO or height_ratio > RANDOM_PROP_MAX_HEIGHT_RATIO:
		return false
	if area_ratio > RANDOM_PROP_MAX_AREA_RATIO:
		return false
	var aspect := maxf(prop_size.x / prop_size.y, prop_size.y / prop_size.x)
	if aspect > RANDOM_PROP_MAX_ASPECT_RATIO:
		return false
	return true

static func build_alpha_collision_polygons(texture: Texture2D, texture_to_room_scale: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if texture == null:
		return result
	var image := texture.get_image()
	if image == null:
		return result
	image.convert(Image.FORMAT_RGBA8)
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, PROP_ALPHA_THRESHOLD)
	var source_rect := Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height()))
	var raw_polygons := bitmap.opaque_to_polygons(source_rect, 2.0)
	var center := Vector2(float(image.get_width()) * 0.5, float(image.get_height()) * 0.5)
	for raw_polygon in raw_polygons:
		var polygon := PackedVector2Array()
		for point in raw_polygon:
			var local := (point - center) * texture_to_room_scale
			polygon.append(local)
		if polygon.size() >= 3:
			result.append(polygon)
	return result

static func calculate_prop_collision_rect(texture: Texture2D, source_rect: Rect2, texture_to_room_scale: Vector2) -> Rect2:
	if texture == null:
		return Rect2(-source_rect.size * texture_to_room_scale * 0.5, source_rect.size * texture_to_room_scale)
	var image := texture.get_image()
	if image == null:
		return Rect2(-source_rect.size * texture_to_room_scale * 0.5, source_rect.size * texture_to_room_scale)
	image.convert(Image.FORMAT_RGBA8)
	var source_rect_i := Rect2i(
		Vector2i(roundi(source_rect.position.x), roundi(source_rect.position.y)),
		Vector2i(maxi(1, roundi(source_rect.size.x)), maxi(1, roundi(source_rect.size.y)))
	)
	var alpha_rect := _find_alpha_bounds(image, source_rect_i)
	if alpha_rect.size.x <= 0 or alpha_rect.size.y <= 0:
		return Rect2(-source_rect.size * texture_to_room_scale * 0.5, source_rect.size * texture_to_room_scale)
	var local_position := Vector2(
		float(alpha_rect.position.x - source_rect_i.position.x) * texture_to_room_scale.x,
		float(alpha_rect.position.y - source_rect_i.position.y) * texture_to_room_scale.y
	) - source_rect.size * texture_to_room_scale * 0.5
	var local_size := Vector2(float(alpha_rect.size.x) * texture_to_room_scale.x, float(alpha_rect.size.y) * texture_to_room_scale.y)
	var padded := Rect2(local_position, local_size)
	padded = padded.grow_side(SIDE_LEFT, PROP_ALPHA_COLLISION_PADDING.x)
	padded = padded.grow_side(SIDE_RIGHT, PROP_ALPHA_COLLISION_PADDING.x)
	padded = padded.grow_side(SIDE_TOP, PROP_ALPHA_COLLISION_PADDING.y)
	padded = padded.grow_side(SIDE_BOTTOM, PROP_ALPHA_COLLISION_PADDING.y)
	return padded

static func _find_alpha_bounds(image: Image, source_rect: Rect2i) -> Rect2i:
	var min_x := source_rect.end.x
	var min_y := source_rect.end.y
	var max_x := source_rect.position.x - 1
	var max_y := source_rect.position.y - 1
	var start_x := clampi(source_rect.position.x, 0, image.get_width() - 1)
	var start_y := clampi(source_rect.position.y, 0, image.get_height() - 1)
	var end_x := clampi(source_rect.end.x, 0, image.get_width())
	var end_y := clampi(source_rect.end.y, 0, image.get_height())
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			if image.get_pixel(x, y).a <= PROP_ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))

func _add_enemy_previews(parent: Node) -> void:
	var enemy_root := Node2D.new()
	enemy_root.name = "EnemyMaterialPreview"
	enemy_root.z_index = 40
	parent.add_child(enemy_root)

	for preview in ENEMY_PREVIEWS:
		var room_index := int(preview["room"])
		if room_index < 0 or room_index >= room_rects.size():
			push_warning("Enemy preview room index out of range: %s" % room_index)
			continue

		var texture := load(String(preview["texture"])) as Texture2D
		if texture == null:
			push_warning("Enemy preview texture missing: %s" % preview["texture"])
			continue

		var room_rect := room_rects[room_index]
		var offset_ratio := preview["offset_ratio"] as Vector2
		var position := room_rect.position + Vector2(room_rect.size.x * offset_ratio.x, room_rect.size.y * offset_ratio.y)
		_add_enemy_preview(enemy_root, String(preview["name"]), texture, position)

func _add_enemy_preview(parent: Node, display_name: String, texture: Texture2D, position: Vector2) -> void:
	var preview := Node2D.new()
	preview.name = "%sPreview" % display_name.replace(" ", "")
	preview.position = position
	parent.add_child(preview)

	var ring := Line2D.new()
	ring.name = "GroundRing"
	ring.closed = true
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.78, 0.34, 0.86)
	for point_index in range(28):
		var angle := TAU * float(point_index) / 28.0
		ring.add_point(Vector2(cos(angle) * 52.0, sin(angle) * 24.0))
	preview.add_child(ring)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.position = Vector2(0.0, -58.0)
	sprite.scale = ENEMY_PREVIEW_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.add_child(sprite)

	var label := Label.new()
	label.name = "NameLabel"
	label.text = display_name
	label.position = Vector2(-72.0, 32.0)
	label.size = Vector2(144.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.74, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 18)
	preview.add_child(label)

func _fallback_keyboard_vector() -> Vector2:
	var vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vector.y += 1.0
	return vector.normalized() if vector != Vector2.ZERO else Vector2.ZERO
