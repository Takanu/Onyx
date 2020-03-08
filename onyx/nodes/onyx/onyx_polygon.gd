tool
extends "res://addons/onyx/nodes/onyx/onyx.gd"

# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")
var ControlPoint = load("res://addons/onyx/gizmos/control_point.gd")





# ////////////////////////////////////////////////////////////
# TOOL ENUMS

# allows origin point re-orientation, for precise alignments and convenience.
enum OriginPosition {CENTER, BASE, BASE_CORNER}
export(OriginPosition) var origin_mode = OriginPosition.BASE setget update_origin_type

# used to keep track of how to move the origin point into a new position.
var previous_origin_mode = OriginPosition.BASE

# Used to define what plane the points are built on.
enum PointPlane {X_Z, X_Y, Z_Y}
export(PointPlane) var point_plane = PointPlane.X_Z setget update_point_plane

# ////////////////////////////////////////////////////////////
# PROPERTIES

# Exported variables representing all usable handles for re-shaping the mesh, in order.
# All functions that manipulate this list must also manupulate the internal Handles list.
export(Array) var polygon_points = [] setget update_polygon_points
export(float) var depth = 1.0 setget update_depth

const POLYGON_CONTROL_NAME = "polygon_control_"
const BEVEL_CONTROL_NAME = "bevel_control_"


# ////////////////////////////////////////////////////////////
# UVS
enum UnwrapMethod {PROPORTIONAL_OVERLAP, CLAMPED_OVERLAP}
var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP




# ////////////////////////////////////////////////////////////
# UI
var edit_toolbar : Control




# ////////////////////////////////////////////////////////////
# PROPERTY GENERATORS
# Used to give the unwrap method a property category
# If you're watching this Godot developers.... why.
func _get_property_list():
	
#	print("[OnyxCube] ", self.get_name(), " - _get_property_list()")
	
	var props = [
		{	
			# The usage here ensures this property isn't actually saved, as it's an intermediary
			
			"name" : "uv_options/unwrap_method",
			"type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Proportional Overlap, Face Projection"
		},
	]
	return props

func _set(property, value):
#	print("[OnyxCube] ", self.get_name(), " - _set() : ", property, " ", value)
	
	# Same value catcher
	var old_value = self.get(property)
	if old_value != null:
		if old_value == value:
#			print("Same value assignment, BAIIIII")
			return
	
	# ///// SETTERS /////
	match property:
		"uv_options/unwrap_method":
			unwrap_method = value
			generate_geometry()
			return
		

func _get(property):
#	print("[OnyxCube] ", self.get_name(), " - _get() : ", property)
	
	match property:
		"uv_options/unwrap_method":
			return unwrap_method
	

# ////////////////////////////////////////////////////////////
# PROPERTY UPDATERS

# Used when a handle variable changes in the properties panel.
func update_polygon_points(new_value):
	
	polygon_points = new_value
	build_handles()

func update_depth(new_value):
	
	depth = new_value
	generate_geometry()

# Changes the origin position relative to the shape and regenerates geometry and handles.
func update_origin_type(new_value):
	
	if previous_origin_mode == new_value:
		return
	
	origin_mode = new_value
	update_origin_mode()
	balance_handles()
	generate_geometry()
	
	# ensure the origin mode toggle is preserved, and ensure the adjusted handles are saved.
	previous_origin_mode = origin_mode
	old_handle_data = get_control_data()

func update_point_plane(new_value):
	
	origin_mode = new_value
	
	# ???
	# ???



# Updates the origin location when the corresponding property is changed.
func update_origin_mode():
	
	# Used to prevent the function from triggering when not inside the tree.
	# This happens during duplication and replication and causes incorrect node placement.
	if is_inside_tree() == false:
		return
	
	
	# Re-add once handles are a thing, otherwise this breaks the origin stuff.
	if handles.size() == 0:
		return
	
