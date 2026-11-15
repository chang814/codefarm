# 0.2.6 收获节奏与窗口交互验收

日期：2026-11-11。直接修改唯一标准仓库 `<本机仓库>`，由当前 Codex CLI 会话实现。版本与三处更新日志均同步至 0.2.6。

## 改了什么

- 成功收获继续使用 `action_ticks()`；所有失败收获固定花 `kBaseActionTicks = 400`，不受加速和能量影响。查询仍为 1 tick，草仍长 400 tick，价格、产量和解锁顺序未调整。
- 加速后，盲收约为成功 200 + 失败 400 tick 一棵；条件循环用廉价查询等成熟，约 400 tick 一棵。加速提示立即说明挥空代价并指向「条件」与 `can_harvest()`。`speed.cpp` 与 `iff.cpp` 原本已满足一步一个概念，保留原文件，游戏和通关读取同一份。
- 失败由动作开始时的独立信号驱动横扫动画，不裁切植物、不掉奖励。即使失败期间草成熟，也不补播成功动画。收获动作共用可中断时间线，旧回调不会覆盖新姿态。
- 最大化的瞬移来自提示窗避让调用立即设置矩形、取消刚启动的动画。改为先计算避让，再以中心和尺寸同步插值，300ms 平滑过渡；修复快速反向、最小化转最大化、关闭重开、屏幕尺寸变化与还原矩形丢失。
- 弹层关闭中改变窗口尺寸不再留下拦截点击的遮罩；技能解锁的延迟回调只刷新原来的树，不再重建后来打开的树、清掉滚动位置。选项和复制反馈可中断旧动画。
- 完整范本改为替换主程序，并载入配套头文件，按钮提示明确写出替换；不再把第二个 `main` 插进正文。重置会清空分文件、恢复主文件框架保护，并还原浮窗状态。
- 保留暖色鼠尾草绿、Noto Sans CJK SC、默认 20px JetBrains Mono 和现有 HUD；只参考畅记的克制反馈与连续操作方式。

## 自动验收结果

| 检查 | 结果 |
| --- | --- |
| Windows 正常构建入口 `build-win/codefarm_tests.exe` | 1196 通过，0 失败；包含完整玩家路线和全部范本 |
| `codefarm_playthrough.exe` | 147 项路线检查，45 次购买，3112.74 秒游戏时间 |
| 条件教学的同预算对比 | 复制正常游玩获得的同一个世界状态，各运行 30 秒：盲收 20 干草，条件循环 30 干草，提升 50% |
| 解锁门槛 | 购买条件前，单独调用 can_harvest 和使用 if 均被拒绝 |
| 收获事件与时序 | 加速、能量下失败固定 400；成功仍加速；查询 1；生长 400；失败中成熟不发成功脉冲 |
| 从仓库外运行测试 | 在 `<中转目录>` 启动同一测试 EXE，也全部通过 |
| Godot 核心 | `VERIFY_OK` |
| Godot 真实 Vulkan 渲染 | `UI_MOTION_OK`、`SMOKE_OK`、`SKILL_DRAG_OK`、`EDITOR_OK` |

Godot 使用本机 `<Godot 目录>\Godot_v4.7.2-stable_win64_console.exe`，版本 `4.7.2.stable.official.ed1daf0bf`。无头仅用于核心检查，界面检查使用 Windows Vulkan / Forward+ 实际渲染。

### 按钮与交互覆盖

以下为脚本注入鼠标事件、触发实际按钮信号或调用检查入口的自动验收，不是人工逐项手点。

