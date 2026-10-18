extends SceneTree

# Runtime errors in the asynchronous suite cannot silently report success.
class ScriptErrorMonitor extends Logger:
	var descriptions: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			descriptions.append("%s:%d %s %s" % [file, line, code, rationale])

var checks: int = 0
var failures: int = 0
var completed: bool = false
var elapsed: float = 0.0
var suite
var error_monitor := ScriptErrorMonitor.new()

func _initialize() -> void:
	OS.add_logger(error_monitor)
	call_deferred("run")

func _process(delta: float) -> bool:
	elapsed += delta
	if not error_monitor.descriptions.is_empty():
		print("FAIL: Script runtime error: ", error_monitor.descriptions[0])
		print("RESULT: %d checks, %d failures; SCRIPT ERROR" % [checks, failures + 1])
		quit(1)
	if not completed and elapsed > 200.0:
		push_error("FAIL: Movement lab suite timed out or aborted before completion")
		print("RESULT: %d checks, %d failures; INCOMPLETE" % [checks, failures + 1])
		quit(1)
	return false

func tick(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	suite = load("res://tests/sandbox_checks.gd").new()
	await suite.run(self)
	if not suite.completed:
		check(false, "Movement lab suite did not complete")
	suite = load("res://tests/combat_controls_checks.gd").new()
	await suite.run(self)
	if not suite.completed:
		check(false, "Combat controls suite did not complete")
	suite = load("res://tests/aim_form_checks.gd").new()
	await suite.run(self)
	if not suite.completed:
		check(false, "Aim and character-form suite did not complete")
	suite = load("res://tests/target_aim_checks.gd").new()
	await suite.run(self)
	if not suite.completed:
		check(false, "Target gesture and movement suite did not complete")
	suite = load("res://tests/target_ranged_checks.gd").new()
	await suite.run(self)
	if not suite.completed:
		check(false, "Targeted ranged collision suite did not complete")
	if checks < 450:
		check(false, "Movement lab suite completed too few assertions")
	if not error_monitor.descriptions.is_empty():
		check(false, "Movement lab suite raised a script runtime error")
	completed = true
	print("RESULT: %d checks, %d failures; COMPLETE" % [checks, failures])
	quit(1 if failures else 0)
