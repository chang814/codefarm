#include "codefarm/interpreter.hpp"
#include "codefarm/world.hpp"

#include <iostream>
#include <string>
#include <cmath>

using namespace codefarm;

static std::ostream& operator<<(std::ostream& o, EntityType t) { return o << entity_type_name(t); }
static std::ostream& operator<<(std::ostream& o, GroundType t) { return o << ground_type_name(t); }


static int g_failed = 0;
static int g_passed = 0;

#define CHECK(cond)                                                              \
    do {                                                                         \
        if (cond) {                                                              \
            ++g_passed;                                                          \
        } else {                                                                 \
            ++g_failed;                                                          \
            std::cerr << "FAIL  " << __FILE__ << ":" << __LINE__ << "  "         \
                      << #cond << "\n";                                          \
        }                                                                        \
    } while (0)

#define CHECK_EQ(a, b)                                                           \
    do {                                                                         \
        const auto _va = (a);                                                    \
        const auto _vb = (b);                                                    \
        if (_va == _vb) {                                                        \
            ++g_passed;                                                          \
        } else {                                                                 \
            ++g_failed;                                                          \
            std::cerr << "FAIL  " << __FILE__ << ":" << __LINE__ << "  "         \
                      << #a << " == " << #b << "  (" << _va << " vs " << _vb     \
                      << ")\n";                                                  \
        }                                                                        \
    } while (0)

static std::string main_of(const std::string& body) {
    return "int main() {\n" + body + "\n    return 0;\n}\n";
}

#include "test_v2.inc"

static void harvest_ripe(World& world) {
    world.wait_until_mature();
    if (!world.grass_mature()) {
        world.set_grass_mature();
    }
    const ActionResult r = world.harvest();
    CHECK(r.success);
    CHECK_EQ(r.ticks, world.action_ticks());
}

static void harvest_n_ripe(World& world, int n) {
    for (int i = 0; i < n; ++i) {
        harvest_ripe(world);
    }
}

static void grant(World& world, UnlockId id) { world.grant_for_test(id); }

static void test_initial_world() {
    World world;
    CHECK_EQ(world.world_size(), 1);
    CHECK_EQ(world.drone_x(), 0);
    CHECK_EQ(world.drone_y(), 0);
    CHECK_EQ(world.hay(), 0);
    CHECK(!world.loops_unlocked());
    CHECK(world.grass_mature());
    CHECK_EQ(world.tick(), 0);
}

static void test_harvest_ripe_gives_hay() {
    World world;
    const ActionResult r = world.harvest();
    CHECK(r.success);
    CHECK_EQ(r.ticks, kBaseActionTicks);
    CHECK_EQ(world.hay(), 1);
    CHECK_EQ(world.tick(), kBaseActionTicks);
    // At 1x the swing lasts as long as the grow cycle, so the new shoot
    // is ripe when harvest() returns.
    CHECK(world.grass_mature());
    CHECK_EQ(world.grass_grow_ticks_left(), 0);
}

static void test_unripe_grass_restarts_growth() {
    World world;
    world.start_grass_growth();
    CHECK(!world.grass_mature());
    world.advance(100);
    CHECK(!world.grass_mature());
    CHECK_EQ(world.hay(), 0);
    const ActionResult r = world.try_harvest();
    CHECK(!r.success);
    CHECK_EQ(r.ticks, world.action_ticks());
    CHECK_EQ(r.ticks, kBaseActionTicks);
    CHECK_EQ(world.hay(), 0);
    CHECK_EQ(world.tile().entity, EntityType::Grass);
    CHECK_EQ(world.grass_grow_ticks_left(), kGrassGrowTicks);
    CHECK_EQ(world.tile().grow_ticks_total, kGrassGrowTicks);
    world.advance(kGrassGrowTicks - 1);
    CHECK(!world.grass_mature());
    world.advance(1);
    CHECK(world.grass_mature());
}

static void test_empty_harvest() {
    World world;
    world.set_entity_empty();
    const int64_t start = world.tick();
    const ActionResult r = world.harvest();
    CHECK(!r.success);
    CHECK_EQ(r.ticks, world.action_ticks());
    CHECK_EQ(world.hay(), 0);
    CHECK_EQ(world.tick(), start + world.action_ticks());
}

static void test_can_harvest_costs_one_tick() {
    World world;
    const ActionResult yes = world.can_harvest();
    CHECK(yes.success);
    CHECK_EQ(yes.ticks, kFailOrQueryTicks);
    CHECK_EQ(world.tick(), 1);

    world.set_entity_empty();
    const ActionResult no = world.can_harvest();
    CHECK(!no.success);
    CHECK_EQ(no.ticks, kFailOrQueryTicks);
    CHECK_EQ(world.tick(), 2);
}

static void test_five_hay_unlocks_loops() {
    World world;
    for (int i = 0; i < 4; ++i) {
        harvest_ripe(world);
        CHECK(!world.loops_unlocked());
        CHECK(!world.can_unlock(UnlockId::Loops));
        CHECK_EQ(world.hay_shortfall(UnlockId::Loops), 5 - (i + 1));
    }
    CHECK_EQ(world.hay(), 4);
    harvest_ripe(world);
    CHECK_EQ(world.hay(), 5);
    CHECK(!world.loops_unlocked());
    CHECK(world.can_unlock(UnlockId::Loops));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Loops)), static_cast<int>(UnlockResult::Ok));
    CHECK(world.loops_unlocked());
    CHECK_EQ(world.hay(), 0);
    CHECK_EQ(world.hay_earned(), 5);
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Loops)), static_cast<int>(UnlockResult::AlreadyUnlocked));
}