#
#	# based on the current position and properties, work out how much to move the origin.
#	var diff = Vector3(0, 0, 0)
#
#	match previous_origin_mode:
#
#		OriginPosition.CENTER:
#			match origin_mode:
#
#				OriginPosition.BASE:
#					diff = Vector3(0, -y_minus_position, 0)
#				OriginPosition.BASE_CORNER:
#					diff = Vector3(-x_minus_position, -y_minus_position, -z_minus_position)
#
#		OriginPosition.BASE:
#			match origin_mode:
#
#				OriginPosition.CENTER:
#					diff = Vector3(0, y_plus_position / 2, 0)
#				OriginPosition.BASE_CORNER:
#					diff = Vector3(-x_minus_position, 0, -z_minus_position)
#
#		OriginPosition.BASE_CORNER:
#			match origin_mode:
#
#				OriginPosition.BASE:
#					diff = Vector3(x_plus_position / 2, 0, z_plus_position / 2)
#				OriginPosition.CENTER:
#					diff = Vector3(x_plus_position / 2, y_plus_position / 2, z_plus_position / 2)
#
#	# Get the difference
#	var new_loc = self.global_transform.xform(self.translation + diff)
#	var old_loc = self.global_transform.xform(self.translation)
#	var new_translation = new_loc - old_loc
#	#print("MOVING LOCATION: ", old_loc, " -> ", new_loc)
#	#print("TRANSLATION: ", new_translation)
	
	# set it
#	global_translate(new_translation)
#	translate_children(new_translation * -1)
#	boolean_preview_node.set_translation(Vector3(0, 0, 0))

# Updates the origin position for the currently-active Origin Mode, either building a new one using properties or through a new position.
# DOES NOT update the origin when the origin property has changed, for use with handle commits.
func update_origin_position(new_location = null):
	
	pass
#
#	var new_loc = Vector3()
#	var global_tf = self.global_transform
#	var global_pos = self.global_transform.origin
#
#	if new_location == null:
#
#		# Find what the current location should be
#		var diff = Vector3()
#		var mid_x = (x_plus_position - x_minus_position) / 2
#		var mid_y = (y_plus_position - y_minus_position) / 2
#		var mid_z = (z_plus_position - z_minus_position) / 2
#
#		var diff_x = abs(x_plus_position - -x_minus_position)
#		var diff_y = abs(y_plus_position - -y_minus_position)
#		var diff_z = abs(z_plus_position - -z_minus_position)
#
#		match origin_mode:
#			OriginPosition.CENTER:
#				diff = Vector3(mid_x, mid_y, mid_z)
#
#			OriginPosition.BASE:
#				diff = Vector3(mid_x, -y_minus_position, mid_z)
#
#			OriginPosition.BASE_CORNER:
#				diff = Vector3(-x_minus_position, -y_minus_position, -z_minus_position)
#
#		new_loc = global_tf.xform(diff)
#
#	else:
#		new_loc = new_location
#
#	# Get the difference
#	var old_loc = global_pos
#	var new_translation = new_loc - old_loc
#
#
#	# set it
#	global_translate(new_translation)
#	translate_children(new_translation * -1)
#	boolean_preview_node.set_translation(Vector3(0, 0, 0))

# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry():
	
#	print('trying to generate geometry...')
	
	# ////////////////////////////////////////
	# VALIDITY CHECKS
	
	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false || Engine.editor_hint == false:
		return
	
	var mesh_factory = OnyxMeshFactory.new()
	onyx_mesh.clear()
	
	# If the polygon isnt valid, return early and clear the mesh.
	if VectorUtils.find_polygon_2d_intersection(polygon_points) == true:
		mesh = null
		refresh_handle_data()
		update_gizmo()
		return
	
	# If we don't have three points, return early
	if polygon_points.size() < 3:
		mesh = null
		refresh_handle_data()
		update_gizmo()
		return
	
	# ////////////////////////////////////////
	# EXTRUDE VECTOR
	
	var extrude_vector = Vector3()
	match point_plane:
		PointPlane.X_Z:
			extrude_vector = Vector3(0, depth, 0)
		PointPlane.X_Y:
			extrude_vector = Vector3(0, 0, depth)
		PointPlane.Z_Y:
			extrude_vector = Vector3(depth, 0, 0)
	
	var i = 0
	var size = handles.size()
	
	
	# ////////////////////////////////////////
	# POLYGON ORIENTATION
	
	# Add up all the signed angles and see if the average is positive or negative
	var is_positively_orientated = false
	var total_angle_size = 0.0
	
	while i != size:
		var index_a = VectorUtils.loop_int(i, 0, size - 1)
		var index_b = VectorUtils.loop_int(i + 1, 0, size - 1)
		var index_c = VectorUtils.loop_int(i + 2, 0, size - 1)
		total_angle_size += VectorUtils.get_signed_angle(polygon_points[index_a], polygon_points[index_b], polygon_points[index_c])
		
		i += 1
	
