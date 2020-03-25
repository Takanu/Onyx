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
var VecUtils = load("res://addons/onyx/utilities/vector_utils.gd")

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

# The width of the ramp, both the plus and minus points
var start_ramp_width = Vector2(1, 1)

# The depth of the ramp, both the plus and minus points
var start_ramp_depth = Vector2(1, 1)

# The end location of the ramp
var end_position = Vector3(0, 1, 2) 
var end_rotation = Vector3(0, 0, 0)

# The width of the ramp, both the plus and minus points
var end_ramp_width = Vector2(1, 1)

# The depth of the ramp, both the plus and minus points
var end_ramp_depth = Vector2(1, 1)


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
			previous_a_controls = get_control_data()
			
			return true

		# START AND END POINTS /////
		
		"start_position":
			start_position = value
		
		"start_rotation":
			start_rotation = value
		
		"start_ramp_width":
			if value.x < 0:
				value.x = 0
			if value.y < 0:
				value.y = 0

			start_ramp_width = value
		
		"start_ramp_depth":
			if value.x < 0:
				value.x = 0
			if value.y < 0:
				value.y = 0
				
			start_ramp_depth = value

		"end_position":
			end_position = value

		"end_rotation":
			end_rotation = value
		
		"end_ramp_width":
			if value.x < 0:
				value.x = 0
			if value.y < 0:
				value.y = 0
				
			end_ramp_width = value
		
		"end_ramp_depth":
			if value.x < 0:
				value.x = 0
			if value.y < 0:
				value.y = 0
				
			end_ramp_depth = value

		# SHAPE PROPERTIES /////
		
		
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
        
            "name" : "start/start_position",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"start_rotation" : {	
        
            "name" : "start/start_rotation",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},

		"start_ramp_width" : {	
        
            "name" : "start/start_ramp_width",
            "type" : TYPE_VECTOR2,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},

		"start_ramp_depth" : {	
        
            "name" : "start/start_ramp_depth",
            "type" : TYPE_VECTOR2,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"end_position" : {	
        
            "name" : "end/end_position",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		"end_rotation" : {	
        
            "name" : "end/end_rotation",
            "type" : TYPE_VECTOR3,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},

		"end_ramp_width" : {	
        
            "name" : "end/end_ramp_width",
            "type" : TYPE_VECTOR2,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},

		"end_ramp_depth" : {	
        
            "name" : "end/end_ramp_depth",
            "type" : TYPE_VECTOR2,
            "usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		},
		
		# SHAPE PROPERTIES /////
        
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
	var line_bounds = VecUtils.get_vertex_pool_aabb(PoolVector3Array(pool))
	
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
		end_position = Vector3(shape_bounds.size.x / 2, shape_bounds.end.y, 
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
	
	return build_geometry(start_position, end_position, start_ramp_width, 
			start_ramp_depth, end_ramp_width, end_ramp_depth)


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:

    # Prevents geometry generation if the node hasn't loaded yet
    if Engine.editor_hint == false:
        return OnyxMesh.new()

    # TODO - Implement hollow mode for the wedge shape type.

    return build_geometry(start_position, end_position, start_ramp_width, 
			start_ramp_depth, end_ramp_width, end_ramp_depth)
	


# Performs the process of building a set of mesh data and returning it to the caller.
func build_geometry(geom_start : Vector3,  geom_end : Vector3,  
		geom_start_w_bounds : Vector2,  geom_start_d_bounds : Vector2,
		geom_end_w_bounds : Vector2,  geom_end_d_bounds : Vector2):

	# Prevents geometry generation if the node hasn't loaded yet
	if is_inside_tree() == false:
		return
	
	var new_onyx_mesh = OnyxMesh.new()


	# Get some basic transform data.
	var position = Vector3(0, 0, 0)
	var start_tf = Transform(Basis(start_rotation), geom_start)
	var end_tf = Transform(Basis(end_rotation), geom_end)
	
	
	# GENERATION START
	
	#   X---------X  e_t1 e_t2
	#	|         |  e_b1 e_b2
	#	|         |
	#	|         |
	#   X---------X  s_t1 s_t2
	#   X---------X  s_b1 s_b2
	
	# get main 8 vectors
	var base_s_t1 = Vector3(-start_ramp_width.x, start_ramp_depth.y, 0)
	var base_s_t2 = Vector3(start_ramp_width.y, start_ramp_depth.y, 0)
	var base_s_b1 = Vector3(-start_ramp_width.x, -start_ramp_depth.x, 0)
	var base_s_b2 = Vector3(start_ramp_width.y, -start_ramp_depth.x, 0)

	var base_e_t1 = Vector3(-end_ramp_width.x, end_ramp_depth.y, 0)
	var base_e_t2 = Vector3(end_ramp_width.y, end_ramp_depth.y, 0)
	var base_e_b1 = Vector3(-end_ramp_width.x, -end_ramp_depth.x, 0)
	var base_e_b2 = Vector3(end_ramp_width.y, -end_ramp_depth.x, 0)

	# Transform every base point with the start and end transforms
	# var tf_s_t1 = Transform(Basis(start_rotation), geom_start + base_s_t1)
	# var tf_s_t2 = Transform(Basis(start_rotation), geom_start + base_s_t2)
	# var tf_s_b1 = Transform(Basis(start_rotation), geom_start + base_s_b1)
	# var tf_s_b2 = Transform(Basis(start_rotation), geom_start + base_s_b2)

	# var tf_e_t1 = Transform(Basis(end_rotation), geom_end + base_e_t1)
	# var tf_e_t2 = Transform(Basis(end_rotation), geom_end + base_e_t2)
	# var tf_e_b1 = Transform(Basis(end_rotation), geom_end + base_e_b1)
	# var tf_e_b2 = Transform(Basis(end_rotation), geom_end + base_e_b2)
	
	# Get the subdivided points across every edge
	var left_top_edges = VecUtils.subdivide_transform_interpolation(base_s_t1, 
			start_tf, base_e_t1, end_tf, horizontal_edge_loops)
	var left_bottom_edges = VecUtils.subdivide_transform_interpolation(base_s_t2, 
			start_tf, base_e_t2, end_tf, horizontal_edge_loops)
	var right_top_edges = VecUtils.subdivide_transform_interpolation(base_s_b1, 
			start_tf, base_e_b1, end_tf, horizontal_edge_loops)
	var right_bottom_edges = VecUtils.subdivide_transform_interpolation(base_s_b2, 
			start_tf, base_e_b2, end_tf, horizontal_edge_loops)

	# Get any other important pieces of information
	
	

	# /////////////////////////////////////////
	# HORIZONTAL STRIP BUILDER ////////

	# Collect all the vertex sets in one array for easy normal smoothing later
	var top_vertex_sets = []
	var bottom_vertex_sets = []
	var left_vertex_sets = []
	var right_vertex_sets = []
	
	var i = 0
	for i in range(left_top_edges.size() - 1):
		
		var lt_i = left_top_edges[i]
		var lb_i = left_bottom_edges[i]
		var rt_i = right_top_edges[i]
		var rb_i = right_bottom_edges[i]

		top_vertex_sets.append(VecUtils.subdivide_edge(lt_i, rt_i, 
			vertical_edge_loops))
		bottom_vertex_sets.append(VecUtils.subdivide_edge(lb_i, rb_i, 
			vertical_edge_loops))
		left_vertex_sets.append(VecUtils.subdivide_edge(lt_i, lb_i, 
			depth_edge_loops))
		right_vertex_sets.append(VecUtils.subdivide_edge(rt_i, rb_i, 
			depth_edge_loops))


	# /////////////////////////////////////////
	# MESH BUILDER

	build_geometric_surface(new_onyx_mesh, top_vertex_sets, true, 0)
	new_onyx_mesh.push_surface()
	build_geometric_surface(new_onyx_mesh, bottom_vertex_sets, false, 0)
	new_onyx_mesh.push_surface()

	build_geometric_surface(new_onyx_mesh, left_vertex_sets, false, 0)
	new_onyx_mesh.push_surface()
	build_geometric_surface(new_onyx_mesh, right_vertex_sets, true, 0)
	new_onyx_mesh.push_surface()



	# /////////////////////////////////////////
	# TOP/BOTTOM CAPS ////////
	# (these arent as important or complex, they get built last)
	
	var front_uvs = []
	var back_uvs = []

	var start_f1 = start_tf.xform(base_s_t1)
	var start_f2 = start_tf.xform(base_s_t2)
	var start_f3 = start_tf.xform(base_s_b1)
	var start_f4 = start_tf.xform(base_s_b2)

	var end_f1 = end_tf.xform(base_e_t1)
	var end_f2 = end_tf.xform(base_e_t2)
	var end_f3 = end_tf.xform(base_e_b1)
	var end_f4 = end_tf.xform(base_e_b2)
	
	if unwrap_method == UnwrapMethod.PER_FACE_MAPPING:
		front_uvs = [Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)]
		back_uvs = [Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)]
	
	# TODO - TOMORROOOOOW
	elif unwrap_method == UnwrapMethod.PROPORTIONAL_OVERLAP:
		pass
		# var start_cap_width = (start_f1 - start_f2).length()
		# var start_cap_height = (start_f1 - start_f3).length()
		# var end_cap_width = ().length()
		# var end_cap_height = ().length()

		# var start_uv_1 = Vector2(0, cap_tile_height)
		# var start_uv_2 = Vector2(cap_width, cap_tile_height)
		# var start_uv_3 = Vector2(0, 0)
		# var start_uv_4 = Vector2(cap_tile_cap_widthwidth, 0)

		# var end_uv_1 = Vector2(0, cap_tile_height)
		# var end_uv_2 = Vector2(cap_width, cap_tile_height)
		# var end_uv_3 = Vector2(0, 0)
		# var end_uv_4 = Vector2(cap_tile_cap_widthwidth, 0)
		
		# front_uvs = [uv_1, uv_3, uv_4, uv_2]
		# back_uvs = [uv_4, uv_3, uv_1, uv_2]

	var front_v = [start_f1, start_f3, start_f4, start_f2]
	var back_v = [end_f4, end_f3, end_f1, end_f2]
		
	new_onyx_mesh.add_ngon(front_v, [], [], front_uvs, [])
	new_onyx_mesh.add_ngon(back_v, [], [], back_uvs, [])
		


	new_onyx_mesh.push_surface()
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

				# //////////////////////////////
				# NORMAL SOLUTION #1
				var s1_normals = [VecUtils.get_triangle_normal([s1, e1, s2])]
				var e1_normals = [VecUtils.get_triangle_normal([e1, s1, e2])] 
				var s2_normals = [VecUtils.get_triangle_normal([s2, e2, s1])]
				var e2_normals = [VecUtils.get_triangle_normal([e2, e1, s2])]
				
				# BOTTOM SIDE
				if x > 0:
					var h_0 = vertex_sets[x - 1]
					b1 = Vector3(h_0[i])
					b2 = Vector3(h_0[i + 1])
					s1_normals.append(VecUtils.get_triangle_normal([s1, b1, s2]))
					s2_normals.append(VecUtils.get_triangle_normal([s2, b2, s1]))

				# TOP SIDE
				if x < vertex_sets.size() - 2:
					var h_3 = vertex_sets[x + 2]
					u1 = Vector3(h_3[i])
					u2 = Vector3(h_3[i + 1])
					e1_normals.append(VecUtils.get_triangle_normal([e1, u1, e2]))
					e2_normals.append(VecUtils.get_triangle_normal([e2, u2, e1]))

				# LEFT SIDE
				if i > 0:
					s0 = Vector3(h_1[i - 1])  
					e0 = Vector3(h_2[i - 1])
					s1_normals.append(VecUtils.get_triangle_normal([s1, s0, e1]))
					e1_normals.append(VecUtils.get_triangle_normal([e1, e0, s1]))

				# RIGHT SIDE
				if i < h_1.size() - 2:
					s3 = Vector3(h_1[i + 2])  
					e3 = Vector3(h_2[i + 2])
					s2_normals.append(VecUtils.get_triangle_normal([s2, s3, e2]))
					e2_normals.append(VecUtils.get_triangle_normal([e2, e3, s2]))
				
				# BOTTOM LEFT
				if b1 != null && s0 != null:
					s1_normals.append(VecUtils.get_triangle_normal([s1, s0, b1]))
				# BOTTOM RIGHT
				if b2 != null && s3 != null:
					s2_normals.append(VecUtils.get_triangle_normal([s2, b2, s3]))
				# TOP LEFT
				if e0 != null && u1 != null:
					s2_normals.append(VecUtils.get_triangle_normal([e1, e0, u1]))
				# TOP RIGHT
				if u2 != null && e3 != null:
					s2_normals.append(VecUtils.get_triangle_normal([e2, u2, e3]))

				var normal_s1 = Vector3(); var normal_s2 = Vector3(); 
				var normal_e1 = Vector3(); var normal_e2 = Vector3(); 
				
				normal_s1 = VecUtils.get_normal_average(s1_normals)
				normal_s2 = VecUtils.get_normal_average(s2_normals)
				normal_e1 = VecUtils.get_normal_average(e1_normals)
				normal_e2 = VecUtils.get_normal_average(e2_normals)

				if is_positively_signed:
					normals = [normal_s1, normal_e1, normal_e2, normal_s2]
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


	# START AND END POSITIONS

	var start_ramp = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	start_ramp.control_name = 'start_position'
	start_ramp.set_type_translate(false, "modify_control", "commit_control")

	var end_ramp = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	end_ramp.control_name = 'end_position'
	end_ramp.set_type_translate(false, "modify_control", "commit_control")

	# START BOUNDS

	var start_width_minus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	start_width_minus.control_name = 'start_width_minus'
	start_width_minus.set_type_axis(false, "modify_control", 
		"commit_control", Vector3.RIGHT)

	var start_width_plus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	start_width_plus.control_name = 'start_width_plus'
	start_width_plus.set_type_axis(false, "modify_control", 
		"commit_control", Vector3.RIGHT)

	var start_depth_minus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	start_depth_minus.control_name = 'start_depth_minus'
	start_depth_minus.set_type_axis(false, "modify_control", 
		"commit_control", Vector3.UP)

	var start_depth_plus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	start_depth_plus.control_name = 'start_depth_plus'
	start_depth_plus.set_type_axis(false, "modify_control", 
		"commit_control", Vector3.UP)

	# END BOUNDS

	var end_width_minus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	end_width_minus.control_name = 'end_width_minus'
	end_width_minus.set_type_axis(false, "modify_control", 
		"commit_control", Vector3.RIGHT)

	var end_width_plus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	end_width_plus.control_name = 'end_width_plus'
	end_width_plus.set_type_axis(false, "modify_control", 
		"commit_control", Vector3.RIGHT)

	var end_depth_minus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	end_depth_minus.control_name = 'end_depth_minus'
	end_depth_minus.set_type_axis(false, "modify_control", 
		"commit_control", Vector3.UP)

	var end_depth_plus = ControlPoint.new(self, "get_gizmo_undo_state", 
			"get_gizmo_redo_state", "restore_state", "restore_state")
	end_depth_plus.control_name = 'end_depth_plus'
	end_depth_plus.set_type_axis(false, "modify_control", 
		"commit_control", Vector3.UP)
	

	# populate the dictionary
	a_controls[start_ramp.control_name] = start_ramp
	a_controls[end_ramp.control_name] = end_ramp

	a_controls[start_width_minus.control_name] = start_width_minus
	a_controls[start_width_plus.control_name] = start_width_plus
	a_controls[start_depth_minus.control_name] = start_depth_minus
	a_controls[start_depth_plus.control_name] = start_depth_plus

	a_controls[end_width_minus.control_name] = end_width_minus
	a_controls[end_width_plus.control_name] = end_width_plus
	a_controls[end_depth_minus.control_name] = end_depth_minus
	a_controls[end_depth_plus.control_name] = end_depth_plus
	

	# need to give it positions in the case of a duplication or scene load.
	refresh_control_data()

	# Set the accurate axes for all bound points.
	set_bounds_snap_axis()
	

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
	if a_controls.size() == 0:
	#		if gizmo != null:
	##			print("...attempted to refresh_control_data(), rebuilding handles.")
	#			gizmo.control_points.clear()
	#			build_control_points()
	#			return
		build_control_points()
		return

	# Start and end transforms
	var start_tf = Transform(Basis(start_rotation), start_position)
	var end_tf = Transform(Basis(end_rotation), end_position)

	# Start ramp positions
	var start_width_minus = start_tf.xform(Vector3(-start_ramp_width.x, 0, 0))
	var start_width_plus = start_tf.xform(Vector3(start_ramp_width.y, 0, 0))
	var start_depth_minus = start_tf.xform(Vector3(0, -start_ramp_depth.x, 0))
	var start_depth_plus = start_tf.xform(Vector3(0, start_ramp_depth.y, 0))

	# End ramp positions
	var end_width_minus = end_tf.xform(Vector3(-end_ramp_width.x, 0, 0))
	var end_width_plus = end_tf.xform(Vector3(end_ramp_width.y, 0, 0))
	var end_depth_minus = end_tf.xform(Vector3(0, -end_ramp_depth.x, 0))
	var end_depth_plus = end_tf.xform(Vector3(0, end_ramp_depth.y, 0))


	a_controls["start_position"].control_pos = start_position
	a_controls["end_position"].control_pos = end_position

	a_controls["start_width_minus"].control_pos = start_width_minus
	a_controls["start_width_plus"].control_pos = start_width_plus
	a_controls["start_depth_minus"].control_pos = start_depth_minus
	a_controls["start_depth_plus"].control_pos = start_depth_plus

	a_controls["end_width_minus"].control_pos = end_width_minus
	a_controls["end_width_plus"].control_pos = end_width_plus
	a_controls["end_depth_minus"].control_pos = end_depth_minus
	a_controls["end_depth_plus"].control_pos = end_depth_plus

	

# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo (AKA - When someone moves a control point)
func update_control_from_gizmo(control):
	
	var coordinate = control.control_pos
	
	match control.control_name:

		# positions
		'start_position': start_position = coordinate
		'end_position': end_position = coordinate
		
		# start bounds
		'start_width_minus': 
			start_ramp_width.x = (start_position - coordinate).length()
		'start_width_plus': 
			start_ramp_width.y = (start_position - coordinate).length()
		'start_depth_minus': 
			start_ramp_depth.x = (start_position - coordinate).length()
		'start_depth_plus': 
			start_ramp_depth.y = (start_position - coordinate).length()

		# end bounds
		'end_width_minus': 
			end_ramp_width.x = (end_position - coordinate).length()
		'end_width_plus': 
			end_ramp_width.y = (end_position - coordinate).length()
		'end_depth_minus': 
			end_ramp_depth.x = (end_position - coordinate).length()
		'end_depth_plus': 
			end_ramp_depth.y = (end_position - coordinate).length()
	
	refresh_control_data()
	

# Applies the current handle values to the shape attributes
func apply_control_attributes():
	
	start_position = a_controls["start_position"].control_pos
	end_position = a_controls["end_position"].control_pos
	
	start_ramp_width.x = ( a_controls["start_width_minus"].control_pos - 
			start_position ).length()
	start_ramp_width.y = ( a_controls["start_width_plus"].control_pos - 
			start_position ).length()
	start_ramp_depth.x = ( a_controls["start_depth_minus"].control_pos - 
			start_position ).length()
	start_ramp_depth.y = ( a_controls["start_depth_plus"].control_pos - 
			start_position ).length()

	end_ramp_width.x = ( a_controls["end_width_minus"].control_pos - 
			end_position ).length()
	end_ramp_width.y = ( a_controls["end_width_plus"].control_pos - 
			end_position ).length()
	end_ramp_depth.x = ( a_controls["end_depth_minus"].control_pos - 
			end_position ).length()
	end_ramp_depth.y = ( a_controls["end_depth_plus"].control_pos - 
			end_position ).length()
	
	set_bounds_snap_axis()


# Calibrates the stored properties if they need to change before the origin is updated.
# Only called during Gizmo movements for origin auto-updating.
func balance_control_data():
	
	pass
		

# Refreshes the snapping axes that the start and end point boundaries use.
# Used by build_control_points() and apply_control_attributes()
func set_bounds_snap_axis():

	a_controls["start_width_minus"].snap_axis = ( a_controls["start_width_minus"].control_pos - 
			start_position ).normalized()
	a_controls["start_width_plus"].snap_axis = ( a_controls["start_width_plus"].control_pos - 
			start_position ).normalized()
	a_controls["start_depth_minus"].snap_axis = ( a_controls["start_depth_minus"].control_pos - 
			start_position ).normalized()
	a_controls["start_depth_plus"].snap_axis = ( a_controls["start_depth_plus"].control_pos - 
			start_position ).normalized()
	
	a_controls["end_width_minus"].snap_axis = ( a_controls["end_width_minus"].control_pos - 
			end_position ).normalized()
	a_controls["end_width_plus"].snap_axis = ( a_controls["end_width_plus"].control_pos - 
			end_position ).normalized()
	a_controls["end_depth_minus"].snap_axis = ( a_controls["end_depth_minus"].control_pos - 
			end_position ).normalized()
	a_controls["end_depth_plus"].snap_axis = ( a_controls["end_depth_plus"].control_pos - 
			end_position ).normalized()

# ////////////////////////////////////////////////////////////
# BASE UI FUNCTIONS

func editor_select():
	pass

func editor_deselect():
	pass
