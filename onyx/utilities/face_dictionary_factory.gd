tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Used to generate common shapes for the face_dictionary type.

# face_dictionary tuple format:
# {"name": [[vertices], [colors], [tangents], [uv], normal]}
	
	
const TriArray = preload("res://addons/onyx/utilities/triangle_array.gd")
const TWO_PI = PI * 2

# ////////////////////////////////////////////////////////////
# BUILDERS

# Replaces any geometry held with a cuboid that fits inside a maximum and minimum point.
func build_cuboid(face_dict, max_point, min_point):
	
	face_dict.faces.clear()
	
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
	face_dict.faces["x_plus"] = [[top_x, top_xy, bottom_xy, bottom_x], colors, [], [], Vector3(1, 0, 0)]
	face_dict.faces["x_minus"] = [[top_minus_x, top_minus_xy, bottom_minus_xy, bottom_minus_x], colors, [], [], Vector3(-1, 0, 0)]
	
	# Y
	face_dict.faces["y_plus"] = [[top_xy, top_minus_x, bottom_minus_x, bottom_xy], colors, [], [], Vector3(0, 1, 0)]
	face_dict.faces["y_minus"] = [[top_x, bottom_x, bottom_minus_xy, top_minus_xy], colors, [], [], Vector3(0, -1, 0)]
	
	# Z
	face_dict.faces["z_plus"] = [[top_x, top_minus_xy, top_minus_x, top_xy], colors, [], [], Vector3(0, 0, 1)]
	face_dict.faces["z_minus"] = [[bottom_x, bottom_xy, bottom_minus_x, bottom_minus_xy], colors, [], [], Vector3(0, 0, -1)]
	
	return face_dict
	
	
	
func build_sphere(t_dict, height, x_width, z_width, segments, height_segments, position, slice_from, slice_to, hemisphere, generate_cap, generate_ends):
	
	# The increments that vertex plotting will be broken up into
	var deltaTheta = PI/height_segments
	var deltaPhi = 2*PI/segments
	
	# The variables used to step through and plot points.
	var theta1 = 0.0
	var theta2 = deltaTheta
	var phi1 = 0.0
	var phi2 = deltaPhi
	
#	print([theta1, theta2, phi1, phi2])
	
	var ring = 0
	while ring < height_segments:
		if ring != 0:
			theta1 += deltaTheta
			theta2 += deltaTheta
			
		var point = 0
			
#		print("thetas: ", theta1, theta2)
#		print("NEW RING===========")
		
		while point <= segments - 1:
			if point != 0:
				phi1 += deltaPhi
				phi2 += deltaPhi
				
			#phi2   phi1
		    # |      |
		    # 2------1 -- theta1
		    # |\ _   |
		    # |    \ |
		    # 3------4 -- theta2
		    #

			# Vertices
			var vertex1 = Vector3(sin(theta2) * cos(phi2) * (x_width/2),  cos(theta2) * (height/2),  sin(theta2) * sin(phi2) * (z_width/2))
    		
			var vertex2 = Vector3(sin(theta1) * cos(phi2) * (x_width/2),  cos(theta1) * (height/2),  sin(theta1) * sin(phi2) * (z_width/2))
			
			var vertex3 = Vector3(sin(theta1) * cos(phi1) * (x_width/2),  cos(theta1) * (height/2),  sin(theta1) * sin(phi1) * (z_width/2))
			
			var vertex4 = Vector3(sin(theta2) * cos(phi1) * (x_width/2),  cos(theta2) * (height/2),  sin(theta2) * sin(phi1) * (z_width/2))
			
			vertex1 += position
			vertex2 += position
			vertex3 += position
			vertex4 += position
			
			if ring == -1:
				t_dict.add_tri([vertex1, vertex3, vertex4], [], [], [], null)
			
			if ring == height_segments:
				t_dict.add_tri([vertex3, vertex1, vertex2], [], [], [], null)
			
			t_dict.add_quad([vertex1, vertex2, vertex3, vertex4], [], [], [], null)
			point += 1
			
		
		ring += 1
			
	return t_dict
	
	
	
# Builds a cylinder given the height, width and number of points.  
# Returns an array in the format of face_array.
func build_cylinder(face_dict, points, height, x_width, y_width, rings, position):
	
	face_dict.faces.clear()
	
	# generate the initial circle
	var angle_step = (2.0 * PI) / points
	var current_angle = 0.0
	
	var circle_points = []
	
	while current_angle < 2 * PI:
		
		# get coordinates
		var x = x_width * cos(current_angle)
		var y = y_width * sin(current_angle)
		circle_points.append(Vector2(x, y))
		
		current_angle += angle_step
		
	build_polygon_extrusion(face_dict, circle_points, height, rings, position, Vector3(0, 1, 0))
	return face_dict
	
	
	
