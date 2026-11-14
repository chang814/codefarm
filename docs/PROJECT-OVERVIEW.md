# Codefarm 项目概况

面向畅，以及之后一起开发的人（含 Codex）。读完这份应该能立刻上手。更细的约定写在仓库根目录的 [AGENTS.md](../AGENTS.md)。当前版本以桌面仓库的 `VERSION` 为准，现在是 **0.2.11**（2026-11-14）。唯一标准见 [SOURCE.md](SOURCE.md)。

## 唯一标准

**只认笔记本上的 `D:\桌面\codefarm`。** 这是所有 AI 共同使用的那一份。云电脑 `/workspace/codefarm` 只是工作副本，必须先和桌面对齐再改，改完写回桌面。两边不一致时以桌面为准，禁止用旧的云端包覆盖桌面。详细约定见 [SOURCE.md](SOURCE.md)。

每次改动都要升版本（或至少写进当前版本的更新日志），并且同时改 `VERSION`、`project.godot`、`main.gd` 和三处 changelog。方向以本概况、[playthrough.md](playthrough.md)、[skill-tree-design.md](skill-tree-design.md)、[endless-design.md](endless-design.md)（仅计划）以及最新的 `docs/review-*.md` 为准，不要另起一套。

写代码交给 Codex CLI；Codex Bot 负责派活、监督、验收和同步。

## 一句话定位

Codefarm 是用 **标准 C++** 写逻辑、用 **Godot 4.7.2** 呈现的 3D 编程农场，相当于 C++ 版的 *The Farmer Was Replaced*。工作标题和窗口标题都叫 Codefarm，界面为中文。仓库不使用、也不分发任何原作贴图、音乐或商标名。

## 设计理念

- **先痛后药。** 每个技能先让玩家撞上一个具体麻烦，再交出恰好能解决它的语法或 API。例如开局 `while harvest` 能一刀接一刀收到成熟草；买了「加速」后会打空，这时再买 `if (can_harvest())` 才有意义。
- **化繁为简的 UI。** 图标加一个词，少堆文字。技能树、顶栏、运行按钮都靠形状和颜色说话，说明放在 tooltip 或点开后的详情里。
- **范本一步一个概念。** 每个技能都有一份标准 C++ 范本，就是通关测试真正跑过的那份程序。相邻两份只多引入一个新东西，后期新作物先给朴素正确的写法，再由下一份改一处。解锁后可在提示窗口折叠、复制。
- **玩家写的是标准 C++ 程序形态：** `#include <bits/stdc++.h>`、`using namespace std;`、`int main()`。可执行语句默认写在 `main` 里。解释器是逐步解锁的 C++ 子集，不是完整编译器。

## 当前状态

0.2.2 已按正常玩法从新存档买完全部 45 个技能节点（全程约 52 分钟游戏时间，这是代码写好就跑的下限），每个节点都有范本。0.2.3 优化了图标按钮与选项动效；0.2.4 优化默认 20px 编辑器、框架保护与报错；0.2.5 补上技能树左键拖动。0.2.6 修复最大化瞬移、快速交互与范本载入。0.2.7 用未熟草重置生长代替固定失败惩罚：成功和空挥都按当前动作时间，盲收幼苗会停产，查询不伤幼苗。0.2.8 整理技能树、突出提示中的下一行代码，并将 bot 改为球形与固定竖眼。0.2.9 补上自动存档、欢迎页与音效。0.2.10 修复 bot 偏移与编辑器输入，加入草甸背景、圆角地块和独立技能图标。最新验收见 [review-0.2.8.md](review-0.2.8.md)，教学与长期玩法的后续问题仍见 [review-0.2.4.md](review-0.2.4.md)。无尽 / 优化挑战只写了计划，见 [endless-design.md](endless-design.md)。尚未经畅试玩认可，**不要 git init，也不要上传 GitHub**。

笔记本上的可玩副本在 `D:\桌面\codefarm`。请先完全退出 Godot，再用 Godot 4.7.2 打开其中的 `game` 文件夹。

### 版本历史摘要

