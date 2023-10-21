extends Node2D
@export var max_radius: int = 200
@export var min_radius: int = 60
@export var points: int = 9
@export var min_area: int = 500
var block_color: Color

# Called when the node enters the scene tree for the first time.
func _ready():
	block_color = get_random_color()
	var vert_arr = get_init_points()
	var obb_arr = get_obb(vert_arr)
	subdivide(vert_arr, obb_arr)

func _input(event):
	if event.is_action_pressed("regenerate"):
		get_tree().reload_current_scene()
	if event.is_action_pressed("screenshot"):
		var image = get_viewport().get_texture().get_image()
		image.save_png("screenshots/%s.png" % randi())

func get_init_points():
	var rads = 0
	var vert_arr = PackedVector2Array()
	for i in range(points):
		var dist = randf_range(min_radius, max_radius)
		vert_arr.append(Vector2(cos(rads) * dist, sin(rads) * dist))
		rads -= ((2 * PI) / points)
	return vert_arr

func get_random_color() -> Color:
	var colors = [
		'#46425e',
		'#15788c',
		'#00b9be',
		'#ffb0a3',
		'#ff6973'
	]
	return Color(colors[randi() % colors.size()])

func get_rect_dimensions(vert_arr: PackedVector2Array):
	var top = -INF
	var bottom = INF
	var left = INF
	var right = -INF
	for i in range(vert_arr.size()):
		top = max(top, vert_arr[i].y)
		bottom = min(bottom, vert_arr[i].y)
		left = min(left, vert_arr[i].x)
		right = max(right, vert_arr[i].x)
	var w = right - left
	var h = top - bottom
	return {"left": left, "bottom": bottom, "top": top, "right": right, \
		"width": w, "height": h}

func polygon_to_rect(vert_arr: PackedVector2Array) -> Rect2:
	var rd = get_rect_dimensions(vert_arr)
	return Rect2(Vector2(rd.left, rd.bottom), \
		Vector2(abs(rd.width), abs(rd.height)))

func too_small(vert_arr: PackedVector2Array) -> bool:
	var current_rect = polygon_to_rect(vert_arr)
	return current_rect.get_area() < min_area

func get_rotated_vector(packed_vector_array: PackedVector2Array, \
	pivot: Vector2, angle_to_rotate: float):
	var rotated_vectors = PackedVector2Array()
	for i in range(packed_vector_array.size()):
		var vector = packed_vector_array[i]
		var diff = vector - pivot
		diff = diff.rotated(angle_to_rotate)
		diff += pivot
		rotated_vectors.append(diff)
	return rotated_vectors

func get_angle_to_rotate(vert_arr: PackedVector2Array, pivot_index: int) -> float:
	var next = vert_arr[(pivot_index + 1) % vert_arr.size()]
	return -atan2(next.y - vert_arr[pivot_index].y, next.x - vert_arr[pivot_index].x)

func get_obb(vert_arr: PackedVector2Array):
	var min_rect = INF
	var bounding_box: PackedVector2Array
	var obb_pivot: int
	var obb_angle: float
	for pivot in range(vert_arr.size()):
		var angle = get_angle_to_rotate(vert_arr, pivot)
		var rot = get_rotated_vector(vert_arr, vert_arr[pivot], angle)
		var rd = get_rect_dimensions(rot)
		var current_rect = Rect2(Vector2(rd.left, rd.bottom), \
			Vector2(abs(rd.width), abs(rd.height)))
		if current_rect.get_area() < min_rect:
			min_rect = current_rect.get_area()
			bounding_box = PackedVector2Array([
				current_rect.position,
				Vector2(current_rect.position.x, current_rect.end.y),
				current_rect.end,
				Vector2(current_rect.end.x, current_rect.position.y)
			])
			obb_pivot = pivot
			obb_angle = angle
	var angle_n = -obb_angle
	var final_rot = get_rotated_vector(bounding_box, vert_arr[obb_pivot], angle_n)
	return final_rot

func split_polygon(vert_arr: PackedVector2Array, obb_arr: PackedVector2Array):
	var midpoints = []
	for i in range(obb_arr.size()):
		var v1 = obb_arr[i]
		var v2 = obb_arr[(i + 1) % obb_arr.size()]
		midpoints.append((v1 + v2) / 2)
	var first_half
	var second_half
	if midpoints[0].distance_to(midpoints[2]) < midpoints[1].distance_to(midpoints[3]):
		first_half = PackedVector2Array([obb_arr[0], midpoints[0], midpoints[2], obb_arr[3]])
		second_half = PackedVector2Array([midpoints[0], obb_arr[1], obb_arr[2], midpoints[2]])
	else:
		first_half = PackedVector2Array([obb_arr[0], obb_arr[1], midpoints[1], midpoints[3]])
		second_half = PackedVector2Array([midpoints[1], obb_arr[2], obb_arr[3], midpoints[3]])
	return {
		"p1": Geometry2D.intersect_polygons(vert_arr, first_half)[0],
		"p2": Geometry2D.intersect_polygons(vert_arr, second_half)[0]
	}

func subdivide(vert_arr: PackedVector2Array, obb_arr: PackedVector2Array):
	var split_data = split_polygon(vert_arr, obb_arr)
	var obb_arr1 = get_obb(split_data.p1)
	var obb_arr2 = get_obb(split_data.p2)
	if too_small(obb_arr1) or too_small(obb_arr2):
		var offset_arr = Geometry2D.offset_polygon(vert_arr, -0.5, Geometry2D.JOIN_MITER)
		var polygon = Polygon2D.new()
		polygon.set_polygon(offset_arr[0])
		polygon.color = block_color
		add_child(polygon)
	else:
		subdivide(split_data.p1, obb_arr1)
		subdivide(split_data.p2, obb_arr2)
