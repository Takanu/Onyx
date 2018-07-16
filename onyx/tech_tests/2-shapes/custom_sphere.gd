tool
extends Spatial

var geom = ImmediateGeometry.new()
var color = Vector3(1, 1, 1)

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
		call_deferred("_editor_transform_changed")
		
		
func _editor_transform_changed():
	generate_geometry()
			
			
func generate_geometry():
	
	# ImmediateGeometry
	geom.end()
	geom.clear()
	geom.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, null)
	geom.add_sphere(8, 16, 3.0, true)
	geom.end()
	
	pass