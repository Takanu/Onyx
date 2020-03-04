tool
extends Control

const MENU_GIZMO_SNAP_ENABLE = 0
const MENU_GIZMO_GLOBAL_ORIENTATION = 1
const MENU_GIZMO_SHOW_GRID = 2
const MENU_GIZMO_SHOW_SLICER = 3


# Called when the node enters the scene tree for the first time.
func _ready():
	
	var plugin = get_node("/root/EditorNode/Onyx")
	
	# Populate snap menu
	var snap_menu = get_node("snap_menu")
	snap_menu.get_popup().clear()
	snap_menu.get_popup().add_check_item("Enable Snapping", MENU_GIZMO_SNAP_ENABLE)
	snap_menu.get_popup().add_check_item("Snap on Global Orientation", MENU_GIZMO_GLOBAL_ORIENTATION)
	snap_menu.get_popup().set_item_checked(MENU_GIZMO_GLOBAL_ORIENTATION, true)
#	snap_menu.get_popup().add_check_item("Show Snap Grid", MENU_GIZMO_SHOW_GRID)
#	snap_menu.get_popup().add_check_item("Show Slicer", MENU_GIZMO_SHOW_SLICER)
	snap_menu.get_popup().connect("id_pressed", self, "snap_item_selected")
	
	# connect value box
	var snap_increment = get_node("snap_increment")
	snap_increment.connect("value_changed", self, "snap_increment_update")

# Updates the increment value
func snap_increment_update(value):
	var plugin = get_node("/root/EditorNode/Onyx")
	plugin.snap_gizmo_increment = value

# Used for controlling the behaviour of the Gizmo Snap toolbar popup menu.
func snap_item_selected(id):
	
	var plugin = get_node("/root/EditorNode/Onyx")
	var snap_menu = get_node("snap_menu")
	
	match id:
		
		MENU_GIZMO_SNAP_ENABLE:
			
			if plugin.snap_gizmo_enabled == false:
				plugin.snap_gizmo_enabled = true
				snap_menu.get_popup().set_item_checked(MENU_GIZMO_SNAP_ENABLE, true)
			else:
				plugin.snap_gizmo_enabled = false
				snap_menu.get_popup().set_item_checked(MENU_GIZMO_SNAP_ENABLE, false)
		
		MENU_GIZMO_GLOBAL_ORIENTATION:
			
			if plugin.snap_gizmo_global_orientation == false:
				plugin.snap_gizmo_global_orientation = true
				snap_menu.get_popup().set_item_checked(MENU_GIZMO_GLOBAL_ORIENTATION, true)
			else:
				plugin.snap_gizmo_global_orientation = false
				snap_menu.get_popup().set_item_checked(MENU_GIZMO_GLOBAL_ORIENTATION, false)
				
		MENU_GIZMO_SHOW_GRID:
			
			if plugin.snap_gizmo_grid == false:
				plugin.snap_gizmo_grid = true
				snap_menu.get_popup().set_item_checked(MENU_GIZMO_SHOW_GRID, true)
			else:
				plugin.snap_gizmo_grid = false
				snap_menu.get_popup().set_item_checked(MENU_GIZMO_SHOW_GRID, false)
				
		MENU_GIZMO_SHOW_SLICER:
			
			if plugin.snap_gizmo_slicer == false:
				plugin.snap_gizmo_slicer = true
				snap_menu.get_popup().set_item_checked(MENU_GIZMO_SHOW_SLICER, true)
			else:
				plugin.snap_gizmo_slicer = false
				snap_menu.get_popup().set_item_checked(MENU_GIZMO_SHOW_SLICER, false)
