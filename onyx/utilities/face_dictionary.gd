tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Used for the generation, storage and rendering of geometry with ImmediateGeometry, to compliment Onyx.

# {"name": [[vertices], [colors], [tangents], [uv], normal]}

# All vertices have to be defined in a circular order, to be rendered using Mesh.PRIMITIVE_TRIANGLE_FAN
# Any additions that dont fit this schema will be rejected.
# Any additions with the same name as an old addition will be over-written.

# Any type you dont want to provide should be left empty, vertices and a face normal are required however.


# ////////////////////////////////////////////////////////////
# PROPERTIES
var faces = {}

var utilities = preload("res://addons/onyx/utilities/face_utilities.gd").new()

# ////////////////////////////////////////////////////////////
# ADDITIONS

# Adds a new face with a name, list of vertices and normal.
func add_face(face_name, vertices, colors, tangents, uvs, normal):
	
	if vertices == null:
		return
	
	if vertices.size() < 2:
		return
		
	if normal == null:
		return
	
	faces[face_name] = [vertices, colors, tangents, uvs, normal]
	
	
# ////////////////////////////////////////////////////////////
# GENERATE / RENDER

# Adds a new face to the list with a nane, position, rotation/normal of the face and the intended size.
func generate_square_face(face_name, face_position, normal, face_size):
	
	# Build a square face with a normal of 0, 0, 1
	var v_range = float(face_size) / 2.0
	var vertices_normal = Vector3(0, 0, 1).normalized()
	var vertex_1 = Vector3(-v_range, -v_range, 0)
	var vertex_2 = Vector3(v_range, -v_range, 0)
	var vertex_3 = Vector3(v_range, v_range, 0)
	var vertex_4 = Vector3(-v_range, v_range, 0)
	
	var vertices = [vertex_1, vertex_2, vertex_3, vertex_4]
	var transformed_vertices = []
	
	# Build a basis and rotate it to the normal we desire.
	var dot = vertices_normal.dot(normal)
	var cross = vertices_normal.cross(normal).normalized()
	
	# If the face angle is where we want it, do nothing.
	if dot == 1 || dot == -1:
		#print("No need to rotate!") 
		for vertex in vertices:
			var t_vertex = vertex + face_position
			transformed_vertices.append(t_vertex)

	# Otherwise rotate it!
	else:
		#("Rotating!")
		var matrix = Basis()
		matrix = matrix.rotated(cross, PI*((dot + 1) / 2))
		
		for vertex in vertices:
			var t_vertex = matrix.xform(vertex)
			t_vertex = t_vertex + face_position
			transformed_vertices.append(t_vertex)
			
			
	#print("Final vertices: ", transformed_vertices)
	var current_face = [transformed_vertices, [], [], [], normal]
	faces[face_name] = sort_face(current_face)


# Renders the available geometry using a provided ImmediateGeometry node.
func render_geometry(geom):
	
	geom.clear()
	
	for key in faces:
		var face = faces[key]
		var vertices = face[0]
		var colors = face[1]
		var tangents = face[2]
		var uvs = face[3]
		var normal = face[4]
		
		geom.begin(Mesh.PRIMITIVE_TRIANGLE_FAN, null)
		
		for i in vertices.size():
			
			if colors.size() > i:
				geom.set_color(colors[i])
				
			if tangents.size() > i:
				geom.set_tangent(tangents[i])
				
			if uvs.size() > i:
				geom.set_uv(uvs[i])
				
			geom.set_normal(normal)
			geom.add_vertex(vertices[i])
		
		geom.end()
			

# ////////////////////////////////////////////////////////////
# GETTERS

# Returns just the faces as arrays of vertices that make up each face.
func get_face_vertices():
	
	var results = []
	for key in faces:
		var face = faces[key]
		results.append(face[0])
	
	return results


# Returns the center face of the defined face.
func get_centre_point(for_face):
	
	if faces[for_face]:
		var vertices = faces[for_face][0]
		var total = Vector3()
		
		for vertex in vertices:
			total += vertex
			
		total = total / vertices.size()
		
		return total
	
	return null
	
# Returns the faces stored as an array of triangle arrays.
func get_triangles():
	
	var results = PoolVector3Array()
	
	for i in faces:
		var face = faces[i]
		var vertices = face[0]
		
		results.append(vertices[0])
		results.append(vertices[1])
		results.append(vertices[2])
		results.append(vertices[3])
		
	#print("TRIANGLES: ", results.size())
	return results
	

# Returns the faces as pairs of edge lines that lie around the face.
func get_face_edges():
	
	var results = PoolVector3Array()
	
	for i in faces:
		var face = faces[i]
		var vertices = face[0]
		
		results.append(vertices[0])
		results.append(vertices[1])
		results.append(vertices[2])
		results.append(vertices[3])
		
		results.append(vertices[0])
		results.append(vertices[2])
		results.append(vertices[1])
		results.append(vertices[3])
		
	return results
	
	
