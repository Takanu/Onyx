tool
extends EditorSpatialGizmo

# ////////////////////////////////////////////////////////////
# INFO
# A basic custom gizmo with built in support for snapping  handle movement to an axis.

# Handle Format: { handle_position, [snapping_triangle]? }
# Line Format: [ PoolVector3Array lines, color ]

# The snapping triangle array should be an array of three vertices, where it's surface normal will be used to create a singular
# snapping axis to constrain handle movement.


# ////////////////////////////////////////////////////////////
# REQUIRED IMPLEMENTATION

# Any node that uses this must have the following functions:

# - handle_change(index, coord)
# - handle_commit(index, coord)
# - get_undo_redo_state()
# - restore_state(state)
 

# ////////////////////////////////////////////////////////////
# PROPERTIES

# The resource used for the handle.
var handle_billboard = load("res://addons/onyx/gizmos/default_gizmo.tres")

# The points we need to manage for handles, provided by the owning Spatial
# formatted in tuples of (3d_point [snapping_axes])
var handle_set = []

# The index of the handle currently being modified.
var handle_current_index = -1

# The previous data for the currently dragged handle, before it was edited.
var handle_current_data

# Any lines that should be rendered to represent debug data.
var lines = []


# ////////////////////////////////////////////////////////////
# INITIALIZATION

func _init():
	pass
	print("gizmo initialization finished.")
	

# ////////////////////////////////////////////////////////////
# REDRAWING

# Redraws all lines, meshes and gizmos.
func redraw():
#	print("REDRAWING GIZMO -", self)
	clear()
	
	handle_set = get_spatial_node().convert_handles_to_gizmo()
	
	if handle_set.size() > 0:
		
		var points = PoolVector3Array()
		for handle in handle_set:
			points.push_back(handle[0])
		
		var handle_mat = get_plugin().get_material("handle", self)
		add_handles(points, handle_mat)
		
	
	for line_set in lines:
		#print("adding lines~~~")
		print(line_set[0].size())
		add_lines(line_set[0], mat_solid_color(line_set[1].r, line_set[1].g, line_set[1].b), false)
		
	# I have no idea what this does tbqh
	#get_plugin().update_overlays() 
	
	
# ////////////////////////////////////////////////////////////
# HANDLE MOVEMENT
	
# This function is used when the user drags a gizmo handle 
# (previously added with add_handles) in screen coordinates.
func set_handle(index, camera, point):
	
#	print("++++++++++++++++")
#	print("SETTING HANDLE")
	
	handle_set = get_spatial_node().convert_handles_to_gizmo()
	handle_current_index = index
	
	var handle = handle_set[index]
	var coord = handle[0]
	var triangle = handle[1]
	
	if not handle_current_data:
		handle_current_data = coord
	else:
		coord = handle_current_data
	
	# Get some matrices and coordinates
	var world_matrix = get_spatial_node().global_transform
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
	handle_set[index] = [coord, triangle]
	
	# Notify the node about this new change
	get_spatial_node().handle_change(index, coord)
	
	redraw()
	
	
# Allows an external function to get the coordinates of a handle.
func get_handle_value(index):
	return handle_set[index][0]
	
	
# Used for undo/redo stuff.
# NOT NEEDED, WUPWUP
#func restore_undo_redo_state(state):
#	get_spatial_node().restore_state(state)
	
	
# Commits the handle to the property (if not cancelled).
func commit_handle(index, restore, cancel=false):
	if not cancel:
		
		print("COMMITTING NEW UNDO DATA: ", restore)
		
		# Commit the undo data first so we have it for later
		var new_data = handle_set[index][0]
		var undo_data = get_spatial_node().get_gizmo_undo_state()
		get_spatial_node().handle_commit(index, new_data)
		
		# Now build the redo data
		var redo_data = get_spatial_node().get_gizmo_redo_state()
		
#		print('=================================')
#		print("UNDO DATA: ", undo_data)
#		print('=================================')
#		print("REDO DATA: ", redo_data)
#		print('=================================')
#		print('=================================')
		
		# Now commit both pieces of data onto the undo/redo stack.
		var undo_redo = get_plugin().plugin.get_undo_redo()
		undo_redo.create_action("Onyx Handle Commit "+str(index))
		undo_redo.add_do_method(get_spatial_node(), "restore_state", redo_data)
		undo_redo.add_undo_method(get_spatial_node(), "restore_state", undo_data)
		undo_redo.commit_action()
		
		
	else:
		var handle = handle_set[handle_current_index]
		handle[0] = handle_current_data
		handle_set[handle_current_index] = handle
		
		get_spatial_node().handle_commit(index, handle_current_data)
	
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
	var cross = vec_1.cross(vec_2).normalized()
	var vertex_4 = (cross * 2) + vertex_1
	
	#print("VECTORS: ", vec_1, vec_2, cross)
	#print("FINAL VERTICES: ", vertex_1, vertex_2, vertex_3, vertex_4)
	
	# Build the planes
	var plane_1 = Plane(vertex_1, vertex_2, vertex_4)
	var plane_2 = Plane(vertex_1, vertex_3, vertex_4)
	
	#print("PLANE 1 : ", plane_1)
	#print("PLANE 2 : ", plane_2)
	
	return [plane_1, plane_2]



func mat_solid_color(red, green, blue):
	var mat = SpatialMaterial.new()
	mat.render_priority = mat.RENDER_PRIORITY_MAX
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.flags_no_depth_test = true
	mat.albedo_color = Color(red, green, blue)
	
	return mat


