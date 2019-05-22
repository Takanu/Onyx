#tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Used by Onyx exclusively to fetch a set of geometry from a collision or geometric type.
# The geometry returned will be defined as a face_dictionary or triangle_array type.

var FaceDictionary = load("res://addons/onyx/utilities/face_dictionary.gd")
var TriangleArray = load("res://addons/onyx/utilities/triangle_array.gd")

# ////////////////////////////////////////////////////////////
# BASE FUNCTION

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
	
	
# ////////////////////////////////////////////////////////////
# GETTERS
	
# Extracts and returns geometric information from the CollisionShape type.
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
			var face_set = FaceDictionary.new()
			face_set.build_cuboid(ub, lb)
			
			# Apply the world transform to it.
			face_set.apply_transform(node.global_transform)
			
			# Return it!
			return face_set
			
			
		if shape is CapsuleShape:
			
			# build a capsule mesh that fits the shape
			pass
			
			
		if shape is ConcavePolygonShape:
			
			print("Getting ConcavePolygonShape geometry...")
			var faces = node.get_faces()
			print("FACES: ", faces)
			
			var triangles = TriangleArray.new()
			triangles.add_triangle_vertices(faces)
			
			return triangles
			
			
		if shape is ConvexPolygonShape:
			print("Getting ConcavePolygonShape geometry...")
			var points = node.get_points()
			print("POINTS: ", points)
			
			return null
			
		if shape is CylinderShape:
			
			# build a cylindrical mesh that fits the shape
			pass
			
			
		# planes just encompass everything, they don't fit well into the scope of Onyx currently.
		if shape is PlaneShape:
			pass
			
			
		if shape is SphereShape:
			
			# build a cylindrical mesh that fits the shape
			pass
		
		
	return null
	
# Extracts and returns geometric information from the CollisionPolygon type.
func extract_from_collision_polygon(node):
	
	if node is CollisionPolygon:
		
		var lb = Vector3()
		var ub = Vector3()
		
		var depth = node.get_depth()
		
		# define the points in 3D terms.
		var poly_points = []
		var normal = Vector3(0, 0, 1)
		for point in node.get_polygon():
			var vertex = Vector3(point.x, point.y, (depth / 2) * -1)
			poly_points.append(vertex)
			
			
		# build a geometric model and apply it in world space
		var world_space = node.global_transform
		var world_space_normal = world_space.xform(normal)
		var world_space_points = []
		
		for point in poly_points:
			var vertex = world_space.xform(point)
			world_space_points.append(vertex)
			
		# build the capped 
			
			
		# build faces that fit the polygon
		var face_set = FaceDictionary.new()
		face_set.build_polygon_extrusion(
				
				
		
			
			
	return null
	
# Extracts and returns geometric information from the CSGPrimitive type.
func extract_from_csg(node):
	
	if node is CSGPolygon:
		
		match node.mode:
			
			CSGPolygon.Mode.DEPTH:
				var lb = Vector3()
				var ub = Vector3()
				
				var depth = node.get_depth()
				
				# define the points in 3D terms.
				var poly_points = []
				var normal = Vector3(0, 0, 1)
				for point in node.get_polygon():
					var vertex = Vector3(point.x, point.y, (depth / 2) * -1)
					poly_points.append(vertex)
					
					
				# build a geometric model and apply it in world space
				var world_space = node.global_transform
				var world_space_normal = world_space.xform(normal)
				var world_space_points = []
				
				for point in poly_points:
					var vertex = world_space.xform(point)
					world_space_points.append(vertex)
					
				# build the capped 
					
					
				# build faces that fit the polygon
				var face_set = FaceDictionary.new()
				face_set.build_polygon_extrusion(
				
				
			CSGPolygon.Mode.SPIN:
				pass
				
			
		
		
			
			
	return null
	
	pass