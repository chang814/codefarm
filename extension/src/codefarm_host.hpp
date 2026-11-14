#pragma once

#include "codefarm/interpreter.hpp"
#include "codefarm/world.hpp"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class CodefarmHost : public Node {
    GDCLASS(CodefarmHost, Node)

public:
    CodefarmHost();

    void reset_world();
    String save_state() const;
    bool load_state(const String& state);
    int drone_direction_at(int id) const;
    String load_script(const String& source);
    void start();
    void stop();
    void pause();
    void resume();
    void advance_seconds(double delta);
    void step_seconds(double delta);

    int64_t get_hay() const;
    int64_t get_hay_earned() const;
    int64_t get_wood() const;
    int64_t get_tick() const;
    bool loops_unlocked() const;
    bool speed_unlocked() const;
    bool conditions_unlocked() const;
    bool movement_unlocked() const;
    bool for_unlocked() const;
    bool till_unlocked() const;
    bool plant_unlocked() const;
    int unlock_cost(const String& id) const;
    bool is_unlocked(const String& id) const;
    bool prerequisite_met(const String& id) const;
    int hay_shortfall(const String& id) const;
    bool can_unlock(const String& id) const;
    int try_unlock(const String& id);
    bool is_running() const;
    bool is_paused() const;
    bool is_finished() const;
    int64_t action_ticks() const;
    int action_speed() const;
    String last_error() const;
    int64_t error_line() const;
    int64_t error_col_start() const;
    int64_t error_col_end() const;
    String error_suggestion() const;
    String error_kind() const;
    int get_current_line() const;
    String current_action() const;
    double current_action_progress() const;
    bool last_action_success() const;
    bool grass_mature() const;
    double grass_grow_ratio() const;
    double tile_grow_ratio(int x, int y) const;
    int get_world_size() const;
    int get_drone_x() const;
    int get_drone_y() const;
    int drone_count() const;
    int drone_x_at(int id) const;
    int drone_y_at(int id) const;
    int drone_line(int id) const;
    void set_view_drone(int id);
    int view_drone() const;
    String tile_entity(int x, int y) const;
    String tile_ground(int x, int y) const;
    String last_harvested() const;
    bool take_harvest_pulse();
    bool take_harvest_miss_pulse();
    bool take_flip_pulse();

    int64_t get_item(const String& name) const;
    int64_t get_item_earned(const String& name) const;
    int num_unlocked(const String& id) const;
    Dictionary unlock_cost_map(const String& id) const;
    double tile_water(int x, int y) const;
    int tile_value(int x, int y) const;
    bool tile_infected(int x, int y) const;
    bool tile_is_mature(int x, int y) const;
    String get_hat() const;
    bool maze_active() const;
    void debug_grant(const String& id);
    void debug_add_item(const String& name, int64_t n);
    void set_include(const String& name, const String& source);
    String last_print() const;
    PackedStringArray prints() const;

protected:
    static void _bind_methods();

private:
    codefarm::World world_;
    codefarm::Interpreter interpreter_;
    double tick_accum_ = 0.0;
};

}  // namespace godot
