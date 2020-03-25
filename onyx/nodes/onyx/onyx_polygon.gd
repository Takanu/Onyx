# tool
# extends "res://addons/onyx/nodes/onyx/old/onyx.gd"

# # ////////////////////////////////////////////////////////////
# # DEPENDENCIES
# var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")
# var ControlPoint = load("res://addons/onyx/gizmos/control_point.gd")

# # ////////////////////////////////////////////////////////////
# # PROPERTIES


# # allows origin point re-orientation, for precise alignments and convenience.
# #enum OriginPosition {CENTER, BASE, BASE_CORNER}
# #export(OriginPosition) var origin_mode = OriginPosition.BASE setget update_origin_type
# #var previous_origin_mode = OriginPosition.BASE

# # Used to define what plane the points are built on.
# enum PointPlane {X_Z, X_Y, Z_Y}
# export(PointPlane) var point_plane = PointPlane.X_Z setget update_point_plane

# # Exported variables representing all usable handles for re-shaping the mesh, in order.
# # All functions that manipulate this list must also manupulate the internal Handles list.
# export(Array) var polygon_points = [] setget update_polygon_points
# export(float) var depth = 1.0 setget update_depth

# const POLYGON_CONTROL_NAME = "polygon_control_"
# const BEVEL_CONTROL_NAME = "bevel_control_"


# # ////////////////////////////////////////////////////////////
# # UVS
# enum UnwrapMethod {PROPORTIONAL_OVERLAP, PER_FACE_MAPPING}
# var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP setget update_unwrap_method


# # ////////////////////////////////////////////////////////////
# # UI
# var edit_toolbar : Control

# # ////////////////////////////////////////////////////////////
# # PROPERTY GENERATORS
# # Used to give the unwrap method a property category
# # If you're watching this Godot developers.... why.
# func _get_property_list():

# #	print("[OnyxCube] ", self.get_name(), " - _get_property_list()")

# 	var props = [
# 		{	
# 			# The usage here ensures this property isn't actually saved, as it's an intermediary

# 			"name" : "uv_options/unwrap_method",
# 			"type" : TYPE_INT,
# 			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
# 			"hint": PROPERTY_HINT_ENUM,
# 			"hint_string": "Proportional Overlap, Per-Face Mapping"
# 		},
# 	]
# 	return props

# func _set(property, value):
# #	print("[OnyxPolygon] ", self.get_name(), " - _set() : ", property, " ", value)

# 	# Same value catcher
# 	var old_value = self.get(property)
# 	if old_value != null:
# 		if old_value == value:
# #			print("Same value assignment, BAIIIII")
# 			return

# 	# ///// SETTERS /////
# 	match property:
# 		"uv_options/unwrap_method":
# 			unwrap_method = value
# 			update_geometry()
# 			return


# func _get(property):
# #	print("[OnyxPolygon] ", self.get_name(), " - _get() : ", property)

# 	match property:
# 		"uv_options/unwrap_method":
# 			return unwrap_method



# # ////////////////////////////////////////////////////////////
# # PROPERTY UPDATERS

# # Used when a handle variable changes in the properties panel.
# func update_polygon_points(new_value):

# 	polygon_points = new_value
# 	build_handles()
# 	update_geometry()

# func update_depth(new_value):

# 	depth = new_value
# 	update_geometry()


# func update_point_plane(new_value):

# 	point_plane = new_value
# 	build_handles()
# 	update_geometry()
# 	# ???
# 	# ???

# func update_unwrap_method(new_value):
# 	unwrap_method = new_value
# 	update_geometry()

# # Updates the origin location when the corresponding property is changed.
# # NOTE - Used to work out the difference between the current node position and where it should be now.
# func update_origin_mode():

# 	# Polygon point numerical modification requires a static origin point.
# 	pass


# # Updates the origin position for the currently-active Origin Mode, either building a new one using properties or through a new position.
# # NOTE - For use with handle commits.
# func update_origin_position(new_location = null):

# 	# Polygon point numerical modification requires a static origin point.
# 	pass