| 版本 | 日期 | 摘要 |
| --- | --- | --- |
| 0.1.0 | 2026-11-10 | 第一个可玩预览：1×1 草地、`harvest`、累计干草解锁 `while` 与移动。 |
| 0.1.1 | 2026-11-11 | 按「先痛后药」重排技能；补耕地与种植；代码 / 提示改成可拖动窗口。 |
| 0.1.2 | 2026-11-11 | 干草改为可花的货币；技能树改为图标加一个词；少文字、多图标。 |
| 0.1.3 | 2026-11-11 | 图标与窗口按钮更圆润；小 bot 改成豆子身体（当时还有屏幕脸）。 |
| 0.1.4 | 2026-11-11 | 眼睛改成黑色竖条；视角改为常见自由观察；窗口开合带柔和动效。 |
| 0.1.5 | 2026-11-11 | 实心三角跑完 `main` 即停，空心三角单步；循环和条件之间加「加速」；系统字换 Noto Sans CJK SC 并加大；去掉缩放手柄色块。 |
| 0.2.0 | 2026-11-11 | 按原作 1.0 主线一次落地全部技能与作物机制；多种货币；技能树可滚动。 |
| 0.2.1 | 2026-11-11 | 补上可复现的 `simulate()`、多机 3D、分文件编辑、大田合批；技能树改成圆润曲线分支；去掉脚下圆环；字体再柔和一档。 |
| 0.2.2 | 2026-11-11 | 整局通关测试与逐步递进的范本；移动改半个动作、胡萝卜只花干草等卡关修复；左键拖地图带惯性。 |
| 0.2.3 | 2026-11-11 | 顶栏图标改为圆角方形，按钮带悬停反馈；技能树与设置增加选项切换动效；技能树可左键拖动画布。 |
| 0.2.4 | 2026-11-11 | 代码区 20px 与更清楚的配色；保护默认 `main` 框架；报错带行列和建议；Windows 复跑通关与全量测试。检查记录见 [review-0.2.4.md](review-0.2.4.md)。 |
| 0.2.5 | 2026-11-11 | 技能树支持左键拖动画布（空白和节点上都可开始，6px 阈值，详情内不拖背景），并增加 `verify_skill_drag.gd`。 |
| 0.2.6 | 2026-11-11 | 失败收获固定 400 tick，让条件判断真正提高产出；独立空挥反馈，修复最大化瞬移和按钮状态，验收见 [review-0.2.6.md](review-0.2.6.md)。 |
| 0.2.7 | 2026-11-11 | 未熟草重置为幼苗，所有收割按当前动作时间；盲收持续停产，条件查询恢复成熟收割，支持手动等待恢复，验收见 [review-0.2.7.md](review-0.2.7.md)。 |
| 0.2.9 | 2026-11-14 | 进度自动保存（校验 + 备份）、欢迎页、代码合成音效；顶栏四按钮；修复开始按钮在屏幕外等布局回归，新增 `verify_save.gd`。 |

详细条目见 [CHANGELOG.md](../CHANGELOG.md)。

## 架构

三层分开：纯 C++ 模拟器负责规则，Godot 负责画面和编辑器，GDExtension 把两者接起来。逻辑按网格和 tick 计算；画面只用缓动和动画做手感，不改判定。

```
玩家代码（CodeEdit）
    → CodefarmHost（extension/）
        → Interpreter（sim/）逐步执行 C++ 子集
            → World（sim/）扣费、生长、移动、解锁
        ← 事件 / 状态
    → main.gd 更新 3D 农场、高亮、错误气泡、顶栏
```

范本 `game/exemplars/<id>.cpp`（有的还有 `<id>.farm.hpp`）被两处同时读取：游戏提示和技能详情走 `res://exemplars`（`skill_data.gd`），通关测试走 `tests/playthrough.hpp`。不要另写一份「展示用」代码。

### 目录

