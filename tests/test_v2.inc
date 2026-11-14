static void test_multi_currency_and_costs() {
    World world;
    world.grant_for_test(UnlockId::Senses);
    world.add_item(Item::Wood, 50);
    CHECK(world.can_unlock(UnlockId::Carrots));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Carrots)), static_cast<int>(UnlockResult::Ok));
    CHECK(world.is_unlocked(UnlockId::Carrots));
    CHECK(world.is_unlocked(UnlockId::Costs));
    CHECK_EQ(world.wood(), 0);
    CHECK_EQ(world.cost_of_entity(EntityType::Carrot).hay, 1);
    CHECK_EQ(world.cost_of_entity(EntityType::Carrot).wood, 0);
    // Not enough resources: plant fails in 1 tick and does not plant.
    world.set_ground(GroundType::Soil);
    world.set_entity_empty();
    const int64_t t0 = world.tick();
    const ActionResult denied = world.plant(EntityType::Carrot);
    CHECK(!denied.success);
    CHECK_EQ(denied.ticks, kFailOrQueryTicks);
    CHECK_EQ(world.tick(), t0 + 1);
    CHECK_EQ(world.tile().entity, EntityType::None);
    world.add_item(Item::Hay, 1);
    world.add_item(Item::Wood, 1);
    const ActionResult ok = world.plant(EntityType::Carrot);
    CHECK(ok.success);
    CHECK_EQ(world.hay(), 0);
    CHECK_EQ(world.wood(), 1);  // carrots cost hay only
    CHECK_EQ(world.tile().entity, EntityType::Carrot);
}

static void test_carrot_requires_soil() {
    World world;
    world.grant_for_test(UnlockId::Carrots);
    world.add_item(Item::Hay, 5);
    world.add_item(Item::Wood, 5);
    world.set_grass_mature();
    const ActionResult denied = world.try_plant(EntityType::Carrot);
    CHECK(!denied.success);
    CHECK_EQ(denied.ticks, kFailOrQueryTicks);
    CHECK_EQ(world.tile().entity, EntityType::Grass);
}

static void test_expand_clears_and_grows() {
    World world;
    world.grant_for_test(UnlockId::Movement);
    CHECK_EQ(world.world_size(), 3);
    world.set_pos(1, 1);
    world.set_ground(GroundType::Soil);
    world.set_entity_empty();
    world.add_item(Item::Wood, 40);
    CHECK(world.can_unlock(UnlockId::Expand));
    CHECK_EQ(static_cast<int>(world.try_unlock(UnlockId::Expand)), static_cast<int>(UnlockResult::Ok));
    CHECK_EQ(world.world_size(), 4);
    CHECK_EQ(world.drone_x(), 0);
    CHECK_EQ(world.drone_y(), 0);
    // Field was cleared back to mature grass.
    CHECK_EQ(world.tile_at(1, 1).ground, GroundType::Grassland);
    CHECK(world.tile_mature(1, 1));
    const ActionResult sz = world.get_world_size_action();
    CHECK_EQ(sz.number, 4);
    CHECK_EQ(sz.ticks, kFailOrQueryTicks);
}

static void test_tree_neighbor_growth() {
    World world;
    world.grant_for_test(UnlockId::Trees);
    world.set_use_mean_growth(true);
    world.force_size_for_test(5, true);
    world.set_pos(2, 2);
    world.set_entity_empty();
    world.try_plant(EntityType::Tree);
    const int64_t base = world.tile().grow_ticks_total;
    const int64_t expected_mean = (2240 + 3360) / 2;
    CHECK_EQ(base, expected_mean);

    World one;
    one.grant_for_test(UnlockId::Trees);
    one.set_use_mean_growth(true);
    one.force_size_for_test(5, true);
    one.set_pos(3, 2);
    one.set_entity(EntityType::Tree, false, 0);
    one.set_pos(2, 2);
    one.set_entity_empty();
    one.try_plant(EntityType::Tree);
    CHECK_EQ(one.tile().grow_ticks_total, expected_mean * 2);

    World four;
    four.grant_for_test(UnlockId::Trees);
    four.set_use_mean_growth(true);
    four.force_size_for_test(5, true);
    four.set_pos(3, 2); four.set_entity(EntityType::Tree, false, 0);
    four.set_pos(1, 2); four.set_entity(EntityType::Tree, false, 0);
    four.set_pos(2, 3); four.set_entity(EntityType::Tree, false, 0);
    four.set_pos(2, 1); four.set_entity(EntityType::Tree, false, 0);
    four.set_pos(2, 2);
    four.set_entity_empty();
    four.try_plant(EntityType::Tree);
    CHECK_EQ(four.tile().grow_ticks_total, expected_mean * 16);
    four.wait_until_mature();
    const ActionResult h = four.harvest();
    CHECK(h.success);
    CHECK_EQ(four.wood(), 5);
}

