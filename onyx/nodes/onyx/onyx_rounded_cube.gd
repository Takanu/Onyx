tool
extends "res://addons/onyx/nodes/onyx/onyx.gd"

# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")
var ControlPoint = load("res://addons/onyx/gizmos/control_point.gd")

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

# allows origin point re-orientation, for precise alignments and convenience.
enum OriginPosition {CENTER, BASE, BASE_CORNER}
export(OriginPosition) var origin_mode = OriginPosition.BASE setget update_origin_type

# used to keep track of how to move the origin point into a new position.
var previous_origin_mode = OriginPosition.BASE

# used to force an origin update when using the sliders to adjust positions.
export(bool) var update_origin_setting = true setget update_positions

# ////////////////////////////////////////////////////////////
# PROPERTIES

var color = Vector3(1, 1, 1)

# Exported variables representing all usable handles for re-shaping the mesh, in order.
# Must be exported to be saved in a scene?  smh.
export(float) var x_plus_position = 0.5 setget update_x_plus
export(float) var x_minus_position = 0.5 setget update_x_minus

export(float) var y_plus_position = 1.0 setget update_y_plus
export(float) var y_minus_position = 0.0 setget update_y_minus

export(float) var z_plus_position = 0.5 setget update_z_plus
export(float) var z_minus_position = 0.5 setget update_z_minus

export(float) var corner_size = 0.2 setget update_corner_size
export(int) var corner_iterations = 4 setget update_corner_iterations

# TODO - Reintroduce later once the an extrusion bevel geometry function is written
enum CornerAxis {X, Y, Z}
#export(CornerAxis) var corner_axis = CornerAxis.X setget update_corner_axis
var corner_axis = CornerAxis.X setget update_corner_axis


# SUBDIVISION
# Used to subdivide the mesh to prevent CSG boolean glitches.
# Removed for now, may add back in a future version
#export(Vector3) var subdivisions = Vector3(0, 0, 0)

# BEVELS
#export(float) var bevel_size = 0.2 setget update_bevel_size
#enum BevelTarget {Y_AXIS, X_AXIS, Z_AXIS}
#export(BevelTarget) var bevel_target = BevelTarget.Y_AXIS setget update_bevel_target

# UVS
enum UnwrapMethod {PROPORTIONAL_OVERLAP, CLAMPED_OVERLAP}
var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP setget update_unwrap_method

# MATERIALS
export(bool) var smooth_normals = true setget update_smooth_normals

# ////////////////////////////////////////////////////////////
# PROPERTY GENERATORS
# Used to give the unwrap method a property category
# If you're watching this Godot developers.... why.
func _get_property_list():
	var props = [
		{	
			# The usage here ensures this property isn't actually saved, as it's an intermediary
			
			"name" : "uv_options/unwrap_method",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Proportional Overlap, Clamped Overlap"
		},
	]
	return props

func _set(property, value):
#	print("[OnyxCube] ", self.get_name(), " - _set() : ", property, " ", value)
	
	match property:
		"uv_options/unwrap_method":
			unwrap_method = value
			
			
	generate_geometry()
		

func _get(property):
#	print("[OnyxCube] ", self.get_name(), " - _get() : ", property)
	
	match property:
		"uv_options/unwrap_method":
			return unwrap_method


# ////////////////////////////////////////////////////////////
# PROPERTY UPDATERS
	
# Used when a handle variable changes in the properties panel.
func update_x_plus(new_value):
	if new_value < 0:
		new_value = 0
		
	x_plus_position = new_value
	generate_geometry(true)
	
	
func update_x_minus(new_value):
	if new_value < 0 || origin_mode == OriginPosition.BASE_CORNER:
		new_value = 0
		
	x_minus_position = new_value
	generate_geometry(true)
	
func update_y_plus(new_value):
	if new_value < 0:
		new_value = 0
		
	y_plus_position = new_value
	generate_geometry(true)
	
func update_y_minus(new_value):
	if new_value < 0 || origin_mode == OriginPosition.BASE_CORNER || origin_mode == OriginPosition.BASE:
		new_value = 0
		
	y_minus_position = new_value
	generate_geometry(true)
	
func update_z_plus(new_value):
	if new_value < 0:
		new_value = 0
		
	z_plus_position = new_value
	generate_geometry(true)
	
func update_z_minus(new_value):
	if new_value < 0 || origin_mode == OriginPosition.BASE_CORNER:
		new_value = 0
		
	z_minus_position = new_value
	generate_geometry(true)
	
