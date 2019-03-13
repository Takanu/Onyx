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
export(int) var horizontal_iterations = 0 setget update_horizontal_iterations
export(int) var vertical_iterations = 0 setget update_vertical_iterations

enum RampFillType {NONE, MINUS_Y, PLUS_Y}
export(RampFillType) var ramp_fill_type = RampFillType.NONE setget update_ramp_fill_type

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
	
func update_horizontal_iterations(new_value):
	if new_value < 0:
		new_value = 0
	horizontal_iterations = new_value
	generate_geometry(true)
	
func update_vertical_iterations(new_value):
	if new_value < 0:
		new_value = 0
	vertical_iterations = new_value
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
		
	# If we don't have an onyx_mesh with any data in it, we need to construct that first to apply a material to it.
	if onyx_mesh.tris == null:
		generate_geometry(true)
	
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
	
	
	# GENERATION START
	
	#   X---------X  e1 e2
	#	|         |  e3 e4
	#	|         |
	#	|         |
	#   X---------X  s1 s2
	#   X---------X  s3 s4
	
	onyx_mesh.clear()
	
	# get main 4 vectors
	var v1 = Vector3(-ramp_width/2, ramp_depth/2, 0)
	var v2 = Vector3(ramp_width/2, ramp_depth/2, 0)
	var v3 = Vector3(-ramp_width/2, -ramp_depth/2, 0)
	var v4 = Vector3(ramp_width/2, -ramp_depth/2, 0)
	
	# Get our top and bottom iteration lists.
	var top_verts = OnyxUtils.subdivide_edge(v1, v2, vertical_iterations)
	var bottom_verts = OnyxUtils.subdivide_edge(v3, v4, vertical_iterations)
	
	# Transform each set to the start and finish
	var top_start_verts = OnyxUtils.transform_vector3_array(top_verts, start_tf)
	var bottom_start_verts = OnyxUtils.transform_vector3_array(bottom_verts, start_tf)
	var top_end_verts = OnyxUtils.transform_vector3_array(top_verts, end_tf)
	var bottom_end_verts = OnyxUtils.transform_vector3_array(bottom_verts, end_tf)
