# Codefarm 唯一标准

所有一起开发的人（Codex Bot、Codex CLI、其他 Bot）开工前先读这份，再读 [PROJECT-OVERVIEW.md](PROJECT-OVERVIEW.md) 和仓库根目录的 [AGENTS.md](../AGENTS.md)。

## 权威仓库

**唯一标准版本在笔记本 `D:\桌面\codefarm`。** 以这里的 `VERSION` 文件为准。

- 云电脑上的 `/workspace/codefarm` 只是工作副本：开工前必须先和桌面对齐；改完必须写回桌面。
- 两边不一致时，**以桌面为准**。禁止用更旧的云端包覆盖桌面。
- `C:\Users\machang\agent-tools\` 只用来传包，不要把它当成第二份主仓库，也不要在别的路径长期改同一份游戏。
- 预览用 Godot 4.7.2 打开桌面上的 `game` 文件夹。必须先完全退出 Godot，再打开；不要强杀进程。Godot 开着时，不要覆盖正在使用的脚本、场景或 DLL。

## 每次改动怎么记

版本号是「大.小.补丁」，写在 `VERSION` 里。小修升补丁，大内容或新系统升第二位。

一次改动必须同时改完下面这些，不要只改一处：

1. `VERSION`
2. `game/project.godot` 里的 `config/version`
3. `game/scripts/main.gd` 里的 `const VERSION`
4. 三处更新日志：`CHANGELOG.md`、`game/changelog.md`、`main.gd` 里的 `CHANGELOG_TEXT`
5. 若 README 写了当前版本，一并改

更新日志要写清楚：改了什么、为什么、怎么验证的。不要写空的「杂项修复」。比较完整的一轮，再在 `docs/review-<版本>.md` 里记下检查结果和没做的事（范例：`review-0.2.4.md`）。

## 统一方向

不要另起一套计划。方向以这些文件为准：

- [PROJECT-OVERVIEW.md](PROJECT-OVERVIEW.md)：定位、架构、偏好、协作
- [playthrough.md](playthrough.md)、[skill-tree-design.md](skill-tree-design.md)：课程、范本、技能顺序
- [endless-design.md](endless-design.md)：无尽 / 优化挑战，目前只有计划，**未经畅同意不要开工**
- 最新的 `docs/review-*.md`：已经发现、尚待处理的问题。0.2.4 里优先考虑的是进度持久化、新技能后的消化与引导、调试教学偏晚、技能连线与真实前置不一致、迷宫长挂机。这些优先于再堆新功能。

设计原则上不要偏离：

- 先痛后药
- 界面化繁为简：图标加一个词，少堆文字
- 范本一步只多一个新概念，游戏和测试读同一份文件
- 玩家写的是标准 C++ 形态：`#include <bits/stdc++.h>`、`using namespace std;`、`int main()`
- 未经畅明确同意，不要 `git init`，也不要上传 GitHub

## 谁来改代码

- **写代码、改代码：一律交给 Codex CLI。** 笔记本和云电脑都已用 ChatGPT 登录。
- **Codex Bot 负责派活、监督、跑验收、把结果同步回桌面，并向畅汇报。** 不要在额度紧的时候自己重写一份，和桌面分叉。
- 任务写明「交给 Codex」时必须走 Codex CLI；若 OpenAI 被挡，停下来说明，不要换成别的方式交差。

## 同步时怎么做

- 先读桌面上的 `VERSION` 和最新 changelog，确认自己没有拿着旧副本在改。
- 往桌面合入改动时，保留 `fonts`、`third_party`、`.godot`、`build-win`，只覆盖真正改过的文件。
- 大文件先放到 `C:\Users\machang\agent-tools\`，必要时拆成 3MB 分块，用 `copy /b` 合并后再核对 SHA256。
- 改了 C++ 模拟器或扩展之后，要在笔记本用 MinGW 重编 DLL，并把运行库拷进 `game\bin`。只改 GDScript 或文档时，不要无故重编。
