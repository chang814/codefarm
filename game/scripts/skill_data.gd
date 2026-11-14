extends RefCounted
class_name FarmSkillData

# Icon one-word labels and tree positions for the 1.0 main line.

# A readable learning tree, not a complete dependency graph. Multi-skill and
# alternative prerequisites remain in prerequisite_text() and the simulator.
const CANVAS_SIZE := Vector2(1028, 2048)
const CARD_SIZE := Vector2(100, 120)

static func edges() -> Array:
	return [
		["harvest", "loop"], ["loop", "speed"], ["loop", "hats"],
		["speed", "iff"], ["iff", "move"],
		["move", "forl"], ["move", "till"], ["move", "expand"],
		["forl", "vars"], ["vars", "constn"], ["vars", "ops"],
		["till", "plant"], ["plant", "senses"], ["plant", "swenum"],
		["plant", "hayup"], ["plant", "debug"], ["senses", "carrot"],
		["carrot", "costs"], ["costs", "autounlock"],
		["carrot", "tree"], ["carrot", "func"], ["carrot", "water"],
		["func", "ref"], ["func", "include"], ["func", "array"], ["func", "sun"],
		["array", "rec"], ["array", "pumpkin"], ["sun", "util"],
		["water", "fert"], ["fert", "maze"], ["maze", "mega"],
		["pumpkin", "timing"], ["pumpkin", "companion"], ["pumpkin", "cactus"],
		["cactus", "dino"], ["debug", "debug2"], ["debug2", "sim"],
	]


static func prerequisite_text(id: String) -> String:
	# Transitive requirements omitted; AND / OR wording mirrors world.cpp.
	var extra := {
		"carrot": "感知", "tree": "胡萝卜、运算", "func": "胡萝卜、变量",
		"sun": "函数", "array": "函数", "pumpkin": "数组",
		"util": "南瓜或向日葵", "fert": "浇水", "maze": "肥料、函数",
		"cactus": "南瓜、向日葵、运算", "companion": "南瓜、树木",
		"mega": "迷宫、引用", "timing": "南瓜或向日葵",
		"debug2": "调试或迷宫", "sim": "实验或迷宫",
		"costs": "随胡萝卜获得", "autounlock": "成本",
	}
	if extra.has(id):
		return str(extra[id])
	for edge in edges():
		if edge[1] == id:
			return str({"harvest": "收获", "loop": "循环", "speed": "加速",
				"iff": "条件", "move": "移动", "forl": "计数", "vars": "变量",
				"till": "耕地", "plant": "种植", "func": "函数", "array": "数组",
				"cactus": "仙人掌"}.get(edge[0], edge[0]))
	return "开局已有"



