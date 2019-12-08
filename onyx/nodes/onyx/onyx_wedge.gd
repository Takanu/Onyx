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
var old_handle_data : Dictionary = {}

# The offset of the origin relative to the rest of the mesh.
var origin_offset = Vector3(0, 0, 0)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)


# Exported variables representing all usable handles for re-shaping the mesh, in order.
# Must be exported to be saved in a scene?  smh.
export(Vector3) var point_position = Vector3(0, 1, 0) setget update_point_position
export(float) var point_width = 2 setget update_point_size
export(float) var base_x_size = 2 setget update_base_x_size
export(float) var base_z_size = 2 setget update_base_z_size
export(bool) var keep_shape_proportional = false setget update_proportional_toggle

# UVS
enum UnwrapMethod {PROPORTIONAL_OVERLAP, DIRECT_OVERLAP}
export(UnwrapMethod) var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP setget update_unwrap_method

export(Vector2) var uv_scale = Vector2(1.0, 1.0) setget update_uv_scale
export(bool) var flip_uvs_horizontally = false setget update_flip_uvs_horizontally
export(bool) var flip_uvs_vertically = false setget update_flip_uvs_vertically


# ////////////////////////////////////////////////////////////
# FUNCTIONS


# Global initialisation
func _enter_tree():
		
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
	pass

				
# ////////////////////////////////////////////////////////////
# PROPERTY UPDATERS

# Used when a handle variable changes in the properties panel.
func update_point_size(new_value):
	if new_value < 0:
		new_value = 0
	point_width = new_value
	generate_geometry(true)
	
func update_point_position(new_value):
	point_position = new_value
	generate_geometry(true)
	
func update_base_x_size(new_value):
	if new_value < 0:
		new_value = 0
	
	if keep_shape_proportional == true:
		base_z_size = new_value
		
	base_x_size = new_value
	generate_geometry(true)
	
func update_base_z_size(new_value):
	if new_value < 0:
		new_value = 0
		
	if keep_shape_proportional == true:
		base_x_size = new_value
		
	base_z_size = new_value
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
	old_handle_data = OnyxUtils.get_control_data(self)

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

# Updates the origin during generate_geometry() as well as the currently defined handles, 
# to ensure it's anchored where it needs to be.
func update_origin():
	
# 	print("updating origin222...")
	
	# Used to prevent the function from triggering when not inside the tree.
	# This happens during duplication and replication and causes incorrect node placement.
	if self.is_inside_tree() == false:
		return
	
	# Re-add once handles are a thing, otherwise this breaks the origin stuff.
