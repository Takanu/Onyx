tool
extends Reference


# ////////////////////////////////////////////////////////////


# DEPRECATED
# Use OnyxMesh instead.


# ////////////////////////////////////////////////////////////








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

# ////////////////////////////////////////////////////////////
# ADDITIONS

# Adds a new face with a name, list of vertices and normal.
func add_face(face_name, vertices, colors, tangents, uvs, normal):
	
	if vertices == null:
		return
	
	if vertices.size() < 2:
		return
		
	# if no normal is provided, try to guess
	if normal == null:
		var line_a = (vertices[1] - vertices[0]).normalized()
		var line_b = (vertices[2] - vertices[0]).normalized()
		normal = line_a.cross(line_b)
	
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
				pass
				#geom.set_tangent(tangents[i])
				
			if uvs.size() > i:
				geom.set_uv(uvs[i])
				
			geom.set_normal(normal)
			geom.add_vertex(vertices[i])
		
		geom.end()
		
		
# Renders available face geometry using SurfaceTool and returns a mesh.
func render_surface_geometry():
	
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for key in faces:
		var face = faces[key]
		var vertices = face[0]
		var colors = face[1]
		var tangents = face[2]
		var uvs = face[3]
		var normal = face[4]
		
		var normals = []
		for i in vertices.size():
			normals.append(normal)
		
		var indexes = [0, 1, 2, 2, 3, 0]
		
		surface.add_triangle_fan(PoolVector3Array(vertices), 
			PoolVector2Array(uvs), 
			PoolColorArray(colors), 
			PoolVector2Array(), 
			PoolVector3Array(normals),
			tangents)
			
	surface.index()
	# This generates a lot of errors, not sure why.
	#surface.generate_tangents()
	return surface.commit()
			
			
# Renders the available geometry as a wireframe, using a provided ImmediateGeometry node.
func render_wireframe(geom, color):
	
	var edges = get_face_edges()
	var count = edges.size() / 2
	
	geom.clear()
	
	for i in count:
		var pos = ((i + 1) * 2) - 2
		var point1 = edges[pos]
		var point2 = edges[pos + 1]
		
		geom.begin(Mesh.PRIMITIVE_LINES, null)
		
		geom.set_color(color)
		geom.add_vertex(point1)
			
		geom.set_color(color)
		geom.add_vertex(point2)
		
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
		
		for v in vertices.size():
			results.append(vertices[v])
			
			if v + 1 >= vertices.size():
				results.append(vertices[0])
			else:
				results.append(vertices[v + 1])
		
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
	
	
# Returns an AABB that encapsulates the boundaries of the geometry stored.
func get_bounds():
	
	var lowest_bound = Vector3()
	var highest_bound = Vector3()
	
	for i in faces:
		var face = faces[i]
		var vertices = face[0]
		
		for vertex in vertices:
			if vertex.x > highest_bound.x:
				highest_bound.x = vertex.x
			if vertex.y > highest_bound.y: 
				highest_bound.y = vertex.y
			if vertex.z > highest_bound.z:
				highest_bound.z = vertex.z
				
			if vertex.x < lowest_bound.x:
				lowest_bound.x = vertex.x
			if vertex.y < lowest_bound.y:
				lowest_bound.y = vertex.y
			if vertex.z < lowest_bound.z:
				lowest_bound.z = vertex.z
	
	var size = highest_bound - lowest_bound	
	return AABB(lowest_bound, size)
	

# ////////////////////////////////////////////////////////////
# TRANSFORMS

# Apply a Transformation Matrix to all vertices, normals and tangents currently held.
func apply_transform(tform):
	
	var new_faces = {}
	
	for key in faces.keys:
		var face = faces[key]
		var vertices = face[0]
		var tangents = face[2]
		var normal = face[4]
		
		var new_vertices = []
		var new_tangents = []
		var new_normal = Vector3()
		
		for i in vertices.size():
			
			new_vertices.append( tform.xform(vertices[i]) )
			new_normal = tform.xform(normal)
			
			if tangents.size() > i:
				pass
				
		if new_tangents.size() == 0 && tangents.size() != 0:
			new_tangents = tangents
			
		new_faces[key] = [new_normal, face[1], new_tangents, face[3], new_normal]
			
	# replace the old set with the new one
	faces = new_faces

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

# (this could be better optimised with an algorithm that doesn't rely on planes)
# NOTE - ONLY USE IT IF THE SHAPE IS CONVEX, THIS WONT WORK OTHERWISE.
func is_point_inside_convex_hull(point):
	
	# build a plane for every face
	var planes = []
	for i in faces.size():
		var face = faces[i]
		var vertices = face[0]
		planes.append( Plane(vertices[0], vertices[1], vertices[2]) )
	
	# check if the point lies in front of the plane
	for plane in planes:
		if plane.is_point_over(point) == true:
			#print("point outside hull!")
			return false
	
	#print("point inside hull!")
	return true
	

# Performs a raycast using two points to see if it intersects with the convex hull this
# face dictionary represents.  Returns the closest intersection if true.
# Solution taken from - https://stackoverflow.com/questions/30486312/intersection-of-nd-line-with-convex-hull-in-python

# NOTE - ONLY USE IT IF THE SHAPE IS CONVEX, THIS WONT WORK OTHERWISE.
func raycast_convex_hull(to, from):
	
	var unit_ray = (to - from).normalized()
	var closest_plane = null
	var closest_plane_distance = 0
	
	# build a plane for every face
	var planes = []
	for i in faces.size():
		var face = faces[i]
		var vertices = face[0]
		planes.append( Plane(vertices[0], vertices[1], vertices[2]) )
	
	# search through the planes to find the closest intersection point
	for plane in planes:
		var normal = plane.normal
		var distance = plane.distance_to(from)
		
		# if the origin of the ray already sits on the plane, just return now.
		if distance == 0:
			return from
		
		# If it's minus, flip it.
		if distance < 0:
			normal = normal.inverse()
			distance = distance * -1
		
		# Get the dot product to figure out how much we move along the plane
		# normal for every unit distance along the ray normal
		var dot = unit_ray.dot(normal)
		
		# Make sure the dot product is positive, otherwise it's facing the wrong way
		# and it can be ignored.
		if dot > 0:
			var ray_distance = distance / dot
			
			# If we have no plane or it's smaller than the distance we have, replace the old with the new.
			if closest_plane == null || ray_distance < closest_plane_distance:
				closest_plane = plane
				closest_plane_distance = ray_distance
				
	if closest_plane == null:
		return null
		
	
	return closest_plane.intersects_segment(from, to) 
	
# ////////////////////////////////////////////////////////////
# CLEAN-UP

# Clear all faces
func clear():
	faces = {}