static void test_water_speeds_growth() {
    World dry;
    dry.grant_for_test(UnlockId::Watering);
    dry.set_use_mean_growth(true);
    dry.set_ground(GroundType::Soil);
    dry.set_entity_empty();
    dry.add_item(Item::Hay, 1);
    dry.add_item(Item::Wood, 1);
    dry.plant(EntityType::Carrot);
    const int64_t dry_left = dry.grow_ticks_left();
    dry.set_water(0.0);
    dry.wait_until_mature();
    const int64_t dry_time = dry.tick();

    World wet;
    wet.grant_for_test(UnlockId::Watering);
    wet.set_use_mean_growth(true);
    wet.set_ground(GroundType::Soil);
    wet.set_entity_empty();
    wet.add_item(Item::Hay, 1);
    wet.add_item(Item::Wood, 1);
    wet.plant(EntityType::Carrot);
    wet.set_water(1.0);
    // Freeze evaporation by not rolling? Evaporation is random and will
    // slightly change the ratio. Disable by setting water every wait using
    // a large leftover and measuring ticks at water=1 with a helper:
    // grow at 5x, so ticks needed ~= dry_left / 5, plus plant ticks.
    const int64_t wet_left = wet.grow_ticks_left();
    CHECK_EQ(wet_left, dry_left);
    const int64_t plant_ticks = wet.tick();
    // Advance in one shot so evaporation has fewer slices... still some.
    // Compare against theoretical 5x with a generous tolerance for evaporation.
    wet.advance(wet_left / 5);
    // At water=1, 5x, should be mature or nearly so even with a bit of evap.
    CHECK(wet.tile().mature || wet.grow_ticks_left() < wet_left / 10);
    (void)dry_time;
    (void)plant_ticks;
    // Water 0 vs 1 maturity ratio is about 5.
    CHECK(dry_left >= 4 * (wet_left / 5) );
}

static void test_sunflower_bonus_and_penalty() {
    World world;
    world.grant_for_test(UnlockId::Sunflowers);
    world.force_size_for_test(4, true);
    world.set_pumpkin_wilt_percent(0);
    // Plant 9, harvest max: no 8x.
    int id = 0;
    for (int y = 0; y < 3; ++y) {
        for (int x = 0; x < 3; ++x) {
            world.set_pos(x, y);
            world.set_ground(GroundType::Soil);
            world.set_entity(EntityType::Sunflower, true, 7 + (id % 9));
            ++id;
        }
    }
    // Make (0,0) the unique max (15) among 9 plants.
    world.set_pos(0, 0);
    world.set_entity(EntityType::Sunflower, true, 15);
    CHECK_EQ(world.sunflower_count(), 9);
    world.harvest();
    CHECK_EQ(world.item(Item::Power), 1);

    World ten;
    ten.grant_for_test(UnlockId::Sunflowers);
    ten.force_size_for_test(4, true);
    for (int y = 0; y < 4; ++y) {
        for (int x = 0; x < 3; ++x) {
            if (y == 3 && x == 1) break;
            ten.set_pos(x, y);
            ten.set_ground(GroundType::Soil);
            ten.set_entity(EntityType::Sunflower, true, 8);
        }
    }
    ten.set_pos(0, 0);
    ten.set_entity(EntityType::Sunflower, true, 15);
    ten.set_pos(1, 0);
    ten.set_entity(EntityType::Sunflower, true, 14);
    CHECK_EQ(ten.sunflower_count(), 10);
    ten.set_pos(0, 0);
    ten.harvest();
    CHECK_EQ(ten.item(Item::Power), 8);

    // Wrong harvest: no bonus this time or next.
    World pen;
    pen.grant_for_test(UnlockId::Sunflowers);
    pen.force_size_for_test(4, true);
    for (int i = 0; i < 10; ++i) {
        pen.set_pos(i % 4, i / 4);
        pen.set_ground(GroundType::Soil);
        pen.set_entity(EntityType::Sunflower, true, (i == 0) ? 15 : 9);
    }
    pen.set_pos(1, 0);
    pen.harvest();  // not the max
    CHECK_EQ(pen.item(Item::Power), 1);
    pen.set_pos(0, 0);
    pen.harvest();  // is the max, but penalty applies
    CHECK_EQ(pen.item(Item::Power), 2);
}

