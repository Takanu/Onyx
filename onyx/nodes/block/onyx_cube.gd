tool
extends CSGMesh

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

# allows origin point re-orientation, for precise alignments and convenience.
enum OriginPosition {CENTER, BASE, BASE_CORNER}
export(OriginPosition) var origin_setting = OriginPosition.BASE setget update_origin_mode

# used to keep track of how to move the origin point into a new position.
var previous_origin_setting = OriginPosition.BASE

# used to force an origin update when using the sliders to adjust positions.
export(bool) var update_origin_setting = true setget update_positions

# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to
var plugin

# The face set script, used for managing geometric data.
var tri_array = OnyxMesh.new()

# Materials assigned to gizmos.
var gizmo_mat = load("res://addons/onyx/materials/gizmo_t1.tres")


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

var color = Vector3(1, 1, 1)

# Exported variables representing all usable handles for re-shaping the cube, in order.
# Must be exported to be saved in a scene?  smh.
export(float) var x_plus_position = 0.5 setget update_x_plus
export(float) var x_minus_position = -0.5 setget update_x_minus

export(float) var y_plus_position = 0.5 setget update_y_plus
export(float) var y_minus_position = -0.5 setget update_y_minus

export(float) var z_plus_position = 0.5 setget update_z_plus
export(float) var z_minus_position = -0.5 setget update_z_minus

export(float) var bevel_size = 0.2 setget update_bevel_size
enum BevelTarget {Y_AXIS, X_AXIS, Z_AXIS}
export(BevelTarget) var bevel_target = BevelTarget.Y_AXIS setget update_bevel_target


# ////////////////////////////////////////////////////////////
# FUNCTIONS


# Global initialisation
func _enter_tree():
	
	#print("ONYXCUBE _enter_tree")
	
		
	# Load and generate geometry
	generate_geometry(true) 
		
	# set gizmo stuff
	#old_handles = face_set.get_all_centre_points()
		
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:
		
		# load gizmos
		plugin = get_node("/root/EditorNode/Onyx")
		
		var new_gizmo = plugin.create_spatial_gizmo(self)
		self.set_gizmo(new_gizmo)
		print(gizmo)
		
		set_notify_local_transform(true)
		set_notify_transform(true)
		set_ignore_transform_notification(false)
		
	
func _ready():
	#print("ONYXCUBE _enter_tree")
	pass

	
func _notification(what):
	
	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
		
		# check that transform changes are local only
		if local_tracked_pos != translation:
			local_tracked_pos = translation
			call_deferred("_editor_transform_changed")
		
func _editor_transform_changed():
	
	# The shape only needs to be re-generated when the origin is moved or when the shape changes.
	#print("ONYXCUBE _editor_transform_changed")
	#generate_geometry(true)
	pass

				
# ////////////////////////////////////////////////////////////
# PROPERTY UPDATERS
	
# Used when a handle variable changes in the properties panel.
func update_x_plus(new_value):
	#print("ONYXCUBE update_x_plus")
	if new_value < 0:
		new_value = 0
		
	x_plus_position = new_value
	generate_geometry(true)
	
	
func update_x_minus(new_value):
	#print("ONYXCUBE update_x_minus")
	if new_value > 0 || origin_setting == OriginPosition.BASE_CORNER:
		new_value = 0
		
	x_minus_position = new_value
	generate_geometry(true)
	
func update_y_plus(new_value):
	#print("ONYXCUBE update_y_plus")
	if new_value < 0:
		new_value = 0
		
	y_plus_position = new_value
	generate_geometry(true)
	
func update_y_minus(new_value):
	#print("ONYXCUBE update_y_minus")
	if new_value > 0 || origin_setting == OriginPosition.BASE_CORNER || origin_setting == OriginPosition.BASE:
		new_value = 0
		
	y_minus_position = new_value
	generate_geometry(true)
	
func update_z_plus(new_value):
	#print("ONYXCUBE update_z_plus")
	if new_value < 0:
		new_value = 0
		
	z_plus_position = new_value
	generate_geometry(true)
	
func update_z_minus(new_value):
	#print("ONYXCUBE update_z_minus")
	if new_value > 0 || origin_setting == OriginPosition.BASE_CORNER:
		new_value = 0
		
	z_minus_position = new_value
	generate_geometry(true)
	
	
func update_bevel_size(new_value):
	if new_value > 0:
		new_value = 0
		
	bevel_size = new_value
	generate_geometry(true)
	
func update_bevel_target(new_value):
	bevel_target = new_value
	generate_geometry(true)
	
	
# Used to recalibrate both the origin point location and the position handles.
func update_positions(new_value):
	#print("ONYXCUBE update_positions")
	update_origin_setting = true
	update_origin()
	balance_handles()
	generate_geometry(true)
	
func update_origin_mode(new_value):
	#print("ONYXCUBE set_origin_mode")
	
	if previous_origin_setting == new_value:
		return
	
	origin_setting = new_value
	update_origin()
	balance_handles()
	generate_geometry(true)
	previous_origin_setting = origin_setting
	

