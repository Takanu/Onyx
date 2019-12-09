tool
extends CSGMesh

# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var OnyxUtils = load("res://addons/onyx/nodes/onyx/onyx_utils.gd")
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")
var ControlPoint = load("res://addons/onyx/gizmos/control_point.gd")

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

# allows origin point re-orientation, for precise alignments and convenience.
# NOT AVAILABLE ON TYPES WITH SPLINES OR POSITION POINTS.

#enum OriginPosition {CENTER, BASE, BASE_CORNER}
#export(OriginPosition) var origin_mode = OriginPosition.BASE setget update_origin_mode
#var previous_origin_mode = OriginPosition.BASE
#export(bool) var update_origin_setting = true setget update_positions

# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to
var plugin

# The face set script, used for managing geometric data.
var onyx_mesh = OnyxMesh.new()

# The handle points that will be used to resize the mesh (NOT built in the format required by the gizmo)
var handles = {}

# Old handle points that are saved every time a handle has finished moving.
var old_handle_data = {}

# The offset of the origin relative to the rest of the mesh.
var origin_offset = Vector3(0, 0, 0)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

# ////////////////////////////////////////////////////////////
# EXPORTS

# Exported variables representing all usable handles for re-shaping the mesh, in order.
# Must be exported to be saved in a scene?  smh.
export(Vector3) var start_position = Vector3(0.0, 0.0, 0.0) setget update_start_position
export(Vector3) var end_position = Vector3(0.0, 1.0, 2.0) setget update_end_position

export(float) var stair_width = 2 setget update_stair_width
export(float) var stair_depth = 0.4 setget update_stair_depth
export(int) var stair_count = 4 setget update_stair_count

export(Vector2) var stair_length_percentage = Vector2(1, 1) setget update_stair_length_percentage



# BEVELS
#export(float) var bevel_size = 0.2 setget update_bevel_size
#enum BevelTarget {Y_AXIS, X_AXIS, Z_AXIS}
#export(BevelTarget) var bevel_target = BevelTarget.Y_AXIS setget update_bevel_target

# UVS
enum UnwrapMethod {PROPORTIONAL_OVERLAP, CLAMPED_OVERLAP}
export(UnwrapMethod) var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP setget update_unwrap_method

export(Vector2) var uv_scale = Vector2(1.0, 1.0) setget update_uv_scale
export(bool) var flip_uvs_horizontally = false setget update_flip_uvs_horizontally
export(bool) var flip_uvs_vertically = false setget update_flip_uvs_vertically


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
	
	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
		
		# check that transform changes are local only
		if local_tracked_pos != translation:
			local_tracked_pos = translation
			call_deferred("_editor_transform_changed")
		
func _editor_transform_changed():
	
	# The shape only needs to be re-generated when the origin is moved or when the shape changes.
	#print("ONYXCUBE _editor_transform_changed")
	#generate_geometry(true)
	pass

				
# ////////////////////////////////////////////////////////////
# PROPERTY UPDATERS
	
func update_start_position(new_value):
	start_position = new_value
	generate_geometry(true)
	
	
func update_end_position(new_value):
	end_position = new_value
	generate_geometry(true)
	
func update_stair_width(new_value):
	if new_value < 0:
		new_value = 0
		
	stair_width = new_value
	generate_geometry(true)
	
func update_stair_depth(new_value):
	if new_value < 0:
		new_value = 0
		
	stair_depth = new_value
	generate_geometry(true)
	
func update_stair_length_percentage(new_value):
	if new_value.x < 0:
		new_value.x = 0
	if new_value.y < 0:
		new_value.y = 0
		
	stair_length_percentage = new_value
	generate_geometry(true)
	
func update_stair_count(new_value):
	if new_value < 1:
		new_value = 1
		
	stair_count = new_value
	generate_geometry(true)
	
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
	

# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting):
	
	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return
	
