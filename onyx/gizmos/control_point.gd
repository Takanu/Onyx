tool
extends Resource

# ////////////////////////////////////////////////////////////
# INFO
# A delegate class designed to represent a specific control point for a gizmo.
# A control point can represent one or more handles depending on the Display mode it is in.

# Will also handle callbacks and other features between Onyx types and the Gizmo sub-class.


# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")


# ////////////////////////////////////////////////////////////
# PROPERTIES

# An optional name of the control point, used for sorting purposes.
var control_name: String = ""

# The position of the control point.  This is not necessarily the same as the handles that this object renders.
var control_position: Vector3 = Vector3(0, 0, 0)

# (Optional) The rotation of the control point.  Not all control points will need to store rotation data.
var control_rotation: Vector3 = Vector3(0, 0, 0)

# (Optional) The scale of the control point.  Not all control points will need to store scale data.
var control_scale: Vector3 = Vector3(1, 1, 1)

# The previously recorded position.  This can only be accessed while the point is being moved.
var control_transform_hold = {}

# If false, the Gizmo will not render this point.
var is_control_visible: bool = true


# ////////////////////////////////////////////////////////////
# DISPLAY
# The representation and interaction types that a control point can have.
# FREE - A single handle that can be dragged and moved freely in 3D space, with respect to the camera projection.
# AXIS - A single handle that aligns it's movement to a specific set of axes.
# PLANE - A single handle that aligns it's movement to an infinite plane in 3D space.
# TRANSLATE - A set of three handles that manipulate the class translation in all three global axes.
# ROTATE - A set of three handles that manipulate the class rotation in all three global axes.
# SCALE - A set of three handles that manipulate the class scale in all three global axes.
# CLICK - A single handle that cannot be moved, but immediately triggers a callback function when selected.

# (ones I want to add later)
# TRANSLATE_SPLIT (has two handles instead of three, with one handle being constrained to two axes)

enum HandleType {FREE, AXIS, PLANE, TRANSLATE, ROTATE, SCALE, CLICK}
var handle_type = HandleType.FREE

# If HandleType.AXIS is used, this defines what axis the control point's movement is locked to.
var snap_axis = Vector3()

# If HandleType.AXIS is used, this defines what axis the control point's movement is locked to.
var plane_origin = Vector3()
var plane_x_axis = Vector3()
var plane_y_axis = Vector3()

# If TRANSLATE, ROTATE or SCALE is used, this determines how far the axis handles are from the point they control.
var handle_distance: float = 0.5


# ////////////////////////////////////////////////////////////
# CALLBACK
# The node that this handle belongs to, will be used for all callbacks.
var control_point_owner

# The callback used to create and return undo data.
var undo_data_callback: String = ""

# The callback used to create and return redo data.
var redo_data_callback: String = ""

# The callback used to perform an undo.
var undo_action_callback: String = ""

# The callback used to perform a redo.
var redo_action_callback: String = ""

# ------------

# (FREE MODE) The method called on the owner when the handle is being translated.
var free_update_callback: String = ""

# (FREE MODE) The method called on the owner when the handle has finished translated.
var free_commit_callback: String = ""

# (AXIS MODE) The method called on the owner when the handle is being translated.
var axis_update_callback: String = ""

# (AXIS MODE) The method called on the owner when the handle has finished translated.
var plane_commit_callback: String = ""

# (PLANE MODE) The method called on the owner when the handle is being translated.
var plane_update_callback: String = ""

# (PLANE MODE) The method called on the owner when the handle has finished translated.
var axis_commit_callback: String = ""

# (TRANSLATE MODE) The method called on the owner when the handle is being translated.
var translate_update_callback: String = ""

# (TRANSLATE MODE) The method called on the owner when the handle has finished translated.
var translate_commit_callback: String = ""

# The method called on the owner when the handle is being rotated.
var rotate_update_callback: String = ""

# The method called on the owner when the handle has finished rotating.
var rotate_commit_callback: String = ""

# The method called on the owner when the handle is being scaled.
var scale_update_callback: String = ""

# The method called on the owner when the handle has finished scaling.
var scale_commit_callback: String = ""

