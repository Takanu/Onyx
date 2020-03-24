tool
extends "res://addons/onyx/nodes/onyx/onyx_generator.gd"

# /////////////////////////////////////////////////////////////////////////////
# INFO
# A generator for use with OnyxShape.
# Generates a box-like shape with rounded like corners.  It has a surface-like interaction.

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
	CENTER, 					# Anchored to the center of the shape
	BASE, 						# Anchored to the Y bottom, centered in all other axis
	BASE_CORNER,				# Anchored to the lowest value of every axis
}

# The unwrap methods that can be selected with this generator.
enum UnwrapMethod {
	PROPORTIONAL_OVERLAP, 		# All faces are unwrapped to match world space, will overlap
	PER_FACE_MAPPING,			# Every face is mapped 1:1 with the bounds of UV space
}

# The axis on which the corners become rounded.
enum CornerAxis {
	X,
	Y, 
	Z,
}


# ////////////////////////////////////
# PUBLIC

# The current origin mode set.
var origin_mode = OriginPosition.BASE


# SHAPE PROPERTIES /////

# Exported variables representing all usable handles for re-shaping the mesh.
var x_plus_position = 0.5
var x_minus_position = 0.5

var y_plus_position = 1.0
var y_minus_position = 0.0

var z_plus_position = 0.5
var z_minus_position = 0.5


# Decides which corners on the box become rounded.
var corner_axis = CornerAxis.X

# The size of the corner in standard world units.
var corner_size = 0.2

# The number of faces each corner has.  The more faces, the smoother the appearance
var corner_faces = 4


# HOLLOW PROPERTIES /////

# Used to determine how much the hollow faces move away from the
# sides of the current box.
var _x_plus_hollow = 0.2
var _x_minus_hollow = 0.2

var _y_plus_hollow = 0.2
var _y_minus_hollow = 0.2

var _z_plus_hollow = 0.2
var _z_minus_hollow = 0.2


# UV OPTIONS /////

var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP

# If true, the normals around the rounded corner will be smoothed.
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
		
		# SHAPE PROPERTIES /////
		
		"x_minus_position":
			if value < 0 || origin_mode == OriginPosition.BASE_CORNER:
				value = 0
			
			x_minus_position = value
		
		"x_plus_position":
			if value < 0:
				value = 0
				
			x_plus_position = value
		
		"y_minus_position":
			if value < 0 && (origin_mode == OriginPosition.BASE_CORNER || origin_mode == OriginPosition.BASE) :
				value = 0
				
			y_minus_position = value
		
		"y_plus_position":
			if value < 0:
				value = 0
				
			y_plus_position = value
		
		"z_minus_position":
			if value < 0 || origin_mode == OriginPosition.BASE_CORNER:
				value = 0
				
			z_minus_position = value
		
		"z_plus_position":
			if value < 0:
				value = 0
				
			z_plus_position = value
		
		# CORNER PROPERTIES /////
		
		"corner_axis":
			corner_axis = value
		
		"corner_faces":
			if value <= 0:
				value = 1
				
			corner_faces = value
		
		"corner_size":
			if value <= 0:
				value = 0.01
				
			# ensure the rounded corners do not surpass the bounds of the size of the shape sides.
			var x_range = (x_plus_position - -x_minus_position) / 2
			var y_range = (y_plus_position - -y_minus_position) / 2
			var z_range = (z_plus_position - -z_minus_position) / 2
			
			match corner_axis:
				CornerAxis.X:
					if value > y_range:
						value = y_range
					if value > z_range:
						value = z_range
				CornerAxis.Y:
					if value > x_range:
						value = x_range
					if value > z_range:
						value = z_range
				CornerAxis.Z:
					if value > x_range:
						value = x_range
					if value > y_range:
						value = y_range
				
			corner_size = value
		
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
		
		# UVS / NORMALS /////
		
		"unwrap_method":
			unwrap_method = value
		
		"smooth_normals":
			smooth_normals = value
		
		# HOLLOW MARGINS /////
		
		"_x_minus_hollow":
			_x_minus_hollow = value
		
		"_x_plus_hollow":
			_x_plus_hollow = value
		
		"_y_minus_hollow":
			_y_minus_hollow = value
		
		"_y_plus_hollow":
			_y_plus_hollow = value
		
		"_z_minus_hollow":
			_z_minus_hollow = value
		
		"_z_plus_hollow":
			_z_plus_hollow = value
	
	_process_property_update()
	return true



