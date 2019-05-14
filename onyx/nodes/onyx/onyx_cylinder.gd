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
export(UnwrapMethod) var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP setget update_unwrap_method

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
	old_handle_data = OnyxUtils.get_handle_data(self)

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
	self.global_translate(new_translation)
	OnyxUtils.translate_children(self, new_translation * -1)
	
	

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
	var triangle_y = [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_z = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	
	var height_max = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	height_max.control_name = 'height_max'
	height_max.set_type_axis(false, "handle_change", "handle_commit", triangle_y)
	
	var height_min = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	height_min.control_name = 'height_min'
	height_min.set_type_axis(false, "handle_change", "handle_commit", triangle_y)
	
	var x_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	x_width.control_name = 'x_width'
	x_width.set_type_axis(false, "handle_change", "handle_commit", triangle_x)
	
	var z_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	z_width.control_name = 'z_width'
	z_width.set_type_axis(false, "handle_change", "handle_commit", triangle_z)
	
	# populate the dictionary
	handles["height_max"] = height_max
	handles["height_min"] = height_min
	handles["x_width"] = x_width
	handles["z_width"] = z_width
	
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

	
	generate_handles()
	

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
	
	