# The method called on the owner when the handle has been clicked.
var click_callback: String = ""


# ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# INITIALIZATION
func _init(owner : Node, undo_data_callback : String, redo_data_callback : String, undo_action_callback : String, redo_action_callback : String):
	self.control_point_owner = owner
	self.undo_data_callback = undo_data_callback
	self.redo_data_callback = redo_data_callback
	self.undo_action_callback = undo_action_callback
	self.redo_action_callback = redo_action_callback
	
	

# ////////////////////////////////////////////////////////////
# MAINTENANCE

# Clears any callbacks set.
func clear_callbacks():
	free_update_callback = ""
	free_commit_callback = ""
	axis_update_callback = ""
	axis_commit_callback = ""
	plane_update_callback = ""
	plane_commit_callback = ""
	translate_update_callback = ""
	translate_commit_callback = ""
	
	rotate_update_callback = ""
	rotate_commit_callback = ""
	scale_update_callback = ""
	scale_commit_callback = ""
	
	click_callback = ""
	
 
# ////////////////////////////////////////////////////////////
# MODE SWITCH
# Sets the current handle mode to the FREE type.
func set_type_free(clear_all_callbacks : bool, update_callback : String, commit_callback : String):
	
	if clear_all_callbacks == true:
		clear_callbacks()
	
	self.handle_type = HandleType.FREE
	self.free_update_callback = update_callback
	self.free_commit_callback = commit_callback


func set_type_axis(clear_all_callbacks : bool, update_callback : String, commit_callback : String, snap_axis : Vector3):
	
	if clear_all_callbacks == true:
		clear_callbacks()
	
	self.handle_type = HandleType.AXIS
	self.axis_update_callback = update_callback
	self.axis_commit_callback = commit_callback
	self.snap_axis = snap_axis

func set_type_plane(clear_all_callbacks : bool, update_callback : String, commit_callback : String, plane_origin : Vector3, plane_x : Vector3, plane_y : Vector3):
	
	if clear_all_callbacks == true:
		clear_callbacks()
	
	self.handle_type = HandleType.PLANE
	self.plane_update_callback = update_callback
	self.plane_commit_callback = commit_callback
	self.plane_origin = plane_origin
	self.plane_x_axis = plane_x
	self.plane_y_axis = plane_y

func set_type_translate(clear_all_callbacks : bool, update_callback : String, commit_callback : String):
	
	if clear_all_callbacks == true:
		clear_callbacks()
	
	self.handle_type = HandleType.TRANSLATE
	self.translate_update_callback = update_callback
	self.translate_commit_callback = commit_callback


func set_type_rotation(clear_all_callbacks : bool, update_callback : String, commit_callback : String):
	
	if clear_all_callbacks == true:
		clear_callbacks()
	
	self.handle_type = HandleType.ROTATE
	self.rotation_update_callback = update_callback
	self.rotation_commit_callback = commit_callback


func set_type_scale(clear_all_callbacks : bool, update_callback : String, commit_callback : String):
	
	if clear_all_callbacks == true:
		clear_callbacks()
	
	self.handle_type = HandleType.SCALE
	self.scale_update_callback = update_callback
	self.scale_commit_callback = commit_callback


func set_type_click(clear_all_callbacks : bool, click_callback : String):
	
	if clear_all_callbacks == true:
		clear_callbacks()
	
	self.handle_type = HandleType.CLICK
	self.click_callback = click_callback



# ////////////////////////////////////////////////////////////
# CONTROL POINT ACCESS
# Returns the handles that the gizmo needs to render for this specific control point.
func get_handle_positions():
	
	if is_control_visible == false:
		return null
	
	match handle_type:
		
		HandleType.FREE:
			return [control_position]
			
		HandleType.AXIS:
			return [control_position]
		
		HandleType.PLANE:
			return [control_position]
			
		HandleType.TRANSLATE:
			var handle_x = control_position + Vector3(handle_distance, 0, 0)
			var handle_y = control_position + Vector3(0, handle_distance, 0)
			var handle_z = control_position + Vector3(0, 0, handle_distance)
			return [handle_x, handle_y, handle_z]
		
		
		# currently pass for rotate and scale until i implement it.
		
		HandleType.CLICK:
			return [control_position]

# Returns the lines that the gizmo needs to render for this specific control point.
func get_handle_lines():
	
	if is_control_visible == false:
		return null
	
	if handle_type == HandleType.TRANSLATE:
		var handle_x = control_position + Vector3(handle_distance, 0, 0)
		var handle_y = control_position + Vector3(0, handle_distance, 0)
		var handle_z = control_position + Vector3(0, 0, handle_distance)
		
		var line_1 = [PoolVector3Array( [control_position, handle_x] ), mat_solid_color(1, 0.3, 0.0)]
		var line_2 = [PoolVector3Array( [control_position, handle_y] ), mat_solid_color(0.3, 1, 0.3)]
		var line_3 = [PoolVector3Array( [control_position, handle_z] ), mat_solid_color(0.3, 0.3, 1)]
	
		return [line_1, line_2, line_3]
		
	else:
		return null

# Returns the number of handles this control point currently requests (something rudimentary for counting indexes).
func get_handle_count():
	
	if is_control_visible == false:
		return null
	
	match handle_type:
		
		HandleType.FREE:
			return 1
			
		HandleType.AXIS:
			return 1
		
		HandleType.PLANE:
			return 1
		
		HandleType.TRANSLATE:
			return 3
		
		HandleType.ROTATE:
			return 3
		
		HandleType.SCALE:
			return 3
		
		HandleType.CLICK:
			return 1
		

# Returns the core control point data as a Dictionary (name, position, rotation, scale, hidden)
func get_control_data() -> Dictionary:
	
	var result = {}
	result['name'] = control_name
	result['position'] = control_position
	result['rotation'] = control_rotation
	result['scale'] = control_scale
	result['visible'] = is_control_visible
	
	return result

# Sets core control point data from a previously-created Dictionary.
func set_control_data(data : Dictionary):
	
	# TODO : Error handling, make sure the data we receive is the data we wanted.
	control_name = data['name']
	control_position = data['position']
	control_rotation = data['rotation']
	control_scale = data['scale']
	is_control_visible = data['visible']


# Returns undo data if successful.
func get_undo_data():
	var result = control_point_owner.call(undo_data_callback, self)
	return result

# Returns redo data if successful.
func get_redo_data():
	var result = control_point_owner.call(redo_data_callback, self)
	return result


# ////////////////////////////////////////////////////////////
# GIZMO MODIFICATION
# Depending on the mode set, the handle will be updated in different ways.
func update_handle(index, camera, point):
	
	# Get some matrices and coordinates
	var world_matrix = control_point_owner.global_transform
	var camera_matrix = camera.global_transform
	
	match handle_type:
		
		HandleType.FREE, HandleType.AXIS, HandleType.PLANE:
			
			var new_position = Vector3()
			
			# NEW POSITION GETTERS
			if handle_type == HandleType.FREE:
				var camera_x_basis = camera.get_camera_transform().basis.x
				var camera_y_basis = camera.get_camera_transform().basis.y
				new_position = VectorUtils.project_cursor_to_plane(camera, point, world_matrix, control_position, camera_x_basis, camera_y_basis)
			
			elif handle_type == HandleType.AXIS:
				new_position = project_point_to_axis(point, camera, control_position, world_matrix, snap_axis)
			
			elif handle_type == HandleType.PLANE:
				new_position = VectorUtils.project_cursor_to_plane(camera, point, world_matrix, plane_origin, plane_x_axis, plane_y_axis)
			
			# POSITION PROPERTY HANDLERS
			if not new_position: 
				return #sometimes the projection might fail
			
			if control_transform_hold.has("position") == false:
					control_transform_hold["position"] = new_position
					continue
			
			
			# SNAPPING ENABLED
			if control_point_owner.get_plugin().snap_gizmo_enabled == true:
				
				var snap_increment = control_point_owner.get_plugin().snap_gizmo_increment
				new_position = snap_position(new_position, Vector3(snap_increment, snap_increment, snap_increment))
				
				control_position = new_position
			
			# SNAPPING DISABLED
			else:
				control_position = new_position
			
			# CALLBACK
			match handle_type:
					HandleType.FREE:
						if free_update_callback != "" && control_point_owner.has_method(free_update_callback):
							control_point_owner.call(free_update_callback, self)
					HandleType.AXIS:
						if axis_update_callback != "" && control_point_owner.has_method(axis_update_callback):
							control_point_owner.call(axis_update_callback, self)
					HandleType.PLANE:
						if plane_update_callback != "" && control_point_owner.has_method(plane_update_callback):
							control_point_owner.call(plane_update_callback, self)
		
		
		
		HandleType.TRANSLATE:
#			print("Handling TRANSLATE POINT")
			
			var axis = Vector3()
			var target_position
			var handle_offset
			
			match index:
				0: axis = Vector3(1, 0, 0)
				1: axis = Vector3(0, 1, 0)
				2: axis = Vector3(0, 0, 1)
				
			#this has no use great job.
			match index:
				0: target_position = control_position + Vector3(handle_distance, 0, 0)
				1: target_position = control_position + Vector3(0, handle_distance, 0)
				2: target_position = control_position + Vector3(0, 0, handle_distance)
			match index:
				0: handle_offset = Vector3(handle_distance, 0, 0)
				1: handle_offset = Vector3(0, handle_distance, 0)
				2: handle_offset = Vector3(0, 0, handle_distance)
				
			var new_position = project_point_to_axis(point, camera, control_position, world_matrix, axis)
			
			if new_position == null: 
					return
				
			
			# TODO : Remove when the projection system is fixed.
			match index:
				0: control_position.x = new_position.x
				1: control_position.y = new_position.y
				2: control_position.z = new_position.z
			
			control_position -= handle_offset
			
			# If snapping is enabled, we have stuff to do.
			if control_point_owner.get_plugin().snap_gizmo_enabled == true:
				var snap_increment = control_point_owner.get_plugin().snap_gizmo_increment
				control_position = snap_position(control_position, Vector3(snap_increment, snap_increment, snap_increment))
			
			# Now we have a valid control_position, perform a callback.
#			print("SETTING RAWR")
			if translate_update_callback != "":
				control_point_owner.call(translate_update_callback, self)
			
		
		HandleType.ROTATE:
			pass
		
		HandleType.SCALE:
			pass
		
		HandleType.CLICK:
			pass
		

# Receives the commit call from the Gizmo, to be handled in different ways depending on the ControlPoint mode.
func commit_handle(index, restore):
	
	control_transform_hold["position"] = control_position
	control_transform_hold["rotation"] = control_rotation
	control_transform_hold["scale"] = control_scale
	
	# is there anything else to do here?
	match handle_type:
		
		HandleType.FREE:
			if free_commit_callback != "":
				control_point_owner.call(free_commit_callback, self)
		
		HandleType.AXIS:
			if axis_commit_callback != "":
				control_point_owner.call(axis_commit_callback, self)
				
		HandleType.PLANE:
			if axis_commit_callback != "":
				control_point_owner.call(plane_commit_callback, self)
		
		HandleType.TRANSLATE:
			if translate_commit_callback != "":
				control_point_owner.call(translate_commit_callback, self)
		
		HandleType.ROTATE:
			if rotate_commit_callback != "":
				control_point_owner.call(rotate_commit_callback, self)
		
		HandleType.SCALE:
			if scale_commit_callback != "":
				control_point_owner.call(scale_commit_callback, self)
		
		HandleType.CLICK:
			control_point_owner.call(click_callback, self)
	


# ////////////////////////////////////////////////////////////
# HELPERS
func project_point_to_axis(point, camera, target_position, world_matrix, snap_axis):
	
	# Get the camera view axis.
	var snap_axis_point = snap_axis + target_position
	var camera_basis = camera.get_camera_transform().basis.z
	
	# If the camera basis and snapping axis are equal, quit early.
	if camera_basis == snap_axis:
#		print("camera basis equal to snap axis, leaving early")
		return null
	
	# Rotate the new camera axis point around the snap axis 180º
	var rotation_amount = 180/PI * 90
	var camera_basis_rotated = camera_basis.rotated(snap_axis, rotation_amount)
	
	var axis_transform = Transform(snap_axis, camera_basis, camera_basis_rotated, target_position)
	var projection_plane = Plane(snap_axis_point, target_position, camera_basis_rotated + target_position)
	
	# Setup the projection
	var ray_origin = camera.project_ray_origin(point)
	var ray_dir = camera.project_ray_normal(point)
	ray_origin = world_matrix.xform_inv(ray_origin)
	ray_dir = world_matrix.basis.xform_inv(ray_dir)
	
	# PROJECT
	var intersect_pos = projection_plane.intersects_ray(ray_origin, ray_dir)
	if not intersect_pos: 
#		print("no projection point found, returning early.")
		return null
	
	# Transform the point and minus out the Z value
	var projected_pos = axis_transform.xform_inv(intersect_pos)
	projected_pos.z = 0
	projected_pos.y = 0
	
	var final_pos = axis_transform.xform(projected_pos)
	return final_pos

# Takes a position and snap increment, and locks the position based on that increment.
func snap_position(position: Vector3, increment: Vector3) -> Vector3:
	
	var return_input = Vector3()
	
	if control_point_owner.get_plugin().snap_gizmo_global_orientation == true:
		var translated_input = position + control_point_owner.get_global_transform().origin 
		
		var snapped_input = Vector3()
		snapped_input.x = round(translated_input.x / increment.x) * increment.x
		snapped_input.y = round(translated_input.y / increment.y) * increment.y
		snapped_input.z = round(translated_input.z / increment.z) * increment.z
		
		return_input = snapped_input - control_point_owner.get_global_transform().origin
	
	else:
		return_input.x = round(position.x / increment.x) * increment.x
		return_input.y = round(position.y / increment.y) * increment.y
		return_input.z = round(position.z / increment.z) * increment.z
	
	return return_input

func mat_solid_color(red, green, blue):
	var mat = SpatialMaterial.new()
	mat.render_priority = mat.RENDER_PRIORITY_MAX
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.flags_no_depth_test = true
	mat.albedo_color = Color(red, green, blue)
	
	return mat
	

# Creates a new ControlPoint object and copies all properties to it (any arrays will also be duplicated).
func copy() -> Object:
	var new_control_point = load("res://addons/onyx/gizmos/control_point.gd").new()
	
	# PROPERTIES
	new_control_point.control_name = self.control_name
	new_control_point.control_position = self.control_position
	new_control_point.control_rotation = self.control_rotation
	new_control_point.control_scale = self.control_scale
	new_control_point.is_control_visible = self.is_control_visible
	
	# DISPLAY
	new_control_point.handle_type = self.handle_type
	new_control_point.axis_triangle = self.axis_triangle.duplicate()
	new_control_point.handle_distance = self.handle_distance
	new_control_point.apply_snap = self.apply_snap
	
	# CALLBACK
	new_control_point.control_point_owner = self.control_point_owner
	new_control_point.undo_callback = self.undo_callback
	new_control_point.redo_callback = self.redo_callback

	new_control_point.free_update_callback = self.free_update_callback
	new_control_point.free_commit_callback = self.free_commit_callback
	new_control_point.axis_update_callback = self.axis_update_callback
	new_control_point.axis_commit_callback = self.axis_commit_callback
	new_control_point.translate_update_callback = self.translate_update_callback
	new_control_point.translate_commit_callback = self.translate_commit_callback
	new_control_point.rotate_update_callback = self.rotate_update_callback
	new_control_point.rotate_commit_callback = self.rotate_commit_callback
	new_control_point.scale_update_callback = self.scale_update_callback
	new_control_point.scale_commit_callback = self.scale_commit_callback
	new_control_point.click_callback = self.click_callback
	
	
	return new_control_point

# Replaces the base properties in this object (ones that can be edited by a Gizmo) from the given source ControlPoint.
func restore_base_properties(source):
	
	# PROPERTIES
	self.control_name = source.control_name
	self.control_position = source.control_position
	self.control_rotation = source.control_rotation
	self.control_scale = source.control_scale
	self.is_control_visible = source.is_control_visible
	
