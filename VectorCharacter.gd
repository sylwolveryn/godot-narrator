extends Node2D

var form_value = 0.0  # 0 = W, 1 = GA

func _draw():
	var center = Vector2.ZERO
	var size = 20.0
	
	# Interpolate between W and GA shapes
	# W shape parameters
	var w_points = [
		Vector2(-15, 15),  # bottom left
		Vector2(-5, -10),  # top left
		Vector2(0, 5),     # middle dip
		Vector2(5, -10),   # top right
		Vector2(15, 15)    # bottom right
	]
	
	# GA shape parameters (simplified)
	var ga_points = [
		Vector2(-10, 15),  # bottom left
		Vector2(-10, -8),  # vertical line
		Vector2(10, -8),   # horizontal top
		Vector2(-10, 2),   # crossbar
		Vector2(10, 15)    # diagonal finish
	]
	
	# Interpolate based on form_value
	var current_points = []
	for i in range(w_points.size()):
		var w_point = w_points[i]
		var ga_point = ga_points[i] if i < ga_points.size() else ga_points[ga_points.size() - 1]
		var interpolated = w_point.lerp(ga_point, form_value)
		current_points.append(interpolated)
	
	# Draw the interpolated shape
	var color = Color.WHITE.lerp(Color(0.3, 0.8, 0.5), form_value)
	for i in range(current_points.size() - 1):
		draw_line(current_points[i], current_points[i + 1], color, 4.0, true)
	
	# Draw dakuten when closer to GA
	if form_value > 0.5:
		var dakuten_alpha = (form_value - 0.5) * 2.0
		var dakuten_color = Color(0.9, 0.4, 0.4, dakuten_alpha)
		draw_circle(Vector2(20, -8), 3, dakuten_color)
		draw_circle(Vector2(26, -8), 3, dakuten_color)

func set_form(value: float):
	form_value = clamp(value, 0.0, 1.0)
	queue_redraw()
