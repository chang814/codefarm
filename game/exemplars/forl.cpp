#include <bits/stdc++.h>
using namespace std;

int main() {
    while (true) {
        // 走完一行 3 格，再换到上一行
        for (int i = 0; i < 3; i++) {
            if (can_harvest()) {
                harvest();
            }
            move(East);
        }
        move(North);
    }
    return 0;
}
