# 0.2.8 技能树、提示与圆形伙伴验收

日期：2026-11-11。本轮 Codex CLI 直接在唯一标准仓库 `<本机仓库>` 完成，按 `<中转目录>\codex-0.2.8-brief.md` 实施。开工为 0.2.7，交付为 **0.2.8**。已同步 VERSION、project.godot、main.gd、README、AGENTS、项目概况和三处更新日志。

## 实现

### 技能树

- 保留原有暖色、鼠尾草绿、图标和短词，没有更换整页视觉风格。39 个节点组织为 7 列，中央主干从收获向下依次经过循环、加速、条件、移动、耕地、种植、感知、胡萝卜、函数、数组、南瓜、仙人掌、恐龙；其余节点就近分支。
- 画布为 1028×2048，节点统一 100×120px，列距与行距均为 144px。双资源价格分行，不再撑大卡片；不足提示使用独立覆盖层。悬停只改变底色，选中改变边框，不缩放节点，连线接头保持稳定。
- 将交叉的跨层依赖网整理为 38 条主要学习路径；**连线不代表全部购买前置**。树木、函数、仙人掌、多机等组合前置，以及计时、实验、模拟等替代前置，明确写在节点提示中；购买仍完全使用模拟器的真实判定。顶部标为「学习路线」，相关说明已同步到 skill-tree-design.md。
- 金色表示已解锁，鼠尾草绿边框表示可买，灰色表示待解锁。保留节点购买、升级、详情与不足反馈。
- 左拖保持 6px 点击/拖动分界，节点上也能起拖；松手指数衰减，短暂滑行。滚轮以光标所在画布位置为中心缩放，新增「全貌」「还原」。缩小时画布居中；购买重建和设置往返保留视图。详情窗不随画布缩放、拖动，技能树操作不移动农场相机。

### 提示

- 先显示短痛点，再突出这次用到的一行代码；完整范本与头文件放在可折叠区域中。代码重点从共享范本提取，条件的三行块只合并排版为 `if (can_harvest()) harvest();`，没有另造展示程序。
- 加速提示直接显示「小草没熟就被割掉，连续挥空没干草」，并注明买「条件」后，在已有 while 中加入上述条件行。另给一条恢复办法：停循环，等熟单收，攒 12 干草买条件。
- 加速的完整范本仍是原有 while 收割，不提前加入锁定的 if。条件的完整范本仍只在原有循环里增加成熟判断。`game/exemplars/` 没有修改。
- 「复制」复制共享原文件全文；「载入」替换 main.cpp，并载入配套头文件。两者有可见的简短说明及 tooltip，避免把第二个 main 插进现有程序。提示窗与技能详情共用同一套载入逻辑。
- 移除 main.gd 中旧的完整范本回退副本，所有范本只读共享文件。Noto Sans CJK SC 与默认 20px JetBrains Mono 保留。

### 小 bot

- 身体由半径 0.130、高 0.36 的长胶囊改为半径 0.15、高 0.30 的球体，正面为圆形。保留奶黄磨砂材质，移除身体中段色带，不增加屏幕、额外五官或脚下环。
- 两只眼睛为纯黑圆角竖条，直接固定在身体 rig 上。删除眨眼计时器和 `_blink_eyes()`；没有眼睛转动、位移或缩放动画。收割、除草和移动仍可运动身体及手臂，眼睛自身形状与相对位置不变。
- 主机与额外机体调用同一个 `_make_bot_rig()`，共用球形身体、固定眼睛、手臂和完整锄头，颜色统一为奶黄。
- 手臂与锄头位置随新球体协调，锄柄适当缩短。站立基准为田面上方 0.18，球体底部约离田面 0.02；闲置起伏缩至 0.012，避免原先较明显的悬浮间隙。

## 验收结果

Godot 使用 brief 指定的本机 `Godot_v4.7.2-stable_win64_console.exe`，版本 `4.7.2.stable.official.ed1daf0bf`。核心检查使用 headless，其余五个脚本使用 Windows Vulkan / Forward+ 实际渲染，显卡为 RTX 5090 Laptop GPU。最终一轮依次运行，全部退出码为 0，日志无 ERROR / SCRIPT ERROR。

| 检查 | 结果与日志 |
| --- | --- |
| verify_headless.gd | VERIFY_OK；日志（`build-win/verify_headless-028.log`，本机记录，未入库） |
| verify_ui_motion.gd | UI_MOTION_OK；日志（`build-win/verify_ui_motion-028.log`，本机记录，未入库） |
| verify_smoke.gd | SMOKE_OK；日志（`build-win/verify_smoke-028.log`，本机记录，未入库） |
| verify_skill_drag.gd | SKILL_DRAG_OK；日志（`build-win/verify_skill_drag-028.log`，本机记录，未入库） |
| verify_editor.gd | EDITOR_OK；日志（`build-win/verify_editor-028.log`，本机记录，未入库） |
| verify_028.gd，新增专项 | REFINE_028_OK；日志（`build-win/verify_028.log`，本机记录，未入库） |
| 既有 codefarm_tests.exe | 1495 项通过，0 失败；输出（`build-win/tests-028.txt`，本机记录，未入库） |
| 既有 codefarm_playthrough.exe | 153 项检查通过，45 次购买，3124.48 秒游戏时间；输出（`build-win/playthrough-028.txt`，本机记录，未入库） |

