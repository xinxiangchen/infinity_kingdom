# C++ 重构可行性与 Codex 交接总结

更新日期：2026-06-09  
仓库位置：`F:\infinity_kingdom`  
当前分支：`master`  
当前已同步远端：`origin/master`，最新提交为 `d6b7b2f Fix startup errors and polish combat UI`

## 1. 先说结论

后续把大部分游戏逻辑逐步改成 C++ / GDExtension 是可行的，但不建议直接把整个项目一次性重写。

更推荐的做法是：

1. Godot 场景、UI、流程编排继续用 GDScript。
2. 高频、纯计算、规则稳定的玩法逻辑逐步迁移到 C++。
3. 每迁移一个模块，都先保留 GDScript 对外 API 不变。
4. 主程序仍然通过统一接口调用，不关心背后是 GDScript 还是 C++。

也就是说，不是“把游戏推倒重写成 C++”，而是“把核心玩法系统做成 C++ 模块，Godot/GDScript 负责把模块串起来”。

## 2. 为什么可行

当前项目已经具备 C++/GDExtension 的基础条件：

- 仓库中有 `SConstruct`。
- 仓库中有 `thirdparty/godot-cpp/`。
- 项目结构已经是 Godot 4 项目。
- 后续可以通过 GDExtension 暴露 C++ 类给 GDScript 调用。

从架构上看，项目当前已经有一些天然适合迁移的模块：

- 战斗伤害结算。
- 角色属性、构筑修正、buff/debuff 合并。
- 敌人 AI 的目标选择和移动决策。
- 投射物批量更新。
- 地图物件碰撞框生成。
- 血脉火种、资质继承、皇帝血量持久化等纯规则系统。

这些模块大多可以做成“输入 Dictionary/结构体，输出结果”的形式，适合 C++。

## 3. 为什么不能直接全部 C++ 化

不建议直接全部改 C++，原因有四个：

1. 当前玩法规则还没完全定稿。血脉火种、资质继承、皇帝血量跨代保留、技能分支、武器强化、消耗品槽都还在待实现阶段，太早 C++ 化会增加修改成本。
2. Godot 的 UI、场景树、信号连接、资源加载用 GDScript 更快更直观，课程项目时间有限，不值得全部 C++ 化。
3. 当前 `world.gd` 还承担大量整合职责，需要先拆模块再迁移，否则会把一个大脚本变成一个更难维护的大 C++ 类。
4. GDExtension 调试成本高于 GDScript。每次改 C++ 都要编译，组员协作时容易因为环境不同出问题。

因此最稳的策略是：先解耦，再迁移。

## 4. 推荐迁移顺序

### 第一阶段：不改变玩法，只搭 C++ 最小闭环

目标：证明仓库能稳定加载一个 C++ 扩展。

要做：

- 确认 `.gdextension` 文件位置。
- 确认 Windows debug/release 动态库输出路径。
- 写一个最小 C++ 类，例如 `CppMathTest`。
- 在 Godot 中用 GDScript 调用这个类。
- 写清楚构建命令。

验收：

- Godot 打开项目不报扩展加载错误。
- GDScript 能调用 C++ 方法并得到正确返回。
- 其他同学按文档能重新编译成功。

### 第二阶段：迁移纯计算模块

优先迁移：

- 伤害结算。
- 属性修正合并。
- 暴击、护甲、防御、伤害类型计算。
- 构筑效果合并。

原因：

- 不依赖场景树。
- 容易写测试。
- 出错范围小。
- 后续角色、敌人、Boss 都会用到。

建议 C++ 模块名：

- `CombatCalculator`
- `ModifierStack`
- `DamagePayload`

GDScript 外观接口保持类似：

```gdscript
var result := CombatCalculator.calculate_damage(payload, attacker_state, defender_state)
```

### 第三阶段：迁移 Run 规则

适合迁移：

- 血脉火种。
- 代际编号。
- 资质生成。
- 皇帝血量跨代保留。
- 大周目胜负判断。

建议 C++ 模块名：

- `LineageState`
- `AptitudeGenerator`
- `EmperorProgress`

注意：

- UI 仍然用 GDScript。
- 存档/读档暂时可以先不做复杂二进制格式。
- C++ 只返回状态，主流程决定显示什么面板。

### 第四阶段：迁移敌人和投射物高频逻辑

适合迁移：

- 敌人目标选择。
- 追击、绕障、保持距离。
- 投射物运动更新。
- 大量弹幕碰撞前筛选。

不建议一开始迁移完整 Boss：

- Boss 规则变化多。
- 动画、音频、阶段演出经常需要调。
- 用 GDScript 更适合快速打磨。

### 第五阶段：地图工具类迁移

适合迁移：