# # ////////////////////////////////////////////////////////////
# # GEOMETRY GENERATION

# # Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
# func update_geometry():

# #	print('trying to generate geometry...')

# 	# ////////////////////////////////////////
# 	# VALIDITY CHECKS

# 	# Prevents geometry generation if the node hasn't loaded yet
# 	if is_inside_tree() == false || Engine.editor_hint == false:
# 		return

# 	var mesh_factory = OnyxMeshFactory.new()
# 	onyx_mesh.clear()

# 	# If the polygon isnt valid, return early and clear the mesh.
# 	if VectorUtils.find_polygon_2d_intersection(polygon_points) == true:
# 		mesh = null
# 		refresh_handle_data()
# 		update_gizmo()
# 		return

# 	# If we don't have three points, return early
# 	if polygon_points.size() < 3:
# 		mesh = null
# 		refresh_handle_data()
# 		update_gizmo()
# 		return

# #	print("[OnyxPolygon] ", self.get_name(), " - update_geometry()")

# 	# ////////////////////////////////////////
# 	# EXTRUDE VECTOR + MESH OFFSET

# 	var extrude_vector = get_plane_depth_vector()
# 	var i = 0
# 	var size = handles.size()


# 	# ////////////////////////////////////////
# 	# POLYGON ORIENTATION

# 	# Add up all the signed angles and see if the average is positive or negative
# 	var is_positively_orientated = VectorUtils.find_polygon_2d_orientation(polygon_points)

# 	# A fix for the X_Y orientation
# 	if point_plane == PointPlane.X_Y:
# 		is_positively_orientated = !is_positively_orientated

# 	# ////////////////////////////////////////
# 	# TUBE BUILDER
# 	i = 0
# 	# used for proportional/tube unwrapping
# 	var total_unwrap_distance = 0

# 	# Build the tube
# 	while i != size:

# 		var index_a = VectorUtils.clamp_int(i, 0, size - 1)
# 		var index_b = VectorUtils.clamp_int(i + 1, 0, size - 1)
# 		var position_a = convert_plane_point_to_vector3(polygon_points[index_a])
# 		var position_b = convert_plane_point_to_vector3(polygon_points[index_b])

# 		var base_1 = position_a
# 		var base_2 = position_b
# 		var extr_1 = position_a + extrude_vector
# 		var extr_2 = position_b + extrude_vector

# 		var vertices = [base_1, base_2, extr_2, extr_1]
# 		var uvs = []

# 		# Used for tube unwrapping
# 		var quad_length = (position_b - position_a).length()

# 		if unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
# 			uvs = [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)]

# 		elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
# 			var b_1 = Vector2(total_unwrap_distance, 0)
# 			var b_2 = Vector2(total_unwrap_distance + quad_length, 0)
# 			var e_1 = Vector2(total_unwrap_distance, depth)
# 			var e_2 = Vector2(total_unwrap_distance + quad_length, depth)
# 			uvs = [b_1, b_2, e_2, e_1]

# 		if (depth < 0 && is_positively_orientated) || (depth >= 0 && is_positively_orientated == false):
# 			vertices = [base_1, extr_1, extr_2, base_2]
# 			var uv_1 = uvs[1]
# 			var uv_3 = uvs[3]
# 			uvs.remove(3); uvs.remove(1)
# 			uvs.push_back(uv_1);  uvs.insert(1, uv_3)

# 		onyx_mesh.add_ngon(vertices, [], [], uvs, [])

# 		total_unwrap_distance += quad_length

# 		i += 1


# 	# ////////////////////////////////////////
# 	# POLYGON CAP SOLVER

# 	var bottom_cap = []
# 	var top_cap = []

# 	var top_poly_points = polygon_points.duplicate()
# 	var bottom_poly_points = polygon_points.duplicate()
# 	var vector_mask = 0

# 	# UV calculation
# 	var top_uvs = []
# 	var bottom_uvs = []
# 	var aabb = VectorUtils.get_vertex2_array_aabb(top_poly_points)

