# C++ 开发手册

这份文档说明你们应该如何在这个项目里编写 C++，并让 Godot 能直接调用这些代码。

## 1. 项目工作原理

你们写的 C++ 代码不会直接被 Godot 当脚本运行。

正确流程是：

1. 在 `src/` 中编写 C++ 类
2. 用 `godot-cpp` 方式绑定方法
3. 在 `src/register_types.cpp` 里注册类
4. 编译成动态库
5. 由 Godot 通过 `demo/coursework_extension.gdextension` 加载

完成后，这些类就能在 Godot 编辑器和运行时中被使用。

## 2. 代码写在哪

你们的主要 C++ 代码都写在：

- `src/你的类名.h`
- `src/你的类名.cpp`

建议一类一对文件，结构清晰，方便 6 个人协作。

## 3. 新建一个可被 Godot 调用的类

头文件示例：

```cpp
#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class EnemyAI : public Node {
	GDCLASS(EnemyAI, Node)

protected:
	static void _bind_methods();

public:
	void think(float delta);
};

}
```

源文件示例：

```cpp
#include "enemy_ai.h"

using namespace godot;

void EnemyAI::_bind_methods() {
	ClassDB::bind_method(D_METHOD("think", "delta"), &EnemyAI::think);
}

void EnemyAI::think(float delta) {
	// 在这里写你的玩法逻辑
}
```

## 4. 一定要注册类

打开 `src/register_types.cpp`，把你的类注册进去：

```cpp
GDREGISTER_CLASS(EnemyAI);
```

如果不注册，Godot 就看不到这个类。

## 5. 每次改完都要重新编译

修改 C++ 后，执行：

```bat
scripts\build_debug.bat
```

## 6. 在 Godot 中调用 C++ 类

重新编译成功后，可以在 GDScript 里直接使用：

```gdscript
var enemy := EnemyAI.new()
enemy.think(0.016)
```

也可以在编辑器里把注册后的类直接作为节点添加到场景里。

## 7. 仓库里已经给好的示例

### `GameManager`

作用：

- 保存简单分数
- 提供 `team_name`
- 提供 `add_score()`
- 提供 `get_status_text()`

### `PlayerController`

作用：

- 继承 `CharacterBody2D`
- 提供 `speed`
- 接收 `Vector2` 输入进行移动

## 8. 推荐开发规范

- 每个人尽量负责不同系统，减少同时改同一文件
- 头文件放声明，`.cpp` 放实现
- 新系统尽量新建文件，不要全塞进一个类
- 方法命名清晰稳定，方便场景和脚本调用
- 提交前至少自己编译一次
- 新功能尽量先在 `demo/` 里验证

## 9. 课程项目 6 人分工建议

1. 核心玩法逻辑
2. 玩家控制、攻击、交互
3. 敌人、AI、行为树或状态机
4. 数据系统、分数、背包、存档
5. Godot 场景、UI、演出与资源整合
6. 构建、联调、合并和最终测试

## 10. 最重要的一点

这个项目是“用 C++ 写 Godot 扩展”，不是“把普通 C++ 文件扔进去就会自动运行”。

要让 Godot 调用到你的代码，必须完成这四步：

- 写类
- 绑定方法
- 注册类
- 重新编译
