tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Like FaceDictionary, only not loved.  (Used for collision data and shapes that aren't quad-based).

# [[vertices], [colors], [tangents], [uv], [normal]]

# Only vertices are required.


# ////////////////////////////////////////////////////////////
# PROPERTIES

var triangles = []

# ////////////////////////////////////////////////////////////
# ADDITIONS

# Adds a new triangle with a name, list of vertices and normal.
func add_tri(vertices, colors, tangents, uvs, normal):
	
	if vertices.size() < 2 || vertices == null:
		return
		
#	print("triangle = ", vertices)
	
	# if no normal is provided, try to guess
	if normal == null:
		var line_a = (vertices[1] - vertices[0]).normalized()
		var line_b = (vertices[2] - vertices[0]).normalized()
		normal = line_a.cross(line_b)
	
	triangles.append( [vertices, colors, tangents, uvs, normal] )
	
	
# Adds a quad, treated as two triangles.  
# ASSUMES THEY WERE ADDED AS THOUGH THEY WERE BEING DRAWN BY THE TRIANGLE FAN METHOD.
func add_quad(vertices, colors, tangents, uvs, normal):
	
	if vertices.size() < 2 || vertices == null:
		return
	
	# if no normal is provided, try to guess
	if normal == null:
		var line_a = (vertices[1] - vertices[0]).normalized()
		var line_b = (vertices[2] - vertices[0]).normalized()
		normal = line_b.cross(line_a)
		
#	print("vertices = ", vertices)
		
	var t1 = remove_vertex_from_quad(vertices, colors, tangents, uvs, 3)
	var t2 = remove_vertex_from_quad(vertices, colors, tangents, uvs, 1)
	
	triangles.append( [t1[0], t1[1], t1[2], t1[3], normal] )
	triangles.append( [t2[0], t2[1], t2[2], t2[3], normal] )


# Adds a series of triangles that just have geometry.  Useful if you want to just render as a wireframe.
func add_tri_array(vertices):
	
	var vertex_stack = vertices
	while vertex_stack.size() != 0:
		var v1 = vertex_stack.pop_front()
		var v2 = vertex_stack.pop_front()
		var v3 = vertex_stack.pop_front()
		
		triangles.append( [[v1, v2, v3], [], [], [], []] )
		
		
# ////////////////////////////////////////////////////////////
# RENDERING
		
		
# Renders the available geometry using a provided ImmediateGeometry node.
# Rendering as this type is good for dynamic objects whose shape is to be updated at run-time, when no collision is needed.
func render_immediate_geometry(geom):
	
	geom.clear()
	
	for triangle in triangles:
		var vertices = triangle[0]
		var colors = triangle[1]
		var tangents = triangle[2]
		var uvs = triangle[3]
		var normal = triangle[4]
		
		geom.begin(Mesh.PRIMITIVE_TRIANGLES, null)
		
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
# Rendering as this type is good for static objects, it's just... easier.
func render_surface_geometry():
	
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for triangle in triangles:
#		print("rendering triangle = ", triangle)
		var vertices = triangle[0]
		var colors = triangle[1]
		var tangents = triangle[2]
		var uvs = triangle[3]
		var normal = triangle[4]
		
		var normals = []
		for i in vertices.size():
			normals.append(normal)
		
		#var indexes = [0, 1, 2, 2, 3, 0]
		
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
	
	geom.clear()
	
	for triangle in triangles:
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
# UTILITIES

# Removes a precise position from a dataset, ensuring only the right item is removed if possible
func remove_vertex_from_quad(vertices, colors, tangents, uvs, index):
	
	var new_v = vertices.duplicate()
	if new_v.size() >= index + 1:
		new_v.remove(index)
	
	var new_c = colors.duplicate()
	if new_c.size() >= index + 1:
		new_c.remove(index)
	
	var new_t = tangents.duplicate()
	if new_t.size() >= index + 1:
		new_t.remove(index)
	
	var new_u = uvs.duplicate()
	if new_u.size() >= index + 1:
		new_u.remove(index)
		
	return [new_v, new_c, new_t, new_u]
	
	
# ////////////////////////////////////////////////////////////
# MANAGEMENT

func clear():
	triangles.clear()
	