#	print(self, " - Generating geometry")

	# This shape is too custom to delegate, so it's being done here
	#   X---------X  e1 e2
	#	|         |  e3 e4
	#	|         |
	#	|         |
	#   X---------X  s1 s2
	#   X---------X  s3 s4
	
	# Build a transform
	var z_axis = (end_position - start_position)
	z_axis = Vector3(z_axis.x, 0, z_axis.z).normalized()
	var y_axis = Vector3(0, 1, 0)
	var x_axis = z_axis.cross(y_axis)
	
	var mesh_pos = Vector3()
	var start_tf = Transform(x_axis, y_axis, z_axis, start_position)
	#var end_tf = Transform(x_axis, y_axis, z_axis, end_position)
	
	onyx_mesh.clear()
	
	# Setup variables
	var path_diff = end_position - start_position
	var length_diff = path_diff.length()
	var diff_inc = path_diff / stair_count
	
	# get main 4 vectors
	var v1 = Vector3(-stair_width/2, stair_depth/2, 0)
	var v2 = Vector3(stair_width/2, stair_depth/2, 0)
	var v3 = Vector3(-stair_width/2, -stair_depth/2, 0)
	var v4 = Vector3(stair_width/2, -stair_depth/2, 0)
	
	var length_percentage_minus = Vector3(0, 0, diff_inc.z/2 * -stair_length_percentage.x)
	var length_percentage_plus = Vector3(0, 0, diff_inc.z/2 * stair_length_percentage.y)
	
	var s1 = v1 + length_percentage_plus
	var s2 = v2 + length_percentage_plus
	var s3 = v3 + length_percentage_plus
	var s4 = v4 + length_percentage_plus
		
	var e1 = v1 + length_percentage_minus
	var e2 = v2 + length_percentage_minus
	var e3 = v3 + length_percentage_minus
	var e4 = v4 + length_percentage_minus
	
	# setup uv arrays
	var x_minus_uv = [];  var x_plus_uv = []
	var y_minus_uv = [];  var y_plus_uv = []
	var z_minus_uv = [];  var z_plus_uv = []
	
	# UNWRAP 0 : 1:1 Overlap
	if unwrap_method == UnwrapMethod.CLAMPED_OVERLAP:
		var wrap = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]
		x_minus_uv = wrap;  x_plus_uv = wrap;
		y_minus_uv = wrap;  y_plus_uv = wrap;
		z_minus_uv = wrap;  z_plus_uv = wrap;
	
	elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
		x_minus_uv = [Vector2(e3.z, -e3.y), Vector2(e1.z, -e1.y), Vector2(s1.z, -s1.y), Vector2(s3.z, -s3.y)]
		x_plus_uv = [Vector2(s4.z, -s4.y), Vector2(s2.z, -s2.y), Vector2(e2.z, -e2.y), Vector2(e4.z, -e4.y)]
		
		y_minus_uv = [Vector2(s4.x, -s4.z), Vector2(e4.x, -e4.z), Vector2(e3.x, -e3.z), Vector2(s3.x, -s3.z)]
		y_plus_uv = [Vector2(-s1.x, -s1.z), Vector2(-e1.x, -e1.z), Vector2(-e2.x, -e2.z), Vector2(-s2.x, -s2.z)]
		
		z_minus_uv = [Vector2(-s3.x, -s3.y), Vector2(-s1.x, -s1.y), Vector2(-s2.x, -s2.y), Vector2(-s4.x, -s4.y)]
		z_plus_uv = [Vector2(-e4.x, -e4.y), Vector2(-e2.x, -e2.y), Vector2(-e1.x, -e1.y), Vector2(-e3.x, -e3.y)]
	
	var path_i = start_position + (diff_inc / 2)
	var i = 0
	
	# iterate through path
	while i < stair_count:
		var step_start = path_i
		var step_tf = Transform(Basis(), step_start)
		
		# transform them for the start and finish
		var ms_1 = step_tf.xform(s1)
		var ms_2 = step_tf.xform(s2)
		var ms_3 = step_tf.xform(s3)
		var ms_4 = step_tf.xform(s4)
		
		var me_1 = step_tf.xform(e1)
		var me_2 = step_tf.xform(e2)
		var me_3 = step_tf.xform(e3)
		var me_4 = step_tf.xform(e4)
		
		var flat_distance = Vector3(diff_inc.x, 0, diff_inc.z) / 2
		
		# build the step vertices
		var x_minus = [me_3, me_1, ms_1, ms_3]
		var x_plus = [ms_4, ms_2, me_2, me_4]
		
		var y_minus = [ms_4, me_4, me_3, ms_3]
		var y_plus = [ms_1, me_1, me_2, ms_2]
		
		var z_minus = [ms_3, ms_1, ms_2, ms_4]
		var z_plus = [me_4, me_2, me_1, me_3]
		
		
		# add it to the mesh
		onyx_mesh.add_ngon(x_minus, [], [], x_minus_uv, [])
		onyx_mesh.add_ngon(x_plus, [], [], x_plus_uv, [])
		onyx_mesh.add_ngon(y_minus, [], [], y_minus_uv, [])
		onyx_mesh.add_ngon(y_plus, [], [], y_plus_uv, [])
		onyx_mesh.add_ngon(z_minus, [], [], z_minus_uv, [])
		onyx_mesh.add_ngon(z_plus, [], [], z_plus_uv, [])
		
		i += 1
		path_i += diff_inc
	
	
	# Generate the geometry
	render_onyx_mesh()
	
	# Re-submit the handle positions based on the built faces, so other handles that aren't the
	# focus of a handle operation are being updated
	
	generate_handles()
	update_gizmo()
	


