extends WhiteTestRunner
## Test runner: godot --headless --path . res://tests/run_tests.tscn [-- --min-checks=N]


func _run() -> void:
	await preload("res://tests/rules_tests.gd").new().run(check, self)