# A three-dimensional triangle extrusion C:
func build_wedge(base_x, base_z, point_width, point_position, position):
	
	#   X---------X  b1 b2
	#	|         |
	#		X---------X   p1 p2
	#	|		  |
	#   X---------X  b3 b4
	
	var tris = TriArray.new()
	
	var base_1 = Vector3(-base_x/2, 0, base_z/2) + position
	var base_2 = Vector3(base_x/2, 0, base_z/2) + position
	
	var base_3 = Vector3(-base_x/2, 0, -base_z/2) + position
	var base_4 = Vector3(base_x/2, 0, -base_z/2) + position
	
	var point_1 = Vector3(-point_width/2 + point_position.x, point_position.y, point_position.z) + position
	var point_2 = Vector3(point_width/2 + point_position.x, point_position.y, point_position.z) + position
	
	tris.add_tri([base_3, point_1, base_1], [], [], [], null)
	tris.add_tri([base_2, point_2, base_4], [], [], [], null)
	tris.add_quad([point_1, point_2, base_2, base_1], [], [], [], null)
	tris.add_quad([base_3, base_4, point_2, point_1], [], [], [], null)
	tris.add_quad([base_4, base_3, base_1, base_2], [], [], [], null)
	
	return tris
	
	
	
func build_rounded_rect():
	pass
	
	
# Builds a "polygon extrusion" which takes a series of 2D points and extrudes them along the provided axis.
func build_polygon_extrusion(face_dict, points, depth, rings, position, extrusion_axis):
	
	face_dict.faces.clear()
	
	# make the points given three-dimensional.
	var start_vertices = []
	var start_point_normal = Vector3(0, 0, 1)
	for point in points:
		start_vertices.append(Vector3(point.x, point.y, 0))
	
	var base_vertices = []
	
	# Build a basis and rotate it to the normal we desire.
	var dot = start_point_normal.dot(extrusion_axis)
	var cross = start_point_normal.cross(extrusion_axis).normalized()
	
	#print("DOT/CROSS: ", dot, cross)
	
	# If the face angle is where we want it, do nothing.
	if dot == 1 || dot == -1:
		#print("No need to rotate!") 
		for vertex in start_vertices:
			base_vertices.append(vertex + position)

	# Otherwise rotate it!
	else:
		#("Rotating!")
		var matrix = Basis()
		matrix = matrix.rotated(cross, PI*((dot + 1) / 2))
		
		for vertex in start_vertices:
			var t_vertex = matrix.xform(vertex)
			base_vertices.append(t_vertex + position)
			
	#print("BASE: ", base_vertices)
	# get the normals for all current edges
	var normals = []

	for i in base_vertices.size():

		var a = base_vertices[i]
		var b = Vector3()

		if i == base_vertices.size() - 1:
			b = base_vertices[0]
		else:
			b = base_vertices[i + 1]

		var line_a = (b - a).normalized()
		var line_b = Vector3(0, 1, 0)
		var face_normal = line_a.cross(line_b)

		normals.append(face_normal)


	# based on the number of rings, build the faces.
	var extrusion_step = depth / rings
	var base_extrusion_depth = Vector3()
	var distance_vec = extrusion_axis * extrusion_step
	var face_count = 0

	for i in rings:

		# go roooound the extrusion
		for i in base_vertices.size():

			var c_1 = base_vertices[i]
			var c_2 = Vector3()
			var normal = normals[i]

			if i == base_vertices.size() - 1:
				c_2 = base_vertices[0]
			else:
				c_2 = base_vertices[i + 1]

			c_1 += base_extrusion_depth
			c_2 += base_extrusion_depth
			var c_3 = c_1 + distance_vec
			var c_4 = c_2 + distance_vec

			var vertices = [c_1, c_3, c_4, c_2]
			var tangents = []


			face_dict.faces[face_count] = [vertices, [], tangents, [], normal]
			face_count += 1

		base_extrusion_depth += distance_vec
		
	# now render the top and bottom caps
	var v_cap_bottom = []
	var v_cap_top = []
	var total_extrusion_vec = extrusion_axis * depth
	
	for i in base_vertices.size():
		
		var vertex = base_vertices[i]
		v_cap_bottom.append( vertex )
		v_cap_top.append( vertex + total_extrusion_vec )
		
	v_cap_top.invert()
		
	face_dict.faces[face_count] = [v_cap_bottom, [], [], [], extrusion_axis.inverse()]
	face_dict.faces[face_count + 1] = [v_cap_top, [], [], [], extrusion_axis]
	


# Builds a "polygon extrusion" which takes a series of 2D points and extrudes them along the provided axis.
func build_spline_extrusion(points, depth, rings, position, extrusion_axis):
	
	pass
	
# ////////////////////////////////////////////////////////////
# HELPERS
	
static func create_vertex_circle(pos, segments, radius = 1, start = 0, angle = TWO_PI):
	var circle = []
	circle.resize(segments + 1)
	
	var s_angle = angle/segments
	
	for i in range(segments):
		var a = (s_angle * i) + start
		
		circle[i] = Vector3(cos(a), 0, sin(a)) * radius + pos
		
	if angle != TWO_PI:
		angle += start
		
		circle[segments] = Vector3(cos(angle), 0, sin(angle)) * radius + pos
		
	else:
		circle[segments] = circle[0]
		
	return circle
