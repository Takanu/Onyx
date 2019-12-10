tool
extends CSGMesh

# ////////////////////////////////////////////////////////////
# INFO
# Base class for all Onyx-type nodes, provides fundamental functionality.


# ////////////////////////////////////////////////////////////
# PROPERTIES

# CORE //////////////

# The plugin this node belongs to
var plugin

# The face set script, used for managing geometric data.
var onyx_mesh = OnyxMesh.new()

# The handle points that will be used to resize the mesh (NOT built in the format required by the gizmo)
var handles : Dictionary = {}

# Old handle points that are saved every time a handle has finished moving.
var old_handle_data : Dictionary = {}

# The offset of the origin relative to the rest of the mesh.
var origin_offset = Vector3(0, 0, 0)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

# If true, this node is currently selected.
var is_selected = false


# BEVELS //////////////

#export(float) var bevel_size = 0.2 setget update_bevel_size
#enum BevelTarget {Y_AXIS, X_AXIS, Z_AXIS}
#export(BevelTarget) var bevel_target = BevelTarget.Y_AXIS setget update_bevel_target


# UVS //////////////

var uv_scale = Vector2(1.0, 1.0)
var flip_uvs_horizontally = false
var flip_uvs_vertically = false


# ////////////////////////////////////////////////////////////
# SET/GETTERS

func _get_property_list():
	var props = [
		{
			"name" : "uv_options/uv_scale",
			"type" : TYPE_VECTOR2,
		},
		
		{
			"name" : "uv_options/flip_uvs_horizontally",
			"type" : TYPE_BOOL,
		},
		
		{
			"name" : "uv_options/flip_uvs_vertically",
			"type" : TYPE_BOOL,
		}
	]
	return props

func _set(property, value):
	match property:
		"uv_options/uv_scale":
			uv_scale = value
		"uv_options/flip_uvs_horizontally":
			flip_uvs_horizontally = value
		"uv_options/flip_uvs_vertically":
			flip_uvs_vertically = value
			
	generate_geometry()


func _get(property):
	match property:
		"uv_options/uv_scale":
			return uv_scale
		"uv_options/flip_uvs_horizontally":
			return flip_uvs_horizontally
		"uv_options/flip_uvs_vertically":
			return flip_uvs_vertically

# ////////////////////////////////////////////////////////////
# FUNCTIONS

# Global initialisation
func _enter_tree():
	
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:
		
		# load plugin
		plugin = get_node("/root/EditorNode/Onyx")
		
		# this used to mean something, not anymore though
#		set_notify_local_transform(true)
#		set_notify_transform(true)
#		set_ignore_transform_notification(false)

# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.editor_hint == true:
		if mesh == null:
			build_handles()
			generate_geometry()
			refresh_handle_data()
		
		# Ensure the old_handles variable match the current handles we have for undo/redo.
		old_handle_data = get_control_data()

# This was used, but there's no reason for it to be here.
#func _notification(what):
#
#	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
#
#		# check that transform changes are local only
#		if local_tracked_pos != translation:
#			local_tracked_pos = translation
#			call_deferred("_editor_transform_changed")
#
#func _editor_transform_changed():
#	pass
#


# ////////////////////////////////////////////////////////////
# MESH BUILDING AND RENDERING

func generate_geometry(fix_to_origin_setting = false):
	print("nope!")
	pass

func render_onyx_mesh():
	
	# Optional UV Modifications
	var tf_vec = uv_scale
	if tf_vec.x == 0:
		tf_vec.x = 0.0001
	if tf_vec.y == 0:
		tf_vec.y = 0.0001
	
#	if self.invert_faces == true:
#		tf_vec.x = tf_vec.x * -1.0
	if flip_uvs_vertically == true:
		tf_vec.y = tf_vec.y * -1.0
	if flip_uvs_horizontally == true:
		tf_vec.x = tf_vec.x * -1.0
	
	onyx_mesh.multiply_uvs(tf_vec)
	
	# Create new mesh
	var array_mesh = onyx_mesh.render_surface_geometry(material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	# Set the new mesh
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	set_mesh(mesh)
	



# ////////////////////////////////////////////////////////////
# HANDLE GENERATION FUNCTIONS

func update_origin_position(new_location = null):
	pass

func build_handles():
	pass

func refresh_handle_data():
	pass

func update_handle_from_gizmo(control):
	pass

func apply_handle_attributes():
	pass

func balance_handles():
	pass

# ////////////////////////////////////////////////////////////
# HANDLE MANAGEMENT FUNCTIONS

# Used when an object is selected for the handles to be built.
func handle_build():
	
	if Engine.editor_hint == true:
		build_handles()
		refresh_handle_data()
		old_handle_data = get_control_data()

# Used when an object is deselected to clear the handle info.
func handle_clear():
	
	gizmo.control_points.clear()
	handles.clear()
	

# Notifies the node that a handle has changed.
func handle_change(control):
	
	update_handle_from_gizmo(control)
	generate_geometry()
	

# Called when a handle has stopped being dragged.
# NOTE - This should only finish committing information, restore_state will finalize movement and other opeirations.
func handle_commit(control):
	
	update_handle_from_gizmo(control)
	apply_handle_attributes()
	
	update_origin_position()
	generate_geometry()
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	old_handle_data = get_control_data()

func get_gizmo_control_points() -> Array:
	return handles.values()

# ////////////////////////////////////////////////////////////
# STATE MANAGEMENT

# Returns a list of handle data from each handle.
func get_control_data() -> Dictionary:
	
	var result = {}
	for control in handles.values():
		result[control.control_name] = control.get_control_data()
	
	return result

# Changes all current handle data with a previously set list of handle data.
func set_control_data(data : Dictionary):
	
	for data_key in data.keys():
		handles[data_key].set_control_data(data[data_key])
		

# ////////////////////////////////////////////////////////////
# UNDO/REDO STATES
# Returns a state that can be used to undo or redo a previous change to the shape.
func get_gizmo_redo_state(control_point):
	var saved_translation = global_transform.origin
	return [get_control_data(), saved_translation]
	
	# If it has this method, it will have an origin setting.  This must then be preserved.
	update_origin_position()
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	old_handle_data = get_control_data()


# Returns a state specifically for undo functions in SnapGizmo.
func get_gizmo_undo_state(control_point):
	var saved_translation = global_transform.origin
	return [old_handle_data.duplicate(false), saved_translation]


# Restores the state of the shape to a previous given state.
func restore_state(state):
	
	var new_handles = state[0]
	var stored_location = state[1]
	
#	print("RESTORING STATE -", state)
	
	set_control_data(new_handles)
	old_handle_data = new_handles.duplicate(true)
	apply_handle_attributes()
	
	update_origin_position(stored_location)
	balance_handles()
	
	generate_geometry()
	

# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

func editor_select():
	print("EDITOR SELECTED")
	is_selected = true
	handle_build()
	
	
func editor_deselect():
	print("EDITOR DESELECTED")
	is_selected = false
	handle_clear()
	


# ////////////////////////////////////////////////////////////
# CHILD MANAGEMENT
func translate_children(translation):
	
	for child in get_children():
		child.global_translate(translation)