# 	for point in top_poly_points:
# 		if unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
# 			var uv_x = (point.x - aabb[0].x) / aabb[1].x
# 			var uv_y = (point.y - aabb[0].y) / aabb[1].y
# 			top_uvs.append(Vector2(uv_x, uv_y))

# 		elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
# 			var uv_x = (point.x - aabb[0].x) - aabb[1].x
# 			var uv_y = (point.y - aabb[0].y) - aabb[1].y
# 			top_uvs.append(Vector2(uv_x, uv_y))

# 	bottom_uvs = top_uvs.duplicate()

# 	if is_positively_orientated == true:
# 		top_poly_points.invert()
# 		top_uvs.invert()
# 	else:
# 		bottom_poly_points.invert()
# 		bottom_uvs.invert()


# 	match point_plane:
# 		PointPlane.X_Z:
# 			vector_mask = 1
# 		PointPlane.X_Y:
# 			vector_mask = 2
# 		PointPlane.Z_Y:
# 			vector_mask = 0

# 	# submit it to the new OnyxMesh polygon triangulator.
# 	onyx_mesh.add_unsorted_ngon(top_poly_points, [], [], top_uvs, [], vector_mask, depth)
# 	onyx_mesh.add_unsorted_ngon(bottom_poly_points, [], [], bottom_uvs, [], vector_mask, 0)


# 	# RENDER THE MESH
# 	render_onyx_mesh()

# 	# Re-submit the handle positions based on the built faces, so other handles that aren't the
# 	# focus of a handle operation are being updated\
# 	refresh_handle_data()
# 	update_gizmo()

# 	_generate_hollow_shape()

# # ////////////////////////////////////////////////////////////
# # INHERITED CONTROL POINT FUNCTIONS

# # On initialisation, control points are built for transmitting and handling interactive points between the node and the node's gizmo.
# func build_handles():

# 	# Exit if not being run in the editor
# 	if Engine.editor_hint == false:
# 		return

# 	if polygon_points.size() == 0:
# 		return

# 	var plane_info = get_plane_info()
# 	handles.clear()

# #	print("[OnyxPolygon] ", self.get_name(), " - build_handles()")

# 	var i = 0
# 	for point in polygon_points:
# 		var new_control = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
# 		new_control.control_pos = convert_plane_point_to_vector3(point)
# 		new_control.control_name = POLYGON_CONTROL_NAME + str(i)
# 		new_control.set_type_plane(false, "handle_change", "handle_commit", plane_info["origin"], plane_info["x_up"], plane_info["y_up"])

# 		handles[new_control.control_name] = new_control
# 		i += 1

# 	# need to give it positions in the case of a duplication or scene load.
# 	refresh_handle_data()


# # Uses the current shape properties to refresh the control point data.
# func refresh_handle_data():

# 	# Exit if not being run in the editor
# 	if Engine.editor_hint == false:
# #		print("...attempted to refresh_handle_data()")
# 		return

# 	# Failsafe for script reloads, BECAUSE I CURRENTLY CAN'T DETECT THEM.
# 	if handles.size() == 0:
# 		if gizmo != null:
# #			print("...attempted to refresh_handle_data(), rebuilding handles.")
# 			gizmo.control_points.clear()
# 			build_handles()
# 			return

# #	print("[OnyxPolygon] ", self.get_name(), " - refresh_handle_data()")

# 	var i = 0
# 	for control in handles.values():
# 		control.control_pos = convert_plane_point_to_vector3(polygon_points[i])
# 		i += 1


# # Changes the control and associated property data based on the given index and coordinates.
# func update_handle_from_gizmo(control):

# 	if handles.has(control.control_name) == null:
# 		print("update_handle_from_gizmo() - no handle found, whoops.")
# 		return

# #	print("[OnyxPolygon] ", self.get_name(), " - update_handle_from_gizmo()")

# 	var index = int(control.control_name.replace(POLYGON_CONTROL_NAME, ""))
# 	if index != null:
# 		polygon_points[index] = convert_vector3_to_plane_point(control.control_pos)

# 	refresh_handle_data()


# # Applies the current control values to the shape attributes
# func apply_handle_attributes():