```
codefarm/
  AGENTS.md                 给编码智能体的仓库规则
  VERSION / CMakeLists.txt / README.md / CHANGELOG.md
  docs/                     本概况、通关、技能树、无尽计划、研究备忘
  sim/include/codefarm/     types.hpp（枚举、花费）、world.hpp、interpreter.hpp
  sim/src/                  world.cpp、interpreter.cpp
  tests/                    单元测试、通关测试、范本覆盖
  extension/src/            register.cpp、codefarm_host.cpp
  game/                     Godot 4 工程（主场景 scenes/main.tscn）
    scripts/                见下表
    exemplars/              通关范本
    fonts/                  Noto Sans CJK SC、JetBrains Mono、Droid Sans Fallback
    themes/ bin/ scenes/
  third_party/godot-cpp     Godot 4.7 C++ 绑定（源码包默认不带，本地构建需要）
  tools/                    官方 Godot 4.7.2 编辑器（本机构建用，可不入库）
```

### `game/scripts` 职责

| 文件 | 职责 |
| --- | --- |
| `main.gd` | 主场景：3D 农场、相机、顶栏、代码窗、技能树、提示、设置、运行控制、更新日志。文件**最顶部**的 `preload` 不能删（Windows 类缓存依赖它）。 |
| `skill_data.gd` | 技能树节点、连线、痛点文案、范本读取。 |
| `farm_window.gd` | 可拖动、缩放、最小化的浮窗。**缩放手柄必须是 `body` 的子节点**，不能直接挂在 `PanelContainer` 上，否则整窗都会变成缩放热区并留下色块。 |
| `farm_run_button.gd` | 实心三角「运行一遍」、空心三角「单步」。 |
| `farm_chrome_button.gd` | 窗口 ─ ☐ ✕。 |
| `farm_icons.gd` | 面性 / 半面性图标绘制。 |
| `farm_motion.gd` | 开合与悬停动效。 |
| `error_markup.gd` | 行内错误气泡和波浪线。 |
| `highlight_overlay.gd` | 当前执行行的细高亮。 |
| `verify_headless.gd` | 无显示器冒烟，成功打印 `VERIFY_OK`。 |
| `verify_smoke.gd` | 有画面的验收（需 Xvfb 或显示器），成功打印 `SMOKE_OK`。 |

## 技能树 / 课程表

下表是第 1 级花费和「痛 / 药」。加速、扩田、作物等还可以继续升级，完整阶梯见 `sim/include/codefarm/types.hpp`。更细的机制和原作对照见 [skill-tree-design.md](skill-tree-design.md)、[playthrough.md](playthrough.md)、[research/UNLOCK-CURRICULUM.md](research/UNLOCK-CURRICULUM.md)。

「成本」随胡萝卜一起获得，不必单独购买。

