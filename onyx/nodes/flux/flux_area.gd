tool
extends CSGCombiner

# ////////////////////////////////////////////////////////////
# INFO
# Flux tool - generate random or organised clusters of nodes within a pre-defined area.


# ////////////////////////////////////////////////////////////
# DEPENDENCIES
var FluxUtils = load("res://addons/onyx/nodes/flux/flux_utils.gd")


# ////////////////////////////////////////////////////////////
# AREA TYPE
# The area thats used to distribute nodes within.
enum AreaShape {BOX, CYLINDER}
export(AreaShape) var area_type = AreaShape.BOX setget set_area_type
var previous_area_type = AreaShape.BOX

# used to keep the handle values driving shape changes alive?  or precisely amendable?  idk yet.
export(Dictionary) var area_shape_parameters : Dictionary = {} setget update_area_shape_parameters


# ////////////////////////////////////////////////////////////
# SPAWN OBJECT
# The object to be spawned
export(String, FILE, "*.tscn") var spawn_object setget set_spawn_object

# The number of items that will be spawned
export(int, 0, 10000) var spawn_count = 1 setget set_spawn_count

# Unable to do raytracing rn.  </3
#export(bool) var sprinkle_across_surfaces = false


# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to.
var plugin

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

# The handle points that will be used to resize the mesh (NOT built in the format required by the gizmo)
var handles : Dictionary = {}

# Old handle points that are saved every time a handle has finished moving.
var old_handles : Dictionary = {}



# The debug shape, used to represent the volume in the editor.
var volume_geom = ImmediateGeometry.new()

# The inactive and active colour used to render the shape.
var volume_inactive_color = Color(1, 1, 0, 0.7)

# The OnyxMesh used to build and render the volumes.
var onyx_mesh = OnyxMesh.new()


# The node that all spawned nodes will be a child of.
var spawn_node = CSGCombiner.new()

# The set of positions to use for spawning objects when outside the Editor
var spawn_locations = []


# ////////////////////////////////////////////////////////////
# GRID OPTIONS

# If true, points will no longer be randomised and the spawn count will no longer be used.
export(bool) var use_spawn_grid = false  setget toggle_spawn_grid

# if true, the bounds of the object being spawned will be added to the grid's size, making the grid
# size variable be used for additional padding between spawned objects instead.
export(bool) var add_object_bounds_to_grid = false setget toggle_object_bound_grid

# The grid size to be used for spawning.
export(Vector3) var spawn_grid = Vector3(1, 1, 1) setget set_spawn_grid

# If true, the spawner will re-spawn objects during node transforms and size adjustments
export(bool) var update_during_movement = false 


# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:
		
		# load plugin
		plugin = get_node("/root/EditorNode/Onyx")
		
		# load geometry
		volume_geom.set_name("volume")
		add_child(volume_geom)
		volume_geom.material_override = mat_solid_color(plugin.WireframeUtility_Unselected)
		
		initialise_hierarchy()
		
		set_notify_local_transform(true)
		set_notify_transform(true)
		set_ignore_transform_notification(false)
	

func _ready():
	
	print("_ready")
	
	# Only generate geometry if we have nothing and we're running inside the editor, this likely indicates the node is brand new.
	if Engine.editor_hint == true:
		if area_shape_parameters.size() == 0:
			generate_volume()
			
		# if we have no handles already, make some
		# (used during duplication and other functions)
		if handles.size() == 0:
			generate_handles()
		
		# Ensure the old_handles variable match the current handles we have for undo/redo.
		old_handles = handles.duplicate(true)
		

# Initialises the node that will be used to parent all spawned nodes to.
func initialise_hierarchy():
	spawn_node.name = "Collection"
	add_child(spawn_node)


func _notification(what):
	
	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
		
		# check that transform changes are local only
		if local_tracked_pos != translation:
			local_tracked_pos = translation
			call_deferred("_editor_transform_changed")
		
func _editor_transform_changed():
	
	#print("UPDATING TRANSFORM")
	if update_during_movement == true:
		generate_volume()
		build_location_array()
		spawn_children()
	
# ////////////////////////////////////////////////////////////
# UPDATERS

# Recalculates the area parameters 
func update_area_shape_parameters(new_value):
	print("update_area_shape_parameters")
	area_shape_parameters = new_value
	
	generate_geometry()
	build_location_array()
	spawn_children()

func set_spawn_object(new_value):
	print("set_spawn_object")
	spawn_object = new_value
	build_location_array()
	spawn_children()

func set_spawn_count(new_value):
	print("set_spawn_count")
	spawn_count = new_value
	build_location_array()
	spawn_children()

# Toggles between grid spawning and randomised spawning.
func toggle_spawn_grid(new_value):
	print("toggle_spawn_grid")
	use_spawn_grid = new_value
	
	build_location_array()
	spawn_children()
	

