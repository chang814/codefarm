extends SceneTree

func _init() -> void:
	var host: CodefarmHost = CodefarmHost.new()
	if host == null:
		push_error("无法创建 CodefarmHost")
		quit(1)
		return
	var src := """#include <bits/stdc++.h>
using namespace std;

int main() {
    harvest();
    return 0;
}
"""
	var err: String = host.load_script(src)
	if err != "":
		push_error(err)
		quit(1)
		return
	host.start()
	host.advance_seconds(0.5)
	print("VERIFY mid hay=", host.get_hay(), " running=", host.is_running(), " finished=", host.is_finished(), " tick=", host.get_tick(), " mature=", host.grass_mature())
	if host.get_hay() != 1:
		push_error("期望收获 1 个干草（效果在动作开始时结算）")
		quit(1)
		return
	if not host.is_running():
		push_error("开局一次 harvest 应为 1 秒，0.5 秒时程序还应在跑")
		quit(1)
		return
	if host.grass_mature():
		push_error("收割做到一半时新草不应已经成熟")
		quit(1)
		return
	host.advance_seconds(0.5)
	print("VERIFY end hay=", host.get_hay(), " running=", host.is_running(), " finished=", host.is_finished(), " tick=", host.get_tick(), " mature=", host.grass_mature())
	if not host.is_finished():
		push_error("1 秒后 main 应当结束")
		quit(1)
		return
	if not host.grass_mature():
		push_error("开局速度下，收割结束时新草应刚好成熟")
		quit(1)
		return
	# Main must not restart itself; time can still flow.
	var hay := host.get_hay()
	host.advance_seconds(1.0)
	if host.get_hay() != hay or host.is_running():
		push_error("main 结束后不应自动再跑")
		quit(1)
		return
	print("VERIFY_OK")
	host.free()
	quit(0)
