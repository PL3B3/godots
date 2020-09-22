extends Node

static func interpolate_symmetric(interpolator, obj, property, new, period):
	var old = obj.get(property)
	interpolator.interpolate_property(
		obj,
		property,
		old,
		new,
		period / 2,
		Tween.TRANS_SINE,
		Tween.EASE_OUT)
	interpolator.start()
	yield(interpolator, "tween_completed")
	interpolator.interpolate_property(
		obj,
		property,
		new,
		old,
		period / 2,
		Tween.TRANS_SINE,
		Tween.EASE_OUT)
	interpolator.start()