# Toggles between using the object bounds for grid spacing and not using it.
func toggle_object_bound_grid(new_value):
	print("toggle_object_bound_grid")
	add_object_bounds_to_grid = new_value
	
	build_location_array()
	spawn_children()
	

func set_spawn_grid(new_value):
	spawn_grid = new_value
	
	build_location_array()
	spawn_children()

# Changes the type of area being used, requiring a rebuild of the volume.
func set_area_type(new_value):
	
	print("set_area_type")
	
	# If it equals the previous one, do nothing
	if previous_area_type == new_value:
		return
	
	if is_inside_tree() == false:
		return
	
	print("set_area_type CHECKS SUCCEEDED")

	area_type = new_value
	
	# Set new volume handles depending on the change made.
	generate_volume()
	
	# ensure the origin mode toggle is preserved, and ensure the adjusted handles are saved.
	previous_area_type = area_type
	old_handles = handles.duplicate()
	

# ////////////////////////////////////////////////////////////
# BUILDERS


# Updates the geometry of the volume and the volume_handles responsible.
func generate_volume():
	
	if is_inside_tree() == false:
		return
	
	print("generate_volume")
	
	# get the current AABB so we can make estimations on the box size.
	var aabb = onyx_mesh.get_aabb()
	var maxPoint = aabb.position + aabb.size
	
	if aabb == null or aabb.size == Vector3():
		maxPoint = aabb.position + Vector3(2, 2, 2)
	
	match area_type:
		
		AreaShape.BOX:
			# build the cuboid we'll need for spawning
			var mesh_factory = OnyxMeshFactory.new()
			mesh_factory.build_cuboid(onyx_mesh, aabb.position, maxPoint, 0, Vector3(1, 1, 1))
			
		AreaShape.CYLINDER:
			# build the cuboid we'll need for spawning
			var mesh_factory = OnyxMeshFactory.new()
			mesh_factory.build_cylinder(onyx_mesh, 16, aabb.size.y, aabb.size.x / 2, aabb.size.z / 2, 1, Vector3(0, -aabb.size.y / 2, 0), 0, false)
	
	
	# clear the current area shape parameters and provide new ones
	build_area_shape_parameters()
	generate_geometry()
	build_location_array()
	

# Generates the geometry for the current area wireframe and renders it.
func generate_geometry():
	
	if is_inside_tree() == false:
		return
	
	print("generate_geometry")
	onyx_mesh.clear()
	
	match area_type:
		AreaShape.BOX:
			var mesh_factory = OnyxMeshFactory.new()
			var x_size = area_shape_parameters['x_size']
			var y_size = area_shape_parameters['y_size']
			var z_size = area_shape_parameters['z_size']
			
			var minPoint = Vector3(-x_size/2, -y_size/2, -z_size/2)
			var maxPoint = Vector3(x_size/2, y_size/2, z_size/2)
			
			mesh_factory.build_cuboid(onyx_mesh, minPoint, maxPoint, 0, Vector3(1, 1, 1))
		
		AreaShape.CYLINDER:
			var mesh_factory = OnyxMeshFactory.new()
			var x_size = area_shape_parameters['x_size']
			var y_size = area_shape_parameters['y_size']
			var z_size = area_shape_parameters['z_size']
			
			mesh_factory.build_cylinder(onyx_mesh, 16, y_size, x_size / 2, z_size / 2, 1, Vector3(0, -y_size / 2, 0), 0, false)
		
	onyx_mesh.render_wireframe(volume_geom, volume_inactive_color)
	generate_handles()
	


