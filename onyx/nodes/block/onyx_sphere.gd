tool
extends CSGMesh

# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var OnyxUtils = load("res://addons/onyx/nodes/block/onyx_utils.gd")
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

# allows origin point re-orientation, for precise alignments and convenience.
enum OriginPosition {CENTER, BASE, BASE_CORNER}
export(OriginPosition) var origin_mode = OriginPosition.BASE setget update_origin_mode

# used to keep track of how to move the origin point into a new position.
var previous_origin_mode = OriginPosition.BASE

# used to force an origin update when using the sliders to adjust positions.
export(bool) var update_origin_setting = true setget update_positions

# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to
var plugin

# The face set script, used for managing geometric data.
var onyx_mesh = OnyxMesh.new()

# The handle points that will be used to resize the mesh (NOT built in the format required by the gizmo)
var handles : Dictionary = {}

# Old handle points that are saved every time a handle has finished moving.
var old_handles : Dictionary = {}

# The offset of the origin relative to the rest of the mesh.
var origin_offset = Vector3(0, 0, 0)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)


# Exported variables representing all usable handles for re-shaping the mesh, in order.
# Must be exported to be saved in a scene?  smh.
export(int) var segments = 16 setget update_segments
export(int) var rings = 8 setget update_rings

export(float) var height = 1 setget update_height
export(float) var x_width = 1 setget update_x_width
export(float) var z_width = 1 setget update_z_width
export(bool) var keep_shape_proportional = false setget update_proportional_toggle

# UVS
enum UnwrapMethod {DIRECT_OVERLAP, PROPORTIONAL_OVERLAP}
export(UnwrapMethod) var unwrap_method = UnwrapMethod.DIRECT_OVERLAP setget update_unwrap_method

export(Vector2) var uv_scale = Vector2(1.0, 1.0) setget update_uv_scale
export(bool) var flip_uvs_horizontally = false setget update_flip_uvs_horizontally
export(bool) var flip_uvs_vertically = false setget update_flip_uvs_vertically

# MATERIALS
export(bool) var smooth_normals = true setget update_smooth_normals
export(Material) var material = null setget update_material

# ////////////////////////////////////////////////////////////
# FUNCTIONS


# Global initialisation
func _enter_tree():
	#print("ONYXCUBE _enter_tree")
		
		
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:
		
		# load plugin
		plugin = get_node("/root/EditorNode/Onyx")

		set_notify_local_transform(true)
		set_notify_transform(true)
		set_ignore_transform_notification(false)
		
		

func _exit_tree():
    pass
	
func _ready():
	
	# Delegate ready functionality for in-editor functions.
	OnyxUtils.onyx_ready(self)

	
func _notification(what):
	pass
	
#	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
#		# check that transform changes are local only
#		if local_tracked_pos != translation:
#			local_tracked_pos = translation
#			call_deferred("_editor_transform_changed")
		
func _editor_transform_changed():
	pass

				
# ////////////////////////////////////////////////////////////
# PROPERTY UPDATERS

# Used when a handle variable changes in the properties panel.
func update_segments(new_value):
	if new_value < 3:
		new_value = 3
	segments = new_value
	generate_geometry(true)
	
# Used when a handle variable changes in the properties panel.
func update_rings(new_value):
	if new_value < 3:
		new_value = 3
		
	rings = new_value
	generate_geometry(true)
	
func update_height(new_value):
	if new_value < 0:
		new_value = 0
		
	if keep_shape_proportional == true:
		x_width = new_value
		z_width = new_value
		
	height = new_value
	generate_geometry(true)
	
func update_x_width(new_value):
	if new_value < 0:
		new_value = 0
		
	if keep_shape_proportional == true:
		height = new_value
		z_width = new_value
		
	x_width = new_value
	generate_geometry(true)
	
func update_z_width(new_value):
	if new_value < 0:
		new_value = 0
		
	if keep_shape_proportional == true:
		height = new_value
		x_width = new_value
		
	z_width = new_value
	generate_geometry(true)
	
func update_proportional_toggle(new_value):
	keep_shape_proportional = new_value
	update_origin()
	balance_handles()
	generate_geometry(true)
	
# Used to recalibrate both the origin point location and the position handles.
func update_positions(new_value):
	update_origin_setting = true
	update_origin()
	balance_handles()
	generate_geometry(true)


# Changes the origin position relative to the shape and regenerates geometry and handles.
func update_origin_mode(new_value):

	if previous_origin_mode == new_value:
		return
	
	origin_mode = new_value
	update_origin()
	balance_handles()
	generate_geometry(true)
	
	# ensure the origin mode toggle is preserved, and ensure the adjusted handles are saved.
	previous_origin_mode = origin_mode
	old_handles = handles.duplicate()


