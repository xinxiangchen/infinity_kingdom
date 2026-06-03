# 本轮整合改动记录

本文记录本轮我在项目里完成的主要工作，方便后续在 PR、答辩、组内交接时说明“这一轮到底改了什么”。内容按模块整理，全部面向当前 Godot/GDScript 项目。

## 总体目标

这轮改动的核心目标是把项目从“能跑的单体大文件”推进到“适合多人协作的大作业工程”：

- 接入新版 morenew 角色素材和角色代码。
- 把地图、人物、UI、交互逻辑逐步解耦。
- 给角色组、地图组、UI 组、整合组留下清晰 API 和规范。
- 做出可以单独调试角色和敌人的入口。
- 把地图、敌人、Boss、音频和 C++ GDExtension 脚手架都纳入主仓库。

## 角色接入

本轮把 morenew 的角色资源接进主项目，并保留原来的选人流程。

已经完成：

- 接入骑士、游侠、法师三类角色场景。
- 主流程选人后能实例化对应角色。
- 角色素材、武器、死亡图、技能图标等资源进入项目结构。
- 角色可以和主流程 HUD、战斗、受击、死亡逻辑联动。
- 写了角色模块 API 文档，要求角色组后续封装自己，对外只暴露方法和信号。

相关文档：

- `docs/CHARACTER_MODULE_API.md`
- `docs/GDSCRIPT_CODE_STANDARDS.md`

## 地图与关卡整合

地图部分从单独 demo 开始，逐步接入到主流程。

已经完成：

- 把多张地图房间横向拼接。
- 每个房间左右有入口/出口概念。
- 相机锁定当前房间，不会跨房间乱移动。
- 玩家清完当前房间敌人后，才进入下一张图。
- 城外阶段使用小兵波次。
- 皇宫阶段放 Boss：
  - 第一个皇宫 Boss：审判官。
  - 王座前最终 Boss：双子王子。

地图碰撞也做了多轮修正：

- 地图本身的碰撞改为围住墙体和不可走边界。
- 不再用整片草地/地面当碰撞。
- 逐图维护墙体碰撞框。
- 地图上的小物件使用素材图 alpha 像素包围盒算法生成碰撞框。
- 小物件可以作为掩体，阻挡子弹或攻击。
- 主流程地图会随机生成部分小物件，增加躲避空间。

相关文件：

- `tools/map_browser_demo.gd`
- `systems/map/map_runtime.gd`
- `assets/maps/stitched_demo/`

相关文档：

- `docs/MAP_INTEGRATION_NOTES.md`

## 小兵与 Boss

本轮把 6 种小兵和两个主要 Boss 接进主流程和调试流程。

小兵包括：

- 剑兵
- 盾卫
- 弓手
- 猎手
- 学徒法师
- 秘术师

Boss 包括：

- 审判官
- 双子王子

已完成：

- 城外阶段全部使用小兵波次。
- 皇宫阶段进入 Boss。
- 角色调试入口中可以选择 6 种小兵和 2 个 Boss 作为测试目标。
- 小兵武器显示修复：之前场景里 `Weapon` 节点默认隐藏，现在会根据敌人类型自动挂真实武器贴图。
- 小怪支持普通/精英武器图。

相关文件：

- `actors/enemy/`
- `actors/bosses/town/`
- `ui/debug_enemy_select.gd`
- `tools/character_debug_world.gd`

## 音频接入

本轮把音频 zip 包里的 BGM 放入对应阶段，并接入主流程播放逻辑。

已完成：

- 标题界面 BGM。
- 城外小兵战 BGM。
- 皇宫探索/过渡 BGM。
- 王宫守卫阶段 BGM。
- 皇帝/最终 Boss 阶段 BGM。
- 教堂/间歇阶段 BGM。
- 胜利和失败 BGM。

同时把阶段到 BGM profile 的映射从 `world.gd` 中拆出来：

- `systems/run/audio_route.gd`

这样后续音频组只需要维护 profile 和资源，不需要改主流程。

## 架构解耦

本轮重点拆了 `world.gd` 中过重的职责。

已完成：

- 地图运行时逻辑拆到 `systems/map/map_runtime.gd`。
- 音频阶段路由拆到 `systems/run/audio_route.gd`。
- 新增模块负责人协作文档，约定 UI、人物、地图、交互、轮回、C++ 的边界。
- 新增 GDScript 代码规范，要求模块之间通过 API、信号、snapshot 交互。

当前设计原则：

