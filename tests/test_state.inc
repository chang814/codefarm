// Save/restore from ordinary player actions, then reject damaged snapshots.
static void test_state_and_wrap() {
    World world;
    auto earn = [&](int64_t hay) {
        while (world.hay() < hay) {
            world.wait_until_mature();
            CHECK(world.harvest().success);
        }
    };
    for (auto id : {UnlockId::Loops, UnlockId::Speed, UnlockId::Conditions, UnlockId::Movement,
                    UnlockId::Till, UnlockId::Plant}) {
        earn(world.cost_of(id));
        CHECK(world.unlock(id));
    }
    CHECK(world.till().success);
    CHECK(world.plant(EntityType::Bush).success);
    world.advance(71);
    CHECK(world.move(Dir::East).success);
    const auto snapshot = world.save_state();
    World restored;
    CHECK(restored.load_state(snapshot));
    CHECK_EQ(restored.save_state(), snapshot);
    CHECK_EQ(restored.drone_x(), 1);
    CHECK(restored.drone_direction() == Dir::East);
    CHECK(restored.tile_at(0, 0).ground == GroundType::Soil);
    CHECK(restored.tile_at(0, 0).entity == EntityType::Bush);
    CHECK(restored.num_unlocked(UnlockId::Speed) == 1);
    for (auto bad : {std::string(), snapshot.substr(0, 50), snapshot.substr(0, snapshot.size() - 5),
                     std::string("CODEFARM_WORLD 900\n"), snapshot + "junk",
                     std::string("CODEFARM_WORLD 1\n999999999 0 -1 0 0\n")}) {
        CHECK(!restored.load_state(bad));
        CHECK_EQ(restored.save_state(), snapshot);
    }
    // A restored random engine and future plant growth follow the same path.
    CHECK_EQ(restored.random01(), world.random01());
    restored.advance(83); world.advance(83);
    CHECK_EQ(restored.save_state(), world.save_state());
    struct Step { Dir dir; int x; int y; int nx; int ny; };
    for (const auto& s : {Step{Dir::East, 2, 1, 0, 1}, {Dir::West, 0, 1, 2, 1},
                         {Dir::North, 1, 2, 1, 0}, {Dir::South, 1, 0, 1, 2},
                         {Dir::East, 1, 1, 2, 1}, {Dir::West, 1, 1, 0, 1},
                         {Dir::North, 1, 1, 1, 2}, {Dir::South, 1, 1, 1, 0}}) {
        world.set_pos(s.x, s.y);  // Location fixture, not progress or resource grant.
        const auto ticks = world.tick();
        CHECK(world.can_move(s.dir).success);
        CHECK_EQ(world.tick() - ticks, 1);
        const auto result = world.move(s.dir);
        CHECK(result.success);
        CHECK_EQ(result.ticks, world.move_ticks());
        CHECK_EQ(world.drone_x(), s.nx);
        CHECK_EQ(world.drone_y(), s.ny);
        CHECK(world.drone_direction() == s.dir);
        CHECK(&world.tile() == &world.tile_at(s.nx, s.ny));
        CHECK(world.till().success);
        CHECK_EQ(world.tile().ground, world.tile_at(s.nx, s.ny).ground);
        CHECK(restored.load_state(world.save_state()));
        CHECK_EQ(restored.save_state(), world.save_state());
    }
}
