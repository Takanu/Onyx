tool
extends Spatial

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

enum OriginPosition {CENTER, BASE, BASE_CORNER}
export(OriginPosition) var origin_setting = BASE setget set_origin_mode

# ////////////////////////////////////////////////////////////
# PROPERTIES

var face_set = load("res://addons/onyx/utilities/face_dictionary.gd").new()

# The handle points that will be used to resize the cube (NOT built in the format required by the gizmo)
var handles = []

# The handle points designed to provide the gizmo with information on how it should operate.
var gizmo_handles = []

# Old handle points that are saved every time a handle has finished moving.
var old_handles = []

# The offset of the origin relative to the rest of the cube.
var origin_offset = Vector3(0, 0, 0)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

var geom = ImmediateGeometry.new()
var color = Vector3(1, 1, 1)

# Exported variables representing all usable handles for re-shaping the cube, in order.
# Must be exported to be saved in a scene?  smh.
export(float) var x_plus_position = 0.5 setget update_x_plus
export(float) var x_minus_position = -0.5 setget update_x_minus

export(float) var y_plus_position = 0.5 setget update_y_plus
export(float) var y_minus_position = -0.5 setget update_y_minus

export(float) var z_plus_position = 0.5 setget update_z_plus
export(float) var z_minus_position = -0.5 setget update_z_minus


# ////////////////////////////////////////////////////////////
# FUNCTIONS


# Global initialisation
func _enter_tree():
	#print("****************")
	#print("entering tree...")
	
	# load gizmos
	var plugin = get_node("/root/EditorNode/Onyx")
	gizmo = plugin.create_spatial_gizmo(self)
	#print(face_set)
	#print(gizmo)
	
	# load geometry
	geom.set_name("geom")
	add_child(geom)
	generate_geometry(true) 
	
	# set gizmo stuff
	old_handles = face_set.get_all_centre_points()
	
	set_notify_local_transform(true)
	set_notify_transform(true)
	set_ignore_transform_notification(false)
	
func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	
	pass
	
func _notification(what):
	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
		
		# check that transform changes are local only
		if local_tracked_pos != translation:
			local_tracked_pos = translation
			call_deferred("_editor_transform_changed")
		
func _editor_transform_changed():
	generate_geometry(true)

				
# ////////////////////////////////////////////////////////////
# GENERATE GEOMETRY
	
	
# Used when a handle variable changes in the properties panel.
func update_x_plus(new_value):
	x_plus_position = new_value
	generate_geometry(true)
	
func update_x_minus(new_value):
	x_minus_position = new_value
	generate_geometry(true)
	
func update_y_plus(new_value):
	y_plus_position = new_value
	generate_geometry(true)
	
func update_y_minus(new_value):
	y_minus_position = new_value
	generate_geometry(true)
	
func update_z_plus(new_value):
	z_plus_position = new_value
	generate_geometry(true)
	
func update_z_minus(new_value):
	z_minus_position = new_value
	generate_geometry(true)
	


# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting):
	
	#print("Regenerating geometry")
	
	var maxPoint = Vector3(x_plus_position, y_plus_position, z_plus_position)
	var minPoint = Vector3(x_minus_position, y_minus_position, z_minus_position)
	
	if fix_to_origin_setting == true:
		match origin_setting:
			OriginPosition.BASE:
				maxPoint = Vector3(x_plus_position, (y_plus_position + (y_minus_position * -1)), z_plus_position)
				minPoint = Vector3(x_minus_position, 0, z_minus_position)
				
			OriginPosition.BASE_CORNER:
				maxPoint = Vector3(
					(x_plus_position + (x_minus_position * -1)), 
					(y_plus_position + (y_minus_position * -1)), 
					(z_plus_position + (z_minus_position * -1))
					)
				minPoint = Vector3(0, 0, 0)
				
	face_set.build_cuboid(maxPoint, minPoint)
	face_set.render_geometry(geom)
	
	
	# Re-submit the handle positions based on the built faces, so other handles that aren't the
	# focus of a handle operation are being updated
	var centre_points = face_set.get_all_centre_points()
	handles = centre_points
	#print(handles[0])
	
	x_plus_position = centre_points[0].x
	x_minus_position = centre_points[1].x
	y_plus_position = centre_points[2].y
	y_minus_position = centre_points[3].y
	z_plus_position = centre_points[4].z
	z_minus_position = centre_points[5].z
	
	
	# Build handle points in the required gizmo format.
	var face_list = face_set.get_face_vertices()
	
	gizmo_handles = []
	for i in handles.size():
		gizmo_handles.append([handles[i], face_list[i] ])
	
	# Submit the changes to the gizmo
	if gizmo:
		gizmo.handle_points = gizmo_handles
		gizmo.redraw()
		
	
	
	
