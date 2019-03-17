tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Shared toolset for Onyx-type nodes, dealing with CSG shape creation.

# ////////////////////////////////////////////////////////////
# MESH RENDERING

static func render_onyx_mesh(node):
	
	# Optional UV Modifications
	var tf_vec = node.uv_scale
	if tf_vec.x == 0:
		tf_vec.x = 0.0001
	if tf_vec.y == 0:
		tf_vec.y = 0.0001
	
#	if self.invert_faces == true:
#		tf_vec.x = tf_vec.x * -1.0
	if node.flip_uvs_vertically == true:
		tf_vec.y = tf_vec.y * -1.0
	if node.flip_uvs_horizontally == true:
		tf_vec.x = tf_vec.x * -1.0
	
	node.onyx_mesh.multiply_uvs(tf_vec)
	
	# Create new mesh
	var array_mesh = node.onyx_mesh.render_surface_geometry(node.material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	# Set the new mesh
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	node.set_mesh(mesh)

# ////////////////////////////////////////////////////////////
# HANDLE MANAGEMENT FUNCTIONS

# Notifies the node that a handle has changed.
static func handle_change(node, index, coord):
	
	node.update_handle_from_gizmo(index, coord)
	node.generate_geometry(false)
	
	# FALLBACK HANDLE STUFF
	# Designed to compensate for when no old_handles data exists, to ensure undos still work.
	if node.old_handles.size() == 0 || node.old_handles == null:
		node.old_handles = node.handles.duplicate(true)
	


# Called when a handle has stopped being dragged.
static func handle_commit(node, index, coord):
	
	node.update_handle_from_gizmo(index, coord)
	node.generate_geometry(true)
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	node.old_handles = node.handles.duplicate(true)
	

# ////////////////////////////////////////////////////////////
# UNDO/REDO STATES
# Returns a state that can be used to undo or redo a previous change to the shape.
static func get_gizmo_redo_state(node):
	return [node.handles.duplicate(true), node.translation]


# Returns a state specifically for undo functions in SnapGizmo.
static func get_gizmo_undo_state(node):
	return [node.old_handles.duplicate(true), node.translation]


# Restores the state of the shape to a previous given state.
static func restore_state(node, state):
	var new_handles = state[0]
	var stored_translation = state[1]
	
	print("RESTORING STATE -", state)
	
	node.handles = new_handles.duplicate(true)
	node.old_handles = new_handles.duplicate(true)
	node.apply_handle_attributes()
	node.generate_geometry(true)
	
	node.translation = stored_translation