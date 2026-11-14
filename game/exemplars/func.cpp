#include <bits/stdc++.h>
using namespace std;

void tendTile() {
    if (can_harvest()) {
        harvest();
    }
    // 偶数列种草；奇数列隔行种树和胡萝卜
    if (get_pos_x() % 2 == 0) {
        if (get_ground_type() == Soil) {
            till();
        }
    } else {
        if (get_ground_type() != Soil) {
            till();
        }
        if (get_entity_type() == None) {
            if (get_pos_y() % 2 == 0) {
                plant(Tree);
            } else {
                if (get_water() < 0.5) {
                    use_item(Water);
                }
                Cost c = get_cost(Carrot);
                if (num_items(Hay) >= c.hay && num_items(Wood) >= c.wood) {
                    plant(Carrot);
                }
            }
        }
    }
}

int main() {
    while (true) {
        for (int i = 0; i < get_world_size(); i++) {
            tendTile();
            move(East);
        }
        move(North);
    }
    return 0;
}