# ////////////////////////////////////////////////////////////
# EDIT STATE

func get_undo_state():
	
	return [old_handles, self.translation]
	

# Restores the state of the cube to a previous given state.
func restore_state(state):
	var new_handles = state[0]
	var stored_translation = state[1]
	
	x_plus_position = new_handles[0].x
	x_minus_position = new_handles[1].x
	y_plus_position = new_handles[2].y
	y_minus_position = new_handles[3].y
	z_plus_position = new_handles[4].z
	z_minus_position = new_handles[5].z
	
	self.translation = stored_translation
	self.old_handles = new_handles
	generate_geometry(true)


# Notifies the node that a handle has changed.
func handle_update(index, coord):
	
	change_handle(index, coord)
	generate_geometry(false)
	

# Called when a handle has stopped being dragged.
func handle_commit(index, coord):
	
	change_handle(index, coord)
	update_origin()
	balance_handles()
	generate_geometry(true)
	
	# store old handle points for later.
	old_handles = face_set.get_all_centre_points()
	
			
# Returns the handle with the corresponding coordinates.	
func get_handle(index):
	
	return handles[index]
	

# Changes the handle based on the given index and coordinates.
func change_handle(index, coordinate):
	
	match index:
		0: x_plus_position = coordinate.x
		1: x_minus_position = coordinate.x
		2: y_plus_position = coordinate.y
		3: y_minus_position = coordinate.y
		4: z_plus_position = coordinate.z
		5: z_minus_position = coordinate.z
	
	
# Moves the handle by the given index and coordinate offset.
func move_handle(index, coordinate):
	
	match index:
		0: x_plus_position += coordinate.x
		1: x_minus_position += coordinate.x
		2: y_plus_position += coordinate.y
		3: y_minus_position += coordinate.y
		4: z_plus_position += coordinate.z
		5: z_minus_position += coordinate.z
	
	
func balance_handles():
	#print("balancing coordinates")
		
	var diff = abs(x_plus_position - x_minus_position)
	x_plus_position = diff / 2
	x_minus_position = (diff / 2) * -1
	
	diff = abs(y_plus_position - y_minus_position)
	y_plus_position = diff / 2
	y_minus_position = (diff / 2) * -1
	
	diff = abs(z_plus_position - z_minus_position)
	z_plus_position = diff / 2
	z_minus_position = (diff / 2) * -1
	

func set_origin_mode(new_value):
	
	origin_setting = new_value
	update_origin()
	balance_handles()
	generate_geometry(true)
		

# Updates the origin during generate_geometry() as well as the currently defined handles, 
# to ensure it's anchored where it needs to be.
func update_origin():
	
	# Get all handle positions in global terms.
	var global_handles = []
	for handle in handles:
		global_handles.append(self.to_global(handle))
	
	var x_coord = 0.0
	var y_coord = 0.0
	var z_coord = 0.0
	
	# set it based on the current origin position.
	match origin_setting:
		OriginPosition.CENTER:
			x_coord = (handles[0].x + handles[1].x ) / 2
			y_coord = (handles[2].y + handles[3].y ) / 2
			z_coord = (handles[4].z + handles[5].z ) / 2
		OriginPosition.BASE:
			x_coord = (handles[0].x + handles[1].x ) / 2
			y_coord = handles[3].y 
			z_coord = (handles[4].z + handles[5].z ) / 2
		OriginPosition.BASE_CORNER:
			x_coord = handles[1].x 
			y_coord = handles[3].y
			z_coord = handles[5].z 
	
	# Get the difference
	var new_loc = self.to_global(Vector3(x_coord, y_coord, z_coord))
	var old_loc = self.translation
	#print("MOVING LOCATION: ", old_loc, new_loc)
	
	# set it
	self.global_translate(new_loc - old_loc)
	
	
# Updates the collision triangles responsible for detecting cursor selection in the editor.
func get_gizmo_collision():
	var triangles = face_set.get_triangles()
	
	var return_t = PoolVector3Array()
	for triangle in triangles:
		return_t.append(triangle * 10)
		
	return return_t

# ////////////////////////////////////////////////////////////
# HELPERS

func idek():
	
	# Check if we need to offset geometry based on the origin
	var offset = Vector3()
	match origin_setting:
		OriginPosition.BASE:
			offset = Vector3(x_plus_position, y_minus_position, z_plus_position)
		OriginPosition.BASE_CORNER:
			offset = Vector3(x_minus_position, y_minus_position, z_minus_position)