- 根据图片 alpha 计算最高、最低、最左、最右非透明像素。
- 生成小物件碰撞外框。
- 物件摆放的空间检测。

注意：

- 地图场景拼接仍建议 GDScript 做。
- C++ 只做计算，不直接创建大量 Godot 节点。

## 5. 哪些内容建议保留 GDScript

这些内容不要急着 C++ 化：

- `world.gd` 这种主流程编排。
- UI 面板。
- 选人流程。
- 暂停、设置、结果界面。
- 音乐切换。
- 地图节点创建和场景拼接。
- Boss 演出和阶段调参。
- 调试入口。

这些模块变化频繁，用 GDScript 更适合快速协作。

## 6. 下一个 Codex 接手时的仓库状态

本轮已经做过：

1. 从 GitHub 拉取并更新本地仓库。
2. 本地 `master` 已和 `origin/master` 对齐到 `d6b7b2f`。
3. 在 `todolist/` 下新增了两份文档：
   - `代码架构指南.md`
   - `策划差距与待办指南.md`
4. 本文档用于说明 C++ 重构可行性和后续交接。

注意：

- 当前工作区还有一个原本就存在的 `export_presets.cfg` 本地修改，本轮没有改它。
- 当前新增的 `todolist/` 文档还没有提交到 Git。
- 如果要提交文档，请只提交 `todolist/`，不要把 `export_presets.cfg` 混进去，除非确认它也应该进入版本。

## 7. 当前项目核心结构速记

主入口：

- `app_entry.gd`
- `app_entry.tscn`
- `world.gd`
- `world.tscn`

角色：

- `characters/knight/`
- `characters/ranger/`
- `characters/mage/`

敌人和 Boss：

- `actors/enemy/town_enemy.gd`
- `actors/encounters/`
- `actors/bosses/town/`

地图：

- `systems/map/map_runtime.gd`
- `tools/map_browser_demo.gd`

运行规则：

- `systems/run/run_director.gd`
- `systems/run/run_effects.gd`
- `systems/run/audio_route.gd`

饰品和拾取：

- `systems/accessories/accessory_manager.gd`
- `systems/pickups/`

UI：

- `ui/character_select.*`
- `ui/play_mode_select.*`
- `ui/battle_status.*`
- `ui/character_debug_status.*`
- `ui/debug_enemy_select.*`
- `ui/accessory_choice.*`
- `ui/run_event_panel.*`
- `ui/pause_menu.*`
- `ui/result_screen.*`

C++ 相关：

- `SConstruct`
- `src/`
- `thirdparty/godot-cpp/`

## 8. 当前玩法完成度速记

已经有：

- 三职业选择。
- 正常模式和角色调试模式。
- 地图房间拼接。
- 每张地图一轮怪物刷新。
- 六类小兵素材和逻辑接入。
- 守关 Boss、双子/王子 Boss、最终 Boss 场景。
- 地图入口出口、房间转场、摄像机锁定。
- 小物件随机生成和碰撞。
- HUD、事件、金币、经验、饰品选择。
- BGM 路由。

还缺：

- 血脉火种。
- 父死子继。
- 资质继承。
- 皇帝血量跨代保留。
- 技能分支选择和两次强化。
- 武器强化词条系统。
- 主动消耗品槽。
- 空间化教堂、军需库、商人、皇帝门前准备点。
- 统一交互系统。
- 更完整的 C++/GDExtension 接入。

## 9. 给下一个 Codex 的建议任务顺序

如果下一个 Codex 要继续推进 C++ 和架构，请按这个顺序：

1. 先读 `todolist/代码架构指南.md`。
2. 再读 `todolist/策划差距与待办指南.md`。
3. 确认 `git status`，不要误提交 `export_presets.cfg`。
4. 先做 GDExtension 最小可运行样例。
5. 写 `docs/cpp-gdextension-quickstart.md` 或补充已有 C++ 文档。
6. 迁移一个最小纯计算模块，例如伤害结算。
7. 给 GDScript 保持同名包装接口。
8. 运行 Godot 项目确认正常模式和角色调试模式都不坏。
9. 再考虑迁移血脉火种、资质继承、皇帝持久血量。

## 10. 最重要的原则

后续不要为了“用了 C++”而破坏协作效率。

这门大作业最需要的是：

- 主流程能跑。
- 模块边界清楚。
- 同学之间不互相改爆对方代码。
- 策划核心卖点能落地。
- C++ 用在真正适合的地方。

所以推荐最终架构是：

```text
GDScript：场景、UI、流程、调试、资源装配
C++：战斗计算、构筑规则、继承规则、状态推进、高频更新
```

这样既能满足“后续大部分核心逻辑用 C++ 重写”的课程目标，也不会把 Godot 项目变成难以调试和难以协作的全 C++ 工程。