# Returns the center of all currently held faces.
func get_all_centre_points():
	
	var results = PoolVector3Array()
	
	for i in faces:
		var face = faces[i]
		var vertices = face[0]
		var total = Vector3()
		
		for vertex in vertices:
			total += vertex
			
		total = total / vertices.size()
		
		results.append(total)
	
	#print("RETURN: ", results)
	return results
	
# ////////////////////////////////////////////////////////////
# BUILDERS

# Replaces any geometry held with a cuboid that fits inside a maximum and minimum point.
func build_cuboid(max_point, min_point):
	
	var cube_faces = []
	
	# Build 8 vertex points
	var top_x = Vector3(max_point.x, min_point.y, max_point.z)
	var top_xy = Vector3(max_point.x, max_point.y, max_point.z)
	var top_minus_x = Vector3(min_point.x, max_point.y, max_point.z)
	var top_minus_xy = Vector3(min_point.x, min_point.y, max_point.z)
	
	var bottom_x = Vector3(max_point.x, min_point.y, min_point.z)
	var bottom_xy = Vector3(max_point.x, max_point.y, min_point.z)
	var bottom_minus_x = Vector3(min_point.x, max_point.y, min_point.z)
	var bottom_minus_xy = Vector3(min_point.x, min_point.y, min_point.z)
	
	
	var colors = [Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1)]
	
	# X
	faces["x_plus"] = [[top_x, top_xy, bottom_x, bottom_xy], colors, [], [], Vector3(1, 0, 0)]
	faces["x_minus"] = [[top_minus_x, top_minus_xy, bottom_minus_x, bottom_minus_xy], colors, [], [], Vector3(-1, 0, 0)]
	
	# Y
	faces["y_plus"] = [[top_xy, top_minus_x, bottom_xy, bottom_minus_x], colors, [], [], Vector3(0, 1, 0)]
	faces["y_minus"] = [[top_x, top_minus_xy, bottom_x, bottom_minus_xy], colors, [], [], Vector3(0, -1, 0)]
	
	# Z
	faces["z_plus"] = [[top_x, top_xy, top_minus_xy, top_minus_x], colors, [], [], Vector3(0, 0, 1)]
	faces["z_minus"] = [[bottom_x, bottom_xy, bottom_minus_xy, bottom_minus_x], colors, [], [], Vector3(0, 0, -1)]
	
	return faces
	
	
# Builds a cylinder given the height, width and number of points.  
# Returns an array in the format of face_array.
func build_cylinder(height, radius, points, rings):
	
	var results = []
	
	# generate the initial circle
	var angle_step = (2.0 * PI) / points
	var current_angle = 0.0
	
	var circle_points = []
	
	while current_angle < 2 * PI:
		
		# get coordinates
		var x = radius * cos(current_angle)
		var y = radius * sin(current_angle)
		circle_points.append(Vector3(x, y, 0))
		
		current_angle += angle_step
	
	var circle_normals = []
	
	
	# get the normals of all current edges
	for i in circle_points.size():
	
		var a = circle_points[i]
		var b = Vector3()
		
		if i == circle_points.size() - 1:
			b = circle_points[0]
		else:
			b = circle_points[i + 1]
			
		var line_a = (b - a).normalized()
		var line_b = Vector3(0, 1, 0)
		var face_normal = line_a.cross(line_b)
		
		circle_normals.append(face_normal)
		
	
	# based on the number of rings, build the faces.
	
	pass
	

# ////////////////////////////////////////////////////////////
# HELPERS

# Ensures that the face provided is ordered in a way that follows the intended face direction.
func sort_face(face):
	
	var face_vertices = face[0]
	var intended_face_direction = face[4]
	
	# get the winding order 
	var x_vector = face_vertices[1] - face_vertices[0]
	var y_vector = face_vertices[2] - face_vertices[0]
	var z_vector = x_vector.cross(y_vector)
	var transform = Transform(x_vector, y_vector, z_vector, Vector3(0, 0, 0))
	
	var inverse_transform = transform.inverse()
	var result = inverse_transform * intended_face_direction
	var new_face = []
	
	# If the result is below 0, we need to invert the order of all face components.
	if result.z > 0:
		
		var new_vertices = face[0].invert
		var new_colors = face[1].invert
		var new_tangents = face[2].invert
		var new_uvs = face[3].invert
		
		new_face = [new_vertices, new_colors, new_tangents, new_uvs, face[4]]
	
	# Otherwise, we can just return the face as is.
	else:
		new_face = face
	
	return new_face


	
# ////////////////////////////////////////////////////////////
# CLEAN-UP

# Clear all faces
func clear():
	faces = {}