| id | 名称 | 第 1 级花费 | 痛点 | 药 |
| --- | --- | --- | --- | --- |
| harvest | 收获 | 开局已有 | 每点一次运行，bot 只收一刀 | `harvest()` |
| loop | 循环 | 5 干草 | 每收一刀都要再点运行 | `while` |
| hats | 帽子 | 50 干草 | 想给 bot 换个样子 | `change_hat` |
| speed | 加速 | 8 干草 | 一刀要 1 秒，动作太慢 | 动作变快（生长不变） |
| iff | 条件 | 12 干草 | 加速后盲收反复打断幼苗生长 | `if (can_harvest())` |
| move | 移动 | 20 干草 | 再好的程序也只有一格田 | `move`，田变为 3×3 |
| forl | 计数 | 30 干草 | 绕一圈要把 `move` 抄很多遍 | `for` |
| expand | 扩田 | 40 木头 | 田变大后，写死边长会走歪 | `get_world_size()` |
| till | 耕地 | 40 干草 | 地只会自己长草，没法改 | `till()` |
| vars | 变量 | 70 干草 | `for` 的 `i` 不能拿来判断 | `int` / 表达式里用 `i` |
| plant | 种植 | 60 干草 | 翻好的土是空的 | `plant(Bush)` |
| swenum | 分支 | 25 胡萝卜 | 转向写成一串 `if` | `switch` |
| constn | 常量 | 15 木头 | 边长 3 写死在循环里 | `const` |
| ops | 运算 | 30 干草 + 20 木头 | 只有 `==` `!=` | 取模与逻辑运算 |
| senses | 感知 | 40 木头 | 绕过边缘后不知道自己在哪一列 | `get_pos_x()` / `get_pos_y()` |
| hayup | 草产 | 100 干草 | 每刀只出 1 份干草 | 产量升级 |
| carrot | 胡萝卜 | 50 木头 | 后面的技能要胡萝卜 | `Carrot`（只花干草） |
| func | 函数 | 40 胡萝卜 | 照料一格的代码挤在 `main` 里 | 函数 |
| costs | 成本 | 随胡萝卜赠送 | 种植费会随升级变化 | `get_cost` |
| water | 浇水 | 50 木头 | 胡萝卜长得慢，绕一圈还没熟 | `use_item(Water)` |
| tree | 树木 | 50 木头 + 40 胡萝卜 | 灌木一次只出 1 根木头 | `Tree` |
| ref | 引用 | 30 胡萝卜 | 函数没法把计数带回 `main` | `int&` |
| include | 分文件 | 80 胡萝卜 | 工具函数无处安放 | `#include` |
| sun | 向日葵 | 80 胡萝卜 | 需要一种能攒起来的速度 | `measure()` |
| fert | 肥料 | 80 木头 | 迷宫要奇怪物质 | `Fertilizer` |
| debug | 调试 | 20 干草 + 20 木头 | 看不见库存怎么变 | `print` / `quick_print` |
| array | 数组 | 60 胡萝卜 | 每收一株都要重新绕场量花瓣 | 数组 |
| pumpkin | 南瓜 | 80 木头 + 40 胡萝卜 | 需要更划算的整片作物 | 南瓜（整块 `n³`） |
| maze | 迷宫 | 80 怪异物质 | 后面的节点要金子 | `can_move` / 迷宫 |
| timing | 计时 | 30 南瓜 | 没法比较两版代码用了多久 | `get_time()` |
| rec | 结构体 | 40 胡萝卜 | 函数只能返回一个数 | `struct` |
| util | 工具 | 40 南瓜 | 手写找最大值又长又容易错 | `min` / `max` |
| cactus | 仙人掌 | 120 南瓜 | 乱摆的仙人掌一株只值 1 | `swap` / 排序后 `n²` |
| debug2 | 实验 | 80 金子 | 在大田上试一次要等很久 | `set_world_size` |
| autounlock | 自动 | 150 南瓜 | 技能还得手动点 | `unlock()` |
| companion | 伴侣 | 80 南瓜 | 同样的田，产量到顶了 | `get_companion()` |
| dino | 恐龙 | 120 仙人掌 | 伴侣升级要骨头 | 恐龙帽 |
| mega | 多机 | 120 金子 | 一架无人机绕一圈太慢 | `spawn_drone` |
| sim | 模拟 | 200 金子 | 每次重跑作物长得不一样 | `simulate(种子)` |

通关测试从全新存档出发，只用玩家能做的操作（按余额购买、放入范本、点运行、快进），不调用 `grant_for_test` 等测试后门。路线、逐档用时和相邻范本的差异见 [playthrough.md](playthrough.md)。

## 构建、运行、测试

模拟器和单元测试不依赖 Godot。打开游戏需要先编出 GDExtension。

### Linux

```bash
# 只编测试（推荐日常）
cmake -S . -B build-tests -G Ninja -DCODEFARM_BUILD_EXTENSION=OFF
cmake --build build-tests
./build-tests/codefarm_tests          # 必须全绿（含通关与范本覆盖）
./build-tests/codefarm_playthrough    # 打印逐档路线和用时

# 编 GDExtension，so 放到 game/bin/
cmake -S . -B build -G Ninja -DCODEFARM_BUILD_EXTENSION=ON
cmake --build build

# 无头验收，应打印 VERIFY_OK
./tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script scripts/verify_headless.gd

# 有画面的验收（无显示器时加 Xvfb），应打印 SMOKE_OK
xvfb-run -a -s "-screen 0 1440x900x24" ./tools/Godot_v4.7.2-stable_linux.x86_64 --path game --script scripts/verify_smoke.gd
```

本机若还没有编辑器，从 [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) 下载官方包，用 **4.7.x** 打开 `game/`。仓库里的官方 Linux 二进制在 `tools/Godot_v4.7.2-stable_linux.x86_64`。

### Windows（笔记本 `D:\桌面\codefarm`）

