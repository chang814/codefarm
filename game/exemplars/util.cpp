#include <bits/stdc++.h>
using namespace std;

const int kMax = 32;

struct Spot {
    int x;
    int y;
};

// 田是环形的：一直往东、往北总能走到 (x, y)
void stepTo(int x, int y) {
    while (get_pos_x() != x) {
        move(East);
    }
    while (get_pos_y() != y) {
        move(North);
    }
}

Spot findBest(int petals[kMax][kMax]) {
    Spot best;
    best.x = 0;
    best.y = 0;
    int most = -1;
    for (int x = 0; x < get_world_size(); x++) {
        for (int y = 0; y < get_world_size(); y++) {
            most = max(most, petals[x][y]);
        }
    }
    for (int x = 0; x < get_world_size(); x++) {
        for (int y = 0; y < get_world_size(); y++) {
            if (petals[x][y] == most) {
                best.x = x;
                best.y = y;
            }
        }
    }
    return best;
}

int main() {
    // 种满一遍，把每株的花瓣记进表里，之后不用再绕圈去量
    int petals[kMax][kMax];
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
            petals[x][y] = measure().value;
        }
    }
    while (true) {
        Spot best = findBest(petals);
        stepTo(best.x, best.y);
        while (!can_harvest()) {
        }
        harvest();
        plant(Sunflower);
        petals[best.x][best.y] = measure().value;
    }
    return 0;
}
