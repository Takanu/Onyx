tool
extends Node
class_name OnyxUtils

# ////////////////////////////////////////////////////////////
# INFO
# Used to perform additional common operations across 


# Returns the AABB of any given node.  May return nothing if the node provided has no data to extrapolate bounds from.
static func get_aabb(node):
	
	# //////////////
	# MESH NODES
	if node is Mesh:
		return get_mesh_aabb(node)
		
	elif node is MultiMesh:
		return node.get_aabb()
		
	elif node is MeshInstance:
		return get_mesh_aabb(node.get_mesh())
		
	elif node is ImmediateGeometry:
		print("onyx_utils.get_aabb(node) cannot obtain data from ImmediateGeometry, provide a face_dictionary instead.")
		return
		
	# //////////////
	# CSG NODES
	elif node is CSGBox:
		var ub = Vector3(node.width / 2, node.height / 2, node.depth / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node is CSGCylinder:
		var ub = Vector3(node.radius / 2, node.height / 2, node.radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node is CSGPolygon:
		print("onyx_utils.get_aabb(node) cannot obtain data from CSGPolygon, im just not going to go there right now.")
		return
		
	elif node is CSGSphere:
		var ub = Vector3(node.radius / 2, node.radius / 2, node.radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node is CSGTorus:
		var ub = Vector3(node.outer_radius / 2, node.outer_radius / 2, node.outer_radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
	
	elif node is CSGMesh:
		return get_mesh_aabb(node.get_mesh())
		
	elif node is CSGShape:
		print("onyx_utils.get_aabb(node) cannot obtain data from CSGShape, provide a different CSG or node type")
		return
		
	# //////////////
	# OTHER NODES
	elif node is SpriteBase3D:
		print("SpriteBase3D not yet available for use with onyx_utils.get_aabb(node).")
		return
	
	elif node is CollisionPolygon:
		print("onyx_utils.get_aabb(node) refuses to use a CollisionPolygon as it wont be used at runtime, use a CollisionShape or literally anything else :D")
		return
		
	elif node is CollisionShape:
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
			return get_vertex_aabb(shape.get_faces())
			
		elif shape is ConvexPolygonShape:
			return get_vertex_aabb(shape.get_points())
			
		elif shape is CylinderShape:
			var ub = Vector3(shape.radius, shape.height / 2, shape.radius)
			var lb = ub * -1
			return AABB(lb, ub)
			
		elif shape is PlaneShape:
			print("Really?  REALLY?  onyx_utils.get_aabb(node) refuses to use a PlaneShape, choose literally anything else plz.")
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

# Get an AABB from any vertex pool.	
static func get_vertex_aabb(vertex_pool):
	
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
		print('OnyxUtils : get_triangle_transform : Array needs three Vertex values to work, returning...')
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
	
# "Loops" the variable to the max value if lower than the minimum, and vice-versa.  The difference determines how much it loops back or forward.
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