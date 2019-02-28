tool
extends CSGMesh

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var finished_scene_load = false setget update_finished_scene_load
export(bool) var create_mesh = true setget update_create_mesh

func update_finished_scene_load(new_value):
	finished_scene_load = new_value
	print(self, " - [[finished_scene_load]]")
	
func update_create_mesh(new_value):
	create_mesh = true
	print(self, " - [[create_mesh]]")
	generate_geometry()

# Global initialisation
func _enter_tree():
		
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:

		set_notify_local_transform(true)
		set_notify_transform(true)
		set_ignore_transform_notification(false)
		finished_scene_load = true
	
	print(self, " - Entered Tree")

# Called when the node enters the scene tree for the first time.
func _ready():
	print(self, " - Ready")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
func generate_geometry():
	
	if is_inside_tree() == false:
		print("Isn't inside the tree yet, returning...")
		return
		
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 2
	cylinder.bottom_radius = 2
	cylinder.height = 4
	
	set_mesh(cylinder)
	
	print(self, " - Generated Geometry")