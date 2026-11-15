#include "codefarm/interpreter.hpp"

#include "codefarm/world.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <map>
#include <memory>
#include <sstream>
#include <utility>

#include "interpreter_parser.hpp"
#include "interpreter_runtime.hpp"

namespace codefarm {

using namespace detail;

struct Interpreter::Impl {
    World* world = nullptr;
    std::shared_ptr<std::vector<Stmt>> program;
    std::map<std::string, FunctionDef> functions;
    std::map<std::string, StructDef> structs;
    std::map<std::string, std::string> include_files;
    std::vector<Frame> frames;
    std::vector<std::unique_ptr<Env>> env_store;
    Env* env = nullptr;
    Env globals;
    std::vector<ExecEvent> events;
    ExecEvent current{};
    bool has_current = false;
    int64_t wait_remaining = 0;
    bool running = false;
    bool paused = false;
    bool finished = false;
    bool harvest_pulse = false;
    bool harvest_miss_pulse = false;
    bool flip_pulse = false;
    std::string error;
    Diagnostic diagnostic;
    std::vector<DroneExec> drones;
    int active_drone = 0;
    int view_drone = 0;

    void reset_runtime() {
        frames.clear();
        env_store.clear();
        env = nullptr;
        globals.vars.clear();
        events.clear();
        current = {};
        has_current = false;
        wait_remaining = 0;
        running = false;
        paused = false;
        finished = false;
        harvest_pulse = false;
        harvest_miss_pulse = false;
        flip_pulse = false;
        error.clear();
        diagnostic = {};
        drones.clear();
        active_drone = 0;
        view_drone = 0;
        if (world) {
            world->restore_world_size_if_needed();
            world->reset_drones();
        }
    }

    void fail(const std::string& message, SourceSpan span = {},
              ErrorKind kind = ErrorKind::Generic, const std::string& suggestion = {},
              const std::string& code_word = {}) {
        error = message;
        if (span.line <= 0 && has_current) {
            span.line = current.line;
            span.col_start = 1;
            span.col_end = 2;
        }
        if (span.line <= 0) {
            span.line = 1;
            span.col_start = 1;
            span.col_end = 2;
        }
        if (span.col_end <= span.col_start) span.col_end = span.col_start + 1;
        diagnostic.message = message;
        diagnostic.span = span;
        diagnostic.kind = kind;
        diagnostic.suggestion = suggestion;
        diagnostic.code_word = code_word;
        running = false;
        paused = false;
        finished = false;
        wait_remaining = 0;
    }

    void fail_at(const Expr& expr, const std::string& message, ErrorKind kind = ErrorKind::Generic,
                 const std::string& suggestion = {}, const std::string& code_word = {}) {
        SourceSpan span = expr.span;
        if (span.line <= 0) {
            span.line = expr.line;
            span.col_start = 1;
            span.col_end = 2;
        }
        fail(message, span, kind, suggestion, code_word);
    }

    void begin_wait(const ExecEvent& event) {
        if (events.size() >= 40000) events.erase(events.begin(), events.begin() + 20000);
        events.push_back(event);
        events.back().drone_id = active_drone;
        current = event;
        has_current = true;
        wait_remaining = event.duration_ticks;
        if (event.kind == ActionKind::Harvest && event.success) harvest_pulse = true;
        if (event.kind == ActionKind::Harvest && !event.success) harvest_miss_pulse = true;
        if (event.kind == ActionKind::Flip && event.success) flip_pulse = true;
        if (!drones.empty() && active_drone >= 0 &&
            active_drone < static_cast<int>(drones.size())) {
            drones[static_cast<std::size_t>(active_drone)].wait_remaining = event.duration_ticks;
            drones[static_cast<std::size_t>(active_drone)].current = event;
            drones[static_cast<std::size_t>(active_drone)].has_current = true;
        }
    }

    Value* lookup(const std::string& name) {
        if (env) {
            if (Value* v = env->lookup(name)) return v;
        }
        return globals.lookup(name);
    }

    bool ident_value(const std::string& name, Value* out) {
        Dir d;
        EntityType e;
        GroundType g;
        Item it;
        UnlockId u;
        Hat h;
        if (dir_from_name(name, &d)) {
            *out = Value::make_int(static_cast<int>(d));
            out->kind = VKind::Dir;
            out->s = dir_name(d);
            return true;
        }
        std::string last = name;
        const auto pos = name.rfind("::");
        if (pos != std::string::npos) last = name.substr(pos + 2);
        if (entity_from_name(name, &e) || entity_from_name(last, &e)) {
            *out = Value::make_int(static_cast<int>(e));
            out->kind = VKind::Entity;
            out->s = entity_type_name(e);
            return true;
        }
        if (ground_from_name(name, &g) || ground_from_name(last, &g)) {
            *out = Value::make_int(static_cast<int>(g));
            out->kind = VKind::Ground;
            out->s = ground_type_name(g);
            return true;
        }
        if (item_from_name(name, &it) || item_from_name(last, &it)) {
            *out = Value::make_int(static_cast<int>(it));
            out->kind = VKind::Item;
            out->s = item_name(it);
            return true;
        }
        if (unlock_id_from_name(name, &u) || unlock_id_from_name(last, &u)) {
            *out = Value::make_int(static_cast<int>(u));
            out->kind = VKind::Unlock;
            out->s = unlock_id_name(u);
            return true;
        }
        if (hat_from_name(name, &h) || hat_from_name(last, &h)) {
            *out = Value::make_int(static_cast<int>(h));
            out->kind = VKind::Hat;
            out->s = hat_name(h);
            return true;
        }
        if (Value* v = lookup(name)) {
            *out = v->ref ? *v->ref : *v;
            return true;
        }
        return false;
    }

