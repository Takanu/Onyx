tool
extends Reference
class_name OnyxMesh

# ////////////////////////////////////////////////////////////
# INFO
# A bridge class for storing and manipulating mesh data, to later be used to turn into ImmediateGeometry or Mesh data.
# Stored as sets of 

# [ [vertices], [colors], [tangents], [uv], [normals] ]

# Only vertices are required.


# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")


# ////////////////////////////////////////////////////////////
# PROPERTIES

var tris = []

# ////////////////////////////////////////////////////////////
# ADDITIONS

# Adds a new triangle with a name, list of vertices and normal.
func add_tri(vertices : Array, colors : Array, tangents : Array, uvs : Array, normals : Array) -> void:

	if vertices.size() < 2 || vertices == null:
		print("ONYXMESH : add_tri : Too few or no vertices provided for a triangle.")
		return
	elif vertices.size() > 3:
		print("ONYXMESH : add_tri : Too many vertices provided for a triangle.")

#	print("triangle = ", vertices)

	while colors.size() < vertices.size():
		colors.append(null)

	while tangents.size() < vertices.size():
		tangents.append(null)

	while uvs.size() < vertices.size():
		uvs.append(null)

	# if no normal is provided, try to guess
	if normals.size() == 0:
		var line_a = (vertices[1] - vertices[0]).normalized()
		var line_b = (vertices[2] - vertices[0]).normalized()
		var normal = line_a.cross(line_b)
		normals = [normal, normal, normal]

	# not currently needed
#	if tangents.size() == 0:
#		var tangent = Plane(vertices[0], vertices[1], vertices[2])
#		tangents = [tangent, tangent, tangent]

	tris.append( [vertices, colors, tangents, uvs, normals] )


# Adds an ngon with vertices ordered as if to be rendered using the TRIANGLE_FAN method. Anything else and ur fucked.
func add_ngon(vertices : Array, colors : Array, tangents : Array, uvs : Array, normals : Array) -> void:


	if vertices.size() < 2 || vertices == null:
		print("ONYXMESH : add_ngon : ERROR - Too few or no vertices provided for an ngon.  Returning.")
		return

	while colors.size() < vertices.size():
		colors.append(null)

	while tangents.size() < vertices.size():
		tangents.append(null)

	while uvs.size() < vertices.size():
		uvs.append(null)

	var temp_normal = null

	# if no normal is provided, try to guess
	if normals.size() == 0:
		var line_a = (vertices[1] - vertices[0]).normalized()
		var line_b = (vertices[2] - vertices[0]).normalized()
		temp_normal = line_b.cross(line_a)

	# Go through each set of vertices in sequence
	var a = 1
	var b = 2
	while a <= vertices.size() - 2:
		var new_vs = [vertices[0], vertices[a], vertices[b]]

		var new_cs = []
		if colors.size() != 0:
			new_cs = [colors[0], colors[a], colors[b]]

		var new_ts = []
		if tangents.size() != 0:
			new_ts = [tangents[0], tangents[a], tangents[b]]

		var new_us = []
		if uvs.size() != 0:
			new_us = [uvs[0], uvs[a], uvs[b]]

		var new_ns = []
		if temp_normal != null:
			new_ns = [temp_normal, temp_normal, temp_normal]
		else:
			new_ns = [normals[0], normals[a], normals[b]]

		tris.append([ new_vs, new_cs, new_ts, new_us, new_ns ])

		a += 1
		b += 1



# Adds a series of triangles that just have geometry.  Useful if you want to just render as a wireframe.
func add_tri_array(vertices : Array):

	var vertex_stack = vertices
	while vertex_stack.size() != 0:
		var v1 = vertex_stack.pop_front()
		var v2 = vertex_stack.pop_front()
		var v3 = vertex_stack.pop_front()

		tris.append( [[v1, v2, v3], [], [], [], []] )


# ////////////////////////////////////////////////////////////
# RENDERING


