#include <bits/stdc++.h>
#include "farm.hpp"
using namespace std;

void farmForever() {
    int harvested = 0;
    while (true) {
        for (int i = 0; i < get_world_size(); i++) {
            tendTile(harvested);
            move(East);
        }
        move(North);
    }
}

int main() {
    change_hat(TopHat);
    // 第二架无人机从这里出发，主机错开两行一起干
    spawn_drone(farmForever);
    move(North);
    move(North);
    farmForever();
    return 0;
}