static void test_while_rejected_before_unlock() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    while (true) { harvest(); }\n"));
    CHECK(!err.empty());
    CHECK(err.find("while") != std::string::npos ||
          err.find("循环") != std::string::npos);
    CHECK(!world.loops_unlocked());
}

static void test_harvest_events_and_line_numbers() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    harvest();\n"));
    CHECK_EQ(err, std::string());
    interp.start();
    interp.advance(kBaseActionTicks + 50);
    CHECK(interp.is_finished());
    CHECK_EQ(world.hay(), 1);
    CHECK_EQ(interp.events().size(), 1u);
    CHECK_EQ(interp.events()[0].line, 2);
    CHECK_EQ(interp.events()[0].start_tick, 0);
    CHECK_EQ(interp.events()[0].duration_ticks, kBaseActionTicks);
    CHECK(interp.events()[0].kind == ActionKind::Harvest);
    CHECK(interp.events()[0].success);
}

static void test_second_harvest_ripe_at_base_speed() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    harvest();\n    harvest();\n"));
    CHECK_EQ(err, std::string());
    interp.start();
    interp.advance(kBaseActionTicks * 2 + 10);
    CHECK(interp.is_finished());
    CHECK_EQ(world.hay(), 2);
    int harvests = 0;
    int fails = 0;
    for (const auto& ev : interp.events()) {
        if (ev.kind == ActionKind::Harvest) {
            CHECK_EQ(ev.duration_ticks, kBaseActionTicks);
            ++harvests;
            if (!ev.success) {
                ++fails;
            }
        }
    }
    CHECK_EQ(harvests, 2);
    CHECK_EQ(fails, 0);
}


static void test_highlight_stays_during_harvest() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    CHECK_EQ(interp.load(main_of("    harvest();\n")), std::string());
    interp.start();
    interp.advance(50);
    CHECK(interp.is_running());
    CHECK_EQ(interp.current_line(), 2);
    CHECK(interp.current_event() != nullptr);
    CHECK_EQ(interp.current_event()->duration_ticks, kBaseActionTicks);
    interp.advance(kBaseActionTicks);
    CHECK(interp.is_finished());
    CHECK_EQ(world.hay(), 1);
}

static void test_while_after_unlock() {
    World world;
    grant(world, UnlockId::Loops);
    CHECK(world.loops_unlocked());
    const int64_t hay_before = world.hay();
    const int64_t tick_before = world.tick();
    world.wait_until_mature();
    CHECK(world.grass_mature());

    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    while (true) {\n        harvest();\n    }\n"));
    CHECK_EQ(err, std::string());
    interp.start();
    interp.advance(kBaseActionTicks * 3 + 50);
    CHECK(interp.is_running());
    CHECK(world.hay() >= hay_before + 3);
    int harvests = 0;
    int fails = 0;
    int whiles = 0;
    for (const auto& ev : interp.events()) {
        if (ev.kind == ActionKind::Harvest) {
            CHECK_EQ(ev.line, 3);
            CHECK_EQ(ev.duration_ticks, kBaseActionTicks);
            if (ev.success) {
                ++harvests;
            } else {
                ++fails;
            }
        }
        if (ev.kind == ActionKind::WhileCheck) {
            CHECK_EQ(ev.line, 2);
            CHECK_EQ(ev.duration_ticks, 1);
            ++whiles;
        }
    }
    CHECK(harvests >= 3);
    CHECK_EQ(fails, 0);
    CHECK(whiles >= 3);
    CHECK(world.tick() >= tick_before + kBaseActionTicks * 3);
}

static void test_if_can_harvest() {
    World world;
    grant(world, UnlockId::Conditions);
    world.wait_until_mature();
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    if (can_harvest()) {\n        harvest();\n    }\n"));
    CHECK_EQ(err, std::string());
    interp.start();
    interp.advance(250);
    CHECK(interp.is_finished());
    CHECK_EQ(world.hay(), 1);
    CHECK_EQ(interp.events().size(), 2u);
    CHECK(interp.events()[0].kind == ActionKind::CanHarvest);
    CHECK_EQ(interp.events()[0].line, 2);
    CHECK_EQ(interp.events()[0].duration_ticks, 1);
    CHECK(interp.events()[0].success);
    CHECK(interp.events()[1].kind == ActionKind::Harvest);
    CHECK_EQ(interp.events()[1].line, 3);
    CHECK_EQ(interp.events()[1].duration_ticks, world.action_ticks());
}

static void test_if_skips_unripe() {
    World world;
    grant(world, UnlockId::Conditions);
    world.start_grass_growth();
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    if (can_harvest()) {\n        harvest();\n    }\n"));
    CHECK_EQ(err, std::string());
    interp.start();
    interp.advance(20);
    CHECK(interp.is_finished());
    CHECK_EQ(world.hay(), 0);
    CHECK(!world.grass_mature());
    CHECK_EQ(interp.events().size(), 1u);
    CHECK(interp.events()[0].kind == ActionKind::CanHarvest);
    CHECK(!interp.events()[0].success);
}

