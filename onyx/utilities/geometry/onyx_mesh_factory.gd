tool
extends Reference
class_name OnyxMeshFactory

# ////////////////////////////////////////////////////////////
# INFO
# Used to generate common shapes for the face_dictionary type.

# face_dictionary tuple format:
# {"name": [[vertices], [colors], [tangents], [uv], normal]}
	
	
const TWO_PI = PI * 2

# ////////////////////////////////////////////////////////////
# BUILDERS

# Adds onto a pre-existing OnyxMesh with a cuboid that fits inside a maximum and minimum point.
func build_cuboid(mesh : OnyxMesh, max_point, min_point, unwrap_mode, subdivisions):
	
	# Build 8 vertex points
	var top_x = Vector3(max_point.x, max_point.y, min_point.z)
	var top_xz = Vector3(max_point.x, max_point.y, max_point.z)
	var top_z = Vector3(min_point.x, max_point.y, max_point.z)
	var top = Vector3(min_point.x, max_point.y, min_point.z)
	
	var bottom_x = Vector3(max_point.x, min_point.y, min_point.z)
	var bottom_xz = Vector3(max_point.x, min_point.y, max_point.z)
	var bottom_z = Vector3(min_point.x, min_point.y, max_point.z)
	var bottom = Vector3(min_point.x, min_point.y, min_point.z)
	
	# Build the 6 vertex Lists
	var vec_x_minus = [bottom, top, top_z, bottom_z]
	var vec_x_plus = [bottom_xz, top_xz, top_x, bottom_x]
	var vec_y_minus = [bottom_x, bottom, bottom_z, bottom_xz]
	var vec_y_plus = [top, top_x, top_xz, top_z]
	var vec_z_minus = [bottom_x, top_x, top, bottom]
	var vec_z_plus = [bottom_z, top_z, top_xz, bottom_xz]
	
	var surfaces = []
	surfaces.append( internal_build_surface(bottom, top_z, top, bottom_z, Vector2(subdivisions.z, subdivisions.y), 0) )
	surfaces.append( internal_build_surface(bottom_xz, top_x, top_xz, bottom_x, Vector2(subdivisions.z, subdivisions.y), 0) )
	
	surfaces.append( internal_build_surface(bottom_x, bottom_z, bottom, bottom_xz, Vector2(subdivisions.z, subdivisions.x), 0) )
	surfaces.append( internal_build_surface(top, top_xz, top_x, top_z, Vector2(subdivisions.z, subdivisions.x), 0) )
	
	surfaces.append( internal_build_surface(bottom_x, top, top_x, bottom, Vector2(subdivisions.x, subdivisions.y), 0) )
	surfaces.append( internal_build_surface(bottom_z, top_xz, top_z, bottom_xz, Vector2(subdivisions.x, subdivisions.y), 0) )
	
	for surface in surfaces:
		for quad in surface:
			mesh.add_ngon(quad[0], quad[1], quad[2], quad[3], quad[4])
			
	return mesh
	
	
func build_circle(points, x_width, z_width, position):
	
	var tris = OnyxMesh.new()
	
	# generate the initial circle
	var angle_step = (2.0 * PI) / points
	var current_angle = 0.0
	
	var circle_points = []
	
	while current_angle < 2 * PI:
		
		# get coordinates
		var x = x_width * cos(current_angle)
		var y = z_width * sin(current_angle)
		x += position.x
		y += position.y
		
		circle_points.append(Vector3(x, 0, y))
		current_angle += angle_step
		
	
	var i = circle_points.size()
	while i < circle_points.size():
		
		var p1 = circle_points[i]
		var p2 = circle_points[i + 1]
		
		if i == circle_points.size - 1:
			p2 = circle_points[0]
			
		tris.add_tri([position, p1, p2])
		pass
		
		
	return tris
	
	
