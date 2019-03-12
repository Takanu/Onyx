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
	
	
func build_sphere(height, x_width, z_width, segments, height_segments, position, slice_from, slice_to, hemisphere, generate_cap, generate_ends, smooth_normals):
	
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
		phi1 = 0.0
		phi2 = deltaPhi
			
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
			
			# UV MAPPING
			var uvs = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]
			
			# NORMAL MAPPING
			var normals = []
			
			# If we have smooth normals, we need extra points of detail
			if smooth_normals == true:
				# Get the right circle positions \o/
				var theta0 = theta1 - deltaTheta
				var theta3 = theta2 + deltaTheta
				var phi0 = phi1 - deltaPhi
				var phi3 = phi2 + deltaPhi
				
#				if point == segments - 1:
#					phi3 = deltaPhi
#					phi2 = 0
				
#				if ring == 0 || ring == height_segments:
#					theta0 = OnyxUtils.loop_int( (theta1 + PI), 0, PI * 2)
#					theta3 = OnyxUtils.loop_int( (theta2 + PI), 0, PI * 2)
					
#				print("phis - ", phi0, " ", phi1, " ", phi2, " ", phi3)
				
				# BUILD EXTRA POINTS
				var up_1 = Vector3(sin(theta0) * cos(phi1) * (x_width/2),  cos(theta0) * (height/2),  sin(theta0) * sin(phi1) * (z_width/2))
				var up_2 = Vector3(sin(theta0) * cos(phi2) * (x_width/2),  cos(theta0) * (height/2),  sin(theta0) * sin(phi2) * (z_width/2))
				var left_1 = Vector3(sin(theta1) * cos(phi3) * (x_width/2),  cos(theta1) * (height/2),  sin(theta1) * sin(phi3) * (z_width/2))
				var left_2 = Vector3(sin(theta2) * cos(phi3) * (x_width/2),  cos(theta2) * (height/2),  sin(theta2) * sin(phi3) * (z_width/2))
				var right_1 = Vector3(sin(theta1) * cos(phi0) * (x_width/2),  cos(theta1) * (height/2),  sin(theta1) * sin(phi0) * (z_width/2))
				var right_2 = Vector3(sin(theta2) * cos(phi0) * (x_width/2),  cos(theta2) * (height/2),  sin(theta2) * sin(phi0) * (z_width/2))
				var down_1 = Vector3(sin(theta3) * cos(phi1) * (x_width/2),  cos(theta3) * (height/2),  sin(theta3) * sin(phi1) * (z_width/2))
				var down_2 = Vector3(sin(theta3) * cos(phi2) * (x_width/2),  cos(theta3) * (height/2),  sin(theta3) * sin(phi2) * (z_width/2))
				
				# GET NORMALS
				var n_0_0 = OnyxUtils.get_triangle_normal([vertex1, up_1, right_1])
				var n_1_0 = OnyxUtils.get_triangle_normal([vertex2, up_2, vertex1])
				var n_2_0 = OnyxUtils.get_triangle_normal([left_1, up_2, vertex2])
				
				var n_0_1 = OnyxUtils.get_triangle_normal([vertex4, vertex1, right_2])
				var n_1_1 = OnyxUtils.get_triangle_normal([vertex3, vertex2, vertex4])
				var n_2_1 = OnyxUtils.get_triangle_normal([left_2, vertex2, vertex3])
				
				var n_0_2 = OnyxUtils.get_triangle_normal([down_1, vertex4, right_2])
				var n_1_2 = OnyxUtils.get_triangle_normal([down_2, vertex3, vertex4])
				var n_2_2 = OnyxUtils.get_triangle_normal([left_2, vertex3, down_2])
				
				# COMBINE FOR EACH VERTEX
				var normal_1 = (n_0_0 + n_1_0 + n_0_1 + n_1_1).normalized()
				var normal_2 = (n_1_0 + n_2_0 + n_1_1 + n_2_1).normalized()
				var normal_3 = (n_1_1 + n_2_1 + n_1_2 + n_2_2).normalized()
				var normal_4 = (n_0_1 + n_1_1 + n_0_2 + n_1_2).normalized()
				
				normals = [normal_1, normal_2, normal_3, normal_4]
#				print(normals)
#				if point == 0 || point == segments - 1:
#					print(normals)
					
			else:
				var normal = OnyxUtils.get_triangle_normal([vertex3, vertex2, vertex4])
				normals = [normal, normal, normal, normal]
			
			# CAP RENDERING
			if ring == -1:
				uvs = [Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(1.0, 1.0)]
				normals.remove(1)
				onyx_mesh.add_tri([vertex1, vertex3, vertex4], [], [], uvs, normals)
			
			if ring == height_segments:
				uvs = [Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(1.0, 1.0)]
				normals.remove(3)
				onyx_mesh.add_tri([vertex3, vertex1, vertex2], [], [], uvs, normals)
			
			else:
				onyx_mesh.add_ngon([vertex1, vertex2, vertex3, vertex4], [], [], uvs, normals)
				
			point += 1
			
		
