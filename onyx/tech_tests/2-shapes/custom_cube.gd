tool
extends Spatial

var geom = ImmediateGeometry.new()
var color = Vector3(1, 1, 1)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

# Global initialisation
func _enter_tree():
	set_notify_local_transform(true)
	set_notify_transform(true)
	set_ignore_transform_notification(false)
	
	geom.set_name("geom")
	add_child(geom)
	generate_geometry()
	
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
	generate_geometry()

				
				
func generate_geometry():
	
	# ImmediateGeometry
	geom.clear()
	
	var scale = 1
	
	build_square_face(Vector3(1, 0, 0), Vector3(1, 0, 0), scale)
	build_square_face(Vector3(-1, 0, 0), Vector3(-1, 0, 0), scale)

	build_square_face(Vector3(0, 1, 0), Vector3(0, 1, 0), scale)
	build_square_face(Vector3(0, -1, 0), Vector3(0, -1, 0), scale)
	
	build_square_face(Vector3(0, 0, 1), Vector3(0, 0, 1), scale)
	build_square_face(Vector3(0, 0, -1), Vector3(0, 0, -1), scale)
	
	
	
# the vector represents a Vector3 type that includes a single axis that should be locked.
func build_square_face(face_position, normal, scale):
	
	if face_position.x == 0 && face_position.y == 0 && face_position.z == 0:
		return
	
	# build the vertex set we need.
	var val_x = face_position.x
	var val_y = face_position.y
	var val_z = face_position.z
	
	# need to work out a way to identify what order the vertices need to be drawn in.
	var face_bounds = [[scale, scale], [-scale, scale], [scale, -scale], [-scale, -scale]]
		
	var vertices = []
	
	for i in 4:
		var set = face_bounds[i]
		
		if face_position.x == 0:
			var point = set[0]
			set.remove(0)
			val_x = point
			
		if face_position.y == 0:
			var point = set[0]
			set.remove(0)
			val_y = point
			
		if face_position.z == 0:
			var point = set[0]
			set.remove(0)
			val_z = point
			
		vertices.append(Vector3(val_x, val_y, val_z))
		
	# sort the vertices based on 
	var vertex_order = get_vertex_order(vertices, normal)
	
	# build the face into the class
	geom.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, null)
	
	for i in 4:
		# normals affect shading, but not which side is considered solid.
		geom.set_normal(normal)
		geom.set_color(Color(1, 1, 1))
		geom.add_vertex(vertex_order[i])
		
	geom.end()
	
	
func get_vertex_order(vertex_list, intended_face_direction):
	
	# get the winding order 
	var x_vector = vertex_list[1] - vertex_list[0]
	var y_vector = vertex_list[2] - vertex_list[0]
	var z_vector = x_vector.cross(y_vector)
	var transform = Transform(x_vector, y_vector, z_vector, Vector3(0, 0, 0))
	
	var inverse_transform = transform.inverse()
	var result = inverse_transform * intended_face_direction
	var vertex_order = []
	
	# sort the vertices correctly
	if result.z > 0:
		# counter-clockwise
		vertex_order = [vertex_list[0], vertex_list[2], vertex_list[1], vertex_list[3]]
	else:
		# clockwise
		vertex_order = [vertex_list[0], vertex_list[1], vertex_list[2], vertex_list[3]]
	
	return vertex_order
	
	