func build_sphere(height, x_width, z_width, segments, height_segments, position, slice_from, slice_to, hemisphere, generate_cap, generate_ends):
	
	var onyx_mesh = OnyxMesh.new()
	
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
			
			var uvs = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]
			
			if ring == -1:
				uvs = [Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(1.0, 1.0)]
				onyx_mesh.add_tri([vertex1, vertex3, vertex4], [], [], uvs, [])
			
			if ring == height_segments:
				uvs = [Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(1.0, 1.0)]
				onyx_mesh.add_tri([vertex3, vertex1, vertex2], [], [], uvs, [])
			
			onyx_mesh.add_ngon([vertex1, vertex2, vertex3, vertex4], [], [], uvs, [])
			point += 1
			
		
		ring += 1
			
	return onyx_mesh
	
	
	
# Builds a cylinder given the height, width and number of points.  
# Returns an array in the format of face_array.
func build_cylinder(points : int, height : float, x_width : float, y_width : float, rings : int, position : Vector3, unwrap_method : int):
	
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
		
	return build_polygon_extrusion(circle_points, height, rings, position, Vector3(0, 1, 0), unwrap_method)
	
	
# A three-dimensional triangle extrusion C:
func build_wedge(base_x, base_z, point_width, point_position, position):
	
	#   X---------X  b1 b2
	#	|         |
	#		X---------X   p2 p1
	#	|		  |
	#   X---------X  b3 b4
	
	var tris = OnyxMesh.new()
	
	var base_1 = Vector3(-base_x/2, 0, base_z/2) + position
	var base_2 = Vector3(base_x/2, 0, base_z/2) + position
	
	var base_3 = Vector3(-base_x/2, 0, -base_z/2) + position
	var base_4 = Vector3(base_x/2, 0, -base_z/2) + position
	
	var point_1 = Vector3(-point_width/2 + point_position.x, point_position.y, point_position.z) + position
	var point_2 = Vector3(point_width/2 + point_position.x, point_position.y, point_position.z) + position
	
	var triangle_uv = [Vector2(0.0, 1.0), Vector2(0.5, 0.0), Vector2(1.0, 1.0)]
	var quad_uv = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	
	tris.add_tri([base_3, point_1, base_1], [], [], triangle_uv, [])
	tris.add_tri([base_2, point_2, base_4], [], [], triangle_uv, [])
	tris.add_ngon([point_1, point_2, base_2, base_1], [], [], quad_uv, [])
	tris.add_ngon([point_2, point_1, base_3, base_4], [], [], quad_uv, [])
	tris.add_ngon([base_1, base_2, base_4, base_3], [], [], quad_uv, [])
	
	return tris
	
	
	
func build_rounded_rect():
	pass
	
	
