tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Shared toolset for Onyx-type nodes, dealing with CSG shape creation and shared functionality.

# ////////////////////////////////////////////////////////////
# INITIALIZATION
# Performs 
static func onyx_ready(node):
	
	if Engine.editor_hint == true:
		node.build_handles()
		
		if node.mesh == null:
			node.generate_geometry(true)
		
		node.generate_handles()
		
		# Ensure the old_handles variable match the current handles we have for undo/redo.
		node.old_handle_data = get_control_data(node)
	


# ////////////////////////////////////////////////////////////
# MESH RENDERING

# Updates the main material slot for Onyx shapes.
static func update_material(node, new_value):

	print("updating mat - ", node, new_value)
	
	# Prevents geometry generation if the node hasn't loaded yet, otherwise it will try to set a blank mesh.
	if node.is_inside_tree() == false:
		return
	
	# If we don't have an onyx_mesh with any data in it, we need to construct that first to apply a material to it.
	# This shouldn't be cleared during the duplication process, but it does.  Hmm...
	if node.onyx_mesh.tris.size() == 0:
		print("regenerating mesh from mat update - ", node, new_value)
		node.generate_geometry(true)
	
	var array_mesh = node.onyx_mesh.render_surface_geometry(node.material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	node.set_mesh(mesh)


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
# STATE MANAGEMENT

# Returns a list of handle data from each handle.
static func get_control_data(node) -> Dictionary:
	
	var result = {}
	for control in node.handles.values():
		result[control.control_name] = control.get_control_data()
	
	return result

# Changes all current handle data with a previously set list of handle data.
static func set_control_data(node : Object, data : Dictionary):
	
	for data_key in data.keys():
		node.handles[data_key].set_control_data(data[data_key])


# ////////////////////////////////////////////////////////////
# HANDLE MANAGEMENT FUNCTIONS

# Notifies the node that a handle has changed.
static func handle_change(node, control):
	
	node.update_handle_from_gizmo(control)
	node.generate_geometry(false)
	

# Called when a handle has stopped being dragged.
# NOTE - This should only finish committing information, restore_state will finalize movement and other opeirations.
static func handle_commit(node, control):
	
	node.update_handle_from_gizmo(control)
	node.apply_handle_attributes()
	
	if node.has_method('update_origin_position') == true:
		node.update_origin_position()
	
	node.generate_geometry(false)
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	node.old_handle_data = get_control_data(node)
	

# ////////////////////////////////////////////////////////////
# UNDO/REDO STATES
# Returns a state that can be used to undo or redo a previous change to the shape.
static func get_gizmo_redo_state(node):
	var saved_translation = node.global_transform.origin
	return [get_control_data(node), saved_translation]
	
	# If it has this method, it will have an origin setting.  This must then be preserved.
	if node.has_method('update_origin_position') == true:
		node.update_origin_position()
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	node.old_handle_data = get_control_data(node)


# Returns a state specifically for undo functions in SnapGizmo.
static func get_gizmo_undo_state(node):
	var saved_translation = node.global_transform.origin
	return [node.old_handle_data.duplicate(false), saved_translation]


# Restores the state of the shape to a previous given state.
static func restore_state(node, state):
	
	var new_handles = state[0]
	var stored_location = state[1]
	
#	print("RESTORING STATE -", state)
	
	set_control_data(node, new_handles)
	node.old_handle_data = new_handles.duplicate(true)
	node.apply_handle_attributes()
	
	if node.has_method('update_origin_position') == true:
		node.update_origin_position(stored_location)
	if node.has_method('balance_handles') == true:
		node.balance_handles()
	node.generate_geometry(true)
	

# ////////////////////////////////////////////////////////////
# CHILD MANAGEMENT
static func translate_children(node, translation):
	
	for child in node.get_children():
		child.global_translate(translation)