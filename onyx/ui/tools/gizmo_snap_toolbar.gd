tool
extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	get_node("snap").owner_node = self
	get_node("snap").function_trigger = "toggle_snap"

func toggle_snap():
	var plugin = get_node("/root/EditorNode/Onyx")
	if plugin.snap_gizmo_enabled == true:
		plugin.snap_gizmo_enabled = false
	else:
		plugin.snap_gizmo_enabled = true