    bool eval_to(const Expr& expr, Value* out, int64_t* wait_acc) {
        switch (expr.kind) {
            case ExprKind::LiteralTrue:
                *out = Value::make_bool(true);
                return true;
            case ExprKind::LiteralFalse:
                *out = Value::make_bool(false);
                return true;
            case ExprKind::LiteralInt:
                *out = Value::make_int(expr.int_val);
                return true;
            case ExprKind::LiteralReal:
                *out = Value::make_real(expr.real_val);
                return true;
            case ExprKind::LiteralString:
                *out = Value::make_str(expr.text);
                return true;
            case ExprKind::Ident:
                if (!ident_value(expr.name, out)) {
                    fail_at(expr, line_prefix(expr.line) + "未知的名字 “" + expr.name + "”。");
                    return false;
                }
                return true;
            case ExprKind::Call:
                (void)wait_acc;
                return eval_call(expr, out);
            case ExprKind::InitList: {
                Value arr;
                arr.kind = VKind::Array;
                arr.arr = std::make_shared<std::vector<Value>>();
                for (const auto& k : expr.kids) {
                    Value v;
                    if (!eval_to(k, &v, wait_acc)) return false;
                    arr.arr->push_back(v);
                }
                *out = arr;
                return true;
            }
            case ExprKind::Compare: {
                ActionResult ar;
                ActionKind kind = ActionKind::None;
                Value callv;
                if (!call_any(expr, &callv, &ar, &kind)) return false;
                if (wait_acc) *wait_acc += ar.ticks;
                const bool eq = ar.value == expr.cmp_rhs;
                *out = Value::make_bool(expr.cmp_op == "!=" ? !eq : eq);
                return true;
            }
            case ExprKind::Unary: {
                Value inner;
                if (!eval_to(expr.kids[0], &inner, wait_acc)) return false;
                if (expr.op == "!") {
                    *out = Value::make_bool(!inner.truthy());
                    return true;
                }
                if (expr.op == "-") {
                    if (inner.kind == VKind::Real) {
                        *out = Value::make_real(-inner.d);
                        return true;
                    }
                    *out = Value::make_int(-inner.as_int());
                    return true;
                }
                if (expr.op == "+") {
                    *out = inner;
                    return true;
                }
                // ++ / --
                Value* slot = lvalue(expr.kids[0]);
                if (!slot) {
                    fail_at(expr, line_prefix(expr.line) + "++/-- 需要变量。");
                    return false;
                }
                const int64_t old = slot->as_int();
                int64_t nv = old;
                if (expr.op.find("++") != std::string::npos) nv = old + 1;
                else nv = old - 1;
                *slot = Value::make_int(nv);
                *out = Value::make_int(expr.op.find("pre") == 0 ? nv : old);
                return true;
            }
            case ExprKind::Binary: {
                Value a, b;
                if (!eval_to(expr.kids[0], &a, wait_acc)) return false;
                if (expr.op == "&&") {
                    if (!a.truthy()) {
                        *out = Value::make_bool(false);
                        return true;
                    }
                    if (!eval_to(expr.kids[1], &b, wait_acc)) return false;
                    *out = Value::make_bool(b.truthy());
                    return true;
                }
                if (expr.op == "||") {
                    if (a.truthy()) {
                        *out = Value::make_bool(true);
                        return true;
                    }
                    if (!eval_to(expr.kids[1], &b, wait_acc)) return false;
                    *out = Value::make_bool(b.truthy());
                    return true;
                }
                if (!eval_to(expr.kids[1], &b, wait_acc)) return false;
                if (expr.op == "+" || expr.op == "-" || expr.op == "*" || expr.op == "/" ||
                    expr.op == "%") {
                    if (expr.op == "/" && b.as_int() == 0) {
                        fail_at(expr, line_prefix(expr.line) + "除数不能是 0。");
                        return false;
                    }
                    if (expr.op == "%" && b.as_int() == 0) {
                        fail_at(expr, line_prefix(expr.line) + "模的除数不能是 0。");
                        return false;
                    }
                    if ((a.kind == VKind::Real || b.kind == VKind::Real) && expr.op != "%") {
                        const double x = a.as_real(), y = b.as_real();
                        double r = 0;
                        if (expr.op == "+") r = x + y;
                        else if (expr.op == "-") r = x - y;
                        else if (expr.op == "*") r = x * y;
                        else r = x / y;
                        *out = Value::make_real(r);
                        return true;
                    }
                    int64_t r = 0;
                    const int64_t x = a.as_int(), y = b.as_int();
                    if (expr.op == "+") r = x + y;
                    else if (expr.op == "-") r = x - y;
                    else if (expr.op == "*") r = x * y;
                    else if (expr.op == "/") r = x / y;
                    else r = x % y;
                    *out = Value::make_int(r);
                    return true;
                }
                if (expr.op == "==" || expr.op == "!=") {
                    bool eq = false;
                    if (a.kind == VKind::String || b.kind == VKind::String) eq = a.as_str() == b.as_str();
                    else if (a.kind == VKind::Real || b.kind == VKind::Real) eq = a.as_real() == b.as_real();
                    else eq = a.as_int() == b.as_int();
                    *out = Value::make_bool(expr.op == "==" ? eq : !eq);
                    return true;
                }
                const double x = a.as_real(), y = b.as_real();
                bool c = false;
                if (expr.op == "<") c = x < y;
                else if (expr.op == ">") c = x > y;
                else if (expr.op == "<=") c = x <= y;
                else if (expr.op == ">=") c = x >= y;
                *out = Value::make_bool(c);
                return true;
            }
            case ExprKind::Member: {
                Value base;
                if (!eval_to(expr.kids[0], &base, wait_acc)) return false;
                const std::string& m = expr.name;
                if (base.kind == VKind::Cost) {
                    *out = Value::make_int(base.cost.of(m == "hay" ? Item::Hay :
                                                        m == "wood" ? Item::Wood :
                                                        m == "carrot" ? Item::Carrot :
                                                        m == "pumpkin" ? Item::Pumpkin :
                                                        m == "cactus" ? Item::Cactus :
                                                        m == "gold" ? Item::Gold :
                                                        m == "bone" ? Item::Bone :
                                                        m == "weird" ? Item::WeirdSubstance :
                                                        Item::Hay));
                    if (m == "weird") *out = Value::make_int(base.cost.weird);
                    return true;
                }
                if (base.kind == VKind::Measure) {
                    if (m == "ok") *out = Value::make_bool(base.measure.ok);
                    else if (m == "value") *out = Value::make_int(base.measure.value);
                    else if (m == "x") *out = Value::make_int(base.measure.x);
                    else if (m == "y") *out = Value::make_int(base.measure.y);
                    else {
                        fail_at(expr, line_prefix(expr.line) + "Measure 没有成员 “" + m + "”。");
                        return false;
                    }
                    return true;
                }
                if (base.kind == VKind::Companion) {
                    if (m == "ok") *out = Value::make_bool(base.companion.ok);
                    else if (m == "type") {
                        out->kind = VKind::Entity;
                        out->s = entity_type_name(base.companion.type);
                        out->i = static_cast<int>(base.companion.type);
                    } else if (m == "x") *out = Value::make_int(base.companion.x);
                    else if (m == "y") *out = Value::make_int(base.companion.y);
                    else {
                        fail_at(expr, line_prefix(expr.line) + "Companion 没有成员 “" + m + "”。");
                        return false;
                    }
                    return true;
                }
                if (base.obj && base.obj->count(m)) {
                    *out = (*base.obj)[m];
                    return true;
                }
                fail_at(expr, line_prefix(expr.line) + "没有成员 “" + m + "”。");
                return false;
            }
            case ExprKind::Index: {
                Value base, idx;
                if (!eval_to(expr.kids[0], &base, wait_acc)) return false;
                if (!eval_to(expr.kids[1], &idx, wait_acc)) return false;
                if (!base.arr) {
                    fail_at(expr, line_prefix(expr.line) + "只能对数组使用下标。");
                    return false;
                }
                const int64_t i = idx.as_int();
                if (i < 0 || i >= static_cast<int64_t>(base.arr->size())) {
                    fail_at(expr, line_prefix(expr.line) + "数组下标越界：" + std::to_string(i) + "。");
                    return false;
                }
                *out = (*base.arr)[static_cast<std::size_t>(i)];
                return true;
            }
            case ExprKind::Assign: {
                Value rhs;
                if (!eval_to(expr.kids[1], &rhs, wait_acc)) return false;
                Value* slot = lvalue(expr.kids[0]);
                if (!slot) {
                    if (error.empty()) {
                        fail_at(expr, line_prefix(expr.line) + "赋值的左边需要是变量。");
                    }
                    return false;
                }
                if (expr.op == "=") *slot = deep_copy(rhs);
                else {
                    int64_t r = slot->as_int();
                    const int64_t y = rhs.as_int();
                    if (expr.op == "+=") r += y;
                    else if (expr.op == "-=") r -= y;
                    else if (expr.op == "*=") r *= y;
                    else if (expr.op == "/=") {
                        if (y == 0) {
                            fail_at(expr, line_prefix(expr.line) + "除数不能是 0。");
                            return false;
                        }
                        r /= y;
                    }
                    *slot = Value::make_int(r);
                }
                *out = *slot;
                return true;
            }
            default:
                fail("内部错误：未知表达式。");
                return false;
        }
    }

    Value* lvalue(const Expr& expr) {
        if (expr.kind == ExprKind::Ident) {
            if (Value* v = lookup(expr.name)) return v->ref ? v->ref : v;
            return nullptr;
        }
        if (expr.kind == ExprKind::Index) {
            // Need the actual slot in the variable's array, not a copy.
            Value* container = lvalue(expr.kids[0]);
            if (!container) return nullptr;
            Value idx;
            int64_t dummy = 0;
            if (!eval_to(expr.kids[1], &idx, &dummy)) return nullptr;
            if (!container || !container->arr) return nullptr;
            const int64_t i = idx.as_int();
            if (i < 0 || i >= static_cast<int64_t>(container->arr->size())) {
                fail_at(expr, line_prefix(expr.line) + "数组下标越界：" + std::to_string(i) + "。");
                return nullptr;
            }
            return &(*container->arr)[static_cast<std::size_t>(i)];
        }
        if (expr.kind == ExprKind::Member) {
            Value* base = lvalue(expr.kids[0]);
            if (base && base->obj) {
                return &(*base->obj)[expr.name];
            }
        }
        return nullptr;
    }

    bool arg_ident(const Expr& call, std::size_t i, std::string* name) const {
        if (i < call.kids.size() && call.kids[i].kind == ExprKind::Ident) {
            *name = call.kids[i].name;
            return true;
        }
        if (i == 0 && !call.arg.empty()) {
            *name = call.arg;
            return true;
        }
        return false;
    }

    bool eval_arg(const Expr& call, std::size_t i, Value* out, int64_t* wait_acc) {
        if (i >= call.kids.size()) {
            fail_at(call, line_prefix(call.line) + "参数数量不对。");
            return false;
        }
        return eval_to(call.kids[i], out, wait_acc);
    }

