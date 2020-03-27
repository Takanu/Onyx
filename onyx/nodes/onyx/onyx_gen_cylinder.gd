tool
extends "res://addons/onyx/nodes/onyx/onyx_generator.gd"

# /////////////////////////////////////////////////////////////////////////////
# INFO
# A generator for use with OnyxShape.
# Generates a box-like shape with rounded like corners.  It has a surface-like 
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
var sides = 12
var rings = 1

# The height values for the top and bottom of the cylinder.
var height_max = 1
var height_min = 0

var x_width = 0.5
var z_width = 0.5

# If true, the X and Z width will always equal each other.
var keep_width_proportional = false



# HOLLOW PROPERTIES /////

# Used to determine how much the hollow faces move away from the
# sides of the current box.
var _height_max_hollow = 0.2
var _height_min_hollow = 0.2

var _x_width_hollow = 0.2
var _z_width_hollow = 0.2


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
		
		# SHAPE PROPERTIES /////
		
		"sides":
			if value < 3:
				value = 3
			sides = value
		
		"rings":
			if value < 1:
				value = 1
			rings = value
		
		"height_max":
			if value < 0:
				value = 0
				
			height_max = value
		
		"height_min":
			if value < 0:
				value = 0
			height_min = value
		
		"x_width":
			if value < 0:
				value = 0
				
			if keep_width_proportional == true:
				z_width = value
				
			x_width = value
		
		"z_width":
			if value < 0:
				value = 0
				
			if keep_width_proportional == true:
				x_width = value
				
			z_width = value
		
		"keep_width_proportional":
			keep_width_proportional = value
			_update_origin_mode()
			balance_control_data()
		
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
		
		# UVS / NORMALS /////
		
		"unwrap_method":
			unwrap_method = value
		
		"smooth_normals":
			smooth_normals = value
		
		# HOLLOW MARGINS /////
		
		"_height_max_hollow":
			_height_max_hollow = value
		
		"_height_min_hollow":
			_height_min_hollow = value
		
		"_x_width_hollow":
			_x_width_hollow = value
		
		"_z_width_hollow":
			_z_width_hollow = value
		
	
	_process_property_update()
	return true