func update_corner_size(new_value):
	if new_value <= 0:
		new_value = 0.01
		
	# ensure the rounded corners do not surpass the bounds of the size of the shape sides.
	var x_range = (x_plus_position - -x_minus_position) / 2
	var y_range = (y_plus_position - -y_minus_position) / 2
	var z_range = (z_plus_position - -z_minus_position) / 2
	
	match corner_axis:
		CornerAxis.X:
			if new_value > y_range:
				new_value = y_range
			if new_value > z_range:
				new_value = z_range
		CornerAxis.Y:
			if new_value > x_range:
				new_value = x_range
			if new_value > z_range:
				new_value = z_range
		CornerAxis.Z:
			if new_value > x_range:
				new_value = x_range
			if new_value > y_range:
				new_value = y_range
		
	corner_size = new_value
	generate_geometry(true)
	
func update_corner_iterations(new_value):
	if new_value <= 0:
		new_value = 1
		
	corner_iterations = new_value
	generate_geometry(true)
	
func update_corner_axis(new_value):
	corner_axis = new_value
	generate_geometry(true)

#func update_subdivisions(new_value):
#	subdivisions = new_value
#	generate_geometry(true)
	
#
#func update_bevel_size(new_value):
#	if new_value > 0:
#		new_value = 0
#
#	bevel_size = new_value
#	generate_geometry(true)
#
#func update_bevel_target(new_value):
#	bevel_target = new_value
#	generate_geometry(true)
	
	
# Used to recalibrate both the origin point location and the position handles.
func update_positions(new_value):
	#print("ONYXCUBE update_positions")
	update_origin_setting = true
	update_origin_mode()
	balance_handles()
	generate_geometry(true)
	


# Changes the origin position relative to the shape and regenerates geometry and handles.
func update_origin_type(new_value):

	if previous_origin_mode == new_value:
		return
	
	origin_mode = new_value
	update_origin_mode()
	balance_handles()
	generate_geometry(true)
	
	# ensure the origin mode toggle is preserved, and ensure the adjusted handles are saved.
	previous_origin_mode = origin_mode
	old_handle_data = get_control_data()


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
	
	

# Updates the origin location when the corresponding property is changed.
func update_origin_mode():
	
	# Used to prevent the function from triggering when not inside the tree.
	# This happens during duplication and replication and causes incorrect node placement.
	if is_inside_tree() == false:
		return
	
	#print("ONYXCUBE update_origin")
	
	#Re-add once handles are a thing, otherwise this breaks the origin stuff.
#	if handles.size() == 0:
#		return
	
	# based on the current position and properties, work out how much to move the origin.
	var diff = Vector3(0, 0, 0)
	
	match previous_origin_mode:
		
		OriginPosition.CENTER:
			match origin_mode:
				
				OriginPosition.BASE:
					diff = Vector3(0, -y_minus_position, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-x_minus_position, -y_minus_position, -z_minus_position)
			
		OriginPosition.BASE:
			match origin_mode:
				
				OriginPosition.CENTER:
					diff = Vector3(0, y_plus_position / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-x_minus_position, 0, -z_minus_position)
					
		OriginPosition.BASE_CORNER:
			match origin_mode:
				
				OriginPosition.BASE:
					diff = Vector3(x_plus_position / 2, 0, z_plus_position / 2)
				OriginPosition.CENTER:
					diff = Vector3(x_plus_position / 2, y_plus_position / 2, z_plus_position / 2)
	
	# Get the difference
	var new_loc = self.global_transform.xform(self.translation + diff)
	var old_loc = self.global_transform.xform(self.translation)
	var new_translation = new_loc - old_loc
	#print("MOVING LOCATION: ", old_loc, " -> ", new_loc)
	#print("TRANSLATION: ", new_translation)
	
	# set it
	global_translate(new_translation)
	translate_children(new_translation * -1)
	

# Updates the origin position for the currently-active Origin Mode, either building a new one using properties or through a new position.
# DOES NOT update the origin when the origin property has changed, for use with handle commits.
func update_origin_position(new_location = null):
	
	var new_loc = Vector3()
	var global_tf = self.global_transform
	var global_pos = self.global_transform.origin
	
	if new_location == null:
		
		# Find what the current location should be
		var diff = Vector3()
		var mid_x = (x_plus_position - x_minus_position) / 2
		var mid_y = (y_plus_position - y_minus_position) / 2
		var mid_z = (z_plus_position - z_minus_position) / 2
		
		var diff_x = abs(x_plus_position - -x_minus_position)
		var diff_y = abs(y_plus_position - -y_minus_position)
		var diff_z = abs(z_plus_position - -z_minus_position)
		
		match origin_mode:
			OriginPosition.CENTER:
				diff = Vector3(mid_x, mid_y, mid_z)
			
			OriginPosition.BASE:
				diff = Vector3(mid_x, -y_minus_position, mid_z)
			
			OriginPosition.BASE_CORNER:
				diff = Vector3(-x_minus_position, -y_minus_position, -z_minus_position)
		
		new_loc = global_tf.xform(diff)
	
	else:
		new_loc = new_location
		
	
	# Get the difference
	var old_loc = global_pos
	var new_translation = new_loc - old_loc
	
	# set it
	global_translate(new_translation)
	translate_children(new_translation * -1)



# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting = false):
	
	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return
	
	var maxPoint = Vector3(x_plus_position, y_plus_position, z_plus_position)
	var minPoint = Vector3(-x_minus_position, -y_minus_position, -z_minus_position)
	
	if fix_to_origin_setting == true:
		match origin_mode:
			OriginPosition.BASE:
				maxPoint = Vector3(x_plus_position, (y_plus_position + (y_minus_position * -1)), z_plus_position)
				minPoint = Vector3(-x_minus_position, 0, -z_minus_position)
				
			OriginPosition.BASE_CORNER:
				maxPoint = Vector3(
					(x_plus_position + (-x_minus_position * -1)), 
					(y_plus_position + (-y_minus_position * -1)), 
					(z_plus_position + (-z_minus_position * -1))
					)
				minPoint = Vector3(0, 0, 0)
	
	# Generate the geometry
	var mesh_factory = OnyxMeshFactory.new()
	onyx_mesh.clear()
	
	mesh_factory.build_rounded_rect(onyx_mesh, minPoint, maxPoint, 'X', corner_size, corner_iterations, smooth_normals, unwrap_method)
	render_onyx_mesh()
	
	# Re-submit the handle positions based on the built faces, so other handles that aren't the
	# focus of a handle operation are being updated
	
	refresh_handle_data()
	update_gizmo()
	
	_generate_hollow_shape()
	


# ////////////////////////////////////////////////////////////
# GIZMO HANDLES

# On initialisation, control points are built for transmitting and handling interactive points between the node and the node's gizmo.
func build_handles():
	