    void result_from_action(const ActionResult& ar, Value* out) {
        if (ar.measure.ok || ar.measure.value != 0 || ar.measure.x != 0) {
            out->kind = VKind::Measure;
            out->measure = ar.measure;
            out->i = ar.measure.value;
            out->b = ar.measure.ok;
            return;
        }
        if (ar.companion.ok) {
            out->kind = VKind::Companion;
            out->companion = ar.companion;
            out->b = true;
            return;
        }
        if (!ar.cost.is_zero() || ar.value.empty()) {
            // fall through; costs often zero for bush
        }
        // Prefer structured cost if any field set or caller used get_cost.
        out->kind = VKind::Int;
        out->i = ar.number;
        out->d = ar.real;
        out->s = ar.value;
        out->b = ar.success;
        if (ar.real != 0 && ar.number == 0) {
            out->kind = VKind::Real;
        }
    }

    bool call_any(const Expr& expr, Value* out, ActionResult* ar, ActionKind* kind) {
        if (!world) {
            fail("内部错误：模拟世界尚未绑定。");
            return false;
        }
        const std::string& name = expr.name;
        const int line = expr.line;
        auto no_args = [&]() {
            if (!expr.kids.empty() || !expr.arg.empty()) {
                fail_at(expr, line_prefix(line) + name + "() 不需要参数。");
                return false;
            }
            return true;
        };
        world->set_active_drone(active_drone);

        if (name == "harvest") {
            if (!no_args()) return false;
            *kind = ActionKind::Harvest;
            *ar = world->try_harvest();
            *out = Value::make_bool(ar->success);
            out->s = ar->value;
            return true;
        }
        if (name == "can_harvest") {
            if (!no_args()) return false;
            *kind = ActionKind::CanHarvest;
            *ar = world->try_can_harvest();
            *out = Value::make_bool(ar->success);
            out->s = ar->value;
            return true;
        }
        if (name == "do_a_flip") {
            if (!no_args()) return false;
            *kind = ActionKind::Flip;
            *ar = world->try_flip();
            *out = Value::make_bool(true);
            return true;
        }
        if (name == "move" || name == "can_move" || name == "swap" || name == "measure") {
            Dir dir = Dir::East;
            bool has_dir = false;
            if (name == "measure" && expr.kids.empty() && expr.arg.empty()) {
                *kind = ActionKind::Measure;
                *ar = world->try_measure();
                out->kind = VKind::Measure;
                out->measure = ar->measure;
                out->i = ar->measure.value;
                out->b = ar->measure.ok;
                return true;
            }
            std::string an;
            if (arg_ident(expr, 0, &an) && dir_from_name(an, &dir)) {
                has_dir = true;
            } else if (!expr.kids.empty()) {
                Value v;
                if (!arg_value(expr, 0, &v)) return false;
                if (!dir_from_name(v.s, &dir)) dir = static_cast<Dir>(v.as_int() & 3);
                has_dir = true;
            }
            if (name == "move") {
                if (!has_dir) {
                    fail_at(expr, line_prefix(line) + "move() 需要方向参数，例如 move(East)。");
                    return false;
                }
                *kind = ActionKind::Move;
                *ar = world->try_move(dir);
                *out = Value::make_bool(ar->success);
                return true;
            }
            if (name == "can_move") {
                if (!has_dir) {
                    fail_at(expr, line_prefix(line) + "can_move() 需要方向参数。");
                    return false;
                }
                *kind = ActionKind::CanMove;
                *ar = world->try_can_move(dir);
                *out = Value::make_bool(ar->success);
                return true;
            }
            if (name == "swap") {
                if (!has_dir) {
                    fail_at(expr, line_prefix(line) + "swap() 需要方向参数。");
                    return false;
                }
                *kind = ActionKind::Swap;
                *ar = world->try_swap(dir);
                *out = Value::make_bool(ar->success);
                return true;
            }
            if (name == "measure") {
                *kind = ActionKind::Measure;
                *ar = has_dir ? world->try_measure_dir(dir) : world->try_measure();
                out->kind = VKind::Measure;
                out->measure = ar->measure;
                out->i = ar->measure.value;
                out->b = ar->measure.ok;
                return true;
            }
        }
        if (name == "till") {
            if (!no_args()) return false;
            *kind = ActionKind::Till;
            *ar = world->try_till();
            *out = Value::make_bool(ar->success);
            out->s = ar->value;
            return true;
        }
        if (name == "plant") {
            std::string an;
            EntityType entity = EntityType::None;
            if (!arg_ident(expr, 0, &an) || !entity_from_name(an, &entity)) {
                if (!expr.kids.empty()) {
                    Value v;
                    if (!arg_value(expr, 0, &v)) return false;
                    if (!entity_from_name(v.s, &entity)) entity = static_cast<EntityType>(v.as_int());
                } else {
                    fail_at(expr, line_prefix(line) + "plant() 需要作物参数，例如 plant(Bush)。");
                    return false;
                }
            }
            *kind = ActionKind::Plant;
            *ar = world->try_plant(entity);
            *out = Value::make_bool(ar->success);
            return true;
        }
        if (name == "get_entity_type") {
            if (!no_args()) return false;
            *kind = ActionKind::GetEntity;
            *ar = world->try_get_entity_type();
            out->kind = VKind::Entity;
            out->s = ar->value;
            EntityType e;
            if (entity_from_name(ar->value, &e)) out->i = static_cast<int>(e);
            out->b = ar->success;
            return true;
        }
        if (name == "get_ground_type") {
            if (!no_args()) return false;
            *kind = ActionKind::GetGround;
            *ar = world->try_get_ground_type();
            out->kind = VKind::Ground;
            out->s = ar->value;
            GroundType g;
            if (ground_from_name(ar->value, &g)) out->i = static_cast<int>(g);
            out->b = ar->success;
            return true;
        }
        if (name == "get_pos_x") {
            if (!no_args()) return false;
            *kind = ActionKind::GetPos;
            *ar = world->try_get_pos_x();
            *out = Value::make_int(ar->number);
            return true;
        }
        if (name == "get_pos_y") {
            if (!no_args()) return false;
            *kind = ActionKind::GetPos;
            *ar = world->try_get_pos_y();
            *out = Value::make_int(ar->number);
            return true;
        }
        if (name == "get_world_size") {
            if (!no_args()) return false;
            *kind = ActionKind::GetWorldSize;
            *ar = world->try_get_world_size();
            *out = Value::make_int(ar->number);
            return true;
        }
        if (name == "num_items") {
            Item it = Item::Hay;
            std::string an;
            if (arg_ident(expr, 0, &an)) {
                if (!item_from_name(an, &it)) {
                    fail_at(expr, line_prefix(line) + "未知物品 “" + an + "”。");
                    return false;
                }
            } else if (!expr.kids.empty()) {
                Value v;
                if (!arg_value(expr, 0, &v)) return false;
                if (!item_from_name(v.s, &it)) it = static_cast<Item>(v.as_int());
            } else {
                fail_at(expr, line_prefix(line) + "num_items() 需要物品参数。");
                return false;
            }
            *kind = ActionKind::NumItems;
            *ar = world->try_num_items(it);
            *out = Value::make_int(ar->number);
            return true;
        }
        if (name == "num_unlocked") {
            UnlockId id = UnlockId::Loops;
            std::string an;
            if (arg_ident(expr, 0, &an)) {
                if (!unlock_id_from_name(an, &id)) {
                    fail_at(expr, line_prefix(line) + "未知解锁 “" + an + "”。");
                    return false;
                }
            } else {
                fail_at(expr, line_prefix(line) + "num_unlocked() 需要解锁参数。");
                return false;
            }
            *kind = ActionKind::NumUnlocked;
            *ar = world->try_num_unlocked(id);
            *out = Value::make_int(ar->number);
            return true;
        }
        if (name == "get_cost") {
            *kind = ActionKind::GetCost;
            std::string an;
            if (arg_ident(expr, 0, &an)) {
                EntityType e;
                UnlockId u;
                if (entity_from_name(an, &e)) *ar = world->try_get_cost_entity(e);
                else if (unlock_id_from_name(an, &u)) *ar = world->try_get_cost_unlock(u);
                else {
                    fail_at(expr, line_prefix(line) + "get_cost() 需要实体或解锁名。");
                    return false;
                }
            } else {
                fail_at(expr, line_prefix(line) + "get_cost() 需要参数。");
                return false;
            }
            out->kind = VKind::Cost;
            out->cost = ar->cost;
            return true;
        }
        if (name == "use_item") {
            Item it = Item::Water;
            int n = 1;
            std::string an;
            if (arg_ident(expr, 0, &an)) {
                if (!item_from_name(an, &it)) {
                    fail_at(expr, line_prefix(line) + "未知物品 “" + an + "”。");
                    return false;
                }
            } else {
                fail_at(expr, line_prefix(line) + "use_item() 需要物品参数。");
                return false;
            }
            if (expr.kids.size() >= 2) {
                Value v;
                if (!arg_value(expr, 1, &v)) return false;
                n = static_cast<int>(v.as_int());
            }
            *kind = ActionKind::UseItem;
            *ar = world->try_use_item(it, n);
            *out = Value::make_bool(ar->success);
            return true;
        }
        if (name == "get_water") {
            if (!no_args()) return false;
            *kind = ActionKind::GetWater;
            *ar = world->try_get_water();
            *out = Value::make_real(ar->real);
            return true;
        }
        if (name == "get_companion") {
            if (!no_args()) return false;
            *kind = ActionKind::GetCompanion;
            *ar = world->try_get_companion();
            out->kind = VKind::Companion;
            out->companion = ar->companion;
            out->b = ar->companion.ok;
            return true;
        }
        if (name == "change_hat") {
            Hat hat = Hat::StrawHat;
            std::string an;
            if (!arg_ident(expr, 0, &an) || !hat_from_name(an, &hat)) {
                fail_at(expr, line_prefix(line) + "change_hat() 需要帽子参数。");
                return false;
            }
            *kind = ActionKind::ChangeHat;
            *ar = world->try_change_hat(hat);
            *out = Value::make_bool(ar->success);
            return true;
        }
        if (name == "clear") {
            if (!no_args()) return false;
            *kind = ActionKind::Clear;
            *ar = world->try_clear();
            *out = Value::make_bool(true);
            return true;
        }
        if (name == "unlock") {
            UnlockId id = UnlockId::Loops;
            std::string an;
            if (!arg_ident(expr, 0, &an) || !unlock_id_from_name(an, &id)) {
                fail_at(expr, line_prefix(line) + "unlock() 需要解锁名。");
                return false;
            }
            *kind = ActionKind::Unlock;
            *ar = world->try_unlock_api(id);
            *out = Value::make_bool(ar->success);
            return true;
        }
        if (name == "quick_print" || name == "print" || name == "print_slow") {
            std::string text;
            if (!expr.kids.empty()) {
                Value v;
                if (!arg_value(expr, 0, &v)) return false;
                text = v.as_str();
            }
            if (name == "quick_print") {
                *kind = ActionKind::QuickPrint;
                *ar = world->try_quick_print(text);
            } else {
                *kind = ActionKind::Print;
                world->try_quick_print(text);
                *ar = world->try_print_slow();
            }
            *out = Value::make_bool(true);
            return true;
        }
        if (name == "get_time") {
            if (!no_args()) return false;
            *kind = ActionKind::GetTime;
            *ar = world->try_get_time();
            *out = Value::make_real(ar->real);
            return true;
        }
        if (name == "get_tick_count") {
            if (!no_args()) return false;
            *kind = ActionKind::GetTime;
            *ar = world->try_get_tick_count();
            *out = Value::make_int(ar->number);
            return true;
        }
        if (name == "set_world_size") {
            Value v;
            if (expr.kids.empty() || !arg_value(expr, 0, &v)) {
                fail_at(expr, line_prefix(line) + "set_world_size() 需要边长。");
                return false;
            }
            *kind = ActionKind::SetWorldSize;
            *ar = world->try_set_world_size(static_cast<int>(v.as_int()));
            *out = Value::make_bool(ar->success);
            return true;
        }
        if (name == "set_execution_speed") {
            Value v;
            if (expr.kids.empty() || !arg_value(expr, 0, &v)) {
                fail_at(expr, line_prefix(line) + "set_execution_speed() 需要速度。");
                return false;
            }
            *kind = ActionKind::SetSpeed;
            *ar = world->try_set_execution_speed(v.as_real());
            *out = Value::make_bool(ar->success);
            return true;
        }
        if (name == "simulate") {
            Value seedv;
            if (expr.kids.empty() || !arg_value(expr, 0, &seedv)) {
                fail_at(expr, line_prefix(line) + "simulate() 需要种子。");
                return false;
            }
            double speed = 0.0;
            if (expr.kids.size() >= 2) {
                Value sp;
                if (!arg_value(expr, 1, &sp)) return false;
                speed = sp.as_real();
            }
            *kind = ActionKind::Simulate;
            *ar = world->try_simulate(static_cast<uint64_t>(seedv.as_int()), speed);
            *out = Value::make_int(ar->number);
            return true;
        }
        if (name == "random01") {
            if (!no_args()) return false;
            *kind = ActionKind::MinMax;
            *ar = world->try_random01();
            *out = Value::make_real(ar->real);
            return true;
        }
        if (name == "min" || name == "max" || name == "abs" || name == "std::min" ||
            name == "std::max" || name == "std::abs") {
            *kind = ActionKind::MinMax;
            ar->ticks = kFailOrQueryTicks;
            ar->success = true;
            if (name == "abs" || name == "std::abs") {
                Value v;
                if (expr.kids.empty() || !arg_value(expr, 0, &v)) return false;
                *out = Value::make_int(std::llabs(v.as_int()));
                return true;
            }
            Value a, b;
            if (expr.kids.size() < 2 || !arg_value(expr, 0, &a) ||
                !arg_value(expr, 1, &b)) {
                fail_at(expr, line_prefix(line) + "min/max 需要两个参数。");
                return false;
            }
            const int64_t x = a.as_int(), y = b.as_int();
            *out = Value::make_int((name.find("min") != std::string::npos) ? std::min(x, y) : std::max(x, y));
            return true;
        }
        if (name == "num_drones") {
            *kind = ActionKind::SpawnDrone;
            ar->ticks = kFailOrQueryTicks;
            int alive = 1;
            for (const auto& d : drones) {
                if (d.id > 0 && d.running && !d.finished) ++alive;
            }
            *out = Value::make_int(alive);
            return true;
        }
        if (name == "max_drones") {
            *kind = ActionKind::SpawnDrone;
            ar->ticks = kFailOrQueryTicks;
            *out = Value::make_int(world->max_drones());
            return true;
        }
        if (name == "has_finished") {
            Value v;
            if (expr.kids.empty() || !arg_value(expr, 0, &v)) {
                fail_at(expr, line_prefix(line) + "has_finished() 需要无人机句柄。");
                return false;
            }
            const int id = static_cast<int>(v.as_int());
            *kind = ActionKind::HasFinished;
            ar->ticks = kFailOrQueryTicks;
            bool done = true;
            if (id >= 0 && id < static_cast<int>(drones.size())) {
                done = drones[static_cast<std::size_t>(id)].finished || !drones[static_cast<std::size_t>(id)].running;
            }
            *out = Value::make_bool(done);
            return true;
        }
        if (name == "wait_for") {
            Value v;
            if (expr.kids.empty() || !arg_value(expr, 0, &v)) {
                fail_at(expr, line_prefix(line) + "wait_for() 需要无人机句柄。");
                return false;
            }
            const int id = static_cast<int>(v.as_int());
            *kind = ActionKind::WaitFor;
            if (id >= 0 && id < static_cast<int>(drones.size()) &&
                !drones[static_cast<std::size_t>(id)].finished) {
                // Wait one query tick, then the statement retries until the child is done.
                ar->ticks = kFailOrQueryTicks;
                ar->success = false;
                retry_call = true;
                out->i = id;
                out->kind = VKind::Int;
                return true;
            }
            ar->ticks = kFailOrQueryTicks;
            ar->success = true;
            int64_t ret = 0;
            if (id >= 0 && id < static_cast<int>(drones.size())) ret = drones[static_cast<std::size_t>(id)].ret_i;
            *out = Value::make_int(ret);
            return true;
        }
        if (name == "spawn_drone") {
            *kind = ActionKind::SpawnDrone;
            if (static_cast<int>(drones.size()) >= world->max_drones()) {
                ar->ticks = kFailOrQueryTicks;
                ar->success = false;
                *out = Value::make_int(-1);
                return true;
            }
            std::string fn;
            if (!arg_ident(expr, 0, &fn)) {
                fail_at(expr, line_prefix(line) + "spawn_drone() 需要函数名。");
                return false;
            }
            if (!functions.count(fn)) {
                fail_at(expr, line_prefix(line) + "找不到函数 “" + fn + "”。");
                return false;
            }
            Value argv = Value::make_int(0);
            bool has_arg = false;
            if (expr.kids.size() >= 2) {
                if (!arg_value(expr, 1, &argv)) return false;
                has_arg = true;
            }
            const int id = spawn_child(fn, has_arg, argv);
            ar->ticks = world->action_ticks();
            ar->success = id >= 0;
            *out = Value::make_int(id);
            return true;
        }
        std::string hint = "可以使用 harvest() 或 do_a_flip()。";
        fail_at(expr, line_prefix(line) + "未知函数 “" + name + "()”。" + hint);
        return false;
    }

