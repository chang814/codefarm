#include <bits/stdc++.h>
using namespace std;

int main() {
    while (true) {
        if (can_harvest()) {
            harvest();
        }
        move(East);
    }
    return 0;
}
