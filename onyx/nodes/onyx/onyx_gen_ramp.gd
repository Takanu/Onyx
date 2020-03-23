tool
extends "res://addons/onyx/nodes/onyx/onyx_generator.gd"

# /////////////////////////////////////////////////////////////////////////////
# INFO
# A generator for use with OnyxShape.
# Generates a sphere shape.  It has a surface-like 
# interaction.

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

	# All faces are unwrapped to match world space, overlaps
	PROPORTIONAL_OVERLAP, 	
	# Every face is mapped 1:1 with the bounds of UV space, will not extend beyond it
	PER_FACE_MAPPING,		
}

# Decides if the stairway gets a "base fill", and if so which way along the Y
# axis it's generated.
enum RampFillType {

	# No ramp fill, the stairs will proportionally generate along the two points.
	NONE, 

	# Ramp fill will be downwards.
	MINUS_Y, 

	# Ramp fill will be drawn upwards.
	PLUS_Y,
}


# ////////////////////////////////////
# PUBLIC

# The current origin mode set.
var origin_mode = OriginPosition.BASE


# SHAPE PROPERTIES /////

# The start location of the ramp
var start_position = Vector3(0, 1, 0)
var start_rotation = Vector3(0, 0, 0)

# The end location of the ramp
var end_position = Vector3(0, 1, 2) 
var end_rotation = Vector3(0, 0, 0)

# The width of the ramp
var ramp_width = 6

# The depth of the ramp.
var ramp_depth = 1

# ???
var maintain_width = true

# The number of edge loops inserted from the bottom to the top of the ramp.
var horizontal_edge_loops = 4

# The number of edge loops inserted along the path of the ramp.
var vertical_edge_loops = 4

# The number of edge loops inserted along the depth of the ramp.
var depth_edge_loops = 0

# The fill type of the ramp.
var ramp_fill_type = RampFillType.NONE



# HOLLOW PROPERTIES /////

# Used to determine how much the hollow faces move away from the
# sides of the current shape.

# TODO - Design something that makes sense, after you improve the shapes handle
# functionality


# UV OPTIONS /////

var unwrap_method = UnwrapMethod.PROPORTIONAL_OVERLAP

# If true, the surfaces of the ramp will have smoothed normals.
var smooth_normals = true


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

	#	print("[OnyxRoundedBox] - ", self, "_set()", property, value)
	#	
	match property:

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

		# START AND END POINTS /////
		
		"start_position":
			start_position = value
		
		"start_rotation":
			start_rotation = value

		"end_position":
			end_position = value

		"end_rotation":
			end_rotation = value

		# SHAPE PROPERTIES /////
		
		"ramp_width":
			ramp_width = value
		
		"ramp_depth":
			ramp_depth = value
		
		"maintain_width":
			maintain_width = value

		"horizontal_edge_loops":
			if value < 1:
				value = 1
			horizontal_edge_loops = value
		
		"vertical_edge_loops":
			if value < 0:
				value = 0
			vertical_edge_loops = value
		
		"depth_edge_loops":
			if value < 0:
				value = 0
			depth_edge_loops = value

		"ramp_fill_type":
			ramp_fill_type = value

		# UVS / NORMALS /////

		"unwrap_method":
			unwrap_method = value

		"smooth_normals":
			smooth_normals = value


		# HOLLOW MARGINS /////

		# "_height_max_hollow":
		#     _height_hollow = value

		# "_x_width_hollow":
		#     _x_width_hollow = value

		# "_z_width_hollow":
		#     _z_width_hollow = value


	_process_property_update()
	return true
	
	
	