#	print("TOTAL ANGLE - ", total_angle_size)
	if total_angle_size >= 0:
		is_positively_orientated = true
	
	# ////////////////////////////////////////
	# TUBE BUILDER
	
	i = 0
	
	# Build the tube
	while i != size:
		
		var index_a = VectorUtils.loop_int(i, 0, size - 1)
		var index_b = VectorUtils.loop_int(i + 1, 0, size - 1)
		var position_a = convert_plane_point_to_vector3(polygon_points[index_a])
		var position_b = convert_plane_point_to_vector3(polygon_points[index_b])
		
		var base_1 = position_a
		var base_2 = position_b
		var extr_1 = position_a + extrude_vector
		var extr_2 = position_b + extrude_vector
		
		if (depth < 0 && is_positively_orientated) || (depth >= 0 && is_positively_orientated == false):
			onyx_mesh.add_ngon([base_1, extr_1, extr_2, base_2], [], [], [], [])
		else:
			onyx_mesh.add_ngon([base_1, base_2, extr_2, extr_1], [], [], [], [])
		
		i += 1
	
	
	# ////////////////////////////////////////
	# POLYGON CAP SOLVER
	
	var bottom_cap = []
	var top_cap = []
	
	var polygon_candidates = {}
	i = 0
	for point in polygon_points:
		polygon_candidates[i] = point
		i += 1
	
	var sorted_points = {}
	var found_sets = []
	
	i = 0
	while polygon_candidates.size() != 0:
		
		var p_size = polygon_candidates.size()
		
		# sort them out first
		for index in polygon_candidates.keys():
			
			var index_a = VectorUtils.loop_int(index - 1, 0, p_size - 1)
			var index_b = VectorUtils.loop_int(index, 0, p_size - 1)
			var index_c = VectorUtils.loop_int(index + 1, 0, p_size - 1)
			var point_a = polygon_candidates[index_a]
			var point_b = polygon_candidates[index_b]
			var point_c = polygon_candidates[index_c]
			var signed_angle = VectorUtils.get_signed_angle(point_a, point_b, point_c)
			
			if (signed_angle >= 0 && is_positively_orientated) || (signed_angle < 0 && is_positively_orientated == false):
				sorted_points[index] = {"value": point_b, "aligned": true}
			else:
				sorted_points[index] = {"value": point_b, "aligned": false}
		
		print("SORTED POINTS - ", sorted_points.values())
		
		var sort_index = 0
		var sort_size = sorted_points.size()
		
		while sort_index < sort_size:
			
			# If we've already nabbed this index, continue
			if sorted_points.has(sort_index) == false:
				sort_index += 1
				continue
			
			var index_2 = VectorUtils.loop_int(sort_index + 1, 0, sort_size - 1)
			var index_3 = VectorUtils.loop_int(sort_index + 2, 0, sort_size - 1)
			
			# We need two contiguous points, skip if not
			if !sorted_points.has(index_2) ||  !sorted_points.has(index_3):
				sort_index += 1
				continue
			
			var point_1 = sorted_points[sort_index]
			var point_2 = sorted_points[index_2]
			var point_3 = sorted_points[index_3]
			var match_found = false
			
			# If this is an unaligned point, we just need the next point to be aligned to match
			if point_1["aligned"] == false:
				if point_2["aligned"] == true:
					match_found = true
					
			# Otherwise you only have one match condition
			elif (point_2["aligned"] == true && point_3["aligned"] == true):
				match_found = true
			
			if match_found:
				found_sets.append({"middle_index" : index_2, "points" : [point_1["value"], point_2["value"], point_3["value"]]})
				sorted_points.erase(sort_index);  sorted_points.erase(index_2);  sorted_points.erase(index_3)
				sort_index += 3
				continue
			
			else:
				sort_index += 1
				continue
			

		# For every set we found, add them to the array and remove the middle vertex from the equation
		# (unless we only have three vertices left, in which case we're done!')
		print("FOUND MATCHES - ", found_sets)
		if found_sets.size() == 0:
			print("OH SHIT WE FOUND NONE BYE!")
			break

		for set in found_sets:
			var points = set["points"]
			var p_1 = points[0];  var p_2 = points[1];  var p_3 = points[2];
			var vec_1 = convert_plane_point_to_vector3(p_1)
			var vec_2 = convert_plane_point_to_vector3(p_2)
			var vec_3 = convert_plane_point_to_vector3(p_3)

			if is_positively_orientated:
				top_cap.append([vec_1 + extrude_vector, vec_2 + extrude_vector, vec_3 + extrude_vector])
				bottom_cap.append([vec_1, vec_3, vec_2])
			else:
				bottom_cap.append([vec_1, vec_2, vec_3])
				top_cap.append([vec_1 + extrude_vector, vec_3 + extrude_vector, vec_2 + extrude_vector])

			# Remove the middle point from the candidate list
			polygon_candidates.erase(set["middle_index"])

		# If we're not down the the magic number, prepare for the next.
		print("LEFTOVER POINT CANDIDATES - ", polygon_candidates.keys())
		
		sorted_points.clear()
		found_sets.clear()

		if polygon_candidates.size() >= 3:
			var unsorted_polygon_candidates = polygon_candidates.duplicate()
			polygon_candidates.clear()

			i = 0
			for point in unsorted_polygon_candidates.values():
				polygon_candidates[i] = point
				i += 1
			print("NEXT POINT CANDIDATES - ", polygon_candidates.keys())

		# If we are, CLEAR AND LEAVE
		else:
			break
	
	for set in bottom_cap:
		onyx_mesh.add_tri(set, [], [], [], [])
	for set in top_cap:
		onyx_mesh.add_tri(set, [], [], [], [])
	
	# RENDER THE MESH
	render_onyx_mesh()
	
	# Re-submit the handle positions based on the built faces, so other handles that aren't the
	# focus of a handle operation are being updated\
	refresh_handle_data()
	update_gizmo()
	
	_generate_hollow_shape()

