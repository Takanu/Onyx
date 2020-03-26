tool
extends "res://addons/onyx/nodes/onyx/onyx_generator.gd"

# /////////////////////////////////////////////////////////////////////////////
# INFO
# A generator for use with OnyxShape.
# Generates a wedge shape (kinda like a weird triangle).  
# It has a surface-like interaction.

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
	# Like the above, but applied on a per-segment basis.
	PROPORTIONAL_OVERLAP_SEGMENTS, 
	# Every face is mapped 1:1 with the bounds of UV space, will not extend beyond it
	PER_FACE_MAPPING,		
}


# ////////////////////////////////////
# PUBLIC

# The current origin mode set.
var origin_mode = OriginPosition.BASE


# SHAPE PROPERTIES /////

# The location of the wedge tip, relative to the shape.
var point_position = Vector3(0, 1, 0)

# The negative extent of the tip size, relative to the tip position.
var point_size_minus = 1

# The positive extent of the tip size, relative to the tip position.
var point_size_plus = 1

# The negative extent of the base on the X axis.
var x_minus_position = 1

# The positive extent of the base on the X axis.
var x_plus_position = 1

# The negative extent of the base on the z axis.
var z_minus_position = 1

# The positive extent of the base on the z axis.
var z_plus_position = 1


# If true, the relative position and size of the point will always scale when the
# base dimensions change.
var keep_point_proportional = false



# HOLLOW PROPERTIES /////

# Used to determine how much the hollow faces move away from the
# sides of the current shape.

# TODO - Design something that makes sense, after you improve the shapes handle
# functionality


# UV OPTIONS /////

var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP

# If true, the normals around the circumference of the cylinder will be smoothed.
var smooth_normals = false



# ////////////////////////////////////
# PRIVATE

# Used to track the previously set origin mode, required for origin auto-updating
# to function.
var previous_origin_mode = OriginPosition.BASE

# Used with keep_point_proportional to work out how to move the point position
# when it is enabled, based on where the point is in the base on the X-Z plane.
var _point_proportion_vec = Vector2(0.5, 0.5)

# Used with keep_point_proportional to work out how to move the negative point
# width property when enabled, based on where it lies on the X plane in relation
# to the base. (No orientation adjustments made)
var _point_minus_proportion = 0.25

# Used with keep_point_proportional to work out how to move the positive point
# width property when enabled, based on where it lies on the X plane in relation
# to the base. (No orientation adjustments made)
var _point_plus_proportion = 0.75

# Keeps track of whether we have an active property (as in, one being modified by
# a handle right now.)
var _has_active_property = false

