#pragma once

#include <array>
#include <cstdint>
#include <string>

namespace codefarm {

// ---------------------------------------------------------------------------
// Clock. All farm action timings are derived from these constants.
// ---------------------------------------------------------------------------
inline constexpr int64_t kTicksPerSecond = 400;
inline constexpr int64_t kFailOrQueryTicks = 1;
// Grass grows in 1.0 second (400 ticks). At 1x, a harvest swing takes the
// same 400 ticks, so while (true) { harvest(); } lands on ripe grass. The
// Speed shortens every harvest swing, never growth. Cutting unripe grass
// restarts its 400-tick growth at action start, so a blind 2x loop stalls.
// A 1-tick can_harvest() query leaves growth untouched (about 400 per crop).
inline constexpr int64_t kGrassGrowTicks = 400;
inline constexpr int64_t kBaseActionTicks = kGrassGrowTicks;
inline constexpr int64_t kSuccessActionTicks = kBaseActionTicks;
inline constexpr int kActionSpeedBase = 1;
inline constexpr int kActionSpeedBoosted = 2;
// Bush grows in 2.0 seconds (800 ticks) on tilled soil (teaching value;
// original community mean is 4.0s — kept so 0.1.5 tests stay stable).
inline constexpr int64_t kBushGrowTicks = 800;
inline constexpr int64_t kFlipTicks = 400;
inline constexpr int64_t kMoveTicks = kSuccessActionTicks / 2;  // a step is half a swing
inline constexpr int64_t kTillTicks = kSuccessActionTicks;
inline constexpr int64_t kPlantTicks = kSuccessActionTicks;
inline constexpr int64_t kPrintTicks = 400;  // slow print / cout, ignores Speed
inline constexpr int64_t kWaterIntervalTicks = 4000;       // 10 seconds
inline constexpr int64_t kFertilizerIntervalTicks = 4000;  // 10 seconds
inline constexpr int64_t kEvaporateSliceTicks = 40;        // 0.1 second
inline constexpr int kEvaporateChancePercent = 10;         // 10% per slice
inline constexpr double kEvaporateFraction = 0.01;         // 1% of current water
inline constexpr double kWaterPerCan = 0.25;
inline constexpr int kActionsPerEnergy = 30;
inline constexpr int kSunflowerMinPetals = 7;
inline constexpr int kSunflowerMaxPetals = 15;
inline constexpr int kSunflowerBonusThreshold = 10;
inline constexpr int kSunflowerBonusMul = 8;
inline constexpr int kPumpkinWiltPercent = 20;
inline constexpr int kCactusMinSize = 0;
inline constexpr int kCactusMaxSize = 9;
inline constexpr int kCompanionMaxDist = 3;
inline constexpr int kMazeReuseLimit = 300;
inline constexpr int kDinoMoveBaseTicks = 400;
inline constexpr int kMaxWorldSizePlayable = 16;
inline constexpr int kMaxWorldSizeReserved = 32;

// A-chain shop prices (hay).
inline constexpr int kCostLoops = 5;
inline constexpr int kCostSpeed = 8;
inline constexpr int kCostIf = 12;
inline constexpr int kCostMove = 20;
inline constexpr int kCostFor = 30;
inline constexpr int kCostTill = 40;
inline constexpr int kCostPlant = 60;
inline constexpr int kExpandedWorldSize = 3;

// World side-length ladder. Index 0 is the opening 1×1; index 1 is Movement
// (3×3); later Expand levels walk the rest. 24 and 32 are reserved.
inline constexpr int kWorldSizeLadder[] = {1, 3, 4, 5, 6, 8, 10, 12, 16, 24, 32};
inline constexpr int kWorldSizeLadderCount =
    static_cast<int>(sizeof(kWorldSizeLadder) / sizeof(kWorldSizeLadder[0]));
inline constexpr int kMaxExpandLevel = 8;  // side 16

enum class Item {
    Hay = 0,
    Wood,
    Carrot,
    Pumpkin,
    Power,
    Water,
    Fertilizer,
    WeirdSubstance,
    Gold,
    Cactus,
    Bone,
    COUNT
};
inline constexpr int kItemCount = static_cast<int>(Item::COUNT);

enum class UnlockId {
    Loops = 0,
    Speed,
    Conditions,
    Movement,
    ForLoop,
    Till,
    Plant,
    Variables,
    Const,
    Senses,
    Operators,
    Expand,
    Carrots,
    Costs,
    Watering,
    Trees,
    Functions,
    References,
    HayYield,
    Includes,
    Sunflowers,
    Arrays,
    Structs,
    SwitchEnum,
    Pumpkins,
    Utilities,
    Fertilizer,
    Mazes,
    Cactus,
    Companions,
    Dinosaurs,
    Megafarm,
    Debug,
    Timing,
    Debug2,
    Simulation,
    AutoUnlock,
    Hats,
    COUNT
};
inline constexpr int kUnlockCount = static_cast<int>(UnlockId::COUNT);

enum class UnlockResult {
    Ok = 0,
    AlreadyUnlocked = 1,
    LockedPrerequisite = 2,
    NotEnoughHay = 3,
    Invalid = 4,
    NotEnoughItems = 5,
};

enum class Dir { East, West, North, South };

enum class GroundType {
    Grassland,
    Soil,
    // DLC reserved (The Miner Was Replaced): Clay, Perlite, Loam. Not used
    // on the 1.0 main line.
    Clay,
    Perlite,
    Loam
};

enum class EntityType {
    None,
    Grass,
    Bush,
    Carrot,
    Tree,
    Sunflower,
    Pumpkin,
    DeadPumpkin,
    Cactus,
    Hedge,
    Treasure,
    Apple,
    // DLC reserved: Rice, Bamboo. Not planted on the 1.0 main line.
    Rice,
    Bamboo
};

enum class Hat { StrawHat, DinosaurHat, TopHat };

enum class ActionKind {
    None,
    Harvest,
    CanHarvest,
    Flip,
    Move,
    WhileCheck,
    IfCheck,
    Till,
    Plant,
    GetEntity,
    GetGround,
    ForCheck,
    GetPos,
    GetWorldSize,
    NumItems,
    NumUnlocked,
    GetCost,
    UseItem,
    GetWater,
    Measure,
    CanMove,
    Swap,
    GetCompanion,
    ChangeHat,
    Clear,
    SpawnDrone,
    WaitFor,
    HasFinished,
    Unlock,
    Print,
    QuickPrint,
    GetTime,
    Simulate,
    SetWorldSize,
    SetSpeed,
    MinMax,
};

struct Cost {
    int hay = 0;
    int wood = 0;
    int carrot = 0;
    int pumpkin = 0;
    int cactus = 0;
    int gold = 0;
    int bone = 0;
    int weird = 0;
    int power = 0;

