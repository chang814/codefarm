#include "codefarm/world.hpp"

#include <algorithm>
#include <cmath>
#include <queue>
#include <utility>

namespace codefarm {

Tile World::make_mature_grass() {
    Tile tile;
    tile.ground = GroundType::Grassland;
    tile.entity = EntityType::Grass;
    tile.mature = true;
    tile.grow_ticks_left = 0;
    tile.grow_ticks_total = kGrassGrowTicks;
    return tile;
}

World::World() { reset(); }

void World::reset() {
    size_ = 1;
    expand_level_ = 0;
    saved_expand_level_ = -1;
    drone_x_ = 0;
    drone_y_ = 0;
    drone_dir_ = Dir::South;
    tiles_.assign(1, make_mature_grass());
    for (int i = 0; i < kItemCount; ++i) {
        items_[i] = 0;
        earned_[i] = 0;
    }
    for (int i = 0; i < kUnlockCount; ++i) {
        levels_[i] = 0;
    }
    tick_ = 0;
    supply_accum_ = 0;
    last_harvested_.clear();
    seed_ = 1;
    rng_.seed(1);
    use_mean_growth_ = false;
    pumpkin_wilt_percent_ = kPumpkinWiltPercent;
    next_pumpkin_id_ = 1;
    sunflower_penalty_ = false;
    energy_action_counter_ = 0;
    hat_ = Hat::StrawHat;
    dino_body_.clear();
    apples_eaten_ = 0;
    maze_active_ = false;
    maze_reuse_ = 0;
    treasure_x_ = -1;
    treasure_y_ = -1;
    active_drone_ = 0;
    last_water_tick_ = -1;
    last_water_x_ = -1;
    last_water_y_ = -1;
    last_print_.clear();
    prints_.clear();
    exec_speed_override_ = 0.0;
    reset_drones();
}

void World::clear() {
    drone_x_ = 0;
    drone_y_ = 0;
    reset_drones();
    hat_ = Hat::StrawHat;
    dino_body_.clear();
    apples_eaten_ = 0;
    maze_active_ = false;
    maze_reuse_ = 0;
    treasure_x_ = -1;
    treasure_y_ = -1;
    sunflower_penalty_ = false;
    for (Tile& tile : tiles_) {
        const GroundType g = tile.ground;
        const double water = tile.water;
        const bool watered = tile.watered_once;
        tile = {};
        tile.ground = g;
        tile.water = water;
        tile.watered_once = watered;
        if (g == GroundType::Grassland) {
            tile.entity = EntityType::Grass;
            tile.mature = true;
            tile.grow_ticks_total = kGrassGrowTicks;
        } else {
            tile.entity = EntityType::None;
        }
    }
}

void World::restore_world_size_if_needed() {
    if (saved_expand_level_ < 0) {
        return;
    }
    const int restore = saved_expand_level_;
    saved_expand_level_ = -1;
    expand_to(world_size_for_expand_level(restore), true);
    expand_level_ = restore;
}

bool World::in_bounds(int x, int y) const {
    return x >= 0 && y >= 0 && x < size_ && y < size_;
}

Tile& World::at(int x, int y) { return tiles_[y * size_ + x]; }

const Tile& World::at(int x, int y) const { return tiles_[y * size_ + x]; }

void World::expand_to(int new_size, bool clear_field) {
    if (new_size <= 0) {
        return;
    }
    std::vector<Tile> next(static_cast<std::size_t>(new_size * new_size), make_mature_grass());
    if (!clear_field && new_size >= size_) {
        for (int y = 0; y < size_; ++y) {
            for (int x = 0; x < size_; ++x) {
                next[y * new_size + x] = at(x, y);
            }
        }
    }
    tiles_ = std::move(next);
    size_ = new_size;
    if (drone_x_ >= size_) drone_x_ = 0;
    if (drone_y_ >= size_) drone_y_ = 0;
}

void World::force_size_for_test(int size, bool clear_field) {
    expand_to(size, clear_field);
    for (int i = 0; i < kWorldSizeLadderCount; ++i) {
        if (kWorldSizeLadder[i] == size) {
            expand_level_ = i;
            break;
        }
    }
}

void World::set_pos(int x, int y) {
    if (in_bounds(x, y)) {
        drone_x_ = x;
        drone_y_ = y;
        flush_active_drone();
    }
}

void World::set_seed(uint64_t seed) {
    seed_ = seed;
    rng_.seed(seed);
}

int World::random_int(int lo, int hi) {
    if (hi <= lo) {
        return lo;
    }
    std::uniform_int_distribution<int> dist(lo, hi);
    return dist(rng_);
}

double World::random01() {
    std::uniform_real_distribution<double> dist(0.0, 1.0);
    return dist(rng_);
}

void World::add_item(Item it, int64_t n) {
    if (n == 0) return;
    const int idx = static_cast<int>(it);
    items_[idx] += n;
    if (n > 0) {
        earned_[idx] += n;
    }
}

void World::set_item(Item it, int64_t n) { items_[static_cast<int>(it)] = n; }

void World::advance(int64_t ticks) {
    if (ticks <= 0) {
        return;
    }
    step_environment(ticks);
    tick_ += ticks;
}

void World::step_environment(int64_t ticks) {
    int64_t left = ticks;
    while (left > 0) {
        const int64_t slice = std::min(left, kEvaporateSliceTicks);
        grow_tiles(slice);
        evaporate(slice);
        maybe_supply_items(slice);
        left -= slice;
    }
}

void World::grow_tiles(int64_t ticks) {
    for (int y = 0; y < size_; ++y) {
        for (int x = 0; x < size_; ++x) {
            Tile& tile = at(x, y);
            if (tile.entity == EntityType::None && tile.ground == GroundType::Grassland && !maze_active_ &&
                hat_ != Hat::DinosaurHat) {
                // Bare grassland grows grass again (after a tree or a maze), as
                // it does after a harvest; otherwise those tiles stay empty for good.
                begin_grass_growth(tile);
                continue;
            }
            if (tile.entity == EntityType::None || tile.entity == EntityType::Hedge ||
                tile.entity == EntityType::Treasure || tile.entity == EntityType::DeadPumpkin ||
                tile.entity == EntityType::Apple || tile.mature) {
                continue;
            }
            const double mul = water_growth_mul(tile.water);
            const double reduce = static_cast<double>(ticks) * mul;
            if (static_cast<double>(tile.grow_ticks_left) <= reduce) {
                tile.grow_ticks_left = 0;
                if (tile.entity == EntityType::Pumpkin &&
                    random_int(1, 100) <= pumpkin_wilt_percent_) {
                    tile.entity = EntityType::DeadPumpkin;
                    tile.mature = true;
                    continue;
                }
                tile.mature = true;
            } else {
                tile.grow_ticks_left -= static_cast<int64_t>(reduce);
            }
        }
    }
}

void World::evaporate(int64_t ticks) {
    const double chance = (static_cast<double>(ticks) / static_cast<double>(kEvaporateSliceTicks)) *
                          (static_cast<double>(kEvaporateChancePercent) / 100.0);
    for (Tile& tile : tiles_) {
        if (tile.water <= 0.0) {
            continue;
        }
        if (random01() < chance) {
            tile.water *= (1.0 - kEvaporateFraction);
            if (tile.water < 1e-12) {
                tile.water = 0.0;
            }
        }
    }
}

void World::maybe_supply_items(int64_t ticks) {
    supply_accum_ += ticks;
    while (supply_accum_ >= kWaterIntervalTicks) {
        supply_accum_ -= kWaterIntervalTicks;
        if (levels_[static_cast<int>(UnlockId::Watering)] > 0) {
            const int lvl = levels_[static_cast<int>(UnlockId::Watering)];
            add_item(Item::Water, 1LL << (lvl - 1));
        }
        if (levels_[static_cast<int>(UnlockId::Fertilizer)] > 0) {
            const int lvl = levels_[static_cast<int>(UnlockId::Fertilizer)];
            add_item(Item::Fertilizer, 1LL << (lvl - 1));
        }
    }
}

void World::clear_entity(Tile& tile) {
    tile.entity = EntityType::None;
    tile.mature = false;
    tile.grow_ticks_left = 0;
    tile.grow_ticks_total = 0;
    tile.infected = false;
    tile.value = 0;
    tile.pumpkin_id = 0;
    tile.companion = {};
}

int64_t World::roll_grow_ticks(EntityType entity, int x, int y) {
    const GrowthRange r = growth_range(entity);
    int64_t ticks = 0;
    if (use_mean_growth_ || r.min_ticks == r.max_ticks) {
        ticks = use_mean_growth_ ? (r.min_ticks + r.max_ticks) / 2 : r.min_ticks;
    } else {
        ticks = random_int(static_cast<int>(r.min_ticks), static_cast<int>(r.max_ticks));
    }
    if (entity == EntityType::Tree) {
        const int n = neighbor_tree_count(x, y);
        for (int i = 0; i < n; ++i) {
            ticks *= 2;
        }
    }
    return ticks;
}

void World::begin_growth(Tile& tile, EntityType entity) {
    const std::ptrdiff_t idx = &tile - tiles_.data();
    const int x = static_cast<int>(idx % size_);
    const int y = static_cast<int>(idx / size_);
    tile.entity = entity;
    tile.mature = false;
    tile.infected = false;
    const int64_t ticks = roll_grow_ticks(entity, x, y);
    tile.grow_ticks_left = ticks;
    tile.grow_ticks_total = ticks;
    if (entity == EntityType::Sunflower) {
        tile.value = random_int(kSunflowerMinPetals, kSunflowerMaxPetals);
    } else if (entity == EntityType::Cactus) {
        tile.value = random_int(kCactusMinSize, kCactusMaxSize);
    } else if (entity == EntityType::Pumpkin) {
        tile.pumpkin_id = next_pumpkin_id_++;
        tile.value = tile.pumpkin_id;
    } else {
        tile.value = 0;
        tile.pumpkin_id = 0;
    }
}

void World::begin_grass_growth(Tile& tile) { begin_growth(tile, EntityType::Grass); }

int World::neighbor_tree_count(int x, int y) const {
    int n = 0;
    const Dir dirs[4] = {Dir::East, Dir::West, Dir::North, Dir::South};
    for (Dir d : dirs) {
        int dx = 0, dy = 0;
        dir_delta(d, &dx, &dy);
        const int nx = (x + dx + size_) % size_;
        const int ny = (y + dy + size_) % size_;
        if (at(nx, ny).entity == EntityType::Tree) {
            ++n;
        }
    }
    return n;
}

int World::num_unlocked(UnlockId id) const { return levels_[static_cast<int>(id)]; }

bool World::prerequisite_met(UnlockId id) const {
    auto owned = [&](UnlockId u) { return levels_[static_cast<int>(u)] > 0; };
    switch (id) {
        case UnlockId::Loops:
            return true;
        case UnlockId::Speed:
            return owned(UnlockId::Loops);
        case UnlockId::Conditions:
            return owned(UnlockId::Speed);
        case UnlockId::Movement:
            return owned(UnlockId::Conditions);
        case UnlockId::ForLoop:
        case UnlockId::Till:
            return owned(UnlockId::Movement);
        case UnlockId::Plant:
            return owned(UnlockId::Till);
        case UnlockId::Variables:
            return owned(UnlockId::ForLoop);
        case UnlockId::Const:
            return owned(UnlockId::Variables);
        case UnlockId::Senses:
            return owned(UnlockId::Plant);
        case UnlockId::Operators:
            return owned(UnlockId::Variables);
        case UnlockId::Expand:
            return owned(UnlockId::Movement);
        case UnlockId::Carrots:
            return owned(UnlockId::Plant) && owned(UnlockId::Till) && owned(UnlockId::Senses);
        case UnlockId::Costs:
            return owned(UnlockId::Carrots);
        case UnlockId::Watering:
            return owned(UnlockId::Carrots);
        case UnlockId::Trees:
            return owned(UnlockId::Carrots) && owned(UnlockId::Operators);
        case UnlockId::Functions:
            return owned(UnlockId::Variables) && owned(UnlockId::Carrots);
        case UnlockId::References:
            return owned(UnlockId::Functions);
        case UnlockId::HayYield:
            return owned(UnlockId::Plant);
        case UnlockId::Includes:
            return owned(UnlockId::Functions);
        case UnlockId::Sunflowers:
            return owned(UnlockId::Carrots) && owned(UnlockId::Functions);
        case UnlockId::Arrays:
            return owned(UnlockId::Functions) && owned(UnlockId::Variables);
        case UnlockId::Structs:
            return owned(UnlockId::Arrays);
        case UnlockId::SwitchEnum:
            return owned(UnlockId::Plant);
        case UnlockId::Pumpkins:
            return owned(UnlockId::Carrots) && owned(UnlockId::Arrays);
        case UnlockId::Utilities:
            return owned(UnlockId::Pumpkins) || owned(UnlockId::Sunflowers);
        case UnlockId::Fertilizer:
            return owned(UnlockId::Watering) &&
                   (owned(UnlockId::Trees) || owned(UnlockId::Carrots));
        case UnlockId::Mazes:
            return owned(UnlockId::Fertilizer) && owned(UnlockId::Functions) &&
                   owned(UnlockId::Variables);
        case UnlockId::Cactus:
            return owned(UnlockId::Pumpkins) && owned(UnlockId::Sunflowers) &&
                   owned(UnlockId::Arrays) && owned(UnlockId::Operators);
        case UnlockId::Companions:
            return owned(UnlockId::Pumpkins) && owned(UnlockId::Trees) &&
                   owned(UnlockId::Carrots) && owned(UnlockId::Plant);
        case UnlockId::Dinosaurs:
            return owned(UnlockId::Cactus);
        case UnlockId::Megafarm:
            return owned(UnlockId::Mazes) && owned(UnlockId::Functions) &&
                   owned(UnlockId::References);
        case UnlockId::Debug:
            return owned(UnlockId::Plant);
        case UnlockId::Timing:
            return owned(UnlockId::Pumpkins) || owned(UnlockId::Sunflowers);
        case UnlockId::Debug2:
            return owned(UnlockId::Mazes) || owned(UnlockId::Debug);
        case UnlockId::Simulation:
            return owned(UnlockId::Debug2) || owned(UnlockId::Mazes);
        case UnlockId::AutoUnlock:
            return owned(UnlockId::Costs) &&
                   (owned(UnlockId::Pumpkins) || owned(UnlockId::Carrots));
        case UnlockId::Hats:
            return owned(UnlockId::Loops);
        default:
            return false;
    }
}

Cost World::cost_of_unlock(UnlockId id) const {
    return unlock_cost_at(id, levels_[static_cast<int>(id)]);
}

int World::cost_of(UnlockId id) const { return cost_of_unlock(id).hay; }

Cost World::plant_cost(EntityType entity) const {
    Cost c;
    const int carrot_lv = std::max(1, levels_[static_cast<int>(UnlockId::Carrots)]);
    const int pumpkin_lv = std::max(1, levels_[static_cast<int>(UnlockId::Pumpkins)]);
    const int cactus_lv = std::max(1, levels_[static_cast<int>(UnlockId::Cactus)]);
    switch (entity) {
        case EntityType::Carrot:
            // Hay only: with a wood price every simple grass/bush/carrot
            // layout nets zero wood and the run stalls before Trees.
            c.hay = carrot_lv;
            break;
        case EntityType::Sunflower:
            c.carrot = 1;
            break;
        case EntityType::Pumpkin:
            c.carrot = pumpkin_lv;
            break;
        case EntityType::Cactus:
            c.pumpkin = cactus_lv;
            break;
        case EntityType::Apple:
            c.cactus = std::max(1, levels_[static_cast<int>(UnlockId::Dinosaurs)]);
            break;
        default:
            break;
    }
    return c;
}

Cost World::cost_of_entity(EntityType entity) const { return plant_cost(entity); }

int64_t World::entity_yield(EntityType entity) const {
    const int hay_lv = levels_[static_cast<int>(UnlockId::HayYield)];
    const int tree_lv = levels_[static_cast<int>(UnlockId::Trees)];
    const int carrot_lv = std::max(1, levels_[static_cast<int>(UnlockId::Carrots)]);
    switch (entity) {
        case EntityType::Grass:
            return 1 + hay_lv;
        case EntityType::Bush:
            return tree_lv > 0 ? tree_lv : 1;  // level 0 (pre-tree) still 1
        case EntityType::Tree:
            return 5 * std::max(1, tree_lv);
        case EntityType::Carrot:
            return carrot_lv;
        case EntityType::Sunflower:
            return 1;
        default:
            return 1;
    }
}

bool World::can_afford(const Cost& c) const {
    return item(Item::Hay) >= c.hay && item(Item::Wood) >= c.wood &&
           item(Item::Carrot) >= c.carrot && item(Item::Pumpkin) >= c.pumpkin &&
           item(Item::Cactus) >= c.cactus && item(Item::Gold) >= c.gold &&
           item(Item::Bone) >= c.bone && item(Item::WeirdSubstance) >= c.weird &&
           item(Item::Power) >= c.power;
}

void World::pay(const Cost& c) {
    items_[static_cast<int>(Item::Hay)] -= c.hay;
    items_[static_cast<int>(Item::Wood)] -= c.wood;
    items_[static_cast<int>(Item::Carrot)] -= c.carrot;
    items_[static_cast<int>(Item::Pumpkin)] -= c.pumpkin;
    items_[static_cast<int>(Item::Cactus)] -= c.cactus;
    items_[static_cast<int>(Item::Gold)] -= c.gold;
    items_[static_cast<int>(Item::Bone)] -= c.bone;
    items_[static_cast<int>(Item::WeirdSubstance)] -= c.weird;
    items_[static_cast<int>(Item::Power)] -= c.power;
}

bool World::can_afford_alt(UnlockId id) const {
    if (id == UnlockId::Variables) {
        return item(Item::Hay) >= 70 || item(Item::Wood) >= 25;
    }
    if (id == UnlockId::Const) {
        return item(Item::Wood) >= 15 || item(Item::Hay) >= 40;
    }
    if (id == UnlockId::Senses) {
        return item(Item::Wood) >= 40 || item(Item::Hay) >= 80;
    }
    const Cost primary = cost_of_unlock(id);
    if (primary.is_zero()) {
        return num_unlocked(id) < unlock_max_level(id);
    }
    return can_afford(primary);
}

int World::hay_shortfall(UnlockId id) const {
    if (num_unlocked(id) >= unlock_max_level(id) && id != UnlockId::Expand) {
        return 0;
    }
    if (id == UnlockId::Expand && expand_level_ >= kMaxExpandLevel) {
        return 0;
    }
    const Cost c = cost_of_unlock(id);
    if (item(Item::Hay) >= c.hay) {
        return 0;
    }
    return static_cast<int>(c.hay - item(Item::Hay));
}

Cost World::item_shortfall(UnlockId id) const {
    const Cost c = cost_of_unlock(id);
    Cost s;
    auto sub = [&](Item it, int need, int& out) {
        const int64_t have = item(it);
        if (have < need) out = static_cast<int>(need - have);
    };
    sub(Item::Hay, c.hay, s.hay);
    sub(Item::Wood, c.wood, s.wood);
    sub(Item::Carrot, c.carrot, s.carrot);
    sub(Item::Pumpkin, c.pumpkin, s.pumpkin);
    sub(Item::Cactus, c.cactus, s.cactus);
    sub(Item::Gold, c.gold, s.gold);
    sub(Item::Bone, c.bone, s.bone);
    sub(Item::WeirdSubstance, c.weird, s.weird);
    return s;
}

bool World::can_unlock(UnlockId id) const {
    if (id == UnlockId::Expand) {
        return expand_level_ < kMaxExpandLevel && prerequisite_met(id) && can_afford_alt(id);
    }
    if (num_unlocked(id) >= unlock_max_level(id)) {
        return false;
    }
    return prerequisite_met(id) && can_afford_alt(id);
}

UnlockResult World::try_unlock(UnlockId id) {
    if (static_cast<int>(id) < 0 || static_cast<int>(id) >= kUnlockCount) {
        return UnlockResult::Invalid;
    }
    const int max_lv = unlock_max_level(id);
    int& lvl = levels_[static_cast<int>(id)];
    if (id != UnlockId::Expand && lvl >= max_lv) {
        return UnlockResult::AlreadyUnlocked;
    }
    if (id == UnlockId::Expand && expand_level_ >= kMaxExpandLevel) {
        return UnlockResult::AlreadyUnlocked;
    }
    if (!prerequisite_met(id)) {
        return UnlockResult::LockedPrerequisite;
    }
    Cost paid;
    bool ok = false;
    if (id == UnlockId::Variables) {
        if (item(Item::Wood) >= 25) {
            paid.wood = 25;
            ok = true;
        } else if (item(Item::Hay) >= 70) {
            paid.hay = 70;
            ok = true;
        }
    } else if (id == UnlockId::Const) {
        if (item(Item::Wood) >= 15) {
            paid.wood = 15;
            ok = true;
        } else if (item(Item::Hay) >= 40) {
            paid.hay = 40;
            ok = true;
        }
    } else if (id == UnlockId::Senses) {
        if (item(Item::Wood) >= 40) {
            paid.wood = 40;
            ok = true;
        } else if (item(Item::Hay) >= 80) {
            paid.hay = 80;
            ok = true;
        }
    } else {
        paid = cost_of_unlock(id);
        ok = can_afford(paid);
    }
    if (!ok) {
        const Cost c = cost_of_unlock(id);
        if (c.wood || c.carrot || c.pumpkin || c.cactus || c.gold || c.bone || c.weird) {
            return UnlockResult::NotEnoughItems;
        }
        return UnlockResult::NotEnoughHay;
    }
    pay(paid);
    lvl += 1;
    if (id == UnlockId::Movement && lvl == 1) {
        expand_level_ = 1;
        expand_to(kExpandedWorldSize, false);
    }
    if (id == UnlockId::Expand) {
        expand_level_ = 1 + lvl;
        if (expand_level_ > kMaxExpandLevel) {
            expand_level_ = kMaxExpandLevel;
        }
        expand_to(world_size_for_expand_level(expand_level_), true);
        drone_x_ = 0;
        drone_y_ = 0;
    }
    if (id == UnlockId::Carrots && levels_[static_cast<int>(UnlockId::Costs)] == 0) {
        levels_[static_cast<int>(UnlockId::Costs)] = 1;
    }
    return UnlockResult::Ok;
}

double World::action_speed_factor() const {
    const int lvl = levels_[static_cast<int>(UnlockId::Speed)];
    double f = 1.0;
    if (lvl >= 1) {
        f = 2.0;
        for (int i = 1; i < lvl; ++i) {
            f *= 1.5;
        }
    }
    if (item(Item::Power) > 0) {
        f *= 2.0;
    }
    if (exec_speed_override_ > 0.0) {
        f *= exec_speed_override_;
    }
    return f;
}

int64_t World::move_ticks() const { return std::max<int64_t>(1, action_ticks() / 2); }

int World::action_speed() const {
    return std::max(1, static_cast<int>(std::lround(action_speed_factor())));
}

int64_t World::action_ticks() const {
    const double speed = std::max(0.0001, action_speed_factor());
    return std::max<int64_t>(1, static_cast<int64_t>(std::floor(kBaseActionTicks / speed)));
}

int World::max_drones() const {
    const int lvl = levels_[static_cast<int>(UnlockId::Megafarm)];
    if (lvl <= 0) return 1;
    return 1 + lvl;
}

int64_t World::last_water_use_tick(int x, int y) const {
    if (x == last_water_x_ && y == last_water_y_) {
        return last_water_tick_;
    }
    return -1;
}

void World::apply_harvest_yield(Tile& tile, int64_t amount, Item item, const char* name) {
    int64_t give = amount;
    if (levels_[static_cast<int>(UnlockId::Companions)] > 0 && tile.companion.ok &&
        in_bounds(tile.companion.x, tile.companion.y)) {
        const Tile& other = at(tile.companion.x, tile.companion.y);
        if (other.entity == tile.companion.type) {
            int mul = 5;
            for (int i = 1; i < levels_[static_cast<int>(UnlockId::Companions)]; ++i) {
                mul *= 2;
            }
            give *= mul;
        }
    }
    int64_t substance = 0;
    if (tile.infected && give > 0) {
        substance = give / 2;
        give -= substance;
    }
    if (give > 0) {
        add_item(item, give);
    }
    if (substance > 0) {
        add_item(Item::WeirdSubstance, substance);
    }
    last_harvested_ = name;
}

void World::assign_companion(Tile& tile, EntityType planted, int x, int y) {
    tile.companion = {};
    if (levels_[static_cast<int>(UnlockId::Companions)] <= 0) {
        return;
    }
    const EntityType pool[] = {EntityType::Grass, EntityType::Bush, EntityType::Tree,
                               EntityType::Carrot};
    bool ok_type = false;
    for (EntityType e : pool) {
        if (e == planted) ok_type = true;
    }
    if (!ok_type) {
        return;
    }
    EntityType pref = planted;
    int guard = 0;
    while (pref == planted && guard++ < 8) {
        pref = pool[random_int(0, 3)];
    }
    if (pref == planted) {
        pref = (planted == EntityType::Grass) ? EntityType::Bush : EntityType::Grass;
    }
    std::vector<std::pair<int, int>> spots;
    for (int dy = -kCompanionMaxDist; dy <= kCompanionMaxDist; ++dy) {
        for (int dx = -kCompanionMaxDist; dx <= kCompanionMaxDist; ++dx) {
            if (dx == 0 && dy == 0) continue;
            const int nx = (x + dx + size_) % size_;
            const int ny = (y + dy + size_) % size_;
            if (nx == x && ny == y) continue;
            spots.emplace_back(nx, ny);
        }
    }
    if (spots.empty()) {
        return;
    }
    const auto& pick = spots[static_cast<std::size_t>(random_int(0, static_cast<int>(spots.size()) - 1))];
    tile.companion.ok = true;
    tile.companion.type = pref;
    tile.companion.x = pick.first;
    tile.companion.y = pick.second;
}

int World::pumpkin_square_size(int x, int y) const {
    if (!in_bounds(x, y) || at(x, y).entity != EntityType::Pumpkin || !at(x, y).mature) {
        return 0;
    }
    int best = 1;
    for (int n = size_; n >= 2; --n) {
        for (int ox = 0; ox <= n - 1; ++ox) {
            for (int oy = 0; oy <= n - 1; ++oy) {
                const int x0 = x - ox;
                const int y0 = y - oy;
                if (x0 < 0 || y0 < 0 || x0 + n > size_ || y0 + n > size_) {
                    continue;
                }
                bool ok = true;
                for (int yy = 0; yy < n && ok; ++yy) {
                    for (int xx = 0; xx < n; ++xx) {
                        const Tile& t = at(x0 + xx, y0 + yy);
                        if (t.entity != EntityType::Pumpkin || !t.mature) {
                            ok = false;
                            break;
                        }
                    }
                }
                if (ok) {
                    return n;
                }
            }
        }
    }
    return best;
}

void World::clear_pumpkin_square(int x, int y, int n) {
    for (int ox = 0; ox <= n - 1; ++ox) {
        for (int oy = 0; oy <= n - 1; ++oy) {
            const int x0 = x - ox;
            const int y0 = y - oy;
            if (x0 < 0 || y0 < 0 || x0 + n > size_ || y0 + n > size_) {
                continue;
            }
            bool ok = true;
            for (int yy = 0; yy < n && ok; ++yy) {
                for (int xx = 0; xx < n; ++xx) {
                    const Tile& t = at(x0 + xx, y0 + yy);
                    if (t.entity != EntityType::Pumpkin || !t.mature) {
                        ok = false;
                        break;
                    }
                }
            }
            if (!ok) {
                continue;
            }
            for (int yy = 0; yy < n; ++yy) {
                for (int xx = 0; xx < n; ++xx) {
                    clear_entity(at(x0 + xx, y0 + yy));
                }
            }
            return;
        }
    }
    clear_entity(at(x, y));
}

int World::sunflower_count() const {
    int n = 0;
    for (const Tile& t : tiles_) {
        if (t.entity == EntityType::Sunflower) {
            ++n;
        }
    }
    return n;
}

int World::max_sunflower_petals() const {
    int m = -1;
    for (const Tile& t : tiles_) {
        if (t.entity == EntityType::Sunflower && t.value > m) {
            m = t.value;
        }
    }
    return m;
}

int World::substance_needed() const {
    const int lvl = std::max(1, levels_[static_cast<int>(UnlockId::Mazes)]);
    int need = size_;
    for (int i = 1; i < lvl; ++i) {
        need *= 2;
    }
    return need;
}

void World::clear_maze() {
    for (Tile& t : tiles_) {
        if (t.entity == EntityType::Hedge || t.entity == EntityType::Treasure) {
            clear_entity(t);
        }
    }
    maze_active_ = false;
    maze_reuse_ = 0;
    treasure_x_ = -1;
    treasure_y_ = -1;
}

bool World::generate_maze() {
    if (size_ < 2) {
        return false;
    }
    for (Tile& t : tiles_) {
        clear_entity(t);
        t.entity = EntityType::Hedge;
        t.mature = true;
    }
    const int rw = (size_ + 1) / 2;
    const int rh = (size_ + 1) / 2;
    auto room_x = [](int i) { return i * 2; };
    auto room_y = [](int j) { return j * 2; };
    std::vector<char> seen(static_cast<std::size_t>(rw * rh), 0);
    auto idx = [&](int i, int j) { return j * rw + i; };
    std::vector<std::pair<int, int>> stack;
    const int si = random_int(0, rw - 1);
    const int sj = random_int(0, rh - 1);
    stack.emplace_back(si, sj);
    seen[static_cast<std::size_t>(idx(si, sj))] = 1;
    at(room_x(si), room_y(sj)).entity = EntityType::None;
    at(room_x(si), room_y(sj)).mature = false;
    const int dxi[4] = {1, -1, 0, 0};
    const int dyi[4] = {0, 0, 1, -1};
    while (!stack.empty()) {
        const auto [i, j] = stack.back();
        int order[4] = {0, 1, 2, 3};
        for (int k = 3; k > 0; --k) {
            const int r = random_int(0, k);
            std::swap(order[k], order[r]);
        }
        bool carved = false;
        for (int k = 0; k < 4; ++k) {
            const int ni = i + dxi[order[k]];
            const int nj = j + dyi[order[k]];
            if (ni < 0 || nj < 0 || ni >= rw || nj >= rh) continue;
            if (seen[static_cast<std::size_t>(idx(ni, nj))]) continue;
            const int x0 = room_x(i);
            const int y0 = room_y(j);
            const int x1 = room_x(ni);
            const int y1 = room_y(nj);
            const int wx = (x0 + x1) / 2;
            const int wy = (y0 + y1) / 2;
            if (in_bounds(wx, wy)) clear_entity(at(wx, wy));
            if (in_bounds(x1, y1)) clear_entity(at(x1, y1));
            seen[static_cast<std::size_t>(idx(ni, nj))] = 1;
            stack.emplace_back(ni, nj);
            carved = true;
            break;
        }
        if (!carved) {
            stack.pop_back();
        }
    }
    std::vector<std::pair<int, int>> rooms;
    for (int j = 0; j < rh; ++j) {
        for (int i = 0; i < rw; ++i) {
            const int x = room_x(i);
            const int y = room_y(j);
            if (in_bounds(x, y) && at(x, y).entity == EntityType::None) {
                if (x != 0 || y != 0) rooms.emplace_back(x, y);
            }
        }
    }
    if (rooms.empty()) rooms.emplace_back(0, 0);
    const auto tre = rooms[static_cast<std::size_t>(random_int(0, static_cast<int>(rooms.size()) - 1))];
    treasure_x_ = tre.first;
    treasure_y_ = tre.second;
    Tile& t = at(treasure_x_, treasure_y_);
    t.entity = EntityType::Treasure;
    t.mature = true;
    maze_active_ = true;
    return true;
}

bool World::wrap_allowed() const {
    if (hat_ == Hat::DinosaurHat) return false;
    if (maze_active_) return false;
    return true;
}

bool World::destination(int x, int y, Dir dir, int* nx, int* ny, bool* blocked) const {
    int dx = 0, dy = 0;
    dir_delta(dir, &dx, &dy);
    int tx = x + dx;
    int ty = y + dy;
    *blocked = false;
    if (!in_bounds(tx, ty)) {
        if (!wrap_allowed()) {
            *blocked = true;
            *nx = x;
            *ny = y;
            return false;
        }
        tx = (tx % size_ + size_) % size_;
        ty = (ty % size_ + size_) % size_;
    }
    *nx = tx;
    *ny = ty;
    if (at(tx, ty).entity == EntityType::Hedge) {
        *blocked = true;
        return false;
    }
    if (hat_ == Hat::DinosaurHat && dino_blocked(tx, ty)) {
        *blocked = true;
        return false;
    }
    return true;
}

bool World::dino_blocked(int nx, int ny) const {
    if (dino_body_.size() <= 1) return false;
    const auto tail = dino_body_.back();
    for (const auto& p : dino_body_) {
        if (p.first == nx && p.second == ny) {
            if (p.first == tail.first && p.second == tail.second) {
                return false;
            }
            return true;
        }
    }
    return false;
}

bool World::spawn_apple() {
    const Cost c = plant_cost(EntityType::Apple);
    if (!can_afford(c)) {
        return false;
    }
    std::vector<std::pair<int, int>> spots;
    for (int y = 0; y < size_; ++y) {
        for (int x = 0; x < size_; ++x) {
            if (at(x, y).entity == EntityType::None) {
                spots.emplace_back(x, y);
            }
        }
    }
    if (spots.empty()) {
        // A fully planted field used to leave no room for an apple, so the
        // dinosaur run ended before its first step. Fall back to any tile the
        // body does not cover; the apple replaces whatever grew there.
        for (int y = 0; y < size_; ++y) {
            for (int x = 0; x < size_; ++x) {
                const EntityType e = at(x, y).entity;
                if (e == EntityType::Hedge || e == EntityType::Treasure) continue;
                bool on_body = false;
                for (const auto& b : dino_body_) {
                    if (b.first == x && b.second == y) on_body = true;
                }
                if (!on_body) spots.emplace_back(x, y);
            }
        }
    }
    int ax = drone_x_;
    int ay = drone_y_;
    if (!spots.empty()) {
        const auto p = spots[static_cast<std::size_t>(random_int(0, static_cast<int>(spots.size()) - 1))];
        ax = p.first;
        ay = p.second;
    } else if (at(drone_x_, drone_y_).entity != EntityType::None) {
        return false;
    }
    pay(c);
    Tile& t = at(ax, ay);
    clear_entity(t);
    t.entity = EntityType::Apple;
    t.mature = true;
    t.value = 0;
    return true;
}

void World::harvest_dino() {
    const int n = static_cast<int>(dino_body_.size());
    const int64_t bones = 1LL * n * n;
    if (bones > 0) {
        add_item(Item::Bone, bones);
    }
    last_harvested_ = "Dinosaur";
    for (Tile& t : tiles_) {
        if (t.entity == EntityType::Apple) {
            clear_entity(t);
        }
    }
    dino_body_.clear();
    apples_eaten_ = 0;
    hat_ = Hat::StrawHat;
}

void World::dino_after_move() {}

bool World::plant_allowed(const Tile& tile, EntityType entity) const {
    switch (entity) {
        case EntityType::Bush:
            return tile.ground == GroundType::Soil && tile.entity == EntityType::None;
        case EntityType::Tree:
            return tile.entity == EntityType::None || tile.entity == EntityType::Grass;
        case EntityType::Carrot:
        case EntityType::Sunflower:
        case EntityType::Cactus:
            return tile.ground == GroundType::Soil && tile.entity == EntityType::None;
        case EntityType::Pumpkin:
            return tile.ground == GroundType::Soil &&
                   (tile.entity == EntityType::None || tile.entity == EntityType::DeadPumpkin);
        case EntityType::Grass:
            return tile.ground == GroundType::Grassland && tile.entity == EntityType::None;
        default:
            return false;
    }
}

void World::on_success_action_energy() {
    energy_action_counter_++;
    if (item(Item::Power) > 0 && energy_action_counter_ >= kActionsPerEnergy) {
        energy_action_counter_ = 0;
        items_[static_cast<int>(Item::Power)] -= 1;
    }
}

ActionResult World::try_harvest() {
    Tile& tile = at(drone_x_, drone_y_);
    const int64_t swing = action_ticks();
    if (maze_active_ && tile.entity != EntityType::Treasure) {
        clear_maze();
        return {false, swing, {}};
    }
    if (tile.entity == EntityType::DeadPumpkin) {
        // Nothing to collect, but the swing clears the rotten pumpkin so the
        // tile can take another crop (it used to block cactus and sunflowers).
        clear_entity(tile);
        return {false, swing, {}};
    }
    if (tile.entity == EntityType::Grass && !tile.mature) {
        // Cutting a young shoot restarts its growth at action start. A blind
        // fast loop keeps cutting it back; querying leaves growth untouched.
        begin_grass_growth(tile);
        return {false, swing, {}};
    }
    if (tile.entity == EntityType::None || tile.entity == EntityType::Hedge ||
        tile.entity == EntityType::Apple || !tile.mature) {
        // Other crops keep their existing failure effects and growth state.
        return {false, swing, {}};
    }
    if (tile.entity == EntityType::Treasure) {
        const int lvl = std::max(1, levels_[static_cast<int>(UnlockId::Mazes)]);
        add_item(Item::Gold, 1LL * size_ * size_ * lvl);
        last_harvested_ = "Treasure";
        clear_entity(tile);
        maze_reuse_ += 1;
        if (maze_reuse_ >= kMazeReuseLimit) {
            clear_maze();
        } else {
            std::vector<std::pair<int, int>> empties, hedges;
            for (int y = 0; y < size_; ++y) {
                for (int x = 0; x < size_; ++x) {
                    if (at(x, y).entity == EntityType::None) empties.emplace_back(x, y);
                    if (at(x, y).entity == EntityType::Hedge) hedges.emplace_back(x, y);
                }
            }
            if (maze_reuse_ > 8 && !hedges.empty() && random_int(0, 3) == 0) {
                const auto h = hedges[static_cast<std::size_t>(
                    random_int(0, static_cast<int>(hedges.size()) - 1))];
                clear_entity(at(h.first, h.second));
            }
            if (!empties.empty()) {
                const auto p = empties[static_cast<std::size_t>(
                    random_int(0, static_cast<int>(empties.size()) - 1))];
                treasure_x_ = p.first;
                treasure_y_ = p.second;
                at(treasure_x_, treasure_y_).entity = EntityType::Treasure;
                at(treasure_x_, treasure_y_).mature = true;
            } else {
                clear_maze();
            }
        }
        on_success_action_energy();
        return {true, swing, "Treasure"};
    }
    if (tile.entity == EntityType::Grass) {
        apply_harvest_yield(tile, entity_yield(EntityType::Grass), Item::Hay, "Grass");
        begin_grass_growth(tile);
        on_success_action_energy();
        return {true, swing, "Grass"};
    }
    if (tile.entity == EntityType::Bush) {
        apply_harvest_yield(tile, entity_yield(EntityType::Bush), Item::Wood, "Bush");
        clear_entity(tile);
        on_success_action_energy();
        return {true, swing, "Bush"};
    }
    if (tile.entity == EntityType::Tree) {
        apply_harvest_yield(tile, entity_yield(EntityType::Tree), Item::Wood, "Tree");
        clear_entity(tile);
        on_success_action_energy();
        return {true, swing, "Tree"};
    }
    if (tile.entity == EntityType::Carrot) {
        apply_harvest_yield(tile, entity_yield(EntityType::Carrot), Item::Carrot, "Carrot");
        clear_entity(tile);
        on_success_action_energy();
        return {true, swing, "Carrot"};
    }
    if (tile.entity == EntityType::Sunflower) {
        int64_t give = entity_yield(EntityType::Sunflower);
        const int count = sunflower_count();
        const int best = max_sunflower_petals();
        const bool miss = sunflower_penalty_;
        bool bonus = false;
        if (!miss && count >= kSunflowerBonusThreshold && tile.value == best && best >= 0) {
            give *= kSunflowerBonusMul;
            bonus = true;
        }
        if (miss) {
            sunflower_penalty_ = false;
        } else if (!bonus && count >= kSunflowerBonusThreshold && tile.value != best) {
            sunflower_penalty_ = true;
        }
        apply_harvest_yield(tile, give, Item::Power, "Sunflower");
        clear_entity(tile);
        on_success_action_energy();
        return {true, swing, "Sunflower"};
    }
    if (tile.entity == EntityType::Pumpkin) {
        const int n = pumpkin_square_size(drone_x_, drone_y_);
        apply_harvest_yield(tile, pumpkin_yield(n), Item::Pumpkin, "Pumpkin");
        if (n >= 2) {
            clear_pumpkin_square(drone_x_, drone_y_, n);
        } else {
            clear_entity(tile);
        }
        on_success_action_energy();
        return {true, swing, "Pumpkin"};
    }
    if (tile.entity == EntityType::Cactus) {
        auto cactus_sorted = [&](int x, int y) {
            const Tile& self = at(x, y);
            const Dir dirs[4] = {Dir::North, Dir::East, Dir::South, Dir::West};
            for (Dir d : dirs) {
                int dx = 0, dy = 0;
                dir_delta(d, &dx, &dy);
                const int nx = x + dx;
                const int ny = y + dy;
                // Sorting is judged inside the field: the wrapped neighbour
                // across an edge would make a fully sorted grid impossible.
                if (!in_bounds(nx, ny)) continue;
                const Tile& nb = at(nx, ny);
                if (nb.entity != EntityType::Cactus) continue;
                if (!nb.mature) return false;
                if ((d == Dir::North || d == Dir::East) && nb.value < self.value) return false;
                if ((d == Dir::South || d == Dir::West) && nb.value > self.value) return false;
            }
            return true;
        };
        if (!cactus_sorted(drone_x_, drone_y_)) {
            apply_harvest_yield(tile, 1, Item::Cactus, "Cactus");
            clear_entity(tile);
            on_success_action_energy();
            return {true, swing, "Cactus"};
        }
        std::vector<std::pair<int, int>> group;
        std::vector<char> seen(static_cast<std::size_t>(size_ * size_), 0);
        std::queue<std::pair<int, int>> q;
        q.emplace(drone_x_, drone_y_);
        seen[static_cast<std::size_t>(drone_y_ * size_ + drone_x_)] = 1;
        while (!q.empty()) {
            const auto [x, y] = q.front();
            q.pop();
            group.emplace_back(x, y);
            const Dir dirs[4] = {Dir::East, Dir::West, Dir::North, Dir::South};
            for (Dir d : dirs) {
                int dx = 0, dy = 0;
                dir_delta(d, &dx, &dy);
                const int nx = x + dx, ny = y + dy;
                if (!in_bounds(nx, ny)) continue;
                if (at(nx, ny).entity != EntityType::Cactus || !at(nx, ny).mature) continue;
                const std::size_t id = static_cast<std::size_t>(ny * size_ + nx);
                if (seen[id]) continue;
                seen[id] = 1;
                q.emplace(nx, ny);
            }
        }
        const int n = static_cast<int>(group.size());
        apply_harvest_yield(tile, 1LL * n * n, Item::Cactus, "Cactus");
        for (const auto& p : group) {
            clear_entity(at(p.first, p.second));
        }
        on_success_action_energy();
        return {true, swing, "Cactus"};
    }
    return {false, swing, {}};
}

ActionResult World::try_can_harvest() {
    const Tile& t = tile();
    const bool ripe = t.entity != EntityType::None && t.entity != EntityType::DeadPumpkin &&
                      t.entity != EntityType::Hedge && t.entity != EntityType::Apple && t.mature;
    return {ripe, kFailOrQueryTicks, ripe ? entity_type_name(t.entity) : std::string()};
}

ActionResult World::try_flip() { return {true, kFlipTicks, {}}; }

ActionResult World::try_can_move(Dir dir) {
    int nx = 0, ny = 0;
    bool blocked = false;
    const bool ok = destination(drone_x_, drone_y_, dir, &nx, &ny, &blocked);
    ActionResult r;
    r.success = ok && !blocked;
    r.ticks = kFailOrQueryTicks;
    r.value = dir_name(dir);
    return r;
}

ActionResult World::try_move(Dir dir) {
    if (!movement_unlocked() || size_ <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    int nx = 0, ny = 0;
    bool blocked = false;
    const bool ok = destination(drone_x_, drone_y_, dir, &nx, &ny, &blocked);
    if (!ok || blocked) {
        return {false, kFailOrQueryTicks, dir_name(dir)};
    }
    // A step is quicker than a swing: half an action. Otherwise walking a
    // 3×3 lap earns no more than standing on one tile (both action-bound).
    int64_t cost = move_ticks();
    if (hat_ == Hat::DinosaurHat) {
        int64_t t = kDinoMoveBaseTicks;
        for (int i = 0; i < apples_eaten_; ++i) {
            t = static_cast<int64_t>(std::floor(static_cast<double>(t) * 0.97));
            if (t < 1) t = 1;
        }
        cost = t;
    }
    drone_x_ = nx;
    drone_y_ = ny;
    drone_dir_ = dir;
    if (hat_ == Hat::DinosaurHat) {
        const bool ate = at(nx, ny).entity == EntityType::Apple;
        if (dino_body_.empty()) {
            dino_body_.push_front({nx, ny});
        } else {
            dino_body_.push_front({nx, ny});
            if (!ate && dino_body_.size() > 1) {
                dino_body_.pop_back();
            }
        }
        if (ate) {
            clear_entity(at(nx, ny));
            apples_eaten_ += 1;
            spawn_apple();
        }
    }
    on_success_action_energy();
    return {true, cost, dir_name(dir)};
}

ActionResult World::try_till() {
    if (!till_unlocked()) {
        return {false, kFailOrQueryTicks, {}};
    }
    Tile& tile = at(drone_x_, drone_y_);
    if (tile.ground == GroundType::Grassland) {
        tile.ground = GroundType::Soil;
        clear_entity(tile);
        on_success_action_energy();
        return {true, action_ticks(), ground_type_name(tile.ground)};
    }
    tile.ground = GroundType::Grassland;
    begin_grass_growth(tile);
    on_success_action_energy();
    return {true, action_ticks(), ground_type_name(tile.ground)};
}

ActionResult World::try_plant(EntityType entity) {
    if (entity == EntityType::Bush && !plant_unlocked()) {
        return {false, kFailOrQueryTicks, {}};
    }
    if (entity == EntityType::Carrot && levels_[static_cast<int>(UnlockId::Carrots)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    if (entity == EntityType::Tree && levels_[static_cast<int>(UnlockId::Trees)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    if (entity == EntityType::Sunflower && levels_[static_cast<int>(UnlockId::Sunflowers)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    if (entity == EntityType::Pumpkin && levels_[static_cast<int>(UnlockId::Pumpkins)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    if (entity == EntityType::Cactus && levels_[static_cast<int>(UnlockId::Cactus)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    if (entity != EntityType::Bush && entity != EntityType::Carrot && entity != EntityType::Tree &&
        entity != EntityType::Sunflower && entity != EntityType::Pumpkin &&
        entity != EntityType::Cactus && entity != EntityType::Grass) {
        return {false, kFailOrQueryTicks, {}};
    }
    Tile& tile = at(drone_x_, drone_y_);
    // Bush on grassland keeps the 0.1.5 full-swing failure (existing tests).
    if (entity == EntityType::Bush && !plant_allowed(tile, entity)) {
        return {false, action_ticks(), {}};
    }
    if (!plant_allowed(tile, entity)) {
        return {false, kFailOrQueryTicks, {}};
    }
    const Cost c = plant_cost(entity);
    if (!can_afford(c)) {
        return {false, kFailOrQueryTicks, {}};
    }
    pay(c);
    clear_entity(tile);
    begin_growth(tile, entity);
    assign_companion(tile, entity, drone_x_, drone_y_);
    on_success_action_energy();
    return {true, action_ticks(), entity_type_name(entity)};
}

ActionResult World::try_get_entity_type() {
    const EntityType type = tile().entity;
    const bool present = type != EntityType::None;
    return {present, kFailOrQueryTicks, entity_type_name(type)};
}

ActionResult World::try_get_ground_type() {
    const GroundType type = tile().ground;
    return {type == GroundType::Soil, kFailOrQueryTicks, ground_type_name(type)};
}

ActionResult World::try_get_pos_x() {
    ActionResult r;
    r.success = true;
    r.ticks = kFailOrQueryTicks;
    r.number = drone_x_;
    r.value = std::to_string(drone_x_);
    return r;
}

ActionResult World::try_get_pos_y() {
    ActionResult r;
    r.success = true;
    r.ticks = kFailOrQueryTicks;
    r.number = drone_y_;
    r.value = std::to_string(drone_y_);
    return r;
}

ActionResult World::try_get_world_size() {
    ActionResult r;
    r.success = true;
    r.ticks = kFailOrQueryTicks;
    r.number = size_;
    r.value = std::to_string(size_);
    return r;
}

ActionResult World::try_num_items(Item it) {
    ActionResult r;
    r.success = item(it) > 0;
    r.ticks = kFailOrQueryTicks;
    r.number = item(it);
    r.value = std::to_string(item(it));
    return r;
}

ActionResult World::try_num_unlocked(UnlockId id) {
    ActionResult r;
    r.success = num_unlocked(id) > 0;
    r.ticks = kFailOrQueryTicks;
    r.number = num_unlocked(id);
    r.value = std::to_string(num_unlocked(id));
    return r;
}

ActionResult World::try_get_cost_entity(EntityType entity) {
    ActionResult r;
    r.success = true;
    r.ticks = kFailOrQueryTicks;
    r.cost = cost_of_entity(entity);
    return r;
}

ActionResult World::try_get_cost_unlock(UnlockId id) {
    ActionResult r;
    r.success = true;
    r.ticks = kFailOrQueryTicks;
    r.cost = cost_of_unlock(id);
    return r;
}

ActionResult World::try_get_water() {
    ActionResult r;
    r.success = tile().water > 0.0;
    r.ticks = kFailOrQueryTicks;
    r.real = tile().water;
    r.number = static_cast<int64_t>(tile().water * 1000);
    return r;
}

ActionResult World::try_use_item(Item it, int n) {
    if (n <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    if (it == Item::Water) {
        if (levels_[static_cast<int>(UnlockId::Watering)] <= 0 || item(Item::Water) < n) {
            return {false, kFailOrQueryTicks, {}};
        }
        items_[static_cast<int>(Item::Water)] -= n;
        Tile& tile = at(drone_x_, drone_y_);
        tile.water = std::min(1.0, tile.water + kWaterPerCan * static_cast<double>(n));
        tile.watered_once = true;
        last_water_tick_ = tick_;
        last_water_x_ = drone_x_;
        last_water_y_ = drone_y_;
        on_success_action_energy();
        return {true, action_ticks(), "Water"};
    }
    if (it == Item::Fertilizer) {
        if (levels_[static_cast<int>(UnlockId::Fertilizer)] <= 0 ||
            item(Item::Fertilizer) < n) {
            return {false, kFailOrQueryTicks, {}};
        }
        Tile& tile = at(drone_x_, drone_y_);
        if (tile.entity == EntityType::None || tile.entity == EntityType::Hedge ||
            tile.entity == EntityType::Treasure) {
            return {false, kFailOrQueryTicks, {}};
        }
        items_[static_cast<int>(Item::Fertilizer)] -= n;
        for (int i = 0; i < n; ++i) {
            if (!tile.mature) {
                const int64_t cut = 2 * kTicksPerSecond;
                if (tile.grow_ticks_left <= cut) {
                    tile.grow_ticks_left = 0;
                    tile.mature = true;
                } else {
                    tile.grow_ticks_left -= cut;
                }
            }
            tile.infected = true;
        }
        on_success_action_energy();
        return {true, action_ticks(), "Fertilizer"};
    }
    if (it == Item::WeirdSubstance) {
        if (item(Item::WeirdSubstance) < n) {
            return {false, kFailOrQueryTicks, {}};
        }
        Tile& tile = at(drone_x_, drone_y_);
        if (tile.entity == EntityType::Bush && n >= substance_needed() &&
            levels_[static_cast<int>(UnlockId::Mazes)] > 0) {
            items_[static_cast<int>(Item::WeirdSubstance)] -= n;
            if (!generate_maze()) {
                return {false, kFailOrQueryTicks, {}};
            }
            on_success_action_energy();
            return {true, action_ticks(), "Maze"};
        }
        // Toggle infection on this tile and orthogonal neighbours.
        items_[static_cast<int>(Item::WeirdSubstance)] -= n;
        auto toggle = [&](int x, int y) {
            if (!in_bounds(x, y)) return;
            Tile& t = at(x, y);
            if (t.entity != EntityType::None && t.entity != EntityType::Hedge &&
                t.entity != EntityType::Treasure) {
                t.infected = !t.infected;
            }
        };
        toggle(drone_x_, drone_y_);
        toggle(drone_x_ + 1, drone_y_);
        toggle(drone_x_ - 1, drone_y_);
        toggle(drone_x_, drone_y_ + 1);
        toggle(drone_x_, drone_y_ - 1);
        on_success_action_energy();
        return {true, action_ticks(), "WeirdSubstance"};
    }
    return {false, kFailOrQueryTicks, {}};
}

ActionResult World::try_measure() {
    ActionResult r;
    r.ticks = kFailOrQueryTicks;
    const Tile& t = tile();
    if (maze_active_) {
        r.success = treasure_x_ >= 0;
        r.measure.ok = r.success;
        r.measure.x = treasure_x_;
        r.measure.y = treasure_y_;
        r.number = treasure_x_;
        return r;
    }
    if (hat_ == Hat::DinosaurHat) {
        for (int y = 0; y < size_; ++y) {
            for (int x = 0; x < size_; ++x) {
                if (at(x, y).entity == EntityType::Apple) {
                    r.success = true;
                    r.measure.ok = true;
                    r.measure.x = x;
                    r.measure.y = y;
                    return r;
                }
            }
        }
        r.success = false;
        return r;
    }
    if (t.entity == EntityType::Sunflower || t.entity == EntityType::Cactus) {
        r.success = true;
        r.measure.ok = true;
        r.measure.value = t.value;
        r.number = t.value;
        return r;
    }
    if (t.entity == EntityType::Pumpkin || t.entity == EntityType::DeadPumpkin) {
        r.success = true;
        r.measure.ok = true;
        r.measure.value = t.pumpkin_id;
        r.number = t.pumpkin_id;
        return r;
    }
    r.success = false;
    r.measure.ok = false;
    r.measure.value = -1;
    r.number = -1;
    return r;
}

ActionResult World::try_measure_dir(Dir dir) {
    ActionResult r;
    r.ticks = kFailOrQueryTicks;
    int nx = 0, ny = 0, dx = 0, dy = 0;
    dir_delta(dir, &dx, &dy);
    nx = drone_x_ + dx;
    ny = drone_y_ + dy;
    if (!in_bounds(nx, ny)) {
        if (!wrap_allowed()) {
            r.success = false;
            r.measure.ok = false;
            r.measure.value = -1;
            return r;
        }
        nx = (nx % size_ + size_) % size_;
        ny = (ny % size_ + size_) % size_;
    }
    const Tile& t = at(nx, ny);
    if (t.entity == EntityType::Sunflower || t.entity == EntityType::Cactus) {
        r.success = true;
        r.measure.ok = true;
        r.measure.value = t.value;
        r.number = t.value;
        return r;
    }
    if (t.entity == EntityType::Pumpkin || t.entity == EntityType::DeadPumpkin) {
        r.success = true;
        r.measure.ok = true;
        r.measure.value = t.pumpkin_id;
        r.number = t.pumpkin_id;
        return r;
    }
    r.success = false;
    r.measure.ok = false;
    r.measure.value = -1;
    r.number = -1;
    return r;
}

ActionResult World::try_swap(Dir dir) {
    if (levels_[static_cast<int>(UnlockId::Cactus)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    int nx = 0, ny = 0, dx = 0, dy = 0;
    dir_delta(dir, &dx, &dy);
    nx = drone_x_ + dx;
    ny = drone_y_ + dy;
    if (!in_bounds(nx, ny)) {
        if (!wrap_allowed()) {
            return {false, kFailOrQueryTicks, {}};
        }
        nx = (nx % size_ + size_) % size_;
        ny = (ny % size_ + size_) % size_;
    }
    Tile& a = at(drone_x_, drone_y_);
    Tile& b = at(nx, ny);
    // Swap entity state, including empty tiles (for insertion-style sorts).
    std::swap(a.entity, b.entity);
    std::swap(a.mature, b.mature);
    std::swap(a.grow_ticks_left, b.grow_ticks_left);
    std::swap(a.grow_ticks_total, b.grow_ticks_total);
    std::swap(a.value, b.value);
    std::swap(a.pumpkin_id, b.pumpkin_id);
    std::swap(a.infected, b.infected);
    std::swap(a.companion, b.companion);
    on_success_action_energy();
    return {true, action_ticks(), dir_name(dir)};
}

ActionResult World::try_get_companion() {
    ActionResult r;
    r.ticks = kFailOrQueryTicks;
    r.companion = tile().companion;
    r.success = r.companion.ok;
    return r;
}

ActionResult World::try_change_hat(Hat hat) {
    if (hat == hat_) {
        return {true, action_ticks(), hat_name(hat)};
    }
    if (hat_ == Hat::DinosaurHat && hat != Hat::DinosaurHat) {
        harvest_dino();
        on_success_action_energy();
        return {true, action_ticks(), hat_name(hat)};
    }
    if (hat == Hat::DinosaurHat) {
        if (levels_[static_cast<int>(UnlockId::Dinosaurs)] <= 0) {
            return {false, kFailOrQueryTicks, {}};
        }
        hat_ = Hat::DinosaurHat;
        dino_body_.clear();
        dino_body_.push_front({drone_x_, drone_y_});
        apples_eaten_ = 0;
        spawn_apple();
        on_success_action_energy();
        return {true, action_ticks(), hat_name(hat)};
    }
    if (hat == Hat::TopHat && levels_[static_cast<int>(UnlockId::Hats)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    hat_ = hat;
    on_success_action_energy();
    return {true, action_ticks(), hat_name(hat)};
}

ActionResult World::try_clear() {
    clear();
    return {true, kFailOrQueryTicks, {}};
}

ActionResult World::try_unlock_api(UnlockId id) {
    if (levels_[static_cast<int>(UnlockId::AutoUnlock)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    const UnlockResult ur = try_unlock(id);
    ActionResult r;
    r.success = ur == UnlockResult::Ok;
    r.ticks = kFailOrQueryTicks;
    r.number = static_cast<int>(ur);
    return r;
}

ActionResult World::try_print_slow() {
    return {true, kPrintTicks, last_print_};
}

ActionResult World::try_quick_print(const std::string& text) {
    last_print_ = text;
    prints_.push_back(text);
    ActionResult r;
    r.success = true;
    r.ticks = 0;
    r.value = text;
    return r;
}

ActionResult World::try_get_time() {
    ActionResult r;
    r.success = true;
    r.ticks = kFailOrQueryTicks;
    r.real = static_cast<double>(tick_) / static_cast<double>(kTicksPerSecond);
    r.number = tick_;
    return r;
}

ActionResult World::try_get_tick_count() {
    ActionResult r;
    r.success = true;
    r.ticks = kFailOrQueryTicks;
    r.number = tick_;
    return r;
}

ActionResult World::try_set_world_size(int size) {
    if (levels_[static_cast<int>(UnlockId::Debug2)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    if (size < 3) {
        restore_world_size_if_needed();
        return {true, kFailOrQueryTicks, {}};
    }
    if (saved_expand_level_ < 0) {
        saved_expand_level_ = expand_level_;
    }
    const int cap = world_size_for_expand_level(expand_level_ > 0 ? expand_level_ : 1);
    if (size > cap) size = cap;
    if (size > kMaxWorldSizeReserved) size = kMaxWorldSizeReserved;
    expand_to(size, true);
    drone_x_ = 0;
    drone_y_ = 0;
    reset_drones();
    return {true, kFailOrQueryTicks, std::to_string(size)};
}

ActionResult World::try_set_execution_speed(double speed) {
    if (levels_[static_cast<int>(UnlockId::Debug2)] <= 0) {
        return {false, kFailOrQueryTicks, {}};
    }
    exec_speed_override_ = speed;
    return {true, kFailOrQueryTicks, {}};
}

ActionResult World::try_random01() {
    ActionResult r;
    r.success = true;
    r.ticks = kFailOrQueryTicks;
    r.real = random01();
    return r;
}

ActionResult World::try_simulate(uint64_t seed, double speed) {
    ActionResult r;
    r.ticks = kFailOrQueryTicks;
    if (levels_[static_cast<int>(UnlockId::Simulation)] <= 0) {
        r.success = false;
        return r;
    }
    set_seed(seed);
    if (speed > 0.0) {
        exec_speed_override_ = speed;
    }
    r.success = true;
    r.number = static_cast<int64_t>(seed);
    r.real = static_cast<double>(seed);
    r.value = std::to_string(seed);
    return r;
}

void World::flush_active_drone() {
    if (active_drone_ < 0) return;
    if (active_drone_ >= static_cast<int>(drone_locs_.size())) {
        drone_locs_.resize(static_cast<std::size_t>(active_drone_) + 1);
    }
    drone_locs_[static_cast<std::size_t>(active_drone_)] = {drone_x_, drone_y_, drone_dir_};
}

void World::reset_drones() {
    drone_locs_.assign(1, {drone_x_, drone_y_, drone_dir_});
    active_drone_ = 0;
}

void World::set_active_drone(int id) {
    if (id == active_drone_) {
        flush_active_drone();
        return;
    }
    flush_active_drone();
    if (id < 0) id = 0;
    if (id >= static_cast<int>(drone_locs_.size())) {
        drone_locs_.resize(static_cast<std::size_t>(id) + 1, {drone_x_, drone_y_, drone_dir_});
    }
    active_drone_ = id;
    drone_x_ = drone_locs_[static_cast<std::size_t>(id)].x;
    drone_y_ = drone_locs_[static_cast<std::size_t>(id)].y;
    drone_dir_ = drone_locs_[static_cast<std::size_t>(id)].dir;
}

int World::register_drone() {
    flush_active_drone();
    const int id = static_cast<int>(drone_locs_.size());
    drone_locs_.push_back({drone_x_, drone_y_, drone_dir_});
    return id;
}

int World::drone_x_of(int id) const {
    if (id == active_drone_) return drone_x_;
    if (id < 0 || id >= static_cast<int>(drone_locs_.size())) return 0;
    return drone_locs_[static_cast<std::size_t>(id)].x;
}

int World::drone_y_of(int id) const {
    if (id == active_drone_) return drone_y_;
    if (id < 0 || id >= static_cast<int>(drone_locs_.size())) return 0;
    return drone_locs_[static_cast<std::size_t>(id)].y;
}

Dir World::drone_direction_of(int id) const {
    if (id == active_drone_) return drone_dir_;
    if (id < 0 || id >= static_cast<int>(drone_locs_.size())) return Dir::South;
    return drone_locs_[static_cast<std::size_t>(id)].dir;
}

namespace {

ActionResult apply_and_advance(World* world, ActionResult r) {
    world->advance(r.ticks);
    return r;
}

}  // namespace

ActionResult World::harvest() { return apply_and_advance(this, try_harvest()); }
ActionResult World::can_harvest() { return apply_and_advance(this, try_can_harvest()); }
ActionResult World::do_a_flip() { return apply_and_advance(this, try_flip()); }
ActionResult World::move(Dir dir) { return apply_and_advance(this, try_move(dir)); }
ActionResult World::can_move(Dir dir) { return apply_and_advance(this, try_can_move(dir)); }
ActionResult World::till() { return apply_and_advance(this, try_till()); }
ActionResult World::plant(EntityType entity) { return apply_and_advance(this, try_plant(entity)); }
ActionResult World::get_entity_type() { return apply_and_advance(this, try_get_entity_type()); }
ActionResult World::get_ground_type() { return apply_and_advance(this, try_get_ground_type()); }
ActionResult World::get_pos_x() { return apply_and_advance(this, try_get_pos_x()); }
ActionResult World::get_pos_y() { return apply_and_advance(this, try_get_pos_y()); }
ActionResult World::get_world_size_action() { return apply_and_advance(this, try_get_world_size()); }
ActionResult World::num_items_action(Item item) { return apply_and_advance(this, try_num_items(item)); }
ActionResult World::use_item(Item item, int n) { return apply_and_advance(this, try_use_item(item, n)); }
ActionResult World::get_water_action() { return apply_and_advance(this, try_get_water()); }
ActionResult World::measure() { return apply_and_advance(this, try_measure()); }
ActionResult World::measure_dir(Dir dir) { return apply_and_advance(this, try_measure_dir(dir)); }
ActionResult World::swap(Dir dir) { return apply_and_advance(this, try_swap(dir)); }
ActionResult World::get_companion() { return apply_and_advance(this, try_get_companion()); }
ActionResult World::change_hat(Hat hat) { return apply_and_advance(this, try_change_hat(hat)); }

bool World::grass_mature() const { return tile_mature(drone_x_, drone_y_); }

bool World::tile_mature(int x, int y) const {
    if (!in_bounds(x, y)) {
        return false;
    }
    const Tile& tile = at(x, y);
    return tile.entity != EntityType::None && tile.entity != EntityType::DeadPumpkin &&
           tile.entity != EntityType::Hedge && tile.mature;
}

double World::grass_grow_ratio() const { return tile_grow_ratio(drone_x_, drone_y_); }

double World::tile_grow_ratio(int x, int y) const {
    if (!in_bounds(x, y)) {
        return 0.0;
    }
    const Tile& tile = at(x, y);
    if (tile.entity == EntityType::None || tile.entity == EntityType::Hedge ||
        tile.entity == EntityType::DeadPumpkin) {
        return 0.0;
    }
    if (tile.mature) {
        return 1.0;
    }
    const int64_t total_ticks = tile.grow_ticks_total > 0 ? tile.grow_ticks_total
                                                          : grow_ticks_for(tile.entity);
    if (total_ticks <= 0) {
        return 0.0;
    }
    const double left = static_cast<double>(tile.grow_ticks_left);
    const double total = static_cast<double>(total_ticks);
    return std::clamp(1.0 - left / total, 0.0, 1.0);
}

void World::set_entity_empty() { clear_entity(at(drone_x_, drone_y_)); }

void World::start_grass_growth() {
    Tile& tile = at(drone_x_, drone_y_);
    tile.ground = GroundType::Grassland;
    begin_grass_growth(tile);
}

int64_t World::grow_ticks_left() const {
    const Tile& tile = at(drone_x_, drone_y_);
    if (tile.entity != EntityType::None && !tile.mature) {
        return tile.grow_ticks_left;
    }
    return 0;
}

int64_t World::grass_grow_ticks_left() const {
    const Tile& tile = at(drone_x_, drone_y_);
    if (tile.entity == EntityType::Grass && !tile.mature) {
        return tile.grow_ticks_left;
    }
    return 0;
}

void World::wait_until_mature() {
    const int64_t left = grow_ticks_left();
    if (left > 0) {
        advance(left);
    }
}

void World::set_grass_mature() {
    Tile& tile = at(drone_x_, drone_y_);
    tile.ground = GroundType::Grassland;
    tile.entity = EntityType::Grass;
    tile.mature = true;
    tile.grow_ticks_left = 0;
    tile.grow_ticks_total = kGrassGrowTicks;
}

void World::set_ground(GroundType ground) {
    Tile& tile = at(drone_x_, drone_y_);
    tile.ground = ground;
}

void World::set_bush_growing() {
    Tile& tile = at(drone_x_, drone_y_);
    tile.ground = GroundType::Soil;
    begin_growth(tile, EntityType::Bush);
}

void World::set_bush_mature() {
    Tile& tile = at(drone_x_, drone_y_);
    tile.ground = GroundType::Soil;
    tile.entity = EntityType::Bush;
    tile.mature = true;
    tile.grow_ticks_left = 0;
}

void World::set_entity(EntityType entity, bool mature, int value) {
    Tile& tile = at(drone_x_, drone_y_);
    tile.entity = entity;
    tile.mature = mature;
    tile.value = value;
    if (entity == EntityType::Pumpkin || entity == EntityType::DeadPumpkin) {
        if (tile.pumpkin_id == 0) {
            tile.pumpkin_id = next_pumpkin_id_++;
        }
        if (value != 0) {
            tile.pumpkin_id = value;
            tile.value = value;
        }
    }
    if (mature) {
        tile.grow_ticks_left = 0;
    } else {
        const int64_t ticks = grow_ticks_for(entity);
        tile.grow_ticks_left = ticks;
        tile.grow_ticks_total = ticks;
    }
}

void World::set_water(double w) {
    Tile& tile = at(drone_x_, drone_y_);
    tile.water = std::clamp(w, 0.0, 1.0);
    if (w > 0.0) tile.watered_once = true;
}

void World::set_infected(bool v) { at(drone_x_, drone_y_).infected = v; }

void World::set_grow_ticks_left(int64_t ticks) {
    Tile& tile = at(drone_x_, drone_y_);
    tile.grow_ticks_left = ticks;
    if (tile.grow_ticks_total < ticks) tile.grow_ticks_total = ticks;
    tile.mature = ticks <= 0;
}

void World::grant_prereqs_for_test(UnlockId id) {
    // Recursively grant each prerequisite without spending items.
    auto bump = [&](UnlockId u) {
        if (levels_[static_cast<int>(u)] == 0) {
            grant_for_test(u);
        }
    };
    switch (id) {
        case UnlockId::Loops:
            break;
        case UnlockId::Speed:
            bump(UnlockId::Loops);
            break;
        case UnlockId::Conditions:
            bump(UnlockId::Speed);
            break;
        case UnlockId::Movement:
            bump(UnlockId::Conditions);
            break;
        case UnlockId::ForLoop:
        case UnlockId::Till:
            bump(UnlockId::Movement);
            break;
        case UnlockId::Plant:
            bump(UnlockId::Till);
            break;
        case UnlockId::Variables:
            bump(UnlockId::ForLoop);
            break;
        case UnlockId::Const:
        case UnlockId::Operators:
            bump(UnlockId::Variables);
            break;
        case UnlockId::Senses:
            bump(UnlockId::Plant);
            break;
        case UnlockId::Expand:
            bump(UnlockId::Movement);
            break;
        case UnlockId::Carrots:
            bump(UnlockId::Plant);
            bump(UnlockId::Senses);
            break;
        case UnlockId::Costs:
        case UnlockId::Watering:
            bump(UnlockId::Carrots);
            break;
        case UnlockId::Trees:
            bump(UnlockId::Carrots);
            bump(UnlockId::Operators);
            break;
        case UnlockId::Functions:
            bump(UnlockId::Variables);
            bump(UnlockId::Carrots);
            break;
        case UnlockId::References:
        case UnlockId::Includes:
            bump(UnlockId::Functions);
            break;
        case UnlockId::HayYield:
            bump(UnlockId::Plant);
            break;
        case UnlockId::Sunflowers:
            bump(UnlockId::Carrots);
            bump(UnlockId::Functions);
            break;
        case UnlockId::Arrays:
            bump(UnlockId::Functions);
            break;
        case UnlockId::Structs:
            bump(UnlockId::Arrays);
            break;
        case UnlockId::SwitchEnum:
            bump(UnlockId::Plant);
            break;
        case UnlockId::Pumpkins:
            bump(UnlockId::Carrots);
            bump(UnlockId::Arrays);
            break;
        case UnlockId::Utilities:
            bump(UnlockId::Pumpkins);
            break;
        case UnlockId::Fertilizer:
            bump(UnlockId::Watering);
            break;
        case UnlockId::Mazes:
            bump(UnlockId::Fertilizer);
            bump(UnlockId::Functions);
            break;
        case UnlockId::Cactus:
            bump(UnlockId::Pumpkins);
            bump(UnlockId::Sunflowers);
            bump(UnlockId::Arrays);
            bump(UnlockId::Operators);
            break;
        case UnlockId::Companions:
            bump(UnlockId::Pumpkins);
            bump(UnlockId::Trees);
            break;
        case UnlockId::Dinosaurs:
            bump(UnlockId::Cactus);
            break;
        case UnlockId::Megafarm:
            bump(UnlockId::Mazes);
            bump(UnlockId::References);
            break;
        case UnlockId::Debug:
            bump(UnlockId::Plant);
            break;
        case UnlockId::Timing:
            bump(UnlockId::Pumpkins);
            break;
        case UnlockId::Debug2:
            bump(UnlockId::Debug);
            break;
        case UnlockId::Simulation:
            bump(UnlockId::Debug2);
            break;
        case UnlockId::AutoUnlock:
            bump(UnlockId::Costs);
            bump(UnlockId::Carrots);
            break;
        case UnlockId::Hats:
            bump(UnlockId::Loops);
            break;
        default:
            break;
    }
}

void World::grant_for_test(UnlockId id) {
    grant_prereqs_for_test(id);
    if (levels_[static_cast<int>(id)] == 0) {
        levels_[static_cast<int>(id)] = 1;
    }
    if (id == UnlockId::Movement && expand_level_ < 1) {
        expand_level_ = 1;
        expand_to(kExpandedWorldSize, false);
    }
    if (id == UnlockId::Expand) {
        const int want = 1 + levels_[static_cast<int>(UnlockId::Expand)];
        if (expand_level_ < want) {
            expand_level_ = want;
            if (expand_level_ > kMaxExpandLevel) {
                expand_level_ = kMaxExpandLevel;
            }
            expand_to(world_size_for_expand_level(expand_level_), true);
            drone_x_ = 0;
            drone_y_ = 0;
        }
    }
    if (id == UnlockId::Carrots && levels_[static_cast<int>(UnlockId::Costs)] == 0) {
        levels_[static_cast<int>(UnlockId::Costs)] = 1;
    }
}

void World::grant_level_for_test(UnlockId id, int level) {
    grant_for_test(id);
    if (level > levels_[static_cast<int>(id)]) {
        levels_[static_cast<int>(id)] = level;
    }
    if (id == UnlockId::Expand) {
        expand_level_ = 1 + levels_[static_cast<int>(UnlockId::Expand)];
        expand_to(world_size_for_expand_level(expand_level_), true);
    }
    if (id == UnlockId::Speed && level > 0) {
        levels_[static_cast<int>(UnlockId::Speed)] = level;
    }
}

void World::unlock_all_for_test() {
    grant_for_test(UnlockId::Plant);
    grant_for_test(UnlockId::ForLoop);
}

}  // namespace codefarm