# Builds area shape parameters if none currently exist.
func build_area_shape_parameters():
	
	print("build_area_shape_parameters")
	
	match area_type:
		AreaShape.BOX:
			
			# get the current area so we can make estimations on the box size.
			var aabb = onyx_mesh.get_aabb()
			var maxPoint = aabb.position + aabb.size
			
			# clear the current area shape parameters and provide new ones
			area_shape_parameters.clear()
			area_shape_parameters['x_size'] = aabb.size.x
			area_shape_parameters['y_size'] = aabb.size.y
			area_shape_parameters['z_size'] = aabb.size.z
			
			print(area_shape_parameters)
		
		AreaShape.CYLINDER:
			
			# get the current area so we can make estimations on the box size.
			var aabb = onyx_mesh.get_aabb()
			var maxPoint = aabb.position + aabb.size
			
			# clear the current area shape parameters and provide new ones
			area_shape_parameters.clear()
			area_shape_parameters['x_size'] = aabb.size.x
			area_shape_parameters['y_size'] = aabb.size.y
			area_shape_parameters['z_size'] = aabb.size.z
			
			print(area_shape_parameters)
		
	

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
	
	# If we're not using a grid, this is pretty simple.
	if use_spawn_grid == false:
		while points_found < spawn_count:
			
			print("calculating new location...")
			
			var x = rand_range(lower_pos.x, upper_pos.x)
			var y = rand_range(lower_pos.y, upper_pos.y)
			var z = rand_range(lower_pos.z, upper_pos.z)
			var point = Vector3(x, y, z)
			
			if area_type == AreaShape.BOX:
				results.append(point)
				points_found += 1
				continue
			
			# If the volume type is not a box, we have to work out if this point lies outside the shape. 
			else:
				if onyx_mesh.raycast_point_convex_hull(point) == true:
					results.append(point)
				
				points_found += 1
			
	
	# If we're using a grid, be organised about this
	else:
		print("building spawn grid")
		var current_grid_size = self.spawn_grid
		
		# IF WE'RE GETTING AN OBJECT'S BOUNDS, BRACE YERSELF.
		if add_object_bounds_to_grid == true:
			print("Obtaining spawn candidate AABB...")
			var target_node = spawn_node_candidate()
			if target_node == null:
				print("Unable to SPRINKLE - no child node or valid Spawn Object scene found,")
				return

			# load our utils kit and get the node area.
			var onyx_utils = load("res://addons/onyx/utilities/onyx_utils.gd").new()
			var node_aabb = onyx_utils.get_aabb(target_node)
			current_grid_size += node_aabb.size

			# deallocate what we don't need.
			onyx_utils.free()
			target_node.free()

		#print("getting face set bounds")

		# Average the grid to fit inside the bounds.
		var volume_bounds = onyx_mesh.get_aabb().size
		var grid_count = volume_bounds / spawn_grid
		grid_count.x = floor(grid_count.x)
		grid_count.y = floor(grid_count.y)
		grid_count.z = floor(grid_count.z)
		
		#print(grid_count)

		# now we have the grid count we can fit, multiply it by the grid size and get the starting location.
		var grid_end = (grid_count * current_grid_size) / 2
		var grid_start = grid_end / -1
		
		grid_start += current_grid_size / 2
		grid_end += current_grid_size / 2
		
		#print(volume_bounds)
		
		#print(grid_start)
		#print(grid_end)
		#print(current_grid_size)

		# NOW LETS ITERATE
		var grid_index = Vector3(0, 0, 0)
		#print("starting grid iterations")
		
		while grid_index.x < grid_count.x:
			var spawn_x = grid_start.x + (current_grid_size.x * grid_index.x)
			
			while grid_index.y < grid_count.y:
				var spawn_y = grid_start.y + (current_grid_size.y * grid_index.y)
				
				while grid_index.z < grid_count.z:
					var spawn_z = grid_start.z + (current_grid_size.z * grid_index.z)
					var spawn_point = Vector3(spawn_x, spawn_y, spawn_z)
					
					if area_type == AreaShape.BOX:
						results.append(spawn_point)
					
					else:
						if onyx_mesh.raycast_point_convex_hull(spawn_point) == true:
							results.append(spawn_point)
					
					grid_index.z += 1
				
				grid_index.z = 0
				grid_index.y += 1
				
			grid_index.z = 0
			grid_index.y = 0
			grid_index.x += 1
			
	
	print("location calculations finished.")
	print("results: ", results)
	spawn_locations = results
	
	
# ////////////////////////////////////////////////////////////
# SPAWNERS


# Actually gets down to spawning children \o/
func spawn_children():
	
	if is_inside_tree() == false:
		return
	
	print("spawn_children")
	
	# remove all previous objects
	for child in spawn_node.get_children():
		spawn_node.remove_child(child)
	
	# spawn a new object
	var candidate = spawn_node_candidate()
	print('candidate - ', candidate)
	
	if candidate == null:
		print("Unable to SPRINKLE - no child node or valid Spawn Object scene found,")
		return
		
	if spawn_locations.size() == 0:
		
		print("Unable to SPRINKLE - no spawn locations found,")
		return
	
	for location in spawn_locations:
		
		# If we're using a grid, be organised about this
		var duplicate = candidate.duplicate()
		duplicate.translation = location
		spawn_node.add_child(duplicate)
					

# Finds and returns an instance of the node to be spawned.
func spawn_node_candidate():
	
	print("spawn_node_candidate")
	
#	if spawn_object == "" || spawn_object == null:
#
#		# find all the children in this node
#		for child in self.get_children():
#
#			if child.name == volume_geom.name:
#				continue
#			elif child.name == spawn_node.name:
#				continue
#
#			elif child is Spatial:
#				return child
				
	if spawn_object != "":
		print("trying to spawn an object node!")
		var object = load(spawn_object) # will load when the script is instanced
		var object_node = object.instance()
		return object_node
			
				
				