#		if ring == 1:
#			return onyx_mesh
		ring += 1
			
	return onyx_mesh
	
	
	
# Builds a cylinder given the height, width and number of points.  
# Returns an array in the format of face_array.
func build_cylinder(mesh : OnyxMesh, points : int, height : float, x_width : float, y_width : float, rings : int, position : Vector3, unwrap_method : int, smooth_shading : bool):
	
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
		
	return build_polygon_extrusion(mesh, circle_points, height, rings, position, Vector3(0, 1, 0), unwrap_method, smooth_shading)
	
	
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
	


# Builds a rounded rectangle where the corners around one axis are rounded.
func build_rounded_rect(mesh: OnyxMesh, min_point, max_point, axis: String, corner_size : float, corner_iterations : int, smooth_normals : bool, unwrap_mode : int):
	
	# Clamp important values
	if corner_size < 0:
		corner_size = 0
	if corner_iterations < 1:
		corner_iterations = 1
		
	# Check axis provided
	if axis != 'X' && axis != 'Y' && axis != 'Z':
		print("ONYX_MESH_FACTORY : build_rounded_rect : Wrong axis defined for corner projection, returning early.")
		return
		
	# Build 8 vertex points
	var top_x = Vector3(max_point.x, max_point.y, min_point.z)
	var top_xz = Vector3(max_point.x, max_point.y, max_point.z)
	var top_z = Vector3(min_point.x, max_point.y, max_point.z)
	var top = Vector3(min_point.x, max_point.y, min_point.z)
	
	var bottom_x = Vector3(max_point.x, min_point.y, min_point.z)
	var bottom_xz = Vector3(max_point.x, min_point.y, max_point.z)
	var bottom_z = Vector3(min_point.x, min_point.y, max_point.z)
	var bottom = Vector3(min_point.x, min_point.y, min_point.z)
	
	# ROUNDED CORNERS
	# build the initial list of corners, positive rotation.
	var circle_points = []
	var angle_step = (PI / 2) / corner_iterations
	
	var current_angle = 0.0
	var end_angle = (PI / 2)
	var i = 0
	
	while i < 4:
		var point_set = []
		current_angle = (PI / 2) * i
		end_angle = (PI / 2) * (i + 1)
	
		while current_angle <= end_angle:
			var x = corner_size * cos(current_angle)
			var y = corner_size * sin(current_angle)
			point_set.append(Vector2(x, y))
			current_angle += angle_step
		
		circle_points.append(point_set)
		i += 1
	
	# EXTRUSION
	# build the initial list of vertices to be extruded.
	var extrusion_vertices = []
	
	# will make a nicer bit of code later...
	if axis == 'X':
		var corners_top = OnyxUtils.vector2_to_vector3_array(circle_points[0], 'X', 'Y')
		var corners_y = OnyxUtils.vector2_to_vector3_array(circle_points[1], 'X', 'Y')
		var corners_bottom = OnyxUtils.vector2_to_vector3_array(circle_points[2], 'X', 'Y')
		var corners_x = OnyxUtils.vector2_to_vector3_array(circle_points[3], 'X', 'Y')
		
		# top, top_z, bottom, bottom_z
		# Get the four inset vertices to position the circle points to
		var offset_top = top_z + Vector3(0, -corner_size, -corner_size)
		var offset_y = top + Vector3(0, -corner_size, corner_size)
		var offset_bottom = bottom + Vector3(0, corner_size, corner_size)
		var offset_x = bottom_z + Vector3(0, corner_size, -corner_size)
		
		# Create transforms 
		var tf_top = Transform(Basis(), offset_top)
		var tf_y = Transform(Basis(), offset_y)
		var tf_bottom = Transform(Basis(), offset_bottom)
		var tf_x = Transform(Basis(), offset_x)
		
		# Get the circle points and translate each corner set by the above offsets
		corners_top = OnyxUtils.transform_vector3_array(corners_top, tf_top)
		corners_y = OnyxUtils.transform_vector3_array(corners_y, tf_y)
		corners_bottom = OnyxUtils.transform_vector3_array(corners_bottom, tf_bottom)
		corners_x = OnyxUtils.transform_vector3_array(corners_x, tf_x)
		
		# Stack all the vertices into a single array
		var start_cap = OnyxUtils.combine_arrays([corners_top, corners_y, corners_bottom, corners_x])\
		
		# Project and duplicate
		var tf_end_cap = Transform(Basis(), Vector3(max_point.x - min_point.x, 0, 0)) 
		var end_cap = OnyxUtils.transform_vector3_array(start_cap, tf_end_cap)
		
		# UVS
		var start_cap_uvs = []
		var end_cap_uvs = []
		
		# 0 - Clamped Overlap
		if unwrap_mode == 0:
			var diff = max_point - min_point
			var clamped_vs = []
			
			# for every vertex, minus it by the min and divide by the difference.
			for vertex in start_cap:
				clamped_vs.append( (vertex - min_point) / diff )
			start_cap_uvs = OnyxUtils.vector3_to_vector2_array(clamped_vs, 'X', 'Z')
			
			# for every vertex, minus it by the min and divide by the difference.
