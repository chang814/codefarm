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

void plantAll() {
    for (int x = 0; x < get_world_size(); x++) {
        for (int y = 0; y < get_world_size(); y++) {
            stepTo(x, y);
            if (get_ground_type() != Soil) {
                till();
            }
            // 别的作物先收掉（没熟就等它熟），再种仙人掌
            while (get_entity_type() != Cactus) {
                if (get_entity_type() != None) {
                    harvest();
                }
                plant(Cactus);
            }
        }
    }
}

// 冒泡排序：每行大的往东，每列大的往北
void sortField() {
    int n = get_world_size();
    for (int y = 0; y < n; y++) {
        for (int pass = 0; pass < n - 1; pass++) {
            for (int x = 0; x < n - 1; x++) {
                stepTo(x, y);
                if (measure().value > measure(East).value) {
                    swap(East);
                }
            }
        }
    }
    for (int x = 0; x < n; x++) {
        for (int pass = 0; pass < n - 1; pass++) {
            for (int y = 0; y < n - 1; y++) {
                stepTo(x, y);
                if (measure().value > measure(North).value) {
                    swap(North);
                }
            }
        }
    }
}

int main() {
    // 先在 3×3 上试排序，看清每一步
    set_world_size(3);
    // 固定种子：每次重跑，作物长得一模一样，好比较两版代码
    simulate(42);
    while (true) {
        plantAll();
        sortField();
        while (!can_harvest()) {
        }
        harvest();
    }
    return 0;
}
