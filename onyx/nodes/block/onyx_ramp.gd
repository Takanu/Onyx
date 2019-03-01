tool
extends CSGMesh

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

# allows origin point re-orientation, for precise alignments and convenience.
# NOT AVAILABLE ON TYPES WITH SPLINES OR POSITION POINTS.

#enum OriginPosition {CENTER, BASE, BASE_CORNER}
#export(OriginPosition) var origin_mode = OriginPosition.BASE setget update_origin_mode
#var previous_origin_mode = OriginPosition.BASE
#export(bool) var update_origin_setting = true setget update_positions

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
export(Vector3) var start_position = Vector3(0, 0, 0) setget update_start_position
export(Vector3) var start_rotation = Vector3(0, 0, 0) setget update_start_rotation
export(Vector3) var end_position = Vector3(0, 1, 2) setget update_end_position
export(Vector3) var end_rotation = Vector3(0, 0, 0) setget update_end_rotation

export(float) var ramp_width = 2 setget update_ramp_width
export(float) var ramp_depth = 0.5 setget update_ramp_depth
export(bool) var maintain_width = true setget update_maintain_width
export(int) var iterations = 0 setget update_iterations

enum RampFillType {NONE, MINUS_Y, PLUS_Y}
export(RampFillType) var ramp_fill_type = RampFillType.NONE setget update_ramp_fill_type

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
	#print("ONYXCUBE _enter_tree")
		
		
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
func update_start_position(new_value):
	start_position = new_value
	generate_geometry(true)
	
func update_start_rotation(new_value):
	start_rotation = new_value
	generate_geometry(true)
	
func update_end_position(new_value):
	end_position = new_value
	generate_geometry(true)
	
func update_end_rotation(new_value):
	end_rotation = new_value
	generate_geometry(true)
	
func update_ramp_width(new_value):
	if new_value < 0:
		new_value = 0
		
	ramp_width = new_value
	generate_geometry(true)
	
func update_ramp_depth(new_value):
	if new_value < 0:
		new_value = 0
		
	ramp_depth = new_value
	generate_geometry(true)
	
func update_maintain_width(new_value):
	maintain_width = new_value
	generate_geometry(true)
	
func update_iterations(new_value):
	if new_value < 0:
		new_value = 0
	iterations = new_value
	generate_geometry(true)
	
func update_ramp_fill_type(new_value):
	ramp_fill_type = new_value
	generate_geometry(true)
	
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
	
	# Prevents geometry generation if the node hasn't loaded yet, otherwise it will try to set a blank mesh.
	if is_inside_tree() == false:
		return
	
	var array_mesh = onyx_mesh.render_surface_geometry(material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	set_mesh(mesh)
	

# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting):
	
	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return
	
	# Get some basic transform data.
	var position = Vector3(0, 0, 0)
	var start_tf = Transform(Basis(start_rotation), start_position)
	var end_tf = Transform(Basis(end_rotation), end_position)
	
	var mesh_factory = OnyxMeshFactory.new()
	onyx_mesh = mesh_factory.build_ramp(start_tf, end_tf, ramp_width, ramp_depth, maintain_width, iterations, ramp_fill_type, position)
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
	
#	if self.invert_faces == true:
#		tf_vec.x = tf_vec.x * -1.0
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
	#update_origin()
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
 