    int of(Item item) const {
        switch (item) {
            case Item::Hay:
                return hay;
            case Item::Wood:
                return wood;
            case Item::Carrot:
                return carrot;
            case Item::Pumpkin:
                return pumpkin;
            case Item::Cactus:
                return cactus;
            case Item::Gold:
                return gold;
            case Item::Bone:
                return bone;
            case Item::WeirdSubstance:
                return weird;
            case Item::Power:
                return power;
            default:
                return 0;
        }
    }

    int& of_mut(Item item) {
        switch (item) {
            case Item::Hay:
                return hay;
            case Item::Wood:
                return wood;
            case Item::Carrot:
                return carrot;
            case Item::Pumpkin:
                return pumpkin;
            case Item::Cactus:
                return cactus;
            case Item::Gold:
                return gold;
            case Item::Bone:
                return bone;
            case Item::WeirdSubstance:
                return weird;
            case Item::Power:
                return power;
            default: {
                static int dummy = 0;
                dummy = 0;
                return dummy;
            }
        }
    }

    bool is_zero() const {
        return hay == 0 && wood == 0 && carrot == 0 && pumpkin == 0 && cactus == 0 &&
               gold == 0 && bone == 0 && weird == 0 && power == 0;
    }
};

inline Cost cost_hay(int n) {
    Cost c;
    c.hay = n;
    return c;
}
inline Cost cost_wood(int n) {
    Cost c;
    c.wood = n;
    return c;
}
inline Cost cost_hw(int h, int w) {
    Cost c;
    c.hay = h;
    c.wood = w;
    return c;
}
inline Cost cost_carrot(int n) {
    Cost c;
    c.carrot = n;
    return c;
}
inline Cost cost_wc(int w, int c) {
    Cost x;
    x.wood = w;
    x.carrot = c;
    return x;
}
inline Cost cost_pumpkin(int n) {
    Cost c;
    c.pumpkin = n;
    return c;
}
inline Cost cost_cactus(int n) {
    Cost c;
    c.cactus = n;
    return c;
}
inline Cost cost_gold(int n) {
    Cost c;
    c.gold = n;
    return c;
}
inline Cost cost_bone(int n) {
    Cost c;
    c.bone = n;
    return c;
}
inline Cost cost_weird(int n) {
    Cost c;
    c.weird = n;
    return c;
}

struct GrowthRange {
    int64_t min_ticks = 0;
    int64_t max_ticks = 0;
};

struct Measure {
    bool ok = false;
    int value = 0;
    int x = 0;
    int y = 0;
};

struct Companion {
    bool ok = false;
    EntityType type = EntityType::None;
    int x = 0;
    int y = 0;
};

struct UnlockSpec {
    UnlockId id = UnlockId::Loops;
    const char* name = "";
    int max_level = 1;
};

// ---- name tables -----------------------------------------------------------

inline const char* item_name(Item item) {
    switch (item) {
        case Item::Hay:
            return "Hay";
        case Item::Wood:
            return "Wood";
        case Item::Carrot:
            return "Carrot";
        case Item::Pumpkin:
            return "Pumpkin";
        case Item::Power:
            return "Power";
        case Item::Water:
            return "Water";
        case Item::Fertilizer:
            return "Fertilizer";
        case Item::WeirdSubstance:
            return "WeirdSubstance";
        case Item::Gold:
            return "Gold";
        case Item::Cactus:
            return "Cactus";
        case Item::Bone:
            return "Bone";
        default:
            return "";
    }
}

inline bool item_from_name(const std::string& name, Item* out) {
    for (int i = 0; i < kItemCount; ++i) {
        const Item it = static_cast<Item>(i);
        const char* n = item_name(it);
        if (name == n) {
            *out = it;
            return true;
        }
    }
    if (name == "Weird_Substance" || name == "Substance" || name == "weird") {
        *out = Item::WeirdSubstance;
        return true;
    }
    if (name == "hay") { *out = Item::Hay; return true; }
    if (name == "wood") { *out = Item::Wood; return true; }
    if (name == "carrot") { *out = Item::Carrot; return true; }
    if (name == "pumpkin") { *out = Item::Pumpkin; return true; }
    if (name == "power") { *out = Item::Power; return true; }
    if (name == "water" || name == "water_tank") { *out = Item::Water; return true; }
    if (name == "fertilizer") { *out = Item::Fertilizer; return true; }
    if (name == "gold") { *out = Item::Gold; return true; }
    if (name == "cactus") { *out = Item::Cactus; return true; }
    if (name == "bone") { *out = Item::Bone; return true; }
    return false;
}

inline const char* unlock_id_name(UnlockId id) {
    switch (id) {
        case UnlockId::Loops:
            return "loop";
        case UnlockId::Speed:
            return "speed";
        case UnlockId::Conditions:
            return "iff";
        case UnlockId::Movement:
            return "move";
        case UnlockId::ForLoop:
            return "forl";
        case UnlockId::Till:
            return "till";
        case UnlockId::Plant:
            return "plant";
        case UnlockId::Variables:
            return "vars";
        case UnlockId::Const:
            return "constn";
        case UnlockId::Senses:
            return "senses";
        case UnlockId::Operators:
            return "ops";
        case UnlockId::Expand:
            return "expand";
        case UnlockId::Carrots:
            return "carrot";
        case UnlockId::Costs:
            return "costs";
        case UnlockId::Watering:
            return "water";
        case UnlockId::Trees:
            return "tree";
        case UnlockId::Functions:
            return "func";
        case UnlockId::References:
            return "ref";
        case UnlockId::HayYield:
            return "hayup";
        case UnlockId::Includes:
            return "include";
        case UnlockId::Sunflowers:
            return "sun";
        case UnlockId::Arrays:
            return "array";
        case UnlockId::Structs:
            return "rec";
        case UnlockId::SwitchEnum:
            return "swenum";
        case UnlockId::Pumpkins:
            return "pumpkin";
        case UnlockId::Utilities:
            return "util";
        case UnlockId::Fertilizer:
            return "fert";
        case UnlockId::Mazes:
            return "maze";
        case UnlockId::Cactus:
            return "cactus";
        case UnlockId::Companions:
            return "companion";
        case UnlockId::Dinosaurs:
            return "dino";
        case UnlockId::Megafarm:
            return "mega";
        case UnlockId::Debug:
            return "debug";
        case UnlockId::Timing:
            return "timing";
        case UnlockId::Debug2:
            return "debug2";
        case UnlockId::Simulation:
            return "sim";
        case UnlockId::AutoUnlock:
            return "autounlock";
        case UnlockId::Hats:
            return "hats";
        default:
            return "";
    }
}

inline int unlock_max_level(UnlockId id) {
    switch (id) {
        case UnlockId::Speed:
            return 5;
        case UnlockId::Expand:
            return kMaxExpandLevel;  // levels 2..8 stored as 1..7 plus Movement
        case UnlockId::Carrots:
        case UnlockId::Trees:
        case UnlockId::HayYield:
        case UnlockId::Pumpkins:
            return 6;
        case UnlockId::Watering:
        case UnlockId::Dinosaurs:
            return 5;
        case UnlockId::Fertilizer:
            return 4;
        case UnlockId::Mazes:
        case UnlockId::Cactus:
        case UnlockId::Companions:
        case UnlockId::Megafarm:
            return 5;
        default:
            return 1;
    }
}

inline bool unlock_id_from_name(const std::string& name, UnlockId* out) {
    static const char* kAliases[][2] = {
        {"loop", "loop"}, {"loops", "loop"}, {"while", "loop"},
        {"speed", "speed"}, {"accel", "speed"}, {"加速", "speed"},
        {"iff", "iff"}, {"if", "iff"}, {"conditions", "iff"},
        {"move", "move"}, {"movement", "move"},
        {"forl", "forl"}, {"for", "forl"},
        {"till", "till"},
        {"plant", "plant"},
        {"vars", "vars"}, {"variables", "vars"}, {"var", "vars"},
        {"constn", "constn"}, {"const", "constn"},
        {"senses", "senses"}, {"sense", "senses"},
        {"ops", "ops"}, {"operators", "ops"},
        {"expand", "expand"},
        {"carrot", "carrot"}, {"carrots", "carrot"},
        {"costs", "costs"}, {"cost", "costs"},
        {"water", "water"}, {"watering", "water"},
        {"tree", "tree"}, {"trees", "tree"},
        {"func", "func"}, {"functions", "func"}, {"function", "func"},
        {"ref", "ref"}, {"references", "ref"},
        {"hayup", "hayup"}, {"grass", "hayup"},
        {"include", "include"}, {"includes", "include"},
        {"sun", "sun"}, {"sunflower", "sun"}, {"sunflowers", "sun"},
        {"array", "array"}, {"arrays", "array"}, {"vector", "array"},
        {"rec", "rec"}, {"struct", "rec"}, {"structs", "rec"},
        {"swenum", "swenum"}, {"switch", "swenum"},
        {"pumpkin", "pumpkin"}, {"pumpkins", "pumpkin"},
        {"util", "util"}, {"utilities", "util"},
        {"fert", "fert"}, {"fertilizer", "fert"},
        {"maze", "maze"}, {"mazes", "maze"},
        {"cactus", "cactus"},
        {"companion", "companion"}, {"companions", "companion"},
        {"dino", "dino"}, {"dinosaur", "dino"}, {"dinosaurs", "dino"},
        {"mega", "mega"}, {"megafarm", "mega"}, {"drones", "mega"},
        {"debug", "debug"},
        {"timing", "timing"},
        {"debug2", "debug2"},
        {"sim", "sim"}, {"simulation", "sim"},
        {"autounlock", "autounlock"}, {"unlocks", "autounlock"},
        {"hats", "hats"},
        {nullptr, nullptr},
    };
    // Unlock names are written like the skill-tree enum (Speed, Watering,
    // Pumpkins); match them case-insensitively against the ids and aliases.
    std::string lower = name;
    for (char& ch : lower) {
        if (ch >= 'A' && ch <= 'Z') ch = static_cast<char>(ch - 'A' + 'a');
    }
    std::string key = lower;
    for (int i = 0; kAliases[i][0] != nullptr; ++i) {
        if (lower == kAliases[i][0]) {
            key = kAliases[i][1];
            break;
        }
    }
    for (int i = 0; i < kUnlockCount; ++i) {
        const UnlockId id = static_cast<UnlockId>(i);
        if (key == unlock_id_name(id)) {
            *out = id;
            return true;
        }
    }
    return false;
}

// Cost of the *next* level. `current_level` is 0 if locked.
inline Cost unlock_cost_at(UnlockId id, int current_level) {
    auto geo = [](int first, int ratio, int level_index) {
        int v = first;
        for (int i = 0; i < level_index; ++i) {
            v *= ratio;
        }
        return v;
    };
    switch (id) {
        case UnlockId::Loops:
            return current_level >= 1 ? Cost{} : cost_hay(kCostLoops);
        case UnlockId::Speed:
            if (current_level >= 5) return {};
            if (current_level == 0) return cost_hay(kCostSpeed);
            if (current_level == 1) return cost_wood(20);
            if (current_level == 2) return cost_wc(50, 50);
            if (current_level == 3) return cost_carrot(120);
            return cost_carrot(250);
        case UnlockId::Conditions:
            return current_level >= 1 ? Cost{} : cost_hay(kCostIf);
        case UnlockId::Movement:
            return current_level >= 1 ? Cost{} : cost_hay(kCostMove);
        case UnlockId::ForLoop:
            return current_level >= 1 ? Cost{} : cost_hay(kCostFor);
        case UnlockId::Till:
            return current_level >= 1 ? Cost{} : cost_hay(kCostTill);
        case UnlockId::Plant:
            return current_level >= 1 ? Cost{} : cost_hay(kCostPlant);
        case UnlockId::Variables:
            return current_level >= 1 ? Cost{} : cost_hay(70);  // or 25 wood — paid as hay; also accept wood in world
        case UnlockId::Const:
            return current_level >= 1 ? Cost{} : cost_wood(15);
        case UnlockId::Senses:
            return current_level >= 1 ? Cost{} : cost_wood(40);
        case UnlockId::Operators:
            return current_level >= 1 ? Cost{} : cost_hw(30, 20);
        case UnlockId::Expand: {
            // current_level here is "how many Expand *upgrades* owned" (0 = at 3×3).
            if (current_level >= 7) return {};
            if (current_level == 0) return cost_wood(40);
            if (current_level == 1) return cost_wc(80, 20);
            if (current_level == 2) return cost_wc(160, 60);
            if (current_level == 3) return cost_wc(0, 200);
            if (current_level == 4) return cost_pumpkin(40);
            if (current_level == 5) return cost_pumpkin(120);
            return cost_pumpkin(400);
        }
        case UnlockId::Carrots: {
            if (current_level >= 6) return {};
            if (current_level == 0) return cost_wood(50);
            const int prices[] = {125, 300, 800, 2000, 5000};
            return cost_wood(prices[current_level - 1]);
        }
        case UnlockId::Costs:
            return current_level >= 1 ? Cost{} : Cost{};  // bundled with carrots (0 extra)
        case UnlockId::Watering: {
            if (current_level >= 5) return {};
            if (current_level == 0) return cost_wood(50);
            const int prices[] = {200, 800, 2400, 7200};
            return cost_wood(prices[current_level - 1]);
        }
        case UnlockId::Trees: {
            if (current_level >= 6) return {};
            if (current_level == 0) return cost_wc(50, 40);
            const int prices[] = {100, 300, 900, 2700, 8000};
            return cost_hay(prices[current_level - 1]);
        }
        case UnlockId::Functions:
            return current_level >= 1 ? Cost{} : cost_carrot(40);
        case UnlockId::References:
            return current_level >= 1 ? Cost{} : cost_carrot(30);
        case UnlockId::HayYield: {
            if (current_level >= 6) return {};
            if (current_level == 0) return cost_hay(100);
            return cost_hay(geo(200, 3, current_level - 1));
        }
        case UnlockId::Includes:
            return current_level >= 1 ? Cost{} : cost_carrot(80);
        case UnlockId::Sunflowers:
            return current_level >= 1 ? Cost{} : cost_carrot(80);
        case UnlockId::Arrays:
            return current_level >= 1 ? Cost{} : cost_carrot(60);
        case UnlockId::Structs:
            return current_level >= 1 ? Cost{} : cost_carrot(40);
        case UnlockId::SwitchEnum:
            return current_level >= 1 ? Cost{} : cost_carrot(25);
        case UnlockId::Pumpkins: {
            if (current_level >= 6) return {};
            if (current_level == 0) return cost_wc(80, 40);
            const int prices[] = {80, 200, 500, 1200, 3000};
            return cost_carrot(prices[current_level - 1]);
        }
        case UnlockId::Utilities:
            return current_level >= 1 ? Cost{} : cost_pumpkin(40);
        case UnlockId::Fertilizer: {
            if (current_level >= 4) return {};
            if (current_level == 0) return cost_wood(80);
            const int prices[] = {200, 600, 1800};
            return cost_wood(prices[current_level - 1]);
        }
        case UnlockId::Mazes: {
            if (current_level >= 5) return {};
            if (current_level == 0) return cost_weird(80);
            const int prices[] = {40, 120, 400, 1200};
            return cost_cactus(prices[current_level - 1]);
        }
        case UnlockId::Cactus: {
            if (current_level >= 5) return {};
            if (current_level == 0) return cost_pumpkin(120);
            return cost_pumpkin(geo(400, 4, current_level - 1));
        }
        case UnlockId::Companions: {
            if (current_level >= 5) return {};
            if (current_level == 0) return cost_pumpkin(80);
            return cost_bone(geo(20, 3, current_level - 1));
        }
        case UnlockId::Dinosaurs: {
            if (current_level >= 5) return {};
            if (current_level == 0) return cost_cactus(120);
            return cost_cactus(geo(200, 3, current_level - 1));
        }
        case UnlockId::Megafarm: {
            if (current_level >= 5) return {};
            if (current_level == 0) return cost_gold(120);
            return cost_gold(geo(400, 4, current_level - 1));
        }
        case UnlockId::Debug:
            return current_level >= 1 ? Cost{} : cost_hw(20, 20);
        case UnlockId::Timing:
            return current_level >= 1 ? Cost{} : cost_pumpkin(30);
        case UnlockId::Debug2:
            return current_level >= 1 ? Cost{} : cost_gold(80);
        case UnlockId::Simulation:
            return current_level >= 1 ? Cost{} : cost_gold(200);
        case UnlockId::AutoUnlock:
            return current_level >= 1 ? Cost{} : cost_pumpkin(150);
        case UnlockId::Hats:
            return current_level >= 1 ? Cost{} : cost_hay(50);
        default:
            return {};
    }
}

// Backward-compatible hay-only cost (A-chain and tests).
inline int unlock_cost(UnlockId id) { return unlock_cost_at(id, 0).hay; }

inline GrowthRange growth_range(EntityType type) {
    GrowthRange r;
    switch (type) {
        case EntityType::Grass:
            r.min_ticks = r.max_ticks = kGrassGrowTicks;
            break;
        case EntityType::Bush:
            r.min_ticks = r.max_ticks = kBushGrowTicks;
            break;
        case EntityType::Carrot:
            r.min_ticks = 1920;  // 4.8s
            r.max_ticks = 2880;  // 7.2s
            break;
        case EntityType::Tree:
        case EntityType::Sunflower:
            r.min_ticks = 2240;  // 5.6s
            r.max_ticks = 3360;  // 8.4s
            break;
        case EntityType::Pumpkin:
            r.min_ticks = 80;    // 0.2s
            r.max_ticks = 1520;  // 3.8s
            break;
        case EntityType::Cactus:
            r.min_ticks = r.max_ticks = 400;
            break;
        case EntityType::Apple:
            r.min_ticks = 72;
            r.max_ticks = 88;
            break;
        default:
            break;
    }
    return r;
}

inline int64_t grow_ticks_for(EntityType type) {
    const GrowthRange r = growth_range(type);
    if (r.min_ticks == r.max_ticks) {
        return r.min_ticks;
    }
    return (r.min_ticks + r.max_ticks) / 2;
}

inline int64_t pumpkin_yield(int n) {
    if (n <= 0) {
        return 0;
    }
    if (n >= 6) {
        return 6LL * n * n;
    }
    return 1LL * n * n * n;
}

inline double water_growth_mul(double water) {
    if (water < 0.0) water = 0.0;
    if (water > 1.0) water = 1.0;
    return 1.0 + 4.0 * water;
}

inline int world_size_for_expand_level(int expand_level) {
    // expand_level 0 = 1×1, 1 = 3×3 (Movement), 2 = 4×4, ...
    if (expand_level < 0) expand_level = 0;
    if (expand_level >= kWorldSizeLadderCount) {
        return kWorldSizeLadder[kWorldSizeLadderCount - 1];
    }
    return kWorldSizeLadder[expand_level];
}

inline const char* action_kind_name(ActionKind kind) {
    switch (kind) {
        case ActionKind::Harvest:
            return "harvest";
        case ActionKind::CanHarvest:
            return "can_harvest";
        case ActionKind::Flip:
            return "do_a_flip";
        case ActionKind::Move:
            return "move";
        case ActionKind::WhileCheck:
            return "while";
        case ActionKind::IfCheck:
            return "if";
        case ActionKind::Till:
            return "till";
        case ActionKind::Plant:
            return "plant";
        case ActionKind::GetEntity:
            return "get_entity_type";
        case ActionKind::GetGround:
            return "get_ground_type";
        case ActionKind::ForCheck:
            return "for";
        case ActionKind::GetPos:
            return "get_pos";
        case ActionKind::GetWorldSize:
            return "get_world_size";
        case ActionKind::NumItems:
            return "num_items";
        case ActionKind::NumUnlocked:
            return "num_unlocked";
        case ActionKind::GetCost:
            return "get_cost";
        case ActionKind::UseItem:
            return "use_item";
        case ActionKind::GetWater:
            return "get_water";
        case ActionKind::Measure:
            return "measure";
        case ActionKind::CanMove:
            return "can_move";
        case ActionKind::Swap:
            return "swap";
        case ActionKind::GetCompanion:
            return "get_companion";
        case ActionKind::ChangeHat:
            return "change_hat";
        case ActionKind::Clear:
            return "clear";
        case ActionKind::SpawnDrone:
            return "spawn_drone";
        case ActionKind::WaitFor:
            return "wait_for";
        case ActionKind::HasFinished:
            return "has_finished";
        case ActionKind::Unlock:
            return "unlock";
        case ActionKind::Print:
            return "print";
        case ActionKind::QuickPrint:
            return "quick_print";
        case ActionKind::GetTime:
            return "get_time";
        case ActionKind::Simulate:
            return "simulate";
        case ActionKind::SetWorldSize:
            return "set_world_size";
        case ActionKind::SetSpeed:
            return "set_execution_speed";
        case ActionKind::MinMax:
            return "minmax";
        case ActionKind::None:
        default:
            return "none";
    }
}

inline const char* dir_name(Dir dir) {
    switch (dir) {
        case Dir::East:
            return "East";
        case Dir::West:
            return "West";
        case Dir::North:
            return "North";
        case Dir::South:
            return "South";
    }
    return "East";
}

inline bool dir_from_name(const std::string& name, Dir* out) {
    if (name == "East" || name == "Dir::East") {
        *out = Dir::East;
        return true;
    }
    if (name == "West" || name == "Dir::West") {
        *out = Dir::West;
        return true;
    }
    if (name == "North" || name == "Dir::North") {
        *out = Dir::North;
        return true;
    }
    if (name == "South" || name == "Dir::South") {
        *out = Dir::South;
        return true;
    }
    return false;
}

inline void dir_delta(Dir dir, int* dx, int* dy) {
    *dx = 0;
    *dy = 0;
    switch (dir) {
        case Dir::East:
            *dx = 1;
            break;
        case Dir::West:
            *dx = -1;
            break;
        case Dir::North:
            *dy = 1;
            break;
        case Dir::South:
            *dy = -1;
            break;
    }
}

inline const char* entity_type_name(EntityType type) {
    switch (type) {
        case EntityType::Grass:
            return "Grass";
        case EntityType::Bush:
            return "Bush";
        case EntityType::Carrot:
            return "Carrot";
        case EntityType::Tree:
            return "Tree";
        case EntityType::Sunflower:
            return "Sunflower";
        case EntityType::Pumpkin:
            return "Pumpkin";
        case EntityType::DeadPumpkin:
            return "DeadPumpkin";
        case EntityType::Cactus:
            return "Cactus";
        case EntityType::Hedge:
            return "Hedge";
        case EntityType::Treasure:
            return "Treasure";
        case EntityType::Apple:
            return "Apple";
        case EntityType::Rice:
            return "Rice";
        case EntityType::Bamboo:
            return "Bamboo";
        case EntityType::None:
        default:
            return "None";
    }
}

inline bool entity_from_name(const std::string& name, EntityType* out) {
    const char* names[] = {"None", "Grass", "Bush", "Carrot", "Tree", "Sunflower",
                           "Pumpkin", "DeadPumpkin", "Cactus", "Hedge", "Treasure",
                           "Apple", "Rice", "Bamboo"};
    for (const char* n : names) {
        if (name == n || name == std::string("Entity::") + n) {
            EntityType t = EntityType::None;
            if (std::string(n) == "Grass") t = EntityType::Grass;
            else if (std::string(n) == "Bush") t = EntityType::Bush;
            else if (std::string(n) == "Carrot") t = EntityType::Carrot;
            else if (std::string(n) == "Tree") t = EntityType::Tree;
            else if (std::string(n) == "Sunflower") t = EntityType::Sunflower;
            else if (std::string(n) == "Pumpkin") t = EntityType::Pumpkin;
            else if (std::string(n) == "DeadPumpkin") t = EntityType::DeadPumpkin;
            else if (std::string(n) == "Cactus") t = EntityType::Cactus;
            else if (std::string(n) == "Hedge") t = EntityType::Hedge;
            else if (std::string(n) == "Treasure") t = EntityType::Treasure;
            else if (std::string(n) == "Apple") t = EntityType::Apple;
            else if (std::string(n) == "Rice") t = EntityType::Rice;
            else if (std::string(n) == "Bamboo") t = EntityType::Bamboo;
            *out = t;
            return true;
        }
    }
    return false;
}

inline const char* ground_type_name(GroundType type) {
    switch (type) {
        case GroundType::Soil:
            return "Soil";
        case GroundType::Clay:
            return "Clay";
        case GroundType::Perlite:
            return "Perlite";
        case GroundType::Loam:
            return "Loam";
        case GroundType::Grassland:
        default:
            return "Grassland";
    }
}

inline bool ground_from_name(const std::string& name, GroundType* out) {
    if (name == "Soil" || name == "Ground::Soil") {
        *out = GroundType::Soil;
        return true;
    }
    if (name == "Grassland" || name == "Ground::Grassland") {
        *out = GroundType::Grassland;
        return true;
    }
    if (name == "Clay") {
        *out = GroundType::Clay;
        return true;
    }
    if (name == "Perlite") {
        *out = GroundType::Perlite;
        return true;
    }
    if (name == "Loam") {
        *out = GroundType::Loam;
        return true;
    }
    return false;
}

inline const char* hat_name(Hat hat) {
    switch (hat) {
        case Hat::DinosaurHat:
            return "DinosaurHat";
        case Hat::TopHat:
            return "TopHat";
        case Hat::StrawHat:
        default:
            return "StrawHat";
    }
}

inline bool hat_from_name(const std::string& name, Hat* out) {
    if (name == "DinosaurHat" || name == "Hats::DinosaurHat" || name == "Dinosaur_Hat") {
        *out = Hat::DinosaurHat;
        return true;
    }
    if (name == "TopHat" || name == "Hats::TopHat") {
        *out = Hat::TopHat;
        return true;
    }
    if (name == "StrawHat" || name == "Hats::StrawHat") {
        *out = Hat::StrawHat;
        return true;
    }
    return false;
}

struct ExecEvent {
    int line = 0;  // 1-based source line
    int64_t start_tick = 0;
    int64_t duration_ticks = 0;
    ActionKind kind = ActionKind::None;
    bool success = false;
    int drone_id = 0;
};

struct ActionResult {
    bool success = false;
    int64_t ticks = kFailOrQueryTicks;
    std::string value;
    int64_t number = 0;
    double real = 0.0;
    Measure measure{};
    Companion companion{};
    Cost cost{};
};

}  // namespace codefarm
