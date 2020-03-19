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

# The width of the wedge tip.
var point_width = 6

# The x width of the base.
var base_x_size = 1

# The z width of the base.
var base_z_size = 0.5

# If true, the X, Y and Z width will always equal each other.
var keep_shape_proportional = false



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
            previous_active_controls = get_control_data()
            
            return true

        # SHAPE PROPERTIES /////
        
        "point_position":
            point_position = value
		
        "point_width":
            if value < 0:
                value = 0
            point_width = value

        "base_x_size":
            if value < 0:
                value = 0
            
            if keep_shape_proportional == true:
                base_z_size = value

            base_x_size = value

        "base_z_size":
            if value < 0:
                value = 0
                
            if keep_shape_proportional == true:
                base_x_size = value
                
            base_z_size = value

        "keep_shape_proportional":
            keep_shape_proportional = value
            _update_origin_mode()
            balance_control_data()


        # UVS / NORMALS /////

        "unwrap_method":
            unwrap_method = value

        "smooth_normals":
            smooth_normals = value

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
        
        # SHAPE PROPERTIES /////
        
        "point_position" : {	
        
            "name" : "point_position",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "point_width" : {	
        
            "name" : "point_width",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "base_x_size" : {	
        
            "name" : "base_x_size",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "base_z_size" : {	
        
            "name" : "base_z_size",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "keep_shape_proportional" : {	
        
            "name" : "keep_shape_proportional",
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
	
	var size = Vector3(base_x_size * 2, point_position.y, base_z_size * 2)
	
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
		base_x_size = abs(shape_bounds.size.x / 2)
		base_z_size = abs(shape_bounds.size.z / 2)
	
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



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# MESH GENERATION


# Creates new geometry to reflect the shapes current properties, then returns it.
func update_geometry() -> OnyxMesh:
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()
	
	return build_geometry(point_position, base_x_size, base_z_size)


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:

    # Prevents geometry generation if the node hasn't loaded yet
    if Engine.editor_hint == false:
        return OnyxMesh.new()

    # TODO - Implement hollow mode for the wedge shape type.

    return build_geometry(point_position, base_x_size, base_z_size)
	


# Performs the process of building a set of mesh data and returning it to the caller.
func build_geometry(point_pos : Vector3,  x_size : float,  
        z_size : float):
	
    # Prevents geometry generation if the node hasn't loaded yet
    if is_inside_tree() == false:
        return

    var new_onyx_mesh = OnyxMesh.new()

    # Ensure the geometry is generated to fit around the current origin point.
    var position = Vector3(0, 0, 0)
    var max_x = 0
    if x_size < point_width:
        max_x = point_width
    else:
        max_x = x_size
        
    match origin_mode:
        OriginPosition.CENTER:
            position = Vector3(0, -point_pos.y / 2, 0)
        OriginPosition.BASE:
            position = Vector3(0, 0, 0)
        OriginPosition.BASE_CORNER:
            position = Vector3(max_x / 2, 0, z_size / 2)
            

    # GENERATE MESH

    #   X---------X  b1 b2
    #	|         |
    #		X---------X   p2 p1
    #	|		  |
    #   X---------X  b3 b4

    var base_1 = Vector3(x_size / 2, 0, z_size / 2) + position
    var base_2 = Vector3(-x_size / 2, 0, z_size / 2) + position

    var base_3 = Vector3(x_size / 2, 0, -z_size / 2) + position
    var base_4 = Vector3(-x_size / 2, 0, -z_size / 2) + position

    var point_1 = Vector3(-point_width / 2 + point_pos.x, 
            point_pos.y, point_pos.z) + position
    var point_2 = Vector3(point_width/2 + point_pos.x, 
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
        var median_bottom_point = Vector3(0.0, 0.0, -base_z_size / 2)
        var median_top_point = Vector3(0.0, 0.0, base_z_size / 2)
        
        var bottom_quad_length = (median_point - median_bottom_point).length()
        var top_quad_length = (median_point - median_top_point).length()
        bottom_quad_uv = [Vector2(-point_2.x, 0.0), Vector2(-point_1.x, 0.0), Vector2(-base_4.x, bottom_quad_length), Vector2(-base_3.x, bottom_quad_length)]
        top_quad_uv = [Vector2(-point_1.x, 0.0), Vector2(-point_2.x, 0.0), Vector2(-base_1.x, top_quad_length), Vector2(-base_2.x, top_quad_length)]
        
        # Base UVs
        base_uv = [Vector2(base_1.x, base_1.z), Vector2(base_2.x, base_2.z), Vector2(base_4.x, base_4.z), Vector2(base_3.x, base_3.z)]

    new_onyx_mesh.add_tri([base_1, point_2, base_3], [], [], left_triangle_uv, [])
    new_onyx_mesh.add_tri([base_4, point_1, base_2], [], [], right_triangle_uv, [])
    new_onyx_mesh.add_ngon([point_2, point_1, base_4, base_3], [], [], bottom_quad_uv, [])
    new_onyx_mesh.add_ngon([point_1, point_2, base_1, base_2], [], [], top_quad_uv, [])
    new_onyx_mesh.add_ngon([base_2, base_1, base_3, base_4], [], [], base_uv, [])


    return new_onyx_mesh



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# ORIGIN POINT UPDATERS


# Updates the origin location when the corresponding property is changed.
#
# NOTE - Does not have to be inherited, not all shapes should auto-update origin points.
#
func _update_origin_mode():
	
    # Used to prevent the function from triggering when not inside the tree.
    # This happens during duplication and replication and causes incorrect node placement.
    if Engine.editor_hint == false:
        return

    # Re-add once handles are a thing, otherwise this breaks the origin stuff.
    if active_controls.size() == 0:
        return

    #	print("[OnyxGenerator] ", self.name, " - _update_origin_mode()")
        
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
                    

    _process_origin_move(diff)
	


# Updates the origin position for the currently-active Origin Mode, either by building 
# a new one using it's own properties or through a new position.  
#
# DOES NOT update the origin when the origin property has changed, for use with handle commits.
#
# NOTE - Does not have to be inherited, not all shapes should auto-update origin points.
#
func _update_origin_position():

    if Engine.editor_hint == false:
        return

    #	print("[OnyxGenerator] ", self.name, " - _update_origin_position()")

    var diff = Vector3()
        
    var max_x = 0
    if base_x_size < point_width:
        max_x = point_width
    else:
        max_x = base_x_size
        
    match origin_mode:
        OriginPosition.CENTER:
            diff = Vector3(0, 0, 0) 
        
        OriginPosition.BASE:
            diff = Vector3(0, 0, 0) 
        
        OriginPosition.BASE_CORNER:
            diff = Vector3(0, 0, 0)


    _process_origin_move(diff)
	


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

    var point_position = ControlPoint.new(self, "get_gizmo_undo_state", 
            "get_gizmo_redo_state", "restore_state", "restore_state")
    point_position.control_name = 'point_position'
    point_position.set_type_translate(false, "modify_control", "commit_control")

    var point_width = ControlPoint.new(self, "get_gizmo_undo_state", 
            "get_gizmo_redo_state", "restore_state", "restore_state")
    point_width.control_name = 'point_width'
    point_width.set_type_axis(false, "modify_control", "commit_control", Vector3(1, 0, 0))

    var base_x_size = ControlPoint.new(self, "get_gizmo_undo_state", 
            "get_gizmo_redo_state", "restore_state", "restore_state")
    base_x_size.control_name = 'base_x_size'
    base_x_size.set_type_axis(false, "modify_control", "commit_control", Vector3(1, 0, 0))

    var base_z_size = ControlPoint.new(self, "get_gizmo_undo_state", 
            "get_gizmo_redo_state", "restore_state", "restore_state")
    base_z_size.control_name = 'base_z_size'
    base_z_size.set_type_axis(false, "modify_control", "commit_control", Vector3(0, 0, 1))

    # populate the dictionary
    active_controls[point_position.control_name] = point_position
    active_controls[point_width.control_name] = point_width
    active_controls[base_x_size.control_name] = base_x_size
    active_controls[base_z_size.control_name] = base_z_size

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
    if active_controls.size() == 0:
    #		if gizmo != null:
    ##			print("...attempted to refresh_control_data(), rebuilding handles.")
    #			gizmo.control_points.clear()
    #			build_control_points()
    #			return
        build_control_points()
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
            active_controls["point_position"].control_position = point_position - half_height
            active_controls['point_width'].control_position = Vector3(point_position.x + point_width / 2, point_position.y / 2, point_position.z)
            active_controls['base_x_size'].control_position = Vector3(base_x_size / 2, 0, 0) - half_height
            active_controls['base_z_size'].control_position = Vector3(0, 0, base_z_size / 2) - half_height
            
        OriginPosition.BASE:
            active_controls["point_position"].control_position = point_position
            active_controls['point_width'].control_position = Vector3(point_position.x + point_width / 2, point_position.y, point_position.z)
            active_controls['base_x_size'].control_position = Vector3(base_x_size / 2, 0, 0)
            active_controls['base_z_size'].control_position = Vector3(0, 0, base_z_size / 2)
            
        OriginPosition.BASE_CORNER:
            active_controls["point_position"].control_position = point_position + half_base
            active_controls['point_width'].control_position = Vector3(point_position.x + point_width / 2, point_position.y, point_position.z) + half_base
            active_controls['base_x_size'].control_position = Vector3(base_x_size / 2, 0, 0) + half_base
            active_controls['base_z_size'].control_position = Vector3(0, 0, base_z_size / 2) + half_base
	


	

# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo (AKA - When someone moves a control point)
func update_control_from_gizmo(control):
	
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
	
	refresh_control_data()
	

# Applies the current handle values to the shape attributes
func apply_control_attributes():
	
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
		point_position.x = active_controls['point_position'].control_position.x
		point_position.y = active_controls['point_position'].control_position.y * 2
		point_position.z = active_controls['point_position'].control_position.z
		point_width = (active_controls['point_width'].control_position.x - point_position.x) * 2
		base_x_size = active_controls['base_x_size'].control_position.x * 2
		base_z_size = active_controls['base_z_size'].control_position.z * 2
	
	if origin_mode == OriginPosition.BASE:
		point_position = active_controls['point_position'].control_position
		point_width = (active_controls['point_width'].control_position.x - point_position.x) * 2
		base_x_size = active_controls['base_x_size'].control_position.x * 2
		base_z_size = active_controls['base_z_size'].control_position.z * 2
	
	if origin_mode == OriginPosition.BASE_CORNER:
		point_position.x = active_controls['point_position'].control_position.x - half_base.x
		point_position.y = active_controls['point_position'].control_position.y
		point_position.z = active_controls['point_position'].control_position.z - half_base.z
		
		if point_base_diff > 0:
			point_width = active_controls['point_width'].control_position.x - point_position.x
			base_x_size = active_controls['base_x_size'].control_position.x - (point_base_diff / 2)
		else:
			point_width = active_controls['point_width'].control_position.x - point_position.x + (point_base_diff / 2)
			base_x_size = active_controls['base_x_size'].control_position.x

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
