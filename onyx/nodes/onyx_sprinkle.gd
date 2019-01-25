
tool
extends "res://addons/onyx/nodes/onyx_node.gd"

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

enum VolumeShape {BOX, CYLINDER}
export(VolumeShape) var volume_type = VolumeShape.BOX setget set_volume_type


# ////////////////////////////////////////////////////////////
# SCRIPT EXPORTS
# The object to be spawned
export(String, FILE, ".tscn") var spawn_object

# The number of items that will be spawned
export(int, 0, 10000) var spawn_count = 0 setget set_spawn_count

# Unable to do raytracing rn.  </3
#export(bool) var sprinkle_across_surfaces = false


# //////
# Grid Options

# If true, points will no longer be randomised and the spawn count will no longer be used.
export(bool) var use_spawn_grid = false  setget toggle_spawn_grid

# if true, the bounds of the object being spawned will be added to the grid's size, making the grid
# size variable be used for additional padding between spawned objects instead.
var add_object_bounds_to_grid = false setget toggle_object_bound_grid

# The grid size to be used for spawning.
export(Vector3) var spawn_grid = Vector3(1, 1, 1)



# If true, the spawner will re-spawn objects during node transforms and size adjustments
export(bool) var update_during_movement = false

# Just an array of handle positions, used to track position changes and apply it to the node.
export(Array) var volume_handles = [] setget update_handles

# The set of positions to use for spawning objects when outside the Editor
export(Array) var spawn_locations = []

# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to.
var plugin

# The fuck is this here?
#var control = preload("res://addons/onyx/ui/tools/fence_toolbar.tscn")

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

# The handle points designed to provide the gizmo with information on how it should operate.
var gizmo_handles = []

# The faces used to generate the shape.
var face_set = load("res://addons/onyx/utilities/face_dictionary.gd").new()

# The debug shape, used to represent the volume in the editor.
var volume_geom = ImmediateGeometry.new()
var volume_inactive_color = Color(1, 1, 0, 0.7)

# The node that all spawned nodes will be a child of.
var spawn_node = Spatial.new()

# ////////////////////////x////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	# add transform notifications
	set_notify_local_transform(true)
	set_notify_transform(true)
	set_ignore_transform_notification(false)
	
	
	# If we're in the editor, do all this cool stuff, otherwise don't.
	if Engine.editor_hint == true:
		
		# get the gizmo (DISABLED DURING 3.1 ALPHA)
		plugin = get_node("/root/EditorNode/Onyx")
		gizmo = plugin.create_spatial_gizmo(self)
	
		# load geometry
		volume_geom.set_name("volume")
		add_child(volume_geom)
		volume_geom.material_override = mat_solid_color(plugin.WireframeUtility_Unselected)
	
		# Initialise volume data if we have none
		if volume_handles.size() == 0:
			initialise_handles()
		
		initialise_hierarchy()
		set_physics_process(true)
		
		# If we have spawn positions, use them.  Otherwise update everything
		if spawn_locations.size() > 0:
			update_volume()
			spawn_children()
			
		else:
			update_sprinkler()
	
	# If not, just get to spawning the assets.
	else:
		initialise_hierarchy()
		spawn_children()
	
	
# Initialises the node that will be used to parent 
func initialise_hierarchy():
	spawn_node.name = "Collection"
	add_child(spawn_node)


# Initialises volume_handles and handle data for the first time.
func initialise_handles():
	
	volume_handles = []
	volume_handles.append(Vector3(1, 0, 0))
	volume_handles.append(Vector3(0, 1, 0))
	volume_handles.append(Vector3(0, 0, 1))
	

func _notification(what):
	
	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
		
		# check that transform changes are local only
		if local_tracked_pos != translation:
			local_tracked_pos = translation
			call_deferred("_editor_transform_changed")
		
func _editor_transform_changed():
	
	#print("UPDATING TRANSFORM")
	if update_during_movement == true:
		update_sprinkler()
	
# ////////////////////////////////////////////////////////////
# UPDATERS

# Checks the children it has and the sprinkle settings, and starts sprinklin'
func update_sprinkler():
	
	#print("*******************")
	#print("updating sprinkler!")
	
	# update the volume based on the current volume_handles
	update_volume()
	
	# update the spawner
	build_location_array()
	spawn_children()
	