static void test_missing_semicolon_error_in_chinese() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    harvest()\n"));
    CHECK(!err.empty());
    CHECK(err.find("分号") != std::string::npos);
}

static void test_stop_halts_infinite_loop() {
    World world;
    grant(world, UnlockId::Loops);
    world.wait_until_mature();
    Interpreter interp;
    interp.bind(&world);
    CHECK_EQ(interp.load(main_of("    while (true) { harvest(); }\n")), std::string());
    interp.start();
    interp.advance(world.action_ticks() / 2);
    CHECK(interp.is_running());
    interp.stop();
    CHECK(!interp.is_running());
    const int64_t hay = world.hay();
    interp.advance(400);
    CHECK_EQ(world.hay(), hay);
}

static void test_exact_budget_finishes() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    CHECK_EQ(interp.load(main_of("    harvest();\n")), std::string());
    interp.start();
    interp.advance(kBaseActionTicks);
    CHECK(interp.is_finished());
    CHECK_EQ(world.hay(), 1);
    CHECK_EQ(world.tick(), kBaseActionTicks);
    CHECK(world.grass_mature());
}

static void test_standard_cpp_main() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string src =
        "#include <bits/stdc++.h>\n"
        "using namespace std;\n"
        "\n"
        "int main() {\n"
        "    harvest();\n"
        "    return 0;\n"
        "}\n";
    CHECK_EQ(interp.load(src), std::string());
    interp.start();
    interp.advance(kBaseActionTicks + 50);
    CHECK(interp.is_finished());
    CHECK_EQ(world.hay(), 1);
    CHECK_EQ(interp.events().size(), 1u);
    CHECK(interp.events()[0].kind == ActionKind::Harvest);
    CHECK_EQ(interp.events()[0].line, 5);
    CHECK_EQ(interp.events()[0].duration_ticks, kBaseActionTicks);
}

static void test_return_stops_program() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string src =
        "int main() {\n"
        "    harvest();\n"
        "    return 0;\n"
        "    harvest();\n"
        "}\n";
    CHECK_EQ(interp.load(src), std::string());
    interp.start();
    interp.advance(500);
    CHECK(interp.is_finished());
    CHECK_EQ(world.hay(), 1);
    CHECK_EQ(interp.events().size(), 1u);
}

static void test_statements_must_be_inside_main() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load("harvest();\n");
    CHECK(!err.empty());
    CHECK(err.find("main") != std::string::npos);
    const std::string err2 = interp.load("int main() {}\nharvest();\n");
    CHECK(!err2.empty());
    CHECK(err2.find("main") != std::string::npos);
}

static void test_hay_earned_tracks_lifetime() {
    World world;
    CHECK_EQ(world.hay(), 0);
    CHECK_EQ(world.hay_earned(), 0);
    harvest_ripe(world);
    CHECK_EQ(world.hay(), 1);
    CHECK_EQ(world.hay_earned(), 1);
    harvest_ripe(world);
    CHECK_EQ(world.hay(), 2);
    CHECK_EQ(world.hay_earned(), 2);
    world.reset();
    CHECK_EQ(world.hay(), 0);
    CHECK_EQ(world.hay_earned(), 0);
    CHECK_EQ(world.world_size(), 1);
    CHECK(!world.movement_unlocked());
}

static void test_move_rejected_before_unlock() {
    World world;
    const ActionResult blocked = world.try_move(Dir::East);
    CHECK(!blocked.success);
    CHECK_EQ(blocked.ticks, kFailOrQueryTicks);
    CHECK_EQ(world.drone_x(), 0);
    CHECK_EQ(world.drone_y(), 0);
    CHECK_EQ(world.world_size(), 1);

    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    move(East);\n"));
    CHECK(!err.empty());
    CHECK(err.find("移动") != std::string::npos || err.find("move") != std::string::npos);
    CHECK(!world.movement_unlocked());
}

static void test_expand_at_move_unlock_hay() {
    World world;
    grant(world, UnlockId::Conditions);
    harvest_n_ripe(world, kCostMove);
    CHECK_EQ(world.hay_earned(), kCostMove);
    CHECK_EQ(world.hay(), kCostMove);
    CHECK_EQ(world.world_size(), 1);
    CHECK(!world.movement_unlocked());
    CHECK(world.loops_unlocked());
    CHECK(world.conditions_unlocked());
    CHECK(world.can_unlock(UnlockId::Movement));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Movement)), static_cast<int>(UnlockResult::Ok));
    CHECK_EQ(world.hay(), 0);
    CHECK(world.movement_unlocked());
    CHECK_EQ(world.world_size(), 3);
    CHECK_EQ(world.drone_x(), 0);
    CHECK_EQ(world.drone_y(), 0);
    CHECK(!world.tile_mature(0, 0));
    for (int y = 0; y < 3; ++y) {
        for (int x = 0; x < 3; ++x) {
            if (x == 0 && y == 0) {
                continue;
            }
            CHECK(world.tile_mature(x, y));
            CHECK_EQ(world.tile_grow_ratio(x, y), 1.0);
        }
    }
}

