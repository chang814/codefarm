#include <bits/stdc++.h>
using namespace std;

// 朝苹果走一步；四个方向都被身体挡住就返回 false
bool stepToward(int ax, int ay) {
    if (get_pos_x() < ax && can_move(East)) {
        return move(East);
    }
    if (get_pos_x() > ax && can_move(West)) {
        return move(West);
    }
    if (get_pos_y() < ay && can_move(North)) {
        return move(North);
    }
    if (get_pos_y() > ay && can_move(South)) {
        return move(South);
    }
    if (can_move(East)) {
        return move(East);
    }
    if (can_move(North)) {
        return move(North);
    }
    if (can_move(West)) {
        return move(West);
    }
    if (can_move(South)) {
        return move(South);
    }
    return false;
}

int main() {
    change_hat(DinosaurHat);
    while (true) {
        Measure apple = measure();
        if (!apple.ok || !stepToward(apple.x, apple.y)) {
            break;
        }
    }
    // 摘下帽子，按尾巴长度换骨头
    change_hat(StrawHat);
    return 0;
}