# Updates the geometry of the volume and the volume_handles responsible.
func update_volume():
	
	#print("updating volume...")
	
	match volume_type:
		
		VolumeShape.BOX:
			
			# fetch the current handle points
			var maxPoint = Vector3(volume_handles[0].x, volume_handles[1].y, volume_handles[2].z)
			var minPoint = maxPoint * -1
			
			# build the cuboid we'll need for spawning
			face_set.build_cuboid(maxPoint, minPoint)
			
			# if we're in the editor, show the visual representation and update the gizmo.
			if Engine.editor_hint == true:
				face_set.render_wireframe(volume_geom, volume_inactive_color)
			
				# Re-submit the handle positions based on the built faces, so other volume_handles that aren't the
				# focus of a handle operation are being updated
				var centre_points = face_set.get_all_centre_points()
				volume_handles = [centre_points[0], centre_points[2], centre_points[4]]
				
				# Build handle points in the required gizmo format.
				var face_list = face_set.get_face_vertices()
				
				gizmo_handles = []
				gizmo_handles.append([volume_handles[0], face_list[0] ])
				gizmo_handles.append([volume_handles[1], face_list[2] ])
				gizmo_handles.append([volume_handles[2], face_list[4] ])
				
				# Submit the changes to the gizmo
				if gizmo:
					gizmo.handle_points = gizmo_handles
					#gizmo.lines = gizmo_lines
		
		VolumeShape.CYLINDER:
			
			var width = volume_handles[0].x
			var height = volume_handles[1].y * 2
			
			# Build the volume geometry and render it.
			var position = Vector3(0, (height / 2) * -1, 0)
			var mesh_factory = load("res://addons/onyx/utilities/face_dictionary_factory.gd").new()
			face_set = mesh_factory.build_cylinder(face_set, 20, height, width, width, 2, position)
			
			# if we're in the editor, show the visual representation and update the gizmo.
			if Engine.editor_hint == true:
				face_set.render_wireframe(volume_geom, volume_inactive_color)
				
				# Volume handles must always be re-generated to ensure accurate snaps.
				var bounds = face_set.get_bounds()
				volume_handles = []
				volume_handles.append( Vector3(bounds.size.x + bounds.position.x, 0, 0) )
				volume_handles.append( Vector3(0, bounds.size.y + bounds.position.y, 0) )
				
				# Build handle points in the required gizmo format with snap surfaces.
				gizmo_handles = []
				gizmo_handles.append( [volume_handles[0], [Vector3(0, -1, -1), Vector3(0, 1, -1), Vector3(0, 1, 1)] ])
				gizmo_handles.append( [volume_handles[1], [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1)] ])
			
				# Submit the changes to the gizmo
				if gizmo:
					gizmo.handle_points = gizmo_handles
				

# Fetches and returns a series of points to spawn objets on, based on various parameters.
func build_location_array():
	
#	if sprinkle_across_surfaces == true:
#		build_raycasted_location_array()
#		return
	
	var results = []
	var bounds = face_set.get_bounds()
	var upper_pos = bounds.position + bounds.size
	var lower_pos = bounds.position
	
	var points_found = 0
	
	
	if use_spawn_grid == false:
		while points_found < spawn_count:
			
			#print("calculating new location...")
			
			var x = rand_range(lower_pos.x, upper_pos.x)
			var y = rand_range(lower_pos.y, upper_pos.y)
			var z = rand_range(lower_pos.z, upper_pos.z)
			var point = Vector3(x, y, z)
			
			if volume_type == VolumeShape.BOX:
				results.append(point)
				points_found += 1
				continue
			
			# If the volume type is not a box, we have to work out if this point lies outside the shape. 
			else:
				if face_set.is_point_inside_convex_hull(point) == true:
					results.append(point)
					
				points_found += 1
				
				
	else:
		#print("building spawn grid")
		var current_grid_size = self.spawn_grid
		
		# IF WE'RE GETTING AN OBJECT'S BOUNDS, BRACE YERSELF.
		if add_object_bounds_to_grid == true:
			#print("Obtaining spawn candidate AABB...")
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
		var volume_bounds = face_set.get_bounds().size
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
					
					if volume_type == VolumeShape.BOX:
						results.append(spawn_point)
					
					else:
						if face_set.is_point_inside_convex_hull(spawn_point) == true:
							results.append(spawn_point)
					
					grid_index.z += 1
				
				grid_index.z = 0
				grid_index.y += 1
				
			grid_index.z = 0
			grid_index.y = 0
			grid_index.x += 1
			
	
	#print("location calculations finished.")
	#print("results: ", results)
	spawn_locations = results
	
	
