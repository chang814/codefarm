#pragma once

#include "codefarm/types.hpp"

#include <memory>
#include <string>
#include <vector>

namespace codefarm {

class World;

struct SourceSpan {
    int line = 1;
    int col_start = 1;  // 1-based, inclusive
    int col_end = 1;    // 1-based, exclusive
};

enum class ErrorKind {
    None = 0,
    Generic,
    Typo,
    MissingSemicolon,
    Unclosed,
    LockedSyntax,
    OutsideMain,
};

struct Diagnostic {
    std::string message;
    SourceSpan span;
    std::string suggestion;
    ErrorKind kind = ErrorKind::None;
    std::string code_word;
};

int edit_distance(const std::string& a, const std::string& b);
std::string suggest_identifier(const std::string& name, const std::vector<std::string>& known);
const char* error_kind_name(ErrorKind kind);

// C++-style subset. Preferred form:
//   #include <bits/stdc++.h>
//   using namespace std;
//   int main() { harvest(); return 0; }
// Also accepts bare statements for tests: harvest();
// Builtins: harvest(); do_a_flip(); can_harvest();
//   if (can_harvest()) { harvest(); }
//   while (true) { harvest(); }  // rejected until 5 lifetime hay
//   move(East);                 // rejected until 15 lifetime hay
class Interpreter {
public:
    Interpreter();
    Interpreter(const Interpreter&) = delete;
    Interpreter& operator=(const Interpreter&) = delete;
    Interpreter(Interpreter&&) noexcept;
    Interpreter& operator=(Interpreter&&) noexcept;
    ~Interpreter();

    void bind(World* world);
    World* world() const;
    void set_include(const std::string& name, const std::string& source);

    // Parse and compile. Empty string means success. Does not start running.
    std::string load(const std::string& source);

    void start();
    void stop();
    void pause();
    void resume();
    void clear();

    // Advance simulation time, executing statements as their waits complete.
    void advance(int64_t ticks);
    // Run until the current (or next) statement / farm action finishes, then
    // pause. Consumes at most `ticks` of simulation time this call.
    void step_advance(int64_t ticks);

    bool is_running() const;
    bool is_paused() const;
    bool is_finished() const;
    bool has_error() const;
    const std::string& error() const;
    const Diagnostic& diagnostic() const;
    int error_line() const;
    int error_col_start() const;
    int error_col_end() const;
    const std::string& error_suggestion() const;
    ErrorKind error_kind() const;

    // 1-based; 0 if nothing is executing.
    int current_line() const;
    int drone_count() const;
    int drone_x(int id) const;
    int drone_y(int id) const;
    int drone_line(int id) const;
    void set_view_drone(int id);
    int view_drone() const;
    const ExecEvent* current_event() const;
    // 0–1 progress through the current action: (tick - event.start) / duration.
    double current_action_progress() const;
    const std::vector<ExecEvent>& events() const;

    // True once when a successful harvest / flip action begins (for juice).
    bool take_harvest_pulse();
    bool take_harvest_miss_pulse();
    bool take_flip_pulse();

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

}  // namespace codefarm
