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
var unwrap_method = UnwrapMethod.DIRECT_OVERLAP setget update_unwrap_method

# MATERIALS
export(bool) var smooth_normals = true setget update_smooth_normals


# ////////////////////////////////////////////////////////////
# PROPERTY GENERATORS
# Used to give the unwrap method a property category
# If you're watching this Godot developers.... why.

# Commented out until I have more options to offer, only one unwrap method works.

#func _get_property_list():
#	var props = [
#		{	
#			# The usage here ensures this property isn't actually saved, as it's an intermediary
#
#			"name" : "uv_options/unwrap_method",
#			"type" : TYPE_STRING,
#			"usage": PROPERTY_USAGE_EDITOR,
#			"hint": PROPERTY_HINT_ENUM,
#			"hint_string": "Direct Overlap, Proportional Overlap"
#		},
#	]
#	return props

func _set(property, value):
	match property:
		"uv_options/unwrap_method":
			if value == "Proportional Overlap":
				unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP
			else:
				unwrap_method = UnwrapMethod.DIRECT_OVERLAP
			
	generate_geometry()
		

func _get(property):
	match property:
		"uv_options/unwrap_method":
			return unwrap_method


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
	update_origin_mode()
	balance_handles()
	generate_geometry(true)
	
# Used to recalibrate both the origin point location and the position handles.
func update_positions(new_value):
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
	



# Updates the origin during generate_geometry() as well as the currently defined handles, 
# to ensure it's anchored where it needs to be.
func update_origin_mode():
	
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
	var new_translation = new_loc - old_loc

	# set it
	self.global_translate(new_translation)
	translate_children(new_translation * -1)
	

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
	translate_children(new_translation * -1)




# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting = false):
	
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
	refresh_handle_data()
	update_gizmo()


# ////////////////////////////////////////////////////////////
# GIZMO HANDLES

# On initialisation, control points are built for transmitting and handling interactive points between the node and the node's gizmo.
func build_handles():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	var triangle_x = [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_y = [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_z = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	
	var height = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	height.control_name = 'height'
	height.set_type_axis(false, "handle_change", "handle_commit", triangle_y)
	
	var x_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	x_width.control_name = 'x_width'
	x_width.set_type_axis(false, "handle_change", "handle_commit", triangle_x)
	
	var z_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	z_width.control_name = 'z_width'
	z_width.set_type_axis(false, "handle_change", "handle_commit", triangle_z)
	
	
	# populate the dictionary
	handles[height.control_name] = height
	handles[x_width.control_name] = x_width
	handles[z_width.control_name] = z_width
	
	# need to give it positions in the case of a duplication or scene load.
	refresh_handle_data()

# Uses the current settings to refresh the handle list.
func refresh_handle_data():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	# Failsafe for script reloads, BECAUSE I CURRENTLY CAN'T DETECT THEM.
	if handles.size() == 0: 
		gizmo.control_points.clear()
		build_handles()
		return
	
	match origin_mode:
		OriginPosition.CENTER:
			handles["height"].control_position = Vector3(0, height / 2, 0)
			handles["x_width"].control_position = Vector3(x_width / 2, 0, 0)
			handles["z_width"].control_position = Vector3(0, 0, z_width / 2)
			
		OriginPosition.BASE:
			handles["height"].control_position = Vector3(0, height, 0)
			handles["x_width"].control_position = Vector3(x_width / 2, height / 2, 0)
			handles["z_width"].control_position = Vector3(0, height / 2, z_width / 2)
			
		OriginPosition.BASE_CORNER:
			handles["height"].control_position = Vector3(x_width / 2, height, z_width / 2)
			handles["x_width"].control_position = Vector3(x_width, height / 2, z_width / 2)
			handles["z_width"].control_position = Vector3(x_width / 2, height / 2, z_width)
	
	

# Changes the handle based on the given index and coordinates.
func update_handle_from_gizmo(control):
	
	var coordinate = control.control_position
	
	var target_val = 0.0
	match control.control_name:
			'height': target_val = max(coordinate.y, 0)
			'x_width': target_val = max(coordinate.x, 0)
			'z_width': target_val = max(coordinate.z, 0)
	
	# Multiply the target depending on where the origin is (to adjust for different handle scales).
	if origin_mode == OriginPosition.CENTER:
		target_val = target_val * 2
	elif origin_mode == OriginPosition.BASE && control.control_name != 'height':
		target_val = target_val * 2
	
	# If proportional shape toggle is on, apply to all values
	if keep_shape_proportional == true:
		height = target_val
		x_width = target_val
		z_width = target_val
	
	# Otherwise apply selectively.
	else:
		match control.control_name:
			'height': height = target_val
			'x_width': x_width = target_val
			'z_width': z_width = target_val
	
	refresh_handle_data()
	

# Applies the current handle values to the shape attributes
func apply_handle_attributes():
	
	if origin_mode == OriginPosition.CENTER:
		height = handles["height"].control_position.y * 2
		x_width = handles["x_width"].control_position.x * 2
		z_width = handles["z_width"].control_position.z * 2
	
	if origin_mode == OriginPosition.BASE:
		height = handles["height"].control_position.y
		x_width = handles["x_width"].control_position.x * 2
		z_width = handles["z_width"].control_position.z * 2
	
	if origin_mode == OriginPosition.BASE_CORNER:
		height = handles["height"].control_position.y
		x_width = handles["x_width"].control_position.x
		z_width = handles["z_width"].control_position.z
	
	

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_handles():
	
	# There's no duality between handles for this type, no balancing needed.
	pass