| 对象 | 覆盖方式与结果 |
| --- | --- |
| 顶栏：代码、技能树、提示、设置、日志、回正 | 鼠标点击各按钮；打开、关闭、重开与相机回正通过。弹层打开时通过面板内页签切换，遮罩保留输入隔离 |
| 代码窗与提示窗：最小化、最大化/还原、关闭 | 鼠标点击通过；另测快速反向、最小化→最大化→还原、已最大化提示窗的暂存与恢复 |
| 窗口标题与缩放角 | 注入拖动；最大化还原后仍可移动与缩放，松手清理状态；中间帧连续，终点尊重顶栏和提示窗 |
| 实心运行与空心单步 | 实际按钮信号；main 跑完即停、运行中再次按下停止、每次单步只做一个动作；点击编辑器停止由 smoke 验证 |
| 技能购买、详情、复制、载入、关闭 | 前期用正常收获赚取资源后点击购买；复制等于共享范本，载入后只有一个完整主程序；头文件载入与复制由 smoke 的隔离 UI 场景验证 |
| 技能树拖动画布 | 双轴、节点起拖不误购、微小移动仍点击、详情不拖背景、区域外松手和失焦恢复通过 |
| 设置与面板选项 | 16/18/20 字号按钮、滑动底板、技能/设置/日志页签快速切换、重置确认/取消通过；重置时模拟旧头文件处于活动状态 |
| 提示范本 | 鼠标折叠/展开、主程序复制、连续复制反馈通过；配套头文件复制信号也验证为同源文本 |
| 编辑器 | 默认框架保护、正文撤销、辅助函数和头文件编辑、行列报错与独立高亮由 editor 检查通过 |

## 构建与复验

```powershell
cmd.exe /c 'set PATH=<MinGW>\bin;<CMake>\bin;%PATH% && cd /d <本机仓库>\build-win && cmake --build . -j 8'
cmd.exe /c 'set PATH=<MinGW>\bin;%PATH% && cd /d <本机仓库> && build-win\codefarm_tests.exe'
cmd.exe /c 'set PATH=<MinGW>\bin;%PATH% && cd /d <本机仓库> && build-win\codefarm_playthrough.exe'
$godotExe = '<Godot 目录>\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path game --script scripts/verify_headless.gd
foreach ($name in 'verify_ui_motion','verify_smoke','verify_skill_drag','verify_editor') {
    & $godotExe --path game --script ('scripts/' + $name + '.gd')
}
```

CMake 直接把新扩展 DLL 输出到 `game/bin`。构建前确认 Godot 已完全退出；三个 MinGW 运行库也已复制进该目录，并与 `<MinGW>\bin` 的 SHA256 逐项核对一致。扩展 DLL SHA256：`F2645CE87F9B22BB26B11AD4C1027A39C4B3658649242640600BFAFD6DA2D6D6`。

Windows 中文路径问题从正常构建入口修复：CMake 生成 UTF-8 字节数组，测试用宽字符路径/API 打开文件，并可从工作目录或 EXE 回溯源码根目录。本次没有跳过范本或使用旧的 audit EXE。

原始测试记录在 `build-win/tests-026.txt`、`build-win/playthrough-026.txt`；Godot 日志在 `<中转目录>\codefarm-026/verify_*.log`。截图：修改前 ui-026-before（`shots/ui-026-before.png`，本机记录，未入库），修改后 默认界面（`shots/ui-026-default.png`，本机记录，未入库）、最大化中间帧（`shots/ui-026-max-mid.png`，本机记录，未入库）、最大化终点（`shots/ui-026-max.png`，本机记录，未入库）、挥空（`shots/ui-026-miss.png`，本机记录，未入库）、设置（`shots/ui-026-settings.png`，本机记录，未入库）。

## 未做与边界

没有实施无尽模式、存档持久化或经济重平衡，没有 git init、提交或上传。真实玩家路线完全不用加资源/直接解锁后门；既有 smoke 的后期作物和多文件检查继续使用隔离测试夹具，不将它算作通关。当前结果代表此台 Windows 电脑、固定路线和种子；真人学习体验、多随机种子、长期迷宫挂机及跨机器表现未验收。构建仍有既有的未使用变量/函数与成员初始化顺序警告。
