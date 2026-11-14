#pragma once
// Full playthrough harness: plays Codefarm from a fresh save using only what
// a player can do — write the exemplar program, press "run once" (restart it
// when main returns), and buy skills with what the farm earned. No test
// backdoors (grant_for_test, set_item, set_grass_mature...) are used here.

#include "codefarm/interpreter.hpp"
#include "codefarm/world.hpp"

#include <filesystem>

#include <fstream>
#include <functional>
#include <map>
#include <sstream>
#include <string>
#include <vector>
#include "codefarm_paths.hpp"

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

namespace playthrough {

using namespace codefarm;

inline std::filesystem::path utf8_path(const std::string& text) {
#ifdef _WIN32
    const int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
                                     static_cast<int>(text.size()), nullptr, 0);
    std::wstring wide(static_cast<std::size_t>(n), L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
                        static_cast<int>(text.size()), wide.data(), n);
    return std::filesystem::path(wide);
#else
    return std::filesystem::path(std::u8string(text.begin(), text.end()));
#endif
}

inline std::string path_utf8(const std::filesystem::path& path) {
    const auto bytes = path.u8string();
    return std::string(bytes.begin(), bytes.end());
}

inline std::string source_dir() {
    static const std::string root = [] {
        const auto configured = utf8_path(reinterpret_cast<const char*>(codefarm_paths::root));
        std::vector<std::filesystem::path> candidates = {configured, std::filesystem::current_path()};
#ifdef _WIN32
        std::wstring exe(32768, L'\0');
        const DWORD n = GetModuleFileNameW(nullptr, exe.data(), static_cast<DWORD>(exe.size()));
        exe.resize(n);
        candidates.push_back(std::filesystem::path(exe).parent_path());
#endif
        for (auto candidate : candidates) {
            for (int i = 0; i < 8 && !candidate.empty(); ++i) {
                std::error_code ec;
                if (std::filesystem::is_regular_file(candidate / "game/exemplars/harvest.cpp", ec))
                    return path_utf8(candidate);
                const auto parent = candidate.parent_path();
                if (parent == candidate) break;
                candidate = parent;
            }
        }
        return path_utf8(configured);
    }();
    return root;
}

inline std::string exemplar_dir() { return source_dir() + "/game/exemplars"; }

