tool
extends "res://addons/onyx/nodes/onyx/onyx_generator.gd"

# /////////////////////////////////////////////////////////////////////////////
# INFO
# A generator for use with OnyxShape.
# Generates a sphere shape.  It has a surface-like 
# interaction.

# A surface-like interaction means that each control point acts as an independent 
# point in space to define the boundaries of the shape, rather than it merely defining
# the "x width" or height, which allows it to be more useful when building and 
# carving spaces.


# ////////////////////////////////////////////////////////////
# DEPENDENCIES

# 2D and 3D vector math library
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")

# Helper Object for filling in the gap in functionality that exists with Gizmo handles.
var ControlPoint = load("res://addons/onyx/gizmos/control_point.gd")


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# STATICS

# Used for origin auto-updating, to define where the position should always move
# itself to.
enum OriginPosition {

	# Anchored to the center of the shape
	CENTER, 				
	# Anchored to the Y bottom, centered in all other axis
	BASE, 				
	# Anchored to the lowest value of every axis	
	BASE_CORNER,			
}

# The unwrap methods that can be selected with this generator.
enum UnwrapMethod {

	# All faces are unwrapped to match world space, overlaps
	PROPORTIONAL_OVERLAP, 	
	# Every face is mapped 1:1 with the bounds of UV space, will not extend beyond it
	PER_FACE_MAPPING,		
}

# Decides if the stairway gets a "base fill", and if so which way along the Y
# axis it's generated.
enum RampFillType {

	# No ramp fill, the stairs will proportionally generate along the two points.
	NONE, 

	# Ramp fill will be downwards.
	MINUS_Y, 

	# Ramp fill will be drawn upwards.
	PLUS_Y,
}


# ////////////////////////////////////
# PUBLIC

# The current origin mode set.
var origin_mode = OriginPosition.BASE


# SHAPE PROPERTIES /////

# The start location of the stair ramp.
var start_position = Vector3(0, 1, 0)

# The end location of the stair ramp.
var end_position = Vector3(0, 1, 2) 

# The width of the ramp
var stair_width = 6

# The depth of the ramp.
var stair_depth = 1

# If true, the stair count value is used to define the density of stairs
# regardless of how long it is.
var use_count_proportionally = true

# The number of stairs available. (Only active if use_count_proportionally
# is false)
var stair_count = 4

# The number of stairs per unit (Only active if use_count_proportionally
# is true)
var stairs_per_unit = 0.33


# The margins for the size of each step
var stair_length_percentage = Vector2(1, 1)


# HOLLOW PROPERTIES /////

# Used to determine how much the hollow faces move away from the
# sides of the current shape.

# TODO - Design something that makes sense, after you improve the shapes handle
# functionality


# UV OPTIONS /////

var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP


# ////////////////////////////////////
# PRIVATE

# Used to track the previously set origin mode, required for origin auto-updating
# to function.
var previous_origin_mode = OriginPosition.BASE


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# PROPERTY HANDLING

# Used in replacement of setget functions to streamline triggers n stuff.
func _set(property, value):

	#	print("[OnyxRoundedBox] - ", self, "_set()", property, value)
	#	
	match property:

		# ORIGIN MODE /////

		"origin_mode":
			if previous_origin_mode == value:
				return
			
			origin_mode = value
			_update_origin_mode()
			
			balance_control_data()
			
			_process_property_update()
			
			# ensure the origin mode toggle is preserved, and ensure the adjusted handles are saved.
			previous_origin_mode = origin_mode
			pre_controls = get_control_data()
			
			return true

		# START AND END POINTS /////
		
		"start_position":
			start_position = value
		
		"end_position":
			end_position = value

		# SHAPE PROPERTIES /////
		
		"stair_width":
			if value < 0:
				value = 0
			stair_width = value
		
		"stair_depth":
			if value < 0:
				value = 0
			stair_depth = value
		
		"stair_count":
			if value < 0:
				value = 0
			stair_count = value

		"use_count_proportionally":
			if use_count_proportionally == value:
				return

			use_count_proportionally = value
			self._process_property_list_change()
		
		"stairs_per_unit":
			if value < 0.1:
				value = 0.1

			stairs_per_unit = value
		
		"stair_length_percentage":
			if value.x < 0:
				value.x = 0
			if value.y < 0:
				value.y = 0
			stair_length_percentage = value

		# "ramp_fill_type":
		# 	ramp_fill_type = value

		# UVS / NORMALS /////

		"unwrap_method":
			unwrap_method = value


		# HOLLOW MARGINS /////

		# "_height_max_hollow":
		#     _height_hollow = value

		# "_x_width_hollow":
		#     _x_width_hollow = value

		# "_z_width_hollow":
		#     _z_width_hollow = value


	_process_property_update()
	return true

