# 모든 테스트 파일의 베이스 클래스.
# 사용법: extends "res://test/test_case.gd" 후 test_ 로 시작하는 메서드 작성.
extends RefCounted

var failures: Array[String] = []
var current_test := ""


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		_fail("expected true", msg)


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		_fail("expected false", msg)


func assert_eq(actual, expected, msg := "") -> void:
	if actual != expected:
		_fail("expected %s but got %s" % [str(expected), str(actual)], msg)


func assert_ne(actual, other, msg := "") -> void:
	if actual == other:
		_fail("expected values to differ, both were %s" % str(actual), msg)


func assert_almost_eq(actual: float, expected: float, tolerance := 0.0001, msg := "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %f ~= %f (tol %f)" % [actual, expected, tolerance], msg)


func _fail(detail: String, msg: String) -> void:
	var suffix := " — " + msg if msg != "" else ""
	failures.append("%s: %s%s" % [current_test, detail, suffix])
