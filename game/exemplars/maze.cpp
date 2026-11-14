#include <bits/stdc++.h>
using namespace std;

Dir turnRight(Dir d) {
    if (d == North) {
        return East;
    }
    if (d == East) {
        return South;
    }
    if (d == South) {
        return West;
    }
    return North;
}

Dir turnLeft(Dir d) {
    if (d == North) {
        return West;
    }
    if (d == West) {
        return South;
    }
    if (d == South) {
        return East;
    }
    return North;
}

// 脚下种一丛灌木，撒奇怪物质长成迷宫
void makeMaze() {
    if (get_ground_type() != Soil) {
        till();
    }
    while (get_entity_type() != Bush) {
        if (can_harvest()) {
            harvest();
        }
        plant(Bush);
    }
    use_item(WeirdSubstance, get_world_size());
}

// 右手扶墙走到宝箱
void solve() {
    Dir facing = North;
    while (get_entity_type() != Treasure) {
        Dir right = turnRight(facing);
        if (can_move(right)) {
            facing = right;
            move(facing);
        } else if (can_move(facing)) {
            move(facing);
        } else {
            facing = turnLeft(facing);
        }
    }
    harvest();
}

int main() {
    makeMaze();
    while (true) {
        solve();
    }
    return 0;
}