    int spawn_child(const std::string& fn, bool has_arg, const Value& argv) {
        if (drones.empty()) {
            // Promote the main execution to drone 0 if we haven't already.
            DroneExec main_d;
            main_d.id = 0;
            main_d.running = false;  // main uses the top-level frame stack
            main_d.finished = true;
            main_d.started = true;
            drones.push_back(std::move(main_d));
        }
        DroneExec child;
        child.id = world ? world->register_drone() : static_cast<int>(drones.size());
        if (child.id < static_cast<int>(drones.size())) {
            // Should not happen; keep ids dense.
            child.id = static_cast<int>(drones.size());
        }
        child.running = true;
        child.started = true;
        auto e = std::make_shared<Env>();
        const FunctionDef& def = functions[fn];
        if (has_arg && !def.params.empty()) {
            e->define(def.params[0].name, deep_copy(argv));  // by value: no shared memory
        }
        child.env = e.get();
        Frame root = make_frame(&def.body, FrameKind::Fn);
        root.fn_name = fn;
        root.own_env = e;
        child.frames.push_back(std::move(root));
        const int id = child.id;
        drones.push_back(std::move(child));
        return id;
    }

    // ---- statement execution with suspend / replay ----------------------
    //
    // Every farm action and every user function call suspends the current
    // statement. The statement's frame keeps a memo of the call results it
    // has already produced; when execution resumes, the statement is
    // evaluated again from the start and replays those results instead of
    // repeating the side effects. That gives each action its own start tick
    // (effects land at the right time) and lets function bodies yield like
    // main does, including infinite loops inside functions and drones.

