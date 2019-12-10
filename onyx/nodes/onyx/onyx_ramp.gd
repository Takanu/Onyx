tool
extends "res://addons/onyx/nodes/onyx/onyx.gd"

# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var VectorUtils = load("res://addons/onyx/utilities/vector_utils.gd")
var ControlPoint = load("res://addons/onyx/gizmos/control_point.gd")

# ////////////////////////////////////////////////////////////
# PROPERTIES

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


# ////////////////////////////////////////////////////////////
# PROPERTY GENERATORS
# Used to give the unwrap method a property category
# If you're watching this Godot developers.... why.
func _get_property_list():
	var props = [
		{	
			# The usage here ensures this property isn't actually saved, as it's an intermediary
			
			"name" : "uv_options/unwrap_method",
			"type" : TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Proportional Overlap, Direct Overlap"
		},
	]
	return props

func _set(property, value):
	match property:
		"uv_options/unwrap_method":
			if value == "Proportional Overlap":
				unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP
			else:
				unwrap_method = UnwrapMethod.DIRECT_OVERLAP
			
			
	generate_geometry()
		

func _get(property):
	match property:
		"uv_options/unwrap_method":
			return unwrap_method



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
	

# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting = false):
	
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
	var top_verts = VectorUtils.subdivide_edge(v1, v2, vertical_iterations)
	var bottom_verts = VectorUtils.subdivide_edge(v3, v4, vertical_iterations)
	
	# Transform each set to the start and finish
	var top_start_verts = VectorUtils.transform_vector3_array(top_verts, start_tf)
	var bottom_start_verts = VectorUtils.transform_vector3_array(bottom_verts, start_tf)
	var top_end_verts = VectorUtils.transform_vector3_array(top_verts, end_tf)
	var bottom_end_verts = VectorUtils.transform_vector3_array(bottom_verts, end_tf)
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
		var m1_top = VectorUtils.transform_vector3_array(top_verts, s_tf)
		var m1_bottom = VectorUtils.transform_vector3_array(bottom_verts, s_tf)
		var m2_top = VectorUtils.transform_vector3_array(top_verts, e_tf)
		var m2_bottom = VectorUtils.transform_vector3_array(bottom_verts, e_tf)
		
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
	
	# Re-submit the handle positions based on the built faces, so other handles that aren't the
	# focus of a handle operation are being updated\
	refresh_handle_data()
	update_gizmo()
	


# ////////////////////////////////////////////////////////////
# GIZMO HANDLES

# On initialisation, control points are built for transmitting and handling interactive points between the node and the node's gizmo.
func build_handles():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	var triangle_z = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	
	var start_ramp = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	start_ramp.control_name = 'start_position'
	start_ramp.set_type_translate(false, "handle_change", "handle_commit")
	
	var end_ramp = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	end_ramp.control_name = 'end_position'
	end_ramp.set_type_translate(false, "handle_change", "handle_commit")
	
	var ramp_width = ControlPoint.new(self, "get_gizmo_undo_state", "get_gizmo_redo_state", "restore_state", "restore_state")
	ramp_width.control_name = 'ramp_width'
	ramp_width.set_type_axis(false, "handle_change", "handle_commit", triangle_z)
	
	# populate the dictionary
	handles[start_ramp.control_name] = start_ramp
	handles[end_ramp.control_name] = end_ramp
	handles[ramp_width.control_name] = ramp_width
	
	# need to give it positions in the case of a duplication or scene load.
	refresh_handle_data()
	

# Uses the current settings to refresh the handle list.
func refresh_handle_data():
	
	# Exit if not being run in the editor
	if Engine.editor_hint == false:
		return
	
	# Failsafe for script reloads, BECAUSE I CURRENTLY CAN'T DETECT THEM.
	if handles.size() == 0: 
		gizmo.control_points.clear()
		build_handles()
		return
	
	var depth_mid = Vector3(0, ramp_depth/2, 0)
	var width_mid =  Vector3(ramp_width/2, 0, 0)
	
	handles["start_position"].control_position = start_position
	handles["end_position"].control_position = end_position
	handles["ramp_width"].control_position = start_position + depth_mid + width_mid


# Changes the handle based on the given index and coordinates.
func update_handle_from_gizmo(control):
	
	var coordinate = control.control_position
	
	match control.control_name:
		# positions
		'start_position': start_position = coordinate
		'end_position': end_position = coordinate
		'ramp_width': ramp_width = (coordinate.x - start_position.x) * 2
	
#	print('NEW END POSITION: ', end_position)
		
	refresh_handle_data()
	

# Applies the current handle values to the shape attributes
func apply_handle_attributes():
	
	start_position = handles["start_position"].control_position
	end_position = handles["end_position"].control_position
	ramp_width = (handles["ramp_width"].control_position.x - start_position.x) * 2

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_handles():
	
	# balance handles here
	pass
