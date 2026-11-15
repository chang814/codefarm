extends Node3D
const FarmIcon := preload("res://scripts/farm_icons.gd")
const FarmWindow := preload("res://scripts/farm_window.gd")
const FarmRunButton := preload("res://scripts/farm_run_button.gd")
const FarmChromeButton := preload("res://scripts/farm_chrome_button.gd")
const FarmErrorMarkup := preload("res://scripts/error_markup.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")
const FarmSkillData := preload("res://scripts/skill_data.gd")
const FarmSave := preload("res://scripts/farm_save.gd")
const FarmAudio := preload("res://scripts/farm_audio.gd")
const FarmScenery := preload("res://scripts/farm_scenery.gd")
const FarmLayout := preload("res://scripts/farm_layout.gd")
const FarmCameraRig := preload("res://scripts/farm_camera_rig.gd")

const VERSION := "0.2.11"
const TILE_SPACING := FarmLayout.TILE_SPACING
const TILE_HEIGHT := FarmLayout.TILE_HEIGHT
const TILE_WIDTH := FarmLayout.TILE_WIDTH
const STUBBLE := FarmLayout.STUBBLE
const STARTER := """#include <bits/stdc++.h>
using namespace std;

int main() {
    harvest();
    return 0;
}
"""


const CONTROLS_TEXT := "视角：左键按住地面拖动平移（松手轻轻滑一下），右键拖动转动，滚轮缩放，WASD 移动，F 回正。左键点在窗口和按钮上只操作界面。"

const CHANGELOG_TEXT := """0.2.11  —  2026-11-14

GitHub 公开试玩版。修复导出资源包后中文与代码字体读取失败：优先通过 Godot 资源加载器读取导入字体，保留源文件回退。增加 Windows 免安装试玩包与源码构建说明。保留 0.2.10 的存档、声音、欢迎页、场景与游戏规则。

0.2.10  —  2026-11-14

修复：小 bot 连续抖动或翻跟头后不再偏离地块；在 return 0; 上一行按回车等正常输入不再被框架保护撤销；报错标记不再每帧刷错误；欢迎页特写不再被草挡住，并显示存档里的农场、干草和技能数。

画面：草甸有色块与云影，四周有摆动的草丛、小花、圆树、光点和蝴蝶，全部由代码生成。地块改为圆角柔和方块，阴影更软。技能树里共用图标的技能各有自己的简单图形。

模拟器规则与范本未改。

0.2.9  —  2026-11-14

进度自动保存：农场、库存、技能、代码和窗口状态都会留下，关掉再开可以「继续游戏」。存档带校验并保留一份备份，主档损坏时自动用备份。

新增欢迎页，修复开始按钮被排到屏幕外的问题。新增代码合成的音效（收割、挥空、耕地、解锁等），设置里可选关 / 轻 / 开。

顶栏收为四个按钮，视角回正和更新日志移入设置。技能卡加一行用途并保持固定大小；提示窗默认露出范本按钮。模拟器规则与范本未改；C++ 1844 项检查、六项 Godot 验收与存档专项通过。

0.2.8  —  2026-11-11

技能树收紧为向下主干与两侧短分支，连线表示学习路线，完整前置放进节点提示。价格分行、悬停接头稳定；左拖保留 6px 阈值并增加短惯性，滚轮缩放、全貌与还原方便找后期节点，购买后保持视图。

提示先显示痛点和本次要加的一行；加速直接指向「条件」与 if (can_harvest()) harvest();，余额不足时可停下等熟单收。完整范本可折叠、复制和载入；载入替换主程序并带上头文件。

主机和多机共用奶黄球形身体、纯黑固定竖眼与协调的手臂锄头；移除眨眼。保留 0.2.7 收割时序与共享范本。既有 Windows C++ 1495 项检查、45 次购买路线、五项 Godot 验收与本轮专项检查通过；未重编扩展。验收与截图见 docs/review-0.2.8.md。

0.2.7  —  2026-11-11

未熟就砍会把草打回幼苗，重新生长 400 tick；加速后反复盲收会一直长不熟。成功和空挥都花当前动作时间，一档加速为 200 tick，查询仍为 1 tick，不伤幼苗。

先停循环，等熟再单次收割，攒够 12 干草购买「条件」；在原有 while 里加 if (can_harvest()) harvest(); 即可等熟再收。生长、价格、产量和技能顺序不变。补充持续停产、查询时序、其它作物与正常恢复测试，完整验收见 docs/review-0.2.7.md。

Windows C++ 1495 项检查与 153 项真实路线检查通过，完成 45 次购买。同起点 30 秒：盲收 1 干草后持续停产，条件循环 30 干草。五项 Godot 验证通过，扩展和运行库已更新。

0.2.6  —  2026-11-11

挥空固定花 400 tick，不再随加速或能量缩短；成功动作仍加速，草仍长 400 tick，查询仍花 1 tick。同一起点运行 30 秒，纯收获循环 20 干草，条件循环 30 干草。挥空有独立横扫，不裁切作物、不掉奖励；加速提示指向「条件」与 can_harvest()。

修复提示窗避让取消最大化动画造成的瞬移；窗口用 300ms 平滑曲线连续放大与还原。快速反向、最小化转最大化、关闭重开、拖动缩放和屏幕尺寸变化保持正确状态。选项与复制反馈可打断旧动画，保留现有暖色风格与字体。

载入完整范本时替换主程序并加载头文件，避免嵌套 main；重置同时清空分文件并还原浮窗。修复 Windows 中文路径下正常测试入口读取范本失败；1196 项 C++ 检查通过，真实玩家路线完成 45 次购买。完整验收与按钮覆盖见 docs/review-0.2.6.md。

0.2.5  —  2026-11-11

技能树支持左键按住拖动，横向、纵向跟随鼠标移动；节点上也能起拖。轻点仍用于解锁或查看详情，移动超过 6px 后只拖动，不会误点技能。保留滚轮、滚动条和详情面板操作；区域外松手、失焦或关闭面板时结束拖动。

0.2.4  —  2026-11-11

代码默认 20px，优化结构配色并修复主编辑器高亮失效。默认框架受保护，正文、辅助函数和头文件仍可编辑。报错显示行列位置与修改建议，柔和呈现并定位代码。自动通关 45 次购买、139 项路线检查、1167 项 C++ 测试通过；发现的教学节奏和长期运行问题已记录在项目流程检查文档。保留现有生产规则。

0.2.3  —  2026-11-11

图标与按钮改为柔和圆角方形，保持正方形绘制比例。悬停渐亮，按下短促收紧，松开平滑恢复。技能树、设置、日志新增面板内导航，选中底板柔和平移，内容随方向短距离平移淡入；连续切换会接续当前状态。分文件切换保留按钮并淡入代码。保留现有字体、相机、运行语义和农场规则。

0.2.2  —  2026-11-11

每个技能都有一份「范本」：正常通关测试真正跑过的那段程序。范本一步只多一个新概念，解锁后在提示窗口和技能详情里显示，可折叠、一键复制，高亮和代码区一致。提示先用一句话说清痛点，再给范本。地图改成左键按住地面拖动平移，松手后有一点轻微惯性。

范本与通关
• 新增从全新存档出发、只用玩家操作的整局通关测试，按课程表顺序买完所有节点，每一档都验证「先痛后药」。全程约 52 分钟游戏时间，最长一档约 5 分钟，没有长时间挂机。
• 范本放在 game/exemplars/，测试与游戏读同一份文件；另有测试保证每个节点都有能解析、能运行的范本。

规则调整与修复
• 移动只花半个动作，边走边收比原地收更划算。
• 胡萝卜只花干草，不再花木头，避免木头被吃光卡关。
• 仙人掌排序和成片判断不再跨边缘环绕；恐龙苹果在田满时也能找到落点；收割枯萎南瓜会清掉它；新一次运行会结束上一次的迷宫；空着的草地会重新长草。
• 解释器：实数四则运算、二维数组参数、文件级常量对函数和无人机可见、解锁名不区分大小写；get_time() 需要「计时」；变量未解锁时用 for 的 i 会给出清楚提示。

操作
• 左键在地面上按住拖动平移地图，地面跟着鼠标走；有一小段拖动阈值，点击仍是点击。拖动时显示抓手光标。在窗口、按钮上按下左键只操作界面。右键转动、滚轮缩放、WASD、F 回正和中键平移都保留。

0.2.1  —  2026-11-11

补上可复现的 simulate()，画面能同时看到多台无人机，解锁分文件后可切换新建用户文件，大田用地块合批和降频动画。技能树节点对齐、连线改成圆润分支，后期节点容易扫到；胡萝卜、树、向日葵、南瓜、仙人掌、迷宫篱笆和宝藏更好认；顶栏资源图标各不相同。去掉小 bot 脚下的圆环，田下不再是带清晰圆边的正圆岛屿。系统界面字再加大约 2px，字色和字重更柔和，行距字距略松；代码区仍是 JetBrains Mono 18px。

0.2.0  —  2026-11-11

按原作 1.0 主线把全部技能与作物一次落地。技能树可滚动，顶栏按解锁显示多种资源。种植、浇水、树木、向日葵、南瓜、迷宫、仙人掌、伴侣、恐龙帽和多无人机都按课程表机制运行，而不是只加图标。

内容
• 技能树覆盖循环、加速、条件、移动、计数、耕地、种植、扩田、变量、常量、运算、感知、胡萝卜、成本查询、浇水、树木、函数、引用、分文件、向日葵、数组、结构体、分支、南瓜、工具函数、肥料、迷宫、仙人掌、伴侣、恐龙、多机、打印、计时、实验、模拟、自动解锁和帽子。
• 花费按课程表压缩值；多种货币可花余额与累计产量分开。扩田会清场并增大边长，请用 get_world_size()。
• 浇水、邻树惩罚、向日葵花瓣与连罚、南瓜枯死与 n³、迷宫生成与错收消失、仙人掌排序后 n²、伴侣种植、恐龙帽蛇规则、多机无共享内存都在模拟器里实现。
• 3D 作物用原创风格化模型区分，不是原作贴图。DLC 采矿、水稻、竹子只留接口，不挡主线。

界面
• 系统字与 0.1.5 相同：Noto Sans CJK、较大字号；代码区 JetBrains Mono 18。缩放手柄仍是透明点击区加淡 L 线。
• 实心三角仍是跑完 main 即停，空心三角单步。开局收割与生长仍是 400 tick；加速只缩短动作。

0.1.5  —  2026-11-11

实心三角改为把 main 跑完就停，不再自动重跑；空心三角改为单步。失败收割和成功收割花同样的时间，开局一刀刚好等草长熟。循环和条件之间加了「加速」技能，速度改由技能决定。系统字更大，窗口缩放手柄不再留下色块，视角跟手一些。

运行
• 实心三角是「运行」：完整执行一遍 main，结束即停，草地仍继续生长。空心三角是「单步」：每次只执行一条语句或一个农场动作，然后暂停。点进代码区仍会停止。不再提供自动反复执行 main 的模式。

解锁
• 成功收割和失败收割都花费完整动作时间；查询仍是 1 tick。开局一次 harvest 约为 1 秒，和草的生长时间相同，所以 while (true) { harvest(); } 能一刀接一刀收到成熟草。
• 设置里不再让玩家自己拉速度。在「循环」（5 干草）之后花费 8 干草解锁「加速」，动作大约变为 2 倍快，此时纯 while 收割会打在未熟的草上。再花费 12 干草解锁「条件」。之后仍是移动 20、计数 30、耕地 40、种植 60。

相机与界面
• 右键转动 1:1 跟鼠标，WASD 松开即停，平移像抓住地面拖动，滚轮以鼠标指向为参考缩放。
• 系统界面字号加大，使用 Noto Sans CJK（SIL OFL）。代码区仍是 18 号 JetBrains Mono。
• 窗口右下角缩放手柄改为透明点击区，只用很淡的 L 形线条提示，不再留下金色色块。

0.1.4  —  2026-11-11

按试玩反馈修了眼睛、鼠标、视角和界面动效。

农场与角色
• 小 bot 的眼睛改成贴在豆子身体正面的黑色竖长条（圆角胶囊），没有屏幕或脸板，也没有高光白点。眨眼时条会轻轻合上。

相机与鼠标
• 修了鼠标拖动卡住：在空地按下右键或中键开始观察后，即使在按钮或窗口上松开，也会结束拖动；窗口失焦或按 Esc 同样清掉拖动状态。左键不再平移视角，只用来点界面；点农田空地把键盘焦点还给相机。
• 视角改成常见的自由观察：按住右键原地转动（不再绕远处锚点滑），WASD 沿当前视角水平移动，空格上升、Shift 下降，中键或 Shift+右键平移，滚轮靠近或拉远。转动跟手，松开即停。在任何界面上滚动或拖动都不会带动相机。按 F 或点回正，回到田在右侧空地的斜俯视。

界面
• 代码 / 提示窗口打开时淡入并从 0.96 放到 1，关闭淡出；最小化收到标题栏、还原展开，尺寸变化保持平滑。
• 技能树、设置、日志的背景淡入，卡片略上移再落下。顶栏图标、运行按钮和窗口 ─ ☐ ✕ 悬停轻微提亮并放到约 1.05，按下收到 0.96，松开回弹。技能详情弹出保持柔和。

————————

0.1.3  —  2026-11-11

把图标、窗口按钮和小 bot 再做柔和一些。

界面
• 全部图标改为粗圆的面性 / 半面性风格（填充或半透明底 + 粗描边），线宽约为原来的 1.5–2 倍，端点和拐角大圆角，形状更胖更简单；深色底上用偏暖的奶白，避免刺眼纯白。「条件」是带问号的菱形，不再像人字。
• 代码 / 提示窗口的 ─ ☐ ✕ 做成浅底色圆角小框，悬停略亮，关闭悬停为柔和珊瑚红。
• 运行按钮改成圆润的胶囊框，三角顶点倒圆角，配色为柔和的鼠尾草绿。实心为持续运行、空心为运行一次，运行中仍变为停止并有轻微脉动。

农场与角色
• 小 bot 重新建模：单一豆子 / 胶囊身体（没有单独的大头和脚，轻微悬浮），正面一块圆角深色小屏幕，两只柔和发光的圆眼会眨，浅绿腰带，两只短圆手臂。去掉螺旋桨。手里斜握一把长约身高 0.8 的小锄头（暖木柄 + 柔和灰绿金属头，举在头顶一侧）。配色暖奶白、浅绿和暖木，材质哑光，并带轻微描边，避免过曝成一团白。
• 待机轻轻上下晃，移动时轻微前倾；收割和耕地时用锄头做柔和的挖 / 割动作；do_a_flip() 会翻身；出错卡住时轻抖。

————————

0.1.2  —  2026-11-11

把界面再收一收：少文字、多图标，并把小草、机器人和相机手感磨顺。

农场与角色
• 小草叶片有弯曲、粗细变化和轻微摆动，成熟时带一点暖色微光。
• 无人机换成会动的小 bot：屏幕脸会眨眼，待机漂浮，移动时倾斜，收割会点头，do_a_flip() 会真翻跟头。

界面
• 代码 / 提示窗口的最小化、全屏、关闭是绘制出来的 ─ ☐ ✕，像桌面客户端；全屏后变为还原的双方框，关闭悬停为红色。
• 顶栏用图标：干草捆 + 数字，代码、技能、提示、设置、日志和回正视角都带简短 tooltip。技能卡片改以图标为主，文字缩短。
• 运行入口在代码窗口标题栏：实心三角持续运行（main 结束后自动再跑），空心三角只跑一遍。点进代码区会停止。顶栏不再放运行 / 停止。
• 在代码区按 Shift+滚轮缩放字号（12–32px），右下角短暂显示百分比；Ctrl+0 或双击百分比复位。本次会话会记住字号。代码区滚轮不会带动相机。

相机
• 右键拖动环绕旋转，左键在空地拖动或中键拖动平移，滚轮缩放。WASD 相对视角在水平面移动，空格上升、Shift 下降。俯仰、缩放、高度和平移都有范围，并带阻尼。
• 默认斜俯视，田地在代码窗口右侧居中。按 F、双击空地或点回正视角可复位。编辑器或文本框有焦点时，键盘只输入文字，不会移动相机。

已知限制
• 干草改为可花的货币：在技能树点击灰色图标解锁技能（循环 5、条件 10、移动 20、计数 30、耕地 40、种植 60）。累计收获不再自动解锁。变量、函数仍只在技能树中预告。

————————

0.1.1  —  2026-11-11

在 0.1.0 之后补上耕地、种植，并按「先痛后药」重排技能树。界面改成方块田与可拖动的代码 / 提示窗口。

编程
• 开局只有 harvest() 和 do_a_flip()。if 与 can_harvest() 不再一开始就给。
• 技能树花费干草解锁：while 5、if 与 can_harvest() 10、move 20（同时扩大为 3×3）、for 30、till 40、plant(Bush) 与 get_entity_type() / get_ground_type() 以及 == / != 共 60。前置未开或干草不够时不能购买。
• for 用来走过 3×3 的田垄，不必把 move 手写很多遍。循环变量暂时还不能参与运算。
• 仍用标准 C++ 形态：#include、using namespace std;、int main()。

农场
• 田块改成带侧边和轻微倒角的泥土方块，草长在顶面，像小的立体微缩格。
• till() 把草地翻成耕地（毁掉上面的植物），再翻一次变回草地。plant(Bush) 只能种在空的耕地上，成熟后收割得到木头。
• 解锁花的是当前背包里的干草，不是累计收获。

界面
• 代码和提示是真正的窗口：可拖动、最小化、全屏、关闭，并记住本次位置。关闭后用顶栏的「代码」「提示」重新打开。提示正文可滚动，全屏代码时会把提示收起到标题栏，避免挡住编辑器，退出全屏后恢复原状。
• 编辑器、补全、提示、技能树和设置共用一套暖鼠尾草、奶油与哑光金的主题，代码用 JetBrains Mono。技能树卡片加宽、减少折行。

已知限制
• 变量、自定义函数、数组和结构体等后续 C++ 节点仅在技能树中预告。
• 语言仍是很小的 C++ 子集。

————————

0.1.0  —  2026-11-10

Codefarm 第一个可玩的公开预览版。开局 1×1 草地，累计 5 个干草解锁 while，15 个解锁移动（0.1.1 起改为 20，并增补判断与耕地）。
"""

const SAGE_BG := Color(0.16, 0.20, 0.18, 0.94)
const SAGE_DEEP := Color(0.11, 0.14, 0.13, 0.97)
const CREAM := Color(0.93, 0.91, 0.85, 1)
const GOLD := Color(0.78, 0.62, 0.38, 1)
const GOLD_SOFT := Color(0.80, 0.70, 0.50, 1)
const TEXT := Color(0.90, 0.88, 0.82, 1)
const TEXT_DIM := Color(0.80, 0.78, 0.72, 1)
const DANGER := Color(0.86, 0.46, 0.38, 1)
# Syntax: distinct roles, all in the same sage / cream / gold family.
const SYN_KEYWORD := Color(0.79, 0.72, 0.91, 1)
const SYN_TYPE := Color(0.62, 0.79, 0.88, 1)
const SYN_FUNC := Color(0.70, 0.84, 0.66, 1)
const SYN_NUMBER := Color(0.91, 0.77, 0.57, 1)
const SYN_ENUM := Color(0.65, 0.83, 0.78, 1)
const SYN_STD := Color(0.73, 0.80, 0.85, 1)
const SYN_SYMBOL := Color(0.73, 0.77, 0.73, 1)
const SYN_COMMENT := Color(0.59, 0.67, 0.61, 1)
const SYN_PREPROC := Color(0.65, 0.76, 0.73, 1)
const SYN_STRING := Color(0.87, 0.81, 0.62, 1)
const SYN_IDENT := Color(0.90, 0.92, 0.87, 1)

@onready var host: CodefarmHost = $CodefarmHost
@onready var drone: Node3D = $Farm/Drone
@onready var juice_anchor: Node3D = $Farm/Juice
@onready var farm_root: Node3D = $Farm
@onready var farm_tile: MeshInstance3D = $Farm/Tile
@onready var farm_earth: MeshInstance3D = $Farm/Earth
var _farm_meadow: MeshInstance3D
var scenery: FarmScenery
@onready var grass_placeholder: Node3D = $Farm/Grass
@onready var camera: Camera3D = $Camera3D
@onready var ui_root: Control = $UI/Root

var editor: CodeEdit
var run_button: Button
var stop_button: Button
var run_loop_button: FarmRunButton
var run_once_button: FarmRunButton
var hay_label: Label
var wood_wrap: HBoxContainer
var _item_chips: Dictionary = {}
var wood_label: Label
var font_badge: Label
var reset_cam_button: Button
var error_markup: Control
var hint_next_label: Label
var hint_next_code: CodeEdit
var hint_load_button: Button
var hint_code: CodeEdit
var hint_prose_after: Label
var _error_history: PackedStringArray = []
var _error_latched := false
var _error_runtime := false
var hint_line: Label
var title_label: Label
var highlight: Control
var backdrop: ColorRect
var _panel_tabs: Control
var overlay_card: PanelContainer
var overlay_title: Label
var overlay_body: Control
var overlay_close: Button

var _font_ui: Font
var _font_ui_bold: Font
var _font_mono: Font
var _font_size: int = 20
var _font_size_default: int = 20
var _font_display: float = 18.0
var _font_zoom_accum: float = 0.0
var _font_tween: Tween
var _font_badge_tween: Tween
var _font_anchor_line: int = -1
var _font_anchor_y: float = 0.0
var _stepping: bool = false
var _open_panel: String = ""
var _reset_confirming: bool = false
var _loops_seen: bool = false
var _speed_seen: bool = false
var _if_seen: bool = false
var _move_seen: bool = false
var _for_seen: bool = false
var _till_seen: bool = false
var _plant_seen: bool = false
var _highlighted_line: int = -1
var _pending_line: int = -1
var _pending_t: float = 0.0
var _drone_base_y: float = 0.42
var _hover_t: float = 0.0
var _harvesting: bool = false
var _harvest_tween: Tween
var _flipping: bool = false
var _tilling: bool = false
var _shot_hide_plants: bool = false
var _plots: Dictionary = {}
var _plots_root: Node3D
var _shown_size: int = 1
var _drone_from := Vector3.ZERO
var _drone_to := Vector3.ZERO
var _drone_move_t: float = 1.0
var _pending_paren_adjust: bool = false
var _completion_prefix: String = ""
var _blade_mats: Array[StandardMaterial3D] = []
var _theme: Theme
var code_window: PanelContainer
var hint_window: PanelContainer
var code_btn: Button
var skill_button: Button
var hint_button: Button
var settings_button: Button
var log_button: Button
var hint_body_label: Label
var hint_scroll: ScrollContainer
var _hint_stashed := false
var _hint_stash_visible := true
var _hint_stash_minimized := false
var _hint_stash_maximized := false
var _hint_stash_rect := Rect2()
var _code_default := Rect2(20, 94, 520, 432)
var _hint_default := Rect2(20, 538, 520, 342)
var _grass_mat: StandardMaterial3D
var _soil_mat: StandardMaterial3D
var _bush_mats: Array[StandardMaterial3D] = []
var _wet_soil_mat: StandardMaterial3D
var skill_detail: Control
var _selected_skill_id := ""
var last_copied_template := ""
# Hint window: one-sentence pain + collapsible 「范本」 (the playthrough's exemplar).
var hint_skill_id := ""
var hint_exemplar_toggle: Button
var hint_copy_button: Button
var hint_copied_label: Label
var hint_header_label: Label
var hint_header_code: CodeEdit
var hint_header_copy: Button
var _hint_exemplar_open := true
var _code_highlighter: CodeHighlighter
var _skill_glow_nodes: Array = []
var skill_scroll: ScrollContainer
var _skill_more_hint: Control
var _skill_view := {"zoom": 1.0, "scroll": Vector2.ZERO}
var _file_bar: HBoxContainer
var _file_bar_wrap: Control
var _user_files: Dictionary = {}
var _active_file := "main.cpp"
var _extra_drones: Array = []
var _drones_root: Node3D
var _view_drone: int = 0
var _grass_anim_accum: float = 0.0
var _blade_mm_inst: MultiMeshInstance3D
var _lod_mm_inst: MultiMeshInstance3D
var _tile_mm_grass: MultiMeshInstance3D
var _tile_mm_soil: MultiMeshInstance3D
var _tile_mm_wet: MultiMeshInstance3D
var _blade_young: StandardMaterial3D
var _blade_mid: StandardMaterial3D
var _blade_ripe: StandardMaterial3D
var _blade_meshes: Array[ArrayMesh] = []
var _bot_rig: Node3D
var _bot_hoe: Node3D
var _bot_arm_l: Node3D
var _bot_arm_r: Node3D
var _bot_eye_l: Node3D
var _bot_eye_r: Node3D
var camera_rig: FarmCameraRig
const FONT_SIZE_MIN := 12
const FONT_SIZE_MAX := 32

