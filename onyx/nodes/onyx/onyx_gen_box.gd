tool
extends "res://addons/onyx/nodes/onyx/onyx_generator.gd"

# /////////////////////////////////////////////////////////////////////////////
# INFO
# A generator for use with OnyxShape.
# Generates a box-like shape which has a surface-like interaction 

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
	
	# All faces are unwrapped to match world space, will overlap UV space
	PROPORTIONAL_OVERLAP, 		
	# Every face is mapped 1:1 within the bounds of UV space
	PER_FACE_MAPPING,			
}


# ////////////////////////////////////
# PUBLIC

# The current origin mode set.
export(OriginPosition) var origin_mode = OriginPosition.BASE


# SHAPE PROPERTIES /////

# Exported variables representing all usable handles for re-shaping the mesh.
var x_plus_position = 0.5
var x_minus_position = 0.5

var y_plus_position = 1.0
var y_minus_position = 0.0

var z_plus_position = 0.5
var z_minus_position = 0.5


# Used to subdivide the mesh to help ease CSG boolean inaccuracies.
export(Vector3) var subdivisions = Vector3(1, 1, 1)


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
	
#	print("[OnyxBox] - ", self, "_set()", property, value)
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
		
		"subdivisions":
			if value.x < 1:
				value.x = 1
			if value.y < 1:
				value.y = 1
			if value.z < 1:
				value.z = 1
				
			subdivisions = value
		
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
		
		# # ORIGIN SETTINGS /////
		
		"origin_mode" : {	
		
			"name" : "origin_mode",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Center, Base, Bottom Corner"
		},
		
		# UV UNWRAP TYPES /////
		
		"unwrap_method" : {	
		
			"name" : "uv_options/unwrap_method",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Proportional Overlap, Per-Face Mapping"
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
	
#	print('trying to generate geometry...')
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return
	
#	print("[OnyxCube] - build_geometry()")
	
	var maxPoint = Vector3(x_plus, y_plus, z_plus)
	var minPoint = Vector3(-x_minus, -y_minus, -z_minus)
	
	# Generate the geometry
	var new_onyx_mesh = OnyxMesh.new()
	var mesh_factory = OnyxMeshFactory.new()
	
	# Build 8 vertex points
	var top_x = Vector3(maxPoint.x, maxPoint.y, minPoint.z)
	var top_xz = Vector3(maxPoint.x, maxPoint.y, maxPoint.z)
	var top_z = Vector3(minPoint.x, maxPoint.y, maxPoint.z)
	var top = Vector3(minPoint.x, maxPoint.y, minPoint.z)
	
	var bottom_x = Vector3(maxPoint.x, minPoint.y, minPoint.z)
	var bottom_xz = Vector3(maxPoint.x, minPoint.y, maxPoint.z)
	var bottom_z = Vector3(minPoint.x, minPoint.y, maxPoint.z)
	var bottom = Vector3(minPoint.x, minPoint.y, minPoint.z)
	
	# Build the 6 vertex Lists
	var vec_x_minus = [bottom, top, top_z, bottom_z]
	var vec_x_plus = [bottom_xz, top_xz, top_x, bottom_x]
	var vec_y_minus = [bottom_x, bottom, bottom_z, bottom_xz]
	var vec_y_plus = [top, top_x, top_xz, top_z]
	var vec_z_minus = [bottom_x, top_x, top, bottom]
	var vec_z_plus = [bottom_z, top_z, top_xz, bottom_xz]
	
	var surfaces = []
	surfaces.append( mesh_factory.internal_build_surface(bottom, top_z, top, bottom_z, 
			Vector2(subdivisions.z, subdivisions.y), 0) )
	surfaces.append( mesh_factory.internal_build_surface(bottom_xz, top_x, top_xz, bottom_x, 
			Vector2(subdivisions.z, subdivisions.y), 0) )
	
	surfaces.append( mesh_factory.internal_build_surface(bottom_x, bottom_z, bottom, bottom_xz, 
			Vector2(subdivisions.z, subdivisions.x), 0) )
	surfaces.append( mesh_factory.internal_build_surface(top, top_xz, top_x, top_z, 
			Vector2(subdivisions.z, subdivisions.x), 0) )
	
	surfaces.append( mesh_factory.internal_build_surface(bottom_x, top, top_x, bottom, 
			Vector2(subdivisions.x, subdivisions.y), 0) )
	surfaces.append( mesh_factory.internal_build_surface(bottom_z, top_xz, top_z, bottom_xz, 
			Vector2(subdivisions.x, subdivisions.y), 0) )
	
	var i = 0
	
	for surface in surfaces:
		
		var vertices = []
		for quad in surface:
			for vertex in quad[0]:
				vertices.append(vertex)
		
		for quad in surface:
			
			# UV UNWRAPPING
			
			# 1:1 Overlap is Default
			var uvs = quad[3]
			
			# Proportional Overlap
			# Try and work out how to properly reorient the UVS later...
			if unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
				if i == 0 || i == 1:
					uvs = VectorUtils.vector3_to_vector2_array(quad[0], 'X', 'Z')
					uvs = [uvs[2], uvs[3], uvs[0], uvs[1]]
#					if i == 0:
#						uvs = VectorUtils.reverse_array(uvs)
				elif i == 2 || i == 3:
					uvs = VectorUtils.vector3_to_vector2_array(quad[0], 'Y', 'X')
					uvs = [uvs[2], uvs[3], uvs[0], uvs[1]]
					#uvs = VectorUtils.reverse_array(uvs)
				elif i == 4 || i == 5:
					uvs = VectorUtils.vector3_to_vector2_array(quad[0], 'Z', 'X')
					uvs = [uvs[2], uvs[3], uvs[0], uvs[1]]
#					if i == 5:
#						uvs = VectorUtils.reverse_array(uvs)

				
#				print(uvs)
			
			# Island Split - UV split up into two thirds.
#			elif unwrap_method == UnwrapMethod.ISLAND_SPLIT:
#
#				# get the max and min
#				var surface_range = VectorUtils.get_vector3_ranges(vertices)
#				var max_point = surface_range['max']
#				var min_point = surface_range['min']
#				var diff = max_point - min_point
#
#				var initial_uvs = []
#
#				if i == 0 || i == 1:
#					initial_uvs = VectorUtils.vector3_to_vector2_array(quad[0], 'X', 'Z')
#				elif i == 2 || i == 3:
#					initial_uvs = VectorUtils.vector3_to_vector2_array(quad[0], 'Y', 'X')
#				elif i == 4 || i == 5:
#					initial_uvs = VectorUtils.vector3_to_vector2_array(quad[0], 'Z', 'X')
#
#				for uv in initial_uvs:
#					uv
			
			new_onyx_mesh.add_ngon(quad[0], quad[1], quad[2], uvs, quad[4])
			
		i += 1
	
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