    static constexpr int kMaxInstantSteps = 1000000;

    Value last_ret_value = Value::make_int(0);
    int64_t last_fn_ret = 0;
    std::size_t memo_frame = static_cast<std::size_t>(-1);
    std::size_t memo_pos = 0;
    bool suspended = false;
    bool retry_call = false;
    const std::vector<Value>* cur_args = nullptr;

    static Value deep_copy(const Value& v) {
        if (v.kind == VKind::Object && v.obj) {
            Value c = v;
            c.obj = std::make_shared<std::map<std::string, Value>>();
            for (const auto& kv : *v.obj) (*c.obj)[kv.first] = deep_copy(kv.second);
            return c;
        }
        return v;
    }

    std::vector<Value>* cur_memo() {
        if (memo_frame < frames.size()) return &frames[memo_frame].memo;
        return nullptr;
    }

    void begin_stmt() {
        memo_frame = frames.empty() ? static_cast<std::size_t>(-1) : frames.size() - 1;
        memo_pos = 0;
        suspended = false;
    }

    void wait_event(int line, ActionKind kind, int64_t ticks, bool success) {
        ExecEvent ev;
        ev.line = line;
        ev.start_tick = world->tick();
        ev.duration_ticks = ticks;
        ev.kind = kind;
        ev.success = success;
        begin_wait(ev);
    }

    bool arg_value(const Expr& call, std::size_t i, Value* out) {
        if (cur_args && i < cur_args->size()) {
            const Value& v = (*cur_args)[i];
            if (v.kind == VKind::None) {
                fail_at(call.kids[i], line_prefix(call.kids[i].line) + "未知的名字 “" + call.kids[i].name + "”。");
                return false;
            }
            *out = v;
            return true;
        }
        if (i >= call.kids.size()) {
            fail_at(call, line_prefix(call.line) + "参数数量不对。");
            return false;
        }
        int64_t acc = 0;
        return eval_to(call.kids[i], out, &acc);
    }

    // Evaluate call arguments left to right. Bare identifiers that are not
    // values (function names for spawn_drone) become VKind::None markers.
    bool eval_args(const Expr& call, const FunctionDef* def, std::vector<Value>* argv) {
        argv->clear();
        for (std::size_t i = 0; i < call.kids.size(); ++i) {
            const Expr& k = call.kids[i];
            Value v;
            if (def && i < def->params.size() && def->params[i].is_ref) {
                v.kind = VKind::None;
            } else if (k.kind == ExprKind::Ident) {
                if (!ident_value(k.name, &v)) {
                    v = Value{};
                    v.kind = VKind::None;
                }
            } else {
                int64_t acc = 0;
                if (!eval_to(k, &v, &acc)) return false;
            }
            argv->push_back(v);
        }
        return true;
    }

    bool eval_call(const Expr& expr, Value* out) {
        const auto fit = functions.find(expr.name);
        const FunctionDef* def = fit == functions.end() ? nullptr : &fit->second;
        std::vector<Value> argv;
        if (!eval_args(expr, def, &argv)) return false;
        std::vector<Value>* memo = cur_memo();
        if (memo && memo_pos < memo->size()) {
            *out = (*memo)[memo_pos++];
            return true;
        }
        if (def) return begin_user_call(expr, *def, argv);
        ActionResult ar;
        ActionKind kind = ActionKind::None;
        retry_call = false;
        cur_args = &argv;
        const bool ok = call_any(expr, out, &ar, &kind);
        cur_args = nullptr;
        if (!ok) return false;
        if (retry_call) {
            retry_call = false;
            wait_event(expr.line, kind, kFailOrQueryTicks, false);
            suspended = true;
            return false;
        }
        if (memo) {
            memo->push_back(*out);
            memo_pos = memo->size();
        }
        if (ar.ticks > 0) {
            wait_event(expr.line, kind, ar.ticks, ar.success);
            suspended = true;
            return false;
        }
        return true;
    }

    bool begin_user_call(const Expr& expr, const FunctionDef& def, const std::vector<Value>& argv) {
        if (frames.size() > 4000) {
            fail_at(expr, line_prefix(expr.line) + "函数调用嵌套太深（可能是无限递归）。");
            return false;
        }
        auto e = std::make_shared<Env>();
        for (std::size_t i = 0; i < def.params.size(); ++i) {
            const FunctionParam& prm = def.params[i];
            if (i >= expr.kids.size()) {
                e->define(prm.name, Value::make_int(0));
                continue;
            }
            if (prm.is_ref) {
                Value* slot = lvalue(expr.kids[i]);
                if (!slot) {
                    if (error.empty()) fail_at(expr, line_prefix(expr.line) + "引用参数需要变量。");
                    return false;
                }
                Value box;
                box.ref = slot;
                box.kind = slot->kind;
                e->define(prm.name, box);
                continue;
            }
            e->define(prm.name, deep_copy(argv[i]));
        }
        Frame f = make_frame(&def.body, FrameKind::Fn);
        f.fn_name = def.name;
        f.own_env = e;
        f.restore_env = env;
        env = e.get();
        frames.push_back(std::move(f));
        suspended = true;
        return false;
    }

    // Pop through the innermost function frame and hand `ret` to the caller's
    // statement memo so it resumes with the returned value.
    void finish_fn(const Value& ret) {
        while (!frames.empty()) {
            const bool is_fn = frames.back().fkind == FrameKind::Fn;
            Env* restore = frames.back().restore_env;
            frames.pop_back();
            if (is_fn) {
                env = restore;
                break;
            }
        }
        last_ret_value = ret;
        last_fn_ret = ret.as_int();
        if (!frames.empty()) frames.back().memo.push_back(ret);
    }

    bool in_function() const {
        for (auto it = frames.rbegin(); it != frames.rend(); ++it) {
            if (it->fkind == FrameKind::Fn) return true;
        }
        return false;
    }

    void finish_stmt(std::size_t fi) {
        frames[fi].memo.clear();
        frames[fi].index++;
    }