# ////////////////////////////////////////////////////////////
# GIZMO HANDLES

# Uses the current settings to refresh the handle list.
func generate_handles():
	handles.clear()
	
	print("generate_handles")
	
	match area_type:
		AreaShape.BOX:
			
			var x_size = area_shape_parameters['x_size']
			var y_size = area_shape_parameters['y_size']
			var z_size = area_shape_parameters['z_size']
			
			print(x_size)
			
			handles['x_size'] = Vector3(x_size / 2, 0, 0)
			handles['y_size'] = Vector3(0, y_size / 2, 0)
			handles['z_size'] = Vector3(0, 0, z_size / 2)
		
		AreaShape.CYLINDER:
			
			var x_size = area_shape_parameters['x_size']
			var y_size = area_shape_parameters['y_size']
			var z_size = area_shape_parameters['z_size']
			
			handles['x_size'] = Vector3(x_size / 2, 0, 0)
			handles['y_size'] = Vector3(0, y_size / 2, 0)
			handles['z_size'] = Vector3(0, 0, z_size / 2)
	

# Converts the dictionary format of handles to a pair of handles with optional triangle for normal snaps.
func convert_handles_to_gizmo() -> Array:
	
	# convert handles here
	var result = []
	
	# generate collision triangles
	var triangle_x = [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_y = [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]
	var triangle_z = [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	
	# convert handle values to an array
	var handle_array = handles.values()
	
	match area_type:
		AreaShape.BOX:
			
			result.append( [handle_array[0], triangle_x] )
			result.append( [handle_array[1], triangle_y] )
			result.append( [handle_array[2], triangle_z] )
		
		AreaShape.CYLINDER:
			
			result.append( [handle_array[0], triangle_x] )
			result.append( [handle_array[1], triangle_y] )
			result.append( [handle_array[2], triangle_z] )
	
	return result


# Converts the gizmo handle format of an array of points and applies it to the dictionary format for Onyx.
func convert_handles_to_onyx(handles) -> Dictionary:
	
	var result = {}
	result["x_size"] = handles[0]
	result["y_size"] = handles[1]
	result["z_size"] = handles[2]
	
	return result
	

# Changes the handle based on the given index and coordinates.
func update_handle_from_gizmo(index, coordinate):
	
	match area_type:
		AreaShape.BOX:
			match index:
				0: area_shape_parameters['x_size'] = max(coordinate.x, 0) * 2
				1: area_shape_parameters['y_size'] = max(coordinate.y, 0) * 2
				2: area_shape_parameters['z_size'] = max(coordinate.z, 0) * 2
		
		AreaShape.CYLINDER:
			match index:
				0: area_shape_parameters['x_size'] = max(coordinate.x, 0) * 2
				1: area_shape_parameters['y_size'] = max(coordinate.y, 0) * 2
				2: area_shape_parameters['z_size'] = max(coordinate.z, 0) * 2

# Applies the current handle values to the shape attributes
func apply_handle_attributes():
	
	match area_type:
		AreaShape.BOX:
			area_shape_parameters['x_size'] = handles["x_size"].x * 2
			area_shape_parameters['y_size'] = handles["y_size"].y * 2
			area_shape_parameters['z_size'] = handles["z_size"].z * 2
			
		AreaShape.CYLINDER:
			area_shape_parameters['x_size'] = handles["x_size"].x * 2
			area_shape_parameters['y_size'] = handles["y_size"].y * 2
			area_shape_parameters['z_size'] = handles["z_size"].z * 2


# ////////////////////////////////////////////////////////////
# STANDARD HANDLE FUNCTIONS
# (DO NOT CHANGE THESE BETWEEN SCRIPTS)

# Notifies the node that a handle has changed.
func handle_change(index, coord):
	update_handle_from_gizmo(index, coord)
	generate_geometry()

# Called when a handle has stopped being dragged.
func handle_commit(index, coord):
	update_handle_from_gizmo(index, coord)
	apply_handle_attributes()
	
	build_location_array()
	spawn_children()
	
	old_handles = handles.duplicate(true)


# ////////////////////////////////////////////////////////////
# STATES
# Returns a state that can be used to undo or redo a previous change to the shape.
func get_gizmo_redo_state():
	#return FluxUtils.get_gizmo_redo_state(self)
	return []
	
# Returns a state specifically for undo functions in SnapGizmo.
func get_gizmo_undo_state():
	#return FluxUtils.get_gizmo_undo_state(self)
	return []

# Restores the state of the shape to a previous given state.
func restore_state(state):
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
	mat.flags_no_depth_test = true
	mat.albedo_color = color
	
	return mat
