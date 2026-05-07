# Infinity Kingdom C++ GDExtension 项目

这是一个已经配好 `godot-cpp + GDExtension` 的 Godot 4 团队项目模板，适合课程大作业直接使用。

你们可以把主要游戏逻辑写在 `C++` 中，再由 Godot 直接加载和调用。

## 仓库里已经包含什么

- 可直接使用的 `godot-cpp` 依赖：`thirdparty/godot-cpp`
- 根目录构建脚本：`SConstruct`
- C++ 示例源码：`src/`
- Godot 演示工程：`demo/`
- Windows 构建脚本：`scripts/`
- 中文操作文档：`docs/`

## 你们现在能直接做什么

1. 打开终端进入仓库根目录
2. 执行调试构建：

```bat
scripts\build_debug.bat
```

3. 用 Godot 打开 `demo/project.godot`
4. 运行 `main.tscn`
5. 之后直接在 `src/` 里继续写 C++ 代码

## 目录说明

- `src/`：你们主要写 C++ 逻辑的地方
- `demo/`：Godot 测试工程、`.gdextension` 配置和编译产物
- `scripts/`：Windows 下的快捷构建脚本
- `docs/`：中文使用说明和协作文档
- `thirdparty/godot-cpp/`：已经放好的 Godot C++ 绑定

## 常用构建命令

调试版：

```bat
scons platform=windows target=template_debug
```

发布版：

```bat
scons platform=windows target=template_release
```

## 现在项目里已经有的示例类

- `GameManager`：简单分数与状态管理
- `PlayerController`：2D 角色移动控制示例

它们已经在 `src/register_types.cpp` 中注册，可以直接被 Godot 识别。

## 文档入口

- 环境安装与编译：`docs/setup-and-build.md`
- 如何编写 C++ 并暴露给 Godot：`docs/cpp-workflow.md`
- 6 人协作建议：`docs/team-collaboration.md`

## 适合你们课程大作业的使用方式

- 大部分玩法逻辑写在 C++
- 场景、UI、资源和少量胶水逻辑放在 Godot 侧
- 每次修改 C++ 后重新编译，再回到 Godot 测试
