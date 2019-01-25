extends EditorSpatialGizmoPlugin

# ////////////////////////////////////////////////////////////
# INFO
# Gizmo plugin that manages and creates gizmos for other Onyx types.

const SnapGizmo = preload("res://addons/onyx/gizmos/snap_gizmo.gd")

var plugin

func _init(plugin):
	self.plugin = plugin

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
# Creates gizmo types!
func create_gizmo(spatial):
	var gizmo = SnapGizmo.new(plugin, spatial)
	return gizmo

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