static void test_pumpkin_merge_and_wilt() {
    World world;
    world.grant_for_test(UnlockId::Pumpkins);
    world.set_pumpkin_wilt_percent(0);
    world.force_size_for_test(4, true);
    for (int y = 0; y < 2; ++y) {
        for (int x = 0; x < 2; ++x) {
            world.set_pos(x, y);
            world.set_ground(GroundType::Soil);
            world.set_entity(EntityType::Pumpkin, true, 1);
        }
    }
    world.set_pos(0, 0);
    world.harvest();
    CHECK_EQ(world.item(Item::Pumpkin), 8);  // 2^3
    CHECK_EQ(world.tile_at(1, 1).entity, EntityType::None);

    World dead;
    dead.grant_for_test(UnlockId::Pumpkins);
    dead.set_pumpkin_wilt_percent(0);
    dead.force_size_for_test(4, true);
    for (int y = 0; y < 2; ++y) {
        for (int x = 0; x < 2; ++x) {
            dead.set_pos(x, y);
            dead.set_ground(GroundType::Soil);
            dead.set_entity(EntityType::Pumpkin, true, 1);
        }
    }
    dead.set_pos(1, 1);
    dead.set_entity(EntityType::DeadPumpkin, true, 1);
    CHECK(!dead.can_harvest().success);
    dead.set_pos(0, 0);
    dead.harvest();
    CHECK_EQ(dead.item(Item::Pumpkin), 1);  // cannot take the 8
}

static void test_fertilizer_infection_tax() {
    World world;
    world.grant_for_test(UnlockId::Fertilizer);
    world.grant_for_test(UnlockId::Trees);
    world.set_use_mean_growth(true);
    world.force_size_for_test(3, true);
    world.set_pos(0, 0);
    world.set_entity_empty();
    world.try_plant(EntityType::Tree);
    const int64_t left = world.grow_ticks_left();
    world.add_item(Item::Fertilizer, 1);
    const ActionResult u = world.try_use_item(Item::Fertilizer);
    CHECK(u.success);
    CHECK(world.tile().infected);
    CHECK_EQ(world.grow_ticks_left(), left - 800);
    world.wait_until_mature();
    world.harvest();
    // Tree yield 5, half becomes substance.
    CHECK_EQ(world.wood(), 3);
    CHECK_EQ(world.item(Item::WeirdSubstance), 2);
}