static func nodes(host: Object) -> Array:
	var list := [
		_n("harvest", "收获", _p(3, 0), true, 0, "", "harvest()", "给 bot 下指令"),
		_n("loop", "循环", _p(3, 1), host.loops_unlocked(), host.unlock_cost("loop"), "harvest", "while", "不用每次点运行"),
		_n("hats", "帽子", _p(5, 1), host.is_unlocked("hats"), 0, "loop", "装饰", "换一顶帽子"),
		_n("speed", "加速", _p(3, 2), host.speed_unlocked(), host.unlock_cost("speed"), "loop", "加速", "动作更快"),
		_n("iff", "条件", _p(3, 3), host.conditions_unlocked(), host.unlock_cost("iff"), "speed", "if", "成熟再收"),
		_n("move", "移动", _p(3, 4), host.movement_unlocked(), host.unlock_cost("move"), "iff", "move", "走出一格田"),
		_n("forl", "计数", _p(1, 5), host.for_unlocked(), host.unlock_cost("forl"), "move", "for", "走过整垄"),
		_n("expand", "扩田", _p(5, 5), host.is_unlocked("expand"), 0, "move", "边长", "更大的田"),
		_n("till", "耕地", _p(3, 5), host.till_unlocked(), host.unlock_cost("till"), "move", "till", "改地表"),
		_n("vars", "变量", _p(1, 6), host.is_unlocked("vars"), 0, "forl", "int", "记下数字"),
		_n("plant", "种植", _p(3, 6), host.plant_unlocked(), host.unlock_cost("plant"), "till", "plant", "种第二种作物"),
		_n("swenum", "分支", _p(4, 7), host.is_unlocked("swenum"), 0, "plant", "switch", "按作物分支"),
		_n("constn", "常量", _p(0, 7), host.is_unlocked("constn"), 0, "vars", "const", "写出边长"),
		_n("ops", "运算", _p(1, 7), host.is_unlocked("ops"), 0, "vars", "% &&", "计算与组合"),
		_n("senses", "感知", _p(3, 7), host.is_unlocked("senses"), 0, "plant", "坐标", "知道自己在哪"),
		_n("hayup", "草产", _p(5, 7), host.is_unlocked("hayup"), 0, "plant", "产量", "每刀更多干草"),
		_n("carrot", "胡萝卜", _p(3, 8), host.is_unlocked("carrot"), 0, "senses", "Carrot", "第三种货币"),
		_n("func", "函数", _p(3, 9), host.is_unlocked("func"), 0, "vars", "函数", "复用一段代码"),
		_n("costs", "成本", _p(1, 8), host.is_unlocked("costs"), 0, "carrot", "get_cost", "别写死花费"),
		_n("water", "浇水", _p(5, 9), host.is_unlocked("water"), 0, "carrot", "浇水", "作物长得更快"),
		_n("tree", "树木", _p(2, 9), host.is_unlocked("tree"), 0, "carrot", "Tree", "更多木头"),
		_n("ref", "引用", _p(0, 10), host.is_unlocked("ref"), 0, "func", "int&", "把计数带回来"),
		_n("include", "分文件", _p(1, 10), host.is_unlocked("include"), 0, "func", "#include", "工具函数安放处"),
		_n("sun", "向日葵", _p(4, 10), host.is_unlocked("sun"), 0, "func", "measure", "量花瓣找最大"),
		_n("fert", "肥料", _p(5, 10), host.is_unlocked("fert"), 0, "water", "肥料", "催熟并感染"),
		_n("debug", "调试", _p(6, 7), host.is_unlocked("debug"), 0, "plant", "打印", "看清程序"),
		_n("array", "数组", _p(3, 10), host.is_unlocked("array"), 0, "func", "数组", "记住每一格"),
		_n("pumpkin", "南瓜", _p(3, 11), host.is_unlocked("pumpkin"), 0, "array", "南瓜", "合并与枯死"),
		_n("maze", "迷宫", _p(5, 11), host.is_unlocked("maze"), 0, "fert", "迷宫", "寻找宝藏"),
		_n("timing", "计时", _p(1, 12), host.is_unlocked("timing"), 0, "pumpkin", "时间", "对比两次运行"),
		_n("rec", "结构体", _p(2, 11), host.is_unlocked("rec"), 0, "array", "struct", "一格多项状态"),
		_n("util", "工具", _p(4, 11), host.is_unlocked("util"), 0, "pumpkin", "min/max", "少写比较"),
		_n("cactus", "仙人掌", _p(3, 12), host.is_unlocked("cactus"), 0, "pumpkin", "swap", "排序后一次收"),
		_n("debug2", "实验", _p(6, 8), host.is_unlocked("debug2"), 0, "debug", "缩小田", "对照实验"),
		_n("autounlock", "自动", _p(0, 8), host.is_unlocked("autounlock"), 0, "costs", "unlock", "程序自己买技能"),
		_n("companion", "伴侣", _p(2, 12), host.is_unlocked("companion"), 0, "pumpkin", "伴侣", "按请求布局"),
		_n("dino", "恐龙", _p(3, 13), host.is_unlocked("dino"), 0, "cactus", "帽子", "蛇与骨头"),
		_n("mega", "多机", _p(5, 12), host.is_unlocked("mega"), 0, "maze", "无人机", "并行干活"),
		_n("sim", "模拟", _p(6, 9), host.is_unlocked("sim"), 0, "debug2", "模拟", "可复现重放"),
	]
	for node in list:
		if str(node["id"]) == "harvest":
			continue
		node["cost_map"] = host.unlock_cost_map(node["id"])
		node["level"] = host.num_unlocked(node["id"])
		node["can_buy"] = host.can_unlock(node["id"])
		node["owned"] = host.is_unlocked(node["id"])
	return list