# ////////////////////////////////////////////////////////////
# RAYCASTS

# Find any raycast candidates
func build_raycasted_location_array():
	
	print("RAAAYYYZZZZ")
	
	var results = []
	var space_state = get_world().direct_space_state
	
	var bounds = face_set.get_bounds()
	var start_height = bounds.position.y + bounds.size.y
	var upper_pos = bounds.position + bounds.size
	var lower_pos = bounds.position
	
	var points_found = 0
	
	while points_found < spawn_count:
		
		# get the start and end point
		var x = rand_range(lower_pos.x, upper_pos.x)
		var z = rand_range(lower_pos.z, upper_pos.z)
		
		var start = Vector3(x, start_height, z)
		var end = Vector3(x, lower_pos.y, z)
		
		# see if we catch something
		var raycast_result = space_state.intersect_ray(start, end)
		print(raycast_result)
		if raycast_result.empty() == false:
			results.append(raycast_result["position"])
			
		points_found += 1
		
	spawn_locations = results
				
				

# Finds and returns an instance of the node to be spawned.
func spawn_node_candidate():
	
	if spawn_object == "" || spawn_object == null:
		
		# find all the children in this node
		for child in self.get_children():
			
			if child.name == volume_geom.name:
				continue
			elif child.name == spawn_node.name:
				continue
			
			elif child is Spatial:
				return child
				
	else:
		var object = load(spawn_object) # will load when the script is instanced
		var object_node = object.instance()
		return object_node
			
				
				
# Actually gets down to spawning children \o/
func spawn_children():
	
	# remove all previous objects
	for child in spawn_node.get_children():
		spawn_node.remove_child(child)
	
	# spawn a new object
	var candidate = spawn_node_candidate()
	if candidate == null:
		print("Unable to SPRINKLE - no child node or valid Spawn Object scene found,")
		return
		
	if spawn_locations.size() == 0:
		print("Unable to SPRINKLE - no spawn locations found,")
		return
	
	for location in spawn_locations:
			
		var duplicate = candidate.duplicate()
		duplicate.translation = location
		spawn_node.add_child(duplicate)
					


# ////////////////////////////////////////////////////////////
# HANDLES

# Receives an update from the gizmo when a handle is currently being dragged.
func handle_change(index, coord):
	
	#print("HANDLE UPDATE")
	volume_handles[index] = coord
	
	if update_during_movement == true:
		update_sprinkler()
	else:
		update_volume()
	
	
	
# Receives an update from the gizmo when a handle has finished being dragged.
func handle_commit(index, coord):
	
	#print("HANDLE COMMIT")
	volume_handles[index] = coord
	#update_sprinkler()
	
	
# ////////////////////////////////////////////////////////////
# GETTERS / SETTERS

# Toggles between grid spawning and randomised spawning.
func toggle_spawn_grid(new_value):
	print("toggling...")
	use_spawn_grid = new_value
	
	build_location_array()
	spawn_children()
	
# Toggles between using the object bounds for grid spacing and not using it.
func toggle_object_bound_grid(new_value):
	add_object_bounds_to_grid = new_value
	
	build_location_array()
	spawn_children()
	
func update_handles(new_value):
	volume_handles = new_value
	
	update_sprinkler()

# Gives the gizmo an undo state to use when undoing handle movement.
func get_undo_state():
	
	return volume_handles
	
# Restores a previous handle state.
func restore_state(state):
	
	volume_handles = state
	update_sprinkler()
	

func set_volume_type(new_value):
	
	# Set new volume handles depending on the change made.
	var area = face_set.get_bounds()
	volume_handles = []
	
	# Generate new handles based on the new volume type.
	match new_value:
		VolumeShape.BOX:
			volume_handles.append(Vector3(area.size.x / 2, 0, 0))
			volume_handles.append(Vector3(0, area.size.y / 2, 0))
			volume_handles.append(Vector3(0, 0, area.size.z / 2))
		
		VolumeShape.CYLINDER:
			volume_handles.append(Vector3(area.size.x / 2, 0, 0))
			volume_handles.append(Vector3(0, area.size.y / 2, 0))
			
	
	volume_type = new_value
	update_sprinkler()
	
func set_spawn_count(new_value):
	spawn_count = new_value
	build_location_array()
	spawn_children()
	
	
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
