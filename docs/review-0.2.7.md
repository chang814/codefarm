# 0.2.7 幼苗重置与条件教学验收

日期：2026-11-11。当前 Codex CLI 会话直接在唯一标准仓库 `D:\桌面\codefarm` 实现。开工版本为 0.2.6，已同步 VERSION、project.godot、main.gd、README、AGENTS 和三处更新日志至 0.2.7。

## 规则与实现

- `World::try_harvest()` 仅对 `EntityType::Grass && !tile.mature` 调用现有 `begin_grass_growth(tile)`：在动作开始时恢复为幼苗，生长剩余及总时长均为 400 tick，不产干草，不产生成功收获事件。
- 每一次收割，无论成功或失败，均花动作开始时的 `action_ticks()`。开局 400 tick，一档加速 200 tick；能量也会缩短挥刀。移除了 0.2.6 的固定 400 tick 失败惩罚；没有使用 1 tick 失败捷径。
- 重置之后立即正常推进世界：一档加速的失败动作花 200 tick，结束后幼苗还剩 200 tick。动作结束不再重置一次。反复盲收会反复打断生长，不能靠两次空挥养熟草。
- `can_harvest()` 和其它查询仍为 1 tick，不重置幼苗；生长基础时长、经济、产量、价格和解锁顺序不变。其它幼年作物不重置生长；空地、篱笆、苹果不因此长出草，枯萎南瓜仍被清除，迷宫误收仍清除迷宫。
- 成功与空挥保持独立反馈，空挥不发奖励、不因后续自然成熟变成成功。两种挥刀动画均随动作速度调整，作物高度继续由模拟器生长状态驱动。

## 提示、范本与恢复路线

加速提示、技能知识和设置速度说明已改为幼苗受损规则。加速提示同时说明恢复办法：停止循环，等熟再单次收割，攒够 12 干草买「条件」；也可以在买加速前预留余额。避免玩家余额不足时只得到“去买条件”的指引。

`game/exemplars/speed.cpp` 与 `iff.cpp` 保持原文件：前者只有 while 收割，后者只在同一个 while 内加 `if (can_harvest())`。游戏和测试仍读同一文件，不在加速节点提前教 if。

真实玩家路线现在先验证盲收停产，再用开局单次收割范本配合普通空闲等待赚取条件费用，随后正常购买并继续主线。此路线没有 `grant_for_test`、`set_item`、强制成熟或直接发资源。

## 验收结果

| 检查 | 结果 |
| --- | --- |
| MinGW 增量构建 | 通过；扩展直接输出到 game/bin |
| 正常入口 codefarm_tests.exe | 1495 项通过，0 失败；包含真实路线与所有范本 |
| codefarm_playthrough.exe | 153 项路线检查通过，45 次购买，3124.48 秒游戏时间 |
| 加速前 while，20 秒采样（排除首刀） | 19 次成功，0 次失败 |
| 加速后 while，20 秒采样（排除首刀） | 0 次成功，39 次失败；持续打断幼苗 |
| 同一个正常获得的世界状态，各运行 30 秒 | 盲收新增 1 干草：1 成功 / 59 失败，前 2 秒之后 0 成功；条件循环新增 30 干草：30 成功 / 0 失败 |
| 解锁门槛 | 购买条件前，单独 can_harvest() 与 if 都被拒绝 |
| 时序与查询 | 起手重置 400，失败挥刀 200 后剩 200；查询 1 tick 且不重置；成功与失败均按 action_ticks，包含能量 |
| 其它作物与相邻格 | 非草幼苗保持实体及生长计时；枯萎南瓜清除；相邻格不受本次草重置影响 |
| Godot 核心 | VERIFY_OK |
| Godot Vulkan 真实渲染 | UI_MOTION_OK、SMOKE_OK、SKILL_DRAG_OK、EDITOR_OK |
| Godot smoke 新增回归 | 加速后连续 20 秒新增 0 干草；停止、等熟单收后正常购买条件；条件循环 30 秒新增 30 干草 |

Godot 为本机 `D:\桌面\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`，版本 `4.7.2.stable.official.ed1daf0bf`。核心检查使用 headless，其余使用 Windows Vulkan / Forward+ 与实际渲染。UI 脚本注入鼠标事件、触发真实按钮信号并检查场景状态，不代表人工试玩。

原始结果：`build-win/build-027.txt`、`build-win/tests-027.txt`、`build-win/playthrough-027.txt`。Godot 日志：`C:\Users\machang\agent-tools\codefarm-027\verify_*.log`。截图包括 [默认界面](../shots/ui-027-default.png)、[空挥](../shots/ui-027-miss.png)、[设置](../shots/ui-027-settings.png)、[最大化中间帧](../shots/ui-027-max-mid.png)。

## DLL 与运行库

构建与复制之前已确认 Godot 完全退出；没有强杀 Godot。扩展由 CMake 直接重编进 `game/bin`。三个运行库已从 `D:\mingw64\bin` 复制到 `game/bin`，逐项核对源与目标 SHA256 一致。

| game/bin 文件 | SHA256 |
| --- | --- |
| codefarm.windows.template_debug.x86_64.dll | 15617AACDF09C3F9F143FB3542998608D35AA85371F88BFF36A12D8DBF67910D |
| libgcc_s_seh-1.dll | 9E48A39710D35D506EDCB0B12707872416AE8FD2ED8E92088EEF0C5C2375A264 |
| libstdc++-6.dll | 497687DEB0F1D5FD7AAC7F42FB37E30E5B826BE7EA9313B6ECF73740E3108A84 |
| libwinpthread-1.dll | 55774E39FDA420143EA05738F4FC22A3142E35D3CA65ED1C81CEA26D1BB670AF |

## 复验命令

先完全退出 Godot，再构建；不要在旧编辑器中依赖 DLL 热重载。

```powershell
cmd.exe /c 'set PATH=D:\mingw64\bin;D:\bin\win64\cmake\bin;%PATH% && cd /d D:\桌面\codefarm\build-win && cmake --build . -j 8'
cmd.exe /c 'set PATH=D:\mingw64\bin;%PATH% && cd /d D:\桌面\codefarm && build-win\codefarm_tests.exe'
cmd.exe /c 'set PATH=D:\mingw64\bin;%PATH% && cd /d D:\桌面\codefarm && build-win\codefarm_playthrough.exe'
$godotExe = 'D:\桌面\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path game --script scripts/verify_headless.gd
foreach ($name in 'verify_ui_motion','verify_smoke','verify_skill_drag','verify_editor') {
    & $godotExe --path game --script ('scripts/' + $name + '.gd')
    if ($LASTEXITCODE -ne 0) { throw ($name + ' failed') }
}
```

## 边界

本次只调整幼苗误收、收割耗时、相关反馈、提示和回归验证；未实施无尽模式、持久化或经济重平衡。未 git init、提交或 push，未创建另一棵长期工作树，未访问禁止目录。既有单元测试与 smoke 的后期场景夹具仍与真实玩家路线分开，不用它们替代通关。

0.2.6 的固定失败 400 tick、盲收 20 / 条件 30 只保留在历史更新日志与旧评审中，当前玩法以本评审为准。自动验收覆盖固定种子和此台 Windows 电脑；真人学习体验、多种子、长时间运行、其它平台未在本轮验证。构建仍提示既有未使用函数/变量和成员初始化顺序警告。
