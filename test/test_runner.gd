# GUT 비의존 헤드리스 테스트 러너.
# 실행: godot --headless --script test/test_runner.gd (프로젝트 루트에서)
# 첫 실행 전 godot --headless --import 가 필요할 수 있다.
# test/ 아래 test_*.gd (test_runner.gd, test_case.gd 제외)를 로드해
# test_ 로 시작하는 메서드를 모두 실행한다. 실패가 있으면 종료코드 1.
extends SceneTree

const TEST_DIR := "res://test"


func _initialize() -> void:
	var total := 0
	var failed: Array[String] = []

	for file_name in _collect_test_files():
		var script: GDScript = load(TEST_DIR + "/" + file_name)
		if script == null or not script.can_instantiate():
			failed.append(file_name + " :: failed to load script")
			continue
		var case = script.new()
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			case.current_test = method_name
			case.call(method_name)
		for failure in case.failures:
			failed.append(file_name + " :: " + failure)

	if failed.is_empty():
		print("OK — %d tests passed" % total)
		quit(0)
	else:
		for line in failed:
			printerr("FAIL " + line)
		printerr("FAILED — %d of %d tests failed" % [failed.size(), total])
		quit(1)


func _collect_test_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		printerr("cannot open " + TEST_DIR)
		quit(1)
		return files
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") \
				and f != "test_runner.gd" and f != "test_case.gd":
			files.append(f)
	files.sort()
	return files