static func _p(col: int, row: int) -> Vector2:
	# Even column/row grid so branches line up and spacing stays even.
	return Vector2(32.0 + float(col) * 144.0, 24.0 + float(row) * 144.0)


static func _n(id: String, nam: String, pos: Vector2, owned: bool, cost: int, req: String, idea: String, pain: String) -> Dictionary:
	return {"id": id, "name": nam, "pos": pos, "owned": owned, "cost": cost, "req": req, "idea": idea, "pain": pain, "soon": false}


static func cost_text(cost_map: Dictionary) -> String:
	var parts: PackedStringArray = []
	var names := {
		"hay": "干草", "wood": "木头", "carrot": "胡萝卜", "pumpkin": "南瓜",
		"cactus": "仙人掌", "gold": "金子", "bone": "骨头", "weird": "物质"
	}
	for k in ["hay", "wood", "carrot", "pumpkin", "cactus", "gold", "bone", "weird"]:
		var n := int(cost_map.get(k, 0))
		if n > 0:
			parts.append("%d %s" % [n, names[k]])
	if parts.is_empty():
		return "0"
	return " + ".join(parts)


const EXEMPLAR_DIR := "res://exemplars"

# Order the playthrough buys the skills in; each exemplar adds one idea to the
# one before it (docs/playthrough.md shows the step-by-step diffs).
const EXEMPLAR_ORDER := [
	"harvest", "loop", "speed", "iff", "move", "forl", "till", "plant", "vars", "constn",
	"senses", "ops", "expand", "carrot", "costs", "water", "tree", "hayup", "func", "ref",
	"include", "sun", "array", "rec", "pumpkin", "util", "debug", "timing", "autounlock", "fert",
	"maze", "swenum", "cactus", "companion", "dino", "debug2", "sim", "mega", "hats",
]

# One sentence: the pain this skill cures.
const PAIN := {
	"harvest": "每点一次运行，bot 只收一刀。",
	"loop": "每收一刀都要再点一次运行。",
	"speed": "小草没熟就被割掉，连续挥空没干草。",
	"iff": "未熟就砍会重置生长；等成熟再收割。",
	"move": "一格田写得再好，也只有一份收入。",
	"forl": "绕一圈要把 move 抄很多遍。",
	"till": "地只会自己长草，没法改。",
	"plant": "翻好的土是空的，什么也不长。",
	"vars": "for 的 i 只能数圈，不能拿来判断，整片田只能种一种东西。",
	"constn": "边长 3 写死在循环里，扩田时要到处改。",
	"senses": "绕过边缘以后，程序不知道自己站在哪一列。",
	"ops": "只有 == 和 !=，写不出「偶数列种草」。",
	"expand": "田变大以后，写死边长的程序会走歪。",
	"carrot": "只有干草和木头，后面的技能要胡萝卜。",
	"costs": "种植费会随升级变化，写死的数字迟早种不下去。",
	"water": "胡萝卜长得慢，绕一圈回来还没熟。",
	"tree": "灌木一次只出 1 根木头，大额升级买不起。",
	"hayup": "每刀只出 1 份干草，干草升级很贵。",
	"func": "照料一格的代码挤在 main 里，复制到哪都要改好几处。",
	"ref": "函数没法把计数带回 main。",
	"include": "工具函数无处安放，每个程序都要从头抄。",
	"sun": "加速以后动作仍偏慢，需要一种能攒起来的速度。",
	"array": "每收一株向日葵，都要重新绕场量一遍花瓣。",
	"rec": "找最大花瓣要带回 x 和 y 两个数，函数只能返回一个。",
	"swenum": "转向写成一串 if，又长又容易漏。",
	"pumpkin": "需要越种越划算的作物：整片熟透一起收。",
	"util": "手写找最大值又长又容易错。",
	"fert": "迷宫要奇怪物质，现有作物给不了。",
	"maze": "后面的节点要金子，作物给不了。",
	"cactus": "需要更高阶的货币，乱摆的仙人掌一株只值 1 个。",
	"companion": "同样的田，产量到顶了。",
	"dino": "伴侣升级要骨头。",
	"mega": "田大了，一架无人机绕一圈太慢。",
	"debug": "看不见库存在程序里怎么变。",
	"timing": "不知道一轮花了多久，没法比较两版代码。",
	"debug2": "在大田上试一次排序要等很久。",
	"sim": "每次重跑作物长得不一样，比较不公平。",
	"autounlock": "技能还得手动点，程序没法自己花掉库存。",
	"hats": "想给 bot 换个样子。",
}