# Returns the list of custom shape properties that an owner should save and display.
func get_shape_properties() -> Dictionary:

	var props = {

		# ORIGIN SETTINGS /////
		
		"origin_mode" : {	
		
			"name" : "origin_mode",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Center, Base, Bottom Corner"
		},
		
		# START AND END POINTS /////
		
		"start_position" : {	
		
			"name" : "start_position",
			"type" : TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"end_position" : {	
		
			"name" : "end_position",
			"type" : TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		# SHAPE PROPERTIES /////
		
		"stair_width" : {	
		
			"name" : "stair_width",
			"type" : TYPE_REAL,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"stair_depth" : {	
		
			"name" : "stair_depth",
			"type" : TYPE_REAL,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},

		"stair_length_percentage" : {	
		
			"name" : "stair_length_percentage",
			"type" : TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},

		"use_count_proportionally" : {	
		
			"name" : "use_count_proportionally",
			"type" : TYPE_BOOL,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		
		# "ramp_fill_type" : {	
		
		#     "name" : "ramp_fill_type",
		#     "type" : TYPE_INT,
		# 	"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		# 	"hint": PROPERTY_HINT_ENUM,
		#     "hint_string": "Proportional Overlap, Per-Face Mapping"
		# },
		
		
		# UV / NORMALS /////
		
		"unwrap_method" : {	
		
			"name" : "uv_options/unwrap_method",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "None, Minus Y, Plus Y"
		},
		
		"smooth_normals" : {	
		
			"name" : "uv_options/smooth_normals",
			"type" : TYPE_BOOL,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
	}

	if use_count_proportionally == false:
		props["stair_count"] = {
			"name" : "stair_count",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		}

	else:
		props["stairs_per_unit"] = {
			"name" : "stairs_per_unit",
			"type" : TYPE_REAL,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		}


	return props



# Returns a set of custom properties used to tell the owner general aspects of it's
# shape, helping the owner set new properties for the next shape.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func get_shape_aspects() -> Dictionary:
	
	var aspects = {}

	var pool = [start_position, end_position]
	var line_bounds = VectorUtils.get_vertex_pool_aabb(PoolVector3Array(pool))
	
	var size = Vector3(line_bounds.size.x, line_bounds.size.y, line_bounds.size.z)
	var origin = Vector3(0, 0, 0)
	
	aspects[ShapeAspects.SHAPE_BOUNDS] = AABB(origin, size)
	aspects[ShapeAspects.ORIGIN] = Vector3(0, 0, 0)
	
	# TODO - Generate hollow margin aspect data

	return aspects


# Used by the owner to implant parts of the last shape generator to a new one.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func load_shape_aspects(aspects : Dictionary):
	
	if aspects.has(ShapeAspects.SHAPE_BOUNDS):
		var shape_bounds : AABB = aspects[ShapeAspects.SHAPE_BOUNDS]
		
		# If we're given an aspect, set the values now
		# TODO - Make this more accurate

		start_position = Vector3(shape_bounds.size.x / 2, shape_bounds.position.y, 
				shape_bounds.position.z)
		end_position = Vector3(shape_bounds.size.x / 2, shape_bounds.end.y, 
				shape_bounds.end.z)
		
	
#		if aspects.has(ShapeAspects.HOLLOW_BOUNDS):
#			var hollow_bounds = aspects[ShapeAspects.HOLLOW_BOUNDS]
#
	
	build_control_points()

# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# MESH GENERATION


# Creates new geometry to reflect the shapes current properties, then returns it.
func update_geometry() -> OnyxMesh:
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()
	
	return build_geometry(start_position, end_position, stair_width, stair_depth)


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:

    # Prevents geometry generation if the node hasn't loaded yet
    if Engine.editor_hint == false:
        return OnyxMesh.new()

    # TODO - Implement hollow mode for the wedge shape type.

    return build_geometry(start_position, end_position, stair_width, stair_depth)
	


# Performs the process of building a set of mesh data and returning it to the caller.
func build_geometry(geom_start : Vector3,  geom_end : Vector3,  geom_width : float,  
		geom_depth : float):

	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return
	
	var new_onyx_mesh = OnyxMesh.new()


	print(self, " - Generating geometry")

	# This shape is too custom to delegate, so it's being done here
	#   X---------X  e1 e2
	#	|         |  e3 e4
	#	|         |
	#	|         |
	#   X---------X  s1 s2
	#   X---------X  s3 s4
	
	# Build a transform
	var z_axis = (end_position - geom_start)
	z_axis = Vector3(z_axis.x, 0, z_axis.z).normalized()
	var y_axis = Vector3(0, 1, 0)
	var x_axis = z_axis.cross(y_axis)
	
	var mesh_pos = Vector3()
	var start_tf = Transform(x_axis, y_axis, z_axis, geom_start)
	#var end_tf = Transform(x_axis, y_axis, z_axis, end_position)

	# Change stair value based on proportional toggle
	var path_diff = end_position - geom_start
	var path_length = path_diff.length()
	var total_stairs = 0

	if use_count_proportionally == false:
		total_stairs = stair_count
	else:
		total_stairs = path_length / stairs_per_unit 
	
	# Setup variables
	
	var diff_inc = path_diff / total_stairs
	
	# get main 4 vectors
	var v1 = Vector3(-geom_width/2, geom_depth/2, 0)
	var v2 = Vector3(geom_width/2, geom_depth/2, 0)
	var v3 = Vector3(-geom_width/2, -geom_depth/2, 0)
	var v4 = Vector3(geom_width/2, -geom_depth/2, 0)
	
	var length_percentage_minus = Vector3(0, 0, 
			diff_inc.z/2 * -stair_length_percentage.x)
	var length_percentage_plus = Vector3(0, 0, 
			diff_inc.z/2 * stair_length_percentage.y)
	
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
	if unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
		var wrap = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]
		x_minus_uv = wrap;  x_plus_uv = wrap;
		y_minus_uv = wrap;  y_plus_uv = wrap;
		z_minus_uv = wrap;  z_plus_uv = wrap;
	
	elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
		x_minus_uv = [Vector2(e3.z, -e3.y), Vector2(e1.z, -e1.y), 
				Vector2(s1.z, -s1.y), Vector2(s3.z, -s3.y)]
		x_plus_uv = [Vector2(s4.z, -s4.y), Vector2(s2.z, -s2.y), 
				Vector2(e2.z, -e2.y), Vector2(e4.z, -e4.y)]
		
		y_minus_uv = [Vector2(s4.x, -s4.z), Vector2(e4.x, -e4.z), 
				Vector2(e3.x, -e3.z), Vector2(s3.x, -s3.z)]
		y_plus_uv = [Vector2(-s1.x, -s1.z), Vector2(-e1.x, -e1.z), 
				Vector2(-e2.x, -e2.z), Vector2(-s2.x, -s2.z)]
		
		z_minus_uv = [Vector2(-s3.x, -s3.y), Vector2(-s1.x, -s1.y), 
				Vector2(-s2.x, -s2.y), Vector2(-s4.x, -s4.y)]
		z_plus_uv = [Vector2(-e4.x, -e4.y), Vector2(-e2.x, -e2.y), 
				Vector2(-e1.x, -e1.y), Vector2(-e3.x, -e3.y)]
	
	var path_i = start_position + (diff_inc / 2)
	var i = 0
	
	# iterate through path
	while i < total_stairs:
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
		new_onyx_mesh.add_ngon(x_minus, [], [], x_minus_uv, [])
		new_onyx_mesh.add_ngon(x_plus, [], [], x_plus_uv, [])
		new_onyx_mesh.add_ngon(y_minus, [], [], y_minus_uv, [])
		new_onyx_mesh.add_ngon(y_plus, [], [], y_plus_uv, [])
		new_onyx_mesh.add_ngon(z_minus, [], [], z_minus_uv, [])
		new_onyx_mesh.add_ngon(z_plus, [], [], z_plus_uv, [])
		new_onyx_mesh.push_surface()
		
		i += 1
		path_i += diff_inc


	return new_onyx_mesh



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# ORIGIN POINT UPDATERS



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# CONTROL POINTS

# Clears and rebuilds the control list from scratch.
func build_control_points():

	#	print("[OnyxCube] ", self.get_name(), " - build_control_points()")

	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return

	var start_position = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	start_position.control_name = 'start_position'
	start_position.set_type_translate(false, "modify_control", "commit_control")
	
	var end_position = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	end_position.control_name = 'end_position'
	end_position.set_type_translate(false, "modify_control", "commit_control")
	
	var stair_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	stair_width.control_name = 'stair_width'
	stair_width.set_type_axis(false, "modify_control", "commit_control", Vector3(1, 0, 0))
	
	# populate the dictionary
	acv_controls[start_position.control_name] = start_position
	acv_controls[end_position.control_name] = end_position
	acv_controls[stair_width.control_name] = stair_width

	# need to give it positions in the case of a duplication or scene load.
	refresh_control_data()
	

# Ensures the data in the current control list reflects the shape properties.
func refresh_control_data():

	# If it's not selected, do not generate. (hollow object's can be refreshed without selection)
	#	if is_selected == false && is_hollow_object == false:
	#		return

	# Exit if not being run in the editor
	if Engine.editor_hint == false:
	#		print("...attempted to refresh_control_data()")
		return

	# Failsafe for script reloads, BECAUSE I CURRENTLY CAN'T DETECT THEM.
	# TODO - Migrate this to the new system somehow.
	if acv_controls.size() == 0:
	#		if gizmo != null:
	##			print("...attempted to refresh_control_data(), rebuilding handles.")
	#			gizmo.control_points.clear()
	#			build_control_points()
	#			return
		build_control_points()
		return

	var depth_mid = Vector3(0, stair_depth/2, 0)
	var width_mid =  Vector3(stair_width/2, 0, 0)
	var length_mid = Vector3(0, 0, ((end_position - start_position).length() / stair_count) / 2)
	
	acv_controls["start_position"].control_pos = start_position 
	acv_controls["end_position"].control_pos = end_position
	acv_controls["stair_width"].control_pos = start_position + depth_mid + width_mid
	

# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo (AKA - When someone moves a control point)
func update_control_from_gizmo(control):
	
	var coordinate = control.control_pos
	
	match control.control_name:
		# positions
		'start_position': start_position = coordinate
		'end_position': end_position = coordinate
		'stair_width': stair_width = (coordinate.x - start_position.x) * 2
		
	refresh_control_data()
	

# Applies the current handle values to the shape attributes
func apply_control_attributes():
	
	start_position = acv_controls["start_position"].control_pos
	end_position = acv_controls["end_position"].control_pos
	stair_width = (acv_controls["stair_width"].control_pos.x - start_position.x) * 2

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_control_data():
	
	pass
		

# ////////////////////////////////////////////////////////////
# BASE UI FUNCTIONS

func editor_select():
	pass

func editor_deselect():
	pass