#			for vertex in end_cap:
#				clamped_vs.append( (vertex - min_point) / diff )
#			end_cap_uvs = OnyxUtils.vector3_to_vector2_array(clamped_vs, 'X', 'Z')
			
			for uv in start_cap_uvs:
				end_cap_uvs.append(uv * Vector2(-1.0, -1.0))
		
		# 1 - Proportional Overlap
		if unwrap_mode == 1:
			start_cap_uvs = OnyxUtils.vector3_to_vector2_array(start_cap, 'X', 'Z')
			end_cap_uvs = OnyxUtils.vector3_to_vector2_array(end_cap, 'X', 'Z')
		
		mesh.add_ngon(OnyxUtils.reverse_array(start_cap), [], [], start_cap_uvs, [])
		mesh.add_ngon(end_cap, [], [], end_cap_uvs, [])
		
		# used for Proportional Unwrap.
		var total_edge_length = 0.0
		
		# Build side edges
		var v_1 = 0
		while v_1 < start_cap.size():
			
			var v_2 = OnyxUtils.loop_int( (v_1 + 1), 0, (start_cap.size() - 1) )
			
			var b_1 = start_cap[v_1]
			var b_2 = start_cap[v_2]
			var t_1 = end_cap[v_1]
			var t_2 = end_cap[v_2]
			
			var normals = []
			
			# SMOOTH SHADING
			if smooth_normals == true:
				var v_0 = OnyxUtils.loop_int( (v_1 - 1), 0, (start_cap.size() - 1) )
				var v_3 = OnyxUtils.loop_int( (v_2 + 1), 0, (start_cap.size() - 1) )
				
				var b_0 = start_cap[v_0]
				var b_3 = start_cap[v_3]
				var t_0 = end_cap[v_0]
				var t_3 = end_cap[v_3]
				
				var n_0 = OnyxUtils.get_triangle_normal( [b_0, t_0, b_1] )
				var n_1 = OnyxUtils.get_triangle_normal( [b_1, t_1, b_2] )
				var n_2 = OnyxUtils.get_triangle_normal( [b_2, t_2, b_3] )
				
				var normal_1 = (n_0 + n_1).normalized()
				var normal_2 = (n_1 + n_2).normalized()
				normals = [normal_1, normal_2, normal_2, normal_1]
				
			else:
				var normal = OnyxUtils.get_triangle_normal( [b_1, t_1, b_2] )
				normals = [normal, normal, normal, normal]
				
				
			# UVS
			var uvs = []
			
			# 0 - Clamped Overlap
			if unwrap_mode == 0:
				uvs = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
			
			# 1 - Proportional Overlap
			elif unwrap_mode == 1:
				var height = (t_1 - b_1).length()
				var new_width = (t_2 - t_1).length()
				uvs = [Vector2(total_edge_length, 0.0), Vector2(total_edge_length + new_width, 0.0), 
				Vector2(total_edge_length + new_width, height), Vector2(total_edge_length, height)]
			
			var vertex_set = [b_1, b_2, t_2, t_1]
			mesh.add_ngon(vertex_set, [], [], uvs, normals)
			
			v_1 += 1
			total_edge_length += (t_2 - t_1).length()
		
	
	
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
	
	print("START TF: ", start_tf)
	print("END TF: ", end_tf)
	
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
	
	var i = 0
	while i < iterations:
		
		# transform the starts and ends by the interpolation between the start and end transformation
		var start_percentage = float(i) / iterations
		var end_percentage = float(i + 1) / iterations
			
		var s_tf = start_tf.interpolate_with(end_tf, start_percentage)
		var e_tf = start_tf.interpolate_with(end_tf, end_percentage)
		
		print(start_percentage)
		
		# Calculate the current positions
		var s1_move = s_tf.xform(v1)
		var s2_move = s_tf.xform(v2)
		var s3_move = s_tf.xform(v3)
		var s4_move = s_tf.xform(v4)
		
		var e1_move = e_tf.xform(v1)
		var e2_move = e_tf.xform(v2)
		var e3_move = e_tf.xform(v3)
		var e4_move = e_tf.xform(v4)
		
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
func build_polygon_extrusion(mesh : OnyxMesh, points : Array, depth : float, rings : int, position : Vector3, extrusion_axis : Vector3, unwrap_method : int, smooth_shading : bool):
	
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
			

	# based on the number of rings, build the faces.
	var extrusion_step = depth / rings
	var base_extrusion_depth = Vector3()
	var distance_vec = extrusion_axis * extrusion_step
	var face_count = 0
	
	for i in rings:
		
		# Used for Proportional Unwrap methods.
		var total_edge_length = 0.0
		
		# go roooound the extrusion
		for v_1 in base_vertices.size():
			
			# X--------X  t_1   t_2
			# |        |
			# |        |
			# |        |
			# X--------X  b_1   b_2
			
			# Get positions ahead and behind the set we plan on looking at for smooth normals
			var v_0 = OnyxUtils.loop_int(v_1 - 1, 0, base_vertices.size() - 1)
			var v_2 = OnyxUtils.loop_int(v_1 + 1, 0, base_vertices.size() - 1)
			var v_3 = OnyxUtils.loop_int(v_1 + 2, 0, base_vertices.size() - 1)

			var b_0 = base_vertices[v_0]
			var b_1 = base_vertices[v_1]
			var b_2 = base_vertices[v_2]
			var b_3 = base_vertices[v_0]

			b_1 += base_extrusion_depth
			b_2 += base_extrusion_depth
			var t_1 = b_1 + distance_vec
			var t_2 = b_2 + distance_vec

			var vertices = [b_1, t_1, t_2, b_2]
			var tangents = []
			var normals = []
			
			# NORMAL TYPES
			if smooth_shading == true:
				var n_1 = OnyxUtils.get_triangle_normal([b_0, b_1, t_1])
				var n_2 = OnyxUtils.get_triangle_normal([b_2, b_2, b_3])
				normals = [n_1, n_1, n_2, n_2]
			else:
				var normal = OnyxUtils.get_triangle_normal([b_1, t_1, b_2])
				normals = [normal, normal, normal, normal]
			
			# UNWRAP METHOD 0 - CLAMPED OVERLAP
			var uvs = []
			if unwrap_method == 0:
				uvs = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]

			# UNWRAP METHOD 1 - PROPORTIONAL OVERLAP
			# Unwraps evenly across all rings, scaling based on vertex position.
			elif unwrap_method == 1:
				var base_width = (b_2 - b_1).length()
				var base_height = (t_1 - b_1).length()
				
				uvs = [Vector2(total_edge_length, b_1.y), Vector2(total_edge_length, t_1.y), 
				Vector2(total_edge_length + base_width, t_1.y), Vector2(total_edge_length + base_width, b_1.y)]
				
				total_edge_length += base_width
				
			# UNWRAP METHOD 1 - PROPORTIONAL OVERLAP SEGMENTS
			# Proportionally unwraps horizontally, but applies the same unwrap coordinates to all rings.
			elif unwrap_method == 2:
				var base_width = (b_2 - b_1).length()
				var base_height = (t_1 - b_1).length()
				
				uvs = [Vector2(total_edge_length, 0.0), Vector2(total_edge_length, base_height), 
				Vector2(total_edge_length + base_width, base_height), Vector2(total_edge_length + base_width, 0.0)]
				
				total_edge_length += base_width
				
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
	
	# UNWRAP METHOD 0 - CLAMPED OVERLAP
	if unwrap_method == 0:
		for vector in v_cap_top:
			var uv = Vector2(vector.x / top_range.x, vector.z / top_range.z)
			uv = uv + Vector2(0.5, 0.5)
			top_uvs.append(uv)
		
		for vector in v_cap_bottom:
			var uv = Vector2(vector.x / bottom_range.x, vector.z / bottom_range.z)
			uv = uv + Vector2(0.5, 0.5)
			bottom_uvs.append(uv)
		
	# UNWRAP METHOD 1+2 - PROPORTIONAL OVERLAP AND SEGMENTS
	# Unwraps evenly across all rings, scaling based on vertex position.
	elif unwrap_method == 1 || unwrap_method == 2:
		for vector in v_cap_top:
			top_uvs.append(Vector2(vector.x, vector.z))
		for vector in v_cap_bottom:
			bottom_uvs.append(Vector2(vector.x, vector.z))
			
		
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
				
#			# UNWRAP MODE - PROPORTIONAL OVERLAP
			# Can't do this until I understand UV projection.
#			elif unwrap_mode == 1:
#				uvs = OnyxUtils.vector3_to_vector2_array(vectors, 'X', 'Z')
			
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
