#include <bits/stdc++.h>
using namespace std;

const int kSize = 3;

int main() {
    while (true) {
        for (int i = 0; i < kSize; i++) {
            if (can_harvest()) {
                harvest();
            }
            // 每行第一格留给草，其余种灌木
            if (i == 0) {
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
