tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Used to perform additional common operations across 


# Returns the AABB of any given node.  May return nothing if the node provided has no data to extrapolate bounds from.
func get_aabb(node):
	
	# //////////////
	# MESH NODES
	if node is Mesh:
		return get_mesh_aabb(node)
		
	elif node is MultiMesh:
		return node.get_aabb()
		
	elif node is MeshInstance:
		return get_mesh_aabb(node.get_mesh())
		
	elif node is ImmediateGeometry:
		print("onyx_utils.get_aabb(node) cannot obtain data from ImmediateGeometry, provide a face_dictionary instead.")
		return
		
	# //////////////
	# CSG NODES
	elif node is CSGBox:
		var ub = Vector3(node.width / 2, node.height / 2, node.depth / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node is CSGCylinder:
		var ub = Vector3(node.radius / 2, node.height / 2, node.radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node is CSGPolygon:
		print("onyx_utils.get_aabb(node) cannot obtain data from CSGPolygon, im just not going to go there right now.")
		return
		
	elif node is CSGSphere:
		var ub = Vector3(node.radius / 2, node.radius / 2, node.radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
		
	elif node is CSGTorus:
		var ub = Vector3(node.outer_radius / 2, node.outer_radius / 2, node.outer_radius / 2)
		var lb = ub * -1
		return AABB(lb, ub)
	
	elif node is CSGMesh:
		return get_mesh_aabb(node.get_mesh())
		
	elif node is CSGShape:
		print("onyx_utils.get_aabb(node) cannot obtain data from CSGShape, provide a different CSG or node type")
		return
		
	# //////////////
	# OTHER NODES
	elif node is SpriteBase3D:
		print("SpriteBase3D not yet available for use with onyx_utils.get_aabb(node).")
		return
	
	elif node is CollisionPolygon:
		print("onyx_utils.get_aabb(node) refuses to use a CollisionPolygon as it wont be used at runtime, use a CollisionShape or literally anything else :D")
		return
		
	elif node is CollisionShape:
		var shape = node.shape()
		
		if shape is BoxShape:
			var ub = Vector3(shape.extents.x / 2, shape.extents.y / 2, shape.extents.z / 2)
			var lb = ub * -1
			return AABB(lb, ub)
			
		elif shape is CapsuleShape:
			var ub = Vector3(shape.radius, shape.radius, (shape.radius / 2) + shape.height)
			var lb = ub * -1
			return AABB(lb, ub)
		
		elif shape is ConcavePolygonShape:
			return get_vertex_aabb(shape.get_faces())
			
		elif shape is ConvexPolygonShape:
			return get_vertex_aabb(shape.get_points())
			
		elif shape is CylinderShape:
			var ub = Vector3(shape.radius, shape.height / 2, shape.radius)
			var lb = ub * -1
			return AABB(lb, ub)
			
		elif shape is PlaneShape:
			print("Really?  REALLY?  onyx_utils.get_aabb(node) refuses to use a PlaneShape, choose literally anything else plz.")
			return
			
		elif shape is RayShape:
			return
			
		elif shape is SphereShape:
			var ub = Vector3(shape.radius, shape.radius, shape.radius)
			var lb = ub * -1
			return AABB(lb, ub)
		
	
	return null
	
	
# Gets the AABB of any given Mesh.
func get_mesh_aabb(mesh):
	
	if mesh is Mesh:
		var vertex_pool = mesh.get_faces()
		var v_size = vertex_pool.size()
		
		if v_size == 0:
			return AABB(Vector3(0, 0, 0), Vector3(0, 0, 0))
			
		#var i = 0
		var lb = Vector3(0, 0, 0)
		var ub = Vector3(0, 0, 0)
			
		for vertex in vertex_pool:
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
		
	else:
		return null

# Get an AABB from any vertex pool.	
func get_vertex_aabb(vertex_pool):
	
	var v_size = vertex_pool.size()
	
	if v_size == 0:
		return AABB(Vector3(0, 0, 0), Vector3(0, 0, 0))
		
	#var i = 0
	var lb = Vector3(0, 0, 0)
	var ub = Vector3(0, 0, 0)
		
	for vertex in vertex_pool:
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