# Builds a ramp between two points based on many many many things.
func build_ramp(start_tf, end_tf, width, depth, maintain_width, iterations, ramp_fill_type, position):
	
	#   X---------X  e1 e2
	#	|         |  e3 e4
	#	|         |
	#	|         |
	#   X---------X  s1 s2
	#   X---------X  s3 s4
	
	var tris = OnyxMesh.new()
	
	# get main 4 vectors
	var v1 = Vector3(-width/2, depth/2, 0)
	var v2 = Vector3(width/2, depth/2, 0)
	var v3 = Vector3(-width/2, -depth/2, 0)
	var v4 = Vector3(width/2, -depth/2, 0)
	
	# transform them for the start and finish
	var s1 = start_tf.xform(v1) + position
	var s2 = start_tf.xform(v2) + position
	var s3 = start_tf.xform(v3) + position
	var s4 = start_tf.xform(v4) + position
	
	var e1 = end_tf.xform(v1) + position
	var e2 = end_tf.xform(v2) + position
	var e3 = end_tf.xform(v3) + position
	var e4 = end_tf.xform(v4) + position
	
	# ramp fill type conditionals
	if ramp_fill_type == 1:
		e3.y = s3.y
		e4.y = s4.y
	elif ramp_fill_type == 2:
		s1.y = e1.y
		s2.y = e2.y
		
	# UV prep
	var diff_1 = e1 - s1
	var diff_2 = e2 - s2
	var diff_3 = e3 - s3
	var diff_4 = e4 - s4
	
	# draw caps
	var cap_uv = [Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)]
	tris.add_ngon([s3, s4, s2, s1], [], [], cap_uv, [])
	tris.add_ngon([e4, e3, e1, e2], [], [], cap_uv, [])
	
	
	# calculate iterations
	iterations = iterations + 1
	var increment = 1.0/float(iterations)
	
	var d1 = s1.distance_to(e1) * increment
	var d2 = s2.distance_to(e2) * increment
	var d3 = s3.distance_to(e3) * increment
	var d4 = s4.distance_to(e4) * increment
	
	var u1 = e1 - s1
	var u2 = e2 - s2
	var u3 = e3 - s3
	var u4 = e4 - s4
	u1 = u1.normalized(); u2 = u2.normalized(); u3 = u3.normalized(); u4 = u4.normalized()
	
	var i = 0
	while i < iterations:
		
		var s1_move = s1 + (u1 * (d1 * i))
		var s2_move = s2 + (u2 * (d2 * i))
		var s3_move = s3 + (u3 * (d3 * i))
		var s4_move = s4 + (u4 * (d4 * i))
		
		var e1_move = s1 + (u1 * (d1 * (i + 1)))
		var e2_move = s2 + (u2 * (d2 * (i + 1)))
		var e3_move = s3 + (u3 * (d3 * (i + 1)))
		var e4_move = s4 + (u4 * (d4 * (i + 1)))
		
		var start_uv_z = 0
		var end_uv_z = 1
		
		var iteration_uv = [Vector2(1.0, end_uv_z), Vector2(0.0, end_uv_z), Vector2(0.0, start_uv_z), Vector2(1.0, start_uv_z)]
		
		tris.add_ngon([s1_move, s2_move, e2_move, e1_move], [], [], iteration_uv, [])
		tris.add_ngon([e3_move, e4_move, s4_move, s3_move], [], [], iteration_uv, [])
		
		tris.add_ngon([s4_move, e4_move, e2_move, s2_move], [], [], iteration_uv, [])
		tris.add_ngon([e3_move, s3_move, s1_move, e1_move], [], [], iteration_uv, [])
		
		i += 1
	
	return tris
	
	
