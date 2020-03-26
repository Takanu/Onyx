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


# ////////////////////////////////////
# PUBLIC

# The current origin mode set.
var origin_mode = OriginPosition.BASE


# SHAPE PROPERTIES /////

# The number of X-Z edge loops that make up the sphere.
var segments = 12
# The number of Y-aligned loops that make up the sphere.
var rings = 6

# The height of the sphere.
var height = 1

# The X width of the sphere.
var x_width = 0.5

# The Z width of the sphere.
var z_width = 0.5

# If true, the X, Y and Z width will always equal each other.
var keep_shape_proportional = false



# HOLLOW PROPERTIES /////

# Used to determine how much the hollow faces move away from the
# sides of the current box.
var _height_hollow = 0.2
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
		
		"segments":
			if value < 3:
				value = 3
			segments = value
		
		"rings":
			if value < 3:
				value = 3
			rings = value
		
		"height":
			if value < 0:
				value = 0
			
			if keep_shape_proportional == true:
				x_width = value
				z_width = value

			height = value
		
		"x_width":
			if value < 0:
				value = 0
				
			if keep_shape_proportional == true:
				x_width = value
				z_width = value
				
			x_width = value
		
		"z_width":
			if value < 0:
				value = 0
				
			if keep_shape_proportional == true:
				x_width = value
				z_width = value

			z_width = value
		
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
		
		"_height_hollow":
			_height_hollow = value
		
		"_x_width_hollow":
			_x_width_hollow = value
		
		"_z_width_hollow":
			_z_width_hollow = value
		
	
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
		
		"segments" : {	
		
			"name" : "segments",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"rings" : {	
		
			"name" : "rings",
			"type" : TYPE_INT,
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

	# ///// POSITIONAL PROPERTIES /////
	
	var bound_names = ["height", "x_width", "z_width"]

	for name in bound_names:

		var property_name = name

		props[property_name] = {
			"name" : property_name,
			"type" : TYPE_REAL,
			"hint" : PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		}

	# ///// HOLLOW MARGIN PROPERTIES /////

	for name in bound_names:

		var property_name = "_" + name + "_hollow"

		props[property_name] = {
			"name" : "hollow_mode/" + name + "_margin",
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
	
	var size = Vector3(x_width * 2, height * 2, z_width * 2)
	
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
		height = abs(shape_bounds.size.y / 2)
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
	
	return build_geometry(height, x_width, z_width)


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:

	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()
	
#	print("[OnyxCube] - update_hollow_geometry()")
	
	var height_diff = height - _height_hollow
	var x_width_diff = x_width - _x_width_hollow
	var z_width_diff = z_width - _z_width_hollow
	
	return build_geometry(height_diff, x_width_diff, z_width_diff)
	


# Performs the process of building a set of mesh data and returning it to the caller.
func build_geometry(geom_height : float,  geom_x_size : float,  
		geom_z_size : float):
	
#	print('trying to build geometry...')
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return

	var new_onyx_mesh = OnyxMesh.new()

	var position = Vector3(0, 0, 0)
	match origin_mode:
		OriginPosition.CENTER:
			position = Vector3(0, 0, 0)
		OriginPosition.BASE:
			position = Vector3(0, geom_height / 2, 0)
		OriginPosition.BASE_CORNER:
			position = Vector3(geom_x_size / 2, geom_height / 2, geom_z_size / 2)
	
	# The increments that vertex plotting will be broken up into
	var deltaTheta = PI/rings
	var deltaPhi = 2*PI/segments
	
	# The variables used to step through and plot points.
	var theta1 = 0.0
	var theta2 = deltaTheta
	var phi1 = 0.0
	var phi2 = deltaPhi
	
#	print([theta1, theta2, phi1, phi2])
	
	var ring = 0
	while ring < rings:
		if ring != 0:
			theta1 += deltaTheta
			theta2 += deltaTheta
			
		var point = 0
		phi1 = 0.0
		phi2 = deltaPhi
			
#		print("thetas: ", theta1, theta2)
#		print("NEW RING===========")
		
		while point <= segments - 1:
			if point != 0:
				phi1 += deltaPhi
				phi2 += deltaPhi
				
			#phi2   phi1
			# |      |
			# 2------1 -- theta1
			# |\ _   |
			# |    \ |
			# 3------4 -- theta2
			#

			# Vertices
			var vertex1 = Vector3(sin(theta2) * cos(phi2) * (geom_x_size/2),  
					cos(theta2) * (geom_height/2),  
					sin(theta2) * sin(phi2) * (geom_z_size/2))
			
			var vertex2 = Vector3(sin(theta1) * cos(phi2) * (geom_x_size/2),  
					cos(theta1) * (geom_height/2),  
					sin(theta1) * sin(phi2) * (geom_z_size/2))
			
			var vertex3 = Vector3(sin(theta1) * cos(phi1) * (geom_x_size/2),  
					cos(theta1) * (geom_height/2),  
					sin(theta1) * sin(phi1) * (geom_z_size/2))
			
			var vertex4 = Vector3(sin(theta2) * cos(phi1) * (geom_x_size/2),  
					cos(theta2) * (geom_height/2),  
					sin(theta2) * sin(phi1) * (geom_z_size/2))
			
			vertex1 += position
			vertex2 += position
			vertex3 += position
			vertex4 += position
			
			# UV MAPPING
			var uvs = [Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]
			
			# NORMAL MAPPING
			var normals = []
			
			# If we have smooth normals, we need extra points of detail
			if smooth_normals == true:
				# Get the right circle positions \o/
				var theta0 = theta1 - deltaTheta
				var theta3 = theta2 + deltaTheta
				var phi0 = phi1 - deltaPhi
				var phi3 = phi2 + deltaPhi
				
#				if point == segments - 1:
#					phi3 = deltaPhi
#					phi2 = 0
				
#				if ring == 0 || ring == height_segments:
#					theta0 = VectorUtils.clamp_int( (theta1 + PI), 0, PI * 2)
#					theta3 = VectorUtils.clamp_int( (theta2 + PI), 0, PI * 2)
					
#				print("phis - ", phi0, " ", phi1, " ", phi2, " ", phi3)

				#phi2   phi1
				# |      |
				# 2------1 -- theta1
				# |\ _   |
				# |    \ |
				# 3------4 -- theta2
				#
				
				# BUILD EXTRA POINTS
				var up_1 = Vector3(sin(theta0) * cos(phi1) * (geom_x_size/2),  
						cos(theta0) * (geom_height/2),  
						sin(theta0) * sin(phi1) * (geom_z_size/2))

				var up_2 = Vector3(sin(theta0) * cos(phi2) * (geom_x_size/2),  
						cos(theta0) * (geom_height/2),  
						sin(theta0) * sin(phi2) * (geom_z_size/2))

				var left_1 = Vector3(sin(theta1) * cos(phi3) * (geom_x_size/2),  
						cos(theta1) * (geom_height/2),  
						sin(theta1) * sin(phi3) * (geom_z_size/2))

				var left_2 = Vector3(sin(theta2) * cos(phi3) * (geom_x_size/2),  
						cos(theta2) * (geom_height/2),  
						sin(theta2) * sin(phi3) * (geom_z_size/2))

				var right_1 = Vector3(sin(theta1) * cos(phi0) * (geom_x_size/2),  
						cos(theta1) * (geom_height/2),  
						sin(theta1) * sin(phi0) * (geom_z_size/2))

				var right_2 = Vector3(sin(theta2) * cos(phi0) * (geom_x_size/2),  
						cos(theta2) * (geom_height/2),  
						sin(theta2) * sin(phi0) * (geom_z_size/2))

				var down_1 = Vector3(sin(theta3) * cos(phi1) * (geom_x_size/2),  
						cos(theta3) * (geom_height/2),  
						sin(theta3) * sin(phi1) * (geom_z_size/2))

				var down_2 = Vector3(sin(theta3) * cos(phi2) * (geom_x_size/2),  
						cos(theta3) * (geom_height/2),  
						sin(theta3) * sin(phi2) * (geom_z_size/2))

				# 	      u2     u1
				#   N2-0  | N1-0 |  N0-0
				#         |      | 
				# l1------2------1------r1
				#   N2-1  | N1-1 |  N0-1
				#         |      |
				# l2------3------4------r2
				#   N2-2  | N1-2 |  N0-2
				#         |      |
				
				# GET NORMALS
				var n_0_0 = VectorUtils.get_triangle_normal([vertex1, up_1, right_1])
				var n_1_0 = VectorUtils.get_triangle_normal([vertex2, up_2, vertex1])
				var n_2_0 = VectorUtils.get_triangle_normal([left_1, up_2, vertex2])
				
				var n_0_1 = VectorUtils.get_triangle_normal([vertex4, vertex1, right_2])
				var n_1_1 = VectorUtils.get_triangle_normal([vertex3, vertex2, vertex4])
				var n_2_1 = VectorUtils.get_triangle_normal([left_2, vertex2, vertex3])
				
				var n_0_2 = VectorUtils.get_triangle_normal([down_1, vertex4, right_2])
				var n_1_2 = VectorUtils.get_triangle_normal([down_2, vertex3, vertex4])
				var n_2_2 = VectorUtils.get_triangle_normal([left_2, vertex3, down_2])
				
				# COMBINE FOR EACH VERTEX
				var normal_1 = (n_0_0 + n_1_0 + n_0_1 + n_1_1).normalized()
				var normal_2 = (n_1_0 + n_2_0 + n_1_1 + n_2_1).normalized()
				var normal_3 = (n_1_1 + n_2_1 + n_1_2 + n_2_2).normalized()
				var normal_4 = (n_0_1 + n_1_1 + n_0_2 + n_1_2).normalized()
				
				normals = [normal_1, normal_2, normal_3, normal_4]
#				print(normals)
#				if point == 0 || point == segments - 1:
#					print(normals)
					
			else:
				var normal = VectorUtils.get_triangle_normal([vertex3, vertex2, vertex4])
				normals = [normal, normal, normal, normal]
			
			# CAP RENDERING
			if ring == -1:
				uvs = [Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(1.0, 1.0)]
				normals.remove(1)
				new_onyx_mesh.add_tri([vertex1, vertex3, vertex4], [], [], uvs, normals)
			
			if ring == rings:
				uvs = [Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(1.0, 1.0)]
				normals.remove(3)
				new_onyx_mesh.add_tri([vertex3, vertex1, vertex2], [], [], uvs, normals)
			
			else:
				new_onyx_mesh.add_ngon([vertex1, vertex2, vertex3, vertex4], [], [], uvs, normals)
				
			point += 1
			
		ring += 1
	
	
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
	
	# redundant, keeping it here for structural reasons.
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
	
	var height = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	height.control_name = 'height'
	height.set_type_axis(false, "modify_control", "commit_control", Vector3(0, 1, 0))
	
	var x_width = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	x_width.control_name = 'x_width'
	x_width.set_type_axis(false, "modify_control", "commit_control", Vector3(1, 0, 0))
	
	var z_width = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	z_width.control_name = 'z_width'
	z_width.set_type_axis(false, "modify_control", "commit_control", Vector3(0, 0, 1))

	# populate the dictionary
	acv_controls["height"] = height
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
	
	match origin_mode:
		OriginPosition.CENTER:
			acv_controls["height"].control_pos = Vector3(0, height / 2, 0)
			acv_controls["x_width"].control_pos = Vector3(x_width / 2, 0, 0)
			acv_controls["z_width"].control_pos = Vector3(0, 0, z_width / 2)
			
		OriginPosition.BASE:
			acv_controls["height"].control_pos = Vector3(0, height, 0)
			acv_controls["x_width"].control_pos = Vector3(x_width / 2, height / 2, 0)
			acv_controls["z_width"].control_pos = Vector3(0, height / 2, z_width / 2)
			
		OriginPosition.BASE_CORNER:
			acv_controls["height"].control_pos = Vector3(x_width / 2, 
					height, z_width / 2)
			acv_controls["x_width"].control_pos = Vector3(x_width, 
					height / 2, z_width / 2)
			acv_controls["z_width"].control_pos = Vector3(x_width / 2, 
					height / 2, z_width)


	

# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo (AKA - When someone moves a control point)
func update_control_from_gizmo(control):
	
#	print("[OnyxCube] ", self.get_name(), " - update_control_from_gizmo(control)")
	
	var coordinate = control.control_pos
		
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
		
	refresh_control_data()
	

# Applies the current handle values to the shape attributes
func apply_control_attributes():
	
	if origin_mode == OriginPosition.CENTER:
		height = acv_controls["height"].control_pos.y * 2
		x_width = acv_controls["x_width"].control_pos.x * 2
		z_width = acv_controls["z_width"].control_pos.z * 2

	if origin_mode == OriginPosition.BASE:
		height = acv_controls["height"].control_pos.y
		x_width = acv_controls["x_width"].control_pos.x * 2
		z_width = acv_controls["z_width"].control_pos.z * 2

	if origin_mode == OriginPosition.BASE_CORNER:
		height = acv_controls["height"].control_pos.y
		x_width = acv_controls["x_width"].control_pos.x
		z_width = acv_controls["z_width"].control_pos.z

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