# Returns the list of custom shape properties that an owner should save and display.
func get_shape_properties() -> Dictionary:

    var props = {

        # ORIGIN SETTINGS /////
        
        "origin_mode" : {	
        
            "name" : "origin_mode",
            "type" : TYPE_INT,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "Center, Base, Bottom Corner"
        },
        
        # START AND END POINTS /////
        
        "start_position" : {	
        
            "name" : "start_position",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"start_rotation" : {	
        
            "name" : "start_rotation",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"end_position" : {	
        
            "name" : "end_position",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"end_rotation" : {	
        
            "name" : "end_rotation",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		# SHAPE PROPERTIES /////
        
        "ramp_width" : {	
        
            "name" : "ramp_width",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "ramp_depth" : {	
        
            "name" : "ramp_depth",
            "type" : TYPE_REAL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
        
        "maintain_width" : {	
        
            "name" : "maintain_width",
            "type" : TYPE_BOOL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"horizontal_edge_loops" : {	
        
            "name" : "horizontal_edge_loops",
            "type" : TYPE_INT,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"vertical_edge_loops" : {	
        
            "name" : "vertical_edge_loops",
            "type" : TYPE_INT,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},

		"depth_edge_loops" : {	
        
            "name" : "depth_edge_loops",
            "type" : TYPE_INT,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"ramp_fill_type" : {	
        
            "name" : "ramp_fill_type",
            "type" : TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_ENUM,
            "hint_string": "Proportional Overlap, Per-Face Mapping"
        },
        
        
        # UV / NORMALS /////
        
        "unwrap_method" : {	
        
            "name" : "uv_options/unwrap_method",
            "type" : TYPE_INT,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "None, Minus Y, Plus Y"
        },
        
        "smooth_normals" : {	
        
            "name" : "uv_options/smooth_normals",
            "type" : TYPE_BOOL,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
        },
    }

    return props



# Returns a set of custom properties used to tell the owner general aspects of it's
# shape, helping the owner set new properties for the next shape.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func get_shape_aspects() -> Dictionary:
	
	var aspects = {}

	var pool = [start_position, end_position]
	var line_bounds = VectorUtils.get_vertex_pool_aabb(PoolVector3Array(pool))
	
	var size = Vector3(line_bounds.size.x, line_bounds.size.y, line_bounds.size.z)
	var origin = Vector3(0, 0, 0)
	
	aspects[ShapeAspects.SHAPE_BOUNDS] = AABB(origin, size)
	aspects[ShapeAspects.ORIGIN] = Vector3(0, 0, 0)
	
	# TODO - Generate hollow margin aspect data

	return aspects


# Used by the owner to implant parts of the last shape generator to a new one.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func load_shape_aspects(aspects : Dictionary):
	
	if aspects.has(ShapeAspects.SHAPE_BOUNDS):
		var shape_bounds : AABB = aspects[ShapeAspects.SHAPE_BOUNDS]
		
		# If we're given an aspect, set the values now
		# TODO - Make this more accurate

		start_position = Vector3(shape_bounds.size.x / 2, shape_bounds.position.y, 
				shape_bounds.position.z)
		start_position = Vector3(shape_bounds.size.x / 2, shape_bounds.end.y, 
				shape_bounds.end.z)
		
	
#		if aspects.has(ShapeAspects.HOLLOW_BOUNDS):
#			var hollow_bounds = aspects[ShapeAspects.HOLLOW_BOUNDS]
#
	
	build_control_points()


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# MESH GENERATION


# Creates new geometry to reflect the shapes current properties, then returns it.
func update_geometry() -> OnyxMesh:
	
	# Prevents geometry generation if the node hasn't loaded yet
	if Engine.editor_hint == false:
		return OnyxMesh.new()
	
	return build_geometry(start_position, end_position, ramp_width, ramp_depth)


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:

    # Prevents geometry generation if the node hasn't loaded yet
    if Engine.editor_hint == false:
        return OnyxMesh.new()

    # TODO - Implement hollow mode for the wedge shape type.

    return build_geometry(start_position, end_position, ramp_width, ramp_depth)
	


# Performs the process of building a set of mesh data and returning it to the caller.
func build_geometry(geom_start : Vector3,  geom_end : Vector3,  geom_width : float,  
		geom_depth : float):

	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return
	
	var new_onyx_mesh = OnyxMesh.new()


	# Get some basic transform data.
	var position = Vector3(0, 0, 0)
	var start_tf = Transform(Basis(start_rotation), geom_start)
	var end_tf = Transform(Basis(end_rotation), geom_end)
	
	
	# GENERATION START
	
	#   X---------X  t_e1 t_e2
	#	|         |  b_e1 b_e2
	#	|         |
	#	|         |
	#   X---------X  t_s1 t_s2
	#   X---------X  b_s1 b_s2
	
	# get main 4 vectors
	var v1 = Vector3(-geom_width/2, geom_depth/2, 0)
	var v2 = Vector3(geom_width/2, geom_depth/2, 0)
	var v3 = Vector3(-geom_width/2, -geom_depth/2, 0)
	var v4 = Vector3(geom_width/2, -geom_depth/2, 0)
	
	# Get the edge loop lists for all 4 variable sides of the ramp.
	var top_h_verts = VectorUtils.subdivide_edge(v1, v2, vertical_edge_loops)
	var bottom_h_verts = VectorUtils.subdivide_edge(v3, v4, vertical_edge_loops)
	var left_verts = VectorUtils.subdivide_edge(v1, v3, depth_edge_loops)
	var right_verts = VectorUtils.subdivide_edge(v2, v4, depth_edge_loops)
	
	# Transform each set to the start and finish
	var top_start_verts = VectorUtils.transform_vector3_array(top_h_verts, start_tf)
	var bottom_start_verts = VectorUtils.transform_vector3_array(bottom_h_verts, start_tf)
	var top_end_verts = VectorUtils.transform_vector3_array(top_h_verts, end_tf)
	var bottom_end_verts = VectorUtils.transform_vector3_array(bottom_h_verts, end_tf)

	var left_start_verts = VectorUtils.transform_vector3_array(left_verts, start_tf)
	var right_start_verts = VectorUtils.transform_vector3_array(right_verts, start_tf)
	var left_end_verts = VectorUtils.transform_vector3_array(left_verts, end_tf)
	var right_end_verts = VectorUtils.transform_vector3_array(right_verts, end_tf)
#
	# ramp fill type conditionals
	if ramp_fill_type == 1:
		for i in top_h_verts.size():
			bottom_end_verts[i].y = bottom_start_verts[i].y

	elif ramp_fill_type == 2:
		for i in top_h_verts.size():
			top_start_verts[i].y = top_end_verts[i].y

	# Get any other important pieces of information
	var cap_tile_width = (top_start_verts[1] - top_start_verts[0]).length()
	var cap_tile_height = (top_start_verts[0] - bottom_start_verts[0]).length()
	var cap_width = cap_tile_width * top_h_verts.size() - 1
	

	# /////////////////////////////////////////
	# TOP/BOTTOM LIST BUILDING ////////

	# calculate horizontal_edge_loops
	var total_h_iterations = horizontal_edge_loops + 1
	var increment = 1.0/float(total_h_iterations)
	var current_percentage = 0
	var position_diff = geom_end - geom_start
	var rotation_diff = end_rotation - start_rotation
	
	var cumulative_width = cap_width
	var cumulative_length = 0

	# Collect all the vertex sets in one array for easy normal smoothing later
	var htop_vertex_sets = []
	var hbottom_vertex_sets = []
	
	var i = 0
	for i in range(total_h_iterations + 1):
		current_percentage = float(i) / total_h_iterations
		
		# transform the starts and ends by the interpolation between the start and end transformation
		var start_percentage = float(i) / total_h_iterations
		var end_percentage = float(i + 1) / total_h_iterations
		
		# Get positions and rotations for transforms
		var pos = geom_start + (position_diff * current_percentage)
		var rot = start_rotation + (rotation_diff * current_percentage)
		var transform = Transform(Basis(rot), pos)
		
		# Transform the vertex sets
		var htop_set = VectorUtils.transform_vector3_array(top_h_verts, transform)
		var hbottom_set = VectorUtils.transform_vector3_array(bottom_h_verts, transform)
		htop_vertex_sets.append(htop_set)
		hbottom_vertex_sets.append(hbottom_set)


	# /////////////////////////////////////////
	# LEFT/RIGHT LIST BUILDING ////////

	increment = 1.0/float(total_h_iterations)
	current_percentage = 0
	position_diff = geom_end - geom_start
	rotation_diff = end_rotation - start_rotation

	# Collect all the vertex sets in one array for easy normal smoothing later
	var left_vertex_sets = []
	var right_vertex_sets = []

	for i in range(total_h_iterations + 1):
		current_percentage = float(i) / total_h_iterations
		
		# transform the starts and ends by the interpolation between the start and end transformation
		var start_percentage = float(i) / total_h_iterations
		var end_percentage = float(i + 1) / total_h_iterations
		
		# Get positions and rotations for transforms
		var pos = geom_start + (position_diff * current_percentage)
		var rot = start_rotation + (rotation_diff * current_percentage)
		var transform = Transform(Basis(rot), pos)
		
		# Transform the vertex sets
		var left_set = VectorUtils.transform_vector3_array(left_verts, transform)
		var right_set = VectorUtils.transform_vector3_array(right_verts, transform)
		left_vertex_sets.append(left_set)
		right_vertex_sets.append(right_set)

	# /////////////////////////////////////////
	# MESH BUILDER

	build_geometric_surface(new_onyx_mesh, htop_vertex_sets, false, 0)
	build_geometric_surface(new_onyx_mesh, hbottom_vertex_sets, true, 0)

	build_geometric_surface(new_onyx_mesh, left_vertex_sets, true, 0)
	build_geometric_surface(new_onyx_mesh, right_vertex_sets, false, 0)



	# /////////////////////////////////////////
	# TOP/BOTTOM CAPS ////////
	# (these arent as important or complex, they get built last)
	
	# Metrics for use in unwrapping operations
	cumulative_width = cap_width
	
	for i in range( top_h_verts.size() - 1 ):
		var t_s1 = top_start_verts[i]
		var t_s2 = top_start_verts[i + 1]
		var b_s1 = bottom_start_verts[i]
		var b_s2 = bottom_start_verts[i + 1]
		
		var t_e1 = top_end_verts[i]
		var t_e2 = top_end_verts[i + 1]
		var b_e1 = bottom_end_verts[i]
		var b_e2 = bottom_end_verts[i + 1]
		
		# UVS
		var front_uvs = []
		var back_uvs = []
		
		if unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
			front_uvs = [Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)]
			back_uvs = [Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)]
		
		elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
			var uv_1 = Vector2(cumulative_width, cap_tile_height)
			var uv_2 = Vector2(cumulative_width - cap_width, cap_tile_height)
			var uv_3 = Vector2(cumulative_width - cap_tile_width, 0)
			var uv_4 = Vector2(cumulative_width, 0)
			
			front_uvs = [uv_1, uv_2, uv_3, uv_4]
			back_uvs = [uv_2, uv_1, uv_4, uv_3]
			cumulative_width -= cap_tile_width
			
		new_onyx_mesh.add_ngon([b_s1, b_s2, t_s2, t_s1], [], [], front_uvs, [])
		new_onyx_mesh.add_ngon([b_e2, b_e1, t_e1, t_e2], [], [], back_uvs, [])

	return new_onyx_mesh
	

# This is for building a single surface or surface area for the ramp, using arrays of
# of pre-determined vertices to be drawn as quads.
#
func build_geometric_surface(onyx_mesh : OnyxMesh, vertex_sets : Array, 
		is_positively_signed : bool, unwrap_length_start : float):

	# Get the width of a single vertex set
	var first_v : Vector3 = vertex_sets[0][0]
	var last_v : Vector3 = vertex_sets[0][vertex_sets[0].size() - 1]
	var set_width = (last_v - first_v).length()

	var current_uv_width = set_width
	var current_uv_length = unwrap_length_start

	# VERTICAL ITERATIONS /////

	var x = 0
	for x in range(vertex_sets.size() - 1):

		var h_1 = vertex_sets[x]
		var h_2 = vertex_sets[x + 1]

		# Start 
		var start_uv_z = 0
		var end_uv_z = 1
		var quad_width = (h_1[1] - h_1[0]).length()
		var quad_length = (h_2[0] - h_1[0]).length()

		# HORIZONTAL ITERATIONS /////

		for i in range(h_1.size() - 1):

			var face = []

			# 	       u1     u2
			#           ?      ?
			#     N0-0  | N1-0 |  N2-0
			#           |      | 
			# e0? -----e1-----e2------ ?e3
			#     N0-1  | N1-1 |  N2-1
			#           |      |
			# s0? -----s1-----s2------ ?s3
			#     N0-2  | N1-2 |  N2-2
			#           |      |
			#           ?      ?
			#          b1     b2


			# CORE 4
			var s1 = h_1[i]
			var s2 = h_1[i + 1]
			var e1 = h_2[i]
			var e2 = h_2[i + 1]
			
			if is_positively_signed:
				face = [s1, e1, e2, s2]
			else:
				face = [s1, s2, e2, e1]
				
			# NORMALS /////
			var normals = []
			if smooth_normals == true:


				# VERTEX OPTIONALS
				var b1;  var b2;  var u1;  var u2;
				var s0;  var e0;  var s3;  var e3;

				# NORMAL OPTIONALS
				var n0_0 = Vector3();  var n1_0 = Vector3();  var n2_0 = Vector3();
				var n0_1 = Vector3();  var n1_1 = Vector3();  var n2_1 = Vector3();
				var n0_2 = Vector3();  var n1_2 = Vector3();  var n2_2 = Vector3();

				n1_1 = VectorUtils.get_quad_normal([s1, e1, e2, s2])


				# If we're not the first or last horizontal row, we need to 
				# grab some extra normals
				# BOTTOM SIDE
				if x > 0:
					var h_0 = vertex_sets[x - 1]
					b1 = Vector3(h_0[i])
					b2 = Vector3(h_0[i + 1])
					n1_2 = VectorUtils.get_triangle_normal([b1, s1, s2])

				# TOP SIDE
				if x < vertex_sets.size() - 2:
					var h_3 = vertex_sets[x + 2]
					u1 = Vector3(h_3[i])
					u2 = Vector3(h_3[i + 1])
					n1_0 = VectorUtils.get_triangle_normal([e1, u1, u2])

				# If we're not on the edge, we also need to grab some 
				# extra normals
				# LEFT SIDE
				if i > 0:
					s0 = Vector3(h_1[i - 1])  
					e0 = Vector3(h_2[i - 1])
					n0_1 = VectorUtils.get_triangle_normal([s0, e0, e1])
				
				# RIGHT SIDE
				if i < h_1.size() - 2:
					s3 = Vector3(h_1[i + 2])  
					e3 = Vector3(h_2[i + 2])
					n2_1 = VectorUtils.get_triangle_normal([s2, e2, e3])


				# Find the corner normals if we can.
				if n1_2 != Vector3() && n0_1 != Vector3():
					n0_2 = VectorUtils.get_triangle_normal([b1, s0, s1])
				
				if n0_1 != Vector3() && n1_0 != Vector3():
					n0_2 = VectorUtils.get_triangle_normal([e0, u1, e1])
				
				if n1_0 != Vector3() && n2_1 != Vector3():
					n0_2 = VectorUtils.get_triangle_normal([e2, u2, e3])
				
				if n2_1 != Vector3() && n1_2 != Vector3():
					n0_2 = VectorUtils.get_triangle_normal([s2, s3, b2])
				
				# NOW COMBINE THEM FOR EACH VERTEX
				var normal_s1 = (n0_2 + n1_2 + n0_1 + n1_1).normalized()
				var normal_s2 = (n1_2 + n2_2 + n1_1 + n2_1).normalized()
				var normal_e1 = (n0_1 + n1_1 + n0_0 + n1_0).normalized()
				var normal_e2 = (n1_1 + n2_1 + n1_0 + n2_0).normalized()

				if is_positively_signed:
					normals = [normal_s1, normal_s2, normal_e1, normal_e2]
				else:
					normals = [normal_s1, normal_s2, normal_e2, normal_e1]
			
			# UVS //////
			var uvs = []
			
			# 0 - Per-Face Mapping
			if unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
				uvs = [Vector2(1.0, end_uv_z), Vector2(0.0, end_uv_z), Vector2(0.0, start_uv_z), Vector2(1.0, start_uv_z)]
		
			# 1 - PROPORTIONAL OVERLAP
			elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
				var uv_s1 = Vector2(current_uv_width, current_uv_length)
				var uv_s2 = Vector2(current_uv_width - quad_width, current_uv_length)
				var uv_e2 = Vector2(current_uv_width - quad_width, current_uv_length - quad_length)
				var uv_e1 = Vector2(current_uv_width, current_uv_length - quad_length)

				if is_positively_signed:
					uvs = [uv_s1, uv_e1, uv_e2, uv_s2]
				else:
					uvs = [uv_s1, uv_s2, uv_e2, uv_e1]

				current_uv_width -= quad_width
			
			onyx_mesh.add_ngon(face, [], [], uvs, normals)		


		current_uv_length -= quad_length
		current_uv_width = set_width


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# ORIGIN POINT UPDATERS



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

	var start_ramp = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	start_ramp.control_name = 'start_position'
	start_ramp.set_type_translate(false, "modify_control", "commit_control")

	var end_ramp = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	end_ramp.control_name = 'end_position'
	end_ramp.set_type_translate(false, "modify_control", "commit_control")

	var ramp_width = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	ramp_width.control_name = 'ramp_width'
	ramp_width.set_type_axis(false, "modify_control", "commit_control", Vector3(1, 0, 0))

	# populate the dictionary
	active_controls[start_ramp.control_name] = start_ramp
	active_controls[end_ramp.control_name] = end_ramp
	active_controls[ramp_width.control_name] = ramp_width

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

	var depth_mid = Vector3(0, ramp_depth/2, 0)
	var width_mid =  Vector3(ramp_width/2, 0, 0)

	active_controls["start_position"].control_position = start_position
	active_controls["end_position"].control_position = end_position
	active_controls["ramp_width"].control_position = start_position + depth_mid + width_mid

	

# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo (AKA - When someone moves a control point)
func update_control_from_gizmo(control):
	
	var coordinate = control.control_position
	
	match control.control_name:
		# positions
		'start_position': start_position = coordinate
		'end_position': end_position = coordinate
		'ramp_width': ramp_width = (coordinate.x - start_position.x) * 2
	
	refresh_control_data()
	

# Applies the current handle values to the shape attributes
func apply_control_attributes():
	
	start_position = active_controls["start_position"].control_position
	end_position = active_controls["end_position"].control_position
	ramp_width = (active_controls["ramp_width"].control_position.x - start_position.x) * 2

# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_control_data():
	
	pass
		

# ////////////////////////////////////////////////////////////
# BASE UI FUNCTIONS

func editor_select():
	pass

func editor_deselect():
	pass
