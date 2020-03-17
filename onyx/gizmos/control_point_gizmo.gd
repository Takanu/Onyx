tool
extends EditorSpatialGizmo

# ////////////////////////////////////////////////////////////
# INFO
# A compound gizmo system that uses ControlPoint types instead of loose positions, allowing one node to display gizmos for multiple other nodes as well as being able to display and manage more complicated sets of ControlPoints.
#
#
# Any callbacks are handled through the GizmoHandle type itself.


# ////////////////////////////////////////////////////////////
# INTERFACE

# get_gizmo_control_points() - Owning node must implement this to forward handle data.



# ////////////////////////////////////////////////////////////
# PROPERTIES

# An array of ControlPoint objects that this gizmo should display.  These are always provided by and updated by the spatial node that owns it.
# WARNING - NEVER EDIT THIS LIST WHILE A HANDLE IS BEING OPERATED ON, AND NEVER CHANGE HANDLE VISIBILITY WHILE A HANDLE IS BEING OPERATED ON.
# Control point handling requires knowing what index the handle comes from, and either above changes the indexing.
var control_points = [] 

# Used to preserve the state of the handle being operated on, if the operation is abruptly cancelled.
var control_data_hold

# TEMP
var is_mesh_set = false


# ////////////////////////////////////////////////////////////
# INITIALIZATION

func _init():
	pass


# ////////////////////////////////////////////////////////////
# CONTROL POINT BUILDING
func set_control_points(points : Array):
	control_points = points.duplicate()

# ////////////////////////////////////////////////////////////
# REDRAWING

# Redraws all lines, meshes and gizmos.
func redraw():
#	
	# Clear the old draw data.
	clear()
	
	# Get new control points every time to ensure we have the ones we need (changed since OnyxPolygon)
	control_points = get_spatial_node().call("get_gizmo_control_points")
	
	# If we have a node we can generate a clickable collision mesh for, do it.
	var collision_set
	var node = get_spatial_node()
	
	if node is CSGMesh:
		if node.mesh != null:
			collision_set = node.mesh.generate_triangle_mesh()
	
	
	# Go through all the handles available
	var handle_mat = get_plugin().get_material("handle", self)
	var handles = PoolVector3Array()
		
	for control in control_points:
		var handle_positions = control.get_handle_positions()
		
		if handle_positions is Array:
			for handle_pos in handle_positions:
				handles.push_back(handle_pos)
	
	# Don't add a mesh to a Gizmo, this is poorly optimized and designed.
#	var mesh_result = node.call("get_gizmo_mesh")
#	if mesh_result is Array:
#		if mesh_result.size() == 2:
#			if mesh_result[0] != null:
#				add_mesh(mesh_result[0], false, null, load(mesh_result[1]))
			
	# Grabs handles
	if handles.size() > 0:
		add_handles(handles, handle_mat)
	
	
	# Go through all the lines available
	for control in control_points:
		var lines = control.get_handle_lines()
		
		if lines is Array:
			for line in lines:
				
				add_lines(line[0], line[1], false)
	
	# Add the collision triangles
	if collision_set != null:
		add_collision_triangles(collision_set)
	

# ////////////////////////////////////////////////////////////
# HANDLE MOVEMENT
	
# This function is used when the user drags a gizmo handle 
# (previously added with add_handles) in screen coordinates.
func set_handle(index, camera, point):
	
	# we have to figure out based on the index, what control point this handle belongs to.
	var result = get_control_point(index)
	var target_control = result['control']
	var local_index = result['local_index']
	
	if target_control != null:
		target_control.update_handle(local_index, camera, point)
	
	redraw()

# Allows an external function to get the coordinates of a handle.
# (REQUIRED FOR commit_handle TO WORK, DO NOT REMOVE)
func get_handle_value(index):
	var result = get_control_point(index)
	return result['control'].control_position


# Commits the handle to the property (if not cancelled).
func commit_handle(index, restore, cancel=false):
	
	var result = get_control_point(index)
	var target_control = result['control']
	var local_index = result['local_index']
	
#	print("we made it bois")
	
	if target_control == null:
		print("err, fuck?")
		return
	
	if not cancel:
#		print("COMMITTING NEW UNDO DATA: ", restore)
		
		# Commit the undo data first so we have it for later
		var undo_data = target_control.get_undo_data()
		target_control.commit_handle(local_index, restore)
		
		# Now build the redo data
		var redo_data = target_control.get_redo_data()
		
#		print('=================================')
#		print("UNDO DATA: ", undo_data)
#		print('=================================')
#		print("REDO DATA: ", redo_data)
#		print('=================================')
#		print('=================================')
		
		# Now commit both pieces of data onto the undo/redo stack.
		var undo_redo = get_plugin().plugin.get_undo_redo()
		undo_redo.create_action("Onyx Control Point Commit "+str(index))
		undo_redo.add_do_method(target_control.control_point_owner, target_control.redo_action_callback, redo_data)
		undo_redo.add_undo_method(target_control.control_point_owner, target_control.undo_action_callback, undo_data)
		undo_redo.commit_action()
		
		
	else:
#		print("we cancelled?  hmm")
#		var handle = handle_set[handle_current_index]
#		handle[0] = handle_current_data
#		handle_set[handle_current_index] = handle

		target_control.restore_base_properties(control_data_hold)
		target_control.commit_handle(index, restore)
	
	control_data_hold = null
	
	
	redraw()

# Returns the control point that matches a given index.
func get_control_point(index):
	
	var result = {}
	var current_index = 0
	for control in control_points:
		var control_count = control.get_handle_count()
		
		if index < current_index + control_count:
			var local_index = index - current_index
			return {'control': control, 'local_index': local_index}
		
		current_index += control_count
	
	return null
	

