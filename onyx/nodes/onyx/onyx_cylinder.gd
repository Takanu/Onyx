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

# Exported variables representing all usable handles for re-shaping the cube, in order.
# Must be exported to be saved in a scene?  smh.
export(int) var sides = 12 setget update_sides
export(int) var rings = 1 setget update_rings
export(float) var height_max = 1 setget update_height_max
export(float) var height_min = 0 setget update_height_min

export(float) var x_width = 0.5 setget update_x_width
export(float) var z_width = 0.5 setget update_z_width
export(bool) var keep_width_proportional = false setget update_proportional_toggle

# UVS
enum UnwrapMethod {PROPORTIONAL_OVERLAP, PROPORTIONAL_OVERLAP_SEGMENTS, CLAMPED_OVERLAP}
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
			"hint_string": "Proportional Overlap, Proportional Overlap Segments, Clamped Overlap"
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
func update_sides(new_value):
	if new_value < 3:
		new_value = 3
	sides = new_value
	generate_geometry(true)
	
	
func update_rings(new_value):
	if new_value < 1:
		new_value = 1
	rings = new_value
	generate_geometry(true)
	
	
func update_height_max(new_value):
	if new_value < 0:
		new_value = 0
		
	height_max = new_value
	generate_geometry(true)
	
func update_height_min(new_value):
	if new_value < 0:
		new_value = 0
		
	height_min = new_value
	generate_geometry(true)
	
func update_x_width(new_value):
	if new_value < 0:
		new_value = 0
		
	if keep_width_proportional == true:
		z_width = new_value
		
	x_width = new_value
	generate_geometry(true)
	
func update_z_width(new_value):
	if new_value < 0:
		new_value = 0
		
	if keep_width_proportional == true:
		x_width = new_value
		
	z_width = new_value
	generate_geometry(true)
	
func update_proportional_toggle(new_value):
	keep_width_proportional = new_value
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
	old_handle_data = .get_control_data()

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
					diff = Vector3(0, -height_min, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-x_width, -height_min, -z_width)
			
		OriginPosition.BASE:
			match origin_mode:
				
				OriginPosition.CENTER:
					diff = Vector3(0, height_max / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-x_width, 0, -z_width)
					
		OriginPosition.BASE_CORNER:
			match origin_mode:
				
				OriginPosition.BASE:
					diff = Vector3(x_width, 0, z_width)
				OriginPosition.CENTER:
					diff = Vector3(x_width, height_max / 2, z_width)
	
	# Get the difference
	var new_loc = self.global_transform.xform(self.translation + diff)
	var old_loc = self.global_transform.xform(self.translation)
	var new_translation = new_loc - old_loc
#	print("MOVING LOCATION: ", old_loc, " -> ", new_loc)
	
	# set it
	global_translate(new_translation)
	translate_children(new_translation * -1)
	
	

# Updates the origin position for the currently-active Origin Mode, either building a new one using properties or through a new position.
# DOES NOT update the origin when the origin property has changed, for use with handle commits.
func update_origin_position(new_location = null):
	
	var new_loc = Vector3()
	var global_tf = self.global_transform
	var global_pos = self.global_transform.origin
	
	var diff = Vector3()
	var mid_height = height_max - height_min
	
	if new_location == null:
		
		match origin_mode:
			OriginPosition.CENTER:
				diff = Vector3(0, mid_height / 2, 0)
			
			OriginPosition.BASE:
				diff = Vector3(0, -height_min, 0)
			
			OriginPosition.BASE_CORNER:
				diff = Vector3(0, -height_min, 0)
		
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
	
	# Ensure the geometry is generated to fit around the current origin point.
	var height = 0
	var position = Vector3(0, 0, 0)
	match origin_mode:
		OriginPosition.CENTER:
			height = height_max - -height_min
			position = Vector3(0, -height_min, 0)
		OriginPosition.BASE:
			height = height_max - -height_min
			position = Vector3(0, -height_min, 0)
		OriginPosition.BASE_CORNER:
			height = height_max - -height_min
			position = Vector3(x_width, -height_min, z_width)
			
	
#	print("mesh height: ", height)
#	print("mesh position: ", position)
#
	var mesh_factory = OnyxMeshFactory.new()
	onyx_mesh.clear()
	mesh_factory.build_cylinder(onyx_mesh, sides, height, x_width, z_width, rings, position, unwrap_method, smooth_normals)
	
	render_onyx_mesh()
	
	# Re-submit the handle positions based on the built faces, so other handles that aren't the
	# focus of a handle operation are being updated\
	refresh_handle_data()
	update_gizmo()
	
	_generate_hollow_shape()
	


# ////////////////////////////////////////////////////////////
# GIZMO HANDLES

# On initialisation, control points are built for transmitting and handling interactive points between the node and the node's gizmo.
func build_handles():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	var height_max = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	height_max.control_name = 'height_max'
	height_max.set_type_axis(false, "handle_change", "handle_commit", Vector3(0, 1, 0))
	
	var height_min = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	height_min.control_name = 'height_min'
	height_min.set_type_axis(false, "handle_change", "handle_commit", Vector3(0, -1, 0))
	
	var x_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	x_width.control_name = 'x_width'
	x_width.set_type_axis(false, "handle_change", "handle_commit", Vector3(1, 0, 0))
	
	var z_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	z_width.control_name = 'z_width'
	z_width.set_type_axis(false, "handle_change", "handle_commit", Vector3(0, 0, 1))
	
	# populate the dictionary
	handles["height_max"] = height_max
	handles["height_min"] = height_min
	handles["x_width"] = x_width
	handles["z_width"] = z_width
	
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
	
	var height_mid = (height_max - height_min) / 2
	
	match origin_mode:
		OriginPosition.CENTER:
			handles["height_max"].control_position = Vector3(0, height_max, 0)
			handles["height_min"].control_position = Vector3(0, -height_min, 0)
			handles["x_width"].control_position = Vector3(x_width, 0, 0)
			handles["z_width"].control_position = Vector3(0, 0, z_width)
			
		OriginPosition.BASE:
			handles["height_max"].control_position = Vector3(0, height_max, 0)
			handles["height_min"].control_position = Vector3(0, -height_min, 0)
			handles["x_width"].control_position = Vector3(x_width, height_mid, 0)
			handles["z_width"].control_position = Vector3(0, height_mid, z_width)
			
		OriginPosition.BASE_CORNER:
			handles["height_max"].control_position = Vector3(x_width, height_max, z_width)
			handles["height_min"].control_position = Vector3(x_width, -height_min, z_width)
			handles["x_width"].control_position = Vector3(x_width * 2, height_mid, z_width)
			handles["z_width"].control_position = Vector3(x_width, height_mid, z_width * 2)
	

