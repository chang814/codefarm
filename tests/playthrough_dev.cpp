// Dev tool: run the scripted playthrough and print per-stage timings.
#include "playthrough_route.hpp"
#include <cstdio>

int main() {
    playthrough::Route r = playthrough::play_full_route(true);
    std::printf("%s\n", r.report.c_str());
    return r.ok ? 0 : 1;
}
