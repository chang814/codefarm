#pragma once
// The scripted route through the whole main line. Each stage runs the
// exemplar of the newest skill (the same file the in-game hint shows),
// earns the next skill, and checks the pain that motivates it.

#include "playthrough.hpp"

#include <cstdio>
#include <set>

namespace playthrough {

struct Check {
    std::string name;
    bool ok = false;
    std::string detail;
};

struct Route {
    bool ok = false;
    std::string report;
    std::vector<Check> checks;
    std::vector<StageLog> stages;
    double total_seconds = 0;
    std::vector<std::string> exemplars_run;
};

inline Route play_full_route(bool verbose = false) {
    Route r;
    Player p;
    p.world.set_seed(20261111);
    std::ostringstream rep;
    auto check = [&](const std::string& name, bool ok, const std::string& detail = {}) {
        r.checks.push_back({name, ok, detail});
        if (verbose) std::printf("%s %s %s\n", ok ? "  ok  " : "  FAIL", name.c_str(), detail.c_str());
    };
    auto use = [&](const std::string& id) {
        // Before the skill is owned the exemplar must not compile (or, for
        // skills without new syntax, it simply runs the same code).
        const bool ok = p.load(id);
        check("exemplar " + id + " compiles after unlock", ok, p.error);
        r.exemplars_run.push_back(id);
        return ok;
    };
    auto locked_before = [&](const std::string& id) {
        const std::string err = p.compile_error(id);
        check("exemplar " + id + " needs its skill", !err.empty(), err);
    };
    auto buy = [&](UnlockId id, double max_s) {
        const bool ok = p.earn_and_buy(id, max_s);
        check(std::string("buy ") + unlock_id_name(id), ok, p.error);
        if (verbose && ok) {
            const StageLog& s = p.log.back();
            std::printf("        %-10s lv%d  %-24s %7.1fs  speed x%.2f  (running %s)  [h%lld w%lld c%lld p%lld pw%lld]\n",
                        s.bought.c_str(), s.level, s.cost.c_str(), s.seconds, s.speed, s.program.c_str(),
                        (long long)p.world.hay(), (long long)p.world.wood(), (long long)p.world.item(Item::Carrot),
                        (long long)p.world.item(Item::Pumpkin), (long long)p.world.item(Item::Power));
        }
        return ok;
    };
    // Harvest hits and misses over `secs`, skipping the first swing: a fresh
    // start may land on grass the interrupted run had just cut.
    auto misses_over = [&](double secs, int* ok_n, int* miss_n) {
        const int64_t from = p.world.tick() + p.world.action_ticks();
        p.run_until([] { return false; }, secs);
        p.harvest_counts(ok_n, miss_n, from);
    };
    int ok_n = 0, miss_n = 0;
    // Resource gained per second while running `id`.
    auto gain_rate = [&](const std::string& id, Item item, double secs) {
        p.load(id);
        const int64_t a = p.world.item(item);
        p.run_until([] { return false; }, secs);
        return static_cast<double>(p.world.item(item) - a) / secs;
    };
    // Steps walked per successful harvest while running `id`.
    auto moves_per_harvest = [&](const std::string& id, double secs) {
        p.load(id);
        p.run_until([] { return false; }, secs);
        int moves = 0, ok = 0;
        for (const auto& ev : p.interp().events()) {
            if (ev.kind == ActionKind::Move && ev.success) ++moves;
            if (ev.kind == ActionKind::Harvest && ev.success) ++ok;
        }
        return ok > 0 ? static_cast<double>(moves) / ok : 1e9;
    };
    // Hay + wood + carrots gained per second while running `id`.
    auto crop_rate = [&](const std::string& id, double secs) {
        p.load(id);
        auto crops = [&] { return p.world.hay() + p.world.wood() + p.world.item(Item::Carrot); };
        const int64_t a = crops();
        p.run_until([] { return false; }, secs);
        return static_cast<double>(crops() - a) / secs;
    };
    auto rate_text = [](double a, double b, const char* unit) {
        char buf[96];
        std::snprintf(buf, sizeof buf, "%.2f -> %.2f %s", a, b, unit);
        return std::string(buf);
    };
    // Earn with a program that produces the needed currency, then buy.
    auto buy_with = [&](UnlockId id, const std::string& earner, double max_s) {
        if (p.program() != earner && !p.load(earner)) return false;
        return buy(id, max_s);
    };
    // Columns where the drone turns North (row starts) during `secs`.
    auto row_start_columns = [&](double secs) {
        std::set<int> cols;
        const int64_t end = p.world.tick() + static_cast<int64_t>(secs * kTicksPerSecond);
        int last_y = p.world.drone_y();
        while (p.world.tick() < end) {
            p.run_until([] { return false; }, 0.05);
            if (p.world.drone_y() != last_y) cols.insert(p.world.drone_x());
            last_y = p.world.drone_y();
        }
        return static_cast<int>(cols.size());
    };
    // Distinct tiles the drone stands on during `secs` of play.
    auto coverage = [&](double secs) {
        std::set<std::pair<int, int>> seen;
        const int64_t end = p.world.tick() + static_cast<int64_t>(secs * kTicksPerSecond);
        while (p.world.tick() < end) {
            p.run_until([] { return false; }, 0.1);
            seen.insert({p.world.drone_x(), p.world.drone_y()});
        }
        return static_cast<int>(seen.size());
    };

    // A0 收获：跑一遍只拿 1 干草。
    if (!use("harvest")) goto done;
    p.run_until([] { return false; }, 2.0, 0);
    check("harvest once gives exactly 1 hay", p.world.hay() == 1, std::to_string(p.world.hay()));
    locked_before("loop");
    if (!buy(UnlockId::Loops, 60)) goto done;

    // A1 while：1x 时一刀接一刀都收到成熟草。
    if (!use("loop")) goto done;
    misses_over(20, &ok_n, &miss_n);
    check("while at 1x never misses", ok_n >= 15 && miss_n == 0,
          std::to_string(ok_n) + " ok / " + std::to_string(miss_n) + " miss");
    if (!buy(UnlockId::Speed, 120)) goto done;

    // A2 加速：同一份 while 开始打空。
    if (!use("speed")) goto done;
    check("if is locked before Conditions", !p.compile_error("iff").empty());
    {
        Interpreter query;
        query.bind(&p.world);
        const auto error = query.load("#include <bits/stdc++.h>\nusing namespace std;\nint main() { can_harvest(); return 0; }\n");
        check("can_harvest alone is locked before Conditions", !error.empty(), error);
    }
    misses_over(20, &ok_n, &miss_n);
    check("after speed plain while keeps resetting grass", ok_n == 0 && miss_n > 30,
          std::to_string(ok_n) + " ok / " + std::to_string(miss_n) + " miss");
    locked_before("iff");
    // A blind fast loop cannot earn Conditions. Stop, let grass recover, then
    // run the opening single-harvest program with idle time between clicks.
    // This uses only visible player actions, including when savings are low.
    if (!use("harvest")) goto done;
    p.interp().stop();
    p.run_until([] { return false; }, 1.1, 0);
    for (int clicks = 0; !p.world.can_unlock(UnlockId::Conditions) && clicks < 12; ++clicks) {
        if (!p.load("harvest")) goto done;
        p.run_until([] { return false; }, 1.1, 0);
    }
    check("manual harvest and idle can afford Conditions after stall", p.world.can_unlock(UnlockId::Conditions));
    if (!buy(UnlockId::Conditions, 120)) goto done;

    // A3 if：不再打空。
    {
        // Both programs get the same naturally earned state, growth phase and
        // exact time budget. Copying this checkpoint adds no resources/skills.
        auto sample = [&](const std::string& id) {
            Player trial;
            trial.world = p.world;
            const auto start = trial.world.hay();
            check("comparison loads " + id, trial.load(id), trial.error);
            trial.interp().advance(30 * kTicksPerSecond);
            check("comparison runs " + id, !trial.interp().has_error(), trial.interp().error());
            int good = 0, misses = 0, late_good = 0;
            bool durations_ok = true;
            for (const auto& ev : trial.interp().events()) {
                if (ev.kind != ActionKind::Harvest) continue;
                durations_ok &= ev.duration_ticks == trial.world.action_ticks();
                if (ev.success) {
                    ++good;
                    if (ev.start_tick >= p.world.tick() + 2 * kTicksPerSecond) ++late_good;
                } else ++misses;
            }
            check("comparison harvest uses action_ticks " + id, durations_ok);
            check("comparison harvest pattern " + id,
                  id == "speed" ? (late_good == 0 && misses >= 50) : (good >= 28 && misses == 0),
                  std::to_string(good) + " ok / " + std::to_string(misses) + " miss / " + std::to_string(late_good) + " late ok");
            return trial.world.hay() - start;
        };
        const auto blind = sample("speed");
        const auto guarded = sample("iff");
        check("speed blind loop stalls over 30s", blind >= 0 && blind <= 2,
              std::to_string(blind) + " hay / 30s");
        check("Conditions restores actual output over equal budget", guarded >= 28 && guarded > blind,
              std::to_string(blind) + " -> " + std::to_string(guarded) + " hay / 30s");
    }
    if (!use("iff")) goto done;
    misses_over(20, &ok_n, &miss_n);
    check("if + can_harvest never misses", ok_n >= 15 && miss_n == 0,
          std::to_string(ok_n) + " ok / " + std::to_string(miss_n) + " miss");
    locked_before("move");
    if (!buy(UnlockId::Movement, 300)) goto done;

    // A4 移动：一格田的收入有上限，走一垄更多。
    {
        const double before = gain_rate("iff", Item::Hay, 30);
        if (!use("move")) goto done;
        const double after = gain_rate("move", Item::Hay, 30);
        check("walking a row earns more than one tile", after > before * 1.2, rate_text(before, after, "hay/s"));
    }
    locked_before("forl");
    if (!buy(UnlockId::ForLoop, 300)) goto done;
    // A5 for：不用手写一串 move 就能绕满 3×3。
    {
        p.load("move");
        const int before = coverage(20);
        if (!use("forl")) goto done;
        const int after = coverage(20);
        check("for lap covers the whole 3x3", before == 3 && after == 9,
              std::to_string(before) + " -> " + std::to_string(after) + " tiles");
    }
    locked_before("till");
    if (!buy(UnlockId::Till, 300)) goto done;
    if (!use("till")) goto done;
    {
        const int64_t hay0 = p.world.hay();
        p.run_until([] { return false; }, 5, 0);
        check("tilled row yields nothing yet", p.world.hay() == hay0, std::to_string(p.world.hay() - hay0));
    }
    if (!use("forl")) goto done;
    locked_before("plant");
    if (!buy(UnlockId::Plant, 400)) goto done;
    if (!use("plant")) goto done;
    p.run_until([] { return false; }, 30);
    check("bushes give wood", p.world.wood() >= 5, std::to_string(p.world.wood()));
    check("all-bush field stops hay", p.world.hay() < 20, std::to_string(p.world.hay()));

    // B1 变量：i 能拿来分支，留一列草。
    locked_before("vars");
    if (!buy(UnlockId::Variables, 600)) goto done;
    {
        const double before = gain_rate("plant", Item::Hay, 30);
        if (!use("vars")) goto done;
        const double after = gain_rate("vars", Item::Hay, 30);
        check("a grass column brings hay back", before == 0 && after >= 0.1, rate_text(before, after, "hay/s"));
    }
    // B2 const 边长。
    if (!buy(UnlockId::Const, 600)) goto done;
    if (!use("constn")) goto done;
    // B3 感知：按坐标而不是按 i 分列。
    locked_before("senses");
    if (!buy(UnlockId::Senses, 600)) goto done;
    if (!use("senses")) goto done;
    // B4 运算符：偶数列草、奇数列灌木。
    locked_before("ops");
    if (!buy(UnlockId::Operators, 900)) goto done;
    if (!use("ops")) goto done;
    // B5 扩田：写死 kSize 的程序在 4×4 上漏格，get_world_size() 补全。
    locked_before("expand");
    if (!buy(UnlockId::Expand, 900)) goto done;
    {
        p.load("ops");
        const int before = row_start_columns(40);
        if (!use("expand")) goto done;
        const int after = row_start_columns(40);
        check("kSize=3 rows drift on 4x4, get_world_size keeps rows aligned", before > 1 && after == 1,
              std::to_string(before) + " -> " + std::to_string(after) + " start columns");
    }
    // B6 胡萝卜。
    if (!buy(UnlockId::Carrots, 900)) goto done;
    if (!use("carrot")) goto done;
    p.run_until([] { return false; }, 30);
    check("carrots grow", p.world.item(Item::Carrot) > 0, std::to_string(p.world.item(Item::Carrot)));
    // B7 成本查询（随胡萝卜一起到手）。
    check("costs come with carrots", p.world.is_unlocked(UnlockId::Costs));
    if (!use("costs")) goto done;
    if (!buy(UnlockId::Speed, 900)) goto done;
    // B8 浇水。
    locked_before("water");
    if (!buy(UnlockId::Watering, 900)) goto done;
    if (!use("water")) goto done;
    // B9 树。
    if (!buy(UnlockId::Trees, 1500)) goto done;
    if (!use("tree")) goto done;
    {
        const double before = gain_rate("water", Item::Wood, 60);
        const double after = gain_rate("tree", Item::Wood, 60);
        check("trees out-produce bushes", after > before * 1.5, rate_text(before, after, "wood/s"));
    }
    // B12 草产量：程序不变，一刀两份干草。
    if (!buy(UnlockId::HayYield, 900)) goto done;
    if (!use("hayup")) goto done;
    check("hay yield 2 per grass", p.world.entity_yield(EntityType::Grass) == 2);
    // 木头富余：胡萝卜升一级，每株收 2 根。
    if (!buy(UnlockId::Carrots, 900)) goto done;
    // B10 函数：把一格的照料抽成 tendTile()。
    locked_before("func");
    if (!buy(UnlockId::Functions, 1200)) goto done;
    if (!use("func")) goto done;
    // B11 引用：计数带回 main，收满 100 次就停。
    locked_before("ref");
    if (!buy(UnlockId::References, 1200)) goto done;
    if (!use("ref")) goto done;
    p.run_until([&] { return p.interp().is_finished(); }, 300, 0);
    check("ref program stops after 100 harvests", p.interp().is_finished());
    // B13 #include：tendTile 搬进 farm.hpp。
    locked_before("include");
    if (!buy(UnlockId::Includes, 1500)) goto done;
    if (!use("include")) goto done;
    // 扩到 5×5、Speed 3、胡萝卜 Lv3：后面的作物都要整片田和胡萝卜。
    if (!buy(UnlockId::Expand, 1500)) goto done;
    if (!buy(UnlockId::Carrots, 1500)) goto done;
    if (!buy(UnlockId::Speed, 1500)) goto done;
    // B14 向日葵：只收最大的那株，能量 ×8。
    if (!buy(UnlockId::Sunflowers, 1500)) goto done;
    // Sunflowers and pumpkins are planted with carrots: keep a stock and
    // go back to the carrot farm whenever it runs low.
    p.refill = {Item::Carrot, 30, 150, "include"};
    if (!p.top_up(Item::Carrot, 150, "include", 900)) goto done;
    if (!use("sun")) goto done;
    {
        const int64_t power0 = p.world.item(Item::Power);
        p.run_until([] { return false; }, 120);
        const int64_t gained = p.world.item(Item::Power) - power0;
        int ok = 0, miss = 0;
        p.harvest_counts(&ok, &miss);
        // Net of the power the walking burns; a non-biggest one pays just 1.
        check("sunflower: biggest one pays 8 power", ok > 0 && gained >= 4 * ok,
              std::to_string(gained) + " power from " + std::to_string(ok) + " harvests");
    }
    // B15 数组：记住每株花瓣，不再每收一株绕一圈。
    locked_before("array");
    if (!buy_with(UnlockId::Arrays, "include", 1500)) goto done;
    {
        const double before = moves_per_harvest("sun", 120);
        if (!use("array")) goto done;
        const double after = moves_per_harvest("array", 120);
        check("array walks far less per sunflower than rescanning", after * 2 < before,
              rate_text(before, after, "moves/harvest"));
    }
    // B16 struct：findBest() 一次带回 x 和 y。
    locked_before("rec");
    if (!buy_with(UnlockId::Structs, "include", 1500)) goto done;
    if (!use("rec")) goto done;
    p.run_until([] { return false; }, 30);
    // B18 南瓜：整片熟了一刀收，n³。
    if (!buy_with(UnlockId::Pumpkins, "include", 1800)) goto done;
    if (!p.top_up(Item::Carrot, 150, "include", 900)) goto done;
    if (!use("pumpkin")) goto done;
    {
        const int64_t before = p.world.item(Item::Pumpkin);
        p.run_until([&] { return p.world.item(Item::Pumpkin) > before; }, 600);
        const int64_t got = p.world.item(Item::Pumpkin) - before;
        const int n = p.world.world_size();
        check("one pumpkin harvest pays n^3", got >= static_cast<int64_t>(n) * n * n, std::to_string(got));
    }
    // B19 工具函数：max() 找最大花瓣。
    locked_before("util");
    if (!buy_with(UnlockId::Utilities, "pumpkin", 1800)) goto done;
    if (!use("util")) goto done;
    p.run_until([] { return false; }, 30);
    // B26a 调试：收南瓜时打印库存。
    locked_before("debug");
    if (!buy_with(UnlockId::Debug, "include", 900)) goto done;
    if (!use("debug")) goto done;
    p.run_until([&] { return !p.world.last_print().empty(); }, 600);
    check("quick_print shows pumpkin stock", !p.world.last_print().empty(), p.world.last_print());
    // B26b 计时：量一轮南瓜要多久。
    locked_before("timing");
    if (!buy_with(UnlockId::Timing, "debug", 1800)) goto done;
    if (!use("timing")) goto done;
    // B27 自动解锁：程序自己买南瓜升级。
    if (!buy_with(UnlockId::AutoUnlock, "timing", 2400)) goto done;
    if (!p.top_up(Item::Carrot, 300, "include", 900)) goto done;
    if (!use("autounlock")) goto done;
    {
        const int lv0 = p.world.num_unlocked(UnlockId::Pumpkins);
        p.run_until([&] { return p.world.num_unlocked(UnlockId::Pumpkins) > lv0; }, 900);
        check("program unlocks Pumpkins itself", p.world.num_unlocked(UnlockId::Pumpkins) > lv0,
              std::to_string(lv0) + " -> " + std::to_string(p.world.num_unlocked(UnlockId::Pumpkins)));
    }
    // B20 肥料：施过肥的树收获一半变奇怪物质。
    if (!buy_with(UnlockId::Fertilizer, "include", 1800)) goto done;
    if (!use("fert")) goto done;
    {
        const int64_t w0 = p.world.item(Item::WeirdSubstance);
        p.run_until([] { return false; }, 120);
        check("fertilized trees give weird substance", p.world.item(Item::WeirdSubstance) > w0,
              std::to_string(p.world.item(Item::WeirdSubstance) - w0));
    }
    // 木头富余：肥料升一级，每 10 秒两袋。
    if (!buy(UnlockId::Fertilizer, 900)) goto done;
    // B21 迷宫：右手扶墙拿金子。
    locked_before("maze");
    if (!buy_with(UnlockId::Mazes, "fert", 2400)) goto done;
    if (!p.top_up(Item::WeirdSubstance, 20, "fert", 900)) goto done;
    if (!use("maze")) goto done;
    {
        const int64_t g0 = p.world.item(Item::Gold);
        p.run_until([&] { return p.world.item(Item::Gold) > g0; }, 300);
        check("maze pays gold", p.world.item(Item::Gold) > g0, std::to_string(p.world.item(Item::Gold) - g0));
    }
    // B17 switch：转向写成 switch。
    locked_before("swenum");
    if (!buy_with(UnlockId::SwitchEnum, "include", 900)) goto done;
    if (!use("swenum")) goto done;
    // B22 仙人掌：冒泡排序后一刀收整片。
    if (!buy_with(UnlockId::Cactus, "autounlock", 2400)) goto done;
    if (!p.top_up(Item::Pumpkin, 150, "autounlock", 900)) goto done;
    if (!use("cactus")) goto done;
    {
        const int64_t c0 = p.world.item(Item::Cactus);
        p.run_until([&] { return p.world.item(Item::Cactus) > c0; }, 900);
        const int n = p.world.world_size();
        // A whole sorted field is one group of n² cacti and pays (n²)²; allow
        // a straggler that was still growing.
        check("sorted cactus field pays ~n^4", p.world.item(Item::Cactus) - c0 >= static_cast<int64_t>(n) * n * n * n / 2,
              std::to_string(p.world.item(Item::Cactus) - c0));
    }
    // B23 伴侣：树旁边种它想要的作物，收获 ×5。
    locked_before("companion");
    if (!buy_with(UnlockId::Companions, "autounlock", 2400)) goto done;
    {
        const double before = gain_rate("fert", Item::Wood, 120);
        if (!use("companion")) goto done;
        const double after = gain_rate("companion", Item::Wood, 120);
        check("companions boost wood", after > before, rate_text(before, after, "wood/s"));
    }
    // B24 恐龙：吃苹果长尾巴，摘帽换骨头。
    p.refill = {Item::Pumpkin, 30, 150, "autounlock"};
    if (!buy_with(UnlockId::Dinosaurs, "cactus", 2400)) goto done;
    if (!use("dino")) goto done;
    p.run_until([&] { return p.interp().is_finished(); }, 600, 0);
    check("dinosaur run pays bones", p.world.item(Item::Bone) > 0, std::to_string(p.world.item(Item::Bone)));
    // B26c 实验：缩小世界试排序。
    locked_before("debug2");
    // Gold comes from mazes, and every new maze eats weird substance.
    p.refill = {Item::WeirdSubstance, 5, 40, "fert"};
    if (!buy_with(UnlockId::Debug2, "swenum", 2400)) goto done;
    if (!use("debug2")) goto done;
    p.run_until([] { return false; }, 5);
    check("set_world_size shrinks the field", p.world.world_size() == 3, std::to_string(p.world.world_size()));
    // B26d 模拟：固定种子重放。
    locked_before("sim");
    if (!buy_with(UnlockId::Simulation, "swenum", 3600)) goto done;
    if (!use("sim")) goto done;
    p.run_until([] { return false; }, 30);
    // B25 多无人机：两架错开两行一起照料。
    locked_before("mega");
    if (!buy_with(UnlockId::Megafarm, "swenum", 3600)) goto done;
    // 田再扩两档（6×6、7×7）：一架无人机绕一圈明显变慢，这才是多机的痛。
    p.refill = {Item::Carrot, 30, 300, "include"};
    if (!buy_with(UnlockId::Expand, "include", 1800)) goto done;
    if (!buy_with(UnlockId::Expand, "include", 1800)) goto done;
    {
        crop_rate("fert", 60);  // let the freshly expanded field grow in first
        const double before = crop_rate("fert", 60);
        if (!use("mega")) goto done;
        const double after = crop_rate("mega", 60);
        check("two drones farm faster", after > before * 1.4, rate_text(before, after, "crops/s"));
    }
    // B27b 帽子：纯装饰。
    if (!buy_with(UnlockId::Hats, "mega", 1800)) goto done;
    if (!use("hats")) goto done;
    p.run_until([] { return false; }, 5);
    check("top hat on", p.world.hat() == Hat::TopHat);

done:
    r.stages = p.log;
    r.total_seconds = p.total_seconds();
    r.ok = true;
    for (const auto& c : r.checks) r.ok = r.ok && c.ok;
    rep << "total " << r.total_seconds << " s over " << r.stages.size() << " purchases";
    if (!p.error.empty()) rep << "\nlast error: " << p.error;
    r.report = rep.str();
    return r;
}

}  // namespace playthrough