# ////////////////////////////////////////////////////////////
# INHERITED CONTROL POINT FUNCTIONS

# On initialisation, control points are built for transmitting and handling interactive points between the node and the node's gizmo.
func build_handles():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	var plane_info = get_plane_info()
	handles.clear()
	
	if polygon_points.size() == 0:
		return
	
	var i = 0
	for point in polygon_points:
		var new_control = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
		new_control.control_position = convert_plane_point_to_vector3(point)
		new_control.control_name = POLYGON_CONTROL_NAME + str(i)
		new_control.set_type_plane(false, "handle_change", "handle_commit", plane_info["origin"], plane_info["x_up"], plane_info["y_up"])
		
		handles[new_control.control_name] = new_control
		i += 1
	
	# need to give it positions in the case of a duplication or scene load.
	refresh_handle_data()
	

# Uses the current shape properties to refresh the control point data.
func refresh_handle_data():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
#		print("...attempted to refresh_handle_data()")
		return
	
	# Failsafe for script reloads, BECAUSE I CURRENTLY CAN'T DETECT THEM.
	if handles.size() == 0:
		if gizmo != null:
#			print("...attempted to refresh_handle_data(), rebuilding handles.")
			gizmo.control_points.clear()
			build_handles()
			return
	
	var i = 0
	for control in handles.values():
		control.control_position = convert_plane_point_to_vector3(polygon_points[i])
		i += 1
		

# Changes the control and associated property data based on the given index and coordinates.
func update_handle_from_gizmo(control):
	
	if handles.has(control.control_name) == null:
		print("update_handle_from_gizmo() - no handle found, whoops.")
		return
	
	var index = int(control.control_name.replace(POLYGON_CONTROL_NAME, ""))
	if index != null:
		polygon_points[index] = convert_vector3_to_plane_point(control.control_position)
	
	refresh_handle_data()
	

# Applies the current control values to the shape attributes
func apply_handle_attributes():
	
	var i = 0
	for control in handles.values():
		polygon_points[i] = convert_vector3_to_plane_point(control.control_position)
		i += 1
	
	pass
	

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_handles():
	
	# > the handle data is unique and independent, no balance required.
	pass
	

# ////////////////////////////////////////////////////////////
# NEW CONTROL POINT FUNCTIONS

