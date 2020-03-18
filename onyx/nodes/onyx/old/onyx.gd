tool
extends CSGMesh

# ////////////////////////////////////////////////////////////
# INFO
# Base class for all Onyx-type nodes, provides fundamental functionality.


# ////////////////////////////////////////////////////////////
# PROPERTIES

# CORE //////////////

## The plugin this node belongs to
#var plugin

# The face set script, used for managing geometric data.
var onyx_mesh = OnyxMesh.new()

# A node created in edit-mode to visualize shapes involved in boolean operations.
var boolean_preview_node = null

# The name for the node used to preview non-union boolean modes.
const BOOLEAN_PREVIEW_NODE_NAME = "Boolean Preview"

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



# HOLLOW MODE //////////////

# Enables and disables hollow mode
var hollow_enable = false

# The object that if set, will be used to hollow out the main shape.
var hollow_object : CSGMesh = null

# Storage object for the hollow mesh, used during runtime.
var hollow_mesh : Mesh

# Hollow object material storage.
var hollow_material : Material

# Constant for the hollow name
const HOLLOW_OBJECT_NAME = "**HOLLOW ONYX OBJECT**"


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
#	print("[Onyx] ", self.get_name() , " - _get_property_list()")
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
		},
		
		{
			"name" : "hollow_mode/enable_hollow_mode",
			"type" : TYPE_BOOL,
		},
		
		{
			"name" : "hollow_mode/hollow_material",
			"type" : TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Material"
		},
		
		{
			"name" : "hollow_mode/hollow_mesh",
			"type" : TYPE_OBJECT,
			"usage" : PROPERTY_USAGE_STORAGE,
		}
	]
	
	
	return props

func _set(property, value):
#	print("[Onyx] ", self.get_name() , " - _set() : ", property, " ", value)
	
	# Same-value catcher.
	var old_value = self.get(property)
	if old_value != null:
		if old_value == value:
#			print("Same value assignment, BAIIIII")
			return
	
	match property:
		
		# Super-class properties /////
		"material":
			material = value
			update_geometry()
			return
		
		"operation":
			operation = value
			update_geometry()
			return
		
		# Saved internal properties /////
		
		
		# UVs /////
		
		"uv_options/uv_scale":
			uv_scale = value
			update_geometry()
			return
			
		"uv_options/flip_uvs_horizontally":
			flip_uvs_horizontally = value
			update_geometry()
			return
			
		"uv_options/flip_uvs_vertically":
			flip_uvs_vertically = value
			update_geometry()
			return
		
		# Hollow Mode
		"hollow_mode/enable_hollow_mode":
			_update_hollow_enable(value)
			return
			
		"hollow_mode/hollow_material":
			_update_hollow_material(value)
			return
			
		"hollow_mode/hollow_mesh":
			hollow_mesh = value
			return
	


func _get(property):
#	print("[Onyx] ", self.get_name() , " - _get() : ", property)
	match property:
		
		# Saved internal properties
		
		# UVs
		"uv_options/uv_scale":
			return uv_scale
		"uv_options/flip_uvs_horizontally":
			return flip_uvs_horizontally
		"uv_options/flip_uvs_vertically":
			return flip_uvs_vertically
		
		# Hollow Mode
		"hollow_mode/enable_hollow_mode":
			return hollow_enable
		"hollow_mode/hollow_material":
			return hollow_material
		"hollow_mode/hollow_mesh":
			return hollow_mesh
	

# Used to prevent weird "disappearances" of the plugin.  smh...
func get_plugin():
	if Engine.editor_hint == true:
		return get_node("/root/EditorNode/Onyx")
	else:
		return null

# ////////////////////////////////////////////////////////////
# FUNCTIONS

# Global initialisation
func _enter_tree():
	
#	print("[Onyx] ", self.get_name() , " - _enter_tree()")
	
	# Required to build hollow data before the scene loads
	if Engine.editor_hint == false:
		_build_runtime_hollow_object()
		

