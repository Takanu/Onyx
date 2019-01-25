tool
extends EditorPlugin

# ////////////////////////////////////////////////////////////
# PROPERTIES

# Core node types
const OnyxCube = preload("./nodes/block/onyx_cube.gd")
const OnyxCylinder = preload("./nodes/block/onyx_cylinder.gd")
const OnyxSphere = preload("./nodes/block/onyx_sphere.gd")
const OnyxWedge = preload("./nodes/block/onyx_wedge.gd")

const OnyxSprinkle  = preload("./nodes/onyx_sprinkle.gd")
const OnyxFence  = preload("./nodes/onyx_fence.gd")

const NodeHandlerList = [OnyxCube, OnyxCylinder, OnyxSphere, OnyxWedge, OnyxSprinkle, OnyxFence]


# Gizmo types
var gizmo_plugin = null


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
	
	#print("ONYX enter_tree")
	
	# Give this node a name so any other node can access it using "node/EditorNode/Onyx"
	name = "Onyx"
	
    # Initialization of the plugin goes here
	gizmo_plugin = load("res://addons/onyx/gizmos/onyx_gizmo_plugin.gd").new(self)
	add_spatial_gizmo_plugin(gizmo_plugin)
	print(gizmo_plugin)
	
	# blocks
	add_custom_type("OnyxCube", "CSGMesh", preload("./nodes/block/onyx_cube.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxCylinder", "CSGMesh", preload("./nodes/block/onyx_cylinder.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxSphere", "CSGMesh", preload("./nodes/block/onyx_sphere.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxWedge", "CSGMesh", preload("./nodes/block/onyx_wedge.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	
	# other core types
	add_custom_type("OnyxSprinkle", "Spatial", preload("./nodes/onyx_sprinkle.gd"), preload("res://addons/onyx/ui/nodes/onyx_sprinkle.png"))
	add_custom_type("OnyxFence", "StaticBody", preload("./nodes/onyx_fence.gd"), preload("res://addons/onyx/ui/nodes/onyx_fence.png"))
	
	# Add custom signals for providing GUI click input.
	add_user_signal("onyx_viewport_clicked", [{"camera": TYPE_OBJECT} , {"event": TYPE_OBJECT}] )
	
	pass
	
	
func create_spatial_gizmo(for_spatial):
	
	#print("ONYX create_spatial_gizmo")
	
	if for_spatial is OnyxCube:
		var gizmo = gizmo_plugin.create_gizmo(for_spatial)
		print("The cube now has a gizmo.")
		
		print("Gizmo: ", gizmo)
		return gizmo
	
	if for_spatial is OnyxSprinkle:
		var gizmo = gizmo_plugin.create_gizmo(for_spatial)
		return gizmo
		
		
# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

# Used to tell Godot that we want to handle these objects when they're selected.
func handles(object):
	
	#print("ONYX handles")
	
	for handled_object in NodeHandlerList:
		if object is handled_object:
			return true
	
#	if object is OnyxCube:
#		return true
#
#	if object is OnyxSprinkle:
#		return true
#
	return false
	
	
# Returns a boolean when one of your handled object types is either selected or deselected.
func make_visible(is_visible):
	
	#print("ONYX make_visible")
	
	# If the node we had is no longer visible and we were given no other nodes,
	# we have to deselect it just to be careful.
	if currently_selected_node != null && is_visible == false:
		currently_selected_node.editor_deselect()
		currently_selected_node = null
	

# Receives the objects we have allowed to handle under the handles(object) function.
func edit(object):
	
	#print("ONYX edit")
	
	currently_selected_node = object
	currently_selected_node.editor_select()
	
	
# ////////////////////////////////////////////////////////////
# CUSTOM UI

# Adds a toolbar to the spatial toolbar area.
func add_toolbar(control_path):
	var new_control = load(control_path).instance()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, new_control)
	return new_control
	
	
# Removes a toolbar to the spatial toolbar area.
func remove_toolbar(control):
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, control)


# Forwards 3D View screen inputs to you whenever you use the handles(object) function
# to tell Godot that you're handling a selected node.
func forward_spatial_gui_input(camera, ev):
	emit_signal("onyx_viewport_clicked", camera, ev)
	
	
func bind_event(ev):
	print(ev)


func _exit_tree():
    # Clean-up of the plugin goes here
	remove_custom_type("OnyxCube")
	remove_custom_type("OnyxSprinkle")
	pass
	
	