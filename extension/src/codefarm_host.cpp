#include "codefarm_host.hpp"

#include <string>

#include <godot_cpp/core/class_db.hpp>

using namespace codefarm;

namespace {

std::string to_std(const godot::String& s) {
    const godot::CharString utf8 = s.utf8();
    return std::string(utf8.get_data(), static_cast<std::size_t>(utf8.length()));
}

godot::String to_godot(const std::string& s) {
    return godot::String::utf8(s.c_str(), static_cast<int>(s.size()));
}

}  // namespace

namespace godot {

CodefarmHost::CodefarmHost() { interpreter_.bind(&world_); }

void CodefarmHost::_bind_methods() {
    ClassDB::bind_method(D_METHOD("reset_world"), &CodefarmHost::reset_world);
    ClassDB::bind_method(D_METHOD("save_state"), &CodefarmHost::save_state);
    ClassDB::bind_method(D_METHOD("load_state", "state"), &CodefarmHost::load_state);
    ClassDB::bind_method(D_METHOD("drone_direction_at", "id"), &CodefarmHost::drone_direction_at);
    ClassDB::bind_method(D_METHOD("load_script", "source"), &CodefarmHost::load_script);
    ClassDB::bind_method(D_METHOD("start"), &CodefarmHost::start);
    ClassDB::bind_method(D_METHOD("stop"), &CodefarmHost::stop);
    ClassDB::bind_method(D_METHOD("pause"), &CodefarmHost::pause);
    ClassDB::bind_method(D_METHOD("resume"), &CodefarmHost::resume);
    ClassDB::bind_method(D_METHOD("advance_seconds", "delta"), &CodefarmHost::advance_seconds);
    ClassDB::bind_method(D_METHOD("step_seconds", "delta"), &CodefarmHost::step_seconds);
    ClassDB::bind_method(D_METHOD("get_hay"), &CodefarmHost::get_hay);
    ClassDB::bind_method(D_METHOD("get_hay_earned"), &CodefarmHost::get_hay_earned);
    ClassDB::bind_method(D_METHOD("get_tick"), &CodefarmHost::get_tick);
    ClassDB::bind_method(D_METHOD("loops_unlocked"), &CodefarmHost::loops_unlocked);
    ClassDB::bind_method(D_METHOD("speed_unlocked"), &CodefarmHost::speed_unlocked);
    ClassDB::bind_method(D_METHOD("conditions_unlocked"), &CodefarmHost::conditions_unlocked);
    ClassDB::bind_method(D_METHOD("movement_unlocked"), &CodefarmHost::movement_unlocked);
    ClassDB::bind_method(D_METHOD("for_unlocked"), &CodefarmHost::for_unlocked);
    ClassDB::bind_method(D_METHOD("till_unlocked"), &CodefarmHost::till_unlocked);
    ClassDB::bind_method(D_METHOD("plant_unlocked"), &CodefarmHost::plant_unlocked);
    ClassDB::bind_method(D_METHOD("unlock_cost", "id"), &CodefarmHost::unlock_cost);
    ClassDB::bind_method(D_METHOD("is_unlocked", "id"), &CodefarmHost::is_unlocked);
    ClassDB::bind_method(D_METHOD("prerequisite_met", "id"), &CodefarmHost::prerequisite_met);
    ClassDB::bind_method(D_METHOD("hay_shortfall", "id"), &CodefarmHost::hay_shortfall);
    ClassDB::bind_method(D_METHOD("can_unlock", "id"), &CodefarmHost::can_unlock);
    ClassDB::bind_method(D_METHOD("try_unlock", "id"), &CodefarmHost::try_unlock);
    ClassDB::bind_method(D_METHOD("get_wood"), &CodefarmHost::get_wood);
    ClassDB::bind_method(D_METHOD("is_running"), &CodefarmHost::is_running);
    ClassDB::bind_method(D_METHOD("is_paused"), &CodefarmHost::is_paused);
    ClassDB::bind_method(D_METHOD("is_finished"), &CodefarmHost::is_finished);
    ClassDB::bind_method(D_METHOD("action_ticks"), &CodefarmHost::action_ticks);
    ClassDB::bind_method(D_METHOD("action_speed"), &CodefarmHost::action_speed);
    ClassDB::bind_method(D_METHOD("last_error"), &CodefarmHost::last_error);
    ClassDB::bind_method(D_METHOD("error_line"), &CodefarmHost::error_line);
    ClassDB::bind_method(D_METHOD("error_col_start"), &CodefarmHost::error_col_start);
    ClassDB::bind_method(D_METHOD("error_col_end"), &CodefarmHost::error_col_end);
    ClassDB::bind_method(D_METHOD("error_suggestion"), &CodefarmHost::error_suggestion);
    ClassDB::bind_method(D_METHOD("error_kind"), &CodefarmHost::error_kind);
    ClassDB::bind_method(D_METHOD("get_current_line"), &CodefarmHost::get_current_line);
    ClassDB::bind_method(D_METHOD("current_action"), &CodefarmHost::current_action);
    ClassDB::bind_method(D_METHOD("current_action_progress"), &CodefarmHost::current_action_progress);
    ClassDB::bind_method(D_METHOD("last_action_success"), &CodefarmHost::last_action_success);
    ClassDB::bind_method(D_METHOD("grass_mature"), &CodefarmHost::grass_mature);
    ClassDB::bind_method(D_METHOD("grass_grow_ratio"), &CodefarmHost::grass_grow_ratio);
    ClassDB::bind_method(D_METHOD("tile_grow_ratio", "x", "y"), &CodefarmHost::tile_grow_ratio);
    ClassDB::bind_method(D_METHOD("get_world_size"), &CodefarmHost::get_world_size);
    ClassDB::bind_method(D_METHOD("get_drone_x"), &CodefarmHost::get_drone_x);
    ClassDB::bind_method(D_METHOD("get_drone_y"), &CodefarmHost::get_drone_y);
    ClassDB::bind_method(D_METHOD("drone_count"), &CodefarmHost::drone_count);
    ClassDB::bind_method(D_METHOD("drone_x_at", "id"), &CodefarmHost::drone_x_at);
    ClassDB::bind_method(D_METHOD("drone_y_at", "id"), &CodefarmHost::drone_y_at);
    ClassDB::bind_method(D_METHOD("drone_line", "id"), &CodefarmHost::drone_line);
    ClassDB::bind_method(D_METHOD("set_view_drone", "id"), &CodefarmHost::set_view_drone);
    ClassDB::bind_method(D_METHOD("view_drone"), &CodefarmHost::view_drone);
    ClassDB::bind_method(D_METHOD("tile_entity", "x", "y"), &CodefarmHost::tile_entity);
    ClassDB::bind_method(D_METHOD("tile_ground", "x", "y"), &CodefarmHost::tile_ground);
    ClassDB::bind_method(D_METHOD("last_harvested"), &CodefarmHost::last_harvested);
    ClassDB::bind_method(D_METHOD("take_harvest_pulse"), &CodefarmHost::take_harvest_pulse);
    ClassDB::bind_method(D_METHOD("take_harvest_miss_pulse"), &CodefarmHost::take_harvest_miss_pulse);
    ClassDB::bind_method(D_METHOD("take_flip_pulse"), &CodefarmHost::take_flip_pulse);
    ClassDB::bind_method(D_METHOD("get_item", "name"), &CodefarmHost::get_item);
    ClassDB::bind_method(D_METHOD("get_item_earned", "name"), &CodefarmHost::get_item_earned);
    ClassDB::bind_method(D_METHOD("num_unlocked", "id"), &CodefarmHost::num_unlocked);
    ClassDB::bind_method(D_METHOD("unlock_cost_map", "id"), &CodefarmHost::unlock_cost_map);
    ClassDB::bind_method(D_METHOD("tile_water", "x", "y"), &CodefarmHost::tile_water);
    ClassDB::bind_method(D_METHOD("tile_value", "x", "y"), &CodefarmHost::tile_value);
    ClassDB::bind_method(D_METHOD("tile_infected", "x", "y"), &CodefarmHost::tile_infected);
    ClassDB::bind_method(D_METHOD("tile_is_mature", "x", "y"), &CodefarmHost::tile_is_mature);
    ClassDB::bind_method(D_METHOD("get_hat"), &CodefarmHost::get_hat);
    ClassDB::bind_method(D_METHOD("maze_active"), &CodefarmHost::maze_active);
    ClassDB::bind_method(D_METHOD("debug_grant", "id"), &CodefarmHost::debug_grant);
    ClassDB::bind_method(D_METHOD("debug_add_item", "name", "n"), &CodefarmHost::debug_add_item);
    ClassDB::bind_method(D_METHOD("set_include", "name", "source"), &CodefarmHost::set_include);
    ClassDB::bind_method(D_METHOD("last_print"), &CodefarmHost::last_print);
    ClassDB::bind_method(D_METHOD("prints"), &CodefarmHost::prints);
}


void CodefarmHost::reset_world() {
    interpreter_.stop();
    interpreter_.clear();
    world_.reset();
    interpreter_.bind(&world_);
    tick_accum_ = 0.0;
}

String CodefarmHost::save_state() const { return to_godot(world_.save_state()); }

bool CodefarmHost::load_state(const String& state) {
    World next;
    if (!next.load_state(to_std(state))) return false;
    interpreter_.bind(nullptr);
    interpreter_.clear();
    world_ = std::move(next);
    interpreter_.bind(&world_);
    tick_accum_ = 0.0;
    return true;
}

int CodefarmHost::drone_direction_at(int id) const {
    return static_cast<int>(world_.drone_direction_of(id));
}

String CodefarmHost::load_script(const String& source) {
    const std::string err = interpreter_.load(to_std(source));
    return to_godot(err);
}

void CodefarmHost::start() {
    tick_accum_ = 0.0;
    interpreter_.start();
}

void CodefarmHost::stop() { interpreter_.stop(); }

void CodefarmHost::pause() { interpreter_.pause(); }

void CodefarmHost::resume() { interpreter_.resume(); }

void CodefarmHost::advance_seconds(double delta) {
    if (delta <= 0.0) {
        return;
    }
    tick_accum_ += delta * static_cast<double>(kTicksPerSecond);
    const auto ticks = static_cast<int64_t>(tick_accum_);
    if (ticks <= 0) {
        return;
    }
    tick_accum_ -= static_cast<double>(ticks);
    if (interpreter_.is_running()) {
        interpreter_.advance(ticks);
    } else {
        // Time still flows when the program has stopped or is paused,
        // so grass can keep growing between runs and between steps.
        world_.advance(ticks);
    }
}

void CodefarmHost::step_seconds(double delta) {
    if (delta <= 0.0) {
        return;
    }
    tick_accum_ += delta * static_cast<double>(kTicksPerSecond);
    const auto ticks = static_cast<int64_t>(tick_accum_);
    if (ticks <= 0) {
        return;
    }
    tick_accum_ -= static_cast<double>(ticks);
    if (interpreter_.is_running() || interpreter_.is_paused()) {
        interpreter_.step_advance(ticks);
        // If the step finished early, leftover ticks still grow the world.
        if (!interpreter_.is_running() && !interpreter_.is_finished() && interpreter_.error().empty()) {
            // paused after one action: do not spend leftover ticks on the next
            // statement. Grass may grow with leftover? Keep it simple: leftover
            // stays in tick_accum_ only if we didn't consume all, which we did.
        }
    } else {
        world_.advance(ticks);
    }
}

int64_t CodefarmHost::get_hay() const { return world_.hay(); }
int64_t CodefarmHost::get_hay_earned() const { return world_.hay_earned(); }
int64_t CodefarmHost::get_tick() const { return world_.tick(); }
bool CodefarmHost::loops_unlocked() const { return world_.loops_unlocked(); }
bool CodefarmHost::speed_unlocked() const { return world_.speed_unlocked(); }
bool CodefarmHost::conditions_unlocked() const { return world_.conditions_unlocked(); }
bool CodefarmHost::movement_unlocked() const { return world_.movement_unlocked(); }
bool CodefarmHost::for_unlocked() const { return world_.for_unlocked(); }
bool CodefarmHost::till_unlocked() const { return world_.till_unlocked(); }
bool CodefarmHost::plant_unlocked() const { return world_.plant_unlocked(); }

int CodefarmHost::unlock_cost(const String& id) const {
    UnlockId uid;
    if (!unlock_id_from_name(to_std(id), &uid)) {
        return 0;
    }
    return world_.cost_of(uid);
}

bool CodefarmHost::is_unlocked(const String& id) const {
    UnlockId uid;
    return unlock_id_from_name(to_std(id), &uid) && world_.is_unlocked(uid);
}

bool CodefarmHost::prerequisite_met(const String& id) const {
    UnlockId uid;
    return unlock_id_from_name(to_std(id), &uid) && world_.prerequisite_met(uid);
}

int CodefarmHost::hay_shortfall(const String& id) const {
    UnlockId uid;
    if (!unlock_id_from_name(to_std(id), &uid)) {
        return 0;
    }
    return world_.hay_shortfall(uid);
}

bool CodefarmHost::can_unlock(const String& id) const {
    UnlockId uid;
    return unlock_id_from_name(to_std(id), &uid) && world_.can_unlock(uid);
}

int CodefarmHost::try_unlock(const String& id) {
    UnlockId uid;
    if (!unlock_id_from_name(to_std(id), &uid)) {
        return static_cast<int>(UnlockResult::Invalid);
    }
    return static_cast<int>(world_.try_unlock(uid));
}

int64_t CodefarmHost::get_wood() const { return world_.wood(); }
bool CodefarmHost::is_running() const { return interpreter_.is_running(); }
bool CodefarmHost::is_paused() const { return interpreter_.is_paused(); }
bool CodefarmHost::is_finished() const { return interpreter_.is_finished(); }
int64_t CodefarmHost::action_ticks() const { return world_.action_ticks(); }
int CodefarmHost::action_speed() const { return world_.action_speed(); }

String CodefarmHost::last_error() const { return to_godot(interpreter_.error()); }
int64_t CodefarmHost::error_line() const { return interpreter_.error_line(); }
int64_t CodefarmHost::error_col_start() const { return interpreter_.error_col_start(); }
int64_t CodefarmHost::error_col_end() const { return interpreter_.error_col_end(); }
String CodefarmHost::error_suggestion() const { return to_godot(interpreter_.error_suggestion()); }
String CodefarmHost::error_kind() const { return to_godot(error_kind_name(interpreter_.error_kind())); }

int CodefarmHost::get_current_line() const { return interpreter_.current_line(); }

String CodefarmHost::current_action() const {
    const ExecEvent* ev = interpreter_.current_event();
    if (!ev) {
        return String();
    }
    return String(action_kind_name(ev->kind));
}

double CodefarmHost::current_action_progress() const {
    return interpreter_.current_action_progress();
}

bool CodefarmHost::last_action_success() const {
    const ExecEvent* ev = interpreter_.current_event();
    return ev && ev->success;
}

bool CodefarmHost::grass_mature() const { return world_.grass_mature(); }
double CodefarmHost::grass_grow_ratio() const { return world_.grass_grow_ratio(); }
double CodefarmHost::tile_grow_ratio(int x, int y) const { return world_.tile_grow_ratio(x, y); }
int CodefarmHost::get_world_size() const { return world_.world_size(); }
int CodefarmHost::get_drone_x() const { return world_.drone_x(); }
int CodefarmHost::get_drone_y() const { return world_.drone_y(); }
int CodefarmHost::drone_count() const { return world_.drone_count(); }
int CodefarmHost::drone_x_at(int id) const { return world_.drone_x_of(id); }
int CodefarmHost::drone_y_at(int id) const { return world_.drone_y_of(id); }
int CodefarmHost::drone_line(int id) const { return interpreter_.drone_line(id); }
void CodefarmHost::set_view_drone(int id) { interpreter_.set_view_drone(id); }
int CodefarmHost::view_drone() const { return interpreter_.view_drone(); }

String CodefarmHost::tile_entity(int x, int y) const {
    if (!world_.in_bounds(x, y)) {
        return String();
    }
    return String(entity_type_name(world_.tile_at(x, y).entity));
}

String CodefarmHost::tile_ground(int x, int y) const {
    if (!world_.in_bounds(x, y)) {
        return String();
    }
    return String(ground_type_name(world_.tile_at(x, y).ground));
}

String CodefarmHost::last_harvested() const { return to_godot(world_.last_harvested()); }

bool CodefarmHost::take_harvest_pulse() { return interpreter_.take_harvest_pulse(); }
bool CodefarmHost::take_harvest_miss_pulse() { return interpreter_.take_harvest_miss_pulse(); }
bool CodefarmHost::take_flip_pulse() { return interpreter_.take_flip_pulse(); }

int64_t CodefarmHost::get_item(const String& name) const {
    Item it;
    if (!item_from_name(to_std(name), &it)) return 0;
    return world_.item(it);
}
int64_t CodefarmHost::get_item_earned(const String& name) const {
    Item it;
    if (!item_from_name(to_std(name), &it)) return 0;
    return world_.earned(it);
}
int CodefarmHost::num_unlocked(const String& id) const {
    UnlockId uid;
    if (!unlock_id_from_name(to_std(id), &uid)) return 0;
    return world_.num_unlocked(uid);
}
Dictionary CodefarmHost::unlock_cost_map(const String& id) const {
    Dictionary d;
    UnlockId uid;
    if (!unlock_id_from_name(to_std(id), &uid)) return d;
    const Cost c = world_.cost_of_unlock(uid);
    d["hay"] = c.hay;
    d["wood"] = c.wood;
    d["carrot"] = c.carrot;
    d["pumpkin"] = c.pumpkin;
    d["cactus"] = c.cactus;
    d["gold"] = c.gold;
    d["bone"] = c.bone;
    d["weird"] = c.weird;
    return d;
}
double CodefarmHost::tile_water(int x, int y) const {
    return world_.in_bounds(x, y) ? world_.tile_at(x, y).water : 0.0;
}
int CodefarmHost::tile_value(int x, int y) const {
    return world_.in_bounds(x, y) ? world_.tile_at(x, y).value : 0;
}
bool CodefarmHost::tile_infected(int x, int y) const {
    return world_.in_bounds(x, y) && world_.tile_at(x, y).infected;
}
bool CodefarmHost::tile_is_mature(int x, int y) const { return world_.tile_mature(x, y); }
String CodefarmHost::get_hat() const { return String(hat_name(world_.hat())); }
bool CodefarmHost::maze_active() const { return world_.maze_active(); }
void CodefarmHost::debug_grant(const String& id) {
    UnlockId uid;
    if (unlock_id_from_name(to_std(id), &uid)) world_.grant_for_test(uid);
}
void CodefarmHost::debug_add_item(const String& name, int64_t n) {
    Item it;
    if (item_from_name(to_std(name), &it)) world_.add_item(it, n);
}
void CodefarmHost::set_include(const String& name, const String& source) {
    interpreter_.set_include(to_std(name), to_std(source));
}
String CodefarmHost::last_print() const { return to_godot(world_.last_print()); }
PackedStringArray CodefarmHost::prints() const {
    PackedStringArray arr;
    for (const auto& s : world_.prints()) arr.append(to_godot(s));
    return arr;
}

}  // namespace godot
