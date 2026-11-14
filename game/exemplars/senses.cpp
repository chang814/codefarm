#include <bits/stdc++.h>
using namespace std;

const int kSize = 3;

int main() {
    while (true) {
        for (int i = 0; i < kSize; i++) {
            if (can_harvest()) {
                harvest();
            }
            // 第 0 列留给草：绕圈后也认得出来
            if (get_pos_x() == 0) {
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