# Makes any final tweaks, then prepares and transfers the mesh.
func render_onyx_mesh():
	OnyxUtils.render_onyx_mesh(self)


# ////////////////////////////////////////////////////////////
# GIZMO HANDLES

# On initialisation, control points are built for transmitting and handling interactive points between the node and the node's gizmo.
func build_handles():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	var triangle_z = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	
	var start_position = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	start_position.control_name = 'start_position'
	start_position.set_type_translate(false, "handle_change", "handle_commit")
	
	var end_position = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	end_position.control_name = 'end_position'
	end_position.set_type_translate(false, "handle_change", "handle_commit")
	
	var stair_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	stair_width.control_name = 'stair_width'
	stair_width.set_type_axis(false, "handle_change", "handle_commit", triangle_z)
	
	# populate the dictionary
	handles[start_position.control_name] = start_position
	handles[end_position.control_name] = end_position
	handles[stair_width.control_name] = stair_width
	
	# need to give it positions in the case of a duplication or scene load.
	generate_handles()

# Uses the current settings to refresh the handle list.
func generate_handles():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	# Failsafe for script reloads, BECAUSE I CURRENTLY CAN'T DETECT THEM.
	if handles.size() == 0: 
		gizmo.control_points.clear()
		build_handles()
		return
	
	var depth_mid = Vector3(0, stair_depth/2, 0)
	var width_mid =  Vector3(stair_width/2, 0, 0)
	var length_mid = Vector3(0, 0, ((end_position - start_position).length() / stair_count) / 2)
	
	handles["start_position"].control_position = start_position 
	handles["end_position"].control_position = end_position
	handles["stair_width"].control_position = start_position + depth_mid + width_mid
	


# Changes the handle based on the given index and coordinates.
func update_handle_from_gizmo(control):
	
	var coordinate = control.control_position
	
	match control.control_name:
		# positions
		'start_position': start_position = coordinate
		'end_position': end_position = coordinate
		'stair_width': stair_width = (coordinate.x - start_position.x) * 2
		
	generate_handles()
	

# Applies the current handle values to the shape attributes
func apply_handle_attributes():
	
	start_position = handles["start_position"].control_position
	end_position = handles["end_position"].control_position
	stair_width = (handles["stair_width"].control_position.x - start_position.x) * 2

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_handles():
	
	# balance handles here
	pass

# ////////////////////////////////////////////////////////////
# STANDARD HANDLE FUNCTIONS
# (DO NOT CHANGE THESE BETWEEN SCRIPTS)

# Returns the control points that the gizmo should currently have.
# Used by ControlPointGizmo to obtain that data once it's created, AFTER this node is created.
func get_gizmo_control_points() -> Array:
	return handles.values()

# Notifies the node that a handle has changed.
func handle_change(control):
	OnyxUtils.handle_change(self, control)

# Called when a handle has stopped being dragged.
func handle_commit(control):
	OnyxUtils.handle_commit(self, control)



# ////////////////////////////////////////////////////////////
# STATES
# Returns a state that can be used to undo or redo a previous change to the shape.
func get_gizmo_redo_state(control):
	return OnyxUtils.get_gizmo_redo_state(self)
	
# Returns a state specifically for undo functions in SnapGizmo.
func get_gizmo_undo_state(control):
	return OnyxUtils.get_gizmo_undo_state(self)

# Restores the state of the shape to a previous given state.
func restore_state(state):
	OnyxUtils.restore_state(self, state)



# ////////////////////////////////////////////////////////////
# SELECTION

func editor_select():
	OnyxUtils.handle_build(self)
	
func editor_deselect():
	OnyxUtils.handle_clear(self)
	
	