@export var persistence_enabled := true
@export var start_on_farm := false  # Explicit scene fixture option for isolated UI tests.
@export var save_path := "user://progress.json"
var _session_phase := "menu"
var _portrait_hidden: Array[Node3D] = []
var audio: FarmAudio
var _sound_level := 2
var _menu: Control
var _start_button: Button
var _save_notice: Label
var _save_timer: Timer
var _save_elapsed := 0.0
var _has_save := false
var _loading_save := false
var _save_message := ""
var _intro_time := 0.0
var _intro_from := Transform3D.IDENTITY
var _intro_to := Transform3D.IDENTITY
var _intro_size := 1.0
var _intro_home_size := 4.15
const INTRO_DURATION := 1.6


func _ready() -> void:
	_setup_camera_rig()
	farm_tile.visible = false
	grass_placeholder.visible = false
	_setup_fonts()
	_setup_theme()
	_build_ui()
	_setup_highlighter()
	_setup_completion()
	_init_farm()
	if editor.text.strip_edges().is_empty() or editor.text.strip_edges() == "harvest();":
		editor.text = STARTER
	_clear_error_markup()
	_apply_hint_text()
	call_deferred("_refresh_hint_layout")
	_update_hay()
	_update_buttons()
	_drone_base_y = TILE_HEIGHT + 0.18
	_snap_drone()
	_soften_lights()
	_build_bot()
	_setup_session()



func _setup_camera_rig() -> void:
	camera_rig = FarmCameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(camera, {
		"point_over_ui": _point_over_ui,
		"mouse_over_editor": _mouse_over_editor,
		"text_input_focused": _text_input_has_focus,
		"panel_open": func() -> bool: return _open_panel != "",
		"farm_size": func() -> int: return _shown_size,
		"code_window_visible": func() -> bool: return code_window != null and code_window.visible,
	})


func _setup_session() -> void:
	get_tree().auto_accept_quit = false
	audio = FarmAudio.new()
	audio.name = "FarmAudio"
	add_child(audio)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.8
	_save_timer.timeout.connect(_save_now)
	add_child(_save_timer)
	_load_progress()
	_ensure_farm_size(host.get_world_size())
	_snap_drone()
	camera_rig.apply_home(host.get_world_size(), true)
	if start_on_farm:
		_session_phase = "playing"
		return
	_intro_to = camera.transform
	_intro_home_size = camera.size
	ui_root.visible = false
	# The same rig leads the welcome screen. No portrait texture or second bot.
	var focus := drone.position + Vector3(0, 0.015, 0)
	camera.position = focus + Vector3(0, 0.10, 2.4)
	camera.look_at(focus)
	camera.size = 0.88
	_bot_rig.rotation = Vector3.ZERO
	_clear_portrait(true)
	_intro_from = camera.transform
	_intro_size = camera.size
	_build_menu()


func _build_menu() -> void:
	_menu = Control.new()
	_menu.name = "Welcome"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.theme = _theme
	$UI.add_child(_menu)
	var title := Label.new()
	title.text = "Codefarm"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title, 38, SAGE_DEEP, true)
	_menu.add_child(title)
	# Anchor first, then offsets: assigning position/size here is absolute and
	# pushed the title and the start button off-screen.
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -170
	title.offset_right = 170
	title.offset_top = 40
	title.offset_bottom = 104
	var actions := VBoxContainer.new()
	actions.name = "WelcomeActions"
	actions.add_theme_constant_override("separation", 14)
	_menu.add_child(actions)
	actions.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	actions.offset_left = -150
	actions.offset_right = 150
	actions.offset_top = -166
	actions.offset_bottom = -22
	_start_button = _make_button("继续游戏" if _has_save else "开始游戏", false, 240)
	_start_button.name = "StartGame"
	_start_button.custom_minimum_size = Vector2(300, 64)
	_start_button.pressed.connect(start_game)
	actions.add_child(_start_button)
	_save_notice = Label.new()
	_save_notice.text = _save_message if not _save_message.is_empty() else _save_summary() if _has_save else "写下第一行，让农场生长"
	_save_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(_save_notice, 17, SAGE_DEEP)
	actions.add_child(_save_notice)
	_start_button.grab_focus()


## What the saved farm holds, so the welcome screen shows the save was read.
func _save_summary() -> String:
	var owned := 0
	for node in FarmSkillData.nodes(host):
		if bool(node.get("owned", false)) and str(node.get("id", "")) != "harvest":
			owned += 1
	var side := int(host.get_world_size())
	return "已读取存档 · %d×%d 农场 · 干草 %d · 技能 %d 项" % [side, side, int(host.get_hay()), owned]


func start_game() -> void:
	if _session_phase != "menu":
		return
	_session_phase = "entering"
	_intro_time = 0.0
	_start_button.disabled = true
	_start_button.release_focus()
	_clear_portrait(false)
	clear_camera_drag()
	var tw := create_tween()
	tw.tween_property(_menu, "modulate:a", 0.0, 0.25)


## The welcome close-up looks straight at the bot. Plants standing between the
## camera and the bot are tucked away for the portrait and return on start.
func _clear_portrait(on: bool) -> void:
	for node in _portrait_hidden:
		if is_instance_valid(node):
			node.visible = true
	_portrait_hidden.clear()
	if scenery:
		scenery.set_decor_visible(not on)
	if not on:
		return
	var at := drone.global_position
	for key in _plots:
		var plot: Dictionary = _plots[key]
		var nodes: Array = [plot["bush"], plot["crop"], plot["lod"]]
		for blade in plot["blades"]:
			nodes.append(blade["pivot"])
		for node in nodes:
			var pos: Vector3 = node.global_position
			if node.visible and pos.z > at.z - 0.10 and absf(pos.x - at.x) < 0.62:
				node.visible = false
				_portrait_hidden.append(node)


func _tick_intro(delta: float) -> void:
	if _session_phase != "entering":
		return
	_intro_time = minf(_intro_time + delta, INTRO_DURATION)
	var t := smootherstep(_intro_time / INTRO_DURATION)
	camera.transform = _intro_from.interpolate_with(_intro_to, t)
	camera.size = lerpf(_intro_size, _intro_home_size, t)
	if _intro_time >= INTRO_DURATION:
		_session_phase = "playing"
		_menu.visible = false
		ui_root.visible = true
		ui_root.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(ui_root, "modulate:a", 1.0, 0.24)
		_queue_save()


func smootherstep(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _snapshot_progress() -> Dictionary:
	_flush_active_file()
	if is_instance_valid(skill_scroll):
		_skill_view = {"zoom": skill_scroll.zoom, "scroll": Vector2(skill_scroll.scroll_horizontal, skill_scroll.scroll_vertical)}
	var scroll: Vector2 = _skill_view.scroll
	return {"version": 1, "world": host.save_state(), "files": _user_files.duplicate(),
		"active_file": _active_file, "hint": hint_skill_id, "exemplar_open": _hint_exemplar_open,
		"zoom": _skill_view.zoom, "scroll": [scroll.x, scroll.y], "font_size": _font_size,
		"selected_skill": _selected_skill_id, "bot_yaw": _bot_rig.rotation.y,
		"hint_visible": hint_window.visible, "code_visible": code_window.visible,
		"sound": _sound_level}


func _valid_progress(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("world") is String or not data.get("files") is Dictionary:
		return false
	var files: Dictionary = data.files
	if not files.get("main.cpp") is String or files.size() > 64:
		return false
	for key in files:
		if not key is String or not files[key] is String or key.length() > 128 or files[key].length() > 524288:
			return false
	if not data.get("active_file") is String or not files.has(data.active_file):
		return false
	if not data.get("hint", "") is String or not data.get("selected_skill", "") is String:
		return false
	var scroll = data.get("scroll")
	if not scroll is Array or scroll.size() != 2:
		return false
	for value in [data.get("zoom"), data.get("font_size"), data.get("bot_yaw"), scroll[0], scroll[1]]:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return float(data.zoom) >= 0.1 and float(data.zoom) <= 3.0 and int(data.font_size) >= FONT_SIZE_MIN and int(data.font_size) <= FONT_SIZE_MAX


func _load_progress() -> bool:
	if not persistence_enabled:
		return false
	_loading_save = true
	var existed := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")
	for path in [save_path, save_path + ".bak"]:
		var data := FarmSave.read_file(path)
		if not _valid_progress(data) or not host.load_state(data.world):
			continue
		_user_files = data.files.duplicate()
		_active_file = data.active_file
		editor.protect_framework = _active_file == "main.cpp"
		editor.text = _user_files[_active_file]
		_set_editor_font_size(int(data.font_size), false, false)
		hint_skill_id = data.get("hint", "")
		_hint_exemplar_open = bool(data.get("exemplar_open", false))
		_skill_view = {"zoom": float(data.zoom), "scroll": Vector2(float(data.scroll[0]), float(data.scroll[1]))}
		_selected_skill_id = data.get("selected_skill", "")
		_bot_rig.rotation.y = float(data.bot_yaw)
		hint_window.visible = bool(data.get("hint_visible", true))
		code_window.visible = bool(data.get("code_visible", true))
		# Older saves have no sound entry; anything unexpected means full volume.
		var sound = data.get("sound", 2)
		_set_sound_level(int(sound) if (sound is float or sound is int) and is_finite(float(sound)) else 2)
		_rebuild_file_bar()
		_push_includes_to_host()
		_apply_hint_text()
		# Mark already-owned introductory hints seen; reopening must not replace the saved hint.
		_loops_seen = host.loops_unlocked()
		_speed_seen = host.speed_unlocked()
		_if_seen = host.conditions_unlocked()
		_move_seen = host.movement_unlocked()
		_for_seen = host.for_unlocked()
		_till_seen = host.till_unlocked()
		_plant_seen = host.plant_unlocked()
		_has_save = true
		_save_message = "已恢复上次备份；进度仍会自动保存。" if path.ends_with(".bak") else ""
		_loading_save = false
		return true
	_loading_save = false
	if existed:
		_save_message = "存档损坏，已安全回到新农场。"
	return false


func _set_sound_level(value: int) -> void:
	_sound_level = clampi(value, 0, 2)
	if audio:
		audio.level = _sound_level


func _sfx(sound: String) -> void:
	if audio and _session_phase == "playing":
		audio.play(sound)


func _queue_save(restart: bool = false) -> void:
	if not persistence_enabled or _loading_save or _save_timer == null:
		return
	if restart or _save_timer.is_stopped():
		_save_timer.start()


func _save_now() -> bool:
	if not persistence_enabled or _loading_save or not is_instance_valid(editor) or _bot_rig == null:
		return false
	var ok := FarmSave.write_file(save_path, _snapshot_progress())
	if not ok:
		_save_message = "保存失败，请检查数据目录空间与权限。"
		if is_instance_valid(_save_notice):
			_save_notice.text = _save_message
		if is_instance_valid(hint_line):
			hint_line.text = _save_message
	else:
		_has_save = true
	return ok


func _exit_tree() -> void:
	_save_now()


func _load_font_file(path: String) -> FontFile:
	# Exported font paths resolve to imported .fontdata, not raw source bytes.
	var font: FontFile
	if ResourceLoader.exists(path):
		font = ResourceLoader.load(path) as FontFile
		if font:
			font = font.duplicate()
	if font == null:
		font = FontFile.new()
		if font.load_dynamic_font(path) != OK:
			return null
	font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return font


func _ui_font_with_fallback(base: Font, fallbacks: Array) -> Font:
	if base == null:
		return null
	var extras: Array = []
	for item in fallbacks:
		if item and item != base:
			extras.append(item)
	if extras.is_empty():
		return base
	var variation := FontVariation.new()
	variation.base_font = base
	variation.fallbacks = extras
	return variation



func _soften_ui_font(base: Font, embolden: float = 0.0) -> Font:
	if base == null:
		return null
	var v := FontVariation.new()
	if base is FontVariation:
		var src := base as FontVariation
		v.base_font = src.base_font
		v.fallbacks = src.fallbacks
	else:
		v.base_font = base
	v.spacing_glyph = 1
	v.spacing_space = 1
	v.spacing_top = 1
	v.spacing_bottom = 2
	if embolden != 0.0:
		v.variation_embolden = embolden
	return v


func _setup_fonts() -> void:
	var droid := _load_font_file("res://fonts/DroidSansFallback.ttf")
	var noto := _load_font_file("res://fonts/NotoSansCJKsc-Regular.otf")
	var noto_bold := _load_font_file("res://fonts/NotoSansCJKsc-Bold.otf")
	var cjk: Font = noto if noto else droid
	var cjk_bold: Font = noto_bold if noto_bold else cjk
	var mono := _load_font_file("res://fonts/JetBrainsMono-Regular.ttf")
	if mono == null:
		mono = _load_font_file("res://fonts/NotoSansMono.ttf")
	if mono and cjk:
		var code_font := FontVariation.new()
		code_font.base_font = mono
		code_font.fallbacks = [cjk]
		_font_mono = code_font
	elif mono:
		_font_mono = mono
	_font_ui = _soften_ui_font(_ui_font_with_fallback(cjk, [droid]), 0.0)
	# Slight embolden on regular, not the heavy Bold cut — softer weight for titles.
	_font_ui_bold = _soften_ui_font(_ui_font_with_fallback(cjk, [cjk_bold, droid]), 0.32)


func _setup_theme() -> void:
	_theme = Theme.new()
	if _font_ui:
		_theme.default_font = _font_ui
	_theme.default_font_size = 20
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_color("font_color", "Button", CREAM)
	_theme.set_color("font_hover_color", "Button", CREAM)
	_theme.set_color("font_pressed_color", "Button", CREAM)
	_theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	_theme.set_color("font_color", "TooltipLabel", CREAM)
	_theme.set_font_size("font_size", "TooltipLabel", 18)
	_theme.set_font_size("font_size", "Label", 20)
	_theme.set_color("font_color", "PopupMenu", CREAM)
	_theme.set_color("font_hover_color", "PopupMenu", CREAM)
	_theme.set_color("font_accelerator_color", "PopupMenu", TEXT_DIM)
	_theme.set_color("font_color", "ItemList", CREAM)
	_theme.set_color("font_hovered_color", "ItemList", CREAM)
	_theme.set_color("font_selected_color", "ItemList", CREAM)
	if _font_mono:
		_theme.set_font("font", "CodeEdit", _font_mono)
		_theme.set_font("font", "TextEdit", _font_mono)
		_theme.set_font("font", "LineEdit", _font_ui if _font_ui else _font_mono)
	if _font_ui:
		for typ in ["Label", "Button", "TooltipLabel", "PopupMenu", "ItemList", "CheckBox", "RichTextLabel", "OptionButton"]:
			_theme.set_font("font", typ, _font_ui)
	var panel := _flat(SAGE_BG, 16, Vector4(16, 12, 16, 12), 10)
	var deep := _flat(SAGE_DEEP, 16, Vector4(16, 12, 16, 12), 12)
	var tip := _flat(SAGE_DEEP, 10, Vector4(12, 8, 12, 8), 8)
	var popup := _flat(Color(0.14, 0.17, 0.15, 0.98), 10, Vector4(8, 6, 8, 6), 8)
	popup.border_color = Color(0.78, 0.62, 0.38, 0.35)
	popup.set_border_width_all(1)
	_theme.set_stylebox("panel", "PanelContainer", panel)
	_theme.set_stylebox("panel", "Panel", panel)
	_theme.set_stylebox("panel", "PopupPanel", popup)
	_theme.set_stylebox("panel", "PopupMenu", popup)
	_theme.set_stylebox("hover", "PopupMenu", _flat(Color(0.78, 0.64, 0.42, 0.30), 6, Vector4(8, 4, 8, 4)))
	_theme.set_stylebox("panel", "TooltipPanel", tip)
	_theme.set_stylebox("tooltip", "PopupMenu", tip)
	_theme.set_stylebox("normal", "Button", _flat(Color(0.30, 0.36, 0.32, 0.95), 9, Vector4(14, 6, 14, 6)))
	_theme.set_stylebox("hover", "Button", _flat(Color(0.36, 0.42, 0.37, 1), 9, Vector4(14, 6, 14, 6)))
	_theme.set_stylebox("pressed", "Button", _flat(Color(0.42, 0.38, 0.26, 1), 9, Vector4(14, 6, 14, 6)))
	_theme.set_stylebox("disabled", "Button", _flat(Color(0.24, 0.27, 0.25, 0.7), 9, Vector4(14, 6, 14, 6)))
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var scroll := _flat(Color(0.22, 0.26, 0.23, 0.95), 6, Vector4(0, 0, 0, 0))
	scroll.set_corner_radius_all(6)
	var grab := _flat(Color(0.70, 0.56, 0.32, 0.85), 6, Vector4(0, 0, 0, 0))
	for bar in ["VScrollBar", "HScrollBar"]:
		_theme.set_stylebox("scroll", bar, scroll)
		_theme.set_stylebox("grabber", bar, grab)
		_theme.set_stylebox("grabber_highlight", bar, _flat(GOLD_SOFT, 6, Vector4(0, 0, 0, 0)))
		_theme.set_stylebox("grabber_pressed", bar, _flat(GOLD, 6, Vector4(0, 0, 0, 0)))
		_theme.set_stylebox("scroll_focus", bar, scroll)
	var ed := _flat(Color(0.10, 0.12, 0.11, 1), 10, Vector4(10, 8, 10, 8))
	_theme.set_stylebox("normal", "CodeEdit", ed)
	_theme.set_stylebox("focus", "CodeEdit", ed)
	_theme.set_stylebox("read_only", "CodeEdit", ed)
	_theme.set_stylebox("completion", "CodeEdit", popup)
	_theme.set_color("background_color", "CodeEdit", Color(0.09, 0.11, 0.10, 1))
	if ui_root:
		ui_root.theme = _theme
	var win := get_window()
	if win:
		win.theme = _theme


func _flat(color: Color, radius: int = 12, pad := Vector4(16, 12, 16, 12), shadow: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.16)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, 2)
	return sb


func _apply_font(node: Control, size: int = 20, color: Color = TEXT, bold: bool = false) -> void:
	var font: Font = _font_ui_bold if bold and _font_ui_bold else _font_ui
	if font:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	if node is Label:
		node.add_theme_constant_override("line_spacing", 8)
	if node is RichTextLabel:
		node.add_theme_constant_override("line_separation", 8)
	if node is Label or node is Button or node is RichTextLabel:
		node.add_theme_color_override("font_color", color)


func _make_button(text: String, gold := false, min_w := 76) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, 44)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := _flat(Color(0.30, 0.36, 0.32, 0.95) if not gold else Color(0.70, 0.50, 0.28, 1), 9, Vector4(14, 6, 14, 6))
	var hover := _flat(Color(0.36, 0.42, 0.37, 1) if not gold else Color(0.78, 0.58, 0.34, 1), 9, Vector4(14, 6, 14, 6))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", _flat(Color(0.24, 0.27, 0.25, 0.7), 9, Vector4(14, 6, 14, 6)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_apply_font(btn, 20, CREAM)
	FarmMotion.bind_hover.call_deferred(btn)
	return btn


func _make_icon_button(kind: FarmIcon.Kind, tip: String, gold := false, min_size := Vector2(52, 52)) -> Button:
	var btn := _make_button("", gold, int(min_size.x))
	btn.text = ""
	btn.tooltip_text = tip
	var edge := maxf(min_size.x, min_size.y)
	btn.custom_minimum_size = Vector2(edge, edge)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_stylebox_override("normal", _flat(Color(0.30, 0.36, 0.32, 0.95) if not gold else Color(0.70, 0.50, 0.28, 1), 9, Vector4(6, 4, 6, 4)))
	btn.add_theme_stylebox_override("hover", _flat(Color(0.36, 0.42, 0.37, 1) if not gold else Color(0.78, 0.58, 0.34, 1), 9, Vector4(6, 4, 6, 4)))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.42, 0.38, 0.26, 1) if not gold else Color(0.78, 0.58, 0.34, 1), 9, Vector4(6, 4, 6, 4)))
	var icon := FarmIcon.new()
	icon.kind = kind
	icon.icon_color = Color(0.88, 0.84, 0.76, 1) if not gold else Color(0.90, 0.84, 0.70, 1)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8
	btn.add_child(icon)
	btn.set_meta("farm_icon", icon)
	return btn


func _resource_chip(kind: FarmIcon.Kind, name: String, tint: Color = Color(0, 0, 0, 0)) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := FarmIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(28, 28)
	icon.icon_color = tint if tint.a > 0.0 else GOLD_SOFT
	row.add_child(icon)
	var label := Label.new()
	label.name = name
	label.text = "0"
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_font(label, 22, GOLD_SOFT, false)
	row.add_child(label)
	return {"row": row, "label": label, "icon": icon}