static func pain(id: String) -> String:
	return String(PAIN.get(id, ""))


const REMEDY := {
	"harvest": "在 main 里写 harvest(); 再点实心三角，收一刀。",
	"loop": "用 while 包住收割，让同一段操作持续执行。",
	"speed": "动作更快，草仍长 400 tick；买「条件」后再按成熟与否收割。",
	"iff": "在已有 while 里加条件；未熟只查询，成熟才收。",
	"move": "收完走向下一格；越过田边会从对面第一格出现。",
	"forl": "用 for 重复走一垄，代替手抄多次 move。",
	"till": "用 till() 翻土；空土不会自己长草，下一步要种植。",
	"plant": "在空土上 plant(Bush)，等成熟再收木头。",
	"vars": "把需要记住的数字放进 int，在判断里使用。",
	"constn": "给不变的边长起名字，循环共用这一处定义。",
	"senses": "用 get_pos_x() 读当前列，再决定照料哪种作物。",
	"ops": "用 % 区分奇偶列，用 && 组合条件。",
	"expand": "购买会清田；改用 get_world_size()，让循环跟着边长走。",
	"carrot": "在土上种胡萝卜，用干草支付种植费，收新资源。",
	"costs": "先 get_cost() 查价格，再决定库存够不够种。",
	"water": "水罐会补给；缺水时 use_item(Water)，缩短生长等待。",
	"tree": "种树产更多木头，留意相邻树会拖慢生长。",
	"hayup": "购买后每刀干草更多，仍用成熟判断收割。",
	"func": "把照料一格提成函数，在每个格子调用它。",
	"ref": "用 int& 参数，把函数内的计数写回调用处。",
	"include": "把工具放进 farm.hpp，再从主程序 include。",
	"sun": "用 measure() 量花瓣，先收最大的一株攒能量。",
	"array": "用数组保存已量过的花瓣，减少重复查询。",
	"rec": "用 struct 把坐标等相关状态作为一项返回。",
	"swenum": "用 switch 把不同方向的操作分开，记得 break。",
	"pumpkin": "补种枯南瓜，等整块成熟后一次收合并产量。",
	"util": "用 max() 保留当前最大值，少写重复比较。",
	"fert": "用肥料催熟；感染作物收获时会产出奇怪物质。",
	"maze": "对灌木用奇怪物质造迷宫，can_move() 探路找宝藏。",
	"cactus": "用 measure() 比大小、swap() 排序，再整片收。",
	"companion": "get_companion() 读请求，在指定格种配套作物增产。",
	"dino": "戴恐龙帽走路吃苹果，摘帽结算骨头；此玩法不跨边。",
	"mega": "把独立工作交给 spawn_drone()；子机参数按值传入。",
	"debug": "用 quick_print() 看库存；输出显示在调试记录里。",
	"timing": "运行前后各读 get_time()，比较一轮耗时。",
	"debug2": "临时缩小田地做实验，程序停止会恢复原大小。",
	"sim": "用相同 seed 运行 simulate()，公平比较两份程序。",
	"autounlock": "资源足够时调用 unlock()，让程序自己购买。",
	"hats": "change_hat() 换造型；装饰不改变收割规则。",
}

static func remedy(id: String) -> String:
	return str(REMEDY.get(id, ""))

