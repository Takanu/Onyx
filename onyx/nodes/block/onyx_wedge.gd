tool
extends CSGMesh

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

# allows origin point re-orientation, for precise alignments and convenience.
enum OriginPosition {CENTER, BASE, BASE_CORNER}
export(OriginPosition) var origin_setting = OriginPosition.BASE setget update_origin_mode

# used to keep track of how to move the origin point into a new position.
var previous_origin_setting = OriginPosition.BASE

# used to force an origin update when using the sliders to adjust positions.
export(bool) var update_origin_setting = true setget update_positions

# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to
var plugin

# The face set script, used for managing geometric data.
var onyx_mesh = OnyxMesh.new()

# Materials assigned to gizmos.
var gizmo_mat = load("res://addons/onyx/materials/gizmo_t1.tres")

# The handle points that will be used to resize the cube (NOT built in the format required by the gizmo)
var handles = []

# The handle points designed to provide the gizmo with information on how it should operate.
var gizmo_handles = []

# Old handle points that are saved every time a handle has finished moving.
var old_handles = []

# The offset of the origin relative to the rest of the shape.
var origin_offset = Vector3(0, 0, 0)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

var color = Vector3(1, 1, 1)

# Exported variables representing all usable handles for re-shaping the mesh, in order.
# Must be exported to be saved in a scene?  smh.
export(Vector3) var point_position = Vector3(0, 1, 0) setget update_point_position
export(float) var point_size = 2 setget update_point_size
export(float) var base_x_size = 2 setget update_base_x_size
export(float) var base_z_size = 2 setget update_base_z_size
export(bool) var keep_shape_proportional = false setget update_proportional_toggle

# UVS
enum UnwrapMethod {DIRECT_OVERLAP, PROPORTIONAL_OVERLAP, DIRECT_ZONE, PROPORTIONAL_ZONE}
export(UnwrapMethod) var unwrap_method = UnwrapMethod.DIRECT_OVERLAP setget update_unwrap_method

export(Vector2) var uv_scale = Vector2(1.0, 1.0) setget update_uv_scale
export(bool) var flip_uvs_horizontally = false setget update_flip_uvs_horizontally
export(bool) var flip_uvs_vertically = false setget update_flip_uvs_vertically

# MATERIALS
export(Material) var material = null setget update_material


# ////////////////////////////////////////////////////////////
# FUNCTIONS


# Global initialisation
func _enter_tree():
		
	# Load and generate geometry
	generate_geometry(true) 
		
	# set gizmo stuff
#	old_handles = onyx_mesh.get_all_centre_points()
		
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:
		
		# load gizmos
		plugin = get_node("/root/EditorNode/Onyx")
		
		var new_gizmo = plugin.create_spatial_gizmo(self)
		self.set_gizmo(new_gizmo)
		print(gizmo)
		
		set_notify_local_transform(true)
		set_notify_transform(true)
		set_ignore_transform_notification(false)
		
	
func _ready():
	pass

	
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
	if new_value < 3:
		new_value = 3
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
	
	if previous_origin_setting == new_value:
		return
	
	origin_setting = new_value
	update_origin()
	balance_handles()
	generate_geometry(true)
	previous_origin_setting = origin_setting
	

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
	
#	if handles.size() == 0:
#		return
	
	var max_x = 0
	if base_x_size < point_size:
		max_x = point_size
	else:
		max_x = base_x_size

	
	# based on the current position and properties, work out how much to move the origin.
	var diff = Vector3(0, 0, 0)

	match previous_origin_setting:

		OriginPosition.CENTER:
			match origin_setting:

				OriginPosition.BASE:
					diff = Vector3(0, -point_position.y / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-max_x / 2, -point_position.y / 2, -base_z_size / 2)

		OriginPosition.BASE:
			match origin_setting:

				OriginPosition.CENTER:
					diff = Vector3(0, point_position.y / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(-max_x / 2, 0, -base_z_size / 2)

		OriginPosition.BASE_CORNER:
			match origin_setting:

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
		
	match origin_setting:
		OriginPosition.CENTER:
			position = Vector3(0, -point_position.y / 2, 0)
		OriginPosition.BASE:
			position = Vector3(0, 0, 0)
		OriginPosition.BASE_CORNER:
			position = Vector3(max_x / 2, 0, base_z_size / 2)
			
	
	var mesh_factory = OnyxMeshFactory.new()
	onyx_mesh = mesh_factory.build_wedge(base_x_size, base_z_size, point_size, point_position, position)
	render_onyx_mesh()
	
	# UPDATE HANDLES
	# dumbass reminder - handles are in local space
	
#	var aabb = AABB(position, Vector3(x_width, height_max - height_min, z_width))
#
#	# Re-submit the handle positions based on the built faces, so other handles that aren't being actively edited are updated to
#	# reflect the new mesh shape and bounds.
#	handles = []
#	handles.append(Vector3(0, aabb.position.y + aabb.size.y, 0))
#	handles.append(Vector3(0, aabb.position.y, 0))
#	handles.append(Vector3(x_width, aabb.position.y + (aabb.size.y / 2), 0))
#	handles.append(Vector3(0, aabb.position.y + (aabb.size.y / 2), z_width))
#
#	print("new handles = ", handles)
	
	# Build handle points in the required gizmo format.
#	var face_list = face_set.get_face_vertices()
#
#	gizmo_handles = []
#	for i in handles.size():
#		gizmo_handles.append([handles[i], face_list[i] ])
#
#	# Submit the changes to the gizmo
#	if gizmo:
#		#gizmo.add_handles(gizmo_handles, gizmo_mat)
#
#		# disabled during alpha
#		update_gizmo()
	

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
#	match origin_setting:
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
 
