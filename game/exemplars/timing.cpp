#include <bits/stdc++.h>
using namespace std;

int main() {
    double start = get_time();
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
            quick_print(num_items(Pumpkin));
            quick_print(get_time() - start);
            start = get_time();
        }
    }
    return 0;
}