# Renders the available geometry using a provided ImmediateGeometry node.
# Rendering as this type is good for dynamic objects whose shape is to be updated at run-time, when no collision is needed.
func render_immediate_geometry(geom : ImmediateGeometry):

	geom.clear()

	for triangle in tris:
		var vertices = triangle[0]
		var colors = triangle[1]
		var tangents = triangle[2]
		var uvs = triangle[3]
		var normals = triangle[4]

		geom.begin(Mesh.PRIMITIVE_TRIANGLES, null)

		for i in vertices.size():

			if colors[i] != null:
				geom.set_color(colors[i])

			if tangents[i] != null:
				geom.set_tangent(tangents[i])

			if uvs[i] != null:
				geom.set_uv(uvs[i])

			if normals[i] != null:
				geom.set_normal(normals[i])

			geom.add_vertex(vertices[i])

		geom.end()

# Renders available face geometry using SurfaceTool and returns a mesh.
# Rendering as this type is good for static objects, it's just... easier.
func render_surface_geometry(material : Material = null, generate_normals = false) -> ArrayMesh:

	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for triangle in tris:
#		print("rendering triangle = ", triangle)
		var vertices = triangle[0]
		var colors = triangle[1]
		var tangents = triangle[2]
		var uvs = triangle[3]
		var normals = triangle[4]

		#var indexes = [0, 1, 2, 2, 3, 0]

		surface.add_triangle_fan(PoolVector3Array(vertices), 
			PoolVector2Array(uvs), 
			PoolColorArray(colors), 
			PoolVector2Array(), 
			PoolVector3Array(normals),
			tangents)

	surface.index()

	if material != null:
		surface.set_material(material)

	# This generates a lot of errors, not sure why.
	#surface.generate_tangents()

	return surface.commit()


# Renders the available geometry as a wireframe, using a provided ImmediateGeometry node.
func render_wireframe(geom : ImmediateGeometry, color : Color):

	geom.clear()

	for triangle in tris:
		var vertices = triangle[0]

		geom.begin(Mesh.PRIMITIVE_LINES, null)

		geom.set_color(color)
		geom.add_vertex(vertices[0])
		geom.set_color(color)
		geom.add_vertex(vertices[1])

		geom.set_color(color)
		geom.add_vertex(vertices[1])
		geom.set_color(color)
		geom.add_vertex(vertices[2])

		geom.set_color(color)
		geom.add_vertex(vertices[2])
		geom.set_color(color)
		geom.add_vertex(vertices[0])

		geom.end()


# ////////////////////////////////////////////////////////////
# OPERATIONS

# Flips all the normals for each vertex.
func flip_normals():

	for tri in tris:
		var normals = tri[4]
		var new_normals = []

		for normal in normals:
			new_normals.append(normal * -1)

		tri[4] = new_normals


# Flips the draw order for all triangles.
func flip_draw_order():

	for tri in tris:
		var split_vertices = separate_vertices(tri)
		tri[0] = [split_vertices[0][0], split_vertices[2][0], split_vertices[1][0]]
		tri[1] = [split_vertices[0][1], split_vertices[2][1], split_vertices[1][1]]
		tri[2] = [split_vertices[0][2], split_vertices[2][2], split_vertices[1][2]]
		tri[3] = [split_vertices[0][3], split_vertices[2][3], split_vertices[1][3]]
		tri[4] = [split_vertices[0][4], split_vertices[2][4], split_vertices[1][4]]

# Multiplies all UVs with the given vector
func multiply_uvs(transform : Vector2):

	for tri in tris:
		var uvs = tri[3]
		var new_uvs = []

		for uv in uvs:
			new_uvs.append(uv * transform)

		tri[3] = new_uvs