# #	print("[OnyxPolygon] ", self.get_name(), " - apply_handle_attributes()")

# 	var i = 0
# 	for control in handles.values():
# 		polygon_points[i] = convert_vector3_to_plane_point(control.control_pos)
# 		i += 1

# 	pass


# # Calibrates the stored properties if they need to change before the origin is updated.
# # Only called during Gizmo movements for origin auto-updating.
# func balance_handles():

# 	# > the handle data is unique and independent, no balance required.
# 	pass


# # ////////////////////////////////////////////////////////////
# # SNAP PLANE FUNCTIONS

# # Returns the info for the plane all points are to be snapped to.
# func get_plane_info() -> Dictionary:

# 	var details = {}
# 	details["origin"] = Vector3(0, 0, 0)

# 	match point_plane:
# 		PointPlane.X_Z:
# 			details["x_up"] = Vector3(1, 0, 0)
# 			details["y_up"] = Vector3(0, 0, 1)
# 		PointPlane.X_Y:
# 			details["x_up"] = Vector3(1, 0, 0)
# 			details["y_up"] = Vector3(0, 1, 0)
# 		PointPlane.Z_Y:
# 			details["x_up"] = Vector3(0, 0, 1)
# 			details["y_up"] = Vector3(0, 1, 0)

# 	return details

# # Returns the depth of the plane as a vector.
# func get_plane_depth_vector():
# 	match point_plane:
# 		PointPlane.X_Z:
# 			return Vector3(0, depth, 0)
# 		PointPlane.X_Y:
# 			return Vector3(0, 0, depth)
# 		PointPlane.Z_Y:
# 			return Vector3(depth, 0, 0)

# # Returns the AABB of the shape (lil convenience function)
# func get_polygon_aabb() -> AABB:
# 	var vector_array = []
# 	for point in polygon_points:
# 		var new_vector = convert_plane_point_to_vector3(point)
# 		vector_array.append(new_vector)
# 		vector_array.append(new_vector + get_plane_depth_vector())

# 	return VectorUtils.get_vertex_pool_aabb(PoolVector3Array(vector_array))

# # Converts a 3D vector to a 2D vector that fits along the current plane.
# func convert_vector3_to_plane_point(vector : Vector3) -> Vector2:

# 	match point_plane:
# 		PointPlane.X_Z:
# 			return Vector2(vector.x, vector.z)
# 		PointPlane.X_Y:
# 			return Vector2(vector.x, vector.y)
# 		PointPlane.Z_Y:
# 			return Vector2(vector.z, vector.y)

# 	# idk failsafe lol
# 	return Vector2()


# # Converts a 2D point on the current snap plane to a 3D object space vector.
# func convert_plane_point_to_vector3(point : Vector2) -> Vector3:
# 	match point_plane:
# 		PointPlane.X_Z:
# 			return Vector3(point.x, 0, point.y)
# 		PointPlane.X_Y:
# 			return Vector3(point.x, point.y, 0)
# 		PointPlane.Z_Y:
# 			return Vector3(0, point.y, point.x)

# 	# idk failsafe lol
# 	return Vector3()

# # ???
# # Don't know if i need a function for moving a newly made control point to the cursor yet.


# # ////////////////////////////////////////////////////////////
# # HOLLOW MODE FUNCTIONS

# # The margin options available in Hollow mode, identified by the control names that should have margins
# func get_hollow_margins() -> Array:

# #	print("[OnyxPolygon] ", self.get_name(), " - get_hollow_margins()")

# 	return [
# 		"top",
# 		"bottom",
# 		"inset",
# 	]


# # Gets the current shape parameters not controlled by handles, to apply to the hollow shape
# func assign_hollow_properties():

# 	if hollow_object == null:
# 		return

# #	print("[OnyxPolygon] ", self.get_name(), " - assign_hollow_properties()")

# #	if hollow_object.polygon_points.hash() != self.polygon_points.hash():
# #		hollow_object.polygon_points = self.polygon_points

# 	if hollow_object.depth != self.depth:
# 		hollow_object.depth = self.depth