# Builds a "polygon extrusion" which takes a series of 2D points and extrudes them along the provided axis.
func build_polygon_extrusion(points : Array, depth : float, rings : int, position : Vector3, extrusion_axis : Vector3, unwrap_method : int):
	
	var mesh = OnyxMesh.new()
	
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
	var normal_list = []

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

		normal_list.append(face_normal)


	# based on the number of rings, build the faces.
	var extrusion_step = depth / rings
	var base_extrusion_depth = Vector3()
	var distance_vec = extrusion_axis * extrusion_step
	var face_count = 0

	for i in rings:

		# go roooound the extrusion
		for i in base_vertices.size():
			
			# X--------X  c_3   c_4
			# |        |
			# |        |
			# |        |
			# X--------X  c_1   c_2

			var c_1 = base_vertices[i]
			var c_2 = Vector3()
			var normal = normal_list[i]

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
			var normals = [normal, normal, normal, normal]
			
			# UNWRAP METHOD 0 - CLAMPED OVERLAP
			var uvs = []
			if unwrap_method == 0:
				uvs = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]

			# UNWRAP METHOD 1 - PROPORTIONAL OVERLAP
			elif unwrap_method == 1:
				var face_transform = OnyxUtils.get_uv_triangle_transform([c_1, c_3, c_2])
				
				print('TRANSFORM = ', face_transform)
				print('VERTICES = ', vertices)
				uvs = OnyxUtils.transform_vector3_array(vertices, face_transform)
				
				# ATTEMPT 1
				var uv_ranges = OnyxUtils.get_vector2_ranges(uvs)
				print('TRANSFORM UVS = ', uvs)

				uvs = OnyxUtils.vector3_to_vector2_array(uvs, 'Y', 'Z')
				uv_ranges = OnyxUtils.get_vector2_ranges(uvs)
				print('NEW_UVS = ', uvs)

				# ATTEMPT 2
				
				
				print('xxxxxxxxxxxxxxxxxxxx')
				
			# ADD FACE
			mesh.add_ngon(vertices, [], tangents, uvs, normals)
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
	
	#var bottom_normals = [extrusion_axis.inverse(), extrusion_axis.inverse(), extrusion_axis.inverse(), extrusion_axis.inverse()]
	#var top_normals = [extrusion_axis, extrusion_axis, extrusion_axis, extrusion_axis]
	
	# UVS
	var utils = OnyxUtils.new()
	var top_bounds = utils.get_vector3_ranges(v_cap_top)
	var bottom_bounds = utils.get_vector3_ranges(v_cap_bottom)
	
	var top_range = top_bounds['max'] - top_bounds['min']
	var bottom_range = bottom_bounds['max'] - bottom_bounds['min']
	
	var top_uvs = []
	var bottom_uvs = []
	for vector in v_cap_top:
		var uv = Vector2(vector.x / top_range.x, vector.z / top_range.z)
		uv = uv + Vector2(0.5, 0.5)
		top_uvs.append(uv)
	for vector in v_cap_bottom:
		var uv = Vector2(vector.x / bottom_range.x, vector.z / bottom_range.z)
		uv = uv + Vector2(0.5, 0.5)
		bottom_uvs.append(uv)
		
	mesh.add_ngon(v_cap_top, [], [], top_uvs, [])
	mesh.add_ngon(v_cap_bottom, [], [], bottom_uvs, [])
	
	return mesh

# Builds a "polygon extrusion" which takes a series of 2D points and extrudes them along the provided axis.
func build_spline_extrusion(points, depth, rings, position, extrusion_axis):
	
	pass
	
	
	
	
# ////////////////////////////////////////////////////////////
# HELPERS

# Builds a set of quads between 4 points, ready to be added to a OnyxMesh.
func internal_build_surface(start_pos : Vector3, end_pos : Vector3, up_max : Vector3, cross_max : Vector3, subdivisions : Vector2, unwrap_mode : int) -> Array:
	
	var results = []
	
	# Subdivision Increments
	var up_div = int( max( floor(subdivisions.y), 1) )
	var cross_div = int( max( floor(subdivisions.x), 1) )
	
	var up_size = up_max - start_pos
	var cross_size = cross_max - start_pos
	
	var up_inc = up_size/up_div
	var cross_inc = cross_size/cross_div
	
	
	# Iterate Grid
	var i_up = 0
	var i_cross = 0
	
	while i_up < subdivisions.y:
		i_cross = 0
		
		while i_cross < subdivisions.x:
			var up_pos = i_up * up_inc
			var cross_pos = i_cross * cross_inc
			
			var vf_1 = start_pos + up_pos + cross_pos
			var vf_2 = vf_1 + up_inc
			var vf_3 = vf_1 + up_inc + cross_inc
			var vf_4 = vf_1 + cross_inc
			var vectors = [vf_1, vf_2, vf_3, vf_4]
			var uvs = []
			
			# UNWRAP MODE - 1:1 Overlap
			if unwrap_mode == 0:
				uvs = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]
				
			# UNWRAP MODE - PROPORTIONAL OVERLAP
			elif unwrap_mode == 1:
				uvs = OnyxUtils.vector3_to_vector2_array(vectors, 'X', 'Z')
			
			results.append([ vectors, [], [], uvs, [] ])
			
			i_cross += 1
		
		i_up += 1
		
	return results
	
	
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