拖动回归新增覆盖真实跨帧松手后的惯性、短时间收敛、滚轮光标锚定、农场相机不变、全貌显示最后一行、详情拦截背景缩放。原有双轴拖动、可买节点起拖不误购、微移点击、详情点击、区域外松手和失焦恢复检查保留。

0.2.8 专项覆盖全部节点不重叠且尺寸一致、每项技能都有代码重点、组合与替代前置可辨、提示仍读共享完整范本、复制全文、载入只有一个 main、视图重建/设置往返不跳位，以及 1280×800、1200×740 下全貌可容纳最后一行。使用正常收割与购买走到加速、条件，没有用测试资源后门推进这条路线。

伙伴专项验证主机与额外机体均为真球体、共用奶黄色材质；在成功收割、失败横扫、耕地和连续移动动画帧中，眼睛节点的局部 transform 与眼睛网格 transform 始终不变。额外机体在此专项中仅作为造型夹具创建，不作为通关证明。

### 0.2.7 教学未退化

真实玩家路线和 Godot smoke 均复跑通过：

- 加速前 while 采样：19 次成功，0 次失败。
- 加速后 while 采样：0 次成功，39 次失败；smoke 连续盲收 20 秒新增 0 干草。
- 同起点 30 秒盲收仅新增 1 干草，开头后持续停产；条件循环恢复约 30 干草，smoke 为 30 秒新增 30 干草。
- 停止盲收、等待成熟再单次收割，可以正常攒够费用购买条件。
- if 和 can_harvest() 在购买条件前仍被拒绝；所有挥刀按 action_ticks()，草生长和幼苗重置仍为 400 tick，查询仍为 1 tick。

本轮未改 C++，按 brief **没有重新构建或复制 DLL**；额外运行了现有两个测试程序。扩展 SHA256 仍为 `15617AACDF09C3F9F143FB3542998608D35AA85371F88BFF36A12D8DBF67910D`，与 0.2.7 交付一致。

另外完成了 UTF-8、版本一致性、三处日志和截图文件核对；修正了开发过程中 PowerShell 管道导致的新文案编码问题，最终无问号替代或 Unicode 替换字符。Impeccable 机械扫描返回 `[]`；GDScript 的实际解析与行为以 Godot 验收为准。

## 截图

| 内容 | 路径 |
| --- | --- |
| 技能树全貌，100% 可读长图 | ui-028-skills-full.png（`shots/ui-028-skills-full.png`，本机记录，未入库） |
| 常规窗口全貌 | ui-028-skills-overview.png（`shots/ui-028-skills-overview.png`，本机记录，未入库） |
| 1280×800 技能树全貌 | ui-028-skills-1280.png（`shots/ui-028-skills-1280.png`，本机记录，未入库） |
| 常规大小的技能树 | ui-028-skills.png（`shots/ui-028-skills.png`，本机记录，未入库） |
| 默认提示窗中的加速重点 | ui-028-hint-default.png（`shots/ui-028-hint-default.png`，本机记录，未入库） |
| 加速提示与完整范本区域 | ui-028-hint-speed.png（`shots/ui-028-hint-speed.png`，本机记录，未入库） |
| 条件提示、代码重点和载入说明 | ui-028-hint-condition.png（`shots/ui-028-hint-condition.png`，本机记录，未入库） |
| 圆形 bot 正面、固定竖眼 | ui-028-bot-front.png（`shots/ui-028-bot-front.png`，本机记录，未入库） |
| 失败横扫中的固定眼睛 | ui-028-bot-miss.png（`shots/ui-028-bot-miss.png`，本机记录，未入库） |

全貌长图为专项脚本在 1440×2300 渲染视口中展开面板后，按实际 100% 节点尺寸捕获；不是普通 900px 高窗口的默认布局。常规全貌图使用实际「全貌」功能，缩小后的文字主要用于定位，滚轮放大后阅读。正面图直接对准当前 bot，临时隐藏植物以清楚展示圆形轮廓；没有修改游戏默认镜头或删除作物。

旧 smoke 的通用截图也随本轮验收刷新；本轮版本专属证据以上述 `ui-028-*` 文件为准。

## 复验命令

先确认用户的 Godot 已完全退出；不要强杀。以下命令从唯一标准仓库运行，日志均在仓库内。

```powershell
$godotExe = '<Godot 目录>\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path game --script scripts/verify_headless.gd --log-file 'D:/桌面/codefarm/build-win/verify_headless-028.log'
foreach ($name in 'verify_ui_motion','verify_smoke','verify_skill_drag','verify_editor','verify_028') {
    & $godotExe --path game --script ('scripts/' + $name + '.gd')
    if ($LASTEXITCODE -ne 0) { throw ($name + ' failed') }
}
cmd.exe /c 'set PATH=<MinGW>\bin;%PATH% && build-win\codefarm_tests.exe'
cmd.exe /c 'set PATH=<MinGW>\bin;%PATH% && build-win\codefarm_playthrough.exe'
```

## 未做事项与边界

没有实施无尽模式、进度持久化、新作物或新经济系统；没有改变收割时序、产量、价格和技能解锁判定。没有 git init、提交、push 或上传，没有创建第二份长期工作树；未访问禁止目录。除读取给定 brief 与技能说明、运行给定工具外，任务文件仅在 `-C` 指定仓库内写入。

开工及每轮验证前确认没有用户已打开的 Godot，测试进程均自行正常退出，没有强杀。交付时没有遗留 Godot 进程。验证为本机自动交互、渲染检查和已有固定路线；真人学习体验、跨平台与长期运行不在本轮验证范围内。按 brief，本评审写完即停止。