    void exec_next() {
        if (!error.empty()) return;
        if (frames.empty()) {
            running = false;
            finished = true;
            has_current = false;
            if (world) world->restore_world_size_if_needed();
            return;
        }
        const std::size_t fi = frames.size() - 1;
        if (frames[fi].index >= frames[fi].body->size()) {
            if (frames[fi].fkind == FrameKind::Fn) {
                finish_fn(Value::make_int(0));
            } else {
                frames.pop_back();
            }
            return;
        }
        const Stmt& stmt = (*frames[fi].body)[frames[fi].index];
        begin_stmt();
        switch (stmt.kind) {
            case StmtKind::ExprStmt: {
                Value unused;
                int64_t d = 0;
                if (!eval_to(stmt.expr, &unused, &d)) return;
                finish_stmt(fi);
                return;
            }
            case StmtKind::VarDecl: {
                int64_t d = 0;
                std::vector<int> dims;
                for (const auto& de : stmt.array_dim_exprs) {
                    Value dv;
                    if (!eval_to(de, &dv, &d)) return;
                    const int64_t n = dv.as_int();
                    if (n <= 0 || n > 4096) {
                        fail_at(de, line_prefix(stmt.line) + "数组大小需要是 1 到 4096 之间的整数。");
                        return;
                    }
                    dims.push_back(static_cast<int>(n));
                }
                Value v = Value::make_int(0);
                if (stmt.has_init) {
                    if (!eval_to(stmt.init, &v, &d)) return;
                }
                Value slot;
                if (!dims.empty()) {
                    slot = make_array(dims, 0, stmt.var_type);
                    if (stmt.has_init && v.arr) fill_array(&slot, v);
                } else if (structs.count(stmt.var_type)) {
                    slot = stmt.has_init ? deep_copy(v) : make_leaf_for_type(stmt.var_type);
                } else {
                    slot = deep_copy(v);
                }
                const bool file_scope = frames.size() == 1 && frames[0].body == program.get();
                if (env && !(stmt.var_const && file_scope)) env->define(stmt.var_name, slot);
                else globals.define(stmt.var_name, slot);
                finish_stmt(fi);
                return;
            }
            case StmtKind::While: {
                if (!world->loops_unlocked()) {
                    fail(line_prefix(stmt.line) + "循环尚未解锁。到技能树花 5 个干草即可使用 while。",
                         stmt.span, ErrorKind::LockedSyntax, "到技能树花 5 个干草解锁", "while");
                    return;
                }
                bool truthy = false;
                if (stmt.expr.kind == ExprKind::LiteralTrue || stmt.expr.kind == ExprKind::LiteralFalse) {
                    truthy = stmt.expr.kind == ExprKind::LiteralTrue;
                    wait_event(stmt.line, ActionKind::WhileCheck, kFailOrQueryTicks, truthy);
                } else {
                    Value v;
                    int64_t d = 0;
                    if (!eval_to(stmt.expr, &v, &d)) return;
                    truthy = v.truthy();
                }
                frames[fi].memo.clear();
                if (truthy) frames.push_back(make_frame(&stmt.body, FrameKind::Loop));
                else frames[fi].index++;
                return;
            }
            case StmtKind::For: {
                if (!world->for_unlocked()) {
                    fail(line_prefix(stmt.line) + "for 循环尚未解锁。到技能树花 30 个干草即可使用 for。",
                         stmt.span, ErrorKind::LockedSyntax, "到技能树花 30 个干草解锁", "for");
                    return;
                }
                if (frames[fi].for_stmt_index != frames[fi].index) {
                    frames[fi].for_started = false;
                    frames[fi].for_phase = 0;
                    frames[fi].for_stmt_index = frames[fi].index;
                    frames[fi].for_name = stmt.for_name;
                    frames[fi].memo.clear();
                }
                int64_t d = 0;
                if (frames[fi].for_phase == 0) {
                    if (!frames[fi].for_started) {
                        int start = stmt.for_start;
                        if (stmt.for_start_is_expr) {
                            Value sv;
                            if (!eval_to(stmt.for_start_expr, &sv, &d)) return;
                            start = static_cast<int>(sv.as_int());
                        }
                        frames[fi].for_i = start;
                        frames[fi].for_started = true;
                    } else {
                        frames[fi].for_i += 1;
                    }
                    frames[fi].for_phase = 1;
                    frames[fi].memo.clear();
                    memo_pos = 0;
                }
                int end = stmt.for_end;
                if (stmt.for_end_is_expr) {
                    Value ev;
                    if (!eval_to(stmt.for_end_expr, &ev, &d)) return;
                    end = static_cast<int>(ev.as_int());
                    if (stmt.for_le) end += 1;
                }
                Frame& f = frames[fi];
                f.memo.clear();
                f.for_phase = 0;
                const bool truthy = f.for_i < end;
                wait_event(stmt.line, ActionKind::ForCheck, kFailOrQueryTicks, truthy);
                if (truthy) {
                    if (world->variables_unlocked() && env) {
                        env->define(stmt.for_name, Value::make_int(f.for_i));
                    }
                    frames.push_back(make_frame(&stmt.body, FrameKind::Loop));
                } else {
                    f.index++;
                    f.for_started = false;
                    f.for_stmt_index = static_cast<std::size_t>(-1);
                }
                return;
            }
            case StmtKind::If: {
                bool truthy = false;
                if (stmt.expr.kind == ExprKind::LiteralTrue || stmt.expr.kind == ExprKind::LiteralFalse) {
                    truthy = stmt.expr.kind == ExprKind::LiteralTrue;
                    wait_event(stmt.line, ActionKind::IfCheck, kFailOrQueryTicks, truthy);
                } else {
                    Value v;
                    int64_t d = 0;
                    if (!eval_to(stmt.expr, &v, &d)) return;
                    truthy = v.truthy();
                }
                finish_stmt(fi);
                if (truthy) {
                    if (!stmt.body.empty()) frames.push_back(make_frame(&stmt.body));
                } else if (!stmt.else_body.empty()) {
                    frames.push_back(make_frame(&stmt.else_body));
                }
                return;
            }
            case StmtKind::Switch: {
                Value v;
                int64_t d = 0;
                if (!eval_to(stmt.expr, &v, &d)) return;
                const std::string key = v.s.empty() ? std::to_string(v.as_int()) : v.s;
                const std::vector<Stmt>* chosen = nullptr;
                const std::vector<Stmt>* def = nullptr;
                for (const auto& c : stmt.cases) {
                    if (c.is_default && !def) def = &c.body;
                    for (const auto& lb : c.labels) {
                        if (!chosen && (lb == key || lb == v.as_str())) chosen = &c.body;
                    }
                }
                finish_stmt(fi);
                if (!chosen) chosen = def;
                if (chosen && !chosen->empty()) frames.push_back(make_frame(chosen, FrameKind::Switch));
                return;
            }
            case StmtKind::Break: {
                while (!frames.empty()) {
                    const FrameKind k = frames.back().fkind;
                    if (k == FrameKind::Fn) {
                        fail(line_prefix(stmt.line) + "break 只能写在循环或 switch 里。");
                        return;
                    }
                    frames.pop_back();
                    if (k == FrameKind::Switch) return;
                    if (k == FrameKind::Loop) {
                        if (!frames.empty()) {
                            Frame& p = frames.back();
                            p.index++;
                            p.for_started = false;
                            p.for_phase = 0;
                            p.for_stmt_index = static_cast<std::size_t>(-1);
                            p.memo.clear();
                        }
                        return;
                    }
                }
                return;
            }
            case StmtKind::Continue: {
                while (!frames.empty()) {
                    const FrameKind k = frames.back().fkind;
                    if (k == FrameKind::Fn) {
                        fail(line_prefix(stmt.line) + "continue 只能写在循环里。");
                        return;
                    }
                    frames.pop_back();
                    if (k == FrameKind::Loop) return;
                }
                return;
            }
            case StmtKind::Return: {
                Value rv = Value::make_int(0);
                if (stmt.has_init) {
                    int64_t d = 0;
                    if (!eval_to(stmt.expr, &rv, &d)) return;
                }
                if (in_function()) {
                    finish_fn(deep_copy(rv));
                    return;
                }
                last_fn_ret = rv.as_int();
                frames.clear();
                running = false;
                finished = true;
                has_current = false;
                wait_remaining = 0;
                if (world) world->restore_world_size_if_needed();
                return;
            }
            case StmtKind::Block:
                finish_stmt(fi);
                if (!stmt.body.empty()) frames.push_back(make_frame(&stmt.body));
                return;
        }
    }

    // Copy an initializer list into a freshly made array (row by row).
    void fill_array(Value* dst, const Value& src) {
        if (!dst->arr || !src.arr) return;
        const std::size_t n = std::min(dst->arr->size(), src.arr->size());
        for (std::size_t i = 0; i < n; ++i) {
            Value& d = (*dst->arr)[i];
            const Value& s = (*src.arr)[i];
            if (d.arr && s.arr) fill_array(&d, s);
            else d = deep_copy(s);
        }
    }

