#tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Used by Onyx exclusively to fetch the area of any kind of type that has one, returning an AABB type.


# ////////////////////////////////////////////////////////////
# BASE FUNCTION

# Gets the area of the node if possible, only if it's a collision type.  If not, returns null.
func get_collision_bounds(node):
	
	if node is CollisionShape:
		return extract_from_collision_shape(node)
		
	if node is CollisionPolygon:
		return extract_from_collision_polygon(node)
		
	if node is CSGShape:
		if node.use_collision == true:
			return extract_from_csg(node)
		
	return null
	
	
# ////////////////////////////////////////////////////////////
# GETTERS

# Gets the area of any node if possible.  If not, returns null.
func get_node_bounds(node):
	
	if node is CollisionShape:
		return extract_from_collision_shape(node)
		
	if node is CollisionPolygon:
		return extract_from_collision_polygon(node)
		
	if node is MeshInstance:
		return extract_from_mesh_instance(node)
		
	if node is MultiMeshInstance:
		return extract_from_multi_mesh_instance(node)
		
	if node is CSGShape:
		return extract_from_csg(node)
		
	return null
	

func extract_from_collision_shape(node):
	
	if node is CollisionShape:
		
		var shape = node.get_shape()
		
		if shape is BoxShape:
			# Get the points for the upper and lower bounds.
			var extents = shape.get_extents()
			var lb = (extents / 2) * -1
			var ub = Vector3((extents.x / 2), (extents.y / 2), (extents.z / 2))
			lb = lb + node.translation
			ub = ub + node.translation
			
			# Apply the transform to them
			var transform = node.global_transform
			lb = transform.xform(lb)
			ub = transform.xform(ub)
			
			# Return!
			return AABB(lb, ub - lb)
			
			
		if shape is CapsuleShape || shape is CylinderShape:
			var radius = node.get_radius()
			var height = node.get_height()
			var lb = Vector3((radius / 2) * -1, height * -1, (radius / 2) * -1)
			var ub = Vector3(radius, height * 2, radius)
			lb = lb + node.translation
			ub = ub + node.translation
			
			# Apply the transform to them
			var transform = node.global_transform
			lb = transform.xform(lb)
			ub = transform.xform(ub)
			
			# Return!
			return AABB(lb, ub - lb)
			
			
		if shape is ConcavePolygonShape:
			var faces = node.get_faces()
			var lb = Vector3()
			var ub = Vector3()
		
			for point in faces:
				if point.x > ub.x:
					ub.x = point.x
				if point.y > ub.y: 
					ub.y = point.y
				if point.z > ub.z: 
					ub.z = point.z
					
				if point.x < lb.x:
					lb.x = point.x
				if point.y < lb.y:
					lb.y = point.y
				if point.z < lb.z: 
					lb.z = point.z
		
			# Apply the transform to them
			var transform = node.global_transform
			lb = transform.xform(lb)
			ub = transform.xform(ub)
			
			# Return!
			return AABB(lb, ub - lb)
			
			
		if shape is ConvexPolygonShape:
			var points = node.get_points()
			var lb = Vector3()
			var ub = Vector3()
		
			for point in points:
				if point.x > ub.x:
					ub.x = point.x
				if point.y > ub.y: 
					ub.y = point.y
				if point.z > ub.z: 
					ub.z = point.z
					
				if point.x < lb.x:
					lb.x = point.x
				if point.y < lb.y:
					lb.y = point.y
				if point.z < lb.z: 
					lb.z = point.z
		
			# Apply the transform to them
			var transform = node.global_transform
			lb = transform.xform(lb)
			ub = transform.xform(ub)
			
			# Return!
			return AABB(lb, ub - lb)
			
#		if shape is CylinderShape:
#			pass
			
		if shape is PlaneShape:
			pass
			
		if shape is SphereShape:
			var radius = shape.get_radius()
			var lb = Vector3((radius / 2) * -1, (radius / 2) * -1, (radius / 2) * -1)
			var ub = Vector3(radius, radius, radius)
			
			# Apply the transform to them
			var transform = node.global_transform
			lb = transform.xform(lb)
			ub = transform.xform(ub)
			
			# Return!
			return AABB(lb, ub - lb)
		
	return null
	
	

# This requires some simple filtering.
func extract_from_collision_polygon(node):
	
	if node is CollisionPolygon:
		var lb = Vector3()
		var ub = Vector3()
		
		var depth = node.get_depth()
		
		# define the points in 3D terms.
		var poly_points = []
		for point in node.get_polygon():
			var vertex = Vector3(point.x, point.y, (depth / 2) * -1)
			poly_points.append(vertex)
			
		for point in poly_points:
			var vertex = Vector3(point.x, point.y, point.z * -1)
			poly_points.append(vertex)
			
		# build a geometric model and apply it in world space
		var world_space = node.global_transform
		var world_space_points = []
		for point in poly_points:
			var vertex = world_space.xform(point)
			world_space_points.append(vertex)
			
		# now build the AABB
		for point in points:
			if point.x > ub.x:
				ub.x = point.x
			if point.y > ub.y: 
				ub.y = point.y
			if point.z > ub.z: 
				ub.z = point.z
				
			if point.x < lb.x:
				lb.x = point.x
			if point.y < lb.y:
				lb.y = point.y
			if point.z < lb.z: 
				lb.z = point.z
		
		return AABB(lb, ub - lb)
		
	return null
	

# This and all the types below belong to VisualInstance, and thus get a bounding box automatically.
func extract_from_mesh_instance(node):
	
	if node is MeshInstance:
		return node.get_transformed_aabb()
	
	return null
	
func extract_from_multi_mesh_instance(node):
	
	if node is MultiMeshInstance:
		return node.get_transformed_aabb()
	
	return null
	
func extract_from_csg(node):
	
	if node is CSGShape:
		return node.get_transformed_aabb()
	
	return null