- `world.gd` 只做主流程编排。
- 人物模块只管自己移动、攻击、技能、受击、动画。
- 地图模块只管房间、碰撞、相机、出生点、战斗点。
- UI 模块只展示状态和发出玩家选择，不直接修改玩法数据。
- 交互逻辑后续独立成 service，不塞进角色或 UI。
- 血缘火种和皇帝持久 HP 后续属于 run state，不属于 UI 或角色。

相关文档：

- `docs/MODULE_OWNERSHIP_AND_GDEXTENSION.md`
- `docs/GDSCRIPT_CODE_STANDARDS.md`
- `docs/PROJECT_STRUCTURE.md`

## 角色调试入口

本轮新增了一个独立角色调试入口，专门给角色组和整合组测试角色。

当前启动流程：

1. 进入主入口。
2. 先使用原来的选人 UI 选择角色。
3. 选完后出现新的模式选择 UI：
   - 正常流程
   - 角色调试
4. 选择正常流程会进入完整主游戏。
5. 选择角色调试会进入无地图测试场。

角色调试场特点：

- 不加载地图。
- 不走饰品奖励。
- 不走关卡结算。
- 有简单方块测试场。
- 有独立角色状态 HUD。
- 可以选择测试敌人。
- 可以选择训练假人、小兵、Boss。
- 可以按 `R` 重置目标。
- 可以按 `Esc` 返回选人。

新增 UI：

- `ui/play_mode_select.gd`
- `ui/debug_enemy_select.gd`
- `ui/character_debug_status.gd`

新增入口：

- `app_entry.tscn`
- `app_entry.gd`

新增启动上下文：

- `systems/run/startup_context.gd`

## C++ GDExtension 脚手架

本轮把已有 C++ GDExtension 插件脚手架接入项目，保证后续 C++ 大作业重构可以继续推进。

已完成：

- 添加 `SConstruct`。
- 添加 `demo/coursework_extension.gdextension`。
- 添加 `src/` 下的 C++ 示例类。
- 添加 `thirdparty/godot-cpp` submodule。
- 修正 `.gdextension` 动态库路径为当前项目结构下的 `res://demo/bin/...`。
- 本地已使用 `scons platform=windows target=template_debug -j8` 编译通过。

注意：

- GitHub 下载 ZIP 不会自动带完整 submodule。
- 要编译 C++，推荐使用：

```bash
git clone --recursive https://github.com/xinxiangchen/infinity_kingdom.git
```

如果已经 clone 但 submodule 没拉：

```bash
git submodule update --init --recursive
```

相关文档：

- `docs/cpp-workflow.md`
- `docs/MODULE_OWNERSHIP_AND_GDEXTENSION.md`

## Git 与仓库状态

本轮已经把代码推送到你的主仓库：

- 主仓库：`xinxiangchen/infinity_kingdom`
- 主分支：`master`
- 整合分支：`integrate-morenew-character`

当前推荐协作方式：

- 你的仓库作为主仓库。
- 其他同学从你的仓库 fork 或 clone。
- 每个人从 `master` 拉自己的功能分支。
- 完成后向 `xinxiangchen/infinity_kingdom:master` 提 PR。

推荐分支命名：

- `feature/character-refactor`
- `feature/map-collision`
- `feature/ui-polish`
- `feature/interaction-system`
- `feature/bloodline-run-state`

## 本轮验证

本轮多次执行了 Godot smoke 和 C++ 构建验证。

常用验证命令：

```powershell
F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --quit

F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --script res://tests/smoke_run_flow.gd

F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --script res://tests/smoke_player_control.gd

scons platform=windows target=template_debug -j8
```

本轮主要提交都通过了基础加载和 smoke 检查。

## 后续建议

角色组：

- 按 `docs/CHARACTER_MODULE_API.md` 和 `docs/GDSCRIPT_CODE_STANDARDS.md` 重构角色。
- 不要让角色脚本直接访问地图或 UI。
- 角色只暴露方法和信号。

地图组：

- 继续逐图修墙体碰撞。
- 维护物件候选和掩体碰撞。
- 新地图先在地图 demo 中验证，再进主流程。

UI 组：

- UI 只接收 snapshot 和发出 signal。
- 不直接改角色血量、金币、地图状态。
- 后续血缘火种和皇帝 HP 需要进 HUD。

整合组：

- 保持 `world.gd` 只做编排。
- 新逻辑优先抽 service/facade。
- 每次合并前跑 smoke。

C++ 组：

- 优先迁移纯逻辑。
- 不要先迁 UI 或 Godot 场景节点。
- 第一批适合迁移：血缘火种、皇帝持久 HP、战斗公式、奖励随机。
