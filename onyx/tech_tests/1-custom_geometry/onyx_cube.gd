tool
extends Spatial

var geom
var color = Vector3(1, 1, 1)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

func _enter_tree():
	set_notify_local_transform(true)
	set_notify_transform(true)
	set_ignore_transform_notification(false)
	local_tracked_pos = translation
	
func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	
	pass
	
func _notification(what):
	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
		if local_tracked_pos != translation:
			local_tracked_pos = translation
			call_deferred("_editor_transform_changed")
		
func _editor_transform_changed():
	instantiate_geometry()
	generate_geometry()

func instantiate_geometry():
	if geom == null :
		geom = $geom
		if geom == null :
			#print("new geom")
			geom = ImmediateGeometry.new()
			geom.set_name("geom")
			add_child(geom)
		else :
			pass
			#print("found geom : " + geom)
				
				
func generate_geometry():
	
	# ImmediateGeometry
	geom.clear()
	geom.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	
	for x_num in 10:
		var x_val = x_num*2
		var v1 = Vector3(0+x_val, 0, rand_range(-0.5, 0.5))
		var v3 = Vector3(0+x_val, 2, rand_range(-0.5, 0.5))
		
		geom.set_normal(Vector3(0, 0, 1))
		geom.set_color(Color(1, 1, 1))
		geom.add_vertex(v1)
		
		geom.set_normal(Vector3(0, 0, 1))
		geom.set_color(Color(1, 1, 1))
		geom.add_vertex(v3)
	
	geom.end()
	
	pass
	


#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