# Adds a control point using a 3D position
func add_control_point(position : Vector3):
	
	var plane_info = get_plane_info()
	
	var new_control = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	new_control.control_position = position
	new_control.control_name = POLYGON_CONTROL_NAME + str(polygon_points.size())
	new_control.set_type_plane(false, "handle_change", "handle_commit", plane_info["origin"], plane_info["x_up"], plane_info["y_up"])
	
	var plane_point = convert_vector3_to_plane_point(position)
	
	polygon_points.append(plane_point)
	handles[new_control.control_name] = new_control
	
	generate_geometry()
	update_gizmo()

# Deletes the control point with the specified control.
func delete_control_point(control):
	
	print("Attempting deletion! - ", control)
	
	var index = int(control.control_name.replace(POLYGON_CONTROL_NAME, ""))
	if handles.has(control.control_name) == false || polygon_points.size() <= index:
		print("nope. - ", index, "handle - ", control.control_name)
		return
	
	polygon_points.remove(index)
	handles.erase(control.control_name)
	
	print("Leftover points - ", polygon_points)
	print("Leftover controls - ", handles.keys())
	
	rename_control_points()
	generate_geometry()

# Used after a deletion to rename all other control points to be sequential
func rename_control_points():
	
	if handles.size() == 0:
		return
	
	# We also need to change the keys...
	var old_handle_stack = handles.duplicate()
	handles.clear()
	
	var i = 0
	for control in old_handle_stack.values():
		control.control_name = POLYGON_CONTROL_NAME + str(i)
		handles[control.control_name] = control
		i += 1
	
	print("Renamed points - ", polygon_points)
	print("Renamed controls - ", handles.keys())
	

# Used to check if the polygon shape we have is free of intersections.
func is_polgon_valid() -> bool:
	return false

# ////////////////////////////////////////////////////////////
# SNAP PLANE FUNCTIONS

# Returns the info for the plane all points are to be snapped to.
func get_plane_info() -> Dictionary:
	
	var details = {}
	details["origin"] = Vector3(0, 0, 0)
	
	match point_plane:
		PointPlane.X_Z:
			details["x_up"] = Vector3(1, 0, 0)
			details["y_up"] = Vector3(0, 0, 1)
		PointPlane.X_Y:
			details["x_up"] = Vector3(1, 0, 0)
			details["y_up"] = Vector3(0, 1, 0)
		PointPlane.Z_Y:
			details["x_up"] = Vector3(0, 0, 1)
			details["y_up"] = Vector3(0, 1, 0)
	
	return details

# Converts a 3D vector to a 2D vector that fits along the current plane.
func convert_vector3_to_plane_point(vector : Vector3) -> Vector2:
	
	match point_plane:
		PointPlane.X_Z:
			return Vector2(vector.x, vector.z)
		PointPlane.X_Y:
			return Vector2(vector.x, vector.y)
		PointPlane.Z_Y:
			return Vector2(vector.z, vector.y)
	
	# idk failsafe lol
	return Vector2()


# Converts a 2D point on the current snap plane to a 3D object space vector.
func convert_plane_point_to_vector3(point : Vector2) -> Vector3:
	match point_plane:
		PointPlane.X_Z:
			return Vector3(point.x, 0, point.y)
		PointPlane.X_Y:
			return Vector3(point.x, point.y, 0)
		PointPlane.Z_Y:
			return Vector3(0, point.y, point.x)
	
	# idk failsafe lol
	return Vector3()

# ???
# Don't know if i need a function for moving a newly made control point to the cursor yet.


# ////////////////////////////////////////////////////////////
# HOLLOW MODE FUNCTIONS

# The margin options available in Hollow mode, identified by the control names that should have margins
func get_hollow_margins() -> Array:
	
	return []


# Gets the current shape parameters not controlled by handles, to apply to the hollow shape
func assign_hollow_properties():
	
	if hollow_object == null:
		return
	
#	print("[OnyxPolygon] ", self.get_name(), " - assign_hollow_properties()")
	
#	if hollow_object.subdivisions != self.subdivisions:
#		hollow_object.subdivisions = self.subdivisions
	

# Assigns the hollow object an origin point based on the origin mode of this Onyx type.
# THIS DOES NOT MODIFY THE ORIGIN TYPE OF THE HOLLOW OBJECT
func assign_hollow_origin():
	
	if hollow_object == null:
		return
	
#	print("[OnyxPolygon] ", self.get_name(), " - assign_hollow_origin()")
	
#	hollow_object.set_translation(Vector3(0, 0, 0))
	

# An override-able function used to determine how margins apply to handles
func apply_hollow_margins(hollow_controls: Dictionary):
	
	if hollow_object == null:
		return
	