static void test_movement_and_torus() {
    World world;
    grant(world, UnlockId::Movement);
    CHECK(world.movement_unlocked());
    CHECK_EQ(world.world_size(), 3);
    CHECK_EQ(world.drone_x(), 0);
    CHECK_EQ(world.drone_y(), 0);

    ActionResult r = world.move(Dir::East);
    CHECK(r.success);
    CHECK_EQ(r.ticks, world.move_ticks());
    CHECK_EQ(world.move_ticks(), world.action_ticks() / 2);
    CHECK_EQ(world.drone_x(), 1);
    CHECK_EQ(world.drone_y(), 0);

    r = world.move(Dir::North);
    CHECK(r.success);
    CHECK_EQ(world.drone_x(), 1);
    CHECK_EQ(world.drone_y(), 1);

    world.reset();
    grant(world, UnlockId::Movement);
    r = world.move(Dir::West);
    CHECK(r.success);
    CHECK_EQ(world.drone_x(), 2);
    CHECK_EQ(world.drone_y(), 0);
    r = world.move(Dir::South);
    CHECK(r.success);
    CHECK_EQ(world.drone_x(), 2);
    CHECK_EQ(world.drone_y(), 2);
    r = world.move(Dir::East);
    CHECK(r.success);
    CHECK_EQ(world.drone_x(), 0);
    CHECK_EQ(world.drone_y(), 2);
    r = world.move(Dir::North);
    CHECK(r.success);
    CHECK_EQ(world.drone_x(), 0);
    CHECK_EQ(world.drone_y(), 0);
}

static void test_independent_tile_growth() {
    World world;
    grant(world, UnlockId::Movement);
    harvest_ripe(world);
    CHECK(!world.tile_mature(0, 0));
    CHECK_EQ(world.grass_grow_ticks_left(), kGrassGrowTicks - world.action_ticks());
    const double home_ratio = world.tile_grow_ratio(0, 0);
    CHECK(home_ratio > 0.49 && home_ratio < 0.51);
    CHECK(world.tile_mature(1, 0));
    CHECK_EQ(world.tile_grow_ratio(1, 0), 1.0);

    const ActionResult moved = world.move(Dir::East);
    CHECK(moved.success);
    CHECK_EQ(world.drone_x(), 1);
    CHECK(world.grass_mature());
    // A step is half a swing, so the home tile is three quarters grown.
    CHECK(!world.tile_mature(0, 0));
    CHECK_EQ(world.tile_grow_ratio(0, 0), 0.75);
    world.advance(world.move_ticks());
    CHECK(world.tile_mature(0, 0));

    const ActionResult cut = world.harvest();
    CHECK(cut.success);
    CHECK(!world.tile_mature(1, 0));
    CHECK(world.tile_mature(0, 0));
    CHECK(world.tile_mature(2, 2));
}

static void test_move_in_program_and_progress() {
    World world;
    grant(world, UnlockId::Movement);
    world.wait_until_mature();
    Interpreter interp;
    interp.bind(&world);
    const std::string src =
        "#include <bits/stdc++.h>\n"
        "using namespace std;\n"
        "enum Dir { East, West, North, South };\n"
        "int main() {\n"
        "    move(East);\n"
        "    return 0;\n"
        "}\n";
    CHECK_EQ(interp.load(src), std::string());
    interp.start();
    interp.advance(50);
    CHECK(interp.is_running());
    CHECK_EQ(interp.current_line(), 5);
    CHECK(interp.current_event() != nullptr);
    CHECK(interp.current_event()->kind == ActionKind::Move);
    CHECK_EQ(interp.current_event()->duration_ticks, world.move_ticks());
    const double progress = interp.current_action_progress();
    CHECK(progress > 0.49 && progress < 0.51);
    CHECK_EQ(world.drone_x(), 1);
    CHECK_EQ(world.drone_y(), 0);
    interp.advance(world.action_ticks());
    CHECK(interp.is_finished());
    CHECK_EQ(world.drone_x(), 1);
}

static void test_harvest_progress_fill() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    CHECK_EQ(interp.load(main_of("    harvest();\n")), std::string());
    interp.start();
    CHECK_EQ(interp.current_action_progress(), 0.0);
    interp.advance(kBaseActionTicks / 2);
    const double mid = interp.current_action_progress();
    CHECK(mid > 0.49 && mid < 0.51);
    interp.advance(kBaseActionTicks / 2);
    CHECK(interp.is_finished());
}

static void test_if_rejected_before_unlock() {
    World world;
    grant(world, UnlockId::Loops);
    CHECK(world.loops_unlocked());
    CHECK(!world.conditions_unlocked());
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    if (can_harvest()) { harvest(); }\n"));
    CHECK(!err.empty());
    CHECK(err.find("条件") != std::string::npos || err.find("if") != std::string::npos);
    const std::string err2 = interp.load(main_of("    can_harvest();\n"));
    CHECK(!err2.empty());
}

