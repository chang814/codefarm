#include <bits/stdc++.h>
using namespace std;

const int kSize = 3;

int main() {
    while (true) {
        for (int i = 0; i < kSize; i++) {
            if (can_harvest()) {
                harvest();
            }
            // 偶数列种草，奇数列种灌木
            if (get_pos_x() % 2 == 0) {
                if (get_ground_type() == Soil) {
                    till();
                }
            } else {
                if (get_ground_type() != Soil) {
                    till();
                }
                if (get_entity_type() == None) {
                    plant(Bush);
                }
            }
            move(East);
        }
        move(North);
    }
    return 0;
}
