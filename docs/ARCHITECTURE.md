# Codefarm 代码结构

本文说明每个源文件负责什么、彼此怎么连接，以及改某类功能时应改哪个文件。规则和设计约定见 [AGENTS.md](../AGENTS.md) 与 [PROJECT-OVERVIEW.md](PROJECT-OVERVIEW.md)。

## 三层

```
sim/        纯 C++ 规则与解释器（无 Godot 依赖）── 唯一的规则来源
extension/  GDExtension：把 sim 包成 Godot 节点 CodefarmHost
game/       Godot 工程：画面、界面、输入、存档，只读写 CodefarmHost
```

玩法规则（生长、收割、价格、解锁、tick 计时）只写在 `sim/`。`game/` 每帧从 `CodefarmHost` 读取状态并呈现，不自行计算规则。

## sim/：模拟器

| 文件 | 负责 |
| --- | --- |
| `include/codefarm/types.hpp` | 实体、地面、物品、价格与生长等数据表 |
| `include/codefarm/world.hpp`、`src/world.cpp`、`src/world_state.cpp` | 农场世界：地块、无人机、背包、技能解锁，以及存档序列化 |
| `include/codefarm/interpreter.hpp` | 解释器公开接口 |
| `src/interpreter_lexer.hpp` | 词法：玩家 C++ 子集的记号 |
| `src/interpreter_ast.hpp` | 语法树：表达式、语句、函数与结构体定义 |
| `src/interpreter_parser.hpp` | 解析：记号转语法树，并检查当前已解锁哪些语言特性 |
| `src/interpreter_runtime.hpp` | 运行时：值、作用域、调用帧、每台无人机的执行状态 |
| `src/interpreter.cpp` | `Interpreter::Impl` 按 tick 逐步执行，以及公开接口实现 |

`interpreter_*.hpp` 是内部头文件，只被 `interpreter.cpp` 包含，内容放在 `codefarm::detail` 命名空间。

## game/scripts/：游戏

`main.gd` 是组装层：持有场景节点，创建下列组件并用 `setup()` 传入依赖、用信号接收回调，负责主循环、欢迎页与会话、存档、代码窗口与提示窗口、运行控制、报错和设置等面板。

| 组件 | 负责 | 与 main 的连接 |
| --- | --- | --- |
| `farm_field.gd` | 田块、草叶、灌木、作物、远景简化、地台、草甸与装饰 | `size_changed` 信号 → 相机重新取景 |
| `farm_bot.gd` | 小 bot 造型、移动、待机、收割/耕地/翻跟头/撞墙动作、多机 | `setup()` 传入 `tile_world`、`sfx` |
| `farm_camera_rig.gd` | 环绕、拖动平移与惯性、缩放、WASD、F 回正 | `setup()` 传入界面遮挡与焦点查询 |
| `farm_skill_tree.gd` | 技能树面板、节点卡片、购买反馈、详情与范本 | `bought`、`rebuild_requested`、`load_exemplar_requested`、`template_copied` 信号 |
| `farm_editor_assist.gd` | 字号缩放、按缩进退格、语法配色、补全 | `edited`、`clicked` 信号 |
| `farm_code_files.gd` | main.cpp 与头文件、文件栏、把头文件交给模拟器 | 存档恢复、重置、载入范本时由 main 调用 |
| `farm_collect_fx.gd` | 收获物飞向顶栏计数的效果 | main 在收割后调用 `collect()` |
| `farm_ui_kit.gd` | 字体、共享 Theme、样式盒与按钮工厂 | main 和各面板通过 `ui.*` 构建控件 |
| `farm_layout.gd` | 田块间距、高度等共享几何 | 田地、相机、bot 共用 |
| `farm_palette.gd` | 界面与语法配色 | 全部界面 |
| `farm_changelog.gd` | 游戏内「日志」面板文本 | 日志面板 |

其余脚本：`farm_window.gd`（可拖动窗口）、`farm_code_editor.gd`（受保护的 main 框架）、`farm_skill_scroll.gd`（技能树拖动缩放）、`highlight_overlay.gd`（执行行高亮）、`error_markup.gd`（报错标记）、`farm_icons.gd`（程序化图标）、`farm_motion.gd`（统一动效）、`farm_audio.gd`（合成音效）、`farm_save.gd`（带校验的存档写入）、`farm_scenery.gd`（草甸装饰）、`skill_data.gd`（技能树布局与文案）。

### 改哪里

| 想改的东西 | 文件 |
| --- | --- |
| 生长、收割、价格、解锁条件 | `sim/`（并跑 C++ 测试与玩家路线） |
| 玩家能写的语法、报错文字 | `sim/src/interpreter_parser.hpp` 等 |
| 作物与地块的样子 | `farm_field.gd` |
| bot 的造型与动作 | `farm_bot.gd` |
| 视角手感 | `farm_camera_rig.gd` |
| 技能树界面 | `farm_skill_tree.gd`；节点位置与文案在 `skill_data.gd` |
| 补全、字号、语法颜色 | `farm_editor_assist.gd`、`farm_palette.gd` |
| 按钮、面板的统一样式 | `farm_ui_kit.gd`、`farm_palette.gd` |
| 更新日志 | `CHANGELOG.md`、`game/changelog.md`、`farm_changelog.gd` |

## 验收脚本

`game/scripts/verify_*.gd` 通过 `main` 与 `main.<组件>`（如 `main.camera_rig`、`main.field`、`main.bot`、`main.skill_tree`、`main.editor_assist`、`main.code_files`）读取状态。改名或移动成员时要同步更新这些脚本：用 `has_method("…")` 守卫的检查在方法消失后会被静默跳过，不会报错。