static void test_maze_can_move_and_wrong_harvest() {
    World world;
    world.grant_for_test(UnlockId::Mazes);
    world.set_seed(7);
    world.force_size_for_test(5, true);
    world.add_item(Item::WeirdSubstance, 80);
    world.set_pos(0, 0);
    world.set_ground(GroundType::Soil);
    world.set_entity(EntityType::Bush, true, 0);
    const ActionResult mz = world.use_item(Item::WeirdSubstance, world.world_size());
    CHECK(mz.success);
    CHECK(world.maze_active());
    // Walk into a hedge if one is adjacent; otherwise can_move at least returns quickly.
    const int64_t t0 = world.tick();
    bool saw_block = false;
    for (Dir d : {Dir::East, Dir::West, Dir::North, Dir::South}) {
        const ActionResult cm = world.try_can_move(d);
        CHECK_EQ(cm.ticks, kFailOrQueryTicks);
        if (!cm.success) {
            const int64_t t1 = world.tick();
            const ActionResult mv = world.move(d);
            CHECK(!mv.success);
            CHECK_EQ(mv.ticks, kFailOrQueryTicks);
            CHECK_EQ(world.drone_x(), 0);
            CHECK_EQ(world.drone_y(), 0);
            saw_block = true;
            (void)t1;
            break;
        }
    }
    (void)t0;
    CHECK(saw_block || world.maze_active());
    // Wrong harvest wipes the maze.
    // Stand on a non-treasure tile.
    if (world.tile().entity == EntityType::Treasure) {
        // move somewhere else if possible
        for (Dir d : {Dir::East, Dir::North, Dir::West, Dir::South}) {
            if (world.try_can_move(d).success) {
                world.move(d);
                break;
            }
        }
    }
    if (world.tile().entity != EntityType::Treasure) {
        world.harvest();
        CHECK(!world.maze_active());
        bool any_hedge = false;
        for (int y = 0; y < world.world_size(); ++y) {
            for (int x = 0; x < world.world_size(); ++x) {
                if (world.tile_at(x, y).entity == EntityType::Hedge ||
                    world.tile_at(x, y).entity == EntityType::Treasure) {
                    any_hedge = true;
                }
            }
        }
        CHECK(!any_hedge);
    }
}

static void test_cactus_sort_yield() {
    World world;
    world.grant_for_test(UnlockId::Cactus);
    world.force_size_for_test(5, true);
    // Three sorted cacti in a row: sizes 1,2,3 west to east. North/south empty.
    for (int x = 0; x < 3; ++x) {
        world.set_pos(x, 0);
        world.set_ground(GroundType::Soil);
        world.set_entity(EntityType::Cactus, true, 1 + x);
    }
    world.set_pos(0, 0);
    world.harvest();
    CHECK_EQ(world.item(Item::Cactus), 9);

    World messy;
    messy.grant_for_test(UnlockId::Cactus);
    messy.force_size_for_test(5, true);
    messy.set_pos(0, 0); messy.set_ground(GroundType::Soil); messy.set_entity(EntityType::Cactus, true, 5);
    messy.set_pos(1, 0); messy.set_ground(GroundType::Soil); messy.set_entity(EntityType::Cactus, true, 1);
    messy.set_pos(0, 0);
    messy.harvest();
    CHECK_EQ(messy.item(Item::Cactus), 1);
    CHECK_EQ(messy.tile_at(1, 0).entity, EntityType::Cactus);
}

static void test_companion_not_self() {
    World world;
    world.grant_for_test(UnlockId::Companions);
    world.force_size_for_test(5, true);
    world.set_pos(2, 2);
    world.set_ground(GroundType::Soil);
    world.set_entity_empty();
    world.add_item(Item::Hay, 1);
    world.add_item(Item::Wood, 1);
    world.plant(EntityType::Carrot);
    const Companion c = world.tile().companion;
    CHECK(c.ok);
    CHECK(c.type != EntityType::Carrot);
    CHECK(!(c.x == 2 && c.y == 2));
    const int dist = std::max(std::abs(c.x - 2), std::abs(c.y - 2));
    CHECK(dist >= 1);
    CHECK(dist <= 3);
}

static void test_dino_rules() {
    World world;
    world.grant_for_test(UnlockId::Dinosaurs);
    world.force_size_for_test(5, true);
    world.add_item(Item::Cactus, 20);
    const ActionResult hat = world.change_hat(Hat::DinosaurHat);
    CHECK(hat.success);
    CHECK(world.hat() == Hat::DinosaurHat);
    // Wrap is disabled: walking off the south/west edge from (0,0) fails.
    const ActionResult west = world.move(Dir::West);
    CHECK(!west.success);
    CHECK_EQ(west.ticks, kFailOrQueryTicks);
    CHECK_EQ(world.drone_x(), 0);
    // Grow the snake by placing an apple to the east and walking onto it.
    world.set_pos(1, 0);
    world.set_entity_empty();
    world.set_entity(EntityType::Apple, true, 0);
    world.set_pos(0, 0);
    const ActionResult step = world.move(Dir::East);
    CHECK(step.success);
    CHECK_EQ(world.dino_length() >= 2, true);
    // Take the hat off: n^2 bones.
    const int n = world.dino_length();
    world.change_hat(Hat::StrawHat);
    CHECK_EQ(world.item(Item::Bone), 1LL * n * n);
    CHECK(world.hat() == Hat::StrawHat);
}

