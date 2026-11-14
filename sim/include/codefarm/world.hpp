#pragma once

#include "codefarm/types.hpp"

#include <cstdint>
#include <deque>
#include <random>
#include <string>
#include <vector>

namespace codefarm {

struct Tile {
    GroundType ground = GroundType::Grassland;
    EntityType entity = EntityType::Grass;
    bool mature = true;
    int64_t grow_ticks_left = 0;
    int64_t grow_ticks_total = 0;
    double water = 0.0;
    bool infected = false;
    int value = 0;          // sunflower petals, cactus size, pumpkin id
    int pumpkin_id = 0;
    Companion companion{};
    bool watered_once = false;
};

// Grid farm simulation. The opening farm is a 1×1 grassland; Movement
// expands it to 3×3 with torus wrapping. Later Expand levels walk the
// side-length ladder and clear the field. Action methods apply their
// effect immediately and return the tick cost without advancing time;
// call advance() to spend those ticks so plants can grow in parallel.
class World {
public:
    World();

    void reset();
    std::string save_state() const;
    bool load_state(const std::string& state);  // transactional, validated snapshot
    Dir drone_direction() const { return drone_dir_; }
    Dir drone_direction_of(int id) const;
    void clear();  // drone back to (0,0), entities cleared, hat reset; inventory kept

    void advance(int64_t ticks);

    ActionResult try_harvest();
    ActionResult try_can_harvest();
    ActionResult try_flip();
    ActionResult try_move(Dir dir);
    ActionResult try_can_move(Dir dir);
    ActionResult try_till();
    ActionResult try_plant(EntityType entity);
    ActionResult try_get_entity_type();
    ActionResult try_get_ground_type();
    ActionResult try_get_pos_x();
    ActionResult try_get_pos_y();
    ActionResult try_get_world_size();
    ActionResult try_num_items(Item item);
    ActionResult try_num_unlocked(UnlockId id);
    ActionResult try_get_cost_entity(EntityType entity);
    ActionResult try_get_cost_unlock(UnlockId id);
    ActionResult try_use_item(Item item, int n = 1);
    ActionResult try_get_water();
    ActionResult try_measure();
    ActionResult try_measure_dir(Dir dir);
    ActionResult try_swap(Dir dir);
    ActionResult try_get_companion();
    ActionResult try_change_hat(Hat hat);
    ActionResult try_clear();
    ActionResult try_unlock_api(UnlockId id);
    ActionResult try_print_slow();
    ActionResult try_quick_print(const std::string& text);
    ActionResult try_get_time();
    ActionResult try_get_tick_count();
    ActionResult try_set_world_size(int size);
    ActionResult try_set_execution_speed(double speed);
    ActionResult try_random01();
    ActionResult try_simulate(uint64_t seed, double speed = 0.0);

    // Convenience for tests: apply the action and then advance by its cost.
    ActionResult harvest();
    ActionResult can_harvest();
    ActionResult do_a_flip();
    ActionResult move(Dir dir);
    ActionResult can_move(Dir dir);
    ActionResult till();
    ActionResult plant(EntityType entity);
    ActionResult get_entity_type();
    ActionResult get_ground_type();
    ActionResult get_pos_x();
    ActionResult get_pos_y();
    ActionResult get_world_size_action();
    ActionResult num_items_action(Item item);
    ActionResult use_item(Item item, int n = 1);
    ActionResult get_water_action();
    ActionResult measure();
    ActionResult measure_dir(Dir dir);
    ActionResult swap(Dir dir);
    ActionResult get_companion();
    ActionResult change_hat(Hat hat);

    int64_t tick() const { return tick_; }
    int64_t hay() const { return item(Item::Hay); }
    int64_t hay_earned() const { return earned(Item::Hay); }
    int64_t wood() const { return item(Item::Wood); }
    int64_t item(Item it) const { return items_[static_cast<int>(it)]; }
    int64_t earned(Item it) const { return earned_[static_cast<int>(it)]; }
    int64_t num_items(Item it) const { return item(it); }
    void add_item(Item it, int64_t n);
    void set_item(Item it, int64_t n);