# Called when the node enters the scene tree for the first time.
func _ready():
	
#	print("[Onyx] ", self.get_name() , " - _ready()")
#	print_property_status()
	
	if Engine.editor_hint == true:
		
		# If this is null, we can assume this node was just created,
		if mesh == null:
#			print("building kit")
			build_handles()
			update_geometry()
			use_collision = true
		
		# If we have an operation that ain't Addition, we need to render the preview mesh so we need handles anyway.  wupwup.
		else:
#			print("[Onyx] ", self.get_name() , "  Do we have handles? - ", handles)
			build_handles()
#			print("[Onyx] ", self.get_name() , "  Do we have handles? - ", handles)
			update_gizmo()
		
		create_boolean_preview()
		
		# Ensure the old_handles variable match the current handles we have for undo/redo.
		old_handle_data = get_control_data()
		
		# If hollow mode is on, initialize the data for it.
		if hollow_enable == true:
			_create_hollow_object()
	

# Used to perform some basic deallocation where necessary
func _exit_tree():
	
	# Trigger this to ensure nothing is left behind.
	if Engine.editor_hint == true:
		editor_deselect()
	
	return
	

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

func update_geometry():
	print("build_geometry() - Override this function!")
	pass

func render_onyx_mesh():
	
	# Optional UV Modifications
	var tf_vec = uv_scale
	if tf_vec.x == 0:
		tf_vec.x = 0.0001
	if tf_vec.y == 0:
		tf_vec.y = 0.0001
	
	if flip_uvs_vertically == true:
		tf_vec.y = tf_vec.y * -1.0
	if flip_uvs_horizontally == true:
		tf_vec.x = tf_vec.x * -1.0
	
	onyx_mesh.multiply_uvs(tf_vec)
	
	# Create new mesh
	array_mesh = onyx_mesh.render_surface_geometry(material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	# Set the new mesh
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	set_mesh(mesh)
	
	render_boolean_preview()
	

# Used to create a node used for previewing the mesh when using a non-union boolean mode.
func create_boolean_preview():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	boolean_preview_node = MeshInstance.new()
	boolean_preview_node.set_name(BOOLEAN_PREVIEW_NODE_NAME)
	add_child(boolean_preview_node)
	
	render_boolean_preview()

# Used to render the boolean preview.
func render_boolean_preview():
	
	if Engine.editor_hint == false || is_inside_tree() == false :
		return
	
	# If we have a boolean preview, decide what to do.
	if boolean_preview_node != null:
		
		if operation == 0:
			boolean_preview_node.visible = false
#			print("Boolean preview hidden")
			return
			
		else:
			boolean_preview_node.visible = true
			var boolean_material = null
			
			if operation == 1:
				boolean_material = load("res://addons/onyx/materials/wireframes/onyx_wireframe_int.material")
			elif operation == 2:
				boolean_material = load("res://addons/onyx/materials/wireframes/onyx_wireframe_sub.material")
			
			# Set the new mesh using the current mesh
			var helper = MeshDataTool.new()
			var boolean_mesh = Mesh.new()
			helper.create_from_surface(mesh, 0)
			helper.set_material(boolean_material)
			helper.commit_to_surface(boolean_mesh)
			
			boolean_preview_node.set_mesh(boolean_mesh)
			
#			print("Boolean preview rendered")
	



# ////////////////////////////////////////////////////////////
# HOLLOW MODE FUNCTIONS

# The margin options available in Hollow mode, using a list of the control names to setup margins for
func update_hollow_geometry() -> Array:
	print("[Onyx] ", self, " - build_hollow_geometry() - Override this function!")
	return []

# An override-able function used to set the hollow object's origin point.
func assign_hollow_origin():
	print("[Onyx] ", self, " - assign_hollow_origin() - Override this function!")
	pass

# Updates the hollow_enable property.  This is also responsible for creating and destroying the hollow object.
func _update_hollow_enable(value):
	
	if Engine.editor_hint == false:
		return
	
	# If we're not yet inside the tree, set the value and return.
	if is_inside_tree() == false:
		hollow_enable = value
		return
	
	# REMEMBER THAT SAVING A SCENE CAUSES PROPERTIES TO BE RE-APPLIED, INSURANCE POLICY
	if hollow_enable == value:
		return
	
	print("[Onyx] ", self.get_name() , " - _update_hollow_enable()")
	
	hollow_enable = value
	
	# if true, get the current class and instance it 
	if value == true:
		_create_hollow_object()
	else:
		_delete_hollow_object()
		

# Internal function for updating the hollow mesh
func _update_hollow_mesh(new_onyx_mesh : OnyxMesh):
	
	print("[Onyx] ", self.get_name() , " - _update_hollow_mesh()")
	
	if Engine.editor_hint == false:
		return
	
	if hollow_object == null:
		return
		
	# Optional UV Modifications
	var tf_vec = uv_scale
	if tf_vec.x == 0:
		tf_vec.x = 0.0001
	if tf_vec.y == 0:
		tf_vec.y = 0.0001
	
	if flip_uvs_vertically == true:
		tf_vec.y = tf_vec.y * -1.0
	if flip_uvs_horizontally == true:
		tf_vec.x = tf_vec.x * -1.0
	
	new_onyx_mesh.multiply_uvs(tf_vec)
	
	# Create new mesh
	array_mesh = new_onyx_mesh.render_surface_geometry(hollow_material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	# Set the new mesh
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	hollow_object.set_mesh(mesh)
	hollow_mesh = mesh


# Setter for hollow materials
func _update_hollow_material(value):
	
	if Engine.editor_hint == false || hollow_material == value:
		return
		
	hollow_material = value
	
	if hollow_object != null:
		hollow_object.material = value


# Creates the hollow object.
func _create_hollow_object():
		
		print("[Onyx] ", self.get_name() , " - _create_hollow_object()")
		
		# REMEMBER THAT RE-SAVING A SCRIPT CAUSES IT TO BE RELOADED, MUST HAVE INSURANCE POLICY
		if Engine.editor_hint == false || hollow_object != null:
#			print("Hollow object already found, returning!")
			return
		
		if has_node(HOLLOW_OBJECT_NAME):
			hollow_object = self.get_node(HOLLOW_OBJECT_NAME)
			return
		
		# Build the node
		hollow_object = CSGMesh.new()
		hollow_object.set_name(HOLLOW_OBJECT_NAME)
		add_child(hollow_object)
		
		# Check for mesh before generating one
		if hollow_mesh != null:
			hollow_object.set_mesh(hollow_mesh)
		else:
			update_hollow_geometry()
		
		# Set the origin and operation mode
		assign_hollow_origin()
		hollow_object.operation = 2
		
		# If the parent has a material, let the child inherit it.
		if hollow_material != null:
			hollow_object.material = hollow_material
		elif material != null:
			hollow_material = self.material
		
		print("new hollow object - ", hollow_object)

func _delete_hollow_object():
	
	print("[Onyx] ", self.get_name() , " - _delete_hollow_data()")
	
	remove_child(hollow_object)
		
	if hollow_object != null:
		hollow_object.queue_free()
		
	hollow_enable = false
	hollow_object = null
	hollow_mesh = null
	
	print("deleted hollow object - ", hollow_object)


# Used specifically for when the game is running, as the node is not saved with the file.
func _build_runtime_hollow_object():
	
	print("[Onyx] ", self.get_name() , " - _build_runtime_hollow_object()")
	
	if Engine.editor_hint == false:
		if hollow_mesh != null:
			
			print("buildin dat hollow - ", hollow_mesh)
			hollow_object = CSGMesh.new()
			hollow_object.set_name(HOLLOW_OBJECT_NAME)
			add_child(hollow_object)
			
			hollow_object.operation = 2
			hollow_object.material = hollow_material
			hollow_object.set_mesh(hollow_mesh)
			
			print(hollow_object.mesh)

# ////////////////////////////////////////////////////////////
# HANDLE GENERATION FUNCTIONS

func update_origin_position(new_location = null):
	print("[Onyx] ", self, " - update_origin_position() - Override this function!")
	pass

func build_handles():
	print("[Onyx] ", self, " - build_handles() - Override this function!")
	pass

func refresh_handle_data():
	print("[Onyx] ", self, " - refresh_handle_data() - Override this function!")
	pass

func update_handle_from_gizmo(control):
	print("[Onyx] ", self, " - update_handle_from_gizmo() - Override this function!")
	pass

func apply_handle_attributes():
	print("[Onyx] ", self, " - apply_handle_attributes() - Override this function!")
	pass

func balance_handles():
	print("[Onyx] ", self, " - balance_handles() - Override this function!")
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
	
	if Engine.editor_hint == true:
		gizmo.control_points.clear()
		handles.clear()
	

# Allows Control Points to notify the parent node that a handle has changed.
func handle_change(control):
	
#	print("********************************")
#	print("[Onyx] ", self.get_name() , " - handle_change()")
	
	update_handle_from_gizmo(control)
	update_geometry()
#	print("********************************")
	

# Allows Control Points to notify the parent node that a handle has stopped being edited.
# NOTE - This should only finish committing information, restore_state will finalize movement and other opeirations.
func handle_commit(control):
#	print("********************************")
#	print("[Onyx] ", self.get_name() , " - handle_commit()")
	
	update_handle_from_gizmo(control)
	apply_handle_attributes()
	
	update_origin_position()
	update_geometry()
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	old_handle_data = get_control_data()
	
#	print("********************************")

func get_gizmo_control_points() -> Array:
	return handles.values()

# ////////////////////////////////////////////////////////////
# STATE MANAGEMENT

# Returns a list of handle data from each handle.
func get_control_data() -> Dictionary:
#	print("[Onyx] ", self.get_name() , " - get_control_data()")
	var result = {}
	for control in handles.values():
		result[control.control_name] = control.get_control_data()
	
	return result

# Changes all current handle data with a previously set list of handle data.
func set_control_data(data : Dictionary):
#	print("[Onyx] ", self.get_name() , " - set_control_data()")
	for data_key in data.keys():
		handles[data_key].set_control_data(data[data_key])
	
#	print("Setting done!")

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
	
#	print("[Onyx] ", self.get_name() , " - restore_state()")
	
	var new_handles = state[0]
	var stored_location = state[1]
	
#	print("RESTORING STATE -", state)
	
	set_control_data(new_handles)
	old_handle_data = new_handles.duplicate(true)
	apply_handle_attributes()
	
	update_origin_position(stored_location)
	balance_handles()
	
	update_geometry()
	
	if hollow_object != null:
		assign_hollow_origin()
	

# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

func editor_select():
	if Engine.editor_hint == true:
		is_selected = true
		handle_build()
	
	
func editor_deselect():
	if Engine.editor_hint == true:
		is_selected = false
		handle_clear()
	


# ////////////////////////////////////////////////////////////
# CHILD MANAGEMENT
func translate_children(translation):
	
#	print("[Onyx] ", self.get_name() , " - translate_children()")
	
	for child in get_children():
		child.global_translate(translation)

func print_property_status():
	print("************************")
	print("PLUGIN - ", get_plugin())
	print("ONYX MESH - ", onyx_mesh)
	print("ARRAY MESH - ", array_mesh)
	print("HANDLES - ", handles)
	print("OLD HANDLE DATA - ", old_handle_data)
	print("IS SELECTED - ", is_selected)
	print("HOLLOW ENABLE - ", hollow_enable)
	print("HOLLOW OBJECT - ", hollow_object)
	print("UV SCALE - ", uv_scale)
	print("************************")
