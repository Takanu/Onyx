extends EditorSpatialGizmoPlugin

# ////////////////////////////////////////////////////////////
# INFO
# Gizmo plugin that manages and creates gizmos for other Onyx types.

const SnapGizmo = preload("res://addons/onyx/gizmos/snap_gizmo.gd")
var plugin

func _init(plugin):
	self.plugin = plugin
	create_handle_material("handle")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
func get_name():
    return "OnyxGizmoPlugin"
	
# Creates gizmo types!
func create_gizmo(spatial):
	print(spatial)
	
	for handled_object in plugin.NodeHandlerList:
		if spatial is handled_object:
			var new_gizmo = SnapGizmo.new()
			
			print('GizmoPlugin - Gizmo creation successful, returning gizmo: ', new_gizmo, spatial)
			return new_gizmo
		
	print('GizmoPlugin - Gizmo creation UNSUCCESSFUL, returning nothing (:.')
	return null
	
# Required to confirm gizmo-ness if the Plugin is doing the drawing
func has_gizmo(spatial):
	for handled_object in plugin.NodeHandlerList:
		if spatial is handled_object:
			print('GizmoPlugin - Plugin can handle node: ', spatial)
			return true
	
	print('GizmoPlugin - Plugin CANNOT handle node: ', spatial)
	return false

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
