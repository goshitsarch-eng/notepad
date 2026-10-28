extends TestCase


func test_harness_runs() -> void:
	assert_eq(1 + 1, 2)
	assert_eq("a".to_upper(), "A")


func test_app_version_is_set() -> void:
	assert_ne(AppInfo.version(), "0.0.0")
