#tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Used by Onyx exclusively to fetch a set of geometry from a collision or geometric type.
# The geometry returned will always be defined as a face_dictionary type.

var FaceDictionary = load("res://addons/onyx/utilities/face_dictionary.gd").new()

# Attempts to extract collision information from the node as a standard set of geometric faces.
func get_collision_as_geometry(node):
	
	if node is CollisionShape:
		return extract_from_collision_shape(node)
		
	if node is CollisionPolygon:
		return extract_from_collision_polygon(node)
		
	if node is CSGShape:
		if node.use_collision == true:
			return extract_from_csg(node)
	
	return null
	
func extract_from_collision_shape(node):
	
	if node is CollisionShape:
		
		var shape = node.get_shape()
		
		if shape is BoxShape:
			
			# Define an upper and lower point from the extents
			var extents = shape.get_extents()
			var lb = Vector3((extents.x / 2) * -1, (extents.y / 2) * -1, (extents.z / 2) * -1)
			var ub = Vector3((extents.x / 2), (extents.y / 2), (extents.z / 2))
			lb = lb + node.translation
			ub = ub + node.translation
			
			# Generate a set of faces using it
			var face_set = FaceDictionary.build_cuboid(ub, lb)
			
			# Apply the world transform to it.
			face_set.apply_transform(node.global_transform)
			
			# Return it!
			return face_set
			
			
		if shape is CapsuleShape || shape is CylinderShape:
			var radius = node.get_radius()
			var height = node.get_height()
			var position = Vector3((radius / 2) * -1, height * -1, (radius / 2) * -1)
			var size = Vector3(radius, height * 2, radius)
			return AABB(position, size)
			
			
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
		
			var size = ub - lb
			return AABB(lb, size)
			
			
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
		
			var size = ub - lb
			return AABB(lb, size)
			
#		if shape is CylinderShape:
#			pass
			
		if shape is PlaneShape:
			pass
			
		if shape is SphereShape:
			var radius = shape.get_radius()
			var position = Vector3((radius / 2) * -1, (radius / 2) * -1, (radius / 2) * -1)
			var size = Vector3(radius, radius, radius)
			return AABB(position, size)
		
	return null
	

func extract_from_collision_polygon(node):
	pass
	
	
func extract_from_csg(node):
	pass