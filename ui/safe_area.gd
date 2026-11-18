class_name TallySafeArea
extends RefCounted
## Insets that keep the screen out of notches and rounded corners, in viewport units. Zero on desktop.


## {left, top, right, bottom}; debug override "l,t,r,b" in viewport px.
static func insets(viewport_size: Vector2, override: String = "") -> Dictionary:
	if not override.is_empty():
		return parse(override)
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return _zero()
	# safe area is in desktop coordinates (second monitor): make it window-relative
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if not OS.has_feature("web"):
		safe.position -= Vector2(DisplayServer.window_get_position())
	return from_rects(safe, win, viewport_size)


## Safe rect (screen px) inside a window of win px, as insets in viewport units.
static func from_rects(safe: Rect2, win: Vector2, viewport_size: Vector2) -> Dictionary:
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return _zero()
	var k := viewport_size / win
	return {
		"left": maxf(0.0, safe.position.x) * k.x,
		"top": maxf(0.0, safe.position.y) * k.y,
		"right": maxf(0.0, win.x - safe.end.x) * k.x,
		"bottom": maxf(0.0, win.y - safe.end.y) * k.y,
	}


static func parse(text: String) -> Dictionary:
	var p := text.split(",")
	var v := func(i: int) -> float: return float(p[i]) if p.size() > i else 0.0
	return {"left": v.call(0), "top": v.call(1), "right": v.call(2), "bottom": v.call(3)}


## Adds the insets to the margins of the screen's root container.
static func apply(margin: MarginContainer, override: String = "") -> void:
	var i := insets(margin.get_viewport_rect().size, override)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, WhiteTheme.MARGIN + int(i[side]))


static func _zero() -> Dictionary:
	return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