#	if handles.size() == 0:
#		return
	
	var max_x = 0
	if base_x_size < point_width:
		max_x = point_width
	else:
		max_x = base_x_size

	
	# based on the current position and properties, work out how much to move the origin.
	var diff = Vector3(0, 0, 0)

	match previous_origin_mode:

		OriginPosition.CENTER:
			match origin_mode:

				OriginPosition.BASE:
					diff = Vector3(0, -point_position.y / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-max_x / 2, -point_position.y / 2, -base_z_size / 2)

		OriginPosition.BASE:
			match origin_mode:

				OriginPosition.CENTER:
					diff = Vector3(0, point_position.y / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-max_x / 2, 0, -base_z_size / 2)

		OriginPosition.BASE_CORNER:
			match origin_mode:

				OriginPosition.BASE:
					diff = Vector3(max_x / 2, 0, base_z_size / 2)
				OriginPosition.CENTER:
					diff = Vector3(max_x / 2, point_position.y / 2, base_z_size / 2)

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
	
	var max_x = 0
	if base_x_size < point_width:
		max_x = point_width
	else:
		max_x = base_x_size
	
	if new_location == null:
		
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
	var max_x = 0
	if base_x_size < point_width:
		max_x = point_width
	else:
		max_x = base_x_size
		
	match origin_mode:
		OriginPosition.CENTER:
			position = Vector3(0, -point_position.y / 2, 0)
		OriginPosition.BASE:
			position = Vector3(0, 0, 0)
		OriginPosition.BASE_CORNER:
			position = Vector3(max_x / 2, 0, base_z_size / 2)
			
	
	# GENERATE MESH
	onyx_mesh.clear()
	
	#   X---------X  b1 b2
	#	|         |
	#		X---------X   p2 p1
	#	|		  |
	#   X---------X  b3 b4
	
	var base_1 = Vector3(base_x_size/2, 0, base_z_size/2) + position
	var base_2 = Vector3(-base_x_size/2, 0, base_z_size/2) + position
	
	var base_3 = Vector3(base_x_size/2, 0, -base_z_size/2) + position
	var base_4 = Vector3(-base_x_size/2, 0, -base_z_size/2) + position
	
	var point_1 = Vector3(-point_width/2 + point_position.x, point_position.y, point_position.z) + position
	var point_2 = Vector3(point_width/2 + point_position.x, point_position.y, point_position.z) + position
	
	# UVS
	var left_triangle_uv = []
	var right_triangle_uv = []
	var bottom_quad_uv = []
	var top_quad_uv = []
	var base_uv = []
	
	if unwrap_method == UnwrapMethod.DIRECT_OVERLAP:
		left_triangle_uv = [Vector2(0.0, 1.0), Vector2(0.5, 0.0), Vector2(1.0, 1.0)]
		right_triangle_uv = left_triangle_uv
		bottom_quad_uv = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
		top_quad_uv = bottom_quad_uv
		base_uv = bottom_quad_uv
		
	elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
		
		# Triangle UVs
		# Get the length between the ramp point and the base
		var above_right_point = Vector3(point_1.x, point_1.y, base_4.z)
		var right_triangle_length = (above_right_point - base_4).length()
		right_triangle_uv = [Vector2(base_4.z, base_4.y), Vector2(point_1.z, -right_triangle_length), Vector2(base_2.z, base_2.y)]
		
		var above_left_point = Vector3(point_2.x, point_2.y, base_3.z)
		var left_triangle_length = (above_left_point - base_3).length()
		left_triangle_uv = [Vector2(base_1.z, base_1.y), Vector2(point_2.z, -left_triangle_length), Vector2(base_3.z, base_3.y)]
		
		# Slope UVs
		var median_point = Vector3(0.0, point_position.y, point_position.z)
		var median_bottom_point = Vector3(0.0, 0.0, -base_z_size / 2)
		var median_top_point = Vector3(0.0, 0.0, base_z_size / 2)
		
		var bottom_quad_length = (median_point - median_bottom_point).length()
		var top_quad_length = (median_point - median_top_point).length()
		bottom_quad_uv = [Vector2(-point_2.x, 0.0), Vector2(-point_1.x, 0.0), Vector2(-base_4.x, bottom_quad_length), Vector2(-base_3.x, bottom_quad_length)]
		top_quad_uv = [Vector2(-point_1.x, 0.0), Vector2(-point_2.x, 0.0), Vector2(-base_1.x, top_quad_length), Vector2(-base_2.x, top_quad_length)]
		
		# Base UVs
		base_uv = [Vector2(base_1.x, base_1.z), Vector2(base_2.x, base_2.z), Vector2(base_4.x, base_4.z), Vector2(base_3.x, base_3.z)]
	
	onyx_mesh.add_tri([base_1, point_2, base_3], [], [], left_triangle_uv, [])
	onyx_mesh.add_tri([base_4, point_1, base_2], [], [], right_triangle_uv, [])
	onyx_mesh.add_ngon([point_2, point_1, base_4, base_3], [], [], bottom_quad_uv, [])
	onyx_mesh.add_ngon([point_1, point_2, base_1, base_2], [], [], top_quad_uv, [])
	onyx_mesh.add_ngon([base_2, base_1, base_3, base_4], [], [], base_uv, [])
	
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