#
	# ramp fill type conditionals
	if ramp_fill_type == 1:
		for i in top_verts.size():
			bottom_end_verts[i].y = bottom_start_verts[i].y

	elif ramp_fill_type == 2:
		for i in top_verts.size():
			top_start_verts[i].y = top_end_verts[i].y
	
	# Metrics for use in unwrapping operations
	var width = (top_start_verts[1] - top_start_verts[0]).length()
	var height = (top_start_verts[0] - bottom_start_verts[0]).length()
	var total_width = width * top_verts.size() - 1
	var cumulative_width = total_width
	
	for i in range( top_verts.size() - 1 ):
		var s1 = top_start_verts[i]
		var s2 = top_start_verts[i + 1]
		var s3 = bottom_start_verts[i]
		var s4 = bottom_start_verts[i + 1]
		
		var e1 = top_end_verts[i]
		var e2 = top_end_verts[i + 1]
		var e3 = bottom_end_verts[i]
		var e4 = bottom_end_verts[i + 1]
		
		# UVS
		var front_uvs = []
		var back_uvs = []
		
		if unwrap_method == UnwrapMethod.DIRECT_OVERLAP:
			front_uvs = [Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)]
			back_uvs = [Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)]
		
		elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
			var uv_1 = Vector2(cumulative_width, height)
			var uv_2 = Vector2(cumulative_width - width, height)
			var uv_3 = Vector2(cumulative_width - width, 0)
			var uv_4 = Vector2(cumulative_width, 0)
			
			front_uvs = [uv_1, uv_2, uv_3, uv_4]
			back_uvs = [uv_2, uv_1, uv_4, uv_3]
			cumulative_width -= width
			
		onyx_mesh.add_ngon([s3, s4, s2, s1], [], [], front_uvs, [])
		onyx_mesh.add_ngon([e4, e3, e1, e2], [], [], back_uvs, [])
		

	# calculate horizontal_iterations
	var bumped_h_iterations = horizontal_iterations + 1
	var increment = 1.0/float(bumped_h_iterations)
	var current_percentage = 0
	var position_diff = end_position - start_position
	var rotation_diff = end_rotation - start_rotation
	
	cumulative_width = total_width
	var cumulative_length = 0
	
	var i = 0
	while i < bumped_h_iterations:
		current_percentage = float(i) / bumped_h_iterations
		
		# transform the starts and ends by the interpolation between the start and end transformation
		var start_percentage = float(i) / bumped_h_iterations
		var end_percentage = float(i + 1) / bumped_h_iterations
		
		var s_pos = start_position + (position_diff * current_percentage)
		var e_pos = start_position + (position_diff * (current_percentage + increment) )
		var s_rot = start_rotation + (rotation_diff * current_percentage)
		var e_rot = start_rotation + (rotation_diff * (current_percentage + increment) )
		
		var s_tf = Transform(Basis(s_rot), s_pos)
		var e_tf = Transform(Basis(e_rot), e_pos)
		
		# Transform the vertex sets
		var m1_top = OnyxUtils.transform_vector3_array(top_verts, s_tf)
		var m1_bottom = OnyxUtils.transform_vector3_array(bottom_verts, s_tf)
		var m2_top = OnyxUtils.transform_vector3_array(top_verts, e_tf)
		var m2_bottom = OnyxUtils.transform_vector3_array(bottom_verts, e_tf)
		
		var start_uv_z = 0
		var end_uv_z = 1
		var quad_width = (m1_top[1] - m1_top[0]).length()
		var quad_length = (m2_top[0] - m1_top[0]).length()
		
		# Iterate through the arrays to build the faces
		for i in range(m1_top.size() - 1):
			var s1 = m1_top[i]
			var s2 = m1_top[i + 1]
			var s3 = m1_bottom[i]
			var s4 = m1_bottom[i + 1]
		
			var e1 = m2_top[i]
			var e2 = m2_top[i + 1]
			var e3 = m2_bottom[i]
			var e4 = m2_bottom[i + 1]
			
			# UVS
			var top_uvs = []
			var bottom_uvs = []
			
			# 0 - DIRECT OVERLAP
			if unwrap_method == UnwrapMethod.DIRECT_OVERLAP:
				top_uvs = [Vector2(1.0, end_uv_z), Vector2(0.0, end_uv_z), Vector2(0.0, start_uv_z), Vector2(1.0, start_uv_z)]
				bottom_uvs = top_uvs
		
			# 1 - PROPORTIONAL OVERLAP
			elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
				var uv_1 = Vector2(cumulative_width, cumulative_length)
				var uv_2 = Vector2(cumulative_width - quad_width, cumulative_length)
				var uv_3 = Vector2(cumulative_width - quad_width, cumulative_length - quad_length)
				var uv_4 = Vector2(cumulative_width, cumulative_length - quad_length)
			
				top_uvs = [uv_1, uv_2, uv_3, uv_4]
				bottom_uvs = [uv_4, uv_3, uv_2, uv_1]
				cumulative_width -= quad_width
				
					
			onyx_mesh.add_ngon([s1, s2, e2, e1], [], [], top_uvs, [])
			onyx_mesh.add_ngon([e3, e4, s4, s3], [], [], bottom_uvs, [])
			
			var iteration_uvs = []
			
		
		# Build the sides.
		var right_cap_id = m1_top.size() - 1
		var right_cap = [m1_bottom[right_cap_id], m2_bottom[right_cap_id], m2_top[right_cap_id], m1_top[right_cap_id]]
		var left_cap = [m2_bottom[0], m1_bottom[0], m1_top[0], m2_top[0]]
		
		var right_uvs = []
		var left_uvs = []
		
		# 0 - DIRECT OVERLAP
		if unwrap_method == UnwrapMethod.DIRECT_OVERLAP:
			right_uvs = [Vector2(1.0, end_uv_z), Vector2(0.0, end_uv_z), Vector2(0.0, start_uv_z), Vector2(1.0, start_uv_z)]
			left_uvs = [Vector2(1.0, end_uv_z), Vector2(0.0, end_uv_z), Vector2(0.0, start_uv_z), Vector2(1.0, start_uv_z)]
	
		# 1 - PROPORTIONAL OVERLAP
		elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
			var quad_height = (m1_top[0] - m1_bottom[0]).length()
				
			var uv_1 = Vector2(cumulative_length, 0)
			var uv_2 = Vector2(cumulative_length - quad_length, 0)
			var uv_3 = Vector2(cumulative_length - quad_length, quad_height)
			var uv_4 = Vector2(cumulative_length, quad_height)
			
			right_uvs = [uv_4, uv_3, uv_2, uv_1]
			left_uvs = [uv_3, uv_4, uv_1, uv_2]
			
		
		onyx_mesh.add_ngon(right_cap, [], [], right_uvs, [])
		onyx_mesh.add_ngon(left_cap, [], [], left_uvs, [])
			
		
		i += 1
		cumulative_length -= quad_length
		cumulative_width = total_width
	
	render_onyx_mesh()
	
	

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
 
