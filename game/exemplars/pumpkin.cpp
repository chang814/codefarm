#include <bits/stdc++.h>
using namespace std;

int main() {
    while (true) {
        // 走一圈：补种空格和枯南瓜；整片都熟了才收
        bool allRipe = true;
        for (int y = 0; y < get_world_size(); y++) {
            for (int x = 0; x < get_world_size(); x++) {
                if (get_ground_type() != Soil) {
                    till();
                }
                if (get_entity_type() != Pumpkin) {
                    if (can_harvest()) {
                        harvest();
                    }
                    plant(Pumpkin);
                    allRipe = false;
                } else if (!can_harvest()) {
                    allRipe = false;
                }
                move(East);
            }
            move(North);
        }
        if (allRipe) {
            harvest();
        }
    }
    return 0;
}