inline std::string read_file(const std::string& path) {
#ifdef _WIN32
    const auto file_path = utf8_path(path);
    HANDLE file = CreateFileW(file_path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                              nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return {};
    std::string out;
    char buffer[8192];
    DWORD n = 0;
    bool ok = true;
    while ((ok = ReadFile(file, buffer, sizeof buffer, &n, nullptr)) && n > 0)
        out.append(buffer, n);
    CloseHandle(file);
    return ok ? out : std::string();
#else
    std::ifstream in(utf8_path(path), std::ios::binary);
    if (!in) return {};
    std::stringstream ss;
    ss << in.rdbuf();
    return ss.str();
#endif
}

// Exemplar main file for a skill id, e.g. "forl" -> game/exemplars/forl.cpp.
inline std::string exemplar(const std::string& id) { return read_file(exemplar_dir() + "/" + id + ".cpp"); }

// Extra headers that belong to an exemplar: "<id>.<name>" files, e.g.
// include.rows.hpp is offered to the program as "rows.hpp".
inline std::map<std::string, std::string> exemplar_includes(const std::string& id) {
    std::map<std::string, std::string> out;
    std::error_code ec;
    for (const auto& entry : std::filesystem::directory_iterator(utf8_path(exemplar_dir()), ec)) {
        const auto utf8 = entry.path().filename().u8string();
        const std::string name(utf8.begin(), utf8.end());
        const std::string prefix = id + ".";
        if (name.rfind(prefix, 0) == 0 && name != id + ".cpp") {
            out[name.substr(prefix.size())] = read_file(exemplar_dir() + "/" + name);
        }
    }
    return out;
}

inline std::vector<std::string> exemplar_ids() {
    std::vector<std::string> ids;
    std::error_code ec;
    for (const auto& entry : std::filesystem::directory_iterator(utf8_path(exemplar_dir()), ec)) {
        const auto utf8 = entry.path().filename().u8string();
        const std::string name(utf8.begin(), utf8.end());
        if (name.size() > 4 && name.substr(name.size() - 4) == ".cpp") ids.push_back(name.substr(0, name.size() - 4));
    }
    return ids;
}

struct StageLog {
    std::string program;   // exemplar that was running
    std::string bought;    // skill bought at the end of this stage
    int level = 0;         // level after buying
    double seconds = 0;    // game seconds since the previous purchase
    double speed = 1;      // action speed factor while earning
    std::string cost;
};

inline std::string cost_text(const Cost& c) {
    std::ostringstream o;
    auto add = [&](int n, const char* name) {
        if (n > 0) {
            if (o.tellp() > 0) o << " + ";
            o << n << " " << name;
        }
    };
    add(c.hay, "hay");
    add(c.wood, "wood");
    add(c.carrot, "carrot");
    add(c.pumpkin, "pumpkin");
    add(c.cactus, "cactus");
    add(c.gold, "gold");
    add(c.bone, "bone");
    add(c.weird, "weird");
    return o.str();
}

class Player {
public:
    World world;
    std::string error;
    std::vector<StageLog> log;

    Player() { interp_.bind(&world); }

    // Press "run once" on an exemplar. Returns false (and records error) if
    // the program does not compile with what is unlocked right now.
    bool load(const std::string& id) {
        program_ = id;
        interp_ = Interpreter();
        interp_.bind(&world);
        for (const auto& kv : exemplar_includes(id)) interp_.set_include(kv.first, kv.second);
        const std::string src = exemplar(id);
        if (src.empty()) {
            error = "missing exemplar " + id;
            return false;
        }
        const std::string err = interp_.load(src);
        if (!err.empty()) {
            error = id + ": " + err;
            return false;
        }
        interp_.start();
        return true;
    }

    // Compile only (no run): used to prove a skill is needed before purchase.
    std::string compile_error(const std::string& id) {
        Interpreter probe;
        probe.bind(&world);
        for (const auto& kv : exemplar_includes(id)) probe.set_include(kv.first, kv.second);
        return probe.load(exemplar(id));
    }

    Interpreter& interp() { return interp_; }

    // Let the current program run. Finished programs are started again, like
    // a player pressing run once more. Stops when `done()` or after
    // `max_seconds` of game time. Returns elapsed game seconds, or -1.
    double run_until(const std::function<bool()>& done, double max_seconds, int max_restarts = 1 << 30) {
        const int64_t t0 = world.tick();
        const int64_t limit = static_cast<int64_t>(max_seconds * kTicksPerSecond);
        int restarts = 0;
        while (world.tick() - t0 < limit) {
            if (done()) return static_cast<double>(world.tick() - t0) / kTicksPerSecond;
            if (interp_.has_error()) {
                error = program_ + " runtime: " + interp_.error();
                return -1;
            }
            if (interp_.is_finished() || !interp_.is_running()) {
                if (++restarts > max_restarts) {
                    // A finished program with no restarts left: time still flows.
                    world.advance(kTicksPerSecond / 4);
                    continue;
                }
                interp_.start();
            }
            const int64_t before = world.tick();
            interp_.advance(kTicksPerSecond / 4);
            if (world.tick() == before && interp_.is_running()) world.advance(1);
        }
        return done() ? static_cast<double>(world.tick() - t0) / kTicksPerSecond : -1;
    }

    // A program that eats a stock (sunflowers and pumpkins eat carrots) is
    // paused while the stock is low: the player runs `program` until the
    // stock is back to `high`, then returns to the earner.
    struct Refill {
        Item item = Item::Carrot;
        int64_t low = -1;  // disabled
        int64_t high = 0;
        std::string program;
    };
    Refill refill;

    // Top a stock up with `program`, then reload the current one.
    bool top_up(Item item, int64_t high, const std::string& program, double max_seconds) {
        if (world.item(item) >= high) return true;
        const std::string back = program_;
        if (!load(program)) return false;
        const double secs = run_until([&] { return world.item(item) >= high; }, max_seconds);
        if (secs < 0) {
            if (error.empty()) error = "could not refill " + std::string(item_name(item)) + " with " + program;
            return false;
        }
        return load(back);
    }

    // Run until the skill can be bought, then stop, buy and restart the same
    // program (it is recompiled, so newly unlocked syntax is accepted).
    bool earn_and_buy(UnlockId id, double max_seconds) {
        StageLog s;
        s.program = program_;
        s.bought = unlock_id_name(id);
        s.cost = cost_text(world.cost_of_unlock(id));
        s.speed = world.action_speed_factor();
        if (!world.prerequisite_met(id)) {
            error = std::string("prerequisite missing for ") + s.bought;
            return false;
        }
        const int64_t deadline = world.tick() + static_cast<int64_t>(max_seconds * kTicksPerSecond);
        double secs = -1;
        while (world.tick() < deadline) {
            const double left = static_cast<double>(deadline - world.tick()) / kTicksPerSecond;
            secs = run_until([&] { return world.can_unlock(id) || world.item(refill.item) < refill.low; }, left);
            if (secs < 0 || world.can_unlock(id)) break;
            if (!top_up(refill.item, refill.high, refill.program, left)) return false;
            secs = -1;
        }
        if (secs < 0) {
            if (error.empty()) {
                error = std::string("could not afford ") + s.bought + " (" + s.cost + ") within " +
                        std::to_string(static_cast<int>(max_seconds)) + "s running " + program_;
            }
            return false;
        }
        interp_.stop();
        if (world.try_unlock(id) != UnlockResult::Ok) {
            error = std::string("unlock failed: ") + s.bought;
            return false;
        }
        (void)secs;
        s.seconds = static_cast<double>(world.tick() - last_buy_tick_) / kTicksPerSecond;
        last_buy_tick_ = world.tick();
        s.level = world.num_unlocked(id);
        log.push_back(s);
        return load(program_);
    }

    double total_seconds() const {
        double t = 0;
        for (const auto& s : log) t += s.seconds;
        return t;
    }

    // Count successful / failed harvests in the current run's event log,
    // optionally only those that started at or after `from_tick`.
    void harvest_counts(int* ok, int* miss, int64_t from_tick = 0) const {
        *ok = 0;
        *miss = 0;
        for (const auto& ev : interp_.events()) {
            if (ev.kind != ActionKind::Harvest || ev.start_tick < from_tick) continue;
            if (ev.success) ++*ok;
            else ++*miss;
        }
    }

    const std::string& program() const { return program_; }

private:
    int64_t last_buy_tick_ = 0;
    Interpreter interp_;
    std::string program_;
};

}  // namespace playthrough