# Changes the handle based on the given index and coordinates.
func update_handle_from_gizmo(control):
	
	var coordinate = control.control_position
	
	match control.control_name:
		'height_max': height_max = max(coordinate.y, -height_min)
		'height_min': height_min = min(coordinate.y, height_max) * -1
		'x_width': x_width = max(coordinate.x, 0)
		'z_width': z_width = max(coordinate.z, 0)
		
	# Keep width proportional with gizmos if true
	if control.control_name == 'x_width'  || control.control_name == 'z_width':
		var final_x = coordinate.x
		var final_z = coordinate.z
		
		if origin_mode == OriginPosition.BASE_CORNER:
			final_x = coordinate.x / 2
			final_z = coordinate.z / 2
		
		# If the width is proportional, balance it
		if keep_width_proportional == true:
			if control.control_name == 'x_width':
				x_width = max(final_x, 0)
				z_width = max(final_x, 0)
			else:
				x_width = max(final_z, 0)
				z_width = max(final_z, 0)
				
		# Otherwise directly assign it.
		else:
			if control.control_name == 'x_width':
				x_width = max(final_x, 0)
			else:
				z_width = max(final_z, 0)

	
	refresh_handle_data()
	

# Applies the current handle values to the shape attributes
func apply_handle_attributes():
	
	# If the base corner is the current origin, we need to deal with widths differently.
	if origin_mode == OriginPosition.BASE_CORNER:
		height_max = handles["height_max"].control_position.y
		height_min = handles["height_min"].control_position.y * -1
		x_width = handles["x_width"].control_position.x / 2
		z_width = handles["z_width"].control_position.z / 2
		
	else:
		height_max = handles["height_max"].control_position.y
		height_min = handles["height_min"].control_position.y * -1
		x_width = handles["x_width"].control_position.x
		z_width = handles["z_width"].control_position.z
	

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_handles():

	var height_diff = height_max + height_min
	
	# balance handles here
	match origin_mode:
		OriginPosition.CENTER:
			height_max = height_diff / 2
			height_min = height_diff / 2
			
		OriginPosition.BASE:
			height_max = height_diff
			height_min = 0
			
		OriginPosition.BASE_CORNER:
			height_max = height_diff
			height_min = 0


# ////////////////////////////////////////////////////////////
# HOLLOW MODE FUNCTIONS

# The margin options available in Hollow mode, identified by the control names that should have margins
func get_hollow_margins() -> Array:
	
#	print("[OnyxCylinder] ", self.get_name(), " - get_hollow_margins()")
	
	var control_names = [
		"height_max",
		"height_min",
		"x_width",
		"z_width",
	]
	
	return control_names

# Gets the current shape parameters not controlled by handles, to apply to the hollow shape
func assign_hollow_properties():
	
	if hollow_object == null:
		return
	
	if hollow_object.sides != self.sides:
		hollow_object.sides = self.sides
	
	if hollow_object.rings != self.rings:
		hollow_object.rings = self.rings
	
	if hollow_object.smooth_normals != self.smooth_normals:
		hollow_object.smooth_normals = self.smooth_normals

# Assigns the hollow object an origin point based on the origin mode of this Onyx type.
# THIS DOES NOT MODIFY THE ORIGIN TYPE OF THE HOLLOW OBJECT
func assign_hollow_origin():
	
	if hollow_object == null:
		return
	
	print("[OnyxCylinder] ", self.get_name(), " - assign_hollow_origin()")
	
	var half_y = (height_max - height_min) / 2
#
#	hollow_object.set_translation(Vector3(0, 0, 0))
#	return
#
	match origin_mode:
		OriginPosition.CENTER:
			hollow_object.set_translation(Vector3(0, 0, 0))
		OriginPosition.BASE:
			hollow_object.set_translation(Vector3(0, 0, 0))
		OriginPosition.BASE_CORNER:
			hollow_object.set_translation(Vector3(x_width, 0, z_width))

# An override-able function used to determine how margins apply to handles
func apply_hollow_margins(hollow_controls: Dictionary):
	
#	print("[OnyxCylinder] ", self.get_name(), " - apply_hollow_margins(controls)")
#	print("base onyx controls - ", handles)
#	print("hollow controls - ", hollow_controls)
	
	for key in hollow_controls.keys():
		var hollow_handle = hollow_controls[key]
		var control_handle = handles[key]
		var margin = hollow_margin_values[key]
		
		match key:
			"height_max":
				hollow_handle.control_position.y = control_handle.control_position.y - margin
			"height_min":
				hollow_handle.control_position.y = control_handle.control_position.y + margin
			"x_width":
				hollow_handle.control_position.x = x_width - margin
			"z_width":
				hollow_handle.control_position.z = z_width - margin
	
	return hollow_controls