static void test_speed_then_if_unlock_costs() {
    World world;
    grant(world, UnlockId::Loops);
    harvest_n_ripe(world, kCostSpeed - 1);
    CHECK(!world.speed_unlocked());
    CHECK(!world.can_unlock(UnlockId::Speed));
    harvest_ripe(world);
    CHECK_EQ(world.hay(), kCostSpeed);
    CHECK(world.can_unlock(UnlockId::Speed));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Speed)), static_cast<int>(UnlockResult::Ok));
    CHECK(world.speed_unlocked());
    CHECK_EQ(world.hay(), 0);
    CHECK_EQ(world.action_speed(), kActionSpeedBoosted);
    CHECK_EQ(world.action_ticks(), kBaseActionTicks / kActionSpeedBoosted);

    harvest_n_ripe(world, kCostIf);
    CHECK_EQ(world.hay(), kCostIf);
    CHECK(world.can_unlock(UnlockId::Conditions));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Conditions)), static_cast<int>(UnlockResult::Ok));
    CHECK(world.conditions_unlocked());
    CHECK_EQ(world.hay(), 0);
}

static void test_cannot_unlock_without_prerequisite() {
    World world;
    harvest_n_ripe(world, kCostLoops + kCostSpeed + kCostIf);
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Speed)), static_cast<int>(UnlockResult::LockedPrerequisite));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Conditions)), static_cast<int>(UnlockResult::LockedPrerequisite));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Loops)), static_cast<int>(UnlockResult::Ok));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Conditions)), static_cast<int>(UnlockResult::LockedPrerequisite));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Speed)), static_cast<int>(UnlockResult::Ok));
    CHECK(world.speed_unlocked());
    const int left = kCostIf;
    CHECK_EQ(world.hay(), left);
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Conditions)), static_cast<int>(UnlockResult::Ok));
    CHECK_EQ(world.hay(), 0);
}

static void test_till_and_plant_flow() {
    World world;
    grant(world, UnlockId::Till);
    CHECK(world.till_unlocked());
    CHECK(world.movement_unlocked());
    CHECK(!world.plant_unlocked());
    CHECK(world.tile().ground == GroundType::Grassland);

    Interpreter blocked;
    blocked.bind(&world);
    const std::string err_plant = blocked.load(main_of("    plant(Bush);\n"));
    CHECK(!err_plant.empty());

    const ActionResult tilled = world.till();
    CHECK(tilled.success);
    CHECK_EQ(tilled.ticks, world.action_ticks());
    CHECK(world.tile().ground == GroundType::Soil);
    CHECK(world.tile().entity == EntityType::None);
    CHECK(!world.grass_mature());

    const ActionResult retill = world.till();
    CHECK(retill.success);
    CHECK(world.tile().ground == GroundType::Grassland);
    CHECK(world.tile().entity == EntityType::Grass);
    CHECK(!world.grass_mature());

    grant(world, UnlockId::Plant);
    CHECK(world.plant_unlocked());
    CHECK(world.till().success);
    CHECK(world.tile().ground == GroundType::Soil);

    const ActionResult planted = world.try_plant(EntityType::Bush);
    CHECK(planted.success);
    CHECK_EQ(planted.ticks, world.action_ticks());
    CHECK(world.tile().entity == EntityType::Bush);
    CHECK(!world.tile().mature);
    CHECK_EQ(world.grow_ticks_left(), kBushGrowTicks);
    world.advance(planted.ticks);
    CHECK_EQ(world.grow_ticks_left(), kBushGrowTicks - world.action_ticks());

    const ActionResult early = world.try_harvest();
    CHECK(!early.success);
    world.wait_until_mature();
    CHECK(world.tile_mature(world.drone_x(), world.drone_y()));
    const ActionResult cut = world.harvest();
    CHECK(cut.success);
    CHECK_EQ(world.wood(), 1);
    CHECK_EQ(world.last_harvested(), std::string("Bush"));
    CHECK(world.tile().entity == EntityType::None);
    CHECK(world.tile().ground == GroundType::Soil);
}

static void test_plant_requires_soil() {
    World world;
    grant(world, UnlockId::Plant);
    CHECK(world.plant_unlocked());
    const ActionResult denied = world.try_plant(EntityType::Bush);
    CHECK(!denied.success);
    CHECK_EQ(denied.ticks, world.action_ticks());
}

static void test_compare_entity_and_ground() {
    World world;
    grant(world, UnlockId::Plant);
    world.till();
    world.plant(EntityType::Bush);
    Interpreter interp;
    interp.bind(&world);
    const std::string src = main_of(
        "    if (get_ground_type() == Soil) {\n"
        "        if (get_entity_type() == Bush) {\n"
        "        }\n"
        "    }\n");
    CHECK_EQ(interp.load(src), std::string());
    interp.start();
    interp.advance(10);
    CHECK(interp.is_finished());
    bool saw_ground = false;
    bool saw_entity = false;
    for (const auto& ev : interp.events()) {
        if (ev.kind == ActionKind::GetGround && ev.success) {
            saw_ground = true;
        }
        if (ev.kind == ActionKind::GetEntity && ev.success) {
            saw_entity = true;
        }
    }
    CHECK(saw_ground);
    CHECK(saw_entity);
}

static void test_for_rejected_before_unlock() {
    World world;
    grant(world, UnlockId::Movement);
    CHECK(world.movement_unlocked());
    CHECK(!world.for_unlocked());
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    for (int i = 0; i < 3; i++) { move(East); }\n"));
    CHECK(!err.empty());
    CHECK(err.find("for") != std::string::npos);
}

