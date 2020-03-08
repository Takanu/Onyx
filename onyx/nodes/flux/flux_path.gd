tool
extends CSGCombiner

# ////////////////////////////////////////////////////////////
# INFO
# Flux tool - generate random or organised clusters of nodes within a pre-defined area.


# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var FluxUtils = load("res://addons/onyx/nodes/flux/flux_utils.gd")
var VectorUtils = load('res://addons/onyx/utilities/vector_utils.gd')
var ControlPoint = load("res://addons/onyx/gizmos/control_point.gd")

# ////////////////////////////////////////////////////////////
# CONSTANTS
const FluxCollectionName = '#flux_internal_collection'
const FluxWireframeName = '#flux_internal_wireframe'

# ////////////////////////////////////////////////////////////
# INTERNAL PROPERTIES

# The plugin this node belongs to.
var plugin

# The handle points that will be used to resize the mesh (NOT built in the format required by the gizmo)
var handles : Dictionary = {}

# Old handle points that are saved every time a handle has finished moving.
var old_handle_data : Dictionary = {}

# The OnyxMesh used to build and render the volumes.
var onyx_mesh = OnyxMesh.new()

# The debug shape, used to represent the volume in the editor.
var volume_geom = ImmediateGeometry.new()

# The node that all spawned nodes will be a child of.
var spawn_node = CSGCombiner.new()

# The set of positions to use for spawning objects when outside the Editor
var spawn_locations = []

# ////////////////////////////////////////////////////////////
# PATH PROPERTIES

var path_points = [] setget update_path_points

# ////////////////////////////////////////////////////////////
# SPAWN OBJECT
# The object to be spawned
export(String, FILE, "*.tscn") var spawn_object setget set_spawn_object


# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	print('_enter_tree')
	print(area_shape_parameters)
	
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:
		
		# load plugin
		plugin = get_node("/root/EditorNode/Onyx")
		
		set_notify_local_transform(true)
		set_notify_transform(true)
		set_ignore_transform_notification(false)
		
		# TODO : Remove when duplication fkin works.
		initialise_path()
	

# Initialises the node that will be used to parent all spawned nodes to.
func initialise_hierarchy():
	print("initialise_hierarchy")
	print(spawn_node)
	
	# duplication failsafe
	for child in self.get_children():
		if child.name == FluxCollectionName:
			spawn_node = child
			return
	
	# if none exist, make a new one
	if spawn_node.get_parent() == null:
		
		print("hierarchy failsafe PASSED")
		spawn_node.name = FluxCollectionName
		add_child(spawn_node)

# Initialises the path point array if none exist.
func initialise_path():
	
	var point_1 = Vector3(0, 0, 0)
	var point_2 = Vector3(0, 1, 2)
	var point_3 = Vector3(0, 0, 4)
	
	path_points = [point_1, point_2, point_3]
	


# ////////////////////////////////////////////////////////////
# BUILDERS

# Generates the wireframe that displays the path 
func generate_geometry():
	
	if is_inside_tree() == false:
		return
	
	print("generate_geometry")
	onyx_mesh.clear()
	
	var i_1 = 0
	var i_2 = 1
	var path_size = path_points.size()
	
	while path_size != 0:
		var point_1 = path_points[i_1]
		var point_2 = path_points[i_2]
		
		onyx_mesh.add_tri([point_1, point_2, point_2], [], [], [], [])
		
		path_size -= 1
		i_1 = clamp_int(i_1 + 1, 0, path_size - 1)
		i_2 = clamp_int(i_2 + 1, 0, path_size - 1)
	
	# hnnng too tired right now.
	onyx_mesh.render_wireframe(volume_geom, plugin.WireframeUtility_Selected)
	refresh_handle_data()

# Fetches and returns a series of points to spawn objets on, based on various parameters.
func build_location_array():
	
	if is_inside_tree() == false:
		return
	
	print("build_location_array")
	
	# can't raycast yet :(
#	if sprinkle_across_surfaces == true:
#		build_raycasted_location_array()
#		return
	
	var results = []
	var bounds = onyx_mesh.get_aabb()
	var upper_pos = bounds.position + bounds.size
	var lower_pos = bounds.position
	
	var points_found = 0
	
	# ################
	# GET DISTANCES
	
	# The distance between each set of two points
	var distances = []
	var total_distance = 0.0
	
	var i_1 = 0
	var i_2 = 1
	var path_size = path_points.size()
	
	while path_size != 0:
		# TODO : Edit for loop functionality
		if path_size == 1:
			return
		var point_1 = path_points[i_1]
		var point_2 = path_points[i_2]
		
		var segment_distance = point_1.distance_to(point_2)
		total_distance += segment_distance
		distances.append(segment_distance)
		
		path_size -= 1
		i_1 = clamp_int(i_1 + 1, 0, path_size - 1)
		i_2 = clamp_int(i_2 + 1, 0, path_size - 1)
	
	


# ////////////////////////////////////////////////////////////
# STANDARD HANDLE FUNCTIONS
# (DO NOT CHANGE THESE BETWEEN SCRIPTS)

# Returns the control points that the gizmo should currently have.
# Used by ControlPointGizmo to obtain that data once it's created, AFTER this node is created.
func get_gizmo_control_points() -> Array:
	return handles.values()

# Notifies the node that a handle has changed.
func handle_change(control):
	print("handle_change")
	update_handle_from_gizmo(control)
	generate_geometry()

# Called when a handle has stopped being dragged.
func handle_commit(control):
	print("handle_commit")
	update_handle_from_gizmo(control)
	apply_handle_attributes()
	
	build_location_array()
	spawn_children()
	
	old_handle_data = FluxUtils.get_control_data(self)


# ////////////////////////////////////////////////////////////
# STATES
# Returns a state that can be used to undo or redo a previous change to the shape.
func get_gizmo_redo_state():
	print("get_gizmo_redo_state")
	#return FluxUtils.get_gizmo_redo_state(self)
	return []
	
# Returns a state specifically for undo functions in SnapGizmo.
func get_gizmo_undo_state():
	print("get_gizmo_undo_state")
	#return FluxUtils.get_gizmo_undo_state(self)
	return []

# Restores the state of the shape to a previous given state.
func restore_state(state):
	print("restore_state")
	#FluxUtils.restore_state(self, state)
	pass
	
	
# ////////////////////////////////////////////////////////////
# SELECTION

func editor_select():
	volume_geom.material_override = mat_solid_color(plugin.WireframeUtility_Selected)
	
	
func editor_deselect():
	volume_geom.material_override = mat_solid_color(plugin.WireframeUtility_Unselected)
	
	
# ////////////////////////////////////////////////////////////
# HELPERS
	
func mat_solid_color(color):
	var mat = SpatialMaterial.new()
	mat.render_priority = mat.RENDER_PRIORITY_MAX
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.flags_no_depth_test = false
	mat.albedo_color = color
	
	return mat