# Updates the origin during generate_geometry() as well as the currently defined handles, 
# to ensure it's anchored where it needs to be.
func update_origin():
	
	# Used to prevent the function from triggering when not inside the tree.
	# This happens during duplication and replication and causes incorrect node placement.
	if self.is_inside_tree() == false:
		return
	
	#print("ONYXCUBE update_origin")
	
	if handles.size() == 0:
		return
	
	# based on the current position and properties, work out how much to move the origin.
	var diff = Vector3(0, 0, 0)
	
	match previous_origin_setting:
		
		OriginPosition.CENTER:
			match origin_setting:
				
				OriginPosition.BASE:
					diff = Vector3(0, y_minus_position, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(x_minus_position, y_minus_position, z_minus_position)
			
		OriginPosition.BASE:
			match origin_setting:
				
				OriginPosition.CENTER:
					diff = Vector3(0, y_plus_position / 2, 0)
				OriginPosition.BASE_CORNER:
					diff = Vector3(x_minus_position, 0, z_minus_position)
					
		OriginPosition.BASE_CORNER:
			match origin_setting:
				
				OriginPosition.BASE:
					diff = Vector3(x_plus_position / 2, 0, z_plus_position / 2)
				OriginPosition.CENTER:
					diff = Vector3(x_plus_position / 2, y_plus_position / 2, z_plus_position / 2)
	
	# Get the difference
	var new_loc = self.translation + diff
	var old_loc = self.translation
	#print("MOVING LOCATION: ", old_loc, " -> ", new_loc)
	
	# set it
	self.global_translate(new_loc - old_loc)

# ////////////////////////////////////////////////////////////
# GEOMETRY GENERATION

# Using the set handle points, geometry is generated and drawn.  The handles owned by the gizmo are also updated.
func generate_geometry(fix_to_origin_setting):
	
	#print("ONYXCUBE generate_geometry")
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
	
	# Generate the geometry
	var mesh_factory = OnyxMeshFactory.new()
	tri_array = mesh_factory.build_cuboid(maxPoint, minPoint)
	
	var array_mesh = tri_array.render_surface_geometry()
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	set_mesh(mesh)
	
	# Re-submit the handle positions based on the built faces, so other handles that aren't the
	# focus of a handle operation are being updated
#	var centre_points = face_set.get_all_centre_points()
#	handles = centre_points
#	#print(handles[0])
#
#	x_plus_position = centre_points[0].x
#	x_minus_position = centre_points[1].x
#	y_plus_position = centre_points[2].y
#	y_minus_position = centre_points[3].y
#	z_plus_position = centre_points[4].z
#	z_minus_position = centre_points[5].z
#
#
#	# Build handle points in the required gizmo format.
#	var face_list = face_set.get_face_vertices()
#
#	gizmo_handles = []
#	for i in handles.size():
#		gizmo_handles.append([handles[i], face_list[i] ])
#
#	# Submit the changes to the gizmo
#	if gizmo:
#		#print("submitting gizmo changes!")
#		#gizmo.add_handles(gizmo_handles, gizmo_mat)
#
#		# disabled during alpha
#		update_gizmo()
		
	
	
	
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
func handle_change(index, coord):
	
	change_handle(index, coord)
	generate_geometry(false)
	

# Called when a handle has stopped being dragged.
func handle_commit(index, coord):
	
	change_handle(index, coord)
	update_origin()
	balance_handles()
	generate_geometry(true)
	
	# store old handle points for later.
#	old_handles = face_set.get_all_centre_points()
	
			
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
	#print("ONYXCUBE balance_handles")
	
	match origin_setting:
		OriginPosition.CENTER:
			var diff = abs(x_plus_position - x_minus_position)
			x_plus_position = diff / 2
			x_minus_position = (diff / 2) * -1
			
			diff = abs(y_plus_position - y_minus_position)
			y_plus_position = diff / 2
			y_minus_position = (diff / 2) * -1
			
			diff = abs(z_plus_position - z_minus_position)
			z_plus_position = diff / 2
			z_minus_position = (diff / 2) * -1
		
		OriginPosition.BASE:
			var diff = abs(x_plus_position - x_minus_position)
			x_plus_position = diff / 2
			x_minus_position = (diff / 2) * -1
			
			diff = abs(y_plus_position - y_minus_position)
			y_plus_position = diff
			y_minus_position = 0
			
			diff = abs(z_plus_position - z_minus_position)
			z_plus_position = diff / 2
			z_minus_position = (diff / 2) * -1
			
		OriginPosition.BASE_CORNER:
			var diff = abs(x_plus_position - x_minus_position)
			x_plus_position = diff
			x_minus_position = 0
			
			diff = abs(y_plus_position - y_minus_position)
			y_plus_position = diff
			y_minus_position = 0
			
			diff = abs(z_plus_position - z_minus_position)
			z_plus_position = diff
			z_minus_position = 0
		
	# Old code just in case the above stuff breaks.
#	var diff = abs(x_plus_position - x_minus_position)
#	x_plus_position = diff / 2
#	x_minus_position = (diff / 2) * -1
#
#	diff = abs(y_plus_position - y_minus_position)
#	y_plus_position = diff / 2
#	y_minus_position = (diff / 2) * -1
#
#	diff = abs(z_plus_position - z_minus_position)
#	z_plus_position = diff / 2
#	z_minus_position = (diff / 2) * -1
	
	
	
# Updates the collision triangles responsible for detecting cursor selection in the editor.
func get_gizmo_collision():
##	var triangles = face_set.get_triangles()
#
#	var return_t = PoolVector3Array()
##	for triangle in triangles:
#		return_t.append(triangle * 10)
#
#	return return_t
	pass
	
# ////////////////////////////////////////////////////////////
# SELECTION

func editor_select():
	pass
	
	
func editor_deselect():
	pass
	
	

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

