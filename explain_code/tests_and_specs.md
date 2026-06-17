# 测试与行为规格抓手

这些测试不是完整单元测试，但很适合作为重构前后的行为规格。

## 核心流程

- `tests/smoke_run_flow.gd`：最重要。覆盖开局、encounter、饰品选择、事件面板、战斗状态、关间奖励、功能房汇合、胜利结果。
- `tests/smoke_function_room_flow.gd`：覆盖功能房选择、stage reward 后进入教堂/军需库/商店，再汇合到 encounter 7。
- `tests/smoke_lineage_save.gd`：覆盖存档随机访问 patch、死亡继承、资质点、家族封禁、皇帝轮替。
- `tests/smoke_story_endings.gd`：覆盖作弊模式、结局条件、HealthComponent 无限 HP 防护。

## 战斗与成长

- `tests/smoke_player_control.gd`：三职业控制效果接口，沉默阻止技能、减速降低速度、定身生效、清除控制恢复。
- `tests/smoke_run_effects.gd`：RunDirector 和 RunEffects 的奖励、事件、modifier、attunement、forge、scout 行为。
- `tests/smoke_accessory_catalog.gd`：饰品目录、图标、生成三选一、offer metadata、fit label、comparison/source label。
- `tests/smoke_accessory_flow.gd`：世界中饰品选择打开、选择后装备并保持 encounter。

## UI 与本地化

- `tests/smoke_ui_screens.gd`：最重的 UI 规格。覆盖标题、角色选择、图鉴、关于页、暂停、音频设置、设置、事件面板、饰品面板、库存、HUD、结果页，以及移动端尺寸适配。
- `tests/smoke_locale_zh_hans.gd`：简体中文 UI 文本检查。
- `tests/capture_ui_layouts.gd`：截图采集，用于视觉回归。

## 地图与视觉

- `tests/smoke_map_random_props.gd`：地图随机 prop、碰撞、可走装饰、功能房共用分支槽。
- `tests/smoke_boss_visuals.gd`：Boss 场景视觉和贴图加载。

## 建议验证顺序

如果下个 Codex 改了核心逻辑，优先跑：

1. `smoke_lineage_save.gd`
2. `smoke_run_effects.gd`
3. `smoke_player_control.gd`
4. `smoke_run_flow.gd`
5. `smoke_function_room_flow.gd`
6. `smoke_ui_screens.gd`

如果只改 UI，优先跑：

1. `smoke_ui_screens.gd`
2. `smoke_locale_zh_hans.gd`
3. `capture_ui_layouts.gd`