#	print("[OnyxPolygon] ", self.get_name(), " - apply_hollow_margins(controls)")
#	print("base onyx controls - ", handles)
#	print("hollow controls - ", hollow_controls)
	
#	for key in hollow_controls.keys():
#		var hollow_handle = hollow_controls[key]
#		var control_handle = handles[key]
#		var margin = hollow_margin_values[key]
		
#		match key:
#			"x_minus":
#				hollow_handle.control_position.x = control_handle.control_position.x + margin
#			"x_plus":
#				hollow_handle.control_position.x = control_handle.control_position.x - margin
#			"y_minus":
#				hollow_handle.control_position.y = control_handle.control_position.y + margin
#			"y_plus":
#				hollow_handle.control_position.y = control_handle.control_position.y - margin
#			"z_minus":
#				hollow_handle.control_position.z = control_handle.control_position.z + margin
#			"z_plus":
#				hollow_handle.control_position.z = control_handle.control_position.z - margin
	
	return hollow_controls


# ////////////////////////////////////////////////////////////

var is_mouse_down = false

# ////////////////////////////////////////////////////////////
# BASE UI FUNCTIONS

func editor_select():
	
	# Failsafe for Godot's script reload badness.
#	plugin.remove_control_in_backup("ONYX_POLYGON_TOOLBAR")

	if edit_toolbar != null:
		edit_toolbar.queue_free()
		edit_toolbar = null
	
	print("EDITOR SELECT")
	if edit_toolbar == null:
		edit_toolbar = load("res://addons/onyx/ui/onyx_polygon_toolbar.tscn").instance()
		edit_toolbar = plugin.add_toolbar(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, edit_toolbar)
		edit_toolbar.connect("edit_mode_changed", self, "_change_edit_mode")
		
#		plugin.add_control_to_backup(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, edit_toolbar, "ONYX_POLYGON_TOOLBAR")

func editor_deselect():
	print("EDITOR DESELECT")
	if edit_toolbar != null:
		edit_toolbar.disconnect("edit_mode_changed", self, "_change_edit_mode")
		plugin.remove_toolbar(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, edit_toolbar)
		edit_toolbar.queue_free()
		edit_toolbar = null
		

func receive_gui_input(camera, event):
	
	if edit_toolbar == null:
		return
	
	if event.is_class("InputEventMouse") == false:
		return
	
#	print("EDIT MODE - ", edit_toolbar.edit_mode)
	
	match edit_toolbar.edit_mode:
		0:
			pass
		1:
			pass
		2:
			return _receive_input_add_mode(camera, event)
		3:
			pass
	
	return false

func _change_edit_mode(old_edit_mode, new_edit_mode):
	
	# If the old edit mode is Delete, switch the handle type to Free
	if old_edit_mode == 3:
		for control in handles.values():
			control.set_type_free(true, "handle_change", "handle_commit")
	
	# If the new edit mode is Delete, switch the handle type to Delete
	elif new_edit_mode == 3:
		for control in handles.values():
			control.set_type_click(true, "delete_control_point")


func _receive_input_add_mode(camera, event):
	
	if event.is_class("InputEventMouse") == false:
		return
	
#	print(event)
	
	if event.is_class("InputEventMouseButton"):
		if is_mouse_down != event.pressed && event.button_index == BUTTON_LEFT:
			# If we have a mouse down event and we didnt before, add a new handle and make it the active handle.
			print("DING!")
			
			if event.pressed == true:
				print("DING! DING! DIIIIIIING!")
				var plane = get_plane_info()
				var mouse_pos = event.position
				var world_tf = self.global_transform
				
				var spawn_position = VectorUtils.project_cursor_to_plane(camera, mouse_pos, world_tf, plane["origin"], plane["x_up"], plane["y_up"])
				print("NEW POSITION - ", spawn_position)
				add_control_point(spawn_position)
			
			# If we have a mouse up event and we didnt before, finish the edit and generate geometry.
			if event.pressed == false:
				pass
			
			is_mouse_down = event.pressed
			return true
	
	# If it hasn't changed, check what mode we're in
	else:
		if is_mouse_down == true:
			pass
		
		if is_mouse_down == false:
			pass
	
	return false



# ////////////////////////////////////////////////////////////
# UI EDITOR FUNCTIONS