CMake 在 `D:\bin\win64\cmake\bin`，编译器用 `D:\mingw64`，Ninja 增量编到 `D:\桌面\codefarm\build-win`。PowerShell 里不要写 `\"`，改用 `cmd.exe /c '...'`：

```bat
cmd.exe /c "set PATH=D:\mingw64\bin;D:\bin\win64\cmake\bin;%PATH% && cd /d D:\桌面\codefarm\build-win && cmake --build ."
```

首次配置（若还没有 build-win）：

```bat
cmd.exe /c "set PATH=D:\mingw64\bin;D:\bin\win64\cmake\bin;%PATH% && cd /d D:\桌面\codefarm && cmake -S . -B build-win -G Ninja -DCODEFARM_BUILD_EXTENSION=ON"
```

编完后，把 `codefarm.windows.template_debug.x86_64.dll` 以及 MinGW 运行库 `libgcc_s_seh-1.dll`、`libstdc++-6.dll`、`libwinpthread-1.dll` 放到 `game\bin`。

**必须完全退出 Godot，再重新打开 `D:\桌面\codefarm\game`。** 不要强杀 Godot，也不要用还开着的旧窗口预览。扩展更新后必须重新加载。

从项目根运行测试（0.2.3 起应能找到范本）：

```bat
cmd.exe /c "set PATH=D:\mingw64\bin;%PATH% && cd /d D:\桌面\codefarm && build-win\codefarm_tests.exe"
```

### 必须保持全绿的测试

- `codefarm_tests`：单元测试（Linux 上 0.2.2 为 1167 项，0.2.3 不应减少）。其中包含：
  - `test_full_playthrough`：从新存档按课程表通关，全程不用测试后门。
  - `test_every_node_has_exemplar`：每个节点都有能解析、能运行的范本。
- 修改范本后，通关测试必须仍然通过。
- `VERIFY_OK`、`SMOKE_OK`。

## 畅的偏好和约定

这些是项目的硬约定，改代码或写界面时不要走样。

- **玩家代码**必须是标准 C++ 形态：`#include <bits/stdc++.h>`、`using namespace std;`、`int main()`。
- **版本号**为「大.小.补丁」。小改（修 bug、文档、小交互）升补丁；大内容或整块新系统升次版本。改动要写进三处更新日志：根目录 `CHANGELOG.md`、`game/changelog.md`、`game/scripts/main.gd` 里的 `CHANGELOG_TEXT`，并同步 `VERSION`、`game/project.godot` 的 `config/version`、`main.gd` 的 `VERSION`。
- **UI** 苛求设计感：图标加一个词，少文字，不堆说明。顶栏图标按钮接近正方形（约 36×36，圆角约 6），图标居中；文字按钮不必改成正方形。
- **字体：** 系统界面用 Noto Sans CJK SC（SIL OFL，做了加大和更柔和的字重 / 行距）；代码区用可缩放的 JetBrains Mono 20px。回退字体是 Droid Sans Fallback。
- **伙伴形象：** 奶黄球形豆子身体 + 固定黑色竖条眼（不眨眼），无屏幕脸，无脚下圆环。田下不要做成带清晰圆边的正圆岛屿。
- **视角：** 左键在地面按住拖动平移，地面跟着手走，松手后有一点惯性；约 6 像素以内仍算点击。左键点在窗口和按钮上只操作界面，不带动地图。右键转视角（1:1，不插值滞后），滚轮朝光标缩放，WASD 移动（松开即停），空格 / Shift 升降，F 回正。中键或 Shift+右键也能平移。技能树空白处（以及从节点上开始）同样可以左键拖动画布，手感与地图一致；打开的技能详情不会被拖走，技能树打开时不会拖动地图。
- **运行：** 实心三角把 `main` 跑完即停，空心三角单步，点进编辑器即停。程序停止后草地仍继续生长。不再自动反复执行 `main`。加速只缩短动作，不缩短生长。失败收割和成功收割均花 action_ticks()；未成熟草在收割开始时重置为 400 tick 幼苗，动作期间正常生长。查询为 1 tick，不重置生长。开局收割与生长都是 400 tick（1 秒）。
- **范本**一步只多一个新概念，测试和游戏读同一份文件。
- **未经畅认可，不上传 GitHub，也不要自行 `git init`。**
- 不要碰 `D:\桌面\一些重要的密码agent勿碰`。不要把测试后门（`grant_for_test` 等）当成玩法。

