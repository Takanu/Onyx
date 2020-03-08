tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Used to perform additional common operations across 


# Returns the AABB of any given node.  May return nothing if the node provided has no data to extrapolate bounds from.
static func get_aabb(node : Node):
	
	# //////////////
	# MESH NODES
	if node.is_class("Mesh"):
		return get_mesh_aabb(node)
		
	elif node.is_class("MultiMesh"):
		return node.get_aabb()
		
	elif node.is_class("MeshInstance"):
		return get_mesh_aabb(node.get_mesh())
		
	elif node.is_class("ImmediateGeometry"):
		print("VectorUtils.get_aabb(node) cannot obtain data from ImmediateGeometry, provide a face_dictionary instead.")
		return null
		
	# //////////////
	# CSG NODES
	elif node.is_class("CSGBox"):
		var ub = Vector3(node.width / 2, node.height / 2, node.depth / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node.is_class("CSGCylinder"):
		var ub = Vector3(node.radius / 2, node.height / 2, node.radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node.is_class("CSGPolygon"):
		print("VectorUtils.get_aabb(node) cannot obtain data from CSGPolygon, im just not going to go there right now.")
		return null
		
	elif node.is_class("CSGSphere"):
		var ub = Vector3(node.radius / 2, node.radius / 2, node.radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node.is_class("CSGTorus"):
		var ub = Vector3(node.outer_radius / 2, node.outer_radius / 2, node.outer_radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
	
	elif node.is_class("CSGMesh"):
		return get_mesh_aabb(node.get_mesh())
		
	elif node.is_class("CSGShape"):
		print("VectorUtils.get_aabb(node) cannot obtain data from CSGShape, provide a different CSG or node type")
		return null
		
	# //////////////
	# OTHER NODES
	elif node.is_class("SpriteBase3D"):
		print("SpriteBase3D not yet available for use with VectorUtils.get_aabb(node).")
		return null
	
	elif node.is_class("CollisionPolygon"):
		print("VectorUtils.get_aabb(node) refuses to use a CollisionPolygon as it wont be used at runtime, use a CollisionShape or literally anything else :D")
		return null
		
	elif node.is_class("CollisionShape"):
		var shape = node.shape()
		
		if shape is BoxShape:
			var ub = Vector3(shape.extents.x / 2, shape.extents.y / 2, shape.extents.z / 2)
			var lb = ub * -1
			return AABB(lb, ub)
			
		elif shape is CapsuleShape:
			var ub = Vector3(shape.radius, shape.radius, (shape.radius / 2) + shape.height)
			var lb = ub * -1
			return AABB(lb, ub)
		
		elif shape is ConcavePolygonShape:
			return get_vertex_pool_aabb(shape.get_faces())
			
		elif shape is ConvexPolygonShape:
			return get_vertex_pool_aabb(shape.get_points())
			
		elif shape is CylinderShape:
			var ub = Vector3(shape.radius, shape.height / 2, shape.radius)
			var lb = ub * -1
			return AABB(lb, ub)
			
		elif shape is PlaneShape:
			print("Really?  REALLY?  VectorUtils.get_aabb(node) refuses to use a PlaneShape, choose literally anything else plz.")
			return
			
		elif shape is RayShape:
			return
			
		elif shape is SphereShape:
			var ub = Vector3(shape.radius, shape.radius, shape.radius)
			var lb = ub * -1
			return AABB(lb, ub)
		
	
	return null
	
	
# Gets the AABB of any given Mesh.
static func get_mesh_aabb(mesh):
	
	if mesh is Mesh:
		var vertex_pool = mesh.get_faces()
		var v_size = vertex_pool.size()
		
		if v_size == 0:
			return AABB(Vector3(0, 0, 0), Vector3(0, 0, 0))
			
		#var i = 0
		var lb = Vector3(0, 0, 0)
		var ub = Vector3(0, 0, 0)
			
		for vertex in vertex_pool:
			if vertex.x < lb.x:
				lb.x = vertex.x
			if vertex.y < lb.y:
				lb.y = vertex.y
			if vertex.z < lb.z:
				lb.z = vertex.z
				
			if vertex.x > ub.x:
				ub.x = vertex.x
			if vertex.y > ub.y:
				ub.y = vertex.y
			if vertex.z > ub.z:
				ub.z = vertex.z
		
		return AABB(lb, ub-lb)
		
	else:
		return null

# Get an AABB from a line segment.	
static func get_2d_segment_aabb(start : Vector2, end : Vector2) -> Array:
	var lb = start
	var ub = end
	
	if start.x > end.x:
		lb.x = end.x
		ub.x = start.x
	if start.y > end.y:
		lb.y = end.y
		ub.y = start.y
		
	return([lb, ub])

# Get an AABB from any vertex pool.	
static func get_vertex_pool_aabb(vertex_pool):
	
	var v_size = vertex_pool.size()
	
	if v_size == 0:
		return AABB(Vector3(0, 0, 0), Vector3(0, 0, 0))
		
	#var i = 0
	var lb = Vector3(0, 0, 0)
	var ub = Vector3(0, 0, 0)
		
	for vertex in vertex_pool:
		if vertex.x < lb.x:
			lb.x = vertex.x
		if vertex.y < lb.y:
			lb.y = vertex.y
		if vertex.z < lb.z:
			lb.z = vertex.z
			
		if vertex.x > ub.x:
			ub.x = vertex.x
		if vertex.y > ub.y:
			ub.y = vertex.y
		if vertex.z > ub.z:
			ub.z = vertex.z
	
	return AABB(lb, ub-lb)
	
	
# Return 6 "face points" that surround a given AABB, used for getting handles.
# ORDER: -X, +X, -Y, +Y, -Z, +Z
static func get_aabb_boundary_points(aabb: AABB) -> Array:
	
	var half_x = aabb.position.x + aabb.size.x / 2
	var half_y = aabb.position.y + aabb.size.y / 2
	var half_z = aabb.position.z + aabb.size.z / 2
	
	var x_minus = Vector3(aabb.position.x, half_y, half_z)
	var x_plus = Vector3(aabb.position.x + aabb.size.x, half_y, half_z)
	
	var y_minus = Vector3(half_x, aabb.position.y, half_z)
	var y_plus = Vector3(half_x, aabb.position.y + aabb.size.y, half_z)
	
	var z_minus = Vector3(half_x, half_y, aabb.position.z )
	var z_plus = Vector3(half_x, half_y, aabb.position.z + aabb.size.z)
	
	return [x_minus, x_plus, y_minus, y_plus, z_minus, z_plus]
	

# Checks if two Vector2 types have their bounding boxes intersect.
static func do_vector_bounds_intersect(a : Array, b : Array) -> bool:
	
	return a[0].x <= b[1].x && a[1].x >= b[0].x && a[0].y <= b[1].y && a[1].y >= b[0].y

# Checks if a single point lies on a segment.
static func is_point_on_segment(seg_start : Vector2, seg_end : Vector2, point : Vector2, error_margin : float) -> bool:
	
	var x_end = Vector2(seg_end.x - seg_start.x, seg_end.y - seg_start.y)
	var point_idk = Vector2(point.x - seg_start.x, point.y - seg_start.y)
	
	var result = x_end.cross(point_idk)
	return abs(result) < error_margin # the margin of error, 0 = perfect touch

# Checks if the point is on the right of the given segment.
static func is_point_right_of_segment(seg_start : Vector2, seg_end : Vector2, point: Vector2) -> bool:
	
	var x_end = Vector2(seg_end.x - seg_start.x, seg_end.y - seg_start.y)
	var point_idk = Vector2(point.x - seg_start.x, point.y - seg_start.y)
	
	return x_end.cross(point_idk) < 0

# Checks if the first segment (interpreted as a ray) intersects the second segment
static func check_ray_segment_intersection(segment_as_ray : Array, ray_2 : Array):
	
	var a_on_line = is_point_on_segment(segment_as_ray[0], segment_as_ray[1], ray_2[0], 0.001)
	var b_on_line = is_point_on_segment(segment_as_ray[0], segment_as_ray[1], ray_2[1], 0.001)
	var a_check = is_point_right_of_segment(segment_as_ray[0], segment_as_ray[1], ray_2[0])
	var b_check = is_point_right_of_segment(segment_as_ray[0], segment_as_ray[1], ray_2[1])
	
	return a_on_line || b_on_line || (a_check != b_check) 
	


# Checks to see if two segments intersect with each other.  
# True if yes, False if no.
static func check_segment_intersection(line_1 : Array, line_2 : Array) -> bool:
	var aabb_1 = get_2d_segment_aabb(line_1[0], line_1[1])
	var aabb_2 = get_2d_segment_aabb(line_2[0], line_2[1])
	
	var bounds_check = do_vector_bounds_intersect(aabb_1, aabb_2)
	if bounds_check == false:
		return false
		
	var ray_check_1 = check_ray_segment_intersection(line_1, line_2)
	var ray_check_2 = check_ray_segment_intersection(line_2, line_1)
	
	return (bounds_check && ray_check_1 && ray_check_2)
	




# Checks to see if a collection of segments intersect with each other.
# If any one of them does, returns true.  Otherwise returns false
static func find_segment_array_intersection(segments : Array):
	
	# gotta have some altered functions to compensate for the fact that each segment
	# connects to each other
	
	var segments_pool = segments.duplicate()
	
	while segments_pool.size() > 1:
		
		var segment_target = segments_pool[0]
		var other_segments = segments_pool.duplicate()
		other_segments.remove(0)
		
		for segment_match in other_segments:
			
			if check_segment_intersection(segment_target, segment_match):
				return true
		
		segments_pool.remove(0)
	
	return false

# Checks to see if the polygon vectors provided intersect with each other.
# If any one of them does, returns true.  Otherwise returns false
static func find_polygon_2d_intersection(points : Array):
	
	var points_pool = points.duplicate()
	
	# This is just a convenience function, sort the points into segment sets
	var segments = {}
	var i = 0
	while i != points_pool.size():
		var i_2 = loop_int(i + 1, 0, points_pool.size() - 1)
		segments[i] = [points_pool[i], points_pool[i_2]]
		i += 1
	
	# Walk through them like normal segments, apart from ones that are attached to the target.
	i = 0
	while segments.size() > 2:
		
		var segment_target = segments[i]
		var other_segments = segments.duplicate()
		other_segments.erase(i)
		
		for segment_match_index in other_segments.keys():
			var segment_match = other_segments[segment_match_index]
			var result = false
			
			# If we're in the first match, we need to avoid their shared point from being matched
			if segment_match_index == i + 1:
				var left_line_check = is_point_on_segment(segment_target[0], segment_target[1], segment_match[1], 0.001)
				var right_line_check = is_point_on_segment(segment_match[0], segment_match[1], segment_target[0], 0.001)
				
				if left_line_check and right_line_check:
					result = true
				
			elif ((segment_match_index == segments.size() - 1) && i == 0):
				var left_line_check = is_point_on_segment(segment_target[0], segment_target[1], segment_match[0], 0.001)
				var right_line_check = is_point_on_segment(segment_match[0], segment_match[1], segment_target[1], 0.001)
				
				if left_line_check and right_line_check:
					result = true
				
			else:
				result = check_segment_intersection(segment_target, segment_match)
				
			if result:
				return true
		
		segments.erase(i)
		i += 1
	
	return find_segment_array_intersection(segments)

# Get the maximum and minimum range on a set of Vector3 values.
static func get_vector3_ranges(vectors : Array) -> Dictionary:
	
	var vector_search = vectors.duplicate()
	var first = vector_search.pop_front()
	
	var max_range = first
	var min_range = first
	
	while vector_search.size() != 0:
		var v_target = vector_search.pop_front()
		
		if max_range.x < v_target.x:
			max_range.x = v_target.x
			
		if max_range.y < v_target.y:
			max_range.y = v_target.y
		
		if max_range.z < v_target.z:
			max_range.z = v_target.z
			
		if min_range.x > v_target.x:
			min_range.x = v_target.x
			
		if min_range.y > v_target.y:
			min_range.y = v_target.y
			
		if min_range.z > v_target.z:
			min_range.z = v_target.z
			
	return {'max' : max_range, 'min' : min_range}
	
# Get the maximum and minimum range on a set of Vector3 values.
static func get_vector2_ranges(vectors : Array) -> Dictionary:
	
	var vector_search = vectors.duplicate()
	var first = vector_search.pop_front()
	
	var max_range = first
	var min_range = first
	
	while vector_search.size() != 0:
		var v_target = vector_search.pop_front()
		
		if max_range.x < v_target.x:
			max_range.x = v_target.x
			
		if max_range.y < v_target.y:
			max_range.y = v_target.y
			
		if min_range.x > v_target.x:
			min_range.x = v_target.x
			
		if min_range.y > v_target.y:
			min_range.y = v_target.y
			
	return {'max' : max_range, 'min' : min_range}
	
# Returns the transformation matrix of any given triangle to a transform that can map coordinates on a 2D plane suitable for unwraps.
# NOTE - THIS CURRENTLY DOESN'T WORK
static func get_uv_triangle_transform(vector_array : Array):
	if vector_array.size() > 3 || vector_array.size() < 3:
		print('VectorUtils : get_triangle_transform : Array needs three Vertex values to work, returning...')
		return null
	
	var AB = vector_array[2] - vector_array[0]
	var AC = vector_array[1] - vector_array[0]
	var N = AB.cross(AC)
	
	var unit = AB.normalized()
	var unit_n = N.normalized()
	var V = unit * unit_n
	
	#print('[x] -', x_axis, ' [y] - ', y_axis, ' [z] - ', z_axis)
	var transform = Transform(unit, V, unit_n, vector_array[0])
	return transform.inverse()
	
# Returns the normal for a set of three vertex points.
static func get_triangle_normal(tris : Array) -> Vector3:
	
	var line_a = (tris[1] - tris[0]).normalized()
	var line_b = (tris[2] - tris[0]).normalized()
	return line_a.cross(line_b)
	
	
static func subdivide_edge(start : Vector3, end : Vector3, subdivisions : int) -> Array:
	
	if subdivisions == 0:
		return [start, end]
	
	var results = []
	
	var diff = end - start
	var increment = diff / (subdivisions + 1)
	results.append(start)
	
	for i in subdivisions:
		results.append(start + (increment * (i + 1)))
		
	results.append(end)
	return results
	
	
# Projects an array of Vector3 values onto a single Vector3 value and returns the results
static func project_vector3_array(input_array : Array, projection_vec : Vector3) -> Array:
	
		var projection_result = []
		for vec in input_array:
			var new_vec = vec.project(projection_vec)
			projection_result.append(new_vec)
		
		return projection_result
		
# Transforms an array of Vector3 values into a Transform value and returns the results
static func transform_vector3_array(input_array : Array, transform : Transform) -> Array:
	
		var projection_result = []
		for vec in input_array:
			var new_vec = transform.xform(vec)
			projection_result.append(new_vec)
		
		return projection_result
		
# Converts an array of Vector3 values to Vector2 values, with an input specifying the axis to omit.
static func vector3_to_vector2_array(input_array : Array, axis_target : String, first_axis : String):
	
	if axis_target != 'X' && axis_target != 'Y' && axis_target != 'Z':
		print('vector3_to_vector2_array error : wrong axis target specified. Returning..')
		return null
	if first_axis == axis_target:
		print('vector3_to_vector2_array error : Axis target identical to the first axis specified. Returning..')
		return null
		
	var crunch_results = []
	for vec in input_array:
		if axis_target == 'X':
			if first_axis == 'Y':
				crunch_results.append(Vector2(vec.y, vec.z))
			else:
				crunch_results.append(Vector2(vec.z, vec.y))
		elif axis_target == 'Y':
			if first_axis == 'X':
				crunch_results.append(Vector2(vec.x, vec.z))
			else:
				crunch_results.append(Vector2(vec.z, vec.x))
		elif axis_target == 'Z':
			if first_axis == 'X':
				crunch_results.append(Vector2(vec.x, vec.y))
			else:
				crunch_results.append(Vector2(vec.y, vec.x))
			
	return crunch_results


# Converts an array of Vector2 values to Vector3 values, with an input specifying the axis to remain empty.
static func vector2_to_vector3_array(input_array : Array, empty_axis : String, first_axis : String):
	
	if empty_axis != 'X' && empty_axis != 'Y' && empty_axis != 'Z':
		print('vector2_to_vector3_array error : wrong axis target specified. Returning..')
		return null
	if first_axis != 'X' && first_axis != 'Y':
		print('vector2_to_vector3_array error : wrong first axis specified. Returning..')
		return null
	if first_axis == empty_axis:
		print('vector2_to_vector3_array error : Axis target identical to the first axis specified. Returning..')
		return null
		
	var crunch_results = []
	for vec in input_array:
		if empty_axis == 'X':
			if first_axis == 'X':
				crunch_results.append(Vector3(0, vec.x, vec.y))
			else:
				crunch_results.append(Vector3(0, vec.y, vec.x))
		elif empty_axis == 'Y':
			if first_axis == 'X':
				crunch_results.append(Vector3(vec.x, 0, vec.y))
			else:
				crunch_results.append(Vector3(vec.y, 0, vec.x))
		elif empty_axis == 'Z':
			if first_axis == 'X':
				crunch_results.append(Vector3(vec.x, vec.y, 0))
			else:
				crunch_results.append(Vector3(vec.y, vec.x, 0))
			
	return crunch_results
	
	
# Combines an array of arrays into a list of the objects inside them.
static func combine_arrays(array_input : Array) -> Array:
	
	var results = []
	for input in array_input:
		
		if input is Array:
			for item in input:
				results.append(item)
				
	return results
	

# Flips the order of items in an array.
static func reverse_array(array_input : Array) -> Array:
	
	var results = []
	var i = array_input.size() - 1
	while i >= 0:
		results.append(array_input[i])
		i -= 1
		
	return results
	
# Shifts the order of all elements in the array forwards or backwards by the given amount.  
# Items that are pushed off one end of the array are re-added to the other end.
static func push_array_order(array_input : Array, shift_amount : int) -> Array:
	
	if shift_amount == 0:
		return array_input.duplicate()
	
	var results = array_input.duplicate()
	
	if shift_amount < 0:
		
		var i = 0
		while i > shift_amount:
			var item = results.pop_front()
			results.push_back(item)
			i -= 1
			
	elif shift_amount > 0:
		
		var i = 0
		while i > shift_amount:
			var item = results.pop_baack()
			results.push_front(item)
			i += 1
	
	return results
	
	
# "Loops" the variable to the max value if lower than the minimum, and vice-versa.  
# The difference determines how much it loops back or forward.
static func loop_int(input : int, min_value : int, max_value : int) -> int:
	
	var result = input
	if result < min_value:
		var diff = result - min_value + 1
		result = max_value + diff
	elif result > max_value:
		var diff = max_value - result + 1
		result = min_value - diff
		
	return result
	
# "Bends" the variable above or below either bound by the amount it breached said bounds.
static func bend_int(input : int, min_value : int, max_value: int) -> int:
	
	var result = input
	if result < min_value:
		var diff = min_value - input
		result = min_value + diff
	elif result > max_value:
		var diff = input - max_value
		result = max_value - diff
	
	return result

# Projects a screen point onto a 3D plane positioned using plane_origin, plane_axis_x and plane_axis_y
static func project_cursor_to_plane(camera : Camera, point : Vector2, world_matrix : Transform, plane_origin : Vector3, plane_axis_x : Vector3, plane_axis_y : Vector3):
	
	# Get the camera view axis.
	var snap_axis_point = plane_axis_x + plane_origin
	var camera_basis = camera.get_camera_transform().basis.z
	
	# If the camera basis and any plane axis are equal, quit early.
	if camera_basis == plane_axis_x || camera_basis == plane_axis_y:
#		print("camera basis equal to snap axis, leaving early")
		return null
	
	var projection_plane = Plane(plane_axis_x + plane_origin, plane_origin, plane_axis_y + plane_origin)
	
	# Setup the projection
	var ray_origin = camera.project_ray_origin(point)
	var ray_dir = camera.project_ray_normal(point)
	ray_origin = world_matrix.xform_inv(ray_origin)
	ray_dir = world_matrix.basis.xform_inv(ray_dir)
	
	# PROJECT
	var intersect_pos = projection_plane.intersects_ray(ray_origin, ray_dir)
	if not intersect_pos: 
#		print("no projection point found, returning early.")
		return null
	
	return intersect_pos

# Gets the signed angle between three points (AKA two vectors)
static func get_signed_angle(point_1 : Vector2, point_2 : Vector2, point_3 : Vector2) -> float:
		var vec_a = (point_2 - point_1).normalized()
		var vec_b = (point_3 - point_2).normalized()
		
		var dot = vec_a.dot(vec_b)
		var cross = (vec_a.x * vec_b.y) - (vec_a.y * vec_b.x)
		return atan2(cross, dot)