func update_unwrap_method(new_value):
	unwrap_method = new_value
	generate_geometry(true)

func update_uv_scale(new_value):
	uv_scale = new_value
	generate_geometry(true)

func update_flip_uvs_horizontally(new_value):
	flip_uvs_horizontally = new_value
	generate_geometry(true)
	
func update_flip_uvs_vertically(new_value):
	flip_uvs_vertically = new_value
	generate_geometry(true)
	
func update_smooth_normals(new_value):
	smooth_normals = new_value
	generate_geometry(true)
	
func update_material(new_value):
	material = new_value
	OnyxUtils.update_material(self, new_value)



# Updates the origin during generate_geometry() as well as the currently defined handles, 
# to ensure it's anchored where it needs to be.
func update_origin():
	
# 	print("updating origin222...")
	
	# Used to prevent the function from triggering when not inside the tree.
	# This happens during duplication and replication and causes incorrect node placement.
	if self.is_inside_tree() == false:
		return
	
	#Re-add once handles are a thing, otherwise this breaks the origin stuff.
#	if handles.size() == 0:
#		return
	
	# based on the current position and properties, work out how much to move the origin.
	var diff = Vector3(0, 0, 0)

	match previous_origin_mode:

		OriginPosition.CENTER:
			match origin_mode:

				OriginPosition.BASE:
					diff = Vector3(0, -height / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-x_width / 2, -height / 2, -z_width / 2)

		OriginPosition.BASE:
			match origin_mode:

				OriginPosition.CENTER:
					diff = Vector3(0, height / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-x_width / 2, 0, -z_width / 2)

		OriginPosition.BASE_CORNER:
			match origin_mode:

				OriginPosition.BASE:
					diff = Vector3(x_width / 2, 0, z_width / 2)
				OriginPosition.CENTER:
					diff = Vector3(x_width / 2, height / 2, z_width / 2)

	# Get the difference
	var new_loc = self.translation + diff
	var old_loc = self.translation
# 	print("MOVING LOCATION: ", old_loc, " -> ", new_loc)

	# set it
	self.global_translate(new_loc - old_loc)
	

# Updates the origin position for the currently-active Origin Mode, either building a new one using properties or through a new position.
# DOES NOT update the origin when the origin property has changed, for use with handle commits.
func update_origin_position(new_location = null):
	
	var new_loc = Vector3()
	var global_tf = self.global_transform
	var global_pos = self.global_transform.origin
	
	var diff = Vector3()
	
	if new_location == null:
		
		# redundant, keeping it here for structural reasons.
		match origin_mode:
			OriginPosition.CENTER:
				diff = Vector3(0, 0, 0)
			
			OriginPosition.BASE:
				diff = Vector3(0, 0, 0)
			
			OriginPosition.BASE_CORNER:
				diff = Vector3(0, 0, 0)
		
		new_loc = global_tf.xform(diff)
	
	else:
		new_loc = new_location
		
	
	# Get the difference
	var old_loc = global_pos
	var new_translation = new_loc - old_loc
	
	# set it
	self.global_translate(new_translation)
	OnyxUtils.translate_children(self, new_translation * -1)




# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting):
	
	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return
	
	# Ensure the geometry is generated to fit around the current origin point.
	var position = Vector3(0, 0, 0)
	match origin_mode:
		OriginPosition.CENTER:
			position = Vector3(0, 0, 0)
		OriginPosition.BASE:
			position = Vector3(0, height / 2, 0)
		OriginPosition.BASE_CORNER:
			position = Vector3(x_width / 2, height / 2, z_width / 2)
			
	
	var mesh_factory = OnyxMeshFactory.new()
	onyx_mesh = mesh_factory.build_sphere(height, x_width, z_width, segments, rings, position, 0, 0, 1, true, true, smooth_normals)
	render_onyx_mesh()
	
	# Re-submit the handle positions based on the built faces, so other handles that aren't the
	# focus of a handle operation are being updated\
	generate_handles()
	update_gizmo()

# Makes any final tweaks, then prepares and transfers the mesh.
func render_onyx_mesh():
	OnyxUtils.render_onyx_mesh(self)


# ////////////////////////////////////////////////////////////
# GIZMO HANDLES

