tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Like FaceDictionary, only not loved.  (Used only for types that will only provide triangle data like collision shapes).

# [[vertices], [colors], [tangents], [uv], [normals]]

# Only vertices are required.


# ////////////////////////////////////////////////////////////
# PROPERTIES

var triangles = []

# ////////////////////////////////////////////////////////////
# ADDITIONS

# Adds a new triangle with a name, list of vertices and normal.
func add_triangle(vertices, colors, tangents, uvs, normals):
	
	if vertices == null:
		return
	
	if vertices.size() < 2:
		return
	
	triangles.append( [vertices, colors, tangents, uvs, normals] )
	

# Adds a series of triangles that just have geometry.
func add_triangle_vertices(vertices):
	
	var vertex_stack = vertices
	while vertex_stack.size() != 0:
		var v1 = vertex_stack.pop_front()
		var v2 = vertex_stack.pop_front()
		var v3 = vertex_stack.pop_front()
		
		triangles.append( [[v1, v2, v3], [], [], [], []] )
	 