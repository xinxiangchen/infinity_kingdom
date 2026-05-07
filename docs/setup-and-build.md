# 环境配置与编译手册

这份文档说明如何配置环境、编译 GDExtension，并在 Godot 中运行项目。

## 1. 需要安装的软件

每位组员至少需要准备：

- Godot 4.3 或更高版本
- Python 3.8+
- SCons
- C++ 编译器

Windows 推荐：

- Visual Studio Build Tools 2022（推荐）
- 或者已经统一配置好的 MinGW

## 2. 项目目录说明

- `src/`：C++ 源码
- `demo/`：Godot 演示工程
- `demo/bin/`：编译生成的动态库
- `thirdparty/godot-cpp/`：Godot C++ 绑定
- `scripts/`：快捷脚本
- `docs/`：项目文档

## 3. 首次使用前先检查环境

在仓库根目录打开终端，执行：

```bat
python --version
scons --version
```

如果你们使用 MSVC，请尽量在 `Developer Command Prompt` 中编译，这样编译器环境会自动准备好。

## 4. 编译调试版

直接执行：

```bat
scripts\build_debug.bat
```

或者手动执行：

```bat
scons platform=windows target=template_debug
```

编译成功后，会在 `demo/bin/` 下生成 `.dll` 文件。

## 5. 编译发布版

执行：

```bat
scripts\build_release.bat
```

或者：

```bat
scons platform=windows target=template_release
```

## 6. 在 Godot 中打开项目

1. 打开 Godot
2. 导入或打开 `demo/project.godot`
3. 运行主场景

如果扩展加载正常，你会看到：

- Godot 能识别 `GameManager` 和 `PlayerController`
- 场景中的文字状态会变化
- 按下确认键后，会调用 C++ 逻辑更新分数

## 7. 常见问题

### 找不到 `scons`

说明 SCons 没有安装好，或者没有加入系统环境变量。

### 找不到编译器

请确认你安装了 C++ 工具链，并在正确的命令行环境中执行编译。

### Godot 提示扩展加载失败

请依次检查：

- 编译是否成功结束
- `demo/bin/` 下是否真的生成了 `.dll`
- `demo/coursework_extension.gdextension` 中的文件名是否对应正确
- Godot 版本是否和当前绑定兼容

## 8. 清理旧产物

如果你怀疑旧文件影响了结果，可以执行：

```bat
scripts\clean_demo_bin.bat
```

然后重新编译。