# Returns the list of custom shape properties that an owner should save and display.
func get_shape_properties() -> Dictionary:

	var props = {
		
		# SHAPE PROPERTIES /////
		
		"corner_size" : {	
		
			"name" : "corner_size",
			"type" : TYPE_REAL,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"corner_faces" : {	
		
			"name" : "corner_faces",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		# ORIGIN SETTINGS /////
		
		"origin_mode" : {	
		
			"name" : "origin_mode",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Center, Base, Bottom Corner"
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
	
	# ///// POSITIONAL PROPERTIES /////
	
	var bound_names = ["x_minus", "x_plus", "y_minus", "y_plus", "z_minus", "z_plus"]
	
	for position in bound_names:
		
		var property_name = position + "_position"
		
		props[property_name] = {
			"name" : property_name,
			"type" : TYPE_REAL,
			"hint" : PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		}

	# ///// HOLLOW MARGIN PROPERTIES /////
	
	for margin in bound_names:
		
		var property_name = "_" + margin + "_hollow"
		
		props[property_name] = {
			"name" : "hollow_mode/" + margin + "_margin",
			"type" : TYPE_REAL,
			"hint" : PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		}
	
	return props

# Returns a set of custom properties used to tell the owner general aspects of it's
# shape, helping the owner set new properties for the next shape.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func get_shape_aspects() -> Dictionary:
	
	var aspects = {}
	
	var size = Vector3(x_minus_position + x_plus_position, 
			y_minus_position + y_plus_position, z_minus_position + z_plus_position)
	
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
		
		# If we're given an aspect, 
		x_minus_position = abs(shape_bounds.position.x)
		y_minus_position = abs(shape_bounds.position.y)
		z_minus_position = abs(shape_bounds.position.z)
		
		x_plus_position = abs(shape_bounds.end.x)
		y_plus_position = abs(shape_bounds.end.y)
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


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# MESH GENERATION


# Creates new geometry to reflect the shapes current properties, then returns it.
func update_geometry() -> OnyxMesh:
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()
	
	return build_geometry(x_minus_position, x_plus_position, y_minus_position,
			y_plus_position, z_minus_position, z_plus_position)


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:

	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()
	
#	print("[OnyxCube] - update_hollow_geometry()")
	
	var x_minus_diff = x_minus_position - _x_minus_hollow
	var x_plus_diff = x_plus_position - _x_plus_hollow
	var y_minus_diff = y_minus_position - _y_minus_hollow
	var y_plus_diff = y_plus_position - _y_plus_hollow
	var z_minus_diff = z_minus_position - _z_minus_hollow
	var z_plus_diff = z_plus_position - _z_plus_hollow
	
	return build_geometry(x_minus_diff, x_plus_diff, y_minus_diff,
			y_plus_diff, z_minus_diff, z_plus_diff)
	


# Performs the process of building a set of mesh data and returning it to the caller.
func build_geometry(x_minus : float,  x_plus : float,  y_minus : float,  y_plus : float, 
	z_minus : float,  z_plus : float):
	
#	print('trying to build geometry...')
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return
	
#	# Clamp important values
	if corner_size < 0:
		corner_size = 0
	if corner_faces < 1:
		corner_faces = 1
		
	
	var max_point = Vector3(x_plus, y_plus, z_plus)
	var min_point = Vector3(-x_minus, -y_minus, -z_minus)
	
	# Build 8 vertex points
	var top_x = Vector3(max_point.x, max_point.y, min_point.z)
	var top_xz = Vector3(max_point.x, max_point.y, max_point.z)
	var top_z = Vector3(min_point.x, max_point.y, max_point.z)
	var top = Vector3(min_point.x, max_point.y, min_point.z)
	
	var bottom_x = Vector3(max_point.x, min_point.y, min_point.z)
	var bottom_xz = Vector3(max_point.x, min_point.y, max_point.z)
	var bottom_z = Vector3(min_point.x, min_point.y, max_point.z)
	var bottom = Vector3(min_point.x, min_point.y, min_point.z)
	
	# Generate the geometry
	var new_onyx_mesh = OnyxMesh.new()
	
	# ROUNDED CORNERS
	# build the initial list of corners, positive rotation.
	var circle_points = []
	var angle_step = (PI / 2) / float(corner_faces)
	
	var current_angle = 0.0
	var end_angle = (PI / 2)
	var i = 0
	
	while i < 4:
		var point_set = []
		current_angle = (PI / 2) * i
		end_angle = (PI / 2) * (i + 1)
		
		var x = corner_size * cos(current_angle)
		var y = corner_size * sin(current_angle)
		point_set.append(Vector2(x, y))
		
		current_angle += angle_step
		
		# adds a lil minus to try and compensate for bit precision issues.
		while current_angle < end_angle - 0.00001:
			x = corner_size * cos(current_angle)
			y = corner_size * sin(current_angle)
			point_set.append(Vector2(x, y))
			
			current_angle += angle_step
		
		x = corner_size * cos(end_angle)
		y = corner_size * sin(end_angle)
		point_set.append(Vector2(x, y))
		
		circle_points.append(point_set)
		i += 1
	
	
	# EXTRUSION
	# build the initial list of vertices to be extruded.
	var extrusion_vertices = []
	
	# will make a nicer bit of code later...
	if corner_axis == CornerAxis.X:
		var corners_top = VectorUtils.vector2_to_vector3_array(circle_points[0], 'X', 'Y')
		var corners_y = VectorUtils.vector2_to_vector3_array(circle_points[1], 'X', 'Y')
		var corners_bottom = VectorUtils.vector2_to_vector3_array(circle_points[2], 'X', 'Y')
		var corners_x = VectorUtils.vector2_to_vector3_array(circle_points[3], 'X', 'Y')
		
		# top, top_z, bottom, bottom_z
		# Get the four inset vertices to position the circle points to
		var offset_top = top_z + Vector3(0, -corner_size, -corner_size)
		var offset_y = top + Vector3(0, -corner_size, corner_size)
		var offset_bottom = bottom + Vector3(0, corner_size, corner_size)
		var offset_x = bottom_z + Vector3(0, corner_size, -corner_size)
		
		# Create transforms 
		var tf_top = Transform(Basis(), offset_top)
		var tf_y = Transform(Basis(), offset_y)
		var tf_bottom = Transform(Basis(), offset_bottom)
		var tf_x = Transform(Basis(), offset_x)
		
		# Get the circle points and translate each corner set by the above offsets
		corners_top = VectorUtils.transform_vector3_array(corners_top, tf_top)
		corners_y = VectorUtils.transform_vector3_array(corners_y, tf_y)
		corners_bottom = VectorUtils.transform_vector3_array(corners_bottom, tf_bottom)
		corners_x = VectorUtils.transform_vector3_array(corners_x, tf_x)
		
		# Stack all the vertices into a single array
		var start_cap = VectorUtils.combine_arrays([corners_top, corners_y, corners_bottom, corners_x])
		
		# Project and duplicate
		var tf_end_cap = Transform(Basis(), Vector3(max_point.x - min_point.x, 0, 0)) 
		var end_cap = VectorUtils.transform_vector3_array(start_cap, tf_end_cap)
		
		# UVS
		var start_cap_uvs = []
		var end_cap_uvs = []
		
		# 0 - Proportional Overlap
		if unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
			start_cap_uvs = VectorUtils.vector3_to_vector2_array(start_cap, 'X', 'Z')
			end_cap_uvs = start_cap_uvs.duplicate()
		
		
		# 1 - Per-Face Mapping
		elif unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
			var diff = max_point - min_point
			var clamped_vs = []
			
			# for every vertex, minus it by the min and divide by the difference.
			for vertex in start_cap:
				clamped_vs.append( (vertex - min_point) / diff )
			start_cap_uvs = VectorUtils.vector3_to_vector2_array(clamped_vs, 'X', 'Z')
			
			# for every vertex, minus it by the min and divide by the difference.
#			for vertex in end_cap:
#				clamped_vs.append( (vertex - min_point) / diff )
#			end_cap_uvs = VectorUtils.vector3_to_vector2_array(clamped_vs, 'X', 'Z')
			
			for uv in start_cap_uvs:
				end_cap_uvs.append(uv * Vector2(-1.0, -1.0))
		
		
		new_onyx_mesh.add_ngon(VectorUtils.reverse_array(start_cap), [], [], start_cap_uvs, [])
		new_onyx_mesh.push_surface()
		new_onyx_mesh.add_ngon(end_cap, [], [], end_cap_uvs, [])
		new_onyx_mesh.push_surface()
		
		# used for Proportional Unwrap.
		var total_edge_length = 0.0
		
		# Build side edges
		var v_1 = 0
		while v_1 < start_cap.size():
			
			var v_2 = VectorUtils.clamp_int( (v_1 + 1), 0, (start_cap.size() - 1) )
			
			var b_1 = start_cap[v_1]
			var b_2 = start_cap[v_2]
			var t_1 = end_cap[v_1]
			var t_2 = end_cap[v_2]
			
			var normals = []
			
			# SMOOTH SHADING
			if smooth_normals == true:
				var v_0 = VectorUtils.clamp_int( (v_1 - 1), 0, (start_cap.size() - 1) )
				var v_3 = VectorUtils.clamp_int( (v_2 + 1), 0, (start_cap.size() - 1) )
				
				var b_0 = start_cap[v_0]
				var b_3 = start_cap[v_3]
				var t_0 = end_cap[v_0]
				var t_3 = end_cap[v_3]
				
				var n_0 = VectorUtils.get_triangle_normal( [b_0, t_0, b_1] )
				var n_1 = VectorUtils.get_triangle_normal( [b_1, t_1, b_2] )
				var n_2 = VectorUtils.get_triangle_normal( [b_2, t_2, b_3] )
				
				var normal_1 = (n_0 + n_1).normalized()
				var normal_2 = (n_1 + n_2).normalized()
				normals = [normal_1, normal_2, normal_2, normal_1]
				
			else:
				var normal = VectorUtils.get_triangle_normal( [b_1, t_1, b_2] )
				normals = [normal, normal, normal, normal]
				
				
			# UVS
			var uvs = []
			
			# 0 - Proportional Overlap
			if unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
				var height = (t_1 - b_1).length()
				var new_width = (t_2 - t_1).length()
				uvs = [Vector2(total_edge_length, 0.0), Vector2(total_edge_length + new_width, 0.0), 
				Vector2(total_edge_length + new_width, height), Vector2(total_edge_length, height)]
			
			# 1 - Per-Face Mapping
			elif unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
				uvs = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
			
			var vertex_set = [b_1, b_2, t_2, t_1]
			new_onyx_mesh.add_ngon(vertex_set, [], [], uvs, normals)
			
			v_1 += 1
			total_edge_length += (t_2 - t_1).length()
		
	new_onyx_mesh.push_surface()
	
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
	
	var x_minus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", 
			"restore_state", "restore_state")
			
	x_minus.control_name = 'x_minus'
	x_minus.set_type_axis(false, "modify_control", "commit_control", Vector3(-1, 0, 0))
	
	
	var x_plus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", 
			"restore_state", "restore_state")
			
	x_plus.control_name = 'x_plus'
	x_plus.set_type_axis(false, "modify_control", "commit_control", Vector3(1, 0, 0))
	
	
	var y_minus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", 
			"restore_state", "restore_state")
			
	y_minus.control_name = 'y_minus'
	y_minus.set_type_axis(false, "modify_control", "commit_control", Vector3(0, -1, 0))
	
	
	var y_plus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", 
			"restore_state", "restore_state")
			
	y_plus.control_name = 'y_plus'
	y_plus.set_type_axis(false, "modify_control", "commit_control", Vector3(0, 1, 0))
	
	
	var z_minus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", 
			"restore_state", "restore_state")
			
	z_minus.control_name = 'z_minus'
	z_minus.set_type_axis(false, "modify_control", "commit_control", Vector3(0, 0, -1))
	
	
	var z_plus = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", 
			"restore_state", "restore_state")
			
	z_plus.control_name = 'z_plus'
	z_plus.set_type_axis(false, "modify_control", "commit_control", Vector3(0, 0, 1))
	
	
	# populate the dictionary
	active_controls["x_minus"] = x_minus
	active_controls["x_plus"] = x_plus
	active_controls["y_minus"] = y_minus
	active_controls["y_plus"] = y_plus
	active_controls["z_minus"] = z_minus
	active_controls["z_plus"] = z_plus
	
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
	