# Returns the list of custom shape properties that an owner should save and display.
func get_shape_properties() -> Dictionary:

	var props = [

		# ORIGIN SETTINGS /////
		{	
			"name" : "origin_mode",
			"private_name" : "origin_mode",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Center, Base, Bottom Corner",
		},
		
		# SHAPE PROPERTIES /////
		
		{	
			"name" : "sides",
			"private_name" : "sides",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		{	
			"name" : "rings",
			"private_name" : "rings",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		
		# UV / NORMALS /////
		
		{	
			"name" : "uv_options/unwrap_method",
			"private_name" : "unwrap_method",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Proportional Overlap, Per-Face Mapping",
		},
		
		{
			"name" : "uv_options/smooth_normals",
			"private_name" : "smooth_normals",
			"type" : TYPE_BOOL,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
	]

	# ///// POSITIONAL PROPERTIES /////
	
	var bound_names = ["height_max", "height_min", "x_width", "z_width"]

	for name in bound_names:

		var property_name = name

		props.append( {
			"name" : property_name,
			"private_name" : property_name,
			"type" : TYPE_REAL,
			"hint" : PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		} )

	# ///// HOLLOW MARGIN PROPERTIES /////

	for name in bound_names:

		var property_name = "_" + name + "_hollow"

		props.append( {
			"name" : "hollow_mode/" + name + "_margin",
			"private_name" : property_name,
			"type" : TYPE_REAL,
			"hint" : PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		} )
		
	return props


# Returns a set of custom properties used to tell the owner general aspects of it's
# shape, helping the owner set new properties for the next shape.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func get_shape_aspects() -> Dictionary:
	
	var aspects = {}
	
	var size = Vector3(x_width * 2, height_max + height_min, z_width * 2)
	
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
		height_max = abs(shape_bounds.size.y)
		height_min = abs(0)
		x_width = abs(shape_bounds.size.x / 2)
		z_width = abs(shape_bounds.size.z / 2)
	
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
	
	return build_geometry(height_max, height_min, x_width, z_width)


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:

	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()
	
#	print("[OnyxCube] - update_hollow_geometry()")

	print(_height_max_hollow, _height_min_hollow, _x_width_hollow, _z_width_hollow)
	
	var height_max_diff = height_max - _height_max_hollow
	var height_min_diff = height_min - _height_min_hollow
	var x_width_diff = x_width - _x_width_hollow
	var z_width_diff = z_width - _z_width_hollow
	
	return build_geometry(height_max_diff, height_min_diff, 
			x_width_diff, z_width_diff)
	


# Performs the process of building a set of mesh data and returning it to the caller.
func build_geometry(geom_height_max : float,  geom_height_min : float,  
		x_size : float,  z_size : float):
	
#	print('trying to build geometry...')
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return

	var new_onyx_mesh = OnyxMesh.new()

	var total_height = geom_height_max - -geom_height_min
	var position = Vector3(0, 0, 0)
	match origin_mode:
		OriginPosition.CENTER:
			position = Vector3(0, -geom_height_min, 0)
		OriginPosition.BASE:
			position = Vector3(0, -geom_height_min, 0)
		OriginPosition.BASE_CORNER:
			position = Vector3(x_size, -geom_height_min, z_size)
	
	# generate the initial circle as a series of 2D points
	var angle_step = (2.0 * PI) / sides
	var current_angle = 0.0
	
	var circle_points = []
	
	while current_angle < 2 * PI:
		
		# get coordinates
		var x = x_size * cos(current_angle)
		var y = z_size * sin(current_angle)
		circle_points.append(Vector2(x, y))
		
		current_angle += angle_step
	

	# make the points given three-dimensional.
	var start_vertices = []
	var start_point_normal = Vector3(0, 0, 1)
	for point in circle_points:
		start_vertices.append(Vector3(point.x, point.y, 0))
	
	var base_vertices = []
	var extrusion_axis = Vector3(0, 1, 0)
	
	
	# Build a basis and rotate it to the normal we desire.
	var dot = start_point_normal.dot(extrusion_axis)
	var cross = start_point_normal.cross(extrusion_axis).normalized()
	
	#print("DOT/CROSS: ", dot, cross)
	
	# If the face angle is where we want it, do nothing.
	if dot == 1 || dot == -1:
		#print("No need to rotate!") 
		for vertex in start_vertices:
			base_vertices.append(vertex + position)

	# Otherwise rotate it!
	else:
		#("Rotating!")
		var matrix = Basis()
		matrix = matrix.rotated(cross, PI*((dot + 1) / 2))
		
		for vertex in start_vertices:
			var t_vertex = matrix.xform(vertex)
			base_vertices.append(t_vertex + position)
			

	# based on the number of rings, build the faces.
	var extrusion_step = total_height / rings
	var base_extrusion_depth = Vector3()
	var distance_vec = extrusion_axis * extrusion_step
	var face_count = 0
	
	for i in rings:
		
		# Used for Proportional Unwrap methods.
		var total_edge_length = 0.0
		
		# go roooound the extrusion
		for v_1 in base_vertices.size():
			
			# X--------X  t_1   t_2
			# |        |
			# |        |
			# |        |
			# X--------X  b_1   b_2
			
			# Get positions ahead and behind the set we plan on looking at for smooth normals
			var v_0 = VectorUtils.clamp_int(v_1 - 1, 0, base_vertices.size() - 1)
			var v_2 = VectorUtils.clamp_int(v_1 + 1, 0, base_vertices.size() - 1)
			var v_3 = VectorUtils.clamp_int(v_1 + 2, 0, base_vertices.size() - 1)

			var b_0 = base_vertices[v_0]
			var b_1 = base_vertices[v_1]
			var b_2 = base_vertices[v_2]
			var b_3 = base_vertices[v_0]

			b_1 += base_extrusion_depth
			b_2 += base_extrusion_depth
			var t_1 = b_1 + distance_vec
			var t_2 = b_2 + distance_vec

			var vertices = [b_1, t_1, t_2, b_2]
			var tangents = []
			var normals = []
			
			# NORMAL TYPES
			if smooth_normals == true:
				var n_1 = VectorUtils.get_triangle_normal([b_0, b_1, t_1])
				var n_2 = VectorUtils.get_triangle_normal([b_2, b_2, b_3])
				normals = [n_1, n_1, n_2, n_2]
			else:
				var normal = VectorUtils.get_triangle_normal([b_1, t_1, b_2])
				normals = [normal, normal, normal, normal]
				
			var uvs = []

			# UNWRAP METHOD 1 - PROPORTIONAL OVERLAP
			# Unwraps evenly across all rings, scaling based on vertex position.
			if unwrap_method == 0:
				var base_width = (b_2 - b_1).length()
				var base_height = (t_1 - b_1).length()
				
				uvs = [Vector2(total_edge_length, b_1.y), Vector2(total_edge_length, t_1.y), 
				Vector2(total_edge_length + base_width, t_1.y), Vector2(total_edge_length + base_width, b_1.y)]
				
				total_edge_length += base_width
				
			# UNWRAP METHOD 1 - PROPORTIONAL OVERLAP SEGMENTS
			# Proportionally unwraps horizontally, but applies the same unwrap coordinates to all rings.
			elif unwrap_method == 1:
				var base_width = (b_2 - b_1).length()
				var base_height = (t_1 - b_1).length()
				
				uvs = [Vector2(total_edge_length, 0.0), Vector2(total_edge_length, base_height), 
				Vector2(total_edge_length + base_width, base_height), Vector2(total_edge_length + base_width, 0.0)]
				
				total_edge_length += base_width
				
			# UNWRAP METHOD 0 - Per-Face Mapping
			elif unwrap_method == 2:
				uvs = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]
				
			# ADD FACE
			new_onyx_mesh.add_ngon(vertices, [], tangents, uvs, normals)
			face_count += 1
			

		base_extrusion_depth += distance_vec
	
	# PUSH
	new_onyx_mesh.push_surface()
		
	# now render the top and bottom caps
	var v_cap_bottom = []
	var v_cap_top = []
	var total_extrusion_vec = extrusion_axis * total_height
	
	for i in base_vertices.size():
		
		var vertex = base_vertices[i]
		v_cap_bottom.append( vertex )
		v_cap_top.append( vertex + total_extrusion_vec )
		
	v_cap_top.invert()
	
	#var bottom_normals = [extrusion_axis.inverse(), extrusion_axis.inverse(), extrusion_axis.inverse(), extrusion_axis.inverse()]
	#var top_normals = [extrusion_axis, extrusion_axis, extrusion_axis, extrusion_axis]
	
	# UVS
	var utils = VectorUtils.new()
	var top_bounds = utils.get_vector3_ranges(v_cap_top)
	var bottom_bounds = utils.get_vector3_ranges(v_cap_bottom)
	
	var top_range = top_bounds['max'] - top_bounds['min']
	var bottom_range = bottom_bounds['max'] - bottom_bounds['min']
	
	var top_uvs = []
	var bottom_uvs = []
	
		
	# UNWRAP METHOD - PROPORTIONAL OVERLAP AND SEGMENTS
	# Unwraps evenly across all rings, scaling based on vertex position.
	if unwrap_method == 0 || unwrap_method == 1:
		for vector in v_cap_top:
			top_uvs.append(Vector2(vector.x, vector.z))
		for vector in v_cap_bottom:
			bottom_uvs.append(Vector2(vector.x, vector.z))
			
			
	# UNWRAP METHOD - Per-Face Mapping
	elif unwrap_method == 2:
		for vector in v_cap_top:
			var uv = Vector2(vector.x / top_range.x, vector.z / top_range.z)
			uv = uv + Vector2(0.5, 0.5)
			top_uvs.append(uv)
		
		for vector in v_cap_bottom:
			var uv = Vector2(vector.x / bottom_range.x, vector.z / bottom_range.z)
			uv = uv + Vector2(0.5, 0.5)
			bottom_uvs.append(uv)
		
		
	new_onyx_mesh.add_ngon(v_cap_top, [], [], top_uvs, [])
	new_onyx_mesh.push_surface()
	new_onyx_mesh.add_ngon(v_cap_bottom, [], [], bottom_uvs, [])
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
	if acv_controls.size() == 0:
		return
	
#	print("[OnyxGenerator] ", self.name, " - _update_origin_mode()")
	
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
	var mid_height = height_max - height_min
		
	match origin_mode:
		OriginPosition.CENTER:
			diff = Vector3(0, mid_height / 2, 0)
		
		OriginPosition.BASE:
			diff = Vector3(0, -height_min, 0)
		
		OriginPosition.BASE_CORNER:
			diff = Vector3(0, -height_min, 0)
	
	
	_process_origin_move(diff)

# Returns the origin point that the hollow object should be set at.
func get_hollow_origin():

	match origin_mode:
		OriginPosition.CENTER:
			return Vector3(0, 0, 0)
		
		OriginPosition.BASE:
			return Vector3(0, 0, 0)
		
		OriginPosition.BASE_CORNER:
			return Vector3(_x_width_hollow, 0, _z_width_hollow)
	
	


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
	
	var height_max = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	height_max.control_name = 'height_max'
	height_max.set_type_axis(false, "modify_control", "commit_control", Vector3(0, 1, 0))
	
	var height_min = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	height_min.control_name = 'height_min'
	height_min.set_type_axis(false, "modify_control", "commit_control", Vector3(0, -1, 0))
	
	var x_width = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	x_width.control_name = 'x_width'
	x_width.set_type_axis(false, "modify_control", "commit_control", Vector3(1, 0, 0))
	
	var z_width = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	z_width.control_name = 'z_width'
	z_width.set_type_axis(false, "modify_control", "commit_control", Vector3(0, 0, 1))
	
	# populate the dictionary
	acv_controls["height_max"] = height_max
	acv_controls["height_min"] = height_min
	acv_controls["x_width"] = x_width
	acv_controls["z_width"] = z_width
	
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
	
#	print("[OnyxCube] ", self.get_name(), " - refresh_control_data()")
	
	var height_mid = (height_max - height_min) / 2
	
	match origin_mode:
		OriginPosition.CENTER:
			acv_controls["height_max"].control_pos = Vector3(0, height_max, 0)
			acv_controls["height_min"].control_pos = Vector3(0, -height_min, 0)
			acv_controls["x_width"].control_pos = Vector3(x_width, 0, 0)
			acv_controls["z_width"].control_pos = Vector3(0, 0, z_width)
			
		OriginPosition.BASE:
			acv_controls["height_max"].control_pos = Vector3(0, height_max, 0)
			acv_controls["height_min"].control_pos = Vector3(0, -height_min, 0)
			acv_controls["x_width"].control_pos = Vector3(x_width, height_mid, 0)
			acv_controls["z_width"].control_pos = Vector3(0, height_mid, z_width)
			
		OriginPosition.BASE_CORNER:
			acv_controls["height_max"].control_pos = Vector3(x_width, height_max, z_width)
			acv_controls["height_min"].control_pos = Vector3(x_width, -height_min, z_width)
			acv_controls["x_width"].control_pos = Vector3(x_width * 2, height_mid, z_width)
			acv_controls["z_width"].control_pos = Vector3(x_width, height_mid, z_width * 2)

	

# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo (AKA - When someone moves a control point)
func update_control_from_gizmo(control):
	
#	print("[OnyxCube] ", self.get_name(), " - update_control_from_gizmo(control)")
	
	var coordinate = control.control_pos
		
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
		
	refresh_control_data()
	

# Applies the current handle values to the shape attributes
func apply_control_attributes():
	
#	print("[OnyxCube] ", self.get_name(), " - apply_control_attributes()")
	
	# If the base corner is the current origin, we need to deal with widths differently.
	if origin_mode == OriginPosition.BASE_CORNER:
		height_max = acv_controls["height_max"].control_pos.y
		height_min = acv_controls["height_min"].control_pos.y * -1
		x_width = acv_controls["x_width"].control_pos.x / 2
		z_width = acv_controls["z_width"].control_pos.z / 2
		
	else:
		height_max = acv_controls["height_max"].control_pos.y
		height_min = acv_controls["height_min"].control_pos.y * -1
		x_width = acv_controls["x_width"].control_pos.x
		z_width = acv_controls["z_width"].control_pos.z

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_control_data():
	
#	print("[OnyxCube] ", self.get_name(), " - balance_control_data()")
	
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
# BASE UI FUNCTIONS

func editor_select():
	pass

func editor_deselect():
	pass



