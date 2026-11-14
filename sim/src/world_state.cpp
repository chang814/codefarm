#include "codefarm/world.hpp"

#include <cmath>
#include <iomanip>
#include <locale>
#include <sstream>

namespace codefarm {

std::string World::save_state() const {
    std::ostringstream out;
    out.imbue(std::locale::classic());
    out << std::setprecision(17) << "CODEFARM_WORLD 1\n";
    out << size_ << ' ' << expand_level_ << ' ' << saved_expand_level_ << ' '
        << tick_ << ' ' << supply_accum_ << '\n';
    for (auto n : items_) out << n << ' ';
    out << '\n';
    for (auto n : earned_) out << n << ' ';
    out << '\n';
    for (auto n : levels_) out << n << ' ';
    out << '\n' << seed_ << ' ' << rng_ << '\n';
    out << use_mean_growth_ << ' ' << pumpkin_wilt_percent_ << ' ' << next_pumpkin_id_
        << ' ' << sunflower_penalty_ << ' ' << energy_action_counter_ << ' '
        << static_cast<int>(hat_) << ' ' << apples_eaten_ << ' ' << maze_active_ << ' '
        << maze_reuse_ << ' ' << treasure_x_ << ' ' << treasure_y_ << ' '
        << exec_speed_override_ << ' ' << last_water_tick_ << ' ' << last_water_x_
        << ' ' << last_water_y_ << '\n';
    out << drone_count() << ' ' << active_drone_ << '\n';
    for (int id = 0; id < drone_count(); ++id)
        out << drone_x_of(id) << ' ' << drone_y_of(id) << ' '
            << static_cast<int>(drone_direction_of(id)) << '\n';
    out << dino_body_.size() << '\n';
    for (auto [x, y] : dino_body_) out << x << ' ' << y << '\n';
    for (const auto& t : tiles_) {
        out << static_cast<int>(t.ground) << ' ' << static_cast<int>(t.entity) << ' '
            << t.mature << ' ' << t.grow_ticks_left << ' ' << t.grow_ticks_total << ' '
            << t.water << ' ' << t.infected << ' ' << t.value << ' ' << t.pumpkin_id
            << ' ' << t.companion.ok << ' ' << static_cast<int>(t.companion.type) << ' '
            << t.companion.x << ' ' << t.companion.y << ' ' << t.watered_once << '\n';
    }
    out << std::quoted(last_harvested_) << ' ' << std::quoted(last_print_) << '\n';
    out << prints_.size() << '\n';
    for (const auto& line : prints_) out << std::quoted(line) << '\n';
    out << "END\n";
    return out.str();
}

bool World::load_state(const std::string& state) {
    if (state.size() > 4 * 1024 * 1024) return false;
    std::istringstream in(state);
    in.imbue(std::locale::classic());
    std::string magic;
    int version = 0;
    in >> magic >> version;
    if (magic != "CODEFARM_WORLD" || version != 1) return false;
    World w;
    in >> w.size_ >> w.expand_level_ >> w.saved_expand_level_ >> w.tick_ >> w.supply_accum_;
    constexpr int64_t limit = INT64_MAX / 16;
    if (!in || w.size_ < 1 || w.size_ > kMaxWorldSizePlayable ||
        w.expand_level_ < 0 || w.expand_level_ > kMaxExpandLevel ||
        w.saved_expand_level_ < -1 || w.saved_expand_level_ > kMaxExpandLevel ||
        w.tick_ < 0 || w.tick_ > limit || w.supply_accum_ < 0 ||
        w.supply_accum_ >= kWaterIntervalTicks) return false;
    for (auto& n : w.items_) { in >> n; if (n < 0 || n > limit) return false; }
    for (auto& n : w.earned_) { in >> n; if (n < 0 || n > limit) return false; }
    for (int i = 0; i < kUnlockCount; ++i) {
        in >> w.levels_[i];
        if (w.levels_[i] < 0 || w.levels_[i] > unlock_max_level(static_cast<UnlockId>(i))) return false;
    }
    in >> w.seed_ >> w.rng_;
    int hat = 0;
    in >> w.use_mean_growth_ >> w.pumpkin_wilt_percent_ >> w.next_pumpkin_id_
       >> w.sunflower_penalty_ >> w.energy_action_counter_ >> hat >> w.apples_eaten_
       >> w.maze_active_ >> w.maze_reuse_ >> w.treasure_x_ >> w.treasure_y_
       >> w.exec_speed_override_ >> w.last_water_tick_ >> w.last_water_x_ >> w.last_water_y_;
    if (!in || hat < 0 || hat > 2 || w.pumpkin_wilt_percent_ < 0 ||
        w.pumpkin_wilt_percent_ > 100 || w.next_pumpkin_id_ < 1 ||
        w.energy_action_counter_ < 0 || w.apples_eaten_ < 0 ||
        w.apples_eaten_ > w.size_ * w.size_ || w.maze_reuse_ < 0 ||
        w.maze_reuse_ > kMazeReuseLimit || !std::isfinite(w.exec_speed_override_) ||
        w.exec_speed_override_ < 0 || w.exec_speed_override_ > 1000) return false;
    w.hat_ = static_cast<Hat>(hat);
    int count = 0;
    in >> count >> w.active_drone_;
    if (!in || count < 1 || count > 64 || w.active_drone_ < 0 || w.active_drone_ >= count) return false;
    w.drone_locs_.resize(count);
    for (auto& loc : w.drone_locs_) {
        int dir = 0;
        in >> loc.x >> loc.y >> dir;
        if (!in || !w.in_bounds(loc.x, loc.y) || dir < 0 || dir > 3) return false;
        loc.dir = static_cast<Dir>(dir);
    }
    const auto& active = w.drone_locs_[w.active_drone_];
    w.drone_x_ = active.x; w.drone_y_ = active.y; w.drone_dir_ = active.dir;
    in >> count;
    if (!in || count < 0 || count > w.size_ * w.size_ + 1) return false;
    w.dino_body_.clear();
    for (int i = 0; i < count; ++i) {
        int x = 0, y = 0;
        in >> x >> y;
        if (!in || !w.in_bounds(x, y)) return false;
        w.dino_body_.emplace_back(x, y);
    }
    if (w.maze_active_ && !w.in_bounds(w.treasure_x_, w.treasure_y_)) return false;
    w.tiles_.resize(w.size_ * w.size_);
    for (auto& t : w.tiles_) {
        int ground = 0, entity = 0, companion = 0;
        in >> ground >> entity >> t.mature >> t.grow_ticks_left >> t.grow_ticks_total
           >> t.water >> t.infected >> t.value >> t.pumpkin_id >> t.companion.ok
           >> companion >> t.companion.x >> t.companion.y >> t.watered_once;
        if (!in || ground < 0 || ground > static_cast<int>(GroundType::Loam) ||
            entity < 0 || entity > static_cast<int>(EntityType::Bamboo) ||
            companion < 0 || companion > static_cast<int>(EntityType::Bamboo) ||
            t.grow_ticks_left < 0 || t.grow_ticks_left > limit ||
            t.grow_ticks_total < 0 || t.grow_ticks_total > limit ||
            t.grow_ticks_left > t.grow_ticks_total || !std::isfinite(t.water) ||
            t.water < 0 || t.water > 1 || t.pumpkin_id < 0 ||
            (t.companion.ok && !w.in_bounds(t.companion.x, t.companion.y))) return false;
        t.ground = static_cast<GroundType>(ground);
        t.entity = static_cast<EntityType>(entity);
        t.companion.type = static_cast<EntityType>(companion);
    }
    in >> std::quoted(w.last_harvested_) >> std::quoted(w.last_print_) >> count;
    if (!in || count < 0 || count > 10000) return false;
    w.prints_.resize(count);
    for (auto& line : w.prints_) in >> std::quoted(line);
    in >> magic;
    if (!in || magic != "END") return false;
    in >> std::ws;
    if (!in.eof()) return false;
    *this = std::move(w);
    return true;
}

}  // namespace codefarm