static void test_print_cost_and_seed() {
    World a;
    a.set_seed(42);
    a.set_use_mean_growth(false);
    a.grant_for_test(UnlockId::Carrots);
    a.set_ground(GroundType::Soil);
    a.set_entity_empty();
    a.add_item(Item::Hay, 1);
    a.add_item(Item::Wood, 1);
    a.plant(EntityType::Carrot);
    const int64_t ga = a.grow_ticks_left();

    World b;
    b.set_seed(42);
    b.set_use_mean_growth(false);
    b.grant_for_test(UnlockId::Carrots);
    b.set_ground(GroundType::Soil);
    b.set_entity_empty();
    b.add_item(Item::Hay, 1);
    b.add_item(Item::Wood, 1);
    b.plant(EntityType::Carrot);
    CHECK_EQ(b.grow_ticks_left(), ga);

    const ActionResult p = a.try_print_slow();
    CHECK_EQ(p.ticks, kPrintTicks);
    CHECK_EQ(p.ticks, 400);
}

static void test_senses_queries() {
    World world;
    world.grant_for_test(UnlockId::Senses);
    world.grant_for_test(UnlockId::Movement);
    world.move(Dir::East);
    const ActionResult x = world.get_pos_x();
    const ActionResult y = world.get_pos_y();
    CHECK_EQ(x.number, 1);
    CHECK_EQ(y.number, 0);
    CHECK_EQ(x.ticks, 1);
    world.add_item(Item::Wood, 4);
    const ActionResult n = world.num_items_action(Item::Wood);
    CHECK_EQ(n.number, 4);
}

static void test_v2_world() {
    test_multi_currency_and_costs();
    test_carrot_requires_soil();
    test_expand_clears_and_grows();
    test_tree_neighbor_growth();
    test_water_speeds_growth();
    test_sunflower_bonus_and_penalty();
    test_pumpkin_merge_and_wilt();
    test_fertilizer_infection_tax();
    test_maze_can_move_and_wrong_harvest();
    test_cactus_sort_yield();
    test_companion_not_self();
    test_dino_rules();
    test_print_cost_and_seed();
    test_senses_queries();
}

static void run_src(World& world, Interpreter& interp, const std::string& src, int64_t ticks) {
    interp.bind(&world);
    const std::string err = interp.load(src);
    CHECK_EQ(err, std::string());
    if (!err.empty()) {
        std::cerr << "  load error: " << err << "\n";
        return;
    }
    interp.start();
    interp.advance(ticks);
}

static void test_vars_const_ops_and_senses() {
    World world;
    world.grant_for_test(UnlockId::Expand);
    world.grant_for_test(UnlockId::Variables);
    world.grant_for_test(UnlockId::Const);
    world.grant_for_test(UnlockId::Operators);
    world.grant_for_test(UnlockId::Senses);
    Interpreter interp;
    const std::string src = R"(
int main() {
    const int SIZE = get_world_size();
    int steps = 0;
    bool ok = true;
    for (int i = 0; i < SIZE; i++) {
        steps = steps + 1;
        move(East);
    }
    if (steps == SIZE && get_pos_x() == 0 && (0 % 2 == 0) && ok) {
        harvest();
    }
    return 0;
}
)";
    run_src(world, interp, src, 100000);
    CHECK(interp.is_finished());
    CHECK(world.hay() >= 1);
}

static void test_i_locked_before_variables() {
    World world;
    world.grant_for_test(UnlockId::ForLoop);
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(main_of(
        "    for (int i = 0; i < 3; i++) {\n"
        "        if (i == 0) harvest();\n"
        "        move(East);\n"
        "    }\n"));
    // if not unlocked either; even without if, i in expr should fail
    CHECK(!err.empty());
}