## 已知问题与待办

- **无尽 / 优化挑战：** 只有计划，见 [endless-design.md](endless-design.md)。主线通关后要用同一套模拟器给固定挑战打分（tick、代码量、动作数），并和范本基准以及个人最好成绩对比。这一轮按畅的要求先只写计划。
- **[research/NEXT-PASSES.md](research/NEXT-PASSES.md)** 是 0.2.0 施工前的落地顺序。P0–P6 的主线机制已在 0.2.0–0.2.1 落地，通关与范本已在 0.2.2 落地。里面还没做成产品的主要是：无尽挑战 / 排行榜、隐藏成就（可不做墙）、DLC 采矿 / 水稻 / 竹子（只留接口，不挡主线）。
- **Windows 测试找不到范本：** 0.2.2 在 `D:\桌面\codefarm` 运行 `build-win\codefarm_tests.exe` 时，CMake 把带「桌面」的绝对路径写进窄字符宏，MinGW 的 `ifstream` / `opendir` 按系统代码页打开就会全部报 missing exemplar。0.2.3 改为 UTF-8 字节数组 + 宽字符 / `std::filesystem` 打开，并在编译期路径失效时从当前目录或可执行文件位置向上查找仓库根。这不是绕过检查，范本仍然要能解析、能跑。
- 玩家语言仍是逐步解锁的 C++ 子集，不是完整编译器。解释器按 tick 预算推进，避免死循环卡死进程。
- GDExtension 目前编了 Linux 和 Windows 的 `template_debug`。若在 macOS 上打开工程，需要在对应平台重编，否则会因缺少 `CodefarmHost` 无法加载。
- 同步到笔记本时：先拷到 `C:\Users\machang\agent-tools\`，再覆盖进 `D:\桌面\codefarm`，保留 `fonts`、`third_party`、`.godot`、`build-win`。大文件可拆成 3MB 分块，在 Windows 上用 `copy /b` 合并并核对 SHA256。

## 协作方式

**唯一标准仓库是 `D:\桌面\codefarm`。** 开工前先读那里的 `VERSION` 和最新更新日志，并对齐工作副本。详细约定见 [SOURCE.md](SOURCE.md)。

从现在起，写代码、改代码一律交给 **Codex CLI**（笔记本与云电脑均已用 ChatGPT 登录）。Codex Bot 负责派活、监督、验收测试、把结果写回桌面，并向畅汇报。若 OpenAI 被挡，停下来说明，不要换成别的方式交差，也不要另开一份长期分叉的工程。

学习计划交给「学习管家」，实验报告草稿交给「作业报告 Bot」，仓库改动或推送交给「GitHub Bot」（推送仍要等畅同意）。需要跨助手转手时走「总管」。

### 交接清单

交给另一位开发者或 Codex CLI 时，请准备：

1. 桌面上的当前版本号，以及要改的是玩法、界面、测试还是文档。先让对方读 [SOURCE.md](SOURCE.md)、本概况和 [AGENTS.md](../AGENTS.md)。
2. 再读 [CHANGELOG.md](../CHANGELOG.md)、[playthrough.md](playthrough.md)，以及最新的 `docs/review-*.md`。
3. 明确「不要做的事」：不覆盖比自己更新的桌面仓库、不 `git init` / 不 push、不碰密码目录、不用测试后门顶替玩法、不改与任务无关的玩法、范本一步一个概念、未经同意不实施无尽模式。
4. 给出复现步骤或失败日志（Windows 命令用 `cmd.exe /c '...'`）。
5. 验收标准：相关测试全绿，三处 changelog 已写，版本号已按时规则 bump。
6. 若改了扩展或 `game/`，提醒畅先完全退出 Godot 再打开；Godot 开着时不要覆盖脚本、场景或 DLL。
7. 同步时只传改动，保留 `fonts` / `third_party` / `.godot` / `build-win`。
