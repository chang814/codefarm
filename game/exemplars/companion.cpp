#include <bits/stdc++.h>
using namespace std;

void stepTo(int x, int y) {
    while (get_pos_x() != x) {
        move(East);
    }
    while (get_pos_y() != y) {
        move(North);
    }
}

// 按作物要的地面种下去：草要草地，灌木和胡萝卜要土
void plantHere(Entity type) {
    if (can_harvest()) {
        harvest();
    }
    if (type == Grass) {
        if (get_ground_type() == Soil) {
            till();
        }
        return;
    }
    if (type != Tree && get_ground_type() != Soil) {
        till();
    }
    if (get_entity_type() == None) {
        plant(type);
    }
}

int main() {
    while (true) {
        for (int x = 0; x < get_world_size(); x++) {
            for (int y = 0; y < get_world_size(); y++) {
                stepTo(x, y);
                if (can_harvest()) {
                    harvest();
                }
                if (get_entity_type() == None) {
                    plant(Tree);
                    // 树想要的伙伴种在旁边，收获翻五倍
                    Companion c = get_companion();
                    if (c.ok) {
                        stepTo(c.x, c.y);
                        plantHere(c.type);
                        stepTo(x, y);
                    }
                }
            }
        }
    }
    return 0;
}