func _build_ui() -> void:
	ui_root.theme = _theme

	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 14
	top.offset_bottom = 84
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_theme_stylebox_override("panel", _flat(SAGE_BG, 16, Vector4(20, 10, 20, 10), 10))
	ui_root.add_child(top)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(top_row)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Codefarm"
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_font(title_label, 24, CREAM, true)
	top_row.add_child(title_label)

	var ver := Label.new()
	ver.text = VERSION
	ver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_font(ver, 17, TEXT_DIM)
	title_label.tooltip_text = "Codefarm " + VERSION
	ver.queue_free()
	var resource_scroll := ScrollContainer.new()
	resource_scroll.name = "ResourceStrip"
	resource_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	resource_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	resource_scroll.custom_minimum_size = Vector2(70, 48)
	top_row.add_child(resource_scroll)
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 14)
	# Fill the strip so chips centre on the bar instead of hugging its top.
	resources.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_scroll.add_child(resources)

	var hay_chip := _resource_chip(FarmIcon.Kind.HAY, "HayLabel", FarmIcon.item_color("hay", GOLD_SOFT))
	hay_chip["row"].tooltip_text = "干草余额"
	hay_label = hay_chip["label"]
	resources.add_child(hay_chip["row"])

	var wood_chip := _resource_chip(FarmIcon.Kind.WOOD, "WoodLabel", FarmIcon.item_color("wood", GOLD_SOFT))
	wood_chip["row"].tooltip_text = "木头"
	wood_wrap = wood_chip["row"]
	wood_label = wood_chip["label"]
	wood_wrap.visible = false
	resources.add_child(wood_wrap)

	_item_chips = {}
	for spec in [
		["carrot", "胡萝卜"],
		["pumpkin", "南瓜"],
		["power", "能量"],
		["water_tank", "水"],
		["fertilizer", "肥料"],
		["weird", "奇怪物质"],
		["gold", "金子"],
		["cactus", "仙人掌"],
		["bone", "骨头"],
	]:
		var chip := _resource_chip(FarmIcon.kind_from_item(spec[0]), spec[0] + "Label", FarmIcon.item_color(spec[0], GOLD_SOFT))
		chip["row"].tooltip_text = spec[1]
		chip["row"].visible = false
		resources.add_child(chip["row"])
		_item_chips[spec[0]] = chip

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.queue_free()

	run_button = null
	stop_button = null
	code_btn = _make_icon_button(FarmIcon.Kind.CODE, "代码")
	code_btn.name = "CodeButton"
	skill_button = _make_icon_button(FarmIcon.Kind.SKILL, "技能树")
	skill_button.name = "SkillButton"
	hint_button = _make_icon_button(FarmIcon.Kind.HINT, "提示")
	hint_button.name = "HintButton"
	settings_button = _make_icon_button(FarmIcon.Kind.SETTINGS, "设置")
	settings_button.name = "SettingsButton"
	log_button = _make_icon_button(FarmIcon.Kind.LOG, "更新日志")
	log_button.name = "LogButton"
	reset_cam_button = _make_icon_button(FarmIcon.Kind.RESET_CAM, "回正视角")
	reset_cam_button.name = "ResetCameraButton"
	for b in [code_btn, skill_button, hint_button, settings_button]:
		top_row.add_child(b)
	# Secondary actions live in settings; retain their real handlers and icons.
	ui_root.add_child(log_button)
	ui_root.add_child(reset_cam_button)
	log_button.hide()
	reset_cam_button.hide()
	code_btn.pressed.connect(_toggle_code_window)
	skill_button.pressed.connect(func() -> void: _toggle_panel("skill"))
	hint_button.pressed.connect(_toggle_hint_window)
	settings_button.pressed.connect(func() -> void: _toggle_panel("settings"))
	log_button.pressed.connect(func() -> void: _toggle_panel("log"))
	reset_cam_button.pressed.connect(func() -> void: reset_camera(false))

	_build_code_window()
	_build_hint_window()

	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.07, 0.08, 0.07, 0.46)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	ui_root.add_child(backdrop)

	overlay_card = PanelContainer.new()
	overlay_card.name = "OverlayCard"
	overlay_card.visible = false
	overlay_card.set_anchors_preset(Control.PRESET_CENTER)
	overlay_card.offset_left = -560
	overlay_card.offset_right = 560
	overlay_card.offset_top = -460
	overlay_card.offset_bottom = 460
	overlay_card.add_theme_stylebox_override("panel", _flat(SAGE_DEEP, 20, Vector4(28, 22, 28, 22), 16))
	ui_root.add_child(overlay_card)
	_fit_overlay()
	get_viewport().size_changed.connect(_fit_overlay)

	var card_v := VBoxContainer.new()
	card_v.add_theme_constant_override("separation", 14)
	overlay_card.add_child(card_v)

	var head := HBoxContainer.new()
	card_v.add_child(head)
	overlay_title = Label.new()
	overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(overlay_title, 26, CREAM, true)
	head.add_child(overlay_title)
	_panel_tabs = preload("res://scripts/farm_tabs.gd").new()
	_panel_tabs.chosen.connect(func(id: String) -> void:
		if _open_panel != id:
			_toggle_panel(id)
	)
	head.add_child(_panel_tabs)
	overlay_close = _make_icon_button(FarmIcon.Kind.CLOSE, "关闭", false, Vector2(44, 44))
	overlay_close.pressed.connect(_close_panel)
	head.add_child(overlay_close)

	overlay_body = Control.new()
	overlay_body.name = "OverlayBody"
	overlay_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.custom_minimum_size = Vector2(0, 360)
	var body_clip := Control.new()
	body_clip.clip_contents = true
	body_clip.custom_minimum_size = Vector2(0, 360)
	body_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_v.add_child(body_clip)
	overlay_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_clip.add_child(overlay_body)


func _fit_overlay() -> void:
	if overlay_card == null:
		return
	FarmMotion.stop(overlay_card)
	var viewport_size := get_viewport().get_visible_rect().size
	var half_width := minf(560.0, (viewport_size.x - 48.0) * 0.5)
	var half_height := minf(410.0, (viewport_size.y - 72.0) * 0.5)
	overlay_card.offset_left = -half_width
	overlay_card.offset_right = half_width
	overlay_card.offset_top = -half_height
	overlay_card.offset_bottom = half_height
	overlay_card.set_meta("_fm_base_top", -half_height)
	overlay_card.set_meta("_fm_base_bot", half_height)
	if overlay_card.visible:
		if _open_panel.is_empty():
			# A resize must not cancel a closing tween and leave its invisible
			# backdrop permanently intercepting clicks.
			FarmMotion.close_overlay(backdrop, overlay_card, FarmMotion.CLOSE_DUR, true)
		else:
			overlay_card.modulate.a = 1.0
			backdrop.modulate.a = 1.0


func _window_bar_style() -> StyleBoxFlat:
	return _flat(Color(0.20, 0.24, 0.21, 1), 0, Vector4(12, 6, 10, 6), 0)


func _build_code_window() -> void:
	code_window = preload("res://scripts/farm_window.gd").new()
	code_window.name = "CodeWindow"
	ui_root.add_child(code_window)
	code_window.setup("代码", _make_button, _flat(SAGE_BG, 16, Vector4(0, 0, 0, 0), 14), _window_bar_style(), _apply_font)
	code_window.min_window_size = Vector2(360, 280)
	code_window.set_position(_code_default.position)
	code_window.set_size(_code_default.size)
	_attach_run_buttons(code_window)
	# FarmWindow owns its close animation; listeners must not hide it early.
	code_window.close_requested.connect(_restore_hint_after_code_max)
	code_window.maximize_changed.connect(_on_code_maximize_changed)
	code_window.resized.connect(func() -> void:
		if highlight:
			highlight.queue_redraw()
	)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	code_window.content.add_child(vbox)

	_file_bar_wrap = Control.new()
	_file_bar_wrap.name = "FileBarWrap"
	_file_bar_wrap.custom_minimum_size = Vector2(0, 32)
	_file_bar_wrap.visible = false
	vbox.add_child(_file_bar_wrap)
	_file_bar = HBoxContainer.new()
	_file_bar.name = "FileBar"
	_file_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_file_bar.add_theme_constant_override("separation", 6)
	_file_bar_wrap.add_child(_file_bar)

	var editor_wrap := Control.new()
	editor_wrap.name = "EditorWrap"
	editor_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_wrap.clip_contents = true
	var framework_note := Label.new()
	framework_note.name = "FrameworkNote"
	framework_note.text = "框架已锁定 · 在 main 内编写操作，可在 main 前添加函数"
	framework_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(framework_note, 14, Color(0.65, 0.75, 0.68))
	vbox.add_child(framework_note)
	vbox.add_child(editor_wrap)

	editor = preload("res://scripts/farm_code_editor.gd").new()
	editor.name = "CodeEditor"
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.gutters_draw_line_numbers = true
	editor.draw_tabs = false
	editor.draw_spaces = false
	editor.indent_automatic = true
	editor.indent_size = 4
	editor.indent_use_spaces = true
	editor.set_tab_size(4)
	editor.indent_wrapped_lines = true
	editor.auto_brace_completion_enabled = true
	editor.auto_brace_completion_highlight_matching = true
	editor.indent_automatic_prefixes = PackedStringArray(["{", ":"])
	editor.placeholder_text = "int main() { harvest(); }"
	editor.text = STARTER
	editor.highlight_current_line = true
	editor.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	var ed_style := _flat(Color(0.09, 0.11, 0.10, 1), 12, Vector4(14, 12, 14, 12))
	editor.add_theme_stylebox_override("normal", ed_style)
	editor.add_theme_stylebox_override("focus", ed_style)
	editor.add_theme_stylebox_override("read_only", ed_style)
	if _font_mono:
		editor.add_theme_font_override("font", _font_mono)
	_apply_editor_font_size()
	editor.add_theme_color_override("font_color", SYN_IDENT)
	editor.add_theme_color_override("font_readonly_color", TEXT_DIM)
	editor.add_theme_color_override("caret_color", GOLD_SOFT)
	editor.add_theme_color_override("current_line_color", Color(0.82, 0.68, 0.44, 0.06))
	editor.add_theme_color_override("selection_color", Color(0.78, 0.62, 0.38, 0.28))
	editor.add_theme_color_override("font_selected_color", CREAM)
	editor.add_theme_color_override("word_highlighted_color", Color(0.78, 0.62, 0.38, 0.16))
	editor.add_theme_color_override("brace_mismatch_color", DANGER)
	editor.add_theme_color_override("font_placeholder_color", Color(0.62, 0.60, 0.54, 0.55))
	editor.add_theme_color_override("completion_background_color", Color(0.14, 0.17, 0.15, 0.98))
	editor.add_theme_color_override("completion_selected_color", Color(0.78, 0.64, 0.42, 0.30))
	editor.add_theme_color_override("completion_existing_color", Color(0.78, 0.64, 0.42, 0.12))
	editor.add_theme_color_override("completion_font_color", CREAM)
	editor.add_theme_color_override("line_number_color", Color(0.70, 0.72, 0.66, 0.90))
	editor.add_theme_constant_override("caret_width", 2)
	editor.gui_input.connect(_on_editor_gui_input)
	editor.focus_entered.connect(_on_editor_focus_entered)
	editor.resized.connect(func() -> void:
		if highlight:
			highlight.queue_redraw()
	)
	editor_wrap.add_child(editor)
	editor.framework_blocked.connect(func() -> void:
		framework_note.text = "固定框架受保护 · 请在 main 内编写，或在前面空行添加函数"
		FarmMotion.stop(framework_note)
		framework_note.modulate.a = 0.6
		var notice := framework_note.create_tween()
		framework_note.set_meta("_fm_tw", notice)
		notice.tween_property(framework_note, "modulate:a", 1.0, 0.2)
	)

	font_badge = Label.new()
	font_badge.name = "FontBadge"
	font_badge.text = "100%"
	font_badge.visible = false
	font_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	font_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	font_badge.tooltip_text = "双击复位字号"
	font_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	font_badge.anchor_left = 1.0
	font_badge.anchor_top = 1.0
	font_badge.anchor_right = 1.0
	font_badge.anchor_bottom = 1.0
	font_badge.offset_left = -78
	font_badge.offset_top = -28
	font_badge.offset_right = -10
	font_badge.offset_bottom = -8
	font_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(font_badge, 16, GOLD_SOFT, true)
	font_badge.gui_input.connect(_on_font_badge_input)
	editor_wrap.add_child(font_badge)

	highlight = preload("res://scripts/highlight_overlay.gd").new()
	highlight.name = "HighlightOverlay"
	editor_wrap.add_child(highlight)
	highlight.set_editor(editor)

	error_markup = preload("res://scripts/error_markup.gd").new()
	error_markup.name = "ErrorMarkup"
	editor_wrap.add_child(error_markup)
	error_markup.set_editor(editor, _font_ui, _font_mono)
	var diagnostic_dock := ScrollContainer.new()
	diagnostic_dock.name = "DiagnosticDock"
	diagnostic_dock.custom_minimum_size = Vector2(0, 112)
	diagnostic_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	diagnostic_dock.visible = false
	vbox.add_child(diagnostic_dock)
	error_markup.set_diagnostic_dock(diagnostic_dock)


func _build_hint_window() -> void:
	hint_window = preload("res://scripts/farm_window.gd").new()
	hint_window.name = "HintWindow"
	ui_root.add_child(hint_window)
	hint_window.setup("提示", _make_button, _flat(SAGE_BG, 16, Vector4(0, 0, 0, 0), 14), _window_bar_style(), _apply_font)
	hint_window.min_window_size = Vector2(360, 180)
	hint_window.set_position(_hint_default.position)
	hint_window.set_size(_hint_default.size)
	hint_window.close_requested.connect(func() -> void:
		_hint_stash_visible = false
		_hint_stashed = false
		code_window.max_bottom_margin = 10.0
		code_window.refresh_max_rect()
	)
	hint_window.resized.connect(func() -> void: _refresh_hint_layout())

	hint_scroll = ScrollContainer.new()
	hint_scroll.name = "HintScroll"
	hint_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	hint_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	hint_window.content.add_child(hint_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 20)
	hint_scroll.add_child(margin)
	var hint_col := VBoxContainer.new()
	hint_col.name = "HintCol"
	hint_col.add_theme_constant_override("separation", 10)
	hint_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(hint_col)
	hint_body_label = Label.new()
	hint_body_label.name = "HintBody"
	hint_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_apply_font(hint_body_label, 20, TEXT)
	hint_col.add_child(hint_body_label)
	hint_next_label = Label.new()
	hint_next_label.name = "HintNextLabel"
	_apply_font(hint_next_label, 17, GOLD_SOFT)
	hint_col.add_child(hint_next_label)
	hint_next_code = CodeEdit.new()
	hint_next_code.name = "HintNextCode"
	hint_next_code.editable = false
	hint_next_code.caret_blink = false
	hint_next_code.context_menu_enabled = false
	hint_next_code.highlight_current_line = false
	hint_next_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	hint_next_code.scroll_fit_content_height = true
	hint_next_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _font_mono:
		hint_next_code.add_theme_font_override("font", _font_mono)
	hint_next_code.add_theme_font_size_override("font_size", _font_size_default)
	hint_next_code.add_theme_color_override("font_readonly_color", SYN_IDENT)
	var next_style := _flat(Color(0.09, 0.11, 0.10, 1), 10, Vector4(12, 10, 12, 10))
	for state in ["normal", "read_only", "focus"]:
		hint_next_code.add_theme_stylebox_override(state, next_style)
	hint_col.add_child(hint_next_code)
	var next_step := Label.new()
	next_step.name = "HintNextStep"
	next_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(next_step, 17, TEXT)
	hint_col.add_child(next_step)
	var bar := HBoxContainer.new()
	bar.name = "HintExemplarBar"
	bar.add_theme_constant_override("separation", 8)
	hint_col.add_child(bar)
	hint_exemplar_toggle = _make_button("范本 ▾", false, 90)
	hint_exemplar_toggle.name = "HintExemplarToggle"
	hint_exemplar_toggle.tooltip_text = "展开或收起范本"
	hint_exemplar_toggle.pressed.connect(_toggle_hint_exemplar)
	bar.add_child(hint_exemplar_toggle)
	hint_copy_button = _make_button("复制", false, 88)
	hint_copy_button.name = "HintCopyExemplar"
	hint_copy_button.tooltip_text = "复制完整主程序到剪贴板"
	hint_copy_button.pressed.connect(_copy_hint_exemplar)
	bar.add_child(hint_copy_button)
	hint_load_button = _make_button("载入", false, 76)
	hint_load_button.name = "HintLoadExemplar"
	hint_load_button.tooltip_text = "替换 main.cpp，并载入配套头文件"
	hint_load_button.pressed.connect(_load_hint_exemplar)
	bar.add_child(hint_load_button)
	hint_copied_label = Label.new()
	hint_copied_label.name = "HintCopied"
	hint_copied_label.text = "已复制"
	hint_copied_label.visible = false
	_apply_font(hint_copied_label, 17, GOLD_SOFT)
	bar.add_child(hint_copied_label)
	hint_code = CodeEdit.new()
	hint_code.name = "HintCode"
	hint_code.editable = false
	hint_code.gutters_draw_line_numbers = true
	hint_code.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	hint_code.scroll_fit_content_height = true
	hint_code.context_menu_enabled = false
	hint_code.caret_blink = false
	hint_code.highlight_current_line = false
	hint_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _font_mono:
		hint_code.add_theme_font_override("font", _font_mono)
	hint_code.add_theme_font_size_override("font_size", _font_size_default)
	hint_code.add_theme_color_override("font_color", SYN_IDENT)
	hint_code.add_theme_color_override("font_readonly_color", SYN_IDENT)
	hint_code.add_theme_color_override("line_number_color", Color(0.70, 0.72, 0.66, 0.90))
	var hint_ed := _flat(Color(0.09, 0.11, 0.10, 1), 10, Vector4(12, 10, 12, 10))
	hint_code.add_theme_stylebox_override("normal", hint_ed)
	hint_code.add_theme_stylebox_override("read_only", hint_ed)
	hint_code.add_theme_stylebox_override("focus", hint_ed)
	hint_col.add_child(hint_code)
	var header_bar := HBoxContainer.new()
	header_bar.name = "HintHeaderBar"
	header_bar.add_theme_constant_override("separation", 8)
	hint_col.add_child(header_bar)
	hint_header_label = Label.new()
	hint_header_label.name = "HintHeaderName"
	hint_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(hint_header_label, 18, TEXT)
	header_bar.add_child(hint_header_label)
	hint_header_copy = _make_button("复制", false, 88)
	hint_header_copy.name = "HintCopyHeader"
	hint_header_copy.tooltip_text = "复制这个头文件"
	hint_header_copy.pressed.connect(_copy_hint_header)
	header_bar.add_child(hint_header_copy)
	hint_header_code = hint_code.duplicate() as CodeEdit
	hint_header_code.name = "HintHeaderCode"
	hint_col.add_child(hint_header_code)
	hint_prose_after = Label.new()
	hint_prose_after.name = "HintAfter"
	hint_prose_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_prose_after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(hint_prose_after, 16, TEXT)
	hint_col.add_child(hint_prose_after)
	hint_col.move_child(hint_prose_after, hint_code.get_index())
	hint_line = hint_body_label


func _toggle_code_window() -> void:
	if code_window == null:
		return
	if code_window.visible and not code_window.minimized and not code_window.is_closing():
		if code_window.has_method("dismiss"):
			code_window.call("dismiss")
		else:
			code_window.visible = false
		return
	code_window.reveal(code_window.current_restore_rect())
	code_window.move_to_front()


func _toggle_hint_window() -> void:
	if hint_window == null:
		return
	if hint_window.visible and not hint_window.minimized and _open_panel != "hint":
		# Refresh text and bring forward; second click hides.
		if hint_window.has_focus() or true:
			pass
	if hint_window.visible and not hint_window.minimized and not hint_window.is_closing():
		if hint_window.has_method("dismiss"):
			hint_window.call("dismiss")
		else:
			hint_window.visible = false
		return
	_apply_hint_text()
	hint_window.reveal(hint_window.current_restore_rect())
	hint_window.move_to_front()
	_refresh_hint_layout()


func _refresh_hint_layout() -> void:
	if hint_body_label == null or hint_scroll == null:
		return
	var width := hint_scroll.size.x
	if width < 80.0 and hint_window:
		width = maxf(80.0, hint_window.size.x - 44.0)
	width = maxf(160.0, width - 36.0)
	for node in [hint_body_label, hint_prose_after, hint_next_label, hint_scroll.find_child("HintNextStep", true, false)]:
		if node == null or not node.visible or node.text.is_empty():
			if node:
				node.custom_minimum_size = Vector2(width, 0)
			continue
		var font: Font = node.get_theme_font("font")
		var fs: int = node.get_theme_font_size("font_size")
		var height := 24.0
		if font:
			var sz := font.get_multiline_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, width, fs)
			height = sz.y + 8.0
		node.custom_minimum_size = Vector2(width, height)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hint_next_code and hint_next_code.visible:
		hint_next_code.custom_minimum_size = Vector2(width, 0)
	for code_box in [hint_code, hint_header_code]:
		if code_box and code_box.visible:
			var lines := maxi(code_box.get_line_count(), 1)
			var fs := _font_size_default
			code_box.custom_minimum_size = Vector2(width, float(lines) * float(fs + 8) + 24.0)


func _on_code_maximize_changed(is_max: bool) -> void:
	if is_max:
		_stash_hint_for_code_max()
	else:
		_restore_hint_after_code_max()
	if highlight:
		highlight.queue_redraw()


func _stash_hint_for_code_max() -> void:
	if hint_window == null or _hint_stashed:
		return
	_hint_stashed = true
	_hint_stash_visible = hint_window.visible
	_hint_stash_minimized = bool(hint_window.get("minimized"))
	_hint_stash_maximized = bool(hint_window.get("maximized"))
	_hint_stash_rect = hint_window.current_restore_rect()
	if _hint_stash_visible:
		code_window.max_bottom_margin = 64.0
		if not _hint_stash_minimized and hint_window.has_method("set_minimized"):
			hint_window.call("set_minimized", true, true)
	else:
		code_window.max_bottom_margin = 10.0
	if code_window.has_method("refresh_max_rect"):
		code_window.call("refresh_max_rect")


func _restore_hint_after_code_max() -> void:
	if hint_window == null or not _hint_stashed:
		return
	_hint_stashed = false
	code_window.max_bottom_margin = 10.0
	if not _hint_stash_visible:
		hint_window.visible = false
		return
	hint_window.visible = true
	if hint_window.has_method("set_minimized"):
		hint_window.call("set_minimized", _hint_stash_minimized, true)
	if not _hint_stash_minimized:
		hint_window.reveal(_hint_stash_rect)
		if _hint_stash_maximized and not hint_window.maximized:
			hint_window.toggle_maximize()
	_refresh_hint_layout()


func _apply_editor_font_size() -> void:
	if editor == null:
		return
	var px := int(round(_font_display))
	editor.add_theme_font_size_override("font_size", px)
	editor.add_theme_constant_override("line_spacing", 6 if px < 19 else 8)
	editor.add_theme_font_size_override("completion_font_size", maxi(14, px - 2))
	if highlight:
		highlight.queue_redraw()
	_keep_font_anchor()


func _font_percent() -> int:
	return int(round(100.0 * float(_font_size) / float(_font_size_default)))


func _show_font_badge() -> void:
	if font_badge == null:
		return
	font_badge.text = "%d%%" % _font_percent()
	font_badge.visible = true
	font_badge.modulate = Color(1, 1, 1, 1)
	if _font_badge_tween and is_instance_valid(_font_badge_tween):
		_font_badge_tween.kill()
	_font_badge_tween = create_tween()
	_font_badge_tween.tween_interval(0.7)
	_font_badge_tween.tween_property(font_badge, "modulate:a", 0.0, 0.28)
	_font_badge_tween.tween_callback(func() -> void:
		if font_badge:
			font_badge.visible = false
			font_badge.modulate = Color(1, 1, 1, 1)
	)


func _on_font_badge_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		reset_editor_font()
		get_viewport().set_input_as_handled()


func reset_editor_font() -> void:
	_set_editor_font_size(_font_size_default, true)