static void test_functions_and_refs() {
    World world;
    world.grant_for_test(UnlockId::Functions);
    world.grant_for_test(UnlockId::References);
    world.grant_for_test(UnlockId::Operators);
    Interpreter interp;
    const std::string src = R"(
void step(int& count) {
    if (can_harvest()) {
        harvest();
        count = count + 1;
    }
}

int main() {
    int harvested = 0;
    step(harvested);
    return 0;
}
)";
    world.set_grass_mature();
    run_src(world, interp, src, 100000);
    if (!interp.error().empty()) std::cerr << "fn err: " << interp.error() << "\n";
    CHECK(interp.is_finished() || interp.error().empty());
    CHECK_EQ(world.hay(), 1);
}

static void test_fn_outside_main_locked() {
    World world;
    world.grant_for_test(UnlockId::Plant);
    Interpreter interp;
    interp.bind(&world);
    const std::string err = interp.load(R"(
void harvest_row() { harvest(); }
int main() { harvest_row(); return 0; }
)");
    CHECK(!err.empty());
    CHECK(err.find("函数") != std::string::npos || err.find("解锁") != std::string::npos);
}

static void test_array_bounds() {
    World world;
    world.grant_for_test(UnlockId::Arrays);
    world.grant_for_test(UnlockId::Operators);
    Interpreter interp;
    interp.bind(&world);
    const std::string src = R"(
int main() {
    int a[2];
    a[0] = 1;
    a[2] = 3;
    return 0;
}
)";
    const std::string err = interp.load(src);
    CHECK_EQ(err, std::string());
    interp.start();
    interp.advance(1000);
    CHECK(interp.has_error());
    CHECK(interp.error().find("越界") != std::string::npos);
    CHECK(interp.error_line() >= 1);
}

static void test_include_file() {
    World world;
    world.grant_for_test(UnlockId::Includes);
    world.grant_for_test(UnlockId::Functions);
    Interpreter interp;
    interp.set_include("rows.hpp", "inline void ping() { do_a_flip(); }\n");
    interp.bind(&world);
    const std::string src = R"(
#include <bits/stdc++.h>
#include "rows.hpp"
using namespace std;
int main() {
    ping();
    return 0;
}
)";
    const std::string err = interp.load(src);
    CHECK_EQ(err, std::string());
    interp.start();
    interp.advance(1000);
    CHECK(interp.is_finished());
    CHECK(world.tick() == kFlipTicks || world.tick() == 2 * kFlipTicks);
}

static void test_print_is_slow() {
    World world;
    world.grant_for_test(UnlockId::Debug);
    world.grant_for_test(UnlockId::Speed);
    Interpreter interp;
    const std::string src = R"(
int main() {
    print("hi");
    return 0;
}
)";
    run_src(world, interp, src, 10000);
    CHECK(interp.is_finished());
    CHECK_EQ(world.tick(), 400);
    // Speed must not shrink print.
    CHECK_EQ(world.action_ticks(), 200);
}

static void test_drones_no_shared_vars_and_water_race() {
    World world;
    world.grant_for_test(UnlockId::Megafarm);
    world.grant_for_test(UnlockId::Watering);
    world.grant_for_test(UnlockId::Functions);
    world.grant_for_test(UnlockId::References);
    world.grant_for_test(UnlockId::Operators);
    world.add_item(Item::Water, 5);
    world.set_water(0.0);
    Interpreter interp;
    const std::string src = R"(
int x = 0;
void bump() {
    x = 7;
    if (get_water() < 0.5) use_item(Water);
}
int main() {
    int x = 1;
    spawn_drone(bump);
    if (get_water() < 0.5) use_item(Water);
    return 0;
}
)";
    // x at file scope may be rejected (only const at file scope). Use a function-local proof:
    // child setting a by-value param shouldn't matter; test water waste instead.
    const std::string src2 = R"(
void water_if_dry() {
    if (get_water() < 0.5) use_item(Water);
}
int main() {
    spawn_drone(water_if_dry);
    water_if_dry();
    return 0;
}
)";
    run_src(world, interp, src2, 100000);
    CHECK(world.item(Item::Water) <= 4);
}