#	print("[OnyxCube] ", self.get_name(), " - refresh_control_data()")
	
	var mid_x = (x_plus_position - x_minus_position) / 2
	var mid_y = (y_plus_position - y_minus_position) / 2
	var mid_z = (z_plus_position - z_minus_position) / 2

	var diff_x = abs(x_plus_position - -x_minus_position)
	var diff_y = abs(y_plus_position - -y_minus_position)
	var diff_z = abs(z_plus_position - -z_minus_position)

	active_controls["x_minus"].control_position = Vector3(-x_minus_position, mid_y, mid_z)
	active_controls["x_plus"].control_position = Vector3(x_plus_position, mid_y, mid_z)
	active_controls["y_minus"].control_position = Vector3(mid_x, -y_minus_position, mid_z)
	active_controls["y_plus"].control_position = Vector3(mid_x, y_plus_position, mid_z)
	active_controls["z_minus"].control_position = Vector3(mid_x, mid_y, -z_minus_position)
	active_controls["z_plus"].control_position = Vector3(mid_x, mid_y, z_plus_position)
	
	

# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo (AKA - When someone moves a control point)
func update_control_from_gizmo(control):
	
#	print("[OnyxCube] ", self.get_name(), " - update_control_from_gizmo(control)")
	
	var coordinate = control.control_position
	
	match control.control_name:
		'x_minus': x_minus_position = min(coordinate.x, x_plus_position) * -1
		'x_plus': x_plus_position = max(coordinate.x, -x_minus_position)
		'y_minus': y_minus_position = min(coordinate.y, y_plus_position) * -1
		'y_plus': y_plus_position = max(coordinate.y, -y_minus_position)
		'z_minus': z_minus_position = min(coordinate.z, z_plus_position) * -1
		'z_plus': z_plus_position = max(coordinate.z, -z_minus_position)
		
	refresh_control_data()
	

# Applies the current handle values to the shape attributes
func apply_control_attributes():
	
#	print("[OnyxCube] ", self.get_name(), " - apply_control_attributes()")
	
	x_minus_position = active_controls["x_minus"].control_position.x * -1
	x_plus_position = active_controls["x_plus"].control_position.x
	y_minus_position = active_controls["y_minus"].control_position.y * -1
	y_plus_position = active_controls["y_plus"].control_position.y
	z_minus_position = active_controls["z_minus"].control_position.z * -1
	z_plus_position = active_controls["z_plus"].control_position.z

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_control_data():
	
#	print("[OnyxCube] ", self.get_name(), " - balance_control_data()")
	
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
# BASE UI FUNCTIONS

func editor_select():
	pass

func editor_deselect():
	pass


# ////////////////////////////////////////////////////////////
# PROPERTY UPDATERS


