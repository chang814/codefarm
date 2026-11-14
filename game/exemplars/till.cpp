#include <bits/stdc++.h>
using namespace std;

int main() {
    // 把脚下这一行翻成土壤：翻完没有产出，要等种植
    for (int i = 0; i < 3; i++) {
        till();
        move(East);
    }
    return 0;
}