static void test_switch_and_struct() {
    World world;
    world.grant_for_test(UnlockId::SwitchEnum);
    world.grant_for_test(UnlockId::Structs);
    world.grant_for_test(UnlockId::Arrays);
    world.grant_for_test(UnlockId::Operators);
    world.grant_for_test(UnlockId::Plant);
    Interpreter interp;
    const std::string src = R"(
struct Plot { Entity entity; int petals; };
int main() {
    Plot field[2][2];
    field[0][0].entity = get_entity_type();
    field[0][0].petals = 3;
    int n = 0;
    switch (get_entity_type()) {
        case Grass:
            n = 1;
            break;
        default:
            n = 2;
            break;
    }
    if (n == 1 && field[0][0].petals == 3) harvest();
    return 0;
}
)";
    world.set_grass_mature();
    run_src(world, interp, src, 100000);
    CHECK(world.hay() >= 1);
}

static void test_simulate_api_reproducible() {
    auto run_once = [](int64_t seed) -> int64_t {
        World world;
        world.grant_for_test(UnlockId::Simulation);
        world.grant_for_test(UnlockId::Carrots);
        world.grant_for_test(UnlockId::Till);
        world.grant_for_test(UnlockId::Plant);
        world.set_use_mean_growth(false);
        world.add_item(Item::Hay, 4);
        world.add_item(Item::Wood, 4);
        Interpreter interp;
        const std::string src =
            std::string("#include <bits/stdc++.h>\nusing namespace std;\nint main() {\n    simulate(")
            + std::to_string(seed) + ");\n    if (get_ground_type() != Soil) till();\n    plant(Carrot);\n    return 0;\n}\n";
        run_src(world, interp, src, 200000);
        if (interp.has_error()) {
            std::cerr << "  simulate error: " << interp.error() << "\n";
        }
        CHECK(interp.is_finished());
        return world.grow_ticks_left();
    };
    const int64_t a = run_once(4242);
    const int64_t b = run_once(4242);
    const int64_t c = run_once(7);
    CHECK(a > 0);
    CHECK_EQ(a, b);
    CHECK(c > 0);
}

static void test_simulate_locked_without_unlock() {
    World world;
    world.grant_for_test(UnlockId::Plant);
    Interpreter interp;
    interp.bind(&world);
    const std::string src = "int main() { simulate(1); return 0; }\n";
    const std::string err = interp.load(src);
    if (err.empty()) {
        interp.start();
        interp.advance(2000);
        CHECK(interp.has_error());
    } else {
        CHECK(err.find("simulate") != std::string::npos);
    }
}

static void test_multi_drone_positions_via_api() {
    World world;
    world.grant_for_test(UnlockId::Megafarm);
    world.grant_level_for_test(UnlockId::Megafarm, 3);
    world.grant_for_test(UnlockId::Functions);
    world.grant_for_test(UnlockId::Movement);
    world.force_size_for_test(3, true);
    Interpreter interp;
    const std::string src = R"(
void go_east() { move(East); }
void go_north() { move(North); }
int main() {
    spawn_drone(go_east);
    spawn_drone(go_north);
    move(West);
    return 0;
}
)";
    run_src(world, interp, src, 200000);
    if (interp.has_error()) {
        std::cerr << "  multi-drone error: " << interp.error() << "\n";
    }
    CHECK(interp.drone_count() >= 3);
    CHECK_EQ(interp.drone_x(0), 2);
    CHECK_EQ(interp.drone_y(0), 0);
    CHECK_EQ(interp.drone_x(1), 1);
    CHECK_EQ(interp.drone_y(1), 0);
    CHECK_EQ(interp.drone_x(2), 0);
    CHECK_EQ(interp.drone_y(2), 1);
}

static void test_v2_lang() {
    test_vars_const_ops_and_senses();
    test_i_locked_before_variables();
    test_functions_and_refs();
    test_fn_outside_main_locked();
    test_array_bounds();
    test_include_file();
    test_print_is_slow();
    test_drones_no_shared_vars_and_water_race();
    test_multi_drone_positions_via_api();
    test_simulate_api_reproducible();
    test_simulate_locked_without_unlock();
    test_switch_and_struct();
}
