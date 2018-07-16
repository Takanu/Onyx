tool
extends EditorSpatialGizmo

# ////////////////////////////////////////////////////////////
# INFO
# A basic custom gizmo with built in support for snapping  handle movement to an axis.

# Handle Format: [ handle_position, [snapping_triangle]? ]
# Line Format: [ PoolVector3Array lines, color ]

# The snapping triangle array should be an array of three vertices, where it's surface normal will be used to create a singular
# snapping axis to constrain handle movement.


# ////////////////////////////////////////////////////////////
# REQUIRED IMPLEMENTATION

# Any node that uses this must have the following functions:

# - handle_update(index, coord)
# - handle_commit(index, coord)
# - get_undo_state()
# - restore_state(state)


# ////////////////////////////////////////////////////////////
# PROPERTIES

# The node this gizmo belongs to.
var node

# The plugin thats responsible for providing the gizmo
var plugin

# The resource used for the handle.
var handle_billboard = load("res://addons/onyx/gizmos/default_gizmo.tres")

# The points we need to manage for handles, provided by the owning Spatial
# formatted in tuples of (3d_point [snapping_axes])
var handle_points = []

# The index of the handle currently being modified.
var handle_current_index = -1

# The previous data for the currently dragged handle, before it was edited.
var handle_current_data


# Any lines that should be rendered to represent debug data.
var lines = []


# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _init(plugin, node):
	self.node = node
	self.plugin = plugin
	set_spatial_node(node)
	
func redraw():
	if node.gizmo_handles == null:
		print("No handle points :(")
		return
	
	handle_points = node.gizmo_handles
	#var triangles = node.get_gizmo_collision()
	
	if handle_points.size() > 0:
		
		clear()
		
		var points = []
		for handle in handle_points:
			points.append(handle[0])
			
		add_handles(points, false, true)
			
		for line_set in lines:
			#print("adding lines~~~")
			print(line_set[0].size())
			add_lines(line_set[0], mat_solid_color(line_set[1].r, line_set[1].g, line_set[1].b), false)
		
		
		plugin.update_overlays() 
	
	
# ////////////////////////////////////////////////////////////
# HANDLE MOVEMENT
	
# This function is used when the user drags a gizmo handle 
# (previously added with add_handles) in screen coordinates.
func set_handle(index, camera, point):
	
	#print("++++++++++++++++")
	#print("SETTING HANDLE")
	
	handle_points = node.gizmo_handles
	handle_current_index = index
	
	var handle = handle_points[index]
	var coord = handle[0]
	var triangle = handle[1]
	
	if not handle_current_data:
		handle_current_data = coord
	else:
		coord = handle_current_data
	
	# Get some matrices and coordinates
	var world_matrix = node.global_transform
	var camera_matrix = camera.global_transform
	
	# Apply the current coordinate to world and camera space
	var world_space_coord = world_matrix.xform(coord)
	var cam_space_coord = camera_matrix.xform_inv(world_space_coord)
	
	
	# ///////////////////////////////////////////////////////
	# CONSTRAINT AXIS USAGE
	if triangle != null:
		
		#print("RAWR HANDLE MOVED: ", coord)
		var planes = make_planes(triangle, coord)
		#print("PLANES: ", planes)
	
		var ray_origin = camera.project_ray_origin(point)
		var ray_dir = camera.project_ray_normal(point)
		ray_origin = world_matrix.xform_inv(ray_origin)
		ray_dir = world_matrix.basis.xform_inv(ray_dir)
		
		
		coord = planes[0].intersects_ray(ray_origin, ray_dir)
		if not coord: 
			return #sometimes the projection might fail
			
		if planes.size() > 1:
			coord = planes[1].project(coord)
		
	# ///////////////////////////////////////////////////////
	# NORMAL DRAG USAGE
	else:
		# Create a screen plane using the points switched coordinate-space Z-axis.
		# Create a ray that points from the point we're provided to the camera.
		# Create an origin using the new point we have.
		var project_plane = Plane(0,0,1, cam_space_coord.z)
		var ray_dir = camera.project_local_ray_normal(point)
		var ray_origin = camera_matrix.xform_inv(camera.project_ray_origin(point))
			
			
		# Get a 3D coordinate we can use based on a ray intersection of the 2D point.
		# Sometimes the projection might fail so we need to return if that's the case.
		coord = project_plane.intersects_ray(ray_origin, ray_dir)
		if not coord: 
			return 
		
		# If it worked, configure and apply it.
		coord = camera_matrix.xform(coord)
		coord = world_matrix.xform_inv(coord)
	
	
	# Set the new point
	handle_points[index] = [coord, triangle]
	
	# Notify the node about this new change
	node.handle_update(index, coord)
	
	redraw()
	
	
# Allows an external function to get the coordinates of a handle.
func get_handle_value(index):
	return handle_points[index][0]
	
	
# Used for undo/redo stuff.
func restore_undo_state(state):
	node.restore_state(state)
	
	
# Commits the handle to the property (if not cancelled).
func commit_handle(index, restore, cancel):
	if not cancel:
		
		var new_data = handle_points[index][0]
		
		var undo_data = node.get_undo_state()
		node.handle_commit(index, new_data)
		var redo_data = node.get_undo_state()
		
		var undo_redo = plugin.get_undo_redo()
		undo_redo.create_action("Transform OnyxCube Point "+str(index))
		undo_redo.add_do_method(self, "restore_undo_state", redo_data)
		undo_redo.add_undo_method(self, "restore_undo_state", undo_data)
		undo_redo.commit_action()
		
	else:
		var handle = handle_points[handle_current_index]
		handle[0] = handle_current_data
		handle_points[handle_points] = handle
		
		node.handle_commit(index, handle_current_data)
	
	handle_current_data = null
	handle_current_index = -1
	
	
	redraw()


# ////////////////////////////////////////////////////////////
# HELPERS
		
func make_planes(triangle, handle_loc):
	
	if typeof(triangle) != TYPE_ARRAY:
		print("(onyx_cube_gizmo : make_planes) No triangle set provided.")
	
	if triangle.size() < 3:
		print("(onyx_cube_gizmo : make_planes) Not enough triangles given.")
	
	# get the unit vector of the two vectors made from the triangle
	var movement_vector =  handle_loc - triangle[0]
	var vertex_1 = triangle[0] + movement_vector
	var vertex_2 = triangle[1] + movement_vector
	var vertex_3 = triangle[2] + movement_vector
	
	var vec_1 = (vertex_2 - vertex_1).normalized()
	var vec_2 = (vertex_3 - vertex_1).normalized()
	var cross = vec_1.cross(vec_2)
	var vertex_4 = (cross * 2) + vertex_1
	
	#print("VECTORS: ", vec_1, vec_2, cross)
	#print("FINAL VERTICES: ", vertex_1, vertex_2, vertex_3, vertex_4)
	
	# Build the planes
	var plane_1 = Plane(vertex_1, vertex_2, vertex_4)
	var plane_2 = Plane(vertex_1, vertex_3, vertex_4)
	
	return [plane_1, plane_2]



func mat_solid_color(red, green, blue):
	var mat = SpatialMaterial.new()
	mat.render_priority = mat.RENDER_PRIORITY_MAX
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.flags_no_depth_test = true
	mat.albedo_color = Color(red, green, blue)
	
	return mat