static func guidance(id: String) -> String:
	return pain(id) + "\n" + remedy(id) + "\n下一行：" + next_line(id)


static func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


# The exemplar program for a skill: the exact file the playthrough test runs.
static func exemplar(id: String) -> String:
	return _read_text("%s/%s.cpp" % [EXEMPLAR_DIR, id])


# Extra files an exemplar includes, e.g. include.farm.hpp -> {"farm.hpp": text}.
static func exemplar_headers(id: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(EXEMPLAR_DIR)
	if dir == null:
		return out
	var prefix := id + "."
	for file_name in dir.get_files():
		if file_name.begins_with(prefix) and file_name != id + ".cpp":
			out[file_name.substr(prefix.length())] = _read_text("%s/%s" % [EXEMPLAR_DIR, file_name])
	return out


# Kept for callers that still ask for a "template": it is the exemplar now.
static func template(id: String) -> String:
	return exemplar(id)


static func knowledge(id: String) -> String:
	var table := {
		"expand": "购买后田会变大并清空现有作物。请改用 get_world_size() 遍历，不要把边长写死。",
		"vars": "解锁后循环变量 i 和自己声明的 int / bool 可以出现在表达式里。",
		"sun": "measure() 返回花瓣 7–15。场上至少 10 株向日葵时，收当前最大瓣得 8 倍能量；收错则这次和下次都没有奖励。不要在界面上找最大瓣。",
		"pumpkin": "约 20% 成熟时枯死，枯南瓜收一刀会清掉。完整的 n×n 成熟南瓜按 n³ 结算（n≥6 为 6n²），必须整块合并后收。",
		"maze": "对灌木使用足够的奇怪物质生成迷宫。打错格子迷宫会消失。can_move 探路几乎免费。",
		"cactus": "尺寸 0–9。田里每株都满足北、东邻居不小于自己，南、西邻居不大于自己时，一次收整片 n 株得 n²。田边不跨边比较。",
		"dino": "戴上恐龙帽后不能环绕，走到尾巴上会失败。摘帽得到尾长的平方块骨头。",
		"mega": "子机没有共享变量，参数按值拷贝。两台机器同一格同时浇水可能会浪费一罐。",
	}
	return String(table.get(id, ""))


static func next_line(id: String) -> String:
	if id == "speed":
		return next_line("iff")
	var needles := {
		"harvest": "harvest();", "loop": "while (true)", "iff": "if (can_harvest()) harvest();",
		"move": "move(East);", "forl": "for (", "till": "till();", "plant": "plant(Bush)",
		"vars": "if (i == 0)", "constn": "const int", "senses": "get_pos_x()", "ops": "%",
		"expand": "get_world_size()", "carrot": "plant(Carrot)", "costs": "get_cost(",
		"water": "use_item(Water", "tree": "plant(Tree)", "hayup": "harvest();",
		"func": "void ", "ref": "int&", "include": '#include "farm.hpp"',
		"sun": "measure()", "array": "[", "rec": "struct ", "swenum": "switch (",
		"pumpkin": "plant(Pumpkin)", "util": "max(", "fert": "use_item(Fertilizer",
		"maze": "can_move(", "cactus": "swap(", "companion": "get_companion()",
		"dino": "change_hat(", "mega": "spawn_drone(", "debug": "quick_print(",
		"timing": "get_time()", "debug2": "set_world_size(", "sim": "simulate(",
		"autounlock": "unlock(", "hats": "change_hat(",
	}
	if id == "iff":
		var source_lines := exemplar(id).split("\n")
		for i in range(source_lines.size() - 1):
			if source_lines[i].contains("if (can_harvest())"):
				return source_lines[i].strip_edges().trim_suffix("{").strip_edges() + " " + source_lines[i + 1].strip_edges()
	var needle := str(needles.get(id, ""))
	var source := exemplar(id)
	for header in exemplar_headers(id).values():
		source += "\n" + str(header)
	for line in source.split("\n"):
		if needle != "" and line.contains(needle):
			return line.strip_edges()
	return ""  # Never invent a second display-only program.