    Value make_leaf_for_type(const std::string& type) {
        if (structs.count(type)) {
            Value obj;
            obj.kind = VKind::Object;
            obj.obj = std::make_shared<std::map<std::string, Value>>();
            for (const auto& f : structs[type].fields) {
                (*obj.obj)[f.second] = Value::make_int(0);
            }
            return obj;
        }
        return Value::make_int(0);
    }
    Value make_array(const std::vector<int>& dims, std::size_t di, const std::string& type) {
        Value v;
        v.kind = VKind::Array;
        v.arr = std::make_shared<std::vector<Value>>();
        if (di >= dims.size()) return v;
        const int n = dims[di];
        v.arr->resize(static_cast<std::size_t>(n));
        if (di + 1 < dims.size()) {
            for (int i = 0; i < n; ++i) (*v.arr)[static_cast<std::size_t>(i)] = make_array(dims, di + 1, type);
        } else {
            for (int i = 0; i < n; ++i) (*v.arr)[static_cast<std::size_t>(i)] = make_leaf_for_type(type);
        }
        return v;
    }

    bool any_child_running() const {
        for (const auto& d : drones) {
            if (d.running && !d.finished) return true;
        }
        return false;
    }

    void pump_children() {
        const int saved = active_drone;
        for (std::size_t i = 0; i < drones.size(); ++i) {
            DroneExec& d = drones[i];
            if (!d.running || d.finished || d.wait_remaining > 0) continue;
            active_drone = d.id;
            world->set_active_drone(d.id);
            // Swap into this drone's stacks.
            std::swap(frames, d.frames);
            std::swap(env, d.env);
            const int64_t wr = wait_remaining;
            wait_remaining = 0;
            const bool was_finished = finished;
            finished = false;
            running = true;
            exec_next();
            d.wait_remaining = wait_remaining;
            d.current = current;
            d.has_current = has_current;
            d.frames.swap(frames);
            d.env = env;
            env = nullptr;
            // restore main
            std::swap(frames, d.frames);
            // Wait, we swapped d.frames into frames at the end of swap twice...
            // After exec, `frames` is the drone's (possibly updated). We want
            // to store that back into d.frames and restore main frames.
            // Let's do it clearly:
            // (abandoned; see fixed block below — this function is rewritten after concat if tests fail)
            wait_remaining = wr;
            finished = was_finished;
            running = true;
            if (d.frames.empty() && d.wait_remaining == 0) {
                d.finished = true;
                d.running = false;
                d.ret_i = last_fn_ret;
            }
        }
        active_drone = saved;
        if (world) world->set_active_drone(saved);
    }

    void advance(int64_t ticks) {
        if ((!running && !any_child_running()) || !error.empty() || ticks < 0) return;
        int steps = 0;
        while ((running || any_child_running()) && error.empty() && !finished) {
            // Pump children that are ready (no wait) so they can start actions.
            pump_children_fixed();
            int64_t min_wait = -1;
            if (running && wait_remaining > 0) min_wait = wait_remaining;
            for (auto& d : drones) {
                if (d.running && !d.finished && d.wait_remaining > 0) {
                    if (min_wait < 0 || d.wait_remaining < min_wait) min_wait = d.wait_remaining;
                }
            }
            const bool main_ready = running && !finished && wait_remaining == 0;
            bool child_ready = false;
            for (auto& d : drones) {
                if (d.running && !d.finished && d.wait_remaining == 0) child_ready = true;
            }
            if (!main_ready && !child_ready && min_wait > 0) {
                if (ticks <= 0) return;
                const int64_t step = std::min(ticks, min_wait);
                world->advance(step);
                if (wait_remaining > 0) wait_remaining -= step;
                for (auto& d : drones) {
                    if (d.wait_remaining > 0) d.wait_remaining -= step;
                }
                ticks -= step;
                steps = 0;
                continue;
            }
            if (main_ready) {
                if (++steps > kMaxInstantSteps) {
                    fail("运行超时：程序在没有消耗时间的情况下循环了太多次。");
                    return;
                }
                exec_next();
                continue;
            }
            if (child_ready) {
                if (++steps > kMaxInstantSteps) {
                    fail("运行超时：无人机程序循环了太多次。");
                    return;
                }
                pump_children_fixed();
                if (wait_remaining == 0 && !main_ready) {
                    // children may still not start waits; if nothing changed, consume 0 and loop
                }
                continue;
            }
            if (!running && !any_child_running()) break;
            if (ticks <= 0) return;
            // Idle? shouldn't happen
            break;
        }
    }

    void pump_children_fixed() {
        const int saved = active_drone;
        std::vector<Frame> main_frames;
        Env* main_env = env;
        const int64_t main_wait = wait_remaining;
        const bool main_has = has_current;
        const ExecEvent main_cur = current;
        main_frames.swap(frames);
        for (std::size_t i = 0; i < drones.size(); ++i) {
            DroneExec& d = drones[i];
            if (!d.running || d.finished || d.wait_remaining > 0) continue;
            active_drone = d.id;
            if (world) world->set_active_drone(d.id);
            frames.swap(d.frames);
            env = d.env;
            wait_remaining = 0;
            has_current = false;
            exec_next();
            d.wait_remaining = wait_remaining;
            d.current = current;
            d.has_current = has_current;
            d.frames.swap(frames);
            d.env = env;
            if (d.frames.empty() && d.wait_remaining == 0) {
                d.finished = true;
                d.running = false;
                d.ret_i = last_fn_ret;
            }
            wait_remaining = 0;
        }
        frames.swap(main_frames);
        env = main_env;
        wait_remaining = main_wait;
        has_current = main_has;
        current = main_cur;
        active_drone = saved;
        if (world) world->set_active_drone(saved);
    }

