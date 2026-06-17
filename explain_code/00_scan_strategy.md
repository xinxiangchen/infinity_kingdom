# Infinity Kingdom 代码解读扫描策略

本文档基于一次轻量目录扫描生成。后续用户明确收窄范围：本次交接不阅读、不解释 C++，只整理项目自己的实现代码，给下一个 Codex 快速接手用。

## 当前项目判断

- 项目类型：Godot 项目。
- 主要脚本语言：GDScript。
- 已存在 C++/GDExtension 雏形和第三方 C++ 依赖，但本次范围明确排除，不阅读、不解释。
- 资源体量较大：`assets/`、`art/`、`audio/`、`tools/generated_previews/` 等目录主要是图片、音频、预览和导入文件。

## 文件类型概览

轻量扫描显示：

- `.gd`：约 116 个，是主要业务逻辑和 UI 逻辑来源。
- `.tscn`：约 44 个，是场景结构、节点关系和脚本绑定的重要来源。
- `.md`：约 37 个，包含已有架构、待办和模块协作说明。本轮不依赖文档替代代码事实。
- `.png` / `.webp` / `.wav` / `.mp3` / `.ttf`：资源文件，后续只记录被谁引用、承担什么角色。

## 建议扫描优先级

### 第一优先级：启动与主流程

- `project.godot`
- `app_entry.gd`
- `world.gd`
- `app_entry.tscn`
- `world.tscn`

目标：

- 找出项目入口。
- 梳理启动流程、主场景、世界控制器职责。
- 给下一个 Codex 标清后续改流程应该从哪里下手。

### 第二优先级：核心玩法系统

- `systems/run/`
- `systems/accessories/`
- `systems/consumables/`
- `systems/map/`
- `systems/pickups/`
- `combat/`
- `effects/`

目标：

- 梳理战斗、道具、局内流程、地图运行、存档、血量、投射物等核心逻辑。
- 识别输入、输出、状态修改、事件或信号。
- 提取可独立理解的状态、输入、输出和副作用。

### 第三优先级：角色与敌人

- `characters/`
- `actors/`

目标：

- 梳理玩家角色、敌人、Boss、状态机、攻击行为。
- 标记共享逻辑、重复逻辑和可抽象接口。
- 识别角色数据、技能、碰撞、受击、死亡、AI 行为的迁移边界。

### 第四优先级：UI 与展示

- `ui/`
- `systems/ui/`

目标：

- 区分纯展示、输入处理、业务状态读写。
- 标记 UI 和核心逻辑耦合点。
- 标记 UI 和核心逻辑耦合点。

### 第五优先级：工具、测试和资源

- `tests/`
- `tools/`
- `audio/tools/`
- `assets/`
- `art/`
- `audio/`

目标：

- 测试脚本可作为行为规格参考。
- 工具脚本只解释用途和输入输出，不作为运行时核心逻辑。
- 资源目录记录分类、引用方式和迁移注意点。

### 本次不处理：C++、第三方与构建

- `src/`
- `SConstruct`
- `.gitmodules`
- `thirdparty/godot-cpp/`
- `export_presets.cfg`

目标：

- 当前用户要求不读 C++，所以上述内容只作为项目背景，不进入实现代码解读。

## 文档目录建议

后续可以逐步补全以下结构：

```text
explain_code/
  00_scan_strategy.md
  01_project_overview.md
  02_entry_and_runtime_flow.md
  03_dependency_map.md
  inventory/
    code_inventory.md
    resource_inventory.md
    docs_inventory.md
  folders/
    actors.md
    audio.md
    characters.md
    combat.md
    effects.md
    src.md
    systems.md
    tests.md
    tools.md
    ui.md
```

## 每个文件夹的解释模板

```md
# 文件夹名

## 职责

说明该文件夹负责的游戏系统或资源范围。

## 主要文件

- `xxx.gd`：负责什么。
- `xxx.tscn`：绑定哪些节点和脚本。

## 输入

- 用户输入。
- 场景节点事件。
- 其他系统调用。
- 配置、存档或资源。

## 输出

- 返回值。
- 修改的状态。
- 发出的信号。
- 创建或销毁的节点。
- UI 更新。
- 文件读写。

## 调用关系

- 调用了哪些模块。
- 被哪些模块调用。
- 依赖哪些 Godot API。

## 关键逻辑

用流程说明核心实现。

## 后续重构抓手

- 可拆分部分。
- 当前隐式接口。
- 状态、输入、输出、副作用。
- 高风险耦合点。

## 风险点

- 引擎耦合。
- UI 耦合。
- 全局状态。
- 动态类型和隐式字段。
- 资源路径硬编码。
```

## 我建议正式扫描前再做的事

1. 先以代码事实为准，文档和待办只作为辅助材料。
2. 建立“代码事实”和“文档意图”的双栏记录，避免旧文档误导实际代码判断。
3. 对所有 `.gd` 文件提取类名、继承类型、信号、导出变量、主要函数名，生成一份代码清单。
4. 对 `.tscn` 提取脚本绑定关系，避免只看脚本而漏掉场景节点输入。
5. 最后再逐文件夹写解释文档，并给每个模块标注重构风险等级。
