#include <bits/stdc++.h>
#include "farm.hpp"
using namespace std;

int main() {
    // 收满 100 次就停，看一轮能收多少
    int harvested = 0;
    while (harvested < 100) {
        for (int i = 0; i < get_world_size(); i++) {
            tendTile(harvested);
            move(East);
        }
        move(North);
    }
    return 0;
}
