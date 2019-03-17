tool
extends CSGMesh

# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var OnyxUtils = load("res://addons/onyx/nodes/block/onyx_utils.gd")
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

# allows origin point re-orientation, for precise alignments and convenience.
enum OriginPosition {CENTER, BASE, BASE_CORNER}
export(OriginPosition) var origin_mode = OriginPosition.BASE setget update_origin_mode

# used to keep track of how to move the origin point into a new position.
var previous_origin_mode = OriginPosition.BASE

# used to force an origin update when using the sliders to adjust positions.
export(bool) var update_origin_setting = true setget update_positions

# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to
var plugin

# The face set script, used for managing geometric data.
var onyx_mesh = OnyxMesh.new()

# The handle points that will be used to resize the cube (NOT built in the format required by the gizmo)
var handles = []

# Old handle points that are saved every time a handle has finished moving.
var old_handles = []

# The offset of the origin relative to the rest of the shape.
var origin_offset = Vector3(0, 0, 0)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)


# Exported variables representing all usable handles for re-shaping the mesh, in order.
# Must be exported to be saved in a scene?  smh.
export(Vector3) var point_position = Vector3(0, 1, 0) setget update_point_position
export(float) var point_size = 2 setget update_point_size
export(float) var base_x_size = 2 setget update_base_x_size
export(float) var base_z_size = 2 setget update_base_z_size
export(bool) var keep_shape_proportional = false setget update_proportional_toggle

# UVS
enum UnwrapMethod {PROPORTIONAL_OVERLAP, DIRECT_OVERLAP}
export(UnwrapMethod) var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP setget update_unwrap_method

export(Vector2) var uv_scale = Vector2(1.0, 1.0) setget update_uv_scale
export(bool) var flip_uvs_horizontally = false setget update_flip_uvs_horizontally
export(bool) var flip_uvs_vertically = false setget update_flip_uvs_vertically

# MATERIALS
export(Material) var material = null setget update_material


# ////////////////////////////////////////////////////////////
# FUNCTIONS


# Global initialisation
func _enter_tree():
	#print("ONYXCUBE _enter_tree")
		
	# Load and generate geometry
	#generate_geometry(true) 
		
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:
		
		# load plugin
		plugin = get_node("/root/EditorNode/Onyx")

		set_notify_local_transform(true)
		set_notify_transform(true)
		set_ignore_transform_notification(false)
		
		

func _exit_tree():
    pass
	
func _ready():
	# Only generate geometry if we have nothing and we're running inside the editor, this likely indicates the node is brand new.
	if Engine.editor_hint == true:
		if mesh == null:
			generate_geometry(true)

	
func _notification(what):
	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
		
		# check that transform changes are local only
		if local_tracked_pos != translation:
			local_tracked_pos = translation
			call_deferred("_editor_transform_changed")
		
func _editor_transform_changed():
	pass

				
# ////////////////////////////////////////////////////////////
# PROPERTY UPDATERS

# Used when a handle variable changes in the properties panel.
func update_point_size(new_value):
	if new_value < 0:
		new_value = 0
	point_size = new_value
	generate_geometry(true)
	
func update_point_position(new_value):
	point_position = new_value
	generate_geometry(true)
	
func update_base_x_size(new_value):
	if new_value < 0:
		new_value = 0
	
	if keep_shape_proportional == true:
		base_z_size = new_value
		
	base_x_size = new_value
	generate_geometry(true)
	
func update_base_z_size(new_value):
	if new_value < 0:
		new_value = 0
		
	if keep_shape_proportional == true:
		base_x_size = new_value
		
	base_z_size = new_value
	generate_geometry(true)
	
func update_proportional_toggle(new_value):
	keep_shape_proportional = new_value
	update_origin()
	balance_handles()
	generate_geometry(true)
	
# Used to recalibrate both the origin point location and the position handles.
func update_positions(new_value):
	update_origin_setting = true
	update_origin()
	balance_handles()
	generate_geometry(true)
	
# Changes the origin position relative to the shape and regenerates geometry and handles.
func update_origin_mode(new_value):
	
	if previous_origin_mode == new_value:
		return
	
	origin_mode = new_value
	update_origin()
	balance_handles()
	generate_geometry(true)
	previous_origin_mode = origin_mode
	

