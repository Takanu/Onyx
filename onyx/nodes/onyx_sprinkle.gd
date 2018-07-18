
tool
extends "res://addons/onyx/nodes/onyx_node.gd"

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

enum VolumeShape {BOX, CYLINDER}
export(VolumeShape) var volume_type = BOX setget set_volume_type


# ////////////////////////////////////////////////////////////
# SCRIPT EXPORTS
# The number of items that will be spawned
export(int, 0, 10000) var spawn_count = 0 setget set_spawn_count


export(bool) var sprinkle_across_surfaces = false


# If true, the spawner will re-spawn objects during node transforms and size adjustments
export(bool) var update_during_movement = false

# Just an array of handle positions, used to track position changes and apply it to the node.
export(Array) var volume_handles = []

# The set of positions to use for spawning objects when outside the Editor
export(Array) var spawn_locations = []

# ////////////////////////////////////////////////////////////
# PROPERTIES

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

# The handle points designed to provide the gizmo with information on how it should operate.
var gizmo_handles = []

# The faces used to generate the shape.
var face_set = load("res://addons/onyx/utilities/face_dictionary.gd").new()

# The debug shape, used to represent the volume in the editor.
var volume_geom = ImmediateGeometry.new()
var volume_active_color = Color(1, 1, 0, 1)
var volume_inactive_color = Color(1, 1, 0, 0.4)

# The node that all spawned nodes will be a child of.
var spawn_node = Spatial.new()

# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	# add transform notifications
	set_notify_local_transform(true)
	set_notify_transform(true)
	set_ignore_transform_notification(false)
	
	
	# If we're in the editor, do all this cool stuff, otherwise don't.
	if Engine.editor_hint == true:
		
		# get the gizmo
		var plugin = get_node("/root/EditorNode/Onyx")
		gizmo = plugin.create_spatial_gizmo(self)
	
		# load geometry
		volume_geom.set_name("volume")
		add_child(volume_geom)
		volume_geom.material_override = mat_solid_color(volume_inactive_color)
	
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
			face_set.build_cylinder(20, height, width, 1, position)
			
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
				

# Fetches and returns a series of randomized location points that 
func build_location_array():
	
	if sprinkle_across_surfaces == true:
		build_raycasted_location_array()
		return
	
	var results = []
	var bounds = face_set.get_bounds()
	var upper_pos = bounds.position + bounds.size
	var lower_pos = bounds.position
	
	var points_found = 0
	
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
	
	#print("location calculations finished.")
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
				
				
# Actually gets down to spawning children \o/
func spawn_children():
	
	# remove all previous objects
	for child in spawn_node.get_children():
		spawn_node.remove_child(child)
	
	# find all the children in this node
	for child in self.get_children():
		
		if child.name == volume_geom.name:
			continue
		elif child.name == spawn_node.name:
			continue
		
		elif child is Spatial:
	
			for location in spawn_locations:
					
				var dup = child.duplicate()
				dup.translation = location
				spawn_node.add_child(dup)


# ////////////////////////////////////////////////////////////
# HANDLES

# Receives an update from the gizmo when a handle is currently being dragged.
func handle_update(index, coord):
	
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
# HELPERS
	
func mat_solid_color(color):
	var mat = SpatialMaterial.new()
	mat.render_priority = mat.RENDER_PRIORITY_MAX
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.flags_no_depth_test = true
	mat.albedo_color = color
	
	return mat