# Keeps track of what that original value is
var _last_active_value = 0.0


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

		# SHAPE PROPERTIES /////
		
		"point_position":
			point_position = value
		
		"point_size_plus":
			if value < 0:
				value = 0
			point_size_plus = value
		
		"point_size_minus":
			if value < 0:
				value = 0
			point_size_minus = value

		"x_minus_position":
			if value < 0:
				value = 0
			
			# TODO - Add a function for balancing property inputs
			# when 

			x_minus_position = value
		
		"x_plus_position":
			if value < 0:
				value = 0
			
			# TODO - Add a function for balancing property inputs
			# when 

			x_plus_position = value
		
		"z_minus_position":
			if value < 0:
				value = 0
			
			# TODO - Add a function for balancing property inputs
			# when 

			z_minus_position = value
		
		"z_plus_position":
			if value < 0:
				value = 0
			
			# TODO - Add a function for balancing property inputs
			# when 

			z_plus_position = value

		"keep_point_proportional":
			keep_point_proportional = value
			_update_origin_mode()
			balance_control_data()


		# UVS / NORMALS /////

		"unwrap_method":
			unwrap_method = value

		"smooth_normals":
			smooth_normals = value

		# HOLLOW MARGINS /////

		# TODO - Reintroduce margins when the margins can be worked out.

	_update_point_proportion_vec()
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
        
        # SHAPE PROPERTIES /////
        
        "point_position" : {	
        
            "name" : "point_position",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "point_size_plus" : {	
        
            "name" : "point_size_plus",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "point_size_minus" : {	
        
            "name" : "point_size_minus",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "x_minus_position" : {	
        
            "name" : "x_minus_position",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },

		"x_plus_position" : {	
        
            "name" : "x_plus_position",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },

		"z_minus_position" : {	
        
            "name" : "z_minus_position",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },

		"z_plus_position" : {	
        
            "name" : "z_plus_position",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "keep_point_proportional" : {	
        
            "name" : "keep_point_proportional",
            "type" : TYPE_BOOL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        
        # UV / NORMALS /////
        
        "unwrap_method" : {	
        
            "name" : "uv_options/unwrap_method",
            "type" : TYPE_INT,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "Proportional Overlap, Per-Face Mapping"
        },
        
        "smooth_normals" : {	
        
            "name" : "uv_options/smooth_normals",
            "type" : TYPE_BOOL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
    }

    return props



# Returns a set of custom properties used to tell the owner general aspects of it's
# shape, helping the owner set new properties for the next shape.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func get_shape_aspects() -> Dictionary:
	
	var aspects = {}
	
	var size = Vector3(x_plus_position + x_minus_position,
			point_position.y - self.translation.y,
			z_plus_position + z_minus_position)
	
	match origin_mode:
		OriginPosition.BASE_CORNER:
			var bounds_origin = Vector3(-size.x / 2, -size.y / 2, -size.z / 2)
			aspects[ShapeAspects.SHAPE_BOUNDS] = AABB(bounds_origin, size)
			aspects[ShapeAspects.ORIGIN] = Vector3(0, 0, 0)
			
		OriginPosition.BASE:
			var bounds_origin = Vector3(-size.x / 2, 0, -size.z / 2)
			aspects[ShapeAspects.SHAPE_BOUNDS] = AABB(bounds_origin, size)
			aspects[ShapeAspects.ORIGIN] = Vector3(size.x / 2, 0, size.z / 2)
			
		OriginPosition.CENTER:
			var bounds_origin = Vector3(0, 0, 0)
			aspects[ShapeAspects.SHAPE_BOUNDS] = AABB(bounds_origin, size)
			aspects[ShapeAspects.ORIGIN] = Vector3(size.x / 2, size.y / 2, size.z / 2)
	
	
#	if get_parent().hollow_enable == true:
#		var h_minus_margin = Vector3(_x_minus_hollow, _y_minus_hollow, _z_minus_hollow)
#		var h_plus_margin = Vector3(_x_plus_hollow, _y_plus_hollow, _z_plus_hollow)
#
#		aspects[ShapeAspects.HOLLOW_BOUNDS] = AABB(origin + h_minus_margin, size - h_plus_margin)

	return aspects


# Used by the owner to implant parts of the last shape generator to a new one.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func load_shape_aspects(aspects : Dictionary):
	
	if aspects.has(ShapeAspects.SHAPE_BOUNDS):
		var shape_bounds : AABB = aspects[ShapeAspects.SHAPE_BOUNDS]
		
		# If we're given an aspect, set the values now
		# TODO - This is not coded correctly.

		point_position.y = abs(shape_bounds.size.y)

		x_minus_position = abs(shape_bounds.position.x)
		x_plus_position = abs(shape_bounds.end.x)
		z_minus_position = abs(shape_bounds.position.z)
		z_plus_position = abs(shape_bounds.end.z)
	
#		if aspects.has(ShapeAspects.HOLLOW_BOUNDS):
#			var hollow_bounds = aspects[ShapeAspects.HOLLOW_BOUNDS]
#
#			_x_minus_hollow = hollow_bounds.position.x - shape_bounds.position.x
#			_y_minus_hollow = hollow_bounds.position.y - shape_bounds.position.x
#			_z_minus_hollow = hollow_bounds.position.z - shape_bounds.position.x
#
#			_x_plus_hollow = hollow_bounds.end.x - shape_bounds.end.x
#			_y_plus_hollow = hollow_bounds.end.y - shape_bounds.end.x
#			_z_plus_hollow = hollow_bounds.end.z - shape_bounds.end.x
	
	build_control_points()
	_update_point_proportion_vec()



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# MESH GENERATION


# Creates new geometry to reflect the shapes current properties, then returns it.
func update_geometry() -> OnyxMesh:
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()
	
	return build_geometry(point_position, point_size_minus, 
			point_size_plus, x_minus_position, x_plus_position,
			z_minus_position, z_plus_position)


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:

	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()

	# TODO - Implement hollow mode for the wedge shape type.

	# return build_geometry(point_position, base_x_size, base_z_size)
	return OnyxMesh.new()


# Performs the process of building a set of mesh data and returning it to the caller.
func build_geometry(point_pos : Vector3,  geom_psize_minus : float,  geom_psize_plus : float, 
		geom_x_minus : float,  geom_x_plus : float,  geom_z_minus : float,  geom_z_plus : float):

	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return

	var new_onyx_mesh = OnyxMesh.new()

	# Ensure the geometry is generated to fit around the current origin point.
	# If it's set to the corner, we need to work out whether the tip or base has the
	# smallest value.

	# Decided to keep it simple and anchor it to the base always.

	var position = Vector3(0, 0, 0)
	# var min_x = 0
	# var minus_x_tip = point_pos.y - geom_psize_minus
	# var minus_x_base = -geom_x_minus

	# if minus_tip < -geom_x_minus:
	# 	min_x = point_width
	# else:
	# 	min_x = x_size

	# var min_z = 0
	# var m
		
	match origin_mode:
		OriginPosition.CENTER:
			position = Vector3(0, -point_pos.y / 2, 0)
		OriginPosition.BASE:
			position = Vector3(0, 0, 0)
		OriginPosition.BASE_CORNER:
			position = Vector3(geom_x_minus, 0, geom_z_minus)
			

	# GENERATE MESH

	#   X---------X  b1 b2
	#	|         |
	#		X---------X   p2 p1
	#	|		  |
	#   X---------X  b3 b4

	var base_1 = Vector3(geom_x_plus, 0, geom_z_plus) + position
	var base_2 = Vector3(-geom_x_minus, 0, geom_z_plus) + position

	var base_3 = Vector3(geom_x_plus, 0, -geom_z_minus) + position
	var base_4 = Vector3(-geom_x_minus, 0, -geom_z_minus) + position

	var point_1 = Vector3(-geom_psize_minus + point_pos.x, 
			point_pos.y, point_pos.z) + position
	var point_2 = Vector3(geom_psize_plus + point_pos.x, 
			point_pos.y, point_pos.z) + position

	# UVS
	var left_triangle_uv = []
	var right_triangle_uv = []
	var bottom_quad_uv = []
	var top_quad_uv = []
	var base_uv = []

	if unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
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
		var median_point = Vector3(0.0, point_pos.y, point_pos.z)
		var median_bottom_point = Vector3(0.0, 0.0, -geom_z_minus / 2)
		var median_top_point = Vector3(0.0, 0.0, geom_z_plus / 2)
		
		var bottom_quad_length = (median_point - median_bottom_point).length()
		var top_quad_length = (median_point - median_top_point).length()
		bottom_quad_uv = [Vector2(-point_2.x, 0.0), Vector2(-point_1.x, 0.0), Vector2(-base_4.x, bottom_quad_length), Vector2(-base_3.x, bottom_quad_length)]
		top_quad_uv = [Vector2(-point_1.x, 0.0), Vector2(-point_2.x, 0.0), Vector2(-base_1.x, top_quad_length), Vector2(-base_2.x, top_quad_length)]
		
		# Base UVs
		base_uv = [Vector2(base_1.x, base_1.z), Vector2(base_2.x, base_2.z), Vector2(base_4.x, base_4.z), Vector2(base_3.x, base_3.z)]

	new_onyx_mesh.add_tri([base_1, point_2, base_3], [], [], left_triangle_uv, [])
	new_onyx_mesh.push_surface()

	new_onyx_mesh.add_tri([base_4, point_1, base_2], [], [], right_triangle_uv, [])
	new_onyx_mesh.push_surface()

	new_onyx_mesh.add_ngon([point_2, point_1, base_4, base_3], [], [], bottom_quad_uv, [])
	new_onyx_mesh.push_surface()

	new_onyx_mesh.add_ngon([point_1, point_2, base_1, base_2], [], [], top_quad_uv, [])
	new_onyx_mesh.push_surface()
	
	new_onyx_mesh.add_ngon([base_2, base_1, base_3, base_4], [], [], base_uv, [])
	new_onyx_mesh.push_surface()


	return new_onyx_mesh



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# ORIGIN POINT UPDATERS


# Updates the origin location when the corresponding property is changed.
#
# NOTE - Does not have to be inherited, not all shapes should auto-update 
# origin points.
#
func _update_origin_mode():
	
    # Used to prevent the function from triggering when not inside the tree.
    # This happens during duplication and replication and causes incorrect node 
	# placement.
    if Engine.editor_hint == false:
        return

    # Re-add once handles are a thing, otherwise this breaks the origin stuff.
    if acv_controls.size() == 0:
        return

    #	print("[OnyxGenerator] ", self.name, " - _update_origin_mode()")
	
	# Decided to keep it simple and make the base always the domain of the 
	# origin point.

    # var max_x = 0
    # if base_x_size < point_width:
    #     max_x = point_width
    # else:
    #     max_x = base_x_size


    # based on the current position and properties, work out how much to 
	# move the origin.
    var diff = Vector3(0, 0, 0)

    match previous_origin_mode:

        OriginPosition.CENTER:
            match origin_mode:

                OriginPosition.BASE:
                    diff = Vector3(0, -point_position.y / 2, 0)
                OriginPosition.BASE_CORNER:
                    diff = Vector3(-x_minus_position, -point_position.y / 2, 
							-z_minus_position)

        OriginPosition.BASE:
            match origin_mode:

                OriginPosition.CENTER:
                    diff = Vector3(0, point_position.y / 2, 0)
                OriginPosition.BASE_CORNER:
                    diff = Vector3(-x_minus_position, 0, -z_minus_position)

        OriginPosition.BASE_CORNER:
            match origin_mode:

                OriginPosition.BASE:
                    diff = Vector3(x_plus_position / 2, 0, z_plus_position / 2)
                OriginPosition.CENTER:
                    diff = Vector3(x_plus_position / 2, point_position.y / 2, 
							z_plus_position / 2)
                    

    _process_origin_move(diff)
	


# Updates the origin position for the currently-active Origin Mode, either by building 
# a new one using it's own properties or through a new position.  
#
# DOES NOT update the origin when the origin property has changed, 
# for use with handle commits.
#
# NOTE - Does not have to be inherited, not all shapes should auto-update 
# origin points.
#
func _update_origin_position():

    if Engine.editor_hint == false:
        return

    #	print("[OnyxGenerator] ", self.name, " - _update_origin_position()")

	# Decided to keep it simple and make the base always the domain of the 
	# origin point.

    var diff = Vector3()
        
    # var max_x = 0
    # if base_x_size < point_width:
    #     max_x = point_width
    # else:
    #     max_x = base_x_size
        
    match origin_mode:
        OriginPosition.CENTER:
            diff = Vector3(0, 0, 0) 
        
        OriginPosition.BASE:
            diff = Vector3(0, 0, 0) 
        
        OriginPosition.BASE_CORNER:
            diff = Vector3(0, 0, 0)


    _process_origin_move(diff)
	

# Returns the origin point that the hollow object should be set at.
func get_hollow_origin():

	return Vector3(0, 0, 0)

# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# CONTROL POINTS

# Clears and rebuilds the control list from scratch.
func build_control_points():

	#	print("[OnyxCube] ", self.get_name(), " - build_control_points()")

	# If it's not selected, do not generate. (hollow object's can be refreshed without selection)
	#	if is_selected == false && is_hollow_object == false:
	#		return

	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return

	# POINT CONTROLS /////

	var point_position = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	point_position.control_name = 'point_position'
	point_position.set_type_translate(false, "modify_control", "commit_control")

	var point_size_minus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	point_size_minus.control_name = 'point_size_minus'
	point_size_minus.set_type_axis(false, "modify_control", "commit_control", 
			Vector3(1, 0, 0))

	var point_size_plus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	point_size_plus.control_name = 'point_size_plus'
	point_size_plus.set_type_axis(false, "modify_control", "commit_control", 
			Vector3(1, 0, 0))

	# BASE CONTROLS /////

	var x_minus_position = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	x_minus_position.control_name = 'x_minus_position'
	x_minus_position.set_type_axis(false, "modify_control", "commit_control", 
			Vector3(1, 0, 0))

	var x_plus_position = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	x_plus_position.control_name = 'x_plus_position'
	x_plus_position.set_type_axis(false, "modify_control", "commit_control", 
			Vector3(1, 0, 0))

	var z_minus_position = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	z_minus_position.control_name = 'z_minus_position'
	z_minus_position.set_type_axis(false, "modify_control", "commit_control", 
			Vector3(0, 0, 1))

	var z_plus_position = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	z_plus_position.control_name = 'z_plus_position'
	z_plus_position.set_type_axis(false, "modify_control", "commit_control", 
			Vector3(0, 0, 1))

	# populate the dictionary
	acv_controls[point_position.control_name] = point_position
	acv_controls[point_size_minus.control_name] = point_size_minus
	acv_controls[point_size_plus.control_name] = point_size_plus

	acv_controls[x_minus_position.control_name] = x_minus_position
	acv_controls[x_plus_position.control_name] = x_plus_position
	acv_controls[z_minus_position.control_name] = z_minus_position
	acv_controls[z_plus_position.control_name] = z_plus_position

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

	# Not needed anymore

	# var max_x = 0
	# if base_x_size < point_width:
	# 	max_x = point_width
	# else:
	# 	max_x = base_x_size

	var half_base = Vector3(x_plus_position / 2, 0, z_plus_position / 2)
	var half_height = Vector3(0, point_position.y / 2, 0)
	var full_height = Vector3(0, point_position.y, 0)

	match origin_mode:
		OriginPosition.CENTER:
			acv_controls["point_position"].control_pos = point_position - half_height
			acv_controls['point_size_minus'].control_pos = Vector3(
					point_position.x - point_size_minus, half_height.y, point_position.z)
			acv_controls['point_size_plus'].control_pos = Vector3(
					point_position.x + point_size_plus, half_height.y, point_position.z)

			# /////////

			acv_controls['x_minus_position'].control_pos = Vector3(
					-x_minus_position, 0, 0) - half_height
			acv_controls['x_plus_position'].control_pos = Vector3(
					x_plus_position, 0, 0) - half_height
			acv_controls['z_minus_position'].control_pos = Vector3(
					0, 0, -z_minus_position) - half_height
			acv_controls['z_plus_position'].control_pos = Vector3(
					0, 0, z_plus_position) - half_height
			

		OriginPosition.BASE:
			acv_controls["point_position"].control_pos = point_position
			acv_controls['point_size_minus'].control_pos = Vector3(
					point_position.x - point_size_minus, point_position.y, point_position.z)
			acv_controls['point_size_plus'].control_pos = Vector3(
					point_position.x + point_size_plus, point_position.y, point_position.z)

			# /////////

			acv_controls['x_minus_position'].control_pos = Vector3(-x_minus_position, 0, 0)
			acv_controls['x_plus_position'].control_pos = Vector3(x_plus_position, 0, 0)
			acv_controls['z_minus_position'].control_pos = Vector3(0, 0, -z_minus_position)
			acv_controls['z_plus_position'].control_pos = Vector3(0, 0, z_plus_position)
			
		OriginPosition.BASE_CORNER:
			acv_controls["point_position"].control_pos = point_position + half_base
			acv_controls['point_size_minus'].control_pos = Vector3(
					point_position.x - point_size_minus, point_position.y, point_position.z) + half_base
			acv_controls['point_size_plus'].control_pos = Vector3(
					point_position.x + point_size_plus, point_position.y, point_position.z) + half_base

			# /////////

			acv_controls['x_minus_position'].control_pos = Vector3(-x_minus_position, 0, 0) + half_base
			acv_controls['x_plus_position'].control_pos = Vector3(x_plus_position, 0, 0) + half_base
			acv_controls['z_minus_position'].control_pos = Vector3(0, 0, -z_minus_position) + half_base
			acv_controls['z_plus_position'].control_pos = Vector3(0, 0, z_plus_position) + half_base



	

# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo to the properties they belong to. 
# (AKA - When someone moves a control point)
# 
func update_control_from_gizmo(control):
	
	var control_pos = control.control_pos

	# Used to measure absolute property changes for the "Keep Point Proportional" option.
	if _has_active_property == false:
		
		match control.control_name:

			'x_minus_position': 
				_has_active_property = true
				_last_active_value = x_minus_position
			'x_plus_position': 
				_has_active_property = true
				_last_active_value = x_plus_position
			'z_minus_position': 
				_has_active_property = true
				_last_active_value = z_minus_position
			'z_plus_position': 
				_has_active_property = true
				_last_active_value = z_plus_position
	

	if origin_mode == OriginPosition.CENTER:
		match control.control_name:
			'point_position':
				point_position.x = control_pos.x
				point_position.y = control_pos.y * 2
				point_position.z = control_pos.z
			'point_size_minus':
				point_size_minus = ( (min(control_pos.x, point_position.x) * -1) + point_position.x)
			'point_size_plus':
				point_size_plus = ( max(control_pos.x, point_position.x) - point_position.x)

			'x_minus_position': 
				x_minus_position = min(control_pos.x, 0) * -1
				var diff = x_minus_position - _last_active_value
				_move_point_width_proportionally(false, diff)
				_last_active_value = x_minus_position

			'x_plus_position': 
				x_plus_position = max(control_pos.x, 0)
				var diff = x_plus_position - _last_active_value
				_move_point_width_proportionally(true, diff)
				_last_active_value = x_plus_position

			'z_minus_position': 
				z_minus_position = min(control_pos.z, 0) * -1
				var diff = z_minus_position - _last_active_value
				_move_point_proportionally(false, diff)
				_last_active_value = z_minus_position

			'z_plus_position': 
				z_plus_position = max(control_pos.z, 0)
				var diff = z_plus_position - _last_active_value
				_move_point_proportionally(true, diff)
				_last_active_value = z_plus_position
	

	if origin_mode == OriginPosition.BASE:
		match control.control_name:
			'point_position': 
				point_position = control_pos
			'point_size_minus':
				point_size_minus = ( (min(control_pos.x, point_position.x) * -1) + point_position.x)
			'point_size_plus':
				point_size_plus = ( max(control_pos.x, point_position.x) - point_position.x)

			'x_minus_position': 
				x_minus_position = min(control_pos.x, 0) * -1
				var diff = x_minus_position - _last_active_value
				_move_point_width_proportionally(false, -diff)
				_last_active_value = x_minus_position

			'x_plus_position': 
				x_plus_position = max(control_pos.x, 0)
				var diff = x_plus_position - _last_active_value
				_move_point_width_proportionally(true, diff)
				_last_active_value = x_plus_position

			'z_minus_position': 
				z_minus_position = min(control_pos.z, 0) * -1
				var diff = z_minus_position - _last_active_value
				_move_point_proportionally(false, -diff)
				_last_active_value = z_minus_position

			'z_plus_position': 
				z_plus_position = max(control_pos.z, 0)
				var diff = z_plus_position - _last_active_value
				_move_point_proportionally(true, diff)
				_last_active_value = z_plus_position

	
	if origin_mode == OriginPosition.BASE_CORNER:
		match control.control_name:
			'point_position':
				point_position.x = control_pos.x - (x_plus_position / 2)
				point_position.y = control_pos.y
				point_position.z = control_pos.z - (z_plus_position / 2)
			
			'point_size_minus':
				point_size_minus = ( (min(control_pos.x, point_position.x) * -1) + point_position.x)
			'point_size_plus':
				point_size_plus = ( max(control_pos.x, point_position.x) - point_position.x)
			
			'x_minus_position': 
				x_minus_position = min(control_pos.x, 0) * -1
				var diff = x_minus_position - _last_active_value
				_move_point_width_proportionally(false, -diff)
				_last_active_value = x_minus_position

			'x_plus_position': 
				x_plus_position = max(control_pos.x, 0)
				var diff = x_plus_position - _last_active_value
				_move_point_width_proportionally(true, diff)
				_last_active_value = x_plus_position

			'z_minus_position': 
				z_minus_position = min(control_pos.z, 0) * -1
				var diff = z_minus_position - _last_active_value
				_move_point_proportionally(false, -diff)
				_last_active_value = z_minus_position

			'z_plus_position': 
				z_plus_position = max(control_pos.z, 0)
				var diff = z_plus_position - _last_active_value
				_move_point_proportionally(true, diff)
				_last_active_value = z_plus_position
	
	refresh_control_data()
	_update_point_proportion_vec()
	

# Applies the current handle values to the shape attributes
func apply_control_attributes():
	
	var half_height = Vector3(0, point_position.y/2, 0)
	var full_height = Vector3(0, point_position.y, 0)
	var half_base = Vector3(x_plus_position / 2, 0, z_plus_position / 2)

	if origin_mode == OriginPosition.CENTER:
		point_position.x = acv_controls['point_position'].control_pos.x
		point_position.y = acv_controls['point_position'].control_pos.y * 2
		point_position.z = acv_controls['point_position'].control_pos.z

		point_size_minus = (acv_controls['point_size_minus'].control_pos.x - point_position.x) * -1
		point_size_plus = (acv_controls['point_size_plus'].control_pos.x - point_position.x)

		x_minus_position = acv_controls['x_minus_position'].control_pos.x * -1
		x_plus_position = acv_controls['x_plus_position'].control_pos.x
		z_minus_position = acv_controls['z_minus_position'].control_pos.z * -1
		z_plus_position = acv_controls['z_plus_position'].control_pos.z
	

	if origin_mode == OriginPosition.BASE:
		point_position = acv_controls['point_position'].control_pos
		
		point_size_minus = (acv_controls['point_size_minus'].control_pos.x - point_position.x) * -1
		point_size_plus = (acv_controls['point_size_plus'].control_pos.x - point_position.x)

		x_minus_position = acv_controls['x_minus_position'].control_pos.x * -1
		x_plus_position = acv_controls['x_plus_position'].control_pos.x
		z_minus_position = acv_controls['z_minus_position'].control_pos.z * -1
		z_plus_position = acv_controls['z_plus_position'].control_pos.z
	

	if origin_mode == OriginPosition.BASE_CORNER:
		point_position.x = acv_controls['point_position'].control_pos.x - half_base.x
		point_position.y = acv_controls['point_position'].control_pos.y
		point_position.z = acv_controls['point_position'].control_pos.z - half_base.z

		x_minus_position = acv_controls['x_minus_position'].control_pos.x * -1
		x_plus_position = acv_controls['x_plus_position'].control_pos.x
		z_minus_position = acv_controls['z_minus_position'].control_pos.z * -1
		z_plus_position = acv_controls['z_plus_position'].control_pos.z
	
	_update_point_proportion_vec()

	# If we were tracking a property value for proportional editing, finish it.
	if _has_active_property == true:
		_has_active_property = false
		_last_active_value = 0.0
		
		
# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_control_data():
	
	pass


# Updates the point proportion vector whenever the point position is moved.
func _update_point_proportion_vec():
	
	var size = Vector2(x_minus_position + x_plus_position,
			 z_minus_position + z_plus_position)

	# Adjust all the values we're getting proportions for so they have
	# an origin of (0, 0)
	var base_point = Vector2(point_position.x + x_minus_position,
			point_position.z + z_minus_position)
		
	var adjusted_minus_width = -point_size_minus + x_minus_position
	var adjusted_plus_width = point_size_plus + x_minus_position

	_point_proportion_vec = Vector2(
			base_point.x / size.x, base_point.y / size.y)

	_point_minus_proportion = adjusted_minus_width / size.x
	_point_plus_proportion = adjusted_plus_width / size.x


# Moves the point based on the current _point_proportion_vec based on the amount of movement provided.
# This node automatically checks if keep_point_proportional is enabled.
# NOTE - This is for Z-axis movement only.
func _move_point_proportionally(positively_signed : bool, movement : float):
	
	if keep_point_proportional == false || movement == 0:
		return

	# If positively signed, check for proportion values lower than 0
	if positively_signed == true && _point_proportion_vec.y < 0:
		return
	
	# If negatively signed, check for proportion values higher than 1
	if positively_signed == false && _point_proportion_vec.y > 1:
		return
	
	# Now work out the total movement
	# Movement is limited to a ratio of 1:1 to keep behaviour in line with
	# proportional width movements.
	var total_movement = 0.0
	
	if positively_signed == true:
		total_movement = movement * min(_point_proportion_vec.y, 1)

	else:
		var one_minus = abs(_point_proportion_vec.y - 1)
		total_movement = movement * min(one_minus, 1)
	
	point_position += Vector3(0, 0, total_movement)


# Moves the point based on the current _point_proportion_vec based on the amount of movement provided.
# This node automatically checks if keep_point_proportional is enabled.
# NOTE - This is for X-axis movement only.
func _move_point_width_proportionally(positively_signed : bool,  movement : float):
	
	if keep_point_proportional == false || movement == 0:
		return

	print(_point_plus_proportion, _point_minus_proportion)

	if positively_signed == true:

		# If we have to move the point, we need to be careful how we move
		# everything else as moving the point will move the width points.
		if _point_proportion_vec.x > 0:
			var adjusted_move = movement * _point_proportion_vec.x
			point_position += Vector3(adjusted_move, 0, 0)
			point_size_minus += adjusted_move

			if _point_plus_proportion > 0:
				point_size_plus += movement / 2
		
		# If not, just move the size proportionally.

		elif _point_plus_proportion > 0:
			point_size_plus += movement
		
		return

	else:

		# If we have to move the point, we need to be careful how we move
		# everything else as moving the point will move the width points.

		if _point_proportion_vec.x < 1:
			var one_minus = abs(_point_proportion_vec.x - 1)
			var adjusted_move = movement * one_minus
			point_position += Vector3(adjusted_move, 0, 0)
			point_size_plus -= adjusted_move

			if _point_minus_proportion < 1:
				point_size_minus -= movement / 2

		# If not, just move the size proportionally.

		elif _point_minus_proportion < 1:
			point_size_minus -= movement
		
		return
		

		


# ////////////////////////////////////////////////////////////
# BASE UI FUNCTIONS

func editor_select():
	pass

func editor_deselect():
	pass