# On initialisation, control points are built for transmitting and handling interactive points between the node and the node's gizmo.
func build_handles():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	var triangle_x = [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_z = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	
	var point_position = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	point_position.control_name = 'point_position'
	point_position.set_type_translate(false, "handle_change", "handle_commit")
	
	var point_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	point_width.control_name = 'point_width'
	point_width.set_type_axis(false, "handle_change", "handle_commit", triangle_x)
	
	var base_x_size = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	base_x_size.control_name = 'base_x_size'
	base_x_size.set_type_axis(false, "handle_change", "handle_commit", triangle_x)
	
	var base_z_size = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	base_z_size.control_name = 'base_z_size'
	base_z_size.set_type_axis(false, "handle_change", "handle_commit", triangle_z)
	
	# populate the dictionary
	handles[point_position.control_name] = point_position
	handles[point_width.control_name] = point_width
	handles[base_x_size.control_name] = base_x_size
	handles[base_z_size.control_name] = base_z_size
	
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
	
	var max_x = 0
	if base_x_size < point_width:
		max_x = point_width
	else:
		max_x = base_x_size
	
	var half_height = Vector3(0, point_position.y/2, 0)
	var full_height = Vector3(0, point_position.y, 0)
	var half_base = Vector3(max_x / 2, 0, base_z_size / 2)
	
	match origin_mode:
		OriginPosition.CENTER:
			handles["point_position"].control_position = point_position - half_height
			handles['point_width'].control_position = Vector3(point_position.x + point_width / 2, point_position.y / 2, point_position.z)
			handles['base_x_size'].control_position = Vector3(base_x_size / 2, 0, 0) - half_height
			handles['base_z_size'].control_position = Vector3(0, 0, base_z_size / 2) - half_height
			
		OriginPosition.BASE:
			handles["point_position"].control_position = point_position
			handles['point_width'].control_position = Vector3(point_position.x + point_width / 2, point_position.y, point_position.z)
			handles['base_x_size'].control_position = Vector3(base_x_size / 2, 0, 0)
			handles['base_z_size'].control_position = Vector3(0, 0, base_z_size / 2)
			
		OriginPosition.BASE_CORNER:
			handles["point_position"].control_position = point_position + half_base
			handles['point_width'].control_position = Vector3(point_position.x + point_width / 2, point_position.y, point_position.z) + half_base
			handles['base_x_size'].control_position = Vector3(base_x_size / 2, 0, 0) + half_base
			handles['base_z_size'].control_position = Vector3(0, 0, base_z_size / 2) + half_base
	

# Changes the handle based on the given index and coordinates.
func update_handle_from_gizmo(control):
	
	var coordinate = control.control_position

	var max_x = 0
	if base_x_size < point_width:
		max_x = point_width
	else:
		max_x = base_x_size
	
	var point_base_diff = point_width - base_x_size

	if origin_mode == OriginPosition.CENTER:
		match control.control_name:
			'point_position':
				point_position.x = coordinate.x
				point_position.y = coordinate.y * 2
				point_position.z = coordinate.z
			'point_width': point_width = ( max(coordinate.x, 0) - point_position.x) * 2
			'base_x_size': base_x_size = max(coordinate.x, 0) * 2
			'base_z_size': base_z_size = max(coordinate.z, 0) * 2
	
	if origin_mode == OriginPosition.BASE:
		match control.control_name:
			'point_position': point_position = coordinate
			'point_width': point_width = ( max(coordinate.x, 0) - point_position.x) * 2
			'base_x_size': base_x_size = max(coordinate.x, 0) * 2
			'base_z_size': base_z_size = max(coordinate.z, 0) * 2
	
	if origin_mode == OriginPosition.BASE_CORNER:
		match control.control_name:
			'point_position':
				point_position.x = coordinate.x - (max_x / 2)
				point_position.y = coordinate.y
				point_position.z = coordinate.z - (base_z_size / 2)
			
			'point_width': 
				if point_width > base_x_size:
					point_width = ( max(coordinate.x, 0) - point_position.x)
				else:
					point_width = ( max(coordinate.x, 0) - point_position.x) + (point_base_diff / 2)
			
			'base_x_size': 
				if base_x_size > point_width:
					base_x_size = max(coordinate.x, 0)
				else:
					base_x_size = max(coordinate.x, 0) - (point_base_diff / 2)
					
			'base_z_size': base_z_size = max(coordinate.z, 0)
	
	generate_handles()
	

# Applies the current handle values to the shape attributes
func apply_handle_attributes():
	
	var max_x = 0
	if base_x_size < point_width:
		max_x = point_width
	else:
		max_x = base_x_size

	var half_height = Vector3(0, point_position.y/2, 0)
	var full_height = Vector3(0, point_position.y, 0)
	var half_base = Vector3(max_x / 2, 0, base_z_size / 2)
	var point_base_diff = point_width - base_x_size

	if origin_mode == OriginPosition.CENTER:
		point_position.x = handles['point_position'].control_position.x
		point_position.y = handles['point_position'].control_position.y * 2
		point_position.z = handles['point_position'].control_position.z
		point_width = (handles['point_width'].control_position.x - point_position.x) * 2
		base_x_size = handles['base_x_size'].control_position.x * 2
		base_z_size = handles['base_z_size'].control_position.z * 2
	
	if origin_mode == OriginPosition.BASE:
		point_position = handles['point_position'].control_position
		point_width = (handles['point_width'].control_position.x - point_position.x) * 2
		base_x_size = handles['base_x_size'].control_position.x * 2
		base_z_size = handles['base_z_size'].control_position.z * 2
	
	if origin_mode == OriginPosition.BASE_CORNER:
		point_position.x = handles['point_position'].control_position.x - half_base.x
		point_position.y = handles['point_position'].control_position.y
		point_position.z = handles['point_position'].control_position.z - half_base.z
		
		if point_base_diff > 0:
			point_width = handles['point_width'].control_position.x - point_position.x
			base_x_size = handles['base_x_size'].control_position.x - (point_base_diff / 2)
		else:
			point_width = handles['point_width'].control_position.x - point_position.x + (point_base_diff / 2)
			base_x_size = handles['base_x_size'].control_position.x
		
# Removes the transform offset applied to handles for the sake of visual clarity on the screen.
#func 

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
	pass
	
func editor_deselect():
	pass
	