static void test_for_loop_moves_three_times() {
    World world;
    grant(world, UnlockId::ForLoop);
    CHECK(world.for_unlocked());
    CHECK_EQ(world.world_size(), 3);
    CHECK_EQ(world.drone_x(), 0);
    Interpreter interp;
    interp.bind(&world);
    const std::string src =
        "#include <bits/stdc++.h>\n"
        "using namespace std;\n"
        "enum Dir { East, West, North, South };\n"
        "int main() {\n"
        "    for (int i = 0; i < 3; i++) {\n"
        "        move(East);\n"
        "    }\n"
        "    return 0;\n"
        "}\n";
    CHECK_EQ(interp.load(src), std::string());
    interp.start();
    interp.advance(50);
    CHECK(interp.is_running());
    interp.advance(800);
    CHECK(interp.is_finished());
    CHECK_EQ(world.drone_x(), 0);
    CHECK_EQ(world.drone_y(), 0);
    int moves = 0;
    int fors = 0;
    for (const auto& ev : interp.events()) {
        if (ev.kind == ActionKind::Move && ev.success) {
            ++moves;
        }
        if (ev.kind == ActionKind::ForCheck) {
            ++fors;
        }
    }
    CHECK_EQ(moves, 3);
    CHECK(fors >= 4);
}

static void test_program_till_then_plant() {
    World world;
    grant(world, UnlockId::Plant);
    world.wait_until_mature();
    Interpreter interp;
    interp.bind(&world);
    const std::string src = main_of("    till();\n    plant(Bush);\n");
    CHECK_EQ(interp.load(src), std::string());
    interp.start();
    interp.advance(500);
    CHECK(interp.is_finished());
    CHECK(world.tile().ground == GroundType::Soil);
    CHECK(world.tile().entity == EntityType::Bush);
    CHECK(!world.tile().mature);
}

static void test_edit_distance_and_suggest() {
    CHECK_EQ(edit_distance("harvest", "harvest"), 0);
    CHECK_EQ(edit_distance("harvest", "harvset"), 2);
    CHECK_EQ(edit_distance("", "if"), 2);
    const std::vector<std::string> known = {"harvest", "do_a_flip", "move"};
    CHECK_EQ(suggest_identifier("harvset", known), std::string("harvest"));
    CHECK_EQ(suggest_identifier("do_a_flp", known), std::string("do_a_flip"));
    CHECK_EQ(suggest_identifier("zzzzzz", known), std::string());
}

static void test_missing_semicolon_span() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    harvest()\n"));
    CHECK(!err.empty());
    CHECK(err.find("分号") != std::string::npos);
    CHECK(interp.error_kind() == ErrorKind::MissingSemicolon);
    CHECK_EQ(interp.error_line(), 2);
    // "    harvest()" — ')' is column 13, insertion point is 14.
    CHECK_EQ(interp.error_col_start(), 14);
    CHECK_EQ(interp.error_col_end(), 15);
    CHECK(interp.error_suggestion().find(";") != std::string::npos);
}

static void test_typo_ident_span_and_suggestion() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    harvset();\n"));
    CHECK(!err.empty());
    CHECK(interp.error_kind() == ErrorKind::Typo);
    CHECK_EQ(interp.error_line(), 2);
    CHECK_EQ(interp.error_col_start(), 5);
    CHECK_EQ(interp.error_col_end(), 12);
    CHECK(interp.error_suggestion().find("harvest") != std::string::npos);
    CHECK(err.find("harvest") != std::string::npos);
}

static void test_unclosed_paren_points_at_opener() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    harvest(\n"));
    CHECK(!err.empty());
    CHECK(interp.error_kind() == ErrorKind::Unclosed);
    CHECK_EQ(interp.error_line(), 2);
    // "    harvest(" — '(' is column 12.
    CHECK_EQ(interp.error_col_start(), 12);
    CHECK_EQ(interp.error_col_end(), 13);
}

static void test_unclosed_brace_points_at_opener() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load("int main() {\n    harvest();\n");
    CHECK(!err.empty());
    CHECK(interp.error_kind() == ErrorKind::Unclosed);
    CHECK_EQ(interp.error_line(), 1);
    // "int main() {" — '{' is column 12.
    CHECK_EQ(interp.error_col_start(), 12);
    CHECK_EQ(interp.error_col_end(), 13);
}

static void test_locked_while_span() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of("    while (true) { harvest(); }\n"));
    CHECK(!err.empty());
    CHECK(err.find("while") != std::string::npos);
    CHECK(err.find("5") != std::string::npos);
    CHECK(interp.error_kind() == ErrorKind::LockedSyntax);
    CHECK_EQ(interp.error_line(), 2);
    CHECK_EQ(interp.error_col_start(), 5);
    CHECK_EQ(interp.error_col_end(), 10);
}