# Bevels hard edges of the mesh.
func bevel_hard_edges(distance : float, iterations : int) -> void:

	# ///////////////////
	# PREPARATION SEARCH
	# ///////////////////

	# Get vertex sets for the mesh.
	var vertex_set = get_vertex_overlap_lists()
	var vertex_list = vertex_set['vertices']
	var v_hard_overlaps = vertex_set['hard_overlap']
	var v_seam_overlaps = vertex_set['seam_overlap']
	var v_soft_overlaps = vertex_set['soft_overlap']

	# Get edge sets for the mesh.
	var edge_list = get_edge_list()

	# Get a list of vertex neighbours as edges, using this list.
	# [ [vertex [neighbours] ]
	var neighbours = []
	for vertex in vertex_list:
		var neighbour_set = {'center': [], 'neighbour_edges': [], 'neighbour_vertices': []}
		var neighbour_results = []
		var vertex_results = []

		for edge in edge_list:
			var ev_1 : Array = edge[0]
			var ev_2 : Array = edge[1]

			if compare_vertices(vertex, ev_1) == true:
				neighbour_results.append(edge)
				vertex_results.append(ev_2)
			if compare_vertices(vertex, ev_2) == true:
				neighbour_results.append(edge)
				vertex_results.append(ev_1)

		neighbour_set['center'] = vertex
		neighbour_set['neighbour_edges'] = neighbour_results
		neighbour_set['neighbour_vertices'] = vertex_results
		neighbours.append(neighbour_set)

	# Get an edge overlap list by sorting the edge list based on vertices on the hard overlap list.
	var e_hard_overlaps = []
	var vertex_edge_pool = v_hard_overlaps.duplicate()
	var i = 0

	for edge_target in edge_list:
		var v1 : Array = edge_target[0]
		var v2 : Array = edge_target[1]
		var v1_found = false
		var v2_found = false

		for ve_set in vertex_edge_pool:
			for v_target in ve_set:
				if compare_vertices(v1, v_target) == true:
					v1_found = true
				elif compare_vertices(v2, v_target) == true:
					v2_found = true

			if v1_found == true && v2_found == true:
				e_hard_overlaps.append(edge_target)
				break

	# ///////////////////
	# SEPARATE CORNER-CONNECTED VERTICES
	# ///////////////////

	var corner_connected_issues = []

	# oh hi lets go through the neighbours.
	for neighbour in neighbours:
		var v_target = neighbour['center']
		var edges = neighbour['neighbour_edges']
		var hard_edge_candidates = []

		# search through all the hard edges and find how many we have 
		for edge in edges:
			if e_hard_overlaps.has(edge):
				hard_edge_candidates.append(edge)

		# if it's greater than 2, we need to fix it.
		if hard_edge_candidates.size() > 2:
			corner_connected_issues.append([neighbour, hard_edge_candidates])

	print("====================")
	print("HEY HERE IT IS WOW WOWOWOWOW")
	print(corner_connected_issues[0])

	# Go through the problem vertices
	for corner_set in corner_connected_issues:
		var neighbour_set = corner_set[0]
		var v_target = neighbour_set['center']
		var edges = neighbour_set['neighbour_edges']
		var vertices = neighbour_set['neighbour_vertices']
		var hard_edges = corner_set[1].duplicate()

		# Pick a random vertex from the vertices list.
		var start = vertices[0]

		# Get signed angles for all vectors
		var angles = []
		var a = 0
		var b = 1
		while a < vertices.size():
			var v_1 = vertices[a]
			var v_2 = vertices[b]
			var vec1 = v_target - v_1
			var vec2 = v_target - v_2
			vec1 = vec1.normalized()
			vec2 = vec2.normalized()

			var angle = acos(vec1.dot(vec2))
			angles.append(angle)

		print(angles)

	# ///////////////////
	# PULL HARD EDGES
	# ///////////////////

	# Look through all hard edges.





# ////////////////////////////////////////////////////////////
# UTILITIES

# Creates and returns a list of all the vertices in the mesh.
func get_vertex_list() -> Array:

	var vertex_list = []
	for tri in tris:
		var split_vertices = separate_vertices(tri)
		for vertex in split_vertices:
			vertex_list.append(vertex.duplicate())


	return vertex_list

