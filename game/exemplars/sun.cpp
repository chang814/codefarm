#include <bits/stdc++.h>
using namespace std;

// 田是环形的：一直往东、往北总能走到 (x, y)
void stepTo(int x, int y) {
    while (get_pos_x() != x) {
        move(East);
    }
    while (get_pos_y() != y) {
        move(North);
    }
}

int main() {
    while (true) {
        // 走一圈：补种向日葵，记下花瓣最多的一株
        int best = -1;
        int bestX = 0;
        int bestY = 0;
        for (int x = 0; x < get_world_size(); x++) {
            for (int y = 0; y < get_world_size(); y++) {
                stepTo(x, y);
                if (get_ground_type() != Soil) {
                    till();
                }
                if (get_entity_type() != Sunflower) {
                    if (can_harvest()) {
                        harvest();
                    }
                    plant(Sunflower);
                }
                Measure m = measure();
                if (m.ok && m.value > best) {
                    best = m.value;
                    bestX = x;
                    bestY = y;
                }
            }
        }
        stepTo(bestX, bestY);
        while (!can_harvest()) {
        }
        harvest();
    }
    return 0;
}