# 	if hollow_object.polygon_points.hash() != self.polygon_points.hash():
# 		hollow_object.polygon_points = self.polygon_points


# # Assigns the hollow object an origin point based on the origin mode of this Onyx type.
# # THIS DOES NOT MODIFY THE ORIGIN TYPE OF THE HOLLOW OBJECT
# func assign_hollow_origin():

# 	if hollow_object == null:
# 		return

# #	print("[OnyxPolygon] ", self.get_name(), " - assign_hollow_origin()")

# 	var bottom_margin = get("hollow_mode/bottom_margin")
# 	hollow_object.set_translation(Vector3(0, bottom_margin, 0))


# # An override-able function used to determine how margins apply to handles
# func apply_hollow_margins(hollow_controls: Dictionary):

# 	if hollow_object == null:
# 		return

# #	print("[OnyxPolygon] ", self.get_name(), " - apply_hollow_margins(controls)")
# #	print("base onyx controls - ", handles)
# #	print("hollow controls - ", hollow_controls)

# 	# TOP CAP
# 	var top_margin = get("hollow_mode/top_margin")
# 	var bottom_margin = get("hollow_mode/bottom_margin")
# 	hollow_object.depth = depth - (top_margin + bottom_margin)

# 	# INSET MARGIN

# 	var hollow_keys = hollow_controls.keys()
# 	var inset = get("hollow_mode/inset_margin")
# 	var i = 0

# 	for hollow_control in hollow_controls.values():

# 		# Get the normal handle positions
# 		var i_0 = VectorUtils.clamp_int(i - 1, 0, hollow_controls.size() - 1)
# 		var i_2 = VectorUtils.clamp_int(i + 1, 0, hollow_controls.size() - 1)

# 		var control_0 = handles[POLYGON_CONTROL_NAME + str(i_0)]
# 		var control_1 = handles[POLYGON_CONTROL_NAME + str(i)]
# 		var control_2 = handles[POLYGON_CONTROL_NAME + str(i_2)]

# 		# Get the unit vector in-between these three points.
# 		var v_1 = control_2.control_pos - control_1.control_pos
# 		var v_2 = control_0.control_pos - control_1.control_pos
# 		var unit = (v_1 + v_2).normalized()

# 		# Pull the hollow control by the unit multiplied by the margin
# 		hollow_control.control_pos = control_1.control_pos + (unit * inset)
# 		i += 1

# 	return hollow_controls



# # ////////////////////////////////////////////////////////////

# var is_mouse_down = false

# # ////////////////////////////////////////////////////////////
# # BASE UI FUNCTIONS

# func editor_select():

# 	if is_hollow_object:
# 		return

# 	if Engine.editor_hint == true:
# 		return

# 	# Failsafe for Godot's script reload badness.
# #	plugin.remove_control_in_backup("ONYX_POLYGON_TOOLBAR")

# 	if edit_toolbar != null:
# 		edit_toolbar.queue_free()
# 		edit_toolbar = null

# 	if edit_toolbar == null:
# 		edit_toolbar = load("res://addons/onyx/ui/onyx_polygon_toolbar.tscn").instance()
# 		edit_toolbar = get_plugin().add_toolbar(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, edit_toolbar, "onyx_polygon_toolbar")
# 		edit_toolbar.connect("edit_mode_changed", self, "_change_edit_mode")

# #		plugin.add_control_to_backup(EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, edit_toolbar, "ONYX_POLYGON_TOOLBAR")


# func editor_deselect():

# 	if is_hollow_object:
# 		return

# 	if Engine.editor_hint == true:
# 		return

# 	get_plugin().remove_toolbar(owner, EditorPlugin.CONTAINER_SPATIAL_EDITOR_BOTTOM, "onyx_polygon_toolbar")

# 	if edit_toolbar != null:
# 		edit_toolbar.disconnect("edit_mode_changed", self, "_change_edit_mode")
# 		edit_toolbar.queue_free()
# 		edit_toolbar = null


# # called by Onyx when a toolbar of this node is being removed.
# func deallocate_toolbar(toolbar):
# 	edit_toolbar.disconnect("edit_mode_changed", self, "_change_edit_mode")
# 	edit_toolbar.queue_free()

# func receive_gui_input(camera, event):

# 	if edit_toolbar == null || is_hollow_object:
# 		return

# 	if event.is_class("InputEventMouse") == false:
# 		return

# #	print("EDIT MODE - ", edit_toolbar.edit_mode)


# 	match edit_toolbar.edit_mode:
# 		0: # NONE
# 			pass
# 		1: # MOVE
# 			pass
# 		2: # ADD
# 			return _receive_input_add_mode(camera, event)
# 		3: # INSERT
# 			return _receive_input_insert_mode(camera, event)
# 		4: # DELETE
# 			pass
# 	return false

# func _change_edit_mode(old_edit_mode, new_edit_mode):

# 	if is_hollow_object:
# 		return

# 	# If the old edit mode is Delete, switch the handle type to Free
# 	if old_edit_mode == 4:
# 		for control in handles.values():
# 			control.set_type_free(true, "handle_change", "handle_commit")

# 	# If the new edit mode is Delete, switch the handle type to Delete
# 	elif new_edit_mode == 4:
# 		for control in handles.values():
# 			control.set_type_click(true, "delete_control_point")


# func _receive_input_add_mode(camera, event):

# 	if event.is_class("InputEventMouse") == false:
# 		return

# #	print(event)

# 	if event.is_class("InputEventMouseButton"):
# 		if is_mouse_down != event.pressed && event.button_index == BUTTON_LEFT:
# 			if event.pressed == true:
# 				var plane = get_plane_info()
# 				var mouse_pos = event.position
# 				var world_tf = self.global_transform

# 				var spawn_position = VectorUtils.project_cursor_to_plane(camera, mouse_pos, world_tf, plane["origin"], plane["x_up"], plane["y_up"])
# 				add_control_point(spawn_position)

# 			# If we have a mouse up event and we didnt before, finish the edit and generate geometry.
# 			if event.pressed == false:
# 				pass

# 			is_mouse_down = event.pressed
# 			return true

# 	# If it hasn't changed, check what mode we're in
# 	else:
# 		if is_mouse_down == true:
# 			pass

# 		if is_mouse_down == false:
# 			pass

# 	return false

# func _receive_input_insert_mode(camera, event):

# 	if event.is_class("InputEventMouse") == false:
# 		return

# 	if event.is_class("InputEventMouseButton"):
# 		if is_mouse_down != event.pressed && event.button_index == BUTTON_LEFT:
# 			if event.pressed == true:
# 				var plane = get_plane_info()
# 				var mouse_pos = event.position
# 				var world_tf = self.global_transform

# 				var spawn_position = VectorUtils.project_cursor_to_plane(camera, mouse_pos, world_tf, plane["origin"], plane["x_up"], plane["y_up"])
# 				insert_control_point(spawn_position)

# 			# If we have a mouse up event and we didnt before, finish the edit and generate geometry.
# 			if event.pressed == false:
# 				pass

# 			is_mouse_down = event.pressed
# 			return true


# # ////////////////////////////////////////////////////////////
# # UI EDITOR FUNCTIONS
# # Adds a control point using a 3D position
# func add_control_point(position : Vector3):

# 	var modified_position = position

# 	# If we have snapping enabled, modify the position.
# 	if get_plugin().snap_gizmo_enabled == true:
# 		var snap_inc = get_plugin().snap_gizmo_increment
# 		var snap_t = get_global_transform()
# 		modified_position = VectorUtils.snap_position(position, Vector3(snap_inc, snap_inc, snap_inc), snap_t)


# 	var plane_info = get_plane_info()

# 	var new_control = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
# 	new_control.control_pos = modified_position
# 	new_control.control_name = POLYGON_CONTROL_NAME + str(polygon_points.size())
# 	new_control.set_type_plane(false, "handle_change", "handle_commit", plane_info["origin"], plane_info["x_up"], plane_info["y_up"])

# 	var plane_point = convert_vector3_to_plane_point(modified_position)

# 	polygon_points.append(plane_point)
# 	handles[new_control.control_name] = new_control

# 	update_geometry()
# 	update_gizmo()

# # Inserts a control point between the two closest points.
# func insert_control_point(position : Vector3):

# 	var modified_position = position

# 	# If we have snapping enabled, modify the position.
# 	if get_plugin().snap_gizmo_enabled == true:
# 		var snap_inc = get_plugin().snap_gizmo_increment
# 		var snap_t = get_global_transform()
# 		modified_position = VectorUtils.snap_position(position, Vector3(snap_inc, snap_inc, snap_inc), snap_t)

# #	print(handles.keys())

# 	# Now figure out which line its closest to.
# 	# TODO - This system really isn't accurate.
# 	var closest_points = []
# 	var closest_distance = 0.0
# 	var i = 0
# 	for control in handles.values():
# 		var control_i2 = VectorUtils.clamp_int(i + 1, 0, handles.size() - 1)
# 		var control_2 = handles[POLYGON_CONTROL_NAME + str(control_i2)]
# 		var control_p1 = control.control_pos
# 		var control_p2 = control_2.control_pos

# 		var point_p1 = convert_vector3_to_plane_point(control_p1)
# 		var point_p2 = convert_vector3_to_plane_point(control_p2)
# 		var check = convert_vector3_to_plane_point(modified_position)

# 		var result = VectorUtils.find_distance_from_segment_2d(check, point_p1, point_p2)

# #		var distance_1 = modified_position.distance_to(control_p1)
# #		var distance_2 = modified_position.distance_to(control_p2)
# #		var result = (distance_1 + distance_2) / 2

# 		if closest_distance == 0 || closest_distance > result:
# 			closest_distance = result
# 			closest_points = [control, control_2]

# 		i += 1

# 	var plane_info = get_plane_info()
# 	var insert_index = int(closest_points[0].control_name.replace(POLYGON_CONTROL_NAME, "")) + 1

# 	var new_control = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
# 	new_control.control_pos = modified_position
# 	new_control.control_name = POLYGON_CONTROL_NAME + str(insert_index)
# 	new_control.set_type_plane(false, "handle_change", "handle_commit", plane_info["origin"], plane_info["x_up"], plane_info["y_up"])

# 	# Rename all the controls above it
# 	var handle_slice = []
# 	var size = handles.size()
# 	i = insert_index
# 	while i < size:
# 		var rename_target = handles[POLYGON_CONTROL_NAME + str(i)]
# 		handle_slice.append(rename_target)
# 		handles.erase(POLYGON_CONTROL_NAME + str(i))
# 		i += 1

# 	i = insert_index + 1
# 	for handle in handle_slice:
# 		handle.control_name = POLYGON_CONTROL_NAME + str(i)
# 		handles[POLYGON_CONTROL_NAME + str(i)] = handle
# 		i += 1

# 	# Insert the new control
# 	var plane_point = convert_vector3_to_plane_point(modified_position)

# 	polygon_points.insert(insert_index, plane_point)
# 	handles[new_control.control_name] = new_control

# 	rename_control_points()
# 	update_geometry()
# 	update_gizmo()

# # Deletes the control point with the specified control.
# func delete_control_point(control):

# 	var index = int(control.control_name.replace(POLYGON_CONTROL_NAME, ""))
# 	if handles.has(control.control_name) == false || polygon_points.size() <= index:
# 		return

# 	polygon_points.remove(index)
# 	handles.erase(control.control_name)

# 	rename_control_points()
# 	update_geometry()

# # Used after a deletion or insertion to rename all other control points to be sequential
# func rename_control_points():

# 	if handles.size() == 0:
# 		return

# 	# We also need to change the keys...
# 	var old_handle_stack = handles.duplicate()
# 	handles.clear()

# 	var i = 0
# 	for control in old_handle_stack.values():
# 		control.control_name = POLYGON_CONTROL_NAME + str(i)
# 		handles[control.control_name] = control
# 		i += 1