func update_unwrap_method(new_value):
	unwrap_method = new_value
	generate_geometry(true)

func update_uv_scale(new_value):
	uv_scale = new_value
	generate_geometry(true)

func update_flip_uvs_horizontally(new_value):
	flip_uvs_horizontally = new_value
	generate_geometry(true)
	
func update_flip_uvs_vertically(new_value):
	flip_uvs_vertically = new_value
	generate_geometry(true)

func update_material(new_value):
	material = new_value
	
	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return
	
	# If we don't have an onyx_mesh with any data in it, we need to construct that first to apply a material to it.
	if onyx_mesh.tris == null:
		generate_geometry(true)
	
	var array_mesh = onyx_mesh.render_surface_geometry(material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	set_mesh(mesh)

# Updates the origin during generate_geometry() as well as the currently defined handles, 
# to ensure it's anchored where it needs to be.
func update_origin():
	
# 	print("updating origin222...")
	
	# Used to prevent the function from triggering when not inside the tree.
	# This happens during duplication and replication and causes incorrect node placement.
	if self.is_inside_tree() == false:
		return
	
	# Re-add once handles are a thing, otherwise this breaks the origin stuff.
#	if handles.size() == 0:
#		return
	
	var max_x = 0
	if base_x_size < point_size:
		max_x = point_size
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

	# Get the difference
	var new_loc = self.translation + diff
	var old_loc = self.translation
# 	print("MOVING LOCATION: ", old_loc, " -> ", new_loc)

	# set it
	self.global_translate(new_loc - old_loc)
	

# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting):
	
	# Ensure the geometry is generated to fit around the current origin point.
	var position = Vector3(0, 0, 0)
	var max_x = 0
	if base_x_size < point_size:
		max_x = point_size
	else:
		max_x = base_x_size
		
	match origin_mode:
		OriginPosition.CENTER:
			position = Vector3(0, -point_position.y / 2, 0)
		OriginPosition.BASE:
			position = Vector3(0, 0, 0)
		OriginPosition.BASE_CORNER:
			position = Vector3(max_x / 2, 0, base_z_size / 2)
			
	
	# GENERATE MESH
	onyx_mesh.clear()
	
	#   X---------X  b1 b2
	#	|         |
	#		X---------X   p2 p1
	#	|		  |
	#   X---------X  b3 b4
	
	var base_1 = Vector3(base_x_size/2, 0, base_z_size/2) + position
	var base_2 = Vector3(-base_x_size/2, 0, base_z_size/2) + position
	
	var base_3 = Vector3(base_x_size/2, 0, -base_z_size/2) + position
	var base_4 = Vector3(-base_x_size/2, 0, -base_z_size/2) + position
	
	var point_1 = Vector3(-point_size/2 + point_position.x, point_position.y, point_position.z) + position
	var point_2 = Vector3(point_size/2 + point_position.x, point_position.y, point_position.z) + position
	
	# UVS
	var left_triangle_uv = []
	var right_triangle_uv = []
	var bottom_quad_uv = []
	var top_quad_uv = []
	var base_uv = []
	
	if unwrap_method == UnwrapMethod.DIRECT_OVERLAP:
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
		var median_point = Vector3(0.0, point_position.y, point_position.z)
		var median_bottom_point = Vector3(0.0, 0.0, -base_z_size / 2)
		var median_top_point = Vector3(0.0, 0.0, base_z_size / 2)
		
		var bottom_quad_length = (median_point - median_bottom_point).length()
		var top_quad_length = (median_point - median_top_point).length()
		bottom_quad_uv = [Vector2(-point_2.x, 0.0), Vector2(-point_1.x, 0.0), Vector2(-base_4.x, bottom_quad_length), Vector2(-base_3.x, bottom_quad_length)]
		top_quad_uv = [Vector2(-point_1.x, 0.0), Vector2(-point_2.x, 0.0), Vector2(-base_1.x, top_quad_length), Vector2(-base_2.x, top_quad_length)]
		
		# Base UVs
		base_uv = [Vector2(base_1.x, base_1.z), Vector2(base_2.x, base_2.z), Vector2(base_4.x, base_4.z), Vector2(base_3.x, base_3.z)]
	
	onyx_mesh.add_tri([base_1, point_2, base_3], [], [], left_triangle_uv, [])
	onyx_mesh.add_tri([base_4, point_1, base_2], [], [], right_triangle_uv, [])
	onyx_mesh.add_ngon([point_2, point_1, base_4, base_3], [], [], bottom_quad_uv, [])
	onyx_mesh.add_ngon([point_1, point_2, base_1, base_2], [], [], top_quad_uv, [])
	onyx_mesh.add_ngon([base_2, base_1, base_3, base_4], [], [], base_uv, [])
	
	render_onyx_mesh()
	

func render_onyx_mesh():
	
	# Optional UV Modifications
	var tf_vec = uv_scale
	if tf_vec.x == 0:
		tf_vec.x = 0.0001
	if tf_vec.y == 0:
		tf_vec.y = 0.0001
	
#		if self.invert_faces == true:
#			tf_vec.x = tf_vec.x * -1.0
	if flip_uvs_vertically == true:
		tf_vec.y = tf_vec.y * -1.0
	if flip_uvs_horizontally == true:
		tf_vec.x = tf_vec.x * -1.0
	
	onyx_mesh.multiply_uvs(tf_vec)
	
	# Create new mesh
	var array_mesh = onyx_mesh.render_surface_geometry(material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	# Set the new mesh
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	set_mesh(mesh)


# ////////////////////////////////////////////////////////////
# EDIT STATE

func get_undo_state():
	return [old_handles, self.translation]

func get_redo_state():
	return [handles, self.translation]

# Restores the state of the cube to a previous given state.
func restore_state(state):
	pass
#	var new_handles = state[0]
#	var stored_translation = state[1]
#
#	handles[0] = height_max
#	handles[1] = height_min
#	handles[2] = x_width
#	handles[3] = z_width
#
#	height_max = handles[0]
#	height_min = handles[1]
#	x_width = handles[2]
#	z_width = handles[3]
#
#	self.translation = stored_translation
#	self.old_handles = new_handles
#	generate_geometry(true)


# Notifies the node that a handle has changed.
func handle_change(index, coord):
	
	change_handle(index, coord)
	generate_geometry(false)
	

# Called when a handle has stopped being dragged.
func handle_commit(index, coord):
	
	change_handle(index, coord)
	update_origin()
	balance_handles()
	generate_geometry(true)
	
	# store old handle points for later.
#	old_handles = face_set.get_all_centre_points()
	
			
# Returns the handle with the corresponding coordinates.	
func get_handle(index):
	
	return handles[index]
	

# Changes the handle based on the given index and coordinates.
func change_handle(index, coordinate):
	pass
	
#	match index:
#		0: x_plus_position = coordinate.x
#		1: x_minus_position = coordinate.x
#		2: y_plus_position = coordinate.y
#		3: y_minus_position = coordinate.y
#		4: z_plus_position = coordinate.z
#		5: z_minus_position = coordinate.z
	
	
# Moves the handle by the given index and coordinate offset.
func move_handle(index, coordinate):
	pass
	
#	match index:
#		0: x_plus_position += coordinate.x
#		1: x_minus_position += coordinate.x
#		2: y_plus_position += coordinate.y
#		3: y_minus_position += coordinate.y
#		4: z_plus_position += coordinate.z
#		5: z_minus_position += coordinate.z
	
	
func balance_handles():
	pass
#	match origin_mode:
#		OriginPosition.CENTER:
#			var diff = abs(height_max - height_min)
#			height_max = diff / 2
#			height_min = (diff / 2) * -1
#
#		OriginPosition.BASE:
#			var diff = abs(height_max - height_min)
#			height_max = diff
#			height_min = 0
#
#		OriginPosition.BASE_CORNER:
#			var diff = abs(height_max - height_min)
#			height_max = diff
#			height_min = 0
#
#	print("balanced handles: ", height_max, height_min)
	
	
# Updates the collision triangles responsible for detecting cursor selection in the editor.
func get_gizmo_collision():
	pass
#	var triangles = onyx_mesh.get_triangles()
#
#	var return_t = PoolVector3Array()
#	for triangle in triangles:
#		return_t.append(triangle * 10)
#
#	return return_t
	
	
# ////////////////////////////////////////////////////////////
# SELECTION

func editor_select():
	pass
	
	
func editor_deselect():
	pass
	
	

# ////////////////////////////////////////////////////////////
# HELPERS
 