    bool loops_unlocked() const { return num_unlocked(UnlockId::Loops) > 0; }
    bool speed_unlocked() const { return num_unlocked(UnlockId::Speed) > 0; }
    bool movement_unlocked() const { return num_unlocked(UnlockId::Movement) > 0; }
    bool conditions_unlocked() const { return num_unlocked(UnlockId::Conditions) > 0; }
    bool for_unlocked() const { return num_unlocked(UnlockId::ForLoop) > 0; }
    bool till_unlocked() const { return num_unlocked(UnlockId::Till) > 0; }
    bool plant_unlocked() const { return num_unlocked(UnlockId::Plant) > 0; }
    bool variables_unlocked() const { return num_unlocked(UnlockId::Variables) > 0; }
    bool const_unlocked() const { return num_unlocked(UnlockId::Const) > 0; }
    bool senses_unlocked() const { return num_unlocked(UnlockId::Senses) > 0; }
    bool operators_unlocked() const { return num_unlocked(UnlockId::Operators) > 0; }
    bool functions_unlocked() const { return num_unlocked(UnlockId::Functions) > 0; }
    bool references_unlocked() const { return num_unlocked(UnlockId::References) > 0; }
    bool includes_unlocked() const { return num_unlocked(UnlockId::Includes) > 0; }
    bool arrays_unlocked() const { return num_unlocked(UnlockId::Arrays) > 0; }
    bool structs_unlocked() const { return num_unlocked(UnlockId::Structs) > 0; }
    bool switch_unlocked() const { return num_unlocked(UnlockId::SwitchEnum) > 0; }
    bool utilities_unlocked() const { return num_unlocked(UnlockId::Utilities) > 0; }

    int world_size() const { return size_; }
    int drone_x() const { return drone_x_; }
    int drone_y() const { return drone_y_; }
    const std::string& last_harvested() const { return last_harvested_; }
    Hat hat() const { return hat_; }
    int dino_length() const { return static_cast<int>(dino_body_.size()); }
    bool maze_active() const { return maze_active_; }
    // Drop an active maze (hedges and treasure). Called when a new run starts.
    void end_maze() { if (maze_active_) clear_maze(); }
    int maze_reuse() const { return maze_reuse_; }
    const std::string& last_print() const { return last_print_; }
    const std::vector<std::string>& prints() const { return prints_; }
    void clear_prints() { prints_.clear(); last_print_.clear(); }

    const Tile& tile() const { return at(drone_x_, drone_y_); }
    const Tile& tile_at(int x, int y) const { return at(x, y); }
    Tile& tile_at_mut(int x, int y) { return at(x, y); }
    bool in_bounds(int x, int y) const;

    bool grass_mature() const;
    bool tile_mature(int x, int y) const;
    double grass_grow_ratio() const;
    double tile_grow_ratio(int x, int y) const;
    int64_t grass_grow_ticks_left() const;
    int64_t grow_ticks_left() const;
    void wait_until_mature();

    // Test helpers (act on the drone's current tile)
    void set_entity_empty();
    void start_grass_growth();
    void set_grass_mature();
    void set_ground(GroundType ground);
    void set_bush_growing();
    void set_bush_mature();
    void set_entity(EntityType entity, bool mature, int value = 0);
    void set_water(double w);
    void set_infected(bool v);
    void set_grow_ticks_left(int64_t ticks);
    void set_seed(uint64_t seed);
    void set_use_mean_growth(bool v) { use_mean_growth_ = v; }
    void set_pumpkin_wilt_percent(int p) { pumpkin_wilt_percent_ = p; }
    void set_pos(int x, int y);
    void unlock_all_for_test();
    void grant_for_test(UnlockId id);
    void grant_level_for_test(UnlockId id, int level);
    // Force field size without going through unlock (tests).
    void force_size_for_test(int size, bool clear_field = true);

    int cost_of(UnlockId id) const;
    Cost cost_of_unlock(UnlockId id) const;
    Cost cost_of_entity(EntityType entity) const;
    int action_speed() const;          // integer UI factor (1 or 2+ rounded)
    double action_speed_factor() const;
    int64_t action_ticks() const;
    int64_t move_ticks() const;  // half a swing
    int64_t flip_ticks() const { return kFlipTicks; }
    int64_t print_ticks() const { return kPrintTicks; }
    bool is_unlocked(UnlockId id) const { return num_unlocked(id) > 0; }
    int num_unlocked(UnlockId id) const;
    int expand_level() const { return expand_level_; }
    bool prerequisite_met(UnlockId id) const;
    int hay_shortfall(UnlockId id) const;
    Cost item_shortfall(UnlockId id) const;
    bool can_unlock(UnlockId id) const;
    UnlockResult try_unlock(UnlockId id);
    bool unlock(UnlockId id) { return try_unlock(id) == UnlockResult::Ok; }

