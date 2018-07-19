tool
extends EditorPlugin

# ////////////////////////////////////////////////////////////
# PROPERTIES

# Core node types
const OnyxCube = preload("./nodes/onyx_cube.gd")
const OnyxSprinkle  = preload("./nodes/onyx_sprinkle.gd")


# Gizmo types
const SnapGizmo = preload("./gizmos/snap_gizmo.gd")


# Wireframe material types
const WireframeCollision_Selected = Color(1, 1, 0, 0.8)
const WireframeCollision_Unselected = Color(1, 1, 0, 0.1)

const WireframeUtility_Selected = Color(0, 0, 1, 0.8)
const WireframeUtility_Unselected = Color(0, 0, 1, 0.1)


# Selection management
var currently_selected_node = null

# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	# Give this node a name so any other node can access it using "node/EditorNode/Onyx"
	name = "Onyx"
	
    # Initialization of the plugin goes here
	add_custom_type("OnyxCube", "CSGMesh", preload("./nodes/onyx_cube.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxSprinkle", "Spatial", preload("./nodes/onyx_sprinkle.gd"), preload("res://addons/onyx/ui/nodes/onyx_sprinkle.png"))
	
	pass
	
	
func create_spatial_gizmo(for_spatial):
	
	if for_spatial is OnyxCube:
		var gizmo = SnapGizmo.new(self, for_spatial)
		return gizmo
	
	if for_spatial is OnyxSprinkle:
		var gizmo = SnapGizmo.new(self, for_spatial)
		return gizmo
		
		
# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

# Used to tell Godot that we want to handle these objects when they're selected.
func handles(object):
	
	if object is OnyxCube:
		return true
		
	if object is OnyxSprinkle:
		return true
		
	return false
	
	
# Returns a boolean when one of your handled object types is either selected or deselected.
func make_visible(is_visible):
	
	# If the node we had is no longer visible and we were given no other nodes,
	# we have to deselect it just to be careful.
	if currently_selected_node != null && is_visible == false:
		currently_selected_node.editor_deselect()
		currently_selected_node = null
	

# Receives the objects we have allowed to handle under the handles(object) function.
func edit(object):
	
	currently_selected_node = object
	currently_selected_node.editor_select()
	
	
# ////////////////////////////////////////////////////////////
# CUSTOM UI

# Adds a toolbar to the spatial toolbar area.
func add_toolbar(control_path, node):
	var new_control = load(control_path).instance()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, new_control)
	return new_control
	
	
# Removes a toolbar to the spatial toolbar area.
func remove_toolbar(control):
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, control)



func _exit_tree():
    # Clean-up of the plugin goes here
	remove_custom_type("OnyxCube")
	remove_custom_type("OnyxSprinkle")
	pass
	
	