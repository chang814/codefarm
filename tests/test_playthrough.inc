// Full playthrough + exemplar coverage. Included from test_sim.cpp.
#include "playthrough_route.hpp"

#include <set>

// Plays the whole main line from a fresh save with the in-game exemplars and
// only player actions (write, run, buy). Every pain/cure check must hold.
static void test_full_playthrough() {
    const playthrough::Route r = playthrough::play_full_route(false);
    for (const auto& c : r.checks) {
        if (!c.ok) std::cerr << "playthrough: " << c.name << "  " << c.detail << "\n";
        CHECK(c.ok);
    }
    CHECK(r.ok);
    std::set<std::string> bought;
    for (const auto& s : r.stages) bought.insert(s.bought);
    for (int i = 0; i < kUnlockCount; ++i) {
        const UnlockId id = static_cast<UnlockId>(i);
        if (id == UnlockId::Costs) continue;  // arrives with carrots
        if (!bought.count(unlock_id_name(id))) std::cerr << "playthrough never bought " << unlock_id_name(id) << "\n";
        CHECK(bought.count(unlock_id_name(id)) == 1);
    }
    // A normal run: tens of minutes of farm time, no stage that idles for long.
    CHECK(r.total_seconds > 1200 && r.total_seconds < 4 * 3600);
    double longest = 0;
    for (const auto& s : r.stages) longest = std::max(longest, s.seconds);
    CHECK(longest < 600);
}

// Every skill node (the GDScript tree and every UnlockId) has an exemplar
// that parses and runs once everything is unlocked.
static void test_every_node_has_exemplar() {
    std::set<std::string> ids = {"harvest"};
    for (int i = 0; i < kUnlockCount; ++i) ids.insert(unlock_id_name(static_cast<UnlockId>(i)));
    const std::string tree = playthrough::read_file(playthrough::source_dir() + "/game/scripts/skill_data.gd");
    CHECK(!tree.empty());
    for (std::size_t at = tree.find("_n(\""); at != std::string::npos; at = tree.find("_n(\"", at + 4)) {
        const std::size_t end = tree.find('"', at + 4);
        ids.insert(tree.substr(at + 4, end - at - 4));
    }
    CHECK(ids.size() >= 39);
    for (const auto& id : ids) {
        const std::string src = playthrough::exemplar(id);
        if (src.empty()) std::cerr << "missing exemplar " << id << "\n";
        CHECK(!src.empty());
        if (src.empty()) continue;
        World world;
        world.set_seed(7);
        for (int i = 0; i < kUnlockCount; ++i) world.grant_for_test(static_cast<UnlockId>(i));
        for (int it = 0; it <= static_cast<int>(Item::Bone); ++it) world.add_item(static_cast<Item>(it), 100000);
        Interpreter interp;
        interp.bind(&world);
        for (const auto& kv : playthrough::exemplar_includes(id)) interp.set_include(kv.first, kv.second);
        const std::string err = interp.load(src);
        if (!err.empty()) std::cerr << "exemplar " << id << ": " << err << "\n";
        CHECK(err.empty());
        if (!err.empty()) continue;
        interp.start();
        for (int k = 0; k < 80 && interp.is_running() && !interp.has_error(); ++k) interp.advance(kTicksPerSecond / 4);
        if (interp.has_error()) std::cerr << "exemplar " << id << " runtime: " << interp.error() << "\n";
        CHECK(!interp.has_error());
        CHECK(!interp.events().empty());
        // Exercise snapshots of every exemplar's actual world state (including
        // active mazes, dinosaurs, companions and multiple drones).
        World restored;
        CHECK(restored.load_state(world.save_state()));
        CHECK_EQ(restored.save_state(), world.save_state());
        // House style: 4-space indent, no tabs, standard C++ entry point.
        CHECK(src.find('\t') == std::string::npos);
        CHECK(src.find("#include <bits/stdc++.h>") != std::string::npos);
        CHECK(src.find("using namespace std;") != std::string::npos);
        CHECK(src.find("int main()") != std::string::npos);
    }
}

static void test_playthrough_suite() {
    test_every_node_has_exemplar();
    test_full_playthrough();
}