# Creates a list of vertex information on vertices that share the same position.
func get_vertex_overlap_lists() -> Dictionary:

	# same position, different normals.
	var hard_overlap_list = []
	# same position, same normals, different uvs
	var seam_overlap_list = []
	# same position, same normals, same uvs
	var soft_overlap_list = []

	# get a list of vertices paired with their normals and other information
	var vertices = get_vertex_list()
	var vertex_pool = vertices.duplicate()

	while vertex_pool.size() != 0:
		var v_target = vertex_pool.pop_front()
		var v_matches = [v_target]
		var found_normal_difference = true
		var found_uv_difference = true

		# fetch all vertices with an overlap
		var i = 0
		while i < vertex_pool.size():
			var v_search = vertex_pool[i]

			if v_search[0] == v_target[0]:
				v_matches.append(v_search)
				vertex_pool.remove(i)

				if found_normal_difference == false:
					if v_search[4] != null && v_target[4] != null:
						if v_search[4] != v_target[4]:
							found_normal_difference == true

				if found_uv_difference == false:
					if v_search[3] != null && v_target[3] != null:
						if v_search[3] != v_target[3]:
							found_uv_difference == true


			else:
				i += 1

		# work out what kind of overlaps exist in this set.
		if found_normal_difference == true:
			hard_overlap_list.append(v_matches.duplicate())

		elif found_uv_difference == true:
			seam_overlap_list.append(v_matches.duplicate())

		else:
			soft_overlap_list.append(v_matches.duplicate())

		# clear the list and repeat
		v_matches.clear()

	return {'vertices':vertices, 'hard_overlap': hard_overlap_list, 'seam_overlap':seam_overlap_list, 'soft_overlap':soft_overlap_list}



# Creates and returns a list of edges from the current mesh (saved as an array of two arrays, each containing the information for each vertex).
# [ [vertex1, vertex2] ]
func get_edge_list() -> Array:

	var edge_list = []
	for tri in tris:
		var split_vertices = separate_vertices(tri)
		var edge = []
		var i = 0
		var z = 1

		while i < split_vertices.size():
			edge = [split_vertices[i], split_vertices[z]]

			i += 1
			z += 1
			if z >= split_vertices.size():
				z = 0

			edge_list.append(edge)

	return edge_list

# Returns the AABB bounds of the mesh.
func get_aabb() -> AABB:
	var v_size = tris.size()

	if v_size == 0:
		return AABB(Vector3(0, 0, 0), Vector3(0, 0, 0))

	var lb = Vector3(0, 0, 0)
	var ub = Vector3(0, 0, 0)

	for tri in tris:
		var vertices = tri[0]

		for vertex in vertices:
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


# Separates vertex information from a triangle array.
func separate_vertices(tri : Array):
	var vertices = tri[0]
	var colors = tri[1]
	var tangents = tri[2]
	var uvs = tri[3]
	var normals = tri[4]

	var split_vertices = []
	var i = 0

	while i < vertices.size():
		var v_new = [vertices[i], colors[i], tangents[i], uvs[i], normals[i]]
		split_vertices.append(v_new)
		i += 1

	return split_vertices

# Compares two vertices to see if they're identical in all components.
func compare_vertices(v1 : Array, v2 : Array):

#	print("comparing vertices...")
#	print(v1)
#	print(v2)

	if v1[0] != v2[0]:
		return false
	if v1[1] != v2[1]:
		return false
	if v1[2] != v2[2]:
		return false
	if v1[3] != v2[3]:
		return false
	if v1[4] != v2[4]:
		return false

	return true

# ////////////////////////////////////////////////////////////
# RAYCASTS

# (this could be better optimised with an algorithm that doesn't rely on planes)
# NOTE - ONLY USE IT IF THE SHAPE IS CONVEX, THIS WONT WORK OTHERWISE.
func raycast_point_convex_hull(point):
	
	# build a plane for every face
	var planes = []
	for i in tris.size():
		var face = tris[i]
		var vertices = face[0]
		planes.append( Plane(vertices[0], vertices[1], vertices[2]) )
	
	# check if the point lies in front of the plane
	for plane in planes:
		if plane.is_point_over(point) == true:
			#print("point outside hull!")
			return false
	
	#print("point inside hull!")
	return true
	

# ////////////////////////////////////////////////////////////
# MANAGEMENT

func clear():
	tris.clear()
