// Runtime values, scopes, call frames and per-drone execution state.
// Internal to the interpreter: included only by interpreter.cpp.
#pragma once

#include "codefarm/interpreter.hpp"
#include "codefarm/world.hpp"
#include "interpreter_ast.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace codefarm::detail {

enum class VKind {
    None, Int, Bool, Real, String, Entity, Ground, Dir, Item, Unlock, Hat, Cost, Measure, Companion,
    Array, Object
};

struct Value {
    VKind kind = VKind::Int;
    int64_t i = 0;
    double d = 0;
    bool b = false;
    std::string s;
    Cost cost{};
    Measure measure{};
    Companion companion{};
    std::shared_ptr<std::vector<Value>> arr;
    std::shared_ptr<std::map<std::string, Value>> obj;
    Value* ref = nullptr;

    static Value make_int(int64_t v) {
        Value x;
        x.kind = VKind::Int;
        x.i = v;
        x.b = v != 0;
        return x;
    }
    static Value make_bool(bool v) {
        Value x;
        x.kind = VKind::Bool;
        x.b = v;
        x.i = v ? 1 : 0;
        return x;
    }
    static Value make_real(double v) {
        Value x;
        x.kind = VKind::Real;
        x.d = v;
        x.i = static_cast<int64_t>(v);
        x.b = v != 0;
        return x;
    }
    static Value make_str(std::string v) {
        Value x;
        x.kind = VKind::String;
        x.s = std::move(v);
        x.b = !x.s.empty();
        return x;
    }

    int64_t as_int() const {
        if (kind == VKind::Real) return static_cast<int64_t>(d);
        return i;
    }
    double as_real() const {
        if (kind == VKind::Real) return d;
        return static_cast<double>(i);
    }
    bool truthy() const {
        if (kind == VKind::String) return !s.empty();
        if (kind == VKind::Real) return d != 0;
        if (kind == VKind::Cost) return !cost.is_zero();
        if (kind == VKind::Measure) return measure.ok;
        if (kind == VKind::Companion) return companion.ok;
        return b || i != 0;
    }
    std::string as_str() const {
        if (kind == VKind::String) return s;
        if (kind == VKind::Real) {
            std::ostringstream os;
            os << d;
            return os.str();
        }
        if (!s.empty()) return s;
        return std::to_string(i);
    }
};

struct Env {
    std::map<std::string, std::unique_ptr<Value>> vars;
    Env* parent = nullptr;

    Value* lookup(const std::string& name) {
        auto it = vars.find(name);
        if (it != vars.end()) return it->second.get();
        if (parent) return parent->lookup(name);
        return nullptr;
    }
    Value* define(const std::string& name, Value v) {
        auto p = std::make_unique<Value>(std::move(v));
        Value* raw = p.get();
        vars[name] = std::move(p);
        return raw;
    }
};

enum class FrameKind { Plain, Loop, Switch, Fn };

// One executing statement list. `memo` replays the results of calls already
// made by the statement at `index`, so a statement can suspend at every farm
// action (or user function call) and resume without repeating side effects.
struct Frame {
    const std::vector<Stmt>* body = nullptr;
    std::size_t index = 0;
    FrameKind fkind = FrameKind::Plain;
    bool for_started = false;
    int for_phase = 0;
    int for_i = 0;
    std::size_t for_stmt_index = static_cast<std::size_t>(-1);
    std::string for_name;
    std::string fn_name;
    std::shared_ptr<Env> own_env;
    Env* restore_env = nullptr;
    std::vector<Value> memo;
};

inline Frame make_frame(const std::vector<Stmt>* body, FrameKind kind = FrameKind::Plain) {
    Frame f;
    f.body = body;
    f.fkind = kind;
    return f;
}

struct DroneExec {
    int id = 0;
    std::vector<Frame> frames;
    std::vector<std::unique_ptr<Env>> envs;
    Env* env = nullptr;
    int64_t wait_remaining = 0;
    ExecEvent current{};
    bool has_current = false;
    bool running = false;
    bool finished = false;
    int64_t ret_i = 0;
    bool started = false;
};

}  // namespace codefarm::detail