    int64_t entity_yield(EntityType entity) const;
    int neighbor_tree_count(int x, int y) const;
    int sunflower_count() const;
    int max_sunflower_petals() const;
    bool sunflower_penalty() const { return sunflower_penalty_; }
    int next_pumpkin_id() const { return next_pumpkin_id_; }

    // Drone / concurrency helpers used by the interpreter.
    int max_drones() const;
    void set_active_drone(int id);
    int active_drone() const { return active_drone_; }
    void reset_drones();
    void flush_active_drone();
    int register_drone();  // copy current position, return new id
    int drone_count() const { return static_cast<int>(drone_locs_.size()); }
    int drone_x_of(int id) const;
    int drone_y_of(int id) const;
    // Same-tick same-tile water waste: two use_item(Water) starting on the
    // same tick both consume a can. World records the last water-use tick
    // per tile so the interpreter can document the rule; both calls still
    // succeed if each drone already decided to water.
    int64_t last_water_use_tick(int x, int y) const;

    uint64_t seed() const { return seed_; }
    std::mt19937_64& rng() { return rng_; }
    int random_int(int lo, int hi);
    double random01();

    // Program-end hook: restore set_world_size temporary shrink.
    void restore_world_size_if_needed();

    // Same-tick race documentation: actions resolve in increasing drone id
    // order, effects apply immediately. If two drones both pass
    // `if (get_water() < 0.5)` on the same tile in the same tick, both
    // will call use_item(Water) and the second can is wasted.

private:
    void begin_growth(Tile& tile, EntityType entity);
    void begin_grass_growth(Tile& tile);
    void clear_entity(Tile& tile);
    void grow_tiles(int64_t ticks);
    void step_environment(int64_t ticks);
    void maybe_supply_items(int64_t ticks);
    void evaporate(int64_t ticks);
    void expand_to(int new_size, bool clear_field);
    void apply_harvest_yield(Tile& tile, int64_t amount, Item item, const char* name);
    int64_t roll_grow_ticks(EntityType entity, int x, int y);
    bool can_afford(const Cost& c) const;
    bool can_afford_alt(UnlockId id) const;
    void pay(const Cost& c);
    Cost plant_cost(EntityType entity) const;
    bool plant_allowed(const Tile& tile, EntityType entity) const;
    void assign_companion(Tile& tile, EntityType planted, int x, int y);
    int pumpkin_square_size(int x, int y) const;
    void clear_pumpkin_square(int x, int y, int n);
    void clear_maze();
    bool generate_maze();
    int substance_needed() const;
    bool destination(int x, int y, Dir dir, int* nx, int* ny, bool* blocked) const;
    bool wrap_allowed() const;
    void dino_after_move();
    bool dino_blocked(int nx, int ny) const;
    void harvest_dino();
    bool spawn_apple();
    static Tile make_mature_grass();
    Tile& at(int x, int y);
    const Tile& at(int x, int y) const;
    void grant_prereqs_for_test(UnlockId id);
    void on_success_action_energy();

    int size_ = 1;
    int expand_level_ = 0;
    int saved_expand_level_ = -1;
    int drone_x_ = 0;
    int drone_y_ = 0;
    Dir drone_dir_ = Dir::South;
    std::vector<Tile> tiles_;
    int64_t items_[kItemCount]{};
    int64_t earned_[kItemCount]{};
    int levels_[kUnlockCount]{};
    int64_t tick_ = 0;
    int64_t supply_accum_ = 0;
    std::string last_harvested_;
    uint64_t seed_ = 1;
    std::mt19937_64 rng_{1};
    bool use_mean_growth_ = false;
    int pumpkin_wilt_percent_ = kPumpkinWiltPercent;
    int next_pumpkin_id_ = 1;
    bool sunflower_penalty_ = false;
    int energy_action_counter_ = 0;
    Hat hat_ = Hat::StrawHat;
    std::deque<std::pair<int, int>> dino_body_;
    int apples_eaten_ = 0;
    bool maze_active_ = false;
    int maze_reuse_ = 0;
    int treasure_x_ = -1;
    int treasure_y_ = -1;
    int active_drone_ = 0;
    struct DroneLoc { int x = 0; int y = 0; Dir dir = Dir::South; };
    std::vector<DroneLoc> drone_locs_{{}};
    int64_t last_water_tick_ = -1;
    int last_water_x_ = -1;
    int last_water_y_ = -1;
    std::string last_print_;
    std::vector<std::string> prints_;
    double exec_speed_override_ = 0.0;  // 0 = unused
};

}  // namespace codefarm
