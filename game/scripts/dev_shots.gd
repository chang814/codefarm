extends SceneTree
## Developer screenshot tour: welcome, first farm, a grown mixed farm, a
## harvest in motion, the skill tree, a skill detail, and settings.
## Output goes to the directory in the SHOT_DIR environment variable.
## Uses test grants to reach late content quickly; it is not a playthrough.

const SHOWCASE := """#include <bits/stdc++.h>
using namespace std;

int main() {
    for (int y = 0; y < get_world_size(); y++) {
        for (int x = 0; x < get_world_size(); x++) {
            int k = (get_pos_x() + get_pos_y() * 2) % 6;
            if (k != 0) {
                if (get_ground_type() != Soil) {
                    till();
                }
            }
            if (k == 1) { plant(Bush); }
            if (k == 2) { plant(Tree); }
            if (k == 3) { plant(Carrot); }
            if (k == 4) { plant(Sunflower); }
            if (k == 5) { plant(Pumpkin); }
            move(East);
        }
        move(North);
    }
    return 0;
}
"""

const LOOP := """#include <bits/stdc++.h>
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
"""

var out_dir := ""


func _init() -> void:
	call_deferred("_run")


func settle(seconds := 0.3) -> void:
	await create_timer(seconds).timeout
	await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image:
		image.save_png(out_dir.path_join(name + ".png"))
		print("SHOT ", name)


func _run() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir == "":
		out_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await settle(0.8)
	await shot("01-welcome")

	main.start_game()
	await settle(2.4)
	await shot("02-first-farm")

	var host = main.host
	for id in ["loop", "speed", "iff", "move", "forl", "till", "plant", "vars", "ops", "senses", "expand", "carrot", "water", "tree", "sun", "pumpkin", "func", "array"]:
		host.debug_grant(id)
	for item in ["hay", "wood", "carrot", "water", "power", "pumpkin"]:
		host.debug_add_item(item, 5000)
	main.editor.text = SHOWCASE
	main.call("_on_run")
	for i in 400:
		host.advance_seconds(0.25)
		if not host.is_running():
			break
	for i in 80:
		host.advance_seconds(0.25)
	main.call("_on_stop")
	await settle(1.2)
	await shot("03-grown-farm")

	main.code_window.visible = false
	main.hint_window.visible = false
	main.reset_camera(true)
	await settle(0.6)
	await shot("04-farm-wide")
	var rig = main.camera_rig
	for view in [["04b-crops-near", Vector3(-0.7, 0.3, 0.2)], ["04c-crops-near", Vector3(1.0, 0.3, -0.9)]]:
		rig.zoom = 2.5
		rig.zoom_s = 2.5
		rig.target = view[1]
		rig.target_s = view[1]
		rig.sync_pos_from_target()
		rig.apply_transform()
		await settle(0.4)
		await shot(view[0])
	main.reset_camera(true)
	await settle(0.3)

	main.code_window.visible = true
	main.editor.text = LOOP
	main.call("_on_run")
	var tries := 0
	while tries < 600:
		await process_frame
		tries += 1
		if main.bot.harvesting:
			break
	await settle(0.12)
	await shot("05-harvest")
	await settle(0.25)
	await shot("06-harvest-later")
	main.call("_on_stop")

	main.call("_toggle_panel", "skill")
	await settle(0.7)
	await shot("07-skill-tree")
	main.skill_tree.open_detail("loop")
	await settle(0.5)
	await shot("08-skill-detail")
	main.skill_tree.close_detail()
	main.call("_toggle_panel", "settings")
	await settle(0.7)
	await shot("09-settings")
	main.call("_close_panel")
	main.hint_window.visible = true
	await settle(0.6)
	await shot("10-hint")
	print("SHOTS_OK")
	quit(0)