    void step_advance(int64_t ticks) {
        if (paused && error.empty() && !finished && program) {
            running = true;
            paused = false;
        }
        if (!running || !error.empty() || ticks < 0) return;
        int steps = 0;
        bool had_wait = wait_remaining > 0;
        while (running && error.empty() && !finished) {
            if (wait_remaining > 0) {
                had_wait = true;
                if (ticks <= 0) return;
                const int64_t step = std::min(ticks, wait_remaining);
                world->advance(step);
                wait_remaining -= step;
                for (auto& d : drones) {
                    if (d.wait_remaining > 0) {
                        d.wait_remaining = std::max<int64_t>(0, d.wait_remaining - step);
                    }
                }
                ticks -= step;
                if (wait_remaining == 0) {
                    running = false;
                    paused = !finished && error.empty();
                    return;
                }
                continue;
            }
            if (++steps > kMaxInstantSteps) {
                fail("运行超时：程序在没有消耗时间的情况下循环了太多次。");
                return;
            }
            exec_next();
            pump_children_fixed();
            if (had_wait && wait_remaining == 0) return;
        }
        if (finished || !error.empty()) paused = false;
    }
};

Interpreter::Interpreter() : impl_(std::make_unique<Impl>()) {}
Interpreter::Interpreter(Interpreter&&) noexcept = default;
Interpreter& Interpreter::operator=(Interpreter&&) noexcept = default;
Interpreter::~Interpreter() = default;

void Interpreter::bind(World* world) { impl_->world = world; }
World* Interpreter::world() const { return impl_->world; }

static std::string preprocess_includes(const std::string& source,
                                       const std::map<std::string, std::string>& files,
                                       const World* world, std::string* error, int depth) {
    if (depth > 16) {
        *error = "include 嵌套太深。";
        return {};
    }
    std::string out;
    std::istringstream in(source);
    std::string line;
    int lineno = 0;
    while (std::getline(in, line)) {
        ++lineno;
        std::string trimmed = line;
        const auto first = trimmed.find_first_not_of(" \t");
        if (first != std::string::npos && trimmed[first] == '#') {
            const auto inc = trimmed.find("#include", first);
            if (inc == first) {
                const auto q1 = trimmed.find('"', inc);
                if (q1 != std::string::npos) {
                    const auto q2 = trimmed.find('"', q1 + 1);
                    if (q2 == std::string::npos) {
                        *error = "第 " + std::to_string(lineno) + " 行：#include 字符串没有结束。";
                        return {};
                    }
                    const std::string name = trimmed.substr(q1 + 1, q2 - q1 - 1);
                    if (!world || !world->includes_unlocked()) {
                        *error = "第 " + std::to_string(lineno) +
                                 " 行：#include 自己的文件尚未解锁。到技能树花费胡萝卜即可使用。";
                        return {};
                    }
                    auto it = files.find(name);
                    if (it == files.end()) {
                        *error = "第 " + std::to_string(lineno) + " 行：找不到文件 “" + name + "”。";
                        return {};
                    }
                    std::string inner = preprocess_includes(it->second, files, world, error, depth + 1);
                    if (!error->empty()) return {};
                    out += inner;
                    if (!out.empty() && out.back() != '\n') out += '\n';
                    continue;
                }
                // <header> — keep the line so source line numbers stay stable.
                out += line;
                out += "\n";
                continue;
            }
        }
        out += line;
        out += "\n";
    }
    return out;
}

std::string Interpreter::load(const std::string& source) {
    impl_->reset_runtime();
    if (!impl_->world) {
        impl_->error = "内部错误：模拟世界尚未绑定。";
        return impl_->error;
    }
    std::string error;
    const std::string pre = preprocess_includes(source, impl_->include_files, impl_->world, &error, 0);
    if (!error.empty()) {
        impl_->error = error;
        impl_->diagnostic.message = error;
        impl_->diagnostic.kind = ErrorKind::LockedSyntax;
        impl_->diagnostic.span = SourceSpan{1, 1, 2};
        return impl_->error;
    }
    Parser parser(pre, impl_->world, &impl_->functions, &impl_->structs);
    if (!parser.parse_program(&error)) {
        impl_->error = error;
        impl_->diagnostic = parser.diagnostic();
        if (impl_->diagnostic.message.empty()) impl_->diagnostic.message = error;
        return impl_->error;
    }
    impl_->functions = parser.functions;
    impl_->structs = parser.structs;
    impl_->program = std::make_shared<std::vector<Stmt>>(std::move(parser.main_body));
    // File-scope consts are applied at start().
    impl_->error.clear();
    impl_->diagnostic = {};
    // Stash globals as statements to run at start.
    if (!parser.globals.empty()) {
        // Globals run first: prepend them to the program body.
        auto body = *impl_->program;
        parser.globals.insert(parser.globals.end(), body.begin(), body.end());
        impl_->program = std::make_shared<std::vector<Stmt>>(std::move(parser.globals));
    }
    return {};
}

void Interpreter::set_include(const std::string& name, const std::string& source) {
    impl_->include_files[name] = source;
}

void Interpreter::start() {
    if (!impl_->error.empty() || !impl_->program) return;
    // A maze belongs to the run that grew it. Left behind it walls in the
    // next program, whose harvest guards never touch the hedges.
    if (impl_->world) impl_->world->end_maze();
    impl_->frames.clear();
    impl_->env_store.clear();
    auto e = std::make_unique<Env>();
    impl_->env = e.get();
    impl_->env_store.push_back(std::move(e));
    impl_->events.clear();
    impl_->current = {};
    impl_->has_current = false;
    impl_->wait_remaining = 0;
    impl_->finished = false;
    impl_->paused = false;
    impl_->harvest_pulse = false;
    impl_->harvest_miss_pulse = false;
    impl_->flip_pulse = false;
    impl_->drones.clear();
    impl_->frames.push_back(make_frame(impl_->program.get()));
    impl_->running = true;
}

void Interpreter::stop() {
    impl_->running = false;
    impl_->paused = false;
    impl_->wait_remaining = 0;
    impl_->frames.clear();
    if (impl_->world) impl_->world->restore_world_size_if_needed();
}

void Interpreter::pause() {
    if (impl_->running) {
        impl_->running = false;
        impl_->paused = true;
    }
}

void Interpreter::resume() {
    if (impl_->paused && impl_->error.empty() && !impl_->finished) {
        impl_->running = true;
        impl_->paused = false;
    }
}

void Interpreter::clear() { impl_->reset_runtime(); }

void Interpreter::advance(int64_t ticks) { impl_->advance(ticks); }
void Interpreter::step_advance(int64_t ticks) { impl_->step_advance(ticks); }

bool Interpreter::is_running() const { return impl_->running; }
bool Interpreter::is_paused() const { return impl_->paused; }
bool Interpreter::is_finished() const { return impl_->finished; }
bool Interpreter::has_error() const { return !impl_->error.empty(); }
const std::string& Interpreter::error() const { return impl_->error; }
const Diagnostic& Interpreter::diagnostic() const { return impl_->diagnostic; }
int Interpreter::error_line() const { return impl_->diagnostic.span.line; }
int Interpreter::error_col_start() const { return impl_->diagnostic.span.col_start; }
int Interpreter::error_col_end() const { return impl_->diagnostic.span.col_end; }
const std::string& Interpreter::error_suggestion() const { return impl_->diagnostic.suggestion; }
ErrorKind Interpreter::error_kind() const { return impl_->diagnostic.kind; }

int Interpreter::current_line() const {
    const int view = impl_->view_drone;
    if (view > 0) {
        return drone_line(view);
    }
    if (!impl_->has_current) return 0;
    return impl_->current.line;
}
int Interpreter::drone_count() const {
    if (impl_->world) {
        const int n = impl_->world->drone_count();
        if (n > 0) return n;
    }
    return std::max(1, static_cast<int>(impl_->drones.size()));
}
int Interpreter::drone_x(int id) const {
    return impl_->world ? impl_->world->drone_x_of(id) : 0;
}
int Interpreter::drone_y(int id) const {
    return impl_->world ? impl_->world->drone_y_of(id) : 0;
}
int Interpreter::drone_line(int id) const {
    if (id <= 0) {
        if (!impl_->has_current) return 0;
        return impl_->current.line;
    }
    if (id >= 0 && id < static_cast<int>(impl_->drones.size()) &&
        impl_->drones[static_cast<std::size_t>(id)].has_current) {
        return impl_->drones[static_cast<std::size_t>(id)].current.line;
    }
    return 0;
}
void Interpreter::set_view_drone(int id) { impl_->view_drone = id; }
int Interpreter::view_drone() const { return impl_->view_drone; }
const ExecEvent* Interpreter::current_event() const {
    return impl_->has_current ? &impl_->current : nullptr;
}
double Interpreter::current_action_progress() const {
    if (!impl_->has_current || impl_->current.duration_ticks <= 0) return 0;
    const int64_t gone = impl_->current.duration_ticks - impl_->wait_remaining;
    return std::clamp(static_cast<double>(gone) / static_cast<double>(impl_->current.duration_ticks), 0.0, 1.0);
}
const std::vector<ExecEvent>& Interpreter::events() const { return impl_->events; }

bool Interpreter::take_harvest_pulse() {
    const bool v = impl_->harvest_pulse;
    impl_->harvest_pulse = false;
    return v;
}
bool Interpreter::take_flip_pulse() {
    const bool v = impl_->flip_pulse;
    impl_->flip_pulse = false;
    return v;
}

bool Interpreter::take_harvest_miss_pulse() {
    const bool v = impl_->harvest_miss_pulse;
    impl_->harvest_miss_pulse = false;
    return v;
}

int edit_distance(const std::string& a, const std::string& b) {
    const std::size_t n = a.size(), m = b.size();
    std::vector<int> prev(m + 1), cur(m + 1);
    for (std::size_t j = 0; j <= m; ++j) prev[j] = static_cast<int>(j);
    for (std::size_t i = 1; i <= n; ++i) {
        cur[0] = static_cast<int>(i);
        for (std::size_t j = 1; j <= m; ++j) {
            const int cost = a[i - 1] == b[j - 1] ? 0 : 1;
            cur[j] = std::min({prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost});
        }
        prev.swap(cur);
    }
    return prev[m];
}

std::string suggest_identifier(const std::string& name, const std::vector<std::string>& known) {
    std::string best;
    int best_d = 3;
    for (const auto& k : known) {
        const int d = edit_distance(name, k);
        if (d < best_d) {
            best_d = d;
            best = k;
        }
    }
    return best;
}

const char* error_kind_name(ErrorKind kind) {
    switch (kind) {
        case ErrorKind::Typo:
            return "typo";
        case ErrorKind::MissingSemicolon:
            return "missing_semicolon";
        case ErrorKind::Unclosed:
            return "unclosed";
        case ErrorKind::LockedSyntax:
            return "locked_syntax";
        case ErrorKind::OutsideMain:
            return "outside_main";
        default:
            return "generic";
    }
}

}  // namespace codefarm
