
tool
extends "res://addons/onyx/nodes/onyx_node.gd"

# ////////////////////////////////////////////////////////////
# TOOL ENUMS

enum VolumeShape {BOX}
export(VolumeShape) var volume_type = BOX setget set_volume_type

# ////////////////////////////////////////////////////////////
# PROPERTIES

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

# Just an array of handle positions, used to track position changes and apply it to the node.
export(Array) var volume_handles = []

# The handle points designed to provide the gizmo with information on how it should operate.
var gizmo_handles = []

# The faces used to generate the shape.
var face_set = load("res://addons/onyx/utilities/face_dictionary.gd").new()
var test = load("res://addons/onyx/utilities/face_utilities.gd").new()

# The debug shape, used to represent the volume in the editor.
var volume_geom = ImmediateGeometry.new()
var volume_active_color = Color(1, 1, 0, 1)
var volume_inactive_color = Color(1, 1, 0, 0.4)

# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	# add transform notifications
	set_notify_local_transform(true)
	set_notify_transform(true)
	set_ignore_transform_notification(false)
	
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
	
	# Generate the volume
	update_sprinkler()
	
	
	# TEST SOME GEOMETRY
	test.build_cylinder(1, 5, 20)
	
	


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
	update_sprinkler()
	

# Checks the children it has and the sprinkle settings, and starts sprinklin'
func update_sprinkler():
	
	if Engine.editor_hint == false:
		return
	
	#print("*******************")
	#print("updating sprinkler!")
	
	# update the volume based on the current volume_handles
	update_volume()
	build_volume()
	
	# get the child nodes it currently has
	
	
	
	
# Updates the geometry of the volume and the volume_handles responsible.
func update_volume():
	
	if Engine.editor_hint == false:
		return
	
	#print("updating volume...")
	
	match volume_type:
		
		VolumeShape.BOX:
			
			# fetch the current handle points
			var maxPoint = Vector3(volume_handles[0].x, volume_handles[1].y, volume_handles[2].z)
			var minPoint = maxPoint * -1
			
			# Build 8 vertex points
			var top_x = Vector3(maxPoint.x, minPoint.y, maxPoint.z)
			var top_xy = Vector3(maxPoint.x, maxPoint.y, maxPoint.z)
			var top_minus_x = Vector3(minPoint.x, maxPoint.y, maxPoint.z)
			var top_minus_xy = Vector3(minPoint.x, minPoint.y, maxPoint.z)
			
			var bottom_x = Vector3(maxPoint.x, minPoint.y, minPoint.z)
			var bottom_xy = Vector3(maxPoint.x, maxPoint.y, minPoint.z)
			var bottom_minus_x = Vector3(minPoint.x, maxPoint.y, minPoint.z)
			var bottom_minus_xy = Vector3(minPoint.x, minPoint.y, minPoint.z)
			
			
			# Build and draw new faces
			face_set.clear()
			
			# X
			face_set.add_face("x_plus", [top_x, top_xy, bottom_x, bottom_xy], Vector3(1, 0, 0))
			face_set.add_face("x_minus", [top_minus_x, top_minus_xy, bottom_minus_x, bottom_minus_xy], Vector3(-1, 0, 0))
			
			# Y
			face_set.add_face("y_plus", [top_xy, top_minus_x, bottom_xy, bottom_minus_x], Vector3(0, 1, 0))
			face_set.add_face("y_minus", [top_x, top_minus_xy, bottom_x, bottom_minus_xy], Vector3(0, -1, 0))
			
			# Z
			face_set.add_face("z_plus", [top_x, top_xy, top_minus_xy, top_minus_x], Vector3(0, 0, 1))
			face_set.add_face("z_minus", [bottom_x, bottom_xy, bottom_minus_xy, bottom_minus_x], Vector3(0, 0, -1))
			
			# Re-submit the handle positions based on the built faces, so other volume_handles that aren't the
			# focus of a handle operation are being updated
			var centre_points = face_set.get_all_centre_points()
			volume_handles = [centre_points[0], centre_points[2], centre_points[4]]
			
			#print("HANDLES: ", volume_handles)
			#print("CENTRE POINTS: ", centre_points)
			
			# Build handle points in the required gizmo format.
			var face_list = face_set.get_face_vertices()
			
			gizmo_handles = []
			gizmo_handles.append([volume_handles[0], face_list[0] ])
			gizmo_handles.append([volume_handles[1], face_list[2] ])
			gizmo_handles.append([volume_handles[2], face_list[4] ])
			
				
			# Build lines to draw the volume shape.
			#var gizmo_lines = []
			#gizmo_lines.append( [face_set.get_face_edges(), Color(1, 1, 0)] ) 
			
			
			# Submit the changes to the gizmo
			if gizmo:
				gizmo.handle_points = gizmo_handles
				#gizmo.lines = gizmo_lines
				

# Builds the volume shape for use in the editor.
func build_volume():
	
	if Engine.editor_hint == false:
		return
		
	var edges = face_set.get_face_edges()
	var count = edges.size() / 2
	volume_geom.clear()
	
	for i in count:
		var pos = ((i + 1) * 2) - 2
		var point1 = edges[pos]
		var point2 = edges[pos + 1]
		
		volume_geom.begin(Mesh.PRIMITIVE_LINES, null)
		
		volume_geom.set_color(volume_active_color)
		volume_geom.add_vertex(point1)
			
		volume_geom.set_color(volume_active_color)
		volume_geom.add_vertex(point2)
		
		volume_geom.end()
	
		
	
	

# ////////////////////////////////////////////////////////////
# HANDLES

# Receives an update from the gizmo when a handle is currently being dragged.
func handle_update(index, coord):
	
	#print("HANDLE UPDATE")
	volume_handles[index] = coord
	update_sprinkler()
	
# Receives an update from the gizmo when a handle has finished being dragged.
func handle_commit(index, coord):
	
	#print("HANDLE COMMIT")
	volume_handles[index] = coord
	update_sprinkler()
	
	
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
	volume_type = new_value
	
	
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