static void test_failed_harvest_costs_full_swing() {
    World world;
    CHECK_EQ(world.action_ticks(), kBaseActionTicks);
    world.start_grass_growth();
    const ActionResult fail = world.try_harvest();
    CHECK(!fail.success);
    CHECK_EQ(fail.ticks, kBaseActionTicks);
    world.set_grass_mature();
    const ActionResult ok = world.try_harvest();
    CHECK(ok.success);
    CHECK_EQ(ok.ticks, fail.ticks);
    grant(world, UnlockId::Conditions);
    grant(world, UnlockId::Speed);
    CHECK_EQ(world.action_ticks(), kBaseActionTicks / 2);
    world.start_grass_growth();
    CHECK_EQ(world.try_harvest().ticks, world.action_ticks());
    CHECK_EQ(world.try_can_harvest().ticks, kFailOrQueryTicks);
    world.add_item(Item::Power, 10);
    CHECK(world.action_ticks() < kBaseActionTicks / 2);
    CHECK_EQ(world.try_harvest().ticks, world.action_ticks());
    world.advance(kGrassGrowTicks - 1);
    CHECK(!world.grass_mature());
    world.advance(1);
    CHECK(world.grass_mature());
    const auto fast = world.try_harvest();
    CHECK(fast.success);
    CHECK_EQ(fast.ticks, world.action_ticks());
    CHECK_EQ(world.try_can_harvest().ticks, kFailOrQueryTicks);
    CHECK(!world.try_can_harvest().success);
}

static void test_while_misses_after_speed() {
    World world;
    grant(world, UnlockId::Speed);
    CHECK(world.speed_unlocked());
    CHECK_EQ(world.action_ticks(), kBaseActionTicks / 2);
    world.wait_until_mature();
    Interpreter interp;
    interp.bind(&world);
    CHECK_EQ(interp.load(main_of("    while (true) { harvest(); }\n")), std::string());
    interp.start();
    interp.advance(30 * kTicksPerSecond);
    CHECK(interp.is_running());
    int success = 0;
    int fail = 0;
    for (const auto& ev : interp.events()) {
        if (ev.kind == ActionKind::Harvest) {
            CHECK_EQ(ev.duration_ticks, world.action_ticks());
            if (ev.success) {
                ++success;
            } else {
                ++fail;
            }
        }
    }
    CHECK_EQ(success, 1);
    CHECK(fail >= 50);
    CHECK_EQ(world.hay(), 1);
    CHECK(!world.grass_mature());
}

static void test_fast_grass_reset_and_query_timing() {
    World world;
    grant(world, UnlockId::Speed);
    grant(world, UnlockId::Conditions);
    const auto good = world.harvest();
    CHECK(good.success);
    CHECK_EQ(good.ticks, 200);
    CHECK_EQ(world.grass_grow_ticks_left(), 200);
    world.advance(150);
    const auto tick = world.tick();
    const auto miss = world.try_harvest();
    CHECK(!miss.success);
    CHECK_EQ(miss.ticks, 200);
    CHECK_EQ(world.tick(), tick);  // reset happens before the swing advances
    CHECK_EQ(world.grass_grow_ticks_left(), 400);
    world.advance(miss.ticks);
    CHECK_EQ(world.grass_grow_ticks_left(), 200);  // not reset again at completion
    const auto query = world.try_can_harvest();
    CHECK(!query.success);
    CHECK_EQ(query.ticks, 1);
    CHECK_EQ(world.grass_grow_ticks_left(), 200);
    CHECK_EQ(world.try_get_entity_type().ticks, 1);
    CHECK_EQ(world.try_get_ground_type().ticks, 1);
    CHECK_EQ(world.try_get_world_size().ticks, 1);
    CHECK_EQ(world.grass_grow_ticks_left(), 200);
    world.advance(query.ticks);
    CHECK_EQ(world.grass_grow_ticks_left(), 199);
    world.advance(198);
    CHECK(!world.grass_mature());
    world.advance(1);
    CHECK(world.grass_mature());
    CHECK_EQ(world.hay(), 1);
    CHECK(world.harvest().success);
    CHECK_EQ(world.hay(), 2);
}

static void test_other_harvest_failures_keep_crop_state() {
    // Isolated fixtures: no full-playthrough shortcuts. Only young Grass
    // restarts growth; failed harvest of another crop must leave it intact.
    for (int mode = 0; mode < 3; ++mode) {
        World world;
        if (mode > 0) grant(world, UnlockId::Speed);
        if (mode > 1) world.add_item(Item::Power, 10);
        for (auto entity : {EntityType::None, EntityType::Bush, EntityType::Tree,
                            EntityType::Carrot, EntityType::Sunflower, EntityType::Pumpkin,
                            EntityType::Cactus, EntityType::Apple, EntityType::Hedge,
                            EntityType::DeadPumpkin}) {
            auto& tile = world.tile_at_mut(0, 0);
            tile.entity = entity;
            tile.ground = GroundType::Soil;
            tile.mature = false;
            tile.grow_ticks_left = 123;
            tile.grow_ticks_total = 800;
            const auto power = world.item(Item::Power);
            const auto miss = world.try_harvest();
            CHECK(!miss.success);
            CHECK_EQ(miss.ticks, world.action_ticks());
            CHECK_EQ(world.item(Item::Power), power);
            CHECK_EQ(world.hay(), 0);
            if (entity == EntityType::DeadPumpkin) {
                CHECK_EQ(tile.entity, EntityType::None);
                CHECK_EQ(tile.grow_ticks_left, 0);
            } else {
                CHECK_EQ(tile.entity, entity);
                CHECK_EQ(tile.grow_ticks_left, 123);
                CHECK_EQ(tile.grow_ticks_total, 800);
            }
        }
    }
    World field;
    grant(field, UnlockId::Movement);
    field.start_grass_growth();
    field.advance(100);
    const Tile neighbor = field.tile_at(1, 0);
    field.try_harvest();
    CHECK_EQ(field.tile_at(1, 0).grow_ticks_left, neighbor.grow_ticks_left);
    CHECK_EQ(field.tile_at(1, 0).mature, neighbor.mature);
}