func _set_editor_font_size(size: int, animate: bool, anchor: bool = true) -> void:
	size = clampi(size, FONT_SIZE_MIN, FONT_SIZE_MAX)
	if anchor and editor:
		var local := editor.get_local_mouse_position()
		var lc: Vector2i = editor.get_line_column_at_pos(local, true)
		_font_anchor_line = lc.y
		_font_anchor_y = local.y
	else:
		_font_anchor_line = -1
	_font_size = size
	if _font_tween and is_instance_valid(_font_tween):
		_font_tween.kill()
	if not animate:
		_font_display = float(size)
		_apply_editor_font_size()
		_show_font_badge()
		return
	_font_tween = create_tween()
	_font_tween.tween_method(_tick_font_display, _font_display, float(size), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_font_badge()


func _tick_font_display(value: float) -> void:
	_font_display = value
	_apply_editor_font_size()


func _keep_font_anchor() -> void:
	if editor == null or _font_anchor_line < 0:
		return
	var after: Vector2 = editor.get_pos_at_line_column(_font_anchor_line, 0)
	var delta: float = after.y - _font_anchor_y
	if absf(delta) < 0.5:
		return
	var line_h := float(editor.get_line_height())
	if line_h <= 0.1:
		return
	editor.scroll_vertical = editor.scroll_vertical + delta / line_h


func _handle_font_zoom(event: InputEventMouseButton) -> void:
	var notch := event.factor if event.factor != 0.0 else 1.0
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		notch = -notch
	elif event.button_index != MOUSE_BUTTON_WHEEL_UP:
		return
	_font_zoom_accum += notch
	if absf(_font_zoom_accum) < 0.85:
		return
	var steps := int(_font_zoom_accum)
	if steps == 0:
		steps = 1 if _font_zoom_accum > 0.0 else -1
	_font_zoom_accum -= float(steps)
	_set_editor_font_size(_font_size + steps, true, true)


func _attach_run_buttons(win: FarmWindow) -> void:
	if win.tools_left == null:
		return
	run_loop_button = FarmRunButton.new()
	run_loop_button.name = "RunLoopButton"
	run_loop_button.mode = FarmRunButton.Mode.LOOP
	run_loop_button.tooltip_text = "运行"
	run_loop_button.pressed.connect(_on_run)
	run_once_button = FarmRunButton.new()
	run_once_button.name = "RunOnceButton"
	run_once_button.mode = FarmRunButton.Mode.ONCE
	run_once_button.tooltip_text = "单步"
	run_once_button.pressed.connect(_on_step)
	win.tools_left.add_child(run_loop_button)
	win.tools_left.add_child(run_once_button)


func _on_editor_gui_input(event: InputEvent) -> void:
	if editor == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			if mb.shift_pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				if mb.pressed:
					_handle_font_zoom(mb)
				editor.accept_event()
				var vp := editor.get_viewport()
				if vp:
					vp.set_input_as_handled()
				return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if host.is_running() or host.is_paused() or _stepping:
				_on_stop()
			_maybe_dismiss_error_on_click(mb.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and (event.keycode == KEY_0 or event.keycode == KEY_KP_0):
			reset_editor_font()
			editor.accept_event()
			var vp2 := editor.get_viewport()
			if vp2:
				vp2.set_input_as_handled()
			return
		if editor.editable and event.keycode == KEY_BACKSPACE and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			if not editor.has_selection() and _try_smart_backspace():
				editor.accept_event()
				var vp3 := editor.get_viewport()
				if vp3:
					vp3.set_input_as_handled()


func _try_smart_backspace() -> bool:
	var line_i := editor.get_caret_line()
	var col := editor.get_caret_column()
	if col <= 0:
		return false
	var line := editor.get_line(line_i)
	var prefix := line.substr(0, col)
	if prefix.is_empty():
		return false
	for i in prefix.length():
		var ch := prefix[i]
		if ch != " " and ch != "\t":
			return false
	var step: int = editor.indent_size if editor.indent_size > 0 else 4
	var remove := col % step
	if remove == 0:
		remove = step
	remove = mini(remove, col)
	editor.begin_complex_operation()
	editor.select(line_i, col - remove, line_i, col)
	editor.delete_selection()
	editor.end_complex_operation()
	return true


func _setup_highlighter() -> void:
	var hl := CodeHighlighter.new()
	hl.number_color = SYN_NUMBER
	hl.symbol_color = SYN_SYMBOL
	hl.function_color = SYN_FUNC
	hl.member_variable_color = SYN_IDENT
	for word in ["while", "if", "else", "for", "return", "using", "namespace", "switch", "case", "break", "default", "continue", "do"]:
		hl.add_keyword_color(word, SYN_KEYWORD)
	for word in ["int", "void", "enum", "class", "struct", "bool", "double", "float", "char", "string", "auto", "const", "constexpr", "include",
			"Dir", "Entity", "Ground", "Item", "Cost", "Measure", "Companion", "Hat", "Unlock"]:
		hl.add_keyword_color(word, SYN_TYPE)
	hl.add_keyword_color("true", SYN_ENUM)
	hl.add_keyword_color("false", SYN_ENUM)
	hl.add_keyword_color("std", SYN_STD)
	for word in ["East", "West", "North", "South", "Grass", "Bush", "None", "Grassland", "Soil",
			"Tree", "Carrot", "Sunflower", "Pumpkin", "DeadPumpkin", "Cactus", "Treasure", "Hedge", "Apple",
			"Hay", "Wood", "Water", "Fertilizer", "WeirdSubstance", "Gold", "Bone", "Power",
			"DinosaurHat", "StrawHat", "TopHat", "Pumpkins"]:
		hl.add_keyword_color(word, SYN_ENUM)
	hl.add_color_region("//", "", SYN_COMMENT, true)
	hl.add_color_region("/*", "*/", SYN_COMMENT, false)
	hl.add_color_region("#", "", SYN_PREPROC, true)
	hl.add_color_region("\"", "\"", SYN_STRING, false)
	hl.add_color_region("'", "'", SYN_STRING, false)
	editor.syntax_highlighter = hl
	_code_highlighter = hl
	editor.highlight_all_occurrences = true
	editor.caret_blink = true
	if hint_code:
		hint_code.syntax_highlighter = hl.duplicate()
	if hint_header_code:
		hint_header_code.syntax_highlighter = hl.duplicate()


func _setup_completion() -> void:
	editor.code_completion_enabled = true
	editor.code_completion_prefixes = PackedStringArray()
	editor.code_completion_requested.connect(_on_completion_requested)
	editor.text_changed.connect(_on_editor_text_changed)


func _on_editor_text_changed() -> void:
	_queue_save(true)
	_maybe_dismiss_error_on_edit()
	if _pending_paren_adjust:
		_pending_paren_adjust = false
		_adjust_caret_in_parens()
	var prefix := _ident_prefix()
	if prefix.length() >= 1 and _prefix_is_ident(prefix) and not _caret_in_comment():
		if prefix != _completion_prefix:
			_completion_prefix = prefix
			editor.request_code_completion(true)
	else:
		_completion_prefix = ""


func _prefix_is_ident(prefix: String) -> bool:
	if prefix.is_empty():
		return false
	var ch := prefix.unicode_at(0)
	return (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95


func _ident_prefix() -> String:
	var line := editor.get_line(editor.get_caret_line())
	var col := editor.get_caret_column()
	var i := col - 1
	while i >= 0:
		var ch := line.unicode_at(i)
		var ok := (ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95
		if not ok:
			break
		i -= 1
	return line.substr(i + 1, col - (i + 1))


func _caret_in_comment() -> bool:
	var line := editor.get_line(editor.get_caret_line())
	var col := editor.get_caret_column()
	var trimmed := line.strip_edges()
	if trimmed.begins_with("#"):
		return true
	var slash := line.find("//")
	return slash >= 0 and slash < col


func _inside_move_call() -> bool:
	var line := editor.get_line(editor.get_caret_line())
	var col := editor.get_caret_column()
	var before := line.substr(0, col)
	var open := before.rfind("move(")
	if open < 0:
		return false
	var close := before.rfind(")")
	return close < open


func _on_completion_requested() -> void:
	var prefix := _ident_prefix()
	_completion_prefix = prefix
	var items := _completion_items()
	if _inside_move_call() and host.movement_unlocked():
		items = _dir_items() + items
	var seen := {}
	for item in items:
		var display: String = item[0]
		var insert: String = item[1]
		var kind: int = item[2]
		var color: Color = item[3]
		if prefix != "" and not insert.begins_with(prefix) and not display.begins_with(prefix):
			var lower_ins := insert.to_lower()
			var lower_pre := prefix.to_lower()
			if not lower_ins.begins_with(lower_pre) and display.find(prefix) < 0:
				continue
		if seen.has(insert):
			continue
		seen[insert] = true
		editor.add_code_completion_option(kind, display, insert, color)
	editor.update_code_completion_options(true)
	_pending_paren_adjust = true


func _completion_items() -> Array:
	var fn := SYN_FUNC
	var kw := SYN_KEYWORD
	var sn := SYN_TYPE
	var en := SYN_ENUM
	var kind_fn := CodeEdit.KIND_FUNCTION
	var kind_kw := CodeEdit.KIND_PLAIN_TEXT
	var kind_const := CodeEdit.KIND_CONSTANT
	var items: Array = []
	items.append(["harvest()    收割成熟的草", "harvest()", kind_fn, fn])
	items.append(["do_a_flip()    翻一个跟头", "do_a_flip()", kind_fn, fn])
	if host.movement_unlocked():
		items.append(["move(East)    向东走一格，边缘环绕", "move(East)", kind_fn, fn])
		items.append(["move(West)    向西走一格", "move(West)", kind_fn, fn])
		items.append(["move(North)    向北走一格", "move(North)", kind_fn, fn])
		items.append(["move(South)    向南走一格", "move(South)", kind_fn, fn])
		for d in ["East", "West", "North", "South"]:
			items.append([d + "    方向", d, kind_const, GOLD_SOFT])
	if host.for_unlocked():
		items.append(["for (int i = 0; i < 3; i++)    计数循环，走过一垄", "for (int i = 0; i < 3; i++) {\n        \n    }", kind_kw, sn])
	if host.till_unlocked():
		items.append(["till()    把草地翻成耕地，或把耕地翻回草地", "till()", kind_fn, fn])
	if host.plant_unlocked():
		items.append(["plant(Bush)    在空的耕地上种灌木", "plant(Bush)", kind_fn, fn])
		items.append(["get_entity_type()    脚下的作物", "get_entity_type()", kind_fn, fn])
		items.append(["get_ground_type()    脚下的地面", "get_ground_type()", kind_fn, fn])
		for d in ["Bush", "Grass", "None", "Soil", "Grassland"]:
			items.append([d + "    实体或地面", d, kind_const, GOLD_SOFT])
	items.append(["int    整数类型 / 入口返回值", "int", kind_kw, kw])
	items.append(["return    结束 main", "return", kind_kw, kw])
	items.append(["using    例如 using namespace std;", "using", kind_kw, kw])
	items.append(["namespace    与 using 一起用", "namespace", kind_kw, kw])
	items.append(["else    否则", "else", kind_kw, kw])
	items.append(["true", "true", kind_kw, kw])
	items.append(["false", "false", kind_kw, kw])
	items.append(["enum    枚举声明", "enum", kind_kw, kw])
	items.append(["void", "void", kind_kw, kw])
	if host.loops_unlocked():
		items.append(["while    循环", "while", kind_kw, kw])
		if host.conditions_unlocked():
			items.append(["while (true) { … }    循环收割模板", "while (true) {\n        if (can_harvest()) {\n            harvest();\n        }\n    }", kind_kw, sn])
		else:
			items.append(["while (true) { harvest(); }    循环收割", "while (true) {\n        harvest();\n    }", kind_kw, sn])
	if host.conditions_unlocked():
		items.append(["if    条件判断", "if", kind_kw, kw])
		items.append(["can_harvest()    脚下的作物是否成熟", "can_harvest()", kind_fn, fn])
		items.append(["if (can_harvest()) { harvest(); }    成熟再收", "if (can_harvest()) {\n        harvest();\n    }", kind_kw, sn])
	items.append(["int main()    标准入口模板", "int main() {\n    \n    return 0;\n}", kind_kw, sn])
	items.append(["#include <bits/stdc++.h>", "#include <bits/stdc++.h>", kind_kw, sn])
	return items


func _dir_items() -> Array:
	var items: Array = []
	for d in [["East", "向东"], ["West", "向西"], ["North", "向北"], ["South", "向南"]]:
		items.append([d[0] + "    " + d[1], d[0], CodeEdit.KIND_CONSTANT, SYN_ENUM])
	return items


func _adjust_caret_in_parens() -> void:
	var line := editor.get_line(editor.get_caret_line())
	var col := editor.get_caret_column()
	if col >= 2 and col <= line.length() and line[col - 1] == ")" and line[col - 2] == "(":
		editor.set_caret_column(col - 1)


func _advance_sim(delta: float) -> void:
	if _stepping and (host.is_running() or host.is_paused()):
		host.step_seconds(delta)
		if host.is_finished() or host.last_error() != "":
			_stepping = false
		elif host.is_paused():
			_stepping = false
			if editor:
				editor.editable = true
			_update_buttons()
		return
	host.advance_seconds(delta)


func _process(delta: float) -> void:
	if _session_phase != "playing":
		_tick_intro(delta)
		return
	_save_elapsed += delta
	if _save_elapsed >= 5.0:
		_save_elapsed = 0.0
		_queue_save()
	_hover_t += delta
	camera_rig.update_input(delta)
	_advance_sim(delta)
	var err: String = host.last_error()
	if err != "":
		_stepping = false
		if not _error_latched:
			_present_host_error(true)
		if _error_runtime:
			_sync_highlight(delta)
		if editor:
			editor.editable = true
		_update_buttons()
	elif host.is_running() or host.is_paused() or _stepping:
		_sync_highlight(delta)
		if host.take_flip_pulse():
			_play_flip()
		if (not _tilling) and str(host.current_action()) == "till" and float(host.current_action_progress()) < 0.28:
			_play_till_hoe()
	elif host.is_finished():
		_clear_highlight()
		_update_buttons()

	# These signals describe the result at action START. Grass becoming ripe
	# during a failed swing must never turn it into a successful harvest effect.
	var harvested: bool = host.take_harvest_pulse()
	var missed: bool = host.take_harvest_miss_pulse()
	if harvested:
		_play_harvest_juice()
		_queue_save()
	elif missed:
		_play_harvest_swing(false)
		_sfx("miss")

	_ensure_farm_size(host.get_world_size())
	_update_grass(delta)
	_sync_drone_fleet()
	_update_drone(delta)
	_refresh_file_bar_visibility()
	camera_rig.update(delta)
	_update_hay()
	_maybe_unlock_hint()
	if _open_panel == "skill":
		var pulse := 0.5 + 0.5 * sin(_hover_t * 2.4)
		for card in _skill_glow_nodes:
			if card is Control and is_instance_valid(card):
				var m := 1.0 + 0.08 * pulse
				(card as Control).modulate = Color(m, m, 0.92 + 0.08 * pulse, 1)


func _on_run() -> void:
	if host.is_running() and not host.is_paused() and not _stepping:
		_on_stop()
		return
	_stepping = false
	if host.is_paused():
		host.resume()
		if editor:
			editor.release_focus()
			editor.editable = false
		_update_buttons()
		return
	_start_program()


func _on_run_loop() -> void:
	_on_run()


func _on_run_once() -> void:
	_on_run()


func _on_step() -> void:
	if host.is_running() and not host.is_paused():
		if _stepping:
			_on_stop()
			return
		_stepping = true
		_update_buttons()
		return
	if host.is_paused():
		_stepping = true
		host.resume()
		if editor:
			editor.release_focus()
			editor.editable = false
		_update_buttons()
		return
	_start_program()
	_stepping = true


func _start_program() -> void:
	if host.is_running():
		return
	_clear_error_markup()
	_clear_highlight()
	_flush_active_file()
	_push_includes_to_host()
	var src := editor.text if _active_file == "main.cpp" else str(_user_files.get("main.cpp", editor.text))
	if _active_file != "main.cpp" and _user_files.has("main.cpp"):
		src = str(_user_files["main.cpp"])
	# Always run the main file; unsaved current include is already pushed.
	if _active_file == "main.cpp":
		src = editor.text
	var err: String = host.load_script(src)
	if err != "":
		_present_host_error(false)
		_stepping = false
		_update_buttons()
		return
	if editor:
		editor.release_focus()
	host.start()
	if editor:
		editor.editable = false
	_update_buttons()


func _on_stop() -> void:
	_stepping = false
	host.stop()
	_harvesting = false
	_flipping = false
	_tilling = false
	if editor:
		editor.editable = true
	_clear_highlight()
	_update_buttons()


func _on_editor_focus_entered() -> void:
	if host.is_running() or host.is_paused() or _stepping:
		_on_stop()


func _update_hay() -> void:
	if hay_label:
		hay_label.text = str(host.get_hay())
	if wood_label:
		wood_label.text = str(host.get_wood())
	if wood_wrap:
		wood_wrap.visible = host.get_wood() > 0 or host.plant_unlocked()
	if _item_chips:
		for key in _item_chips.keys():
			var chip: Dictionary = _item_chips[key]
			var n := int(host.get_item(key))
			chip["label"].text = str(n)
			var show := n > 0
			if key == "carrot":
				show = show or host.is_unlocked("carrot")
			elif key == "pumpkin":
				show = show or host.is_unlocked("pumpkin")
			elif key == "power":
				show = show or host.is_unlocked("sun")
			elif key == "water_tank":
				show = show or host.is_unlocked("water")
			elif key == "fertilizer" or key == "weird":
				show = show or host.is_unlocked("fert")
			elif key == "gold":
				show = show or host.is_unlocked("maze")
			elif key == "cactus":
				show = show or host.is_unlocked("cactus")
			elif key == "bone":
				show = show or host.is_unlocked("dino")
			chip["row"].visible = show


func _update_buttons() -> void:
	var running: bool = host.is_running()
	var paused: bool = host.is_paused()
	if run_loop_button:
		run_loop_button.active = running and not _stepping and not paused
	if run_once_button:
		run_once_button.active = _stepping and running
	if not running and not _stepping and editor:
		editor.editable = true


func _skill_owned(id: String) -> bool:
	return id == "harvest" or bool(host.is_unlocked(id))


# The skill the hint is about: the one bought last, else the furthest owned
# skill along the playthrough order.
func _hint_skill() -> String:
	if hint_skill_id != "" and _skill_owned(hint_skill_id):
		return hint_skill_id
	var best := "harvest"
	for id in FarmSkillData.EXEMPLAR_ORDER:
		if _skill_owned(str(id)):
			best = str(id)
	return best


func _skill_display_name(id: String) -> String:
	for n in _skill_nodes():
		if str(n["id"]) == id:
			return str(n["name"])
	return id


func _hint_header() -> Dictionary:
	var headers := FarmSkillData.exemplar_headers(_hint_skill())
	for k in headers.keys():
		return {"name": str(k), "text": str(headers[k])}
	return {}


func _apply_hint_text() -> void:
	if hint_line == null:
		return
	var id := _hint_skill()
	# One sentence of pain, then the exemplar.
	hint_body_label.text = "%s：%s" % [_skill_display_name(id), FarmSkillData.pain(id)]
	hint_body_label.visible = true
	var focus_line := FarmSkillData.next_line(id)
	hint_next_label.text = "买「条件」后，在 while 里加这一行" if id == "speed" else "这一行写在原有 while 里" if id == "iff" else "这次用到"
	hint_next_label.visible = not focus_line.is_empty()
	hint_next_code.text = focus_line
	hint_next_code.visible = not focus_line.is_empty()
	if _code_highlighter:
		hint_next_code.syntax_highlighter = _code_highlighter.duplicate()
	var next_step: Label = hint_scroll.find_child("HintNextStep", true, false)
	next_step.text = "停循环，等熟单收 → 攒 12 干草买「条件」。" if id == "speed" else "未熟时只查询，不伤幼苗。" if id == "iff" else ""
	if next_step.text.is_empty():
		next_step.text = FarmSkillData.remedy(id)
	next_step.visible = not next_step.text.is_empty()
	var code := FarmSkillData.exemplar(id)
	if code.is_empty():
		code = _skill_template(id)
	var has_code := not code.is_empty()
	if hint_exemplar_toggle:
		hint_exemplar_toggle.visible = has_code
		hint_exemplar_toggle.text = "范本 ▾" if _hint_exemplar_open else "范本 ▸"
	if hint_copy_button:
		hint_copy_button.visible = has_code
	if hint_load_button:
		hint_load_button.visible = has_code
	if hint_code:
		hint_code.text = code
		hint_code.visible = has_code and _hint_exemplar_open
		hint_code.add_theme_font_size_override("font_size", _font_size_default)
		if _code_highlighter:
			hint_code.syntax_highlighter = _code_highlighter.duplicate()
	var header := _hint_header()
	var show_header := not header.is_empty() and _hint_exemplar_open
	if hint_header_label:
		hint_header_label.text = "还要新建 %s：" % str(header.get("name", "")) if show_header else ""
		hint_header_label.get_parent().visible = show_header
	if hint_header_code:
		hint_header_code.text = str(header.get("text", ""))
		hint_header_code.visible = show_header
		hint_header_code.add_theme_font_size_override("font_size", _font_size_default)
		if _code_highlighter:
			hint_header_code.syntax_highlighter = _code_highlighter.duplicate()
	if hint_prose_after:
		hint_prose_after.text = "复制完整程序；载入会替换主程序。"
		hint_prose_after.visible = has_code and _hint_exemplar_open
	_refresh_hint_layout()
	# Sizes settle a frame later (e.g. right after a reset); lay out again then.
	call_deferred("_refresh_hint_layout")


func _toggle_hint_exemplar() -> void:
	_hint_exemplar_open = not _hint_exemplar_open
	_apply_hint_text()


func _flash_copied(label: Label) -> void:
	if label == null:
		return
	label.visible = true
	label.modulate = Color(1, 1, 1, 1)
	FarmMotion.stop(label, "_copied")
	var tw := label.create_tween()
	label.set_meta("_copied", tw)
	tw.tween_interval(0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.visible = false
			label.modulate = Color(1, 1, 1, 1)
	)


func _copy_hint_exemplar() -> void:
	var text := FarmSkillData.exemplar(_hint_skill())
	if text.is_empty():
		return
	last_copied_template = text
	DisplayServer.clipboard_set(text)
	_flash_copied(hint_copied_label)


func _copy_hint_header() -> void:
	var header := _hint_header()
	if header.is_empty():
		return
	last_copied_template = str(header["text"])
	DisplayServer.clipboard_set(last_copied_template)
	_flash_copied(hint_copied_label)


func _maybe_unlock_hint(refresh_panel: bool = true) -> void:
	var changed := false
	if host.loops_unlocked() and not _loops_seen:
		_loops_seen = true
		changed = true
	if host.speed_unlocked() and not _speed_seen:
		_speed_seen = true
		changed = true
	if host.conditions_unlocked() and not _if_seen:
		_if_seen = true
		changed = true
	if host.movement_unlocked() and not _move_seen:
		_move_seen = true
		changed = true
	if host.for_unlocked() and not _for_seen:
		_for_seen = true
		changed = true
	if host.till_unlocked() and not _till_seen:
		_till_seen = true
		changed = true
	if host.plant_unlocked() and not _plant_seen:
		_plant_seen = true
		changed = true
	if changed:
		_apply_hint_text()
		if hint_window and hint_window.visible:
			_apply_hint_text()
		if refresh_panel and _open_panel == "skill":
			_fill_panel("skill")
		elif refresh_panel and _open_panel == "hint":
			_fill_panel("hint")



func _present_host_error(runtime: bool) -> void:
	var message := str(host.last_error())
	if message.is_empty():
		return
	_error_latched = true
	_error_runtime = runtime
	_error_history.append(message)
	if editor and _active_file != "main.cpp":
		_switch_user_file("main.cpp")
	if editor:
		var target_line := clampi(int(host.error_line()) - 1, 0, editor.get_line_count() - 1)
		editor.set_caret_line(target_line)
		editor.set_caret_column(maxi(int(host.error_col_start()) - 1, 0))
		editor.center_viewport_to_caret()
	if error_markup:
		error_markup.show_diagnostic(
			int(host.error_line()),
			int(host.error_col_start()),
			int(host.error_col_end()),
			message,
			str(host.error_suggestion()),
			str(host.error_kind())
		)
	if runtime:
		_play_bot_stuck()
		# Keep the execution highlight on the failing line.
		_apply_highlight(int(host.error_line()) - 1)
	if editor:
		editor.editable = true


func _clear_error_markup() -> void:
	_error_latched = false
	_error_runtime = false
	if error_markup and error_markup.has_method("clear"):
		error_markup.clear()


func _dismiss_error() -> void:
	if error_markup and error_markup.has_method("is_showing") and error_markup.is_showing():
		error_markup.dismiss()
	_error_latched = false


func _maybe_dismiss_error_on_edit() -> void:
	if error_markup == null or not error_markup.is_showing():
		return
	var line_1: int = int(error_markup.shown_line_1())
	if line_1 <= 0:
		_dismiss_error()
		return
	var idx := line_1 - 1
	if idx < 0 or idx >= editor.get_line_count():
		_dismiss_error()
		return
	if editor.get_line(idx) != error_markup.shown_source():
		_dismiss_error()


func _maybe_dismiss_error_on_click(local_pos: Vector2) -> void:
	if error_markup == null or not error_markup.is_showing():
		return
	var lc: Vector2i = editor.get_line_column_at_pos(local_pos, true)
	# Godot returns Vector2i(column, line).
	if lc.y < 0:
		_dismiss_error()
		return
	if lc.y != error_markup.shown_line_1() - 1:
		_dismiss_error()


func _sync_highlight(delta: float) -> void:
	var line: int = host.get_current_line() - 1
	var action: String = host.current_action()
	var long_action: bool = action == "harvest" or action == "do_a_flip" or action == "move" or action == "till" or action == "plant"
	if long_action:
		highlight.set_progress(host.current_action_progress())
	elif line == _highlighted_line:
		highlight.set_progress(host.current_action_progress())
	if line == _highlighted_line:
		_pending_line = -1
		_pending_t = 0.0
		if line >= 0:
			editor.set_caret_line(line)
		return
	if long_action or line < 0:
		_apply_highlight(line)
		if long_action:
			highlight.set_progress(host.current_action_progress())
		return
	if line != _pending_line:
		_pending_line = line
		_pending_t = 0.0
	_pending_t += delta
	if _pending_t >= 0.08:
		_apply_highlight(line)


func _apply_highlight(line: int) -> void:
	if line >= 0 and line < editor.get_line_count():
		highlight.set_current_line(line)
		editor.set_caret_line(line)
		_highlighted_line = line
	else:
		highlight.clear_line()
		_highlighted_line = -1
	_pending_line = -1
	_pending_t = 0.0


func _clear_highlight() -> void:
	highlight.clear_line()
	_highlighted_line = -1
	_pending_line = -1
	_pending_t = 0.0


func _input(event: InputEvent) -> void:
	if _session_phase != "playing":
		return
	# Camera press *and* release must be seen even if the cursor is over UI
	# when the button comes up; otherwise orbit/pan stick and the view follows
	# the mouse. Never capture the cursor.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		clear_camera_drag()
	camera_rig.handle_event(event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _open_panel != "":
		_close_panel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss_error()
		# Clicking empty farm gives the keyboard back to the camera.
		if not _point_over_ui(camera_rig.event_mouse_pos(event)):
			if get_viewport():
				get_viewport().gui_release_focus()
			if event.double_click:
				reset_camera(false)
				get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()
		get_tree().quit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_now()
		clear_camera_drag()
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			clear_camera_drag()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_panel()


func _toggle_panel(panel_id: String) -> void:
	if _open_panel == panel_id:
		_close_panel()
		return
	var previous := _open_panel
	var switching := overlay_card.visible and previous != ""
	_open_panel = panel_id
	_reset_confirming = false
	backdrop.move_to_front()
	overlay_card.move_to_front()
	_fill_panel(panel_id)
	_panel_tabs.select(panel_id, switching)
	if switching:
		var order := ["skill", "settings", "log"]
		FarmMotion.slide_content(overlay_body, 1.0 if order.find(panel_id) > order.find(previous) else -1.0)
	else:
		FarmMotion.stop(overlay_body, "_fm_content")
		overlay_body.position.x = 0.0
		overlay_body.modulate.a = 1.0
		FarmMotion.open_overlay(backdrop, overlay_card)


func _close_panel(instant: bool = false) -> void:
	_open_panel = ""
	_reset_confirming = false
	_close_skill_detail()
	FarmMotion.close_overlay(backdrop, overlay_card, FarmMotion.CLOSE_DUR, instant)


func _clear_overlay_body() -> void:
	for button in [log_button, reset_cam_button]:
		if is_instance_valid(button) and button.get_parent() != ui_root:
			button.reparent(ui_root)
			button.hide()
	if is_instance_valid(skill_scroll) and skill_scroll.is_inside_tree():
		_skill_view = {"zoom": skill_scroll.get("zoom"), "scroll": Vector2(skill_scroll.scroll_horizontal, skill_scroll.scroll_vertical)}
		skill_scroll = null
	_skill_glow_nodes.clear()
	skill_detail = null
	for child in overlay_body.get_children():
		overlay_body.remove_child(child)
		child.queue_free()


func _fill_panel(panel_id: String) -> void:
	_clear_overlay_body()
	match panel_id:
		"skill":
			overlay_title.text = "技能树"
			_fill_skill_tree()
		"hint":
			overlay_title.text = "提示"
			_fill_hint_panel()
		"settings":
			overlay_title.text = "设置"
			_fill_settings_panel()
		"log":
			overlay_title.text = "更新日志"
			_fill_log_panel()


func _fill_hint_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.add_child(scroll)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var id := _hint_skill()
	label.text = "%s：%s\n\n范本\n\n%s" % [_skill_display_name(id), FarmSkillData.pain(id), FarmSkillData.exemplar(id)]
	_apply_font(label, 20, TEXT)
	scroll.add_child(label)
	label.custom_minimum_size = Vector2(620, 0)


func _fill_log_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.add_child(scroll)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = CHANGELOG_TEXT
	_apply_font(label, 20, TEXT)
	scroll.add_child(label)
	label.custom_minimum_size = Vector2(620, 0)


func _fill_settings_panel() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 18)
	overlay_body.add_child(box)
	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 14)
	box.add_child(utility_row)
	for spec in [[reset_cam_button, "视角回正"], [log_button, "更新日志"]]:
		var button: Button = spec[0]
		button.reparent(utility_row)
		button.show()
		var label := _settings_label(spec[1])
		utility_row.add_child(label)
	var save_status := Label.new()
	save_status.text = _save_message if not _save_message.is_empty() else "进度自动保存 · 关闭后可继续"
	_apply_font(save_status, 17, TEXT_DIM)
	box.add_child(save_status)

	box.add_child(_settings_label("运行速度"))
	var speed_note := Label.new()
	speed_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var speed_text := "开局为 1×。速度由技能决定，不能在设置里拉快。"
	if host.speed_unlocked():
		speed_text = "收割与挥空都随技能加快；草仍长 1 秒，未熟就砍会重新长。"
	speed_note.text = speed_text
	_apply_font(speed_note, 19, TEXT)
	box.add_child(speed_note)

	box.add_child(_settings_label("编辑器字号"))
	var font_row := preload("res://scripts/farm_tabs.gd").new()
	font_row.name = "FontOptions"
	font_row.options = [["16", "16"], ["18", "18"], ["20", "20"]]
	font_row.selected = str(_font_size)
	font_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	font_row.chosen.connect(func(value: String) -> void:
		_set_editor_font_size(int(value), true, false)
		font_row.select(value)
	)
	box.add_child(font_row)

	box.add_child(_settings_label("声音"))
	var sound_row := preload("res://scripts/farm_tabs.gd").new()
	sound_row.name = "SoundOptions"
	sound_row.options = [["0", "关"], ["1", "轻"], ["2", "开"]]
	sound_row.selected = str(_sound_level)
	sound_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sound_row.chosen.connect(func(value: String) -> void:
		_set_sound_level(int(value))
		sound_row.select(value)
		_sfx("harvest")
		_queue_save(true)
	)
	box.add_child(sound_row)

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "重置会清空当前干草、木头、累计收获和已解锁的能力，并把农场、窗口和编辑器恢复到开局。字号和声音设置会保留。"
	_apply_font(note, 18, TEXT_DIM)
	box.add_child(note)

	if _reset_confirming:
		var warn := Label.new()
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.text = "确认重置农场吗？进度将全部清除，无法撤回。"
		_apply_font(warn, 20, DANGER)
		box.add_child(warn)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var yes := _make_button("确认重置", true, 120)
		var no := _make_button("取消", false, 88)
		yes.pressed.connect(_confirm_reset)
		no.pressed.connect(func() -> void:
			_reset_confirming = false
			_fill_panel("settings")
		)
		row.add_child(yes)
		row.add_child(no)
	else:
		var reset_btn := _make_button("重置农场", false, 120)
		reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		reset_btn.pressed.connect(func() -> void:
			_reset_confirming = true
			_fill_panel("settings")
		)
		box.add_child(reset_btn)


func _settings_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	_apply_font(label, 20, GOLD_SOFT, true)
	return label


func _confirm_reset() -> void:
	_on_stop()
	host.reset_world()
	_user_files = {"main.cpp": STARTER}
	_active_file = "main.cpp"
	hint_skill_id = ""
	editor.protect_framework = true
	editor.text = STARTER
	_rebuild_file_bar()
	editor.editable = true
	_clear_error_markup()
	_loops_seen = false
	_speed_seen = false
	_if_seen = false
	_move_seen = false
	_for_seen = false
	_till_seen = false
	_plant_seen = false
	_reset_confirming = false
	_harvesting = false
	_flipping = false
	_tilling = false
	_stepping = false
	_clear_highlight()
	_apply_hint_text()
	_ensure_farm_size(1)
	reset_camera(true)
	_snap_drone()
	camera_rig.apply_home(1, false)
	if code_window:
		if code_window.maximized:
			code_window.toggle_maximize()
		code_window.set_minimized(false, true)
		code_window.reveal(_code_default)
	if hint_window:
		if hint_window.maximized:
			hint_window.toggle_maximize()
		hint_window.set_minimized(false, true)
		hint_window.reveal(_hint_default)
	_update_hay()
	_update_buttons()
	_close_panel()
	_queue_save()


func _skill_nodes() -> Array:
	return FarmSkillData.nodes(host)


func _skill_template(id: String) -> String:
	return FarmSkillData.exemplar(id)


func _skill_knowledge(id: String) -> String:
	var extra := FarmSkillData.knowledge(id)
	if extra != "":
		return extra
	match id:
		"harvest":
			return "harvest() 是一次函数调用，做完就往下走。把语句放进 int main()，程序才有入口。do_a_flip() 只是表演，不改农场。"
		"loop":
			return "while (true) 会反复执行花括号里的语句，直到你停下。开局一次收割大约要 1 秒，和草长熟的时间一样，所以循环正好能一刀接一刀收到成熟的草。"
		"speed":
			return "所有挥刀约快 2 倍，每刀 200 tick；草仍要 400 tick 才熟。未熟就砍会打回幼苗，连续盲收会长不熟。先停循环，等熟再单收攒够 12 干草；买「条件」后用 can_harvest() 等熟再收。"
		"iff":
			return "在已有的 while 里加 if (can_harvest()) harvest();，只在成熟时收割。查询只花 1 tick，不打断幼苗生长；一档加速后约每 400 tick 收一棵。"
		"move":
			return "move(East) 走到邻格，到边缘会从对侧出现。解锁时农场扩大为 3×3。方向名可以写成 enum Dir。"
		"forl":
			return "for (int i = 0; i < 3; i++) 把同一段动作做固定次数，适合走完一垄。现在 i 还不能拿来运算。"
		"till":
			return "till() 把草地翻成土壤（并清掉上面的植物），再翻一次变回草地。土壤自己不会长草。"
		"plant":
			return "plant(Bush) 只能种在空的土壤上，灌木 2 秒成熟，收割得到木头。用 get_entity_type() 和 get_ground_type() 判断格子。"
		"vars":
			return "变量用来记住一个有类型的值，例如 int 或 bool。有了它，循环变量才能真正拿来计数。"
		"fn":
			return "把一段重复的动作写成函数，main 里只要调用名字。以后可以在 main 外面定义 harvest_row()。"
		_:
			return ""


func _fill_skill_tree() -> void:
	_skill_glow_nodes.clear()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.add_child(root)

	var scroll := preload("res://scripts/farm_skill_scroll.gd").new()
	scroll.node_clicked.connect(click_skill_node)
	scroll.name = "SkillScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 44
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scroll)
	skill_scroll = scroll

	var wrap := Control.new()
	wrap.name = "SkillWrap"
	wrap.custom_minimum_size = FarmSkillData.CANVAS_SIZE
	scroll.add_child(wrap)
	var canvas := Control.new()
	canvas.name = "SkillCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.add_child(canvas)
	scroll.configure(canvas, wrap, FarmSkillData.CANVAS_SIZE)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(toolbar)
	var guide := Label.new()
	guide.text = "学习路线 · 左拖 / 滚轮缩放"
	guide.tooltip_text = "主线向下，支线补充；完整前置见节点提示。左键拖动，滚轮缩放。"
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(guide, 17, TEXT)
	toolbar.add_child(guide)
	var zoom_label := Label.new()
	_apply_font(zoom_label, 16, TEXT)
	zoom_label.text = "100%"
	toolbar.add_child(zoom_label)
	scroll.zoom_changed.connect(func(value: float) -> void: zoom_label.text = "%d%%" % roundi(value * 100.0))
	var overview := _make_button("全貌", false, 72)
	overview.name = "SkillFitAll"
	overview.tooltip_text = "缩放到完整技能树"
	overview.pressed.connect(scroll.fit_all)
	toolbar.add_child(overview)
	var actual := _make_button("还原", false, 72)
	actual.name = "SkillZoomReset"
	actual.pressed.connect(func() -> void: scroll.zoom_about(1.0))
	toolbar.add_child(actual)

	var nodes := _skill_nodes()
	var index := {}
	for node in nodes:
		index[node["id"]] = node

	var lines := Control.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node_w := 100.0
	var node_h := 120.0
	lines.draw.connect(func() -> void:
		var pairs := FarmSkillData.edges()
		for pair in pairs:
			var a: Dictionary = index[pair[0]]
			var b: Dictionary = index[pair[1]]
			var same_row: bool = absf(float((a["pos"] as Vector2).y) - float((b["pos"] as Vector2).y)) < 8.0
			var pa: Vector2
			var pb: Vector2
			var detour := false
			if same_row:
				var left_first: bool = (a["pos"] as Vector2).x <= (b["pos"] as Vector2).x
				pa = a["pos"] + Vector2(node_w if left_first else 0.0, node_h * 0.5)
				pb = b["pos"] + Vector2(0.0 if left_first else node_w, node_h * 0.5)
				var x0 := minf(pa.x, pb.x)
				var x1 := maxf(pa.x, pb.x)
				for other in nodes:
					if str(other["id"]) == str(a["id"]) or str(other["id"]) == str(b["id"]):
						continue
					var op: Vector2 = other["pos"]
					if absf(op.y - float((a["pos"] as Vector2).y)) < 8.0 and op.x + 10.0 < x1 and op.x + node_w - 10.0 > x0:
						detour = true
						break
			else:
				pa = a["pos"] + Vector2(node_w * 0.5, node_h - 2.0)
				pb = b["pos"] + Vector2(node_w * 0.5, 2.0)
			var col := Color(0.72, 0.70, 0.64, 0.18)
			var width := 2.0
			if a["owned"] and b["owned"]:
				col = Color(0.80, 0.70, 0.50, 0.72)
				width = 2.6
			elif a["owned"] and not b.get("soon", false):
				col = Color(0.80, 0.70, 0.50, 0.34)
				width = 2.2
			_draw_skill_branch(lines, pa, pb, col, width, detour)
	)
	canvas.add_child(lines)

	for node in nodes:
		var card := _skill_node_card(node)
		card.position = node["pos"]
		canvas.add_child(card)
	lines.queue_redraw()

	_skill_more_hint = Control.new()
	_skill_more_hint.name = "SkillMoreHint"
	_skill_more_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_more_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_skill_more_hint.offset_top = -36
	_skill_more_hint.offset_bottom = 0
	_skill_more_hint.draw.connect(func() -> void:
		if skill_scroll == null:
			return
		var bar := skill_scroll.get_v_scroll_bar()
		if bar and bar.value < bar.max_value - skill_scroll.size.y - 8:
			var w := _skill_more_hint.size.x
			var h := _skill_more_hint.size.y
			_skill_more_hint.draw_rect(Rect2(0, 0, w, h), Color(0.11, 0.14, 0.13, 0.0))
			var fade := Color(0.11, 0.14, 0.13, 0.55)
			for i in 10:
				var a := 0.0 + 0.07 * float(i)
				_skill_more_hint.draw_rect(Rect2(0, h * float(i) / 10.0, w, h / 10.0 + 1), Color(fade.r, fade.g, fade.b, a))
			var mid := Vector2(w * 0.5, h * 0.62)
			_skill_more_hint.draw_colored_polygon(PackedVector2Array([
				mid + Vector2(-10, -4), mid + Vector2(10, -4), mid + Vector2(0, 6)
			]), Color(0.86, 0.78, 0.58, 0.55))
	)
	root.add_child(_skill_more_hint)
	var vbar := scroll.get_v_scroll_bar()
	if vbar:
		vbar.value_changed.connect(func(_v: float) -> void:
			if _skill_more_hint:
				_skill_more_hint.queue_redraw()
		)
	# Nudge scroll so the first view already shows a cut-off lower branch.
	scroll.zoom_about(float(_skill_view["zoom"]), Vector2.ZERO)
	scroll.call_deferred("_apply_zoom_scroll", _skill_view["scroll"])
	skill_detail = _make_skill_detail()
	skill_detail.visible = false
	root.add_child(skill_detail)
	scroll.blocking_control = skill_detail
	if _selected_skill_id != "":
		_open_skill_detail(_selected_skill_id)


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


func _append_round_corner(points: PackedVector2Array, p: Vector2, q: Vector2, r: Vector2, radius: float) -> void:
	var v1 := p - q
	var v2 := r - q
	var l1 := v1.length()
	var l2 := v2.length()
	if l1 < 1.0 or l2 < 1.0:
		points.append(q)
		return
	var rad := minf(radius, minf(l1, l2) * 0.48)
	var a := q + v1 * (rad / l1)
	var c := q + v2 * (rad / l2)
	points.append(a)
	for i in range(1, 7):
		var t := float(i) / 6.0
		points.append(_cubic_bezier(a, a.lerp(q, 0.55), c.lerp(q, 0.55), c, t))
	points.append(c)


func _draw_skill_branch(ci: Control, a: Vector2, b: Vector2, col: Color, width: float, detour_below: bool = false) -> void:
	var dy := b.y - a.y
	var dx := b.x - a.x
	var points := PackedVector2Array()
	if detour_below:
		var dip := 28.0
		points.append(a)
		_append_round_corner(points, a, Vector2(a.x, a.y + dip), Vector2(b.x, a.y + dip), 14.0)
		_append_round_corner(points, Vector2(a.x, a.y + dip), Vector2(b.x, a.y + dip), b, 14.0)
		points.append(b)
	elif absf(dx) < 8.0:
		# Same column: a slightly eased vertical.
		var mid := (a + b) * 0.5
		for i in 8:
			var t := float(i) / 7.0
			points.append(_cubic_bezier(a, Vector2(a.x, mid.y), Vector2(b.x, mid.y), b, t))
	elif absf(dy) < 28.0:
		var sx := signf(dx) * clampf(absf(dx) * 0.4, 24.0, 56.0)
		_append_round_corner(points, a, a + Vector2(sx, 0), b, 18.0)
		points.append(b)
		if points.is_empty() or points[0] != a:
			var prefixed := PackedVector2Array([a])
			prefixed.append_array(points)
			points = prefixed
	else:
		# Rounded orthogonal: down from parent, across, down into the child.
		# Keep the horizontal in the corridor just below the parent so lines don't cut cards.
		var stub := 22.0
		var mid := Vector2(b.x, a.y + stub)
		var drop := Vector2(b.x, b.y)
		points.append(a)
		_append_round_corner(points, a, Vector2(a.x, a.y + stub), mid, 16.0)
		_append_round_corner(points, Vector2(a.x, a.y + stub), mid, drop, 16.0)
		points.append(b)
	if points.size() < 2:
		return
	ci.draw_polyline(points, col, width, true)


func _skill_node_card(node: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Skill_" + str(node["id"])
	card.custom_minimum_size = FarmSkillData.CARD_SIZE
	card.size = FarmSkillData.CARD_SIZE
	var owned: bool = node["owned"]
	var soon: bool = node.get("soon", false)
	var id := str(node["id"])
	var can_buy := false
	if not soon and id != "harvest":
		can_buy = bool(node.get("can_buy", false)) or (not owned and host.can_unlock(id))
	var bg := Color(0.30, 0.27, 0.20, 0.95) if owned else Color(0.18, 0.19, 0.18, 0.90)
	if soon:
		bg = Color(0.15, 0.16, 0.15, 0.72)
	elif not owned:
		bg = Color(0.16, 0.17, 0.16, 0.88)
	var style := _flat(bg, 12, Vector4(6, 5, 6, 4), 2)
	if can_buy:
		style.border_color = Color(0.65, 0.81, 0.64, 0.90)
		style.set_border_width_all(2)
	elif owned:
		style.border_color = Color(0.80, 0.70, 0.50, 0.30)
		style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not soon else Control.CURSOR_ARROW
	if soon:
		card.tooltip_text = "即将开放"
	elif not owned:
		card.tooltip_text = "前置：%s\n%s" % [FarmSkillData.prerequisite_text(id), FarmSkillData.cost_text(node.get("cost_map", {}))]
	else:
		card.tooltip_text = "已解锁 · 点击查看"
	card.tooltip_text = FarmSkillData.guidance(id) + "\n" + card.tooltip_text

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var icon := FarmIcon.new()
	if soon:
		icon.kind = FarmIcon.Kind.LOCK
		icon.icon_color = Color(0.62, 0.62, 0.58, 0.45)
	else:
		icon.kind = FarmIcon.kind_from_name(id)
		icon.icon_color = GOLD_SOFT if owned else Color(0.62, 0.62, 0.58, 0.70)
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)

	var title := Label.new()
	title.text = str(node["name"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(title, 18, Color(0.84, 0.76, 0.58, 1) if owned else Color(0.74, 0.73, 0.68, 0.78 if not soon else 0.42), false)
	col.add_child(title)
	var purpose := Label.new()
	purpose.name = "SkillPurpose"
	purpose.text = str(node["pain"])
	purpose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purpose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	purpose.custom_minimum_size.x = 0
	_apply_font(purpose, 12, TEXT_DIM)
	purpose.add_theme_constant_override("line_spacing", -4)
	col.add_child(purpose)

	var cmap: Dictionary = node.get("cost_map", {})
	var price_text := FarmSkillData.cost_text(cmap) if not cmap.is_empty() else (str(node.get("cost", 0)) if int(node.get("cost", 0)) > 0 else "")
	if (not owned or can_buy) and not soon and price_text != "" and price_text != "0":
		var cost := Label.new()
		cost.text = price_text.replace(" + ", "\n")
		cost.name = "CostLabel"
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost.max_lines_visible = 2
		cost.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cost.tooltip_text = price_text
		_apply_font(cost, 12, GOLD if can_buy else Color(0.70, 0.68, 0.62, 0.80), false)
		cost.add_theme_constant_override("line_spacing", -4)
		col.add_child(cost)

	var shortfall := Label.new()
	shortfall.name = "Shortfall"
	shortfall.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortfall.visible = false
	_apply_font(shortfall, 14, DANGER)
	var feedback := Control.new()
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(feedback)
	feedback.add_child(shortfall)
	shortfall.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shortfall.offset_top = -26
	shortfall.offset_bottom = -2

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_skill_node_clicked(id, card)
			card.accept_event()
	)
	if not soon:
		card.mouse_entered.connect(func() -> void: style.bg_color = bg.lightened(0.10))
		card.mouse_exited.connect(func() -> void: style.bg_color = bg)
	card.set_meta("skill_id", id)
	card.set_meta("can_buy", can_buy)
	card.set_meta("base_border", style.border_color)
	if can_buy:
		_skill_glow_nodes.append(card)
	return card


func _on_skill_node_clicked(id: String, card: Control = null) -> void:
	var nodes := _skill_nodes()
	var node: Dictionary = {}
	for n in nodes:
		if str(n["id"]) == id:
			node = n
			break
	if node.is_empty() or node.get("soon", false):
		return
	if id == "harvest" or (node["owned"] and not host.can_unlock(id)):
		_open_skill_detail(id)
		return
	if host.can_unlock(id):
		var code: int = int(host.try_unlock(id))
		if code == 0:
			_queue_save()
			hint_skill_id = id
			_update_hay()
			_apply_hint_text()
			_maybe_unlock_hint(false)
			_selected_skill_id = ""
			if card:
				var shown_scroll_id := skill_scroll.get_instance_id()
				card.pivot_offset = card.size * 0.5
				_play_unlock_flourish(card)
				var tw := create_tween()
				tw.tween_interval(0.26)
				tw.tween_callback(func() -> void:
					# A late unlock flourish must not rebuild a NEW tree after
					# close/reopen and reset the player's current scroll.
					if _open_panel == "skill" and is_instance_valid(skill_scroll) and skill_scroll.get_instance_id() == shown_scroll_id:
						_fill_panel("skill")
				)
			elif _open_panel == "skill":
				_fill_panel("skill")
		return
	# Not enough hay or missing prerequisite: shake, show shortfall if it's hay.
	_open_skill_detail(id)
	if card:
		_shake_skill_card(card)
		if host.prerequisite_met(id):
			var need: int = int(host.hay_shortfall(id))
			var badge: Label = card.find_child("Shortfall", true, false)
			if badge:
				badge.text = "差 %d" % need
				badge.visible = true
				var cost: Label = card.find_child("CostLabel", true, false)
				if cost:
					cost.visible = false
				var tw := card.create_tween()
				tw.tween_interval(0.9)
				tw.tween_callback(func() -> void:
					if is_instance_valid(badge):
						badge.visible = false
					if is_instance_valid(cost):
						cost.visible = true
				)


func _shake_skill_card(card: Control) -> void:
	_sfx("deny")
	FarmMotion.stop(card, "_fm_shake")
	var origin: Vector2 = card.get_meta("_fm_shake_origin", card.position)
	card.set_meta("_fm_shake_origin", origin)
	var tw := card.create_tween()
	card.set_meta("_fm_shake", tw)
	tw.tween_property(card, "position:x", origin.x - 5, 0.04)
	tw.tween_property(card, "position:x", origin.x + 5, 0.05)
	tw.tween_property(card, "position:x", origin.x - 3, 0.04)
	tw.tween_property(card, "position:x", origin.x, 0.05)


func _play_unlock_flourish(card: Control) -> void:
	_sfx("unlock")
	if card == null:
		return
	FarmMotion.stop(card, "_fm_feedback")
	var tw := card.create_tween()
	card.set_meta("_fm_feedback", tw)
	tw.tween_property(card, "scale:x", 0.08, 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(card, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_skill_detail() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SkillDetail"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -210
	panel.offset_bottom = 210
	panel.add_theme_stylebox_override("panel", _flat(SAGE_DEEP, 16, Vector4(18, 16, 18, 16), 12))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.name = "DetailTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(title, 22, GOLD_SOFT, true)
	head.add_child(title)
	var close := _make_icon_button(FarmIcon.Kind.CLOSE, "关闭", false, Vector2(44, 44))
	close.pressed.connect(func() -> void:
		_close_skill_detail()
	)
	head.add_child(close)
	var knowledge := Label.new()
	knowledge.name = "DetailKnowledge"
	knowledge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(knowledge, 19, TEXT)
	v.add_child(knowledge)
	var ex_title := Label.new()
	ex_title.name = "DetailExemplarTitle"
	ex_title.text = "范本"
	_apply_font(ex_title, 18, GOLD_SOFT, true)
	v.add_child(ex_title)
	var code := CodeEdit.new()
	code.name = "DetailCode"
	code.editable = false
	code.gutters_draw_line_numbers = false
	code.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	code.custom_minimum_size = Vector2(0, 168)
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _font_mono:
		code.add_theme_font_override("font", _font_mono)
	code.add_theme_font_size_override("font_size", 16)
	code.add_theme_color_override("font_color", SYN_IDENT)
	code.add_theme_color_override("font_readonly_color", SYN_IDENT)
	var ed := _flat(Color(0.10, 0.12, 0.11, 1), 10, Vector4(10, 8, 10, 8))
	code.add_theme_stylebox_override("normal", ed)
	code.add_theme_stylebox_override("read_only", ed)
	code.add_theme_stylebox_override("focus", ed)
	v.add_child(code)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	var copy_btn := _make_button("复制", false, 88)
	copy_btn.name = "CopyTemplate"
	copy_btn.tooltip_text = "复制完整主程序到剪贴板"
	copy_btn.pressed.connect(_copy_selected_skill_template)
	actions.add_child(copy_btn)
	var insert_btn := _make_button("载入", false, 88)
	insert_btn.name = "InsertTemplate"
	insert_btn.tooltip_text = "替换 main.cpp，并载入配套头文件"
	insert_btn.pressed.connect(_insert_selected_skill_template)
	actions.add_child(insert_btn)
	var copied := Label.new()
	copied.name = "CopiedHint"
	copied.text = "已复制"
	copied.visible = false
	_apply_font(copied, 17, GOLD_SOFT)
	actions.add_child(copied)
	return panel


func _mark_skill_selection(id: String) -> void:
	if not is_instance_valid(skill_scroll):
		return
	for card in skill_scroll.find_children("Skill_*", "PanelContainer", true, false):
		if card.has_meta("skill_id"):
			var style: StyleBoxFlat = card.get_theme_stylebox("panel")
			style.border_color = GOLD_SOFT if str(card.get_meta("skill_id")) == id else card.get_meta("base_border")


func _open_skill_detail(id: String) -> void:
	_selected_skill_id = id
	_mark_skill_selection(id)
	if is_instance_valid(skill_scroll):
		skill_scroll.call("_cancel_drag")
	if skill_detail == null:
		return
	var title: Label = skill_detail.find_child("DetailTitle", true, false)
	var knowledge: Label = skill_detail.find_child("DetailKnowledge", true, false)
	var code: CodeEdit = skill_detail.find_child("DetailCode", true, false)
	var name := id
	for n in _skill_nodes():
		if str(n["id"]) == id:
			name = str(n["name"])
			break
	if title:
		title.text = name
	var owned := _skill_owned(id)
	if knowledge:
		var lines: PackedStringArray = []
		if FarmSkillData.pain(id) != "":
			lines.append(FarmSkillData.pain(id))
		if _skill_knowledge(id) != "":
			lines.append(_skill_knowledge(id))
		lines = [FarmSkillData.pain(id), FarmSkillData.remedy(id), "下一行：" + FarmSkillData.next_line(id)]
		if id in ["speed", "iff"]:
			lines = [FarmSkillData.pain(id), "在 while 里加：if (can_harvest()) harvest();"]
		if not owned:
			lines.append("前置：" + FarmSkillData.prerequisite_text(id))
		knowledge.text = "\n".join(lines)
	var ex_title: Label = skill_detail.find_child("DetailExemplarTitle", true, false)
	if ex_title:
		ex_title.text = "完整范本 · 载入替换主程序" if owned else "范本：解锁后显示"
	if code:
		# The exemplar is shown only once the skill is owned.
		code.text = _skill_template(id) if owned else ""
		code.visible = owned
		if _code_highlighter:
			code.syntax_highlighter = _code_highlighter.duplicate()
	for btn_name in ["CopyTemplate", "InsertTemplate"]:
		var btn: Control = skill_detail.find_child(btn_name, true, false)
		if btn:
			btn.visible = owned
	FarmMotion.open_popup(skill_detail)


func _close_skill_detail() -> void:
	_selected_skill_id = ""
	_mark_skill_selection("")
	if skill_detail:
		FarmMotion.close_popup(skill_detail)


func _copy_selected_skill_template() -> void:
	if not _skill_owned(_selected_skill_id):
		return
	var text := _skill_template(_selected_skill_id)
	if text.is_empty():
		return
	last_copied_template = text
	DisplayServer.clipboard_set(text)
	if skill_detail:
		var hint: Label = skill_detail.find_child("CopiedHint", true, false)
		_flash_copied(hint)


func _load_hint_exemplar() -> void:
	_load_exemplar(_hint_skill())


func _insert_selected_skill_template() -> void:
	_load_exemplar(_selected_skill_id)


func _load_exemplar(id: String) -> void:
	if editor == null:
		return
	if not _skill_owned(id):
		return
	var text := _skill_template(id)
	if text.is_empty():
		return
	# An exemplar is a whole C++ program, never a snippet to put inside main.
	_on_stop()
	if _active_file != "main.cpp":
		_switch_user_file("main.cpp")
	editor.text = text
	_user_files["main.cpp"] = text
	var headers := FarmSkillData.exemplar_headers(id)
	for name in headers:
		_user_files[str(name)] = str(headers[name])
	_rebuild_file_bar()
	_push_includes_to_host()


func click_skill_node(id: String) -> void:
	var card: Control = null
	if overlay_body:
		card = overlay_body.find_child("Skill_" + id, true, false)
	_on_skill_node_clicked(id, card)


func buy_skill(id: String) -> int:

	var code: int = int(host.try_unlock(id))
	if code == 0:
		_queue_save()
		hint_skill_id = id
		_apply_hint_text()
	_update_hay()
	if _open_panel == "skill":
		_fill_panel("skill")
	return code


func open_skill_detail(id: String) -> void:
	_open_skill_detail(id)


func _tile_world(tx: int, ty: int, size: int = -1) -> Vector3:
	if size < 0:
		size = _shown_size
	var origin := (size - 1) * 0.5
	return Vector3((tx - origin) * TILE_SPACING, 0.0, (ty - origin) * TILE_SPACING)


func _init_farm() -> void:
	_plots_root = Node3D.new()
	_plots_root.name = "Plots"
	farm_root.add_child(_plots_root)
	_blade_young = _make_blade_mat(Color(0.32, 0.46, 0.24, 1), 0.0)
	_blade_mid = _make_blade_mat(Color(0.40, 0.58, 0.28, 1), 0.0)
	_blade_ripe = _make_blade_mat(Color(0.58, 0.68, 0.28, 1), 0.22)
	_blade_mats = [_blade_young, _blade_mid, _blade_ripe]
	_blade_meshes = [
		_make_blade_mesh(0.06, 0.028, 0.006, 0.32),
		_make_blade_mesh(0.09, 0.024, 0.005, 0.30),
		_make_blade_mesh(0.04, 0.030, 0.007, 0.34),
		_make_blade_mesh(0.11, 0.022, 0.004, 0.28),
	]
	_grass_mat = _make_soil_mat(Color(0.36, 0.30, 0.20, 1), Color(0.24, 0.20, 0.14, 1))
	_soil_mat = _make_soil_mat(Color(0.30, 0.22, 0.15, 1), Color(0.20, 0.14, 0.10, 1))
	var bush_leaf := StandardMaterial3D.new()
	bush_leaf.albedo_color = Color(0.32, 0.48, 0.28, 1)
	bush_leaf.roughness = 0.62
	var bush_leaf2 := StandardMaterial3D.new()
	bush_leaf2.albedo_color = Color(0.42, 0.56, 0.30, 1)
	bush_leaf2.roughness = 0.55
	var bush_wood := StandardMaterial3D.new()
	bush_wood.albedo_color = Color(0.42, 0.28, 0.16, 1)
	bush_wood.roughness = 0.8
	_bush_mats = [bush_leaf, bush_leaf2, bush_wood]
	_ensure_farm_size(1)
	_update_earth(1)


func _ensure_farm_size(size: int) -> void:
	if size < 1:
		size = 1
	if size == _shown_size and _plots.size() >= size * size:
		return
	var previous := _shown_size
	for key in _plots.keys():
		var plot: Dictionary = _plots[key]
		var tx: int = plot["x"]
		var ty: int = plot["y"]
		plot["root"].visible = tx < size and ty < size
	for y in size:
		for x in size:
			var key := Vector2i(x, y)
			if not _plots.has(key):
				_plots[key] = _make_plot(x, y)
	_shown_size = size
	_position_plots(size)
	_update_earth(size)
	_rebuild_tile_batches(size)
	if size != previous:
		camera_rig.apply_home(size, false)


func _position_plots(size: int) -> void:
	for y in size:
		for x in size:
			var plot: Dictionary = _plots[Vector2i(x, y)]
			plot["root"].position = _tile_world(x, y, size)
			plot["root"].visible = true


func _make_soil_mat(top: Color, side: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = top
	mat.roughness = 0.92
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	return mat


func _make_beveled_tile_mesh() -> ArrayMesh:
	# A soft block: rounded corners and a rounded top edge with smooth
	# normals, so light rolls over the rim instead of breaking on hard creases.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := TILE_WIDTH * 0.5
	var h := TILE_HEIGHT
	var corner := 0.13
	var bevel := 0.065
	var top_c := Color(1.0, 1.0, 1.0, 1)
	var side_c := Color(0.64, 0.62, 0.57, 1)
	var foot_c := Color(0.52, 0.50, 0.46, 1)
	var corner_steps := 6
	var bevel_steps := 4
	# Each ring: [inset, height, colour, tilt of the normal toward straight up].
	var rings: Array = [[0.0, 0.0, foot_c, 0.0], [0.0, h - bevel, side_c, 0.0]]
	for k in range(1, bevel_steps + 1):
		var ang := float(k) / float(bevel_steps) * PI * 0.5
		rings.append([bevel * (1.0 - cos(ang)), h - bevel + bevel * sin(ang), side_c.lerp(top_c, float(k) / float(bevel_steps)), ang])
	var dirs: Array[Vector2] = []
	var centres: Array[Vector2] = []
	for c in 4:
		var centre := Vector2(w - corner, w - corner).rotated(float(c) * PI * 0.5)
		for step in corner_steps + 1:
			dirs.append(Vector2.from_angle(float(c) * PI * 0.5 + float(step) / float(corner_steps) * PI * 0.5))
			centres.append(centre)
	var count := dirs.size()
	var point := func(ring: Array, i: int) -> Vector3:
		var flat: Vector2 = centres[i] + dirs[i] * (corner - float(ring[0]))
		return Vector3(flat.x, float(ring[1]), flat.y)
	var normal := func(ring: Array, i: int) -> Vector3:
		var tilt := float(ring[3])
		return Vector3(dirs[i].x * cos(tilt), sin(tilt), dirs[i].y * cos(tilt)).normalized()
	var emit := func(pos: Vector3, nrm: Vector3, col: Color) -> void:
		st.set_normal(nrm)
		st.set_color(col)
		st.add_vertex(pos)
	# Godot draws clockwise triangles as front faces; orient each one outward.
	var tri := func(p: Array, n: Array, c: Array) -> void:
		var facing: Vector3 = (p[2] - p[0]).cross(p[1] - p[0])
		var order := [0, 1, 2] if facing.dot(n[0] + n[1] + n[2]) > 0.0 else [0, 2, 1]
		for index in order:
			emit.call(p[index], n[index], c[index])
	for r in rings.size() - 1:
		var low: Array = rings[r]
		var high: Array = rings[r + 1]
		for i in count:
			var j := (i + 1) % count
			var p := [point.call(low, i), point.call(low, j), point.call(high, j), point.call(high, i)]
			var n := [normal.call(low, i), normal.call(low, j), normal.call(high, j), normal.call(high, i)]
			var c := [low[2], low[2], high[2], high[2]]
			tri.call([p[0], p[1], p[2]], [n[0], n[1], n[2]], [c[0], c[1], c[2]])
			tri.call([p[0], p[2], p[3]], [n[0], n[2], n[3]], [c[0], c[2], c[3]])
	var last: Array = rings[rings.size() - 1]
	var middle := Vector3(0, h, 0)
	for i in count:
		var j := (i + 1) % count
		tri.call([middle, point.call(last, i), point.call(last, j)], [Vector3.UP, Vector3.UP, Vector3.UP], [top_c, top_c, top_c])
	return st.commit()


func _make_bush_node() -> Node3D:
	var root := Node3D.new()
	root.name = "Bush"
	root.position = Vector3(0, TILE_HEIGHT, 0)
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.04
	cyl.height = 0.16
	stem.mesh = cyl
	stem.material_override = _bush_mats[2]
	stem.position = Vector3(0, 0.08, 0)
	root.add_child(stem)
	for i in 3:
		var ball := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.13 if i == 0 else 0.10
		sph.height = sph.radius * 2.0
		ball.mesh = sph
		ball.material_override = _bush_mats[i % 2]
		var ox := 0.0 if i == 0 else (0.10 if i == 1 else -0.09)
		var oz := 0.0 if i == 0 else (0.07 if i == 1 else 0.08)
		ball.position = Vector3(ox, 0.20 + 0.02 * i, oz)
		root.add_child(ball)
	return root


func _crop_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	mat.metallic = 0.0
	return mat


func _make_crop_node() -> Node3D:
	var root := Node3D.new()
	root.name = "Crop"
	root.position = Vector3(0, TILE_HEIGHT, 0)
	return root


func _crop_add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _crop_mat(color)
	inst.position = pos
	inst.rotation = rot
	inst.scale = scale
	parent.add_child(inst)
	return inst


func _style_crop(node: Node3D, entity: String, ratio: float) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()
	var s := 0.30 + 0.70 * clampf(ratio, 0.0, 1.0)
	node.scale = Vector3(s, s, s)
	match entity:
		"Carrot":
			# Tapered orange root sitting in the soil, plus a fan of green leaves.
			var root := CylinderMesh.new()
			root.top_radius = 0.09
			root.bottom_radius = 0.012
			root.height = 0.42
			root.radial_segments = 10
			_crop_add(node, root, Color(0.92, 0.45, 0.16, 1), Vector3(0, 0.10, 0))
			var shoulder := SphereMesh.new()
			shoulder.radius = 0.09
			shoulder.height = 0.10
			_crop_add(node, shoulder, Color(0.90, 0.42, 0.14, 1), Vector3(0, 0.30, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
			for i in 5:
				var leaf := BoxMesh.new()
				leaf.size = Vector3(0.07, 0.22, 0.02)
				var ang := deg_to_rad(-40 + 20 * i)
				var inst := _crop_add(node, leaf, Color(0.30, 0.58, 0.24, 1), Vector3(sin(ang) * 0.05, 0.42, cos(ang) * 0.03), Vector3(-0.55, ang, 0.15))
				inst.scale = Vector3(1, 1.0 + 0.1 * (i % 2), 1)
			node.scale = Vector3(s, s, s)
		"Tree":
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.05
			trunk.bottom_radius = 0.09
			trunk.height = 0.62
			_crop_add(node, trunk, Color(0.44, 0.28, 0.15, 1), Vector3(0, 0.31, 0))
			var c1 := SphereMesh.new(); c1.radius = 0.28; c1.height = 0.44
			var c2 := SphereMesh.new(); c2.radius = 0.20; c2.height = 0.34
			var c3 := SphereMesh.new(); c3.radius = 0.18; c3.height = 0.30
			_crop_add(node, c1, Color(0.22, 0.48, 0.26, 1), Vector3(0.0, 0.70, 0.0))
			_crop_add(node, c2, Color(0.30, 0.56, 0.28, 1), Vector3(0.16, 0.64, 0.08))
			_crop_add(node, c3, Color(0.26, 0.50, 0.24, 1), Vector3(-0.14, 0.78, -0.06))
		"Sunflower":
			var stem := CylinderMesh.new()
			stem.top_radius = 0.03
			stem.bottom_radius = 0.045
			stem.height = 0.62
			_crop_add(node, stem, Color(0.34, 0.52, 0.22, 1), Vector3(0, 0.31, 0))
			var disk := SphereMesh.new()
			disk.radius = 0.11
			disk.height = 0.12
			_crop_add(node, disk, Color(0.28, 0.16, 0.08, 1), Vector3(0, 0.66, 0.04), Vector3(-0.25, 0, 0))
			for i in 10:
				var petal := SphereMesh.new()
				petal.radius = 0.055
				petal.height = 0.16
				var a := TAU * float(i) / 10.0
				_crop_add(node, petal, Color(0.94, 0.76, 0.16, 1), Vector3(cos(a) * 0.16, 0.66 + sin(a) * 0.04, 0.04 + sin(a) * 0.02), Vector3(0, 0, a), Vector3(0.55, 1.15, 0.35))
			var leaf := BoxMesh.new()
			leaf.size = Vector3(0.12, 0.18, 0.02)
			_crop_add(node, leaf, Color(0.32, 0.56, 0.24, 1), Vector3(0.10, 0.28, 0.02), Vector3(0.4, 0.5, 0.8))
		"Pumpkin":
			var fruit := SphereMesh.new()
			fruit.radius = 0.26
			fruit.height = 0.36
			_crop_add(node, fruit, Color(0.90, 0.48, 0.14, 1), Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(1.15, 0.78, 1.05))
			var rib := SphereMesh.new()
			rib.radius = 0.24
			rib.height = 0.34
			_crop_add(node, rib, Color(0.80, 0.38, 0.10, 1), Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(0.70, 0.82, 1.18))
			var stem := CylinderMesh.new()
			stem.top_radius = 0.025
			stem.bottom_radius = 0.04
			stem.height = 0.10
			_crop_add(node, stem, Color(0.32, 0.42, 0.18, 1), Vector3(0, 0.36, 0), Vector3(0.15, 0, 0.2))
		"DeadPumpkin":
			var wilt := SphereMesh.new()
			wilt.radius = 0.20
			wilt.height = 0.22
			_crop_add(node, wilt, Color(0.42, 0.32, 0.20, 1), Vector3(0, 0.10, 0), Vector3.ZERO, Vector3(1.1, 0.55, 0.9))
		"Cactus":
			var col := CylinderMesh.new()
			col.top_radius = 0.09
			col.bottom_radius = 0.11
			col.height = 0.52
			_crop_add(node, col, Color(0.28, 0.54, 0.32, 1), Vector3(0, 0.26, 0))
			var cap := SphereMesh.new()
			cap.radius = 0.09
			cap.height = 0.12
			_crop_add(node, cap, Color(0.30, 0.56, 0.34, 1), Vector3(0, 0.52, 0))
			var arm_h := CylinderMesh.new()
			arm_h.top_radius = 0.05
			arm_h.bottom_radius = 0.06
			arm_h.height = 0.20
			_crop_add(node, arm_h, Color(0.26, 0.50, 0.30, 1), Vector3(0.14, 0.30, 0), Vector3(0, 0, 1.2))
			var arm_u := CylinderMesh.new()
			arm_u.top_radius = 0.05
			arm_u.bottom_radius = 0.055
			arm_u.height = 0.18
			_crop_add(node, arm_u, Color(0.26, 0.50, 0.30, 1), Vector3(0.24, 0.40, 0))
			var arm_h2 := CylinderMesh.new()
			arm_h2.top_radius = 0.045
			arm_h2.bottom_radius = 0.055
			arm_h2.height = 0.16
			_crop_add(node, arm_h2, Color(0.28, 0.52, 0.32, 1), Vector3(-0.12, 0.26, 0.02), Vector3(0, 0, -1.2))
			var arm_u2 := CylinderMesh.new()
			arm_u2.top_radius = 0.045
			arm_u2.bottom_radius = 0.05
			arm_u2.height = 0.16
			_crop_add(node, arm_u2, Color(0.28, 0.52, 0.32, 1), Vector3(-0.20, 0.34, 0.02))

		"Hedge":
			var wall := BoxMesh.new()
			wall.size = Vector3(0.98, 0.78, 0.98)
			_crop_add(node, wall, Color(0.18, 0.34, 0.20, 1), Vector3(0, 0.39, 0))
			var top := BoxMesh.new()
			top.size = Vector3(1.02, 0.16, 1.02)
			_crop_add(node, top, Color(0.24, 0.42, 0.24, 1), Vector3(0, 0.80, 0))
			var post := CylinderMesh.new()
			post.top_radius = 0.05
			post.bottom_radius = 0.06
			post.height = 0.86
			_crop_add(node, post, Color(0.36, 0.24, 0.14, 1), Vector3(0.40, 0.43, 0.40))
			_crop_add(node, post, Color(0.36, 0.24, 0.14, 1), Vector3(-0.40, 0.43, -0.40))
			node.scale = Vector3.ONE
		"Treasure":
			var box := BoxMesh.new()
			box.size = Vector3(0.36, 0.22, 0.28)
			_crop_add(node, box, Color(0.86, 0.64, 0.18, 1), Vector3(0, 0.14, 0))
			var lid := BoxMesh.new()
			lid.size = Vector3(0.38, 0.08, 0.30)
			_crop_add(node, lid, Color(0.92, 0.74, 0.24, 1), Vector3(0, 0.28, 0))
			var band := BoxMesh.new()
			band.size = Vector3(0.08, 0.24, 0.30)
			_crop_add(node, band, Color(0.72, 0.52, 0.14, 1), Vector3(0, 0.16, 0))
			var gem := SphereMesh.new()
			gem.radius = 0.07
			gem.height = 0.10
			_crop_add(node, gem, Color(0.40, 0.82, 0.86, 1), Vector3(0, 0.36, 0))
			node.scale = Vector3.ONE * maxf(0.85, s)
		"Apple":
			var ap := SphereMesh.new()
			ap.radius = 0.13
			ap.height = 0.24
			_crop_add(node, ap, Color(0.84, 0.20, 0.18, 1), Vector3(0, 0.14, 0))
			var st := CylinderMesh.new()
			st.top_radius = 0.015
			st.bottom_radius = 0.02
			st.height = 0.08
			_crop_add(node, st, Color(0.36, 0.24, 0.12, 1), Vector3(0, 0.28, 0))
		_:
			var sph := SphereMesh.new()
			sph.radius = 0.14
			sph.height = 0.28
			_crop_add(node, sph, Color(0.70, 0.70, 0.55, 1), Vector3(0, 0.14, 0))


func _make_plot(x: int, y: int) -> Dictionary:

	var root := Node3D.new()
	root.name = "Plot_%d_%d" % [x, y]
	_plots_root.add_child(root)

	var tile := MeshInstance3D.new()
	tile.mesh = _make_beveled_tile_mesh()
	tile.material_override = _grass_mat
	tile.position = Vector3(0, 0, 0)
	root.add_child(tile)

	var grass := Node3D.new()
	grass.position = Vector3(0, TILE_HEIGHT, 0)
	root.add_child(grass)

	var bush := _make_bush_node()
	bush.visible = false
	root.add_child(bush)

	var crop := _make_crop_node()
	crop.visible = false
	root.add_child(crop)

	var rng := RandomNumberGenerator.new()
	rng.seed = 814 + x * 37 + y * 91
	var blades: Array = []
	var placed: Array[Vector2] = []
	var attempts := 0
	var blade_cap := 20 if _shown_size < 8 else (8 if _shown_size < 16 else 4)
	while blades.size() < blade_cap and attempts < 80:
		attempts += 1
		var px := rng.randf_range(-0.38, 0.38)
		var pz := rng.randf_range(-0.38, 0.38)
		var ok := true
		for prev in placed:
			if Vector2(px, pz).distance_to(prev) < 0.11:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector2(px, pz))
		var pivot := Node3D.new()
		pivot.position = Vector3(px, 0, pz)
		var yaw := rng.randf_range(0.0, TAU)
		var lean := rng.randf_range(-0.10, 0.16)
		pivot.rotation = Vector3(0.0, yaw, 0.0)
		grass.add_child(pivot)
		var inst := MeshInstance3D.new()
		inst.mesh = _blade_meshes[blades.size() % _blade_meshes.size()]
		inst.material_override = _blade_mid
		inst.position = Vector3.ZERO
		var tall := rng.randf_range(0.82, 1.16)
		pivot.add_child(inst)
		blades.append({
			"pivot": pivot,
			"mesh": inst,
			"tall": tall,
			"stagger": rng.randf_range(0.0, 0.28),
			"phase": rng.randf_range(0.0, TAU),
			"lean": lean,
			"yaw": yaw,
			"visual": 1.0,
		})
	var glow := MeshInstance3D.new()
	glow.name = "RipeGlow"
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.22
	glow_mesh.height = 0.10
	glow_mesh.radial_segments = 16
	glow_mesh.rings = 8
	glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.70, 0.82, 0.32, 0.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.72, 0.84, 0.32, 1)
	glow_mat.emission_energy_multiplier = 0.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.roughness = 1.0
	glow.material_override = glow_mat
	glow.position = Vector3(0, 0.04, 0)
	glow.visible = false
	grass.add_child(glow)
	var lod := MeshInstance3D.new()
	lod.name = "GrassLod"
	var lod_mesh := SphereMesh.new()
	lod_mesh.radius = 0.42
	lod_mesh.height = 0.28
	lod_mesh.radial_segments = 8
	lod_mesh.rings = 4
	lod.mesh = lod_mesh
	lod.material_override = _blade_ripe if _blade_ripe else _crop_mat(Color(0.48, 0.62, 0.28, 1))
	lod.position = Vector3(0, TILE_HEIGHT + 0.04, 0)
	lod.visible = false
	root.add_child(lod)
	return {"x": x, "y": y, "root": root, "tile": tile, "grass": grass, "bush": bush, "crop": crop, "blades": blades, "juice": 0.0, "glow": glow, "glow_mat": glow_mat, "lod": lod}


func _earth_pad_radius(half: float, ang: float) -> float:
	# Rounded-square (superellipse) with a little edge noise — not a hard circle.
	var n := 4.6
	var denom := pow(pow(absf(cos(ang)), n) + pow(absf(sin(ang)), n), 1.0 / n)
	var r := half / maxf(denom, 0.001)
	r *= 1.0 + 0.048 * sin(ang * 3.0 + 0.4) + 0.03 * cos(ang * 5.0 - 0.8) + 0.018 * sin(ang * 7.0 + 1.1)
	return r


func _make_earth_pad_mesh(half: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var segs := 40
	var top_c := Color(0.46, 0.48, 0.40, 1)
	var pts: Array = []
	pts.append(Vector3(0, 0.0, 0))
	for r in range(1, rings + 1):
		var t := float(r) / float(rings)
		for s in segs:
			var ang := TAU * float(s) / float(segs)
			var rad := _earth_pad_radius(half, ang) * t
			# Almost flat; only the outer lip eases down into the meadow.
			var y := 0.0
			if t > 0.86:
				var k := (t - 0.86) / 0.14
				y = -0.10 * k * k
			pts.append(Vector3(cos(ang) * rad, y, sin(ang) * rad))
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		st.set_color(top_c)
		st.add_vertex(a)
		st.set_color(top_c)
		st.add_vertex(b)
		st.set_color(top_c)
		st.add_vertex(c)
	for s in segs:
		var s2 := (s + 1) % segs
		tri.call(pts[0], pts[1 + s], pts[1 + s2])
	for r in range(1, rings):
		var base := 1 + (r - 1) * segs
		var nxt := 1 + r * segs
		for s in segs:
			var s2 := (s + 1) % segs
			tri.call(pts[base + s], pts[nxt + s], pts[nxt + s2])
			tri.call(pts[base + s], pts[nxt + s2], pts[base + s2])
	st.generate_normals()
	return st.commit()


func _ensure_meadow() -> void:
	if _farm_meadow != null and is_instance_valid(_farm_meadow):
		return
	_farm_meadow = MeshInstance3D.new()
	_farm_meadow.name = "Meadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(56, 56)
	_farm_meadow.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.52, 0.43, 1)
	mat.roughness = 1.0
	_farm_meadow.material_override = mat
	_farm_meadow.position = Vector3(0, -0.12, 0)
	_farm_meadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if farm_root:
		farm_root.add_child(_farm_meadow)
		# Keep the pad above the meadow in the tree, meadow first.
		farm_root.move_child(_farm_meadow, 0)
		scenery = FarmScenery.new()
		scenery.name = "Scenery"
		farm_root.add_child(scenery)
		scenery.dress_meadow(_farm_meadow)


func _update_earth(size: int) -> void:
	_ensure_meadow()
	var field := float(maxi(1, size)) * TILE_SPACING
	var half := field * 0.5 + 0.92
	farm_earth.mesh = _make_earth_pad_mesh(half)
	if scenery:
		# The pad is a rounded square; its corners reach about 1.22 x half.
		scenery.layout(half * 1.25 + 0.3)
	var earth_mat := StandardMaterial3D.new()
	earth_mat.albedo_color = Color(1, 1, 1, 1)
	earth_mat.roughness = 1.0
	earth_mat.vertex_color_use_as_albedo = true
	farm_earth.material_override = earth_mat
	farm_earth.position = Vector3(0, -0.05, 0)


func _make_blade_mat(albedo: Color, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.62
	mat.metallic = 0.0
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(0.72, 0.84, 0.30, 1)
		mat.emission_energy_multiplier = emission
	return mat


func _make_blade_mesh(bend: float, base_w: float, tip_w: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 6
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := height * t0
		var y1 := height * t1
		var z0 := bend * t0 * t0
		var z1 := bend * t1 * t1
		var w0 := lerpf(base_w, tip_w, t0 * t0)
		var w1 := lerpf(base_w, tip_w, t1 * t1)
		var c0 := Color(0.22, 0.38, 0.16, 1).lerp(Color(0.70, 0.84, 0.34, 1), pow(t0, 0.85))
		var c1 := Color(0.22, 0.38, 0.16, 1).lerp(Color(0.70, 0.84, 0.34, 1), pow(t1, 0.85))
		var a := Vector3(-w0, y0, z0)
		var b := Vector3(w0, y0, z0)
		var c := Vector3(w1, y1, z1)
		var d := Vector3(-w1, y1, z1)
		st.set_color(c0)
		st.add_vertex(a)
		st.set_color(c0)
		st.add_vertex(b)
		st.set_color(c1)
		st.add_vertex(c)
		st.set_color(c0)
		st.add_vertex(a)
		st.set_color(c1)
		st.add_vertex(c)
		st.set_color(c1)
		st.add_vertex(d)
	st.generate_normals()
	return st.commit()


## Public camera actions (buttons, F key, tests).
func reset_camera(instant: bool = false) -> void:
	camera_rig.reset(instant)


func clear_camera_drag() -> void:
	if camera_rig:
		camera_rig.clear_drag()


# --- UI hit testing (shared by the camera rig and click handling) ---

func _text_input_has_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() else null
	if focus == null:
		return false
	return focus is TextEdit or focus is LineEdit or focus is CodeEdit or focus is SpinBox


func _mouse_over_editor() -> bool:
	if editor == null or not editor.is_visible_in_tree():
		return false
	return editor.get_global_rect().has_point(editor.get_global_mouse_position())


func _is_under_ui_root(node: Node) -> bool:
	var n := node
	while n:
		if n == ui_root:
			return true
		n = n.get_parent()
	return false


func _point_over_ui(pos: Vector2) -> bool:
	if _open_panel != "" and backdrop and backdrop.visible:
		return true
	for w in [code_window, hint_window]:
		if w and w.visible and w.get_global_rect().has_point(pos):
			return true
	if skill_detail and skill_detail.visible and skill_detail.get_global_rect().has_point(pos):
		return true
	if ui_root:
		var top := ui_root.get_node_or_null("TopBar")
		if top and top is Control and (top as Control).visible and (top as Control).get_global_rect().has_point(pos):
			return true
	if get_viewport():
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered and hovered != ui_root and _is_under_ui_root(hovered) and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	return false


func _snap_drone() -> void:
	var pos := _tile_world(host.get_drone_x(), host.get_drone_y())
	drone.position = Vector3(pos.x, _drone_base_y, pos.z + 0.06)
	_drone_to = drone.position
	_drone_from = drone.position
	_drone_move_t = 1.0


func _wrap_target(from: Vector3, logical: Vector3) -> Vector3:
	var span := float(_shown_size) * TILE_SPACING
	var dx := logical.x - from.x
	var dz := logical.z - from.z
	if span > 0.0:
		if dx > span * 0.5:
			dx -= span
		elif dx < -span * 0.5:
			dx += span
		if dz > span * 0.5:
			dz -= span
		elif dz < -span * 0.5:
			dz += span
	return Vector3(from.x + dx, logical.y, from.z + dz)


func _place_moving_bot(node: Node3D, from: Vector3, to: Vector3, t: float, hop: float) -> Vector3:
	var virtual_to := _wrap_target(from, to)
	var direction := Vector3(virtual_to.x - from.x, 0, virtual_to.z - from.z)
	var wrapped := virtual_to.distance_to(to) > TILE_SPACING * 0.5
	if wrapped:
		# Fold away at the outgoing edge, then unfold at the matching incoming
		# edge. Never travel through the field or outside the island at full size.
		var step := direction.normalized() * TILE_SPACING * 0.32
		if t < 0.5:
			var a := t * 2.0
			node.position = from.lerp(from + step, a)
			node.scale = Vector3.ONE * maxf(0.025, 1.0 - a)
		else:
			var a := (t - 0.5) * 2.0
			node.position = (to - step).lerp(to, a)
			node.scale = Vector3.ONE * maxf(0.025, a)
	else:
		node.position = from.lerp(to, t)
		node.scale = Vector3.ONE
	node.position.y = _drone_base_y + sin(t * PI) * hop
	return direction


func _camera_face_yaw() -> float:
	var to_cam := camera.global_position - drone.global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.0001:
		return 0.0
	return atan2(to_cam.x, to_cam.z)


func _update_drone(delta: float) -> void:
	var tile := _tile_world(host.get_drone_x(), host.get_drone_y())
	var logical := Vector3(tile.x, _drone_base_y, tile.z + 0.06)
	var moving := host.is_running() and host.current_action() == "move"
	var move_dir := Vector3.ZERO
	if moving:
		if Vector2(logical.x, logical.z).distance_to(Vector2(_drone_to.x, _drone_to.z)) > 0.04:
			_drone_from = Vector3(drone.position.x, _drone_base_y, drone.position.z)
			_drone_to = logical
			_drone_move_t = 0.0
		var t := smoothstep(0.0, 1.0, host.current_action_progress())
		move_dir = _place_moving_bot(drone, _drone_from, _drone_to, t, 0.12)
	else:
		drone.scale = Vector3.ONE
		if Vector2(drone.position.x, drone.position.z).distance_to(Vector2(logical.x, logical.z)) > 0.8:
			drone.position = logical
			_drone_to = logical
			_drone_from = logical
			_drone_move_t = 1.0
		elif Vector2(logical.x, logical.z).distance_to(Vector2(_drone_to.x, _drone_to.z)) > 0.02:
			_drone_from = drone.position
			_drone_to = logical
			_drone_move_t = 0.0
		if _drone_move_t < 1.0:
			_drone_move_t = minf(1.0, _drone_move_t + delta / 0.28)
			var t2 := smoothstep(0.0, 1.0, _drone_move_t)
			_place_moving_bot(drone, _drone_from, _drone_to, t2, 0.08)
			if _drone_move_t >= 1.0:
				drone.position = logical
				drone.scale = Vector3.ONE
		elif not _harvesting and not _flipping and not _tilling:
			drone.position.x = logical.x
			drone.position.z = logical.z
			drone.position.y = _drone_base_y + sin(_hover_t * 1.35) * 0.012
	_animate_bot(delta, moving, move_dir)
	_update_extra_drones(delta)


func _animate_bot(delta: float, moving: bool, move_dir: Vector3) -> void:
	if _bot_rig == null:
		return
	if _flipping or _harvesting or _tilling:
		pass
	else:
		var face := _camera_face_yaw()
		if moving and move_dir.length_squared() > 0.0001:
			face = atan2(move_dir.x, move_dir.z)
			var lean := clampf(move_dir.length() * 0.35, 0.0, 0.28)
			_bot_rig.rotation.x = lerp_angle(_bot_rig.rotation.x, -lean, 1.0 - exp(-delta * 8.0))
		else:
			_bot_rig.rotation.x = lerp_angle(_bot_rig.rotation.x, sin(_hover_t * 1.2) * 0.05, 1.0 - exp(-delta * 6.0))
		_bot_rig.rotation.y = lerp_angle(_bot_rig.rotation.y, face, 1.0 - exp(-delta * 6.0))
		_bot_rig.rotation.z = lerp_angle(_bot_rig.rotation.z, sin(_hover_t * 0.9) * 0.04, 1.0 - exp(-delta * 6.0))
		if _bot_arm_r and not moving:
			_bot_arm_r.rotation.z = lerp_angle(_bot_arm_r.rotation.z, -0.50 + sin(_hover_t * 1.1) * 0.05, 1.0 - exp(-delta * 4.0))


func _play_bot_stuck() -> void:
	if _bot_rig == null:
		return
	_sfx("stuck")
	# Always shake around the rig's rest pose. Reading the current pose made a
	# second shake start from the middle of the first, and every rapid repeat
	# left the bot a little further off its tile.
	for key in ["_stuck_turn", "_stuck_slide"]:
		FarmMotion.stop(_bot_rig, key)
	var origin_x := 0.0
	var origin_z_rot := 0.0
	_bot_rig.position.x = origin_x
	var tw := _bot_rig.create_tween()
	_bot_rig.set_meta("_stuck_turn", tw)
	tw.tween_property(_bot_rig, "rotation:z", origin_z_rot + 0.18, 0.07).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bot_rig, "rotation:z", origin_z_rot - 0.16, 0.08)
	tw.tween_property(_bot_rig, "rotation:z", origin_z_rot + 0.10, 0.07)
	tw.tween_property(_bot_rig, "rotation:z", origin_z_rot, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var tw2 := _bot_rig.create_tween()
	_bot_rig.set_meta("_stuck_slide", tw2)
	tw2.tween_property(_bot_rig, "position:x", origin_x + 0.03, 0.06)
	tw2.tween_property(_bot_rig, "position:x", origin_x - 0.03, 0.08)
	tw2.tween_property(_bot_rig, "position:x", origin_x, 0.10)


func _update_grass(delta: float) -> void:
	var size := host.get_world_size()
	for y in size:
		for x in size:
			var key := Vector2i(x, y)
			if not _plots.has(key):
				continue
			var plot: Dictionary = _plots[key]
			if plot["juice"] > 0.0:
				plot["juice"] = maxf(0.0, plot["juice"] - delta)
			var ground: String = host.tile_ground(x, y)
			var entity: String = host.tile_entity(x, y)
			var tile_mesh: MeshInstance3D = plot["tile"]
			tile_mesh.material_override = _soil_mat if ground == "Soil" else _grass_mat
			var ratio := clampf(float(host.tile_grow_ratio(x, y)), 0.0, 1.0)
			var grass_node: Node3D = plot["grass"]
			var bush_node: Node3D = plot["bush"]
			var crop_node: Node3D = plot["crop"]
			var is_grass := entity == "Grass"
			var is_bush := entity == "Bush"
			var styled := entity in ["Carrot", "Tree", "Sunflower", "Pumpkin", "DeadPumpkin", "Cactus", "Hedge", "Treasure", "Apple"]
			grass_node.visible = is_grass and not _shot_hide_plants
			bush_node.visible = is_bush and not _shot_hide_plants
			crop_node.visible = styled and not _shot_hide_plants
			if is_bush:
				var bscale := 0.22 + 0.78 * ratio
				bush_node.scale = Vector3(bscale, bscale, bscale)
				bush_node.rotation.y = 0.15 * sin(_hover_t * 0.7 + float(x + y))
			if styled:
				if plot.get("crop_kind", "") != entity:
					_style_crop(crop_node, entity, ratio)
					plot["crop_kind"] = entity
				var s := 0.30 + 0.70 * ratio
				if entity == "Hedge" or entity == "Treasure":
					crop_node.scale = Vector3.ONE
					crop_node.rotation.y = 0.0
				else:
					crop_node.scale = Vector3(s, s, s)
					if (not _field_is_far(plot)) and (entity not in ["Cactus"]):
						crop_node.rotation.y = 0.08 * sin(_hover_t * 0.6 + float(x + y))
			else:
				plot["crop_kind"] = ""
			var water := 0.0
			if host.has_method("tile_water"):
				water = float(host.tile_water(x, y))
			if ground == "Soil" and water > 0.15:
				if _wet_soil_mat == null:
					_wet_soil_mat = _crop_mat(Color(0.22, 0.20, 0.16, 1))
				tile_mesh.material_override = _wet_soil_mat
			_sync_batched_tile(x, y, ground, water)
			if plot.has("glow"):
				var glow: MeshInstance3D = plot["glow"]
				var ripe := is_grass and ratio >= 0.995
				glow.visible = ripe
				if ripe and plot.has("glow_mat"):
					var gm: StandardMaterial3D = plot["glow_mat"]
					var pulse := 0.10 + 0.08 * sin(_hover_t * 2.1 + float(x * 2 + y))
					gm.emission_energy_multiplier = pulse
					gm.albedo_color.a = 0.10 + pulse * 0.35
			if not is_grass:
				if plot.has("lod"):
					plot["lod"].visible = false
				continue
			var far := _field_is_far(plot) or size >= 12
			if plot.has("lod"):
				var lod: MeshInstance3D = plot["lod"]
				if far and size >= 8:
					lod.visible = true and not _shot_hide_plants
					var ls := 0.45 + 0.7 * ratio
					lod.scale = Vector3(ls, 0.25 + 0.9 * ratio, ls)
					grass_node.visible = false
					continue
				else:
					lod.visible = false
			_grass_anim_accum += 0.0  # kept for compatibility
			if size >= 8 and (_hover_t * 10.0) - floor(_hover_t * 10.0) > 0.35 and plot["juice"] <= 0.0:
				continue
			for blade in plot["blades"]:
				var local := clampf((ratio - float(blade["stagger"]) * 0.7) / (1.0 - float(blade["stagger"]) * 0.5), 0.0, 1.0)
				var target := STUBBLE + (float(blade["tall"]) - STUBBLE) * local
				var visual: float = blade["visual"]
				if target + 0.08 < visual:
					visual = lerpf(visual, STUBBLE, 1.0 - exp(-delta * 18.0))
				else:
					visual = lerpf(visual, target, 1.0 - exp(-delta * 8.0))
				blade["visual"] = visual
				var pivot: Node3D = blade["pivot"]
				pivot.scale = Vector3(1.0, visual, 1.0)
				var sway := sin(_hover_t * 1.25 + float(blade["phase"])) * 0.07 * (0.2 + 0.8 * visual)
				var tip_bend := 0.10 * visual
				pivot.rotation.z = float(blade["lean"]) * 0.25 + sway
				pivot.rotation.x = float(blade["lean"]) + sway * 0.4 + tip_bend
				var inst: MeshInstance3D = blade["mesh"]
				if local < 0.35:
					inst.material_override = _blade_young
				elif local < 0.92:
					inst.material_override = _blade_mid
				else:
					inst.material_override = _blade_ripe


func _play_harvest_juice() -> void:
	_play_harvest_swing(true)
	_sfx("harvest")
	var key := Vector2i(host.get_drone_x(), host.get_drone_y())
	if _plots.has(key):
		_plots[key]["juice"] = 0.28
		for blade in _plots[key]["blades"]:
			blade["visual"] = maxf(STUBBLE, float(blade["visual"]) * 0.45)
	var kind := host.last_harvested()
	for i in 5:
		_spawn_hay_strand(i, key, kind == "Bush")


func _play_harvest_swing(success: bool) -> void:
	if _harvest_tween and is_instance_valid(_harvest_tween):
		_harvest_tween.kill()
	_harvesting = true
	# One interruptible timeline owns the pose, including the recovery callback.
	# A miss is a flat sideways sweep without reward strands; the crop height
	# follows the simulator's restarted growth. Both swings follow action speed.
	var duration := clampf(float(host.action_ticks()) / 400.0 * 0.85, 0.16, 0.42)
	_harvest_tween = create_tween().set_parallel(true)
	_harvest_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var poses := [
		[_bot_rig, Vector3(0.50, 0, 0) if success else Vector3(0.12, -0.25, 0), Vector3.ZERO],
		[_bot_arm_r, Vector3(0.95, 0.10, -0.15) if success else Vector3(-0.25, -0.70, -0.50), Vector3(0.20, 0.18, -0.50)],
		[_bot_hoe, Vector3(1.15, 0.10, -0.25) if success else Vector3(0.15, -0.85, -0.48), Vector3(0.30, 0.10, -0.48)],
		[_bot_arm_l, Vector3(0.35, 0, 0.28), Vector3(0.25, 0, 0.26)],
	]
	for pose in poses:
		if pose[0]:
			_harvest_tween.tween_property(pose[0], "rotation", pose[1], duration * 0.45)
			_harvest_tween.tween_property(pose[0], "rotation", pose[2], duration * 0.55).set_delay(duration * 0.45)
	if success:
		_harvest_tween.tween_property(drone, "position:y", _drone_base_y + 0.10, duration * 0.45)
		_harvest_tween.tween_property(drone, "position:y", _drone_base_y, duration * 0.55).set_delay(duration * 0.45)
	_harvest_tween.chain().tween_callback(func() -> void: _harvesting = false)


func _spawn_hay_strand(index: int, key: Vector2i, wood: bool = false) -> void:
	var puff := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.11
	puff.mesh = mesh
	var mat := StandardMaterial3D.new()
	if wood:
		var shade := 0.38 + 0.06 * float(index)
		mat.albedo_color = Color(shade, 0.24 + 0.03 * float(index % 3), 0.14, 1)
	else:
		var shade := 0.78 + 0.08 * float(index)
		mat.albedo_color = Color(shade, 0.68 + 0.04 * float(index % 3), 0.32, 1)
	mat.roughness = 0.55
	puff.material_override = mat
	juice_anchor.add_child(puff)
	var origin := _tile_world(key.x, key.y)
	var spread := 0.08 * float(index - 2)
	puff.position = Vector3(origin.x + spread, TILE_HEIGHT + 0.18, origin.z + 0.02 * float(index))
	puff.rotation = Vector3(0.4, 0.3 * index, 0.2)
	var start := puff.position
	var finish := start + Vector3(-0.85 - 0.08 * float(index), 1.05 + 0.05 * float(index), -0.18 + spread)
	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void:
			var mid := start.lerp(finish, t)
			mid.y += 0.85 * sin(t * PI)
			puff.position = mid
			puff.rotation.z = t * 3.2
			puff.scale = Vector3.ONE * (1.0 - 0.35 * t),
		0.0,
		1.0,
		0.42 + 0.04 * float(index)
	)
	tw.tween_callback(puff.queue_free)


func _play_till_hoe() -> void:
	_tilling = true
	_sfx("till")
	if _bot_rig:
		var bob := create_tween()
		bob.tween_property(_bot_rig, "rotation:x", 0.42, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		bob.tween_property(_bot_rig, "rotation:x", -0.06, 0.14)
		bob.tween_property(_bot_rig, "rotation:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	if _bot_arm_r:
		var rest_r := Vector3(0.20, 0.18, -0.50)
		var arms := create_tween()
		arms.tween_property(_bot_arm_r, "rotation", Vector3(-0.90, 0.15, -0.30), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		arms.tween_property(_bot_arm_r, "rotation", Vector3(1.05, 0.08, -0.10), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		arms.tween_property(_bot_arm_r, "rotation", rest_r, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _bot_hoe:
		var hoe := create_tween()
		hoe.tween_property(_bot_hoe, "rotation", Vector3(-0.55, 0.15, -0.45), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hoe.tween_property(_bot_hoe, "rotation", Vector3(1.25, 0.08, -0.20), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		hoe.tween_property(_bot_hoe, "rotation", Vector3(0.30, 0.10, -0.48), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _bot_arm_l:
		var left := create_tween()
		left.tween_property(_bot_arm_l, "rotation", Vector3(0.45, 0.0, 0.26), 0.14)
		left.tween_property(_bot_arm_l, "rotation", Vector3(0.25, 0.0, 0.26), 0.22)
	var hop := create_tween()
	hop.tween_property(drone, "position:y", _drone_base_y + 0.06, 0.10).set_trans(Tween.TRANS_SINE)
	hop.tween_property(drone, "position:y", _drone_base_y - 0.04, 0.14)
	hop.tween_property(drone, "position:y", _drone_base_y, 0.16).set_trans(Tween.TRANS_SINE)
	hop.tween_callback(func() -> void:
		_tilling = false
	)


func _play_flip() -> void:
	_flipping = true
	_sfx("flip")
	if _bot_rig == null:
		var tw := create_tween()
		tw.tween_property(drone, "rotation:z", TAU, 0.8).set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(func() -> void:
			drone.rotation.z = 0.0
			_flipping = false
		)
		return
	# Rapid flips restart from the ground, never from the top of the last hop.
	FarmMotion.stop(drone, "_flip")
	_bot_rig.rotation.x = 0.0
	var start_y := _drone_base_y
	var tw := create_tween()
	drone.set_meta("_flip", tw)
	tw.set_parallel(true)
	tw.tween_property(_bot_rig, "rotation:x", TAU, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(drone, "position:y", start_y + 0.38, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(drone, "position:y", _drone_base_y, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if _bot_rig:
			_bot_rig.rotation.x = 0.0
		_flipping = false
	)


func _mat(color: Color, rough: float = 0.45, metal: float = 0.0, emission: float = 0.0, emit_color: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = emit_color if emit_color.a > 0.0 else color
		mat.emission_energy_multiplier = emission
	return mat


func _mesh_inst(mesh: Mesh, mat: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	if parent:
		parent.add_child(inst)
	return inst


func _soften_lights() -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_energy = 0.88
		sun.light_color = Color(1.0, 0.93, 0.82, 1)
		sun.shadow_opacity = 0.56
		sun.shadow_blur = 2.4
		sun.light_angular_distance = 2.5
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env: Environment = env_node.environment
		env.ambient_light_energy = 0.34
		env.ambient_light_color = Color(0.90, 0.84, 0.74, 1)
	if get_node_or_null("FillLight") == null:
		var fill := DirectionalLight3D.new()
		fill.name = "FillLight"
		fill.light_energy = 0.22
		fill.light_color = Color(0.80, 0.86, 0.88, 1)
		fill.shadow_enabled = false
		fill.rotation_degrees = Vector3(-25, 130, 0)
		add_child(fill)


func _outline_mesh(mesh: Mesh, parent: Node3D, pos: Vector3, scale := 1.045, rot := Vector3.ZERO) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.33, 0.26, 1)
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var inst := _mesh_inst(mesh, mat, pos, parent)
	inst.rotation = rot
	inst.scale = Vector3.ONE * scale
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_bot() -> void:
	for child in drone.get_children():
		child.queue_free()
	drone.scale = Vector3.ONE
	drone.rotation = Vector3.ZERO
	_bot_rig = Node3D.new()
	_bot_rig.name = "Rig"
	drone.add_child(_bot_rig)
	var parts := _make_bot_rig(_bot_rig)
	_bot_eye_l = parts["eye_l"]
	_bot_eye_r = parts["eye_r"]
	_bot_arm_l = parts["arm_l"]
	_bot_arm_r = parts["arm_r"]
	_bot_hoe = parts["hoe"]


func _make_bot_rig(rig: Node3D) -> Dictionary:
	# Warm matte cream, lower albedo so volume reads under the farm lights.
	var cream := _mat(Color(0.70, 0.62, 0.50, 1), 0.92, 0.0)
	var wood := _mat(Color(0.58, 0.40, 0.26, 1), 0.92, 0.0)
	var metal := _mat(Color(0.42, 0.48, 0.44, 1), 0.78, 0.10)
	var eye_mat := _mat(Color.BLACK, 0.95, 0.0)

	# Single chubby bean / capsule. No separate head, no feet — it hovers.
	var body := SphereMesh.new()
	body.radius = 0.15
	body.height = 0.30
	var body_node := _mesh_inst(body, cream, Vector3(0, -0.01, 0), rig)
	body_node.name = "Body"
	_outline_mesh(body, rig, Vector3(0, -0.01, 0), 1.05)

	# No face plate: two matte black rounded vertical slots sit on the bean.
	var eye_mesh := CapsuleMesh.new()
	eye_mesh.radius = 0.012
	eye_mesh.height = 0.070
	var eye_l := Node3D.new()
	eye_l.name = "EyeLeft"
	var eye_r := Node3D.new()
	eye_r.name = "EyeRight"
	eye_l.position = Vector3(-0.044, 0.025, 0.138)
	eye_r.position = Vector3(0.044, 0.025, 0.138)
	rig.add_child(eye_l)
	rig.add_child(eye_r)
	_mesh_inst(eye_mesh, eye_mat, Vector3.ZERO, eye_l)
	_mesh_inst(eye_mesh, eye_mat, Vector3.ZERO, eye_r)

	var arm_l := Node3D.new()
	var arm_r := Node3D.new()
	arm_l.position = Vector3(-0.146, 0.005, 0.02)
	arm_r.position = Vector3(0.146, 0.005, 0.04)
	arm_l.rotation = Vector3(0.25, 0.0, 0.26)
	arm_r.rotation = Vector3(0.20, 0.18, -0.50)
	rig.add_child(arm_l)
	rig.add_child(arm_r)

	var arm := CapsuleMesh.new()
	arm.radius = 0.024
	arm.height = 0.10
	_mesh_inst(arm, cream, Vector3(0, -0.044, 0.01), arm_l)
	_mesh_inst(arm, cream, Vector3(0, -0.044, 0.01), arm_r)
	_outline_mesh(arm, arm_l, Vector3(0, -0.044, 0.01), 1.08)
	_outline_mesh(arm, arm_r, Vector3(0, -0.044, 0.01), 1.08)
	var hand := SphereMesh.new()
	hand.radius = 0.022
	hand.height = 0.032
	_mesh_inst(hand, cream, Vector3(0, -0.092, 0.014), arm_l)
	_mesh_inst(hand, cream, Vector3(0, -0.092, 0.014), arm_r)

	# Hoe lives on the rig so its silhouette stays readable: long wood handle
	# held at the side, metal head up beside the crown (~0.8 body height).
	var hoe := Node3D.new()
	hoe.name = "Hoe"
	hoe.position = Vector3(0.179, 0.02, 0.05)
	hoe.rotation = Vector3(0.30, 0.10, -0.48)
	rig.add_child(hoe)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.011
	handle.bottom_radius = 0.013
	handle.height = 0.26
	_mesh_inst(handle, wood, Vector3(0, 0, 0), hoe)
	var ferrule := SphereMesh.new()
	ferrule.radius = 0.016
	ferrule.height = 0.024
	_mesh_inst(ferrule, metal, Vector3(0, 0.133, 0), hoe)
	var blade := CapsuleMesh.new()
	blade.radius = 0.024
	blade.height = 0.100
	var blade_n := _mesh_inst(blade, metal, Vector3(0.0, 0.155, 0.016), hoe)
	blade_n.rotation_degrees = Vector3(80, 16, 0)
	blade_n.scale = Vector3(1.70, 1.0, 0.48)
	_outline_mesh(handle, hoe, Vector3(0, 0, 0), 1.08)

	# Right hand sits on the mid-shaft.
	# (Arm already ends near the hoe origin.)

	return {"eye_l": eye_l, "eye_r": eye_r, "arm_l": arm_l, "arm_r": arm_r, "hoe": hoe}


func _field_is_far(plot: Dictionary) -> bool:
	if camera == null or not plot.has("root"):
		return false
	var pos: Vector3 = (plot["root"] as Node3D).global_position
	return camera.global_position.distance_to(pos) > 11.0


func _make_tile_multimesh(mat: Material) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_beveled_tile_mesh()
	mm.instance_count = 0
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_plots_root.add_child(inst)
	return inst


func _rebuild_tile_batches(size: int) -> void:
	var use_batch := size >= 8
	if use_batch:
		if _tile_mm_grass == null:
			_tile_mm_grass = _make_tile_multimesh(_grass_mat)
		if _tile_mm_soil == null:
			_tile_mm_soil = _make_tile_multimesh(_soil_mat)
		if _wet_soil_mat == null:
			_wet_soil_mat = _crop_mat(Color(0.22, 0.20, 0.16, 1))
		if _tile_mm_wet == null:
			_tile_mm_wet = _make_tile_multimesh(_wet_soil_mat)
		var count := size * size
		for inst in [_tile_mm_grass, _tile_mm_soil, _tile_mm_wet]:
			inst.visible = true
			inst.multimesh.instance_count = count
		for y in size:
			for x in size:
				var idx := y * size + x
				var xf := Transform3D(Basis.IDENTITY, _tile_world(x, y, size))
				_tile_mm_grass.multimesh.set_instance_transform(idx, xf)
				_tile_mm_soil.multimesh.set_instance_transform(idx, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
				_tile_mm_wet.multimesh.set_instance_transform(idx, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	else:
		for inst in [_tile_mm_grass, _tile_mm_soil, _tile_mm_wet]:
			if inst:
				inst.visible = false
	for y in size:
		for x in size:
			var plot: Dictionary = _plots[Vector2i(x, y)]
			var tile: MeshInstance3D = plot["tile"]
			tile.visible = not use_batch


func _sync_batched_tile(x: int, y: int, ground: String, water: float) -> void:
	if _shown_size < 8 or _tile_mm_grass == null:
		return
	var idx := y * _shown_size + x
	if idx < 0 or idx >= _tile_mm_grass.multimesh.instance_count:
		return
	var xf := Transform3D(Basis.IDENTITY, _tile_world(x, y, _shown_size))
	var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
	var wet := ground == "Soil" and water > 0.15
	var soil := ground == "Soil" and not wet
	_tile_mm_grass.multimesh.set_instance_transform(idx, xf if ground != "Soil" else hidden)
	_tile_mm_soil.multimesh.set_instance_transform(idx, xf if soil else hidden)
	if _tile_mm_wet:
		_tile_mm_wet.multimesh.set_instance_transform(idx, xf if wet else hidden)


func _flush_active_file() -> void:
	if editor == null:
		return
	_user_files[_active_file] = editor.text
	if _active_file != "main.cpp" and not _user_files.has("main.cpp"):
		_user_files["main.cpp"] = STARTER


func _push_includes_to_host() -> void:
	if host == null or not host.has_method("set_include"):
		return
	if not host.is_unlocked("include"):
		return
	_flush_active_file()
	for name in _user_files.keys():
		if str(name) == "main.cpp":
			continue
		host.set_include(str(name), str(_user_files[name]))


func _refresh_file_bar_visibility() -> void:
	var show := host != null and host.is_unlocked("include")
	if _file_bar_wrap:
		_file_bar_wrap.visible = show
	if show and _file_bar and _file_bar.get_child_count() == 0:
		if not _user_files.has("main.cpp") and editor:
			_user_files["main.cpp"] = editor.text
		_rebuild_file_bar()


func _rebuild_file_bar() -> void:
	if _file_bar == null:
		return
	for child in _file_bar.get_children():
		_file_bar.remove_child(child)
		child.queue_free()
	var names: Array = ["main.cpp"]
	for k in _user_files.keys():
		if str(k) != "main.cpp" and str(k) not in names:
			names.append(str(k))
	for name in names:
		var btn := Button.new()
		btn.text = str(name)
		btn.flat = true
		btn.set_meta("file_name", str(name))
		btn.custom_minimum_size = Vector2(72, 28)
		_apply_font(btn, 15, GOLD_SOFT if _active_file == str(name) else TEXT_DIM, true)
		var chosen := str(name)
		btn.pressed.connect(func() -> void:
			_switch_user_file(chosen)
		)
		_file_bar.add_child(btn)
		FarmMotion.bind_hover(btn, 1.02, 0.97)
	var add := Button.new()
	add.text = "+"
	add.tooltip_text = "新建文件"
	add.custom_minimum_size = Vector2(32, 28)
	_apply_font(add, 18, GOLD_SOFT, true)
	add.pressed.connect(_new_user_file)
	_file_bar.add_child(add)


func _switch_user_file(name: String) -> void:
	_flush_active_file()
	_active_file = name
	if editor:
		editor.protect_framework = name == "main.cpp"
	if not _user_files.has(name):
		_user_files[name] = ""
	if editor:
		editor.text = str(_user_files[name])
	if _file_bar:
		for button in _file_bar.get_children():
			if button is Button and button.has_meta("file_name"):
				var is_active: bool = str(button.get_meta("file_name")) == name
				button.add_theme_color_override("font_color", GOLD_SOFT if is_active else TEXT_DIM)
	if editor:
		FarmMotion.stop(editor, "_file_fade")
		editor.modulate.a = 0.65
		var fade := editor.create_tween()
		editor.set_meta("_file_fade", fade)
		fade.tween_property(editor, "modulate:a", 1.0, 0.18)


func _new_user_file() -> void:
	var n := 1
	var name := "rows.hpp"
	while _user_files.has(name):
		n += 1
		name = "rows_%d.hpp" % n
	_user_files[name] = "void harvest_row() {\n    for (int i = 0; i < get_world_size(); i++) {\n        if (can_harvest()) harvest();\n        move(East);\n    }\n}\n"
	_switch_user_file(name)
	_rebuild_file_bar()


func scroll_skills_toward(id: String) -> void:
	if skill_scroll == null:
		return
	for node in FarmSkillData.nodes(host):
		if str(node["id"]) == id:
			var pos: Vector2 = node["pos"] * float(skill_scroll.get("zoom"))
			skill_scroll.scroll_vertical = int(max(0.0, pos.y - 280.0))
			skill_scroll.scroll_horizontal = int(max(0.0, pos.x - 420.0))
			return


func visible_drone_nodes() -> int:
	var n := 1
	for item in _extra_drones:
		if item is Dictionary and item.has("node") and is_instance_valid(item["node"]) and (item["node"] as Node3D).visible:
			n += 1
	return n


func _sync_drone_fleet() -> void:
	var n := 1
	if host and host.has_method("drone_count"):
		n = maxi(1, int(host.drone_count()))
	if _drones_root == null:
		_drones_root = Node3D.new()
		_drones_root.name = "ExtraDrones"
		farm_root.add_child(_drones_root)
	while _extra_drones.size() < n - 1:
		var id := _extra_drones.size() + 1
		_extra_drones.append(_spawn_extra_drone(id))
	while _extra_drones.size() > n - 1:
		var last: Dictionary = _extra_drones.pop_back()
		if last.has("node") and is_instance_valid(last["node"]):
			(last["node"] as Node3D).queue_free()
	if host and host.has_method("set_view_drone"):
		if _view_drone >= n:
			_view_drone = 0
		host.set_view_drone(_view_drone)


func _spawn_extra_drone(id: int) -> Dictionary:
	var node := Node3D.new()
	node.name = "Drone_%d" % id
	_drones_root.add_child(node)
	var rig := Node3D.new()
	rig.name = "Rig"
	node.add_child(rig)
	_make_bot_rig(rig)
	var tile := _tile_world(0, 0)
	node.position = Vector3(tile.x, _drone_base_y, tile.z + 0.06)
	return {"id": id, "node": node, "rig": rig, "from": node.position, "to": node.position, "t": 1.0}


func _update_extra_drones(delta: float) -> void:
	if not host or not host.has_method("drone_x_at"):
		return
	for item in _extra_drones:
		if not (item is Dictionary) or not item.has("node"):
			continue
		var node: Node3D = item["node"]
		if not is_instance_valid(node):
			continue
		var id := int(item["id"])
		var tile := _tile_world(int(host.drone_x_at(id)), int(host.drone_y_at(id)))
		var logical := Vector3(tile.x, _drone_base_y, tile.z + 0.06)
		var to: Vector3 = item["to"]
		if Vector2(logical.x, logical.z).distance_to(Vector2(to.x, to.z)) > 0.02:
			item["from"] = node.position
			item["to"] = logical
			item["t"] = 0.0
		if float(item["t"]) < 1.0:
			item["t"] = minf(1.0, float(item["t"]) + delta / 0.28)
			var t2 := smoothstep(0.0, 1.0, float(item["t"]))
			_place_moving_bot(node, item["from"], item["to"], t2, 0.08)
		else:
			node.scale = Vector3.ONE
			node.position.x = logical.x
			node.position.z = logical.z
			node.position.y = _drone_base_y + sin(_hover_t * 1.35 + float(id)) * 0.012
		var rig: Node3D = item["rig"]
		if rig:
			var face := 0.0
			var to_cam := camera.global_position - node.global_position
			to_cam.y = 0.0
			if to_cam.length_squared() > 0.0001:
				face = atan2(to_cam.x, to_cam.z)
			rig.rotation.y = lerp_angle(rig.rotation.y, face, 1.0 - exp(-delta * 6.0))
			rig.rotation.x = lerp_angle(rig.rotation.x, sin(_hover_t * 1.2 + float(id)) * 0.05, 1.0 - exp(-delta * 6.0))