#	print("ONYXCUBE build_handles")
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	var triangle_x = [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_y = [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_z = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	
	var x_minus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	x_minus.control_name = 'x_minus'
	x_minus.set_type_axis(false, "handle_change", "handle_commit", triangle_x)
	
	var x_plus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	x_plus.control_name = 'x_plus'
	x_plus.set_type_axis(false, "handle_change", "handle_commit", triangle_x)
	
	var y_minus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	y_minus.control_name = 'y_minus'
	y_minus.set_type_axis(false, "handle_change", "handle_commit", triangle_y)
	
	var y_plus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	y_plus.control_name = 'y_plus'
	y_plus.set_type_axis(false, "handle_change", "handle_commit", triangle_y)
	
	var z_minus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	z_minus.control_name = 'z_minus'
	z_minus.set_type_axis(false, "handle_change", "handle_commit", triangle_z)
	
	var z_plus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	z_plus.control_name = 'z_plus'
	z_plus.set_type_axis(false, "handle_change", "handle_commit", triangle_z)
	
	# populate the dictionary
	handles["x_minus"] = x_minus
	handles["x_plus"] = x_plus
	handles["y_minus"] = y_minus
	handles["y_plus"] = y_plus
	handles["z_minus"] = z_minus
	handles["z_plus"] = z_plus
	
	# need to give it positions in the case of a duplication or scene load.
	refresh_handle_data()
	

# Uses the current settings to refresh the control point positions.
func refresh_handle_data():
	
#	print("ONYXCUBE generate_handles")
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	# Failsafe for script reloads, BECAUSE I CURRENTLY CAN'T DETECT THEM.
	if handles.size() == 0:
		gizmo.control_points.clear()
		build_handles()
		return
	
	var mid_x = (x_plus_position - x_minus_position) / 2
	var mid_y = (y_plus_position - y_minus_position) / 2
	var mid_z = (z_plus_position - z_minus_position) / 2

	var diff_x = abs(x_plus_position - -x_minus_position)
	var diff_y = abs(y_plus_position - -y_minus_position)
	var diff_z = abs(z_plus_position - -z_minus_position)

	handles["x_minus"].control_position = Vector3(-x_minus_position, mid_y, mid_z)
	handles["x_plus"].control_position = Vector3(x_plus_position, mid_y, mid_z)
	handles["y_minus"].control_position = Vector3(mid_x, -y_minus_position, mid_z)
	handles["y_plus"].control_position = Vector3(mid_x, y_plus_position, mid_z)
	handles["z_minus"].control_position = Vector3(mid_x, mid_y, -z_minus_position)
	handles["z_plus"].control_position = Vector3(mid_x, mid_y, z_plus_position)
	
	

# Changes the handle based on the given index and coordinates.
func update_handle_from_gizmo(control):
	
	var coordinate = control.control_position
	
	match control.control_name:
		'x_minus': x_minus_position = min(coordinate.x, x_plus_position) * -1
		'x_plus': x_plus_position = max(coordinate.x, -x_minus_position)
		'y_minus': y_minus_position = min(coordinate.y, y_plus_position) * -1
		'y_plus': y_plus_position = max(coordinate.y, -y_minus_position)
		'z_minus': z_minus_position = min(coordinate.z, z_plus_position) * -1
		'z_plus': z_plus_position = max(coordinate.z, -z_minus_position)
		
	refresh_handle_data()
	

# Applies the current handle values to the shape attributes
func apply_handle_attributes():
	
	x_minus_position = handles["x_minus"].control_position.x * -1
	x_plus_position = handles["x_plus"].control_position.x
	y_minus_position = handles["y_minus"].control_position.y * -1
	y_plus_position = handles["y_plus"].control_position.y
	z_minus_position = handles["z_minus"].control_position.z * -1
	z_plus_position = handles["z_plus"].control_position.z



# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_handles():
	
	var diff_x = abs(x_plus_position - -x_minus_position)
	var diff_y = abs(y_plus_position - -y_minus_position)
	var diff_z = abs(z_plus_position - -z_minus_position)
	
	match origin_mode:
		OriginPosition.CENTER:
			x_plus_position = diff_x / 2
			x_minus_position = (diff_x / 2)
					
			y_plus_position = diff_y / 2
			y_minus_position = (diff_y / 2)
			
			z_plus_position = diff_z / 2
			z_minus_position = (diff_z / 2)
		
		OriginPosition.BASE:
			x_plus_position = diff_x / 2
			x_minus_position = (diff_x / 2)
			
			y_plus_position = diff_y
			y_minus_position = 0
			
			z_plus_position = diff_z / 2
			z_minus_position = (diff_z / 2)
			
		OriginPosition.BASE_CORNER:
			x_plus_position = diff_x
			x_minus_position = 0
			
			y_plus_position = diff_y
			y_minus_position = 0
			
			z_plus_position = diff_z
			z_minus_position = 0
		
	
# ////////////////////////////////////////////////////////////
# HOLLOW MODE FUNCTIONS

# The margin options available in Hollow mode, identified by the control names that should have margins
func get_hollow_margins() -> Array:
	
#	print("[OnyxCube] ", self.get_name(), " - get_hollow_margins()")
	
	var control_names = [
		"x_minus",
		"x_plus",
		"y_minus",
		"y_plus",
		"z_minus",
		"z_plus",
	]
	
	return control_names


# Gets the current shape parameters not controlled by handles, to apply to the hollow shape
func assign_hollow_properties():
	
	if hollow_object == null:
		return
	
	if hollow_object.subdivisions != self.subdivisions:
		hollow_object.subdivisions = self.subdivisions
	
	if hollow_object.corner_size != self.corner_size:
		hollow_object.corner_size = self.corner_size
	
	if hollow_object.corner_iterations != self.corner_iterations:
		hollow_object.corner_iterations = self.corner_iterations
	

# Assigns the hollow object an origin point based on the origin mode of this Onyx type.
# THIS DOES NOT MODIFY THE ORIGIN TYPE OF THE HOLLOW OBJECT
func assign_hollow_origin():
	
	if hollow_object == null:
		return
	
	hollow_object.set_translation(Vector3(0, 0, 0))


# An override-able function used to determine how margins apply to handles
func apply_hollow_margins(hollow_controls: Dictionary):
	
	if hollow_object == null:
		return
	
#	print("[OnyxCube] ", self.get_name(), " - apply_hollow_margins(controls)")
#	print("base onyx controls - ", handles)
#	print("hollow controls - ", hollow_controls)
	
	for key in hollow_controls.keys():
		var hollow_handle = hollow_controls[key]
		var control_handle = handles[key]
		var margin = hollow_margin_values[key]
		
		match key:
			"x_minus":
				hollow_handle.control_position.x = control_handle.control_position.x + margin
			"x_plus":
				hollow_handle.control_position.x = control_handle.control_position.x - margin
			"y_minus":
				hollow_handle.control_position.y = control_handle.control_position.y + margin
			"y_plus":
				hollow_handle.control_position.y = control_handle.control_position.y - margin
			"z_minus":
				hollow_handle.control_position.z = control_handle.control_position.z + margin
			"z_plus":
				hollow_handle.control_position.z = control_handle.control_position.z - margin
	
	return hollow_controls