static void test_step_runs_one_action() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    CHECK_EQ(interp.load(main_of("    harvest();\n    harvest();\n")), std::string());
    interp.start();
    interp.step_advance(kBaseActionTicks + 50);
    CHECK(interp.is_paused());
    CHECK(!interp.is_running());
    CHECK_EQ(world.hay(), 1);
    CHECK_EQ(interp.events().size(), 1u);
    const int64_t tick = world.tick();
    interp.step_advance(0);
    CHECK_EQ(world.tick(), tick);
    interp.step_advance(kBaseActionTicks + 50);
    CHECK(interp.is_finished() || interp.is_paused());
    CHECK_EQ(world.hay(), 2);
}

static void test_harvest_feedback_matches_start_result() {
    World world;
    grant(world, UnlockId::Speed);
    Interpreter interp;
    interp.bind(&world);
    CHECK_EQ(interp.load(main_of("    harvest();\n    harvest();\n")), std::string());
    interp.start();
    interp.advance(1);
    CHECK(interp.take_harvest_pulse());
    CHECK(!interp.take_harvest_miss_pulse());
    CHECK(!interp.take_harvest_pulse());
    interp.advance(world.action_ticks());
    CHECK(interp.take_harvest_miss_pulse());
    CHECK(!interp.take_harvest_pulse());
    const auto hay = world.hay();
    interp.advance(world.action_ticks());
    CHECK(!world.grass_mature());
    CHECK(!interp.take_harvest_pulse());
    // main has ended: idle growth, rather than interpreter execution, matures it.
    world.advance(kGrassGrowTicks);
    CHECK(world.grass_mature());
    CHECK_EQ(world.hay(), hay);
    CHECK(!interp.take_harvest_pulse());  // growth during the miss is not a harvest
    CHECK(!interp.take_harvest_miss_pulse());
}

static void test_outside_main_span() {
    World world;
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load("harvest();\n");
    CHECK(!err.empty());
    CHECK(err.find("main") != std::string::npos);
    CHECK(interp.error_kind() == ErrorKind::OutsideMain);
    CHECK_EQ(interp.error_line(), 1);
    CHECK_EQ(interp.error_col_start(), 1);
    CHECK_EQ(interp.error_col_end(), 8);
}

#include "test_playthrough.inc"
#include "test_state.inc"

int main() {
    test_state_and_wrap();
    test_initial_world();
    test_harvest_ripe_gives_hay();
    test_unripe_grass_restarts_growth();
    test_empty_harvest();
    test_can_harvest_costs_one_tick();
    test_five_hay_unlocks_loops();
    test_while_rejected_before_unlock();
    test_harvest_events_and_line_numbers();
    test_second_harvest_ripe_at_base_speed();
    test_highlight_stays_during_harvest();
    test_while_after_unlock();
    test_if_can_harvest();
    test_if_skips_unripe();
    test_missing_semicolon_error_in_chinese();
    test_stop_halts_infinite_loop();
    test_exact_budget_finishes();
    test_standard_cpp_main();
    test_return_stops_program();
    test_statements_must_be_inside_main();
    test_hay_earned_tracks_lifetime();
    test_move_rejected_before_unlock();
    test_expand_at_move_unlock_hay();
    test_movement_and_torus();
    test_independent_tile_growth();
    test_move_in_program_and_progress();
    test_harvest_progress_fill();
    test_if_rejected_before_unlock();
    test_speed_then_if_unlock_costs();
    test_failed_harvest_costs_full_swing();
    test_while_misses_after_speed();
    test_fast_grass_reset_and_query_timing();
    test_other_harvest_failures_keep_crop_state();
    test_step_runs_one_action();
    test_harvest_feedback_matches_start_result();
    test_cannot_unlock_without_prerequisite();
    test_till_and_plant_flow();
    test_plant_requires_soil();
    test_compare_entity_and_ground();
    test_for_rejected_before_unlock();
    test_for_loop_moves_three_times();
    test_program_till_then_plant();
    test_edit_distance_and_suggest();
    test_missing_semicolon_span();
    test_typo_ident_span_and_suggestion();
    test_unclosed_paren_points_at_opener();
    test_unclosed_brace_points_at_opener();
    test_locked_while_span();
    test_outside_main_span();
    test_v2_world();
    test_v2_lang();
    test_playthrough_suite();

    std::cout << "Passed: " << g_passed << "  Failed: " << g_failed << "\n";
    if (g_failed != 0) {
        std::cerr << "TEST SUITE FAILED\n";
        return 1;
    }
    std::cout << "All tests passed.\n";
    return 0;
}