# Uses the current settings to refresh the handle list.
func generate_handles():
	handles.clear()
	
	match origin_mode:
		OriginPosition.CENTER:
			handles["height"] = Vector3(0, height / 2, 0)
			handles["x_width"] = Vector3(x_width / 2, 0, 0)
			handles["z_width"] = Vector3(0, 0, z_width / 2)
			
		OriginPosition.BASE:
			handles["height"] = Vector3(0, height, 0)
			handles["x_width"] = Vector3(x_width / 2, height / 2, 0)
			handles["z_width"] = Vector3(0, height / 2, z_width / 2)
			
		OriginPosition.BASE_CORNER:
			handles["height"] = Vector3(x_width / 2, height, z_width / 2)
			handles["x_width"] = Vector3(x_width, height / 2, z_width / 2)
			handles["z_width"] = Vector3(x_width / 2, height / 2, z_width)
	
	

# Converts the dictionary format of handles to a pair of handles with optional triangle for normal snaps.
func convert_handles_to_gizmo() -> Array:
	
	var result = []
	
	# generate collision triangles
	var triangle_x = [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_y = [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_z = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	
	# convert handle values to an array
	var handle_array = handles.values()
	result.append( [handle_array[0], triangle_y] )
	result.append( [handle_array[1], triangle_x] )
	result.append( [handle_array[2], triangle_z] )
	
	return result


# Converts the gizmo handle format of an array of points and applies it to the dictionary format for Onyx.
func convert_handles_to_onyx(handles) -> Dictionary:
	
	var result = {}
	result["height"] = handles[0]
	result["x_width"] = handles[1]
	result["z_width"] = handles[2]
	
	return result
	

# Changes the handle based on the given index and coordinates.
func update_handle_from_gizmo(index, coordinate):
	
	var target_val = 0.0
	match index:
			0: target_val = max(coordinate.y, 0)
			1: target_val = max(coordinate.x, 0)
			2: target_val = max(coordinate.z, 0)
	
	# Multiply the target depending on where the origin is (to adjust for different handle scales).
	if origin_mode == OriginPosition.CENTER:
		target_val = target_val * 2
	elif origin_mode == OriginPosition.BASE && index != 0:
		target_val = target_val * 2
	
	# If proportional shape toggle is on, apply to all values
	if keep_shape_proportional == true:
		height = target_val
		x_width = target_val
		z_width = target_val
	
	# Otherwise apply selectively.
	else:
		match index:
			0: height = target_val
			1: x_width = target_val
			2: z_width = target_val
	
	
	# Old handle adjustments, for reference.
#	if origin_mode == OriginPosition.CENTER:
#		match index:
#			0: height = max(coordinate.y, 0) * 2
#			1: x_width = max(coordinate.x, 0) * 2
#			2: z_width = max(coordinate.z, 0) * 2
#
#	if origin_mode == OriginPosition.BASE:
#		match index:
#			0: height = max(coordinate.y, 0) 
#			1: x_width = max(coordinate.x, 0) * 2
#			2: z_width = max(coordinate.z, 0) * 2
#
#	if origin_mode == OriginPosition.BASE_CORNER:
#		match index:
#			0: height = max(coordinate.y, 0) 
#			1: x_width = max(coordinate.x, 0)
#			2: z_width = max(coordinate.z, 0)
	
	generate_handles()
	

# Applies the current handle values to the shape attributes
func apply_handle_attributes():
	
	if origin_mode == OriginPosition.CENTER:
		height = handles["height"].y * 2
		x_width = handles["x_width"].x * 2
		z_width = handles["z_width"].z * 2
	
	if origin_mode == OriginPosition.BASE:
		height = handles["height"].y
		x_width = handles["x_width"].x * 2
		z_width = handles["z_width"].z * 2
	
	if origin_mode == OriginPosition.BASE_CORNER:
		height = handles["height"].y
		x_width = handles["x_width"].x
		z_width = handles["z_width"].z
	
	
	

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_handles():
	
	# There's no duality between handles for this type, no balancing needed.
	pass

# ////////////////////////////////////////////////////////////
# STANDARD HANDLE FUNCTIONS
# (DO NOT CHANGE THESE BETWEEN SCRIPTS)

# Notifies the node that a handle has changed.
func handle_change(index, coord):
	OnyxUtils.handle_change(self, index, coord)

# Called when a handle has stopped being dragged.
func handle_commit(index, coord):
	OnyxUtils.handle_commit(self, index, coord)



# ////////////////////////////////////////////////////////////
# STATES
# Returns a state that can be used to undo or redo a previous change to the shape.
func get_gizmo_redo_state():
	return OnyxUtils.get_gizmo_redo_state(self)
	
# Returns a state specifically for undo functions in SnapGizmo.
func get_gizmo_undo_state():
	return OnyxUtils.get_gizmo_undo_state(self)

# Restores the state of the shape to a previous given state.
func restore_state(state):
	OnyxUtils.restore_state(self, state)
	var new_handles = state[0]


# ////////////////////////////////////////////////////////////
# SELECTION

func editor_select():
	pass
	
func editor_deselect():
	pass
	