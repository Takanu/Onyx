tool
extends Resource

# ////////////////////////////////////////////////////////////
# INFO
# A delegate class designed to represent a specific control point for a gizmo.
# A control point can represent one or more handles depending on the Display mode it is in.

# Will also handle callbacks and other features between Onyx types and the Gizmo sub-class.


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
# TRANSLATE - A set of three handles that manipulate the class translation in all three global axes.
# ROTATE - A set of three handles that manipulate the class rotation in all three global axes.
# SCALE - A set of three handles that manipulate the class scale in all three global axes.
# CLICK - A single handle that cannot be moved, but immediately triggers a callback function when selected.

# (ones I want to add later)
# TRANSLATE_SPLIT (has two handles instead of three, with one handle being constrained to two axes)

enum HandleType {FREE, AXIS, TRANSLATE, ROTATE, SCALE, CLICK}
var handle_type = HandleType.FREE

# If HandleType.AXIS is used, this defines what axis the control point's movement is locked to.
var axis_triangle = []

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


func set_type_axis(clear_all_callbacks : bool, update_callback : String, commit_callback : String, axis_triangle : Array):
	
	if clear_all_callbacks == true:
		clear_callbacks()
	
	self.handle_type = HandleType.AXIS
	self.axis_update_callback = update_callback
	self.axis_commit_callback = commit_callback
	self.axis_triangle = axis_triangle

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
	
	# If the handle type is click, we don't need to calculate any matrices.  Just get it over with.
	if handle_type == HandleType.CLICK:
		control_point_owner.call(click_callback, self)
		return
	
	# Get some matrices and coordinates
	var world_matrix = control_point_owner.global_transform
	var camera_matrix = camera.global_transform
	
	match handle_type:
		
		HandleType.FREE:
#			print("Handling FREE POINT")
			
			# Apply the current coordinate to world and camera space
			var world_space_coord = world_matrix.xform(control_position)
			var cam_space_coord = camera_matrix.xform_inv(world_space_coord)
			
			# Create a screen plane using the points switched coordinate-space Z-axis.
			# Create a ray that points from the point we're provided to the camera.
			# Create an origin using the new point we have.
			var project_plane = Plane(0,0,1, cam_space_coord.z)
			var ray_dir = camera.project_local_ray_normal(point)
			var ray_origin = camera_matrix.xform_inv(camera.project_ray_origin(point))
				
				
			# Get a 3D coordinate we can use based on a ray intersection of the 2D point.
			# Sometimes the projection might fail so we need to return if that's the case.
			var new_position = project_plane.intersects_ray(ray_origin, ray_dir)
			if not new_position: 
				return 
			
			# If it worked, configure and apply it.
			new_position = camera_matrix.xform(new_position)
			new_position = world_matrix.xform_inv(new_position)
			
			# Now we have a valid control_position, perform a callback.
			var control_position = new_position
			if free_update_callback != "":
				control_point_owner.call(free_update_callback, self)
		
		
		HandleType.AXIS:
#			print("Handling AXIS POINT")
			#print("RAWR HANDLE MOVED: ", coord)
			var new_position = project_point_to_axis(point, camera, control_position, world_matrix, axis_triangle)

			if not new_position: 
				return #sometimes the projection might fail
			
			if control_transform_hold.has("position") == false:
					control_transform_hold["position"] = new_position
					continue
			
			# If snapping is enabled, we have stuff to do.
			if control_point_owner.plugin.snap_gizmo_enabled == true:
				
				var snap_increment = control_point_owner.plugin.snap_gizmo_increment
				
				# This is awful, you are awful.
				var diff_gauge_x = round(new_position.x / snap_increment) * snap_increment
				var diff_gauge_y = round(new_position.y / snap_increment) * snap_increment
				var diff_gauge_z = round(new_position.z / snap_increment) * snap_increment
				new_position = Vector3(diff_gauge_x, diff_gauge_y, diff_gauge_z)
				
				control_position = new_position
				control_point_owner.call(axis_update_callback, self)
				return
			
			else:
				control_position = new_position
				if axis_update_callback != "":
					control_point_owner.call(axis_update_callback, self)
		
		
		HandleType.TRANSLATE:
#			print("Handling TRANSLATE POINT")
			
			var target_axis_triangle = []
			var target_position
			var handle_offset
			
			match index:
				0: target_axis_triangle = [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0)]
				1: target_axis_triangle = [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]
				2: target_axis_triangle = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
			match index:
				0: target_position = control_position + Vector3(handle_distance, 0, 0)
				1: target_position = control_position + Vector3(0, handle_distance, 0)
				2: target_position = control_position + Vector3(0, 0, handle_distance)
			match index:
				0: handle_offset = Vector3(handle_distance, 0, 0)
				1: handle_offset = Vector3(0, handle_distance, 0)
				2: handle_offset = Vector3(0, 0, handle_distance)
				
			var new_position = project_point_to_axis(point, camera, control_position, world_matrix, target_axis_triangle)
			
			if new_position == null: 
					return
			
			# TODO : Remove when the projection system is fixed.
			match index:
				0: control_position.x = new_position.x
				1: control_position.y = new_position.y
				2: control_position.z = new_position.z
			
			control_position -= handle_offset
			
			# Now we have a valid control_position, perform a callback.
#			print("SETTING RAWR")
			if translate_update_callback != "":
				control_point_owner.call(translate_update_callback, self)
			
		
		HandleType.ROTATE:
			pass
		
		HandleType.SCALE:
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
		
		HandleType.TRANSLATE:
			if translate_commit_callback != "":
				control_point_owner.call(translate_commit_callback, self)
		
		HandleType.ROTATE:
			if rotate_commit_callback != "":
				control_point_owner.call(rotate_commit_callback, self)
		
		HandleType.SCALE:
			if scale_commit_callback != "":
				control_point_owner.call(scale_commit_callback, self)
		
#		HandleType.CLICK:
#			control_point_owner.call(click_commit_callback, self)
	


# ////////////////////////////////////////////////////////////
# HELPERS
func project_point_to_axis(point, camera, target_position, world_matrix, axis_triangle):
#	print("RAWR HANDLE MOVED: ", target_position)
	var planes = make_planes(axis_triangle, target_position)
#	print("PLANES: ", planes)

	var ray_origin = camera.project_ray_origin(point)
	var ray_dir = camera.project_ray_normal(point)
	ray_origin = world_matrix.xform_inv(ray_origin)
	ray_dir = world_matrix.basis.xform_inv(ray_dir)
	
	# TODO - This system is busted, replace it with something better.
	
	var new_position = Vector3()
	var intersect_pos = planes[0].intersects_ray(ray_origin, ray_dir)
	if not intersect_pos: 
		return null
	
#	print('TARGET POSITION: ', target_position)
#	print('INTERSECT POSITION: ', intersect_pos)
		
	if planes.size() > 1:
		new_position = planes[1].project(intersect_pos)
	
#	print('NEW POSITION: ', new_position)
	
	return new_position
	

# Creates planes with which to lock the position of the handle to a single defined axis, if AXIS is used.
func make_planes(triangle, handle_loc):
	
	if typeof(triangle) != TYPE_ARRAY:
		print("(onyx_cube_gizmo : make_planes) No triangle set provided.")
	
	if triangle.size() < 3:
		print("(onyx_cube_gizmo : make_planes) Not enough triangles given.")
	
#	print("~~~~~")
#	print(triangle, handle_loc)
#	print("~~~~~")
	
	# get the unit vector of the two vectors made from the triangle
	var movement_vector =  handle_loc - triangle[0]
	var vertex_1 = triangle[0] + movement_vector
	var vertex_2 = triangle[1] + movement_vector
	var vertex_3 = triangle[2] + movement_vector
	
	var vec_1 = (vertex_2 - vertex_1).normalized()
	var vec_2 = (vertex_3 - vertex_1).normalized()
	var cross = vec_1.cross(vec_2).normalized()
	var vertex_4 = (cross * 2) + vertex_1
	
#	print("VECTORS: ", vec_1, vec_2, cross)
#	print("FINAL VERTICES: ", vertex_1, vertex_2, vertex_3, vertex_4)
	
	# Build the planes
	var plane_1 = Plane(vertex_1, vertex_2, vertex_4)
	var plane_2 = Plane(vertex_1, vertex_3, vertex_4)
	
#	print("PLANE 1 : ", plane_1)
#	print("PLANE 2 : ", plane_2)
	
	return [plane_1, plane_2]

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
	
