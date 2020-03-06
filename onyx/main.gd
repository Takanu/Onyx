tool
extends EditorPlugin

# ////////////////////////////////////////////////////////////
# PROPERTIES

# Core node types
const OnyxCube = preload("./nodes/onyx/onyx_cube.gd")
const OnyxCylinder = preload("./nodes/onyx/onyx_cylinder.gd")
const OnyxSphere = preload("./nodes/onyx/onyx_sphere.gd")
const OnyxWedge = preload("./nodes/onyx/onyx_wedge.gd")
const OnyxRamp = preload("./nodes/onyx/onyx_ramp.gd")
const OnyxRoundedRect = preload("./nodes/onyx/onyx_rounded_cube.gd")
const OnyxStairs = preload("./nodes/onyx/onyx_stairs.gd")
const OnyxPolygon = preload("./nodes/onyx/onyx_polygon.gd")

const FluxArea  = preload("./nodes/flux/flux_area.gd")
const FluxCollider  = preload("./nodes/flux/flux_collider.gd")

const ResTest = preload('./nodes/res_test.gd')

const NodeHandlerList = [OnyxCube, OnyxCylinder, OnyxSphere, OnyxWedge, OnyxRoundedRect, OnyxStairs, OnyxPolygon, OnyxRamp, FluxArea, FluxCollider]
const NodeStrings = ['OnyxCube', 'OnyxCylinder', 'OnyxSphere', 'OnyxWedge', 'OnyxRoundedRect', 'OnyxStairs', "OnyxPolygon", 'FluxArea', 'FluxCollider']

# Gizmo types
const OnyxGizmoPlugin = preload("res://addons/Onyx/gizmos/onyx_gizmo_plugin.gd")
var gizmo_plugin : OnyxGizmoPlugin


# Wireframe material types
const WireframeCollision_Selected = Color(1, 1, 0, 0.8)
const WireframeCollision_Unselected = Color(1, 1, 0, 0.1)

const WireframeUtility_Selected = Color(0, 1, 1, 0.6)
const WireframeUtility_Unselected = Color(0, 1, 1, 0.05)


# Selection management
var currently_selected_node = null

# User Interface Objects
var snap_menu

# User Interface Variables
var snap_gizmo_enabled = false
var snap_gizmo_increment = 1

# If true, the snapping distances will be based on the object's global location, to compensate for automatic origin adjustment.
var snap_gizmo_global_orientation = true

var snap_gizmo_grid = false
var snap_gizmo_slicer = false

# A record of what controls have been added to the enrionment, used as a testing failsafe.
# ...because Godot's script reload system is baaaaaaaaaaaaad.
var backup_control_list = {}



# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	#print("ONYX enter_tree")
	
	# Give this node a name so any other node can access it using "node/EditorNode/Onyx"
	name = "Onyx"
	
	# Initialization of the plugin goes here
	gizmo_plugin = OnyxGizmoPlugin.new(self)
	add_spatial_gizmo_plugin(gizmo_plugin)
	print(gizmo_plugin)
	
	# onyx types
	add_custom_type("OnyxCube", "CSGMesh", preload("./nodes/onyx/onyx_cube.gd"), preload("res://addons/onyx/icons/nodes/onyx_block.png"))
	add_custom_type("OnyxCylinder", "CSGMesh", preload("./nodes/onyx/onyx_cylinder.gd"), preload("res://addons/onyx/icons/nodes/onyx_block.png"))
	add_custom_type("OnyxSphere", "CSGMesh", preload("./nodes/onyx/onyx_sphere.gd"), preload("res://addons/onyx/icons/nodes/onyx_block.png"))
	add_custom_type("OnyxWedge", "CSGMesh", preload("./nodes/onyx/onyx_wedge.gd"), preload("res://addons/onyx/icons/nodes/onyx_block.png"))
	add_custom_type("OnyxRamp", "CSGMesh", preload("./nodes/onyx/onyx_ramp.gd"), preload("res://addons/onyx/icons/nodes/onyx_block.png"))
	add_custom_type("OnyxRoundedCube", "CSGMesh", preload("./nodes/onyx/onyx_rounded_cube.gd"), preload("res://addons/onyx/icons/nodes/onyx_block.png"))
	add_custom_type("OnyxStairs", "CSGMesh", preload("./nodes/onyx/onyx_stairs.gd"), preload("res://addons/onyx/icons/nodes/onyx_block.png"))
	add_custom_type("OnyxPolygon", "CSGMesh", preload("./nodes/onyx/onyx_polygon.gd"), preload("res://addons/onyx/icons/nodes/onyx_block.png"))
	
	# flux types
	#add_custom_type("FluxArea", "CSGCombiner", preload("./nodes/flux/flux_area.gd"), preload("res://addons/onyx/ui/nodes/onyx_sprinkle.png"))
	#add_custom_type("FluxCollider", "StaticBody", preload("./nodes/flux/flux_collider.gd"), preload("res://addons/onyx/ui/nodes/onyx_fence.png"))
	
	# debug types
	#add_custom_type("ResTest", "CSGMesh",preload('./nodes/res_test.gd'), preload("res://addons/onyx/ui/nodes/onyx_fence.png"))
	
	# Add custom signals for providing GUI click input.
	add_user_signal("onyx_viewport_clicked", [{"camera": TYPE_OBJECT} , {"event": TYPE_OBJECT}] )
	
	# Add a custom snap toolbar for gizmos
	snap_menu = load("res://addons/onyx/ui/gizmo_snap_toolbar.tscn").instance()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, snap_menu)


# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

# Used to tell Godot that we want to handle these objects when they're selected.
func handles(incoming_object):
	
	print("ONYX handles")
	
	for handled_object in NodeHandlerList:
		if incoming_object is handled_object:
			
			# Handle editor selections and deselections here
			if currently_selected_node != incoming_object:
				
				if currently_selected_node != null:
					currently_selected_node.editor_deselect()
					
				currently_selected_node = incoming_object
				currently_selected_node.editor_select()
			
			elif currently_selected_node == null:
				currently_selected_node.editor_select()
			
			return true
	
	if currently_selected_node != null:
		currently_selected_node.editor_deselect()
		currently_selected_node = null
	
	return false
	
# The functionality of this isn't actually clea, gets called multiple times during a new selection o - o
func make_visible(is_visible):
	
#	print("ONYX make_visible - ", is_visible)
	
	# If the node we had is no longer visible and we were given no other nodes,
	# we have to deselect it just to be careful.
#	if currently_selected_node != null && is_visible == false:
#		currently_selected_node.editor_deselect()
#		currently_selected_node = null
	
	pass
	

# The functionality of this is also no longer clear, gets called multiple times for no obvious reason
func edit(object):
	
#	print("ONYX edit - ", object)
	
#	currently_selected_node = object
#	currently_selected_node.editor_select()
	pass
	
	
# ////////////////////////////////////////////////////////////
# CUSTOM UI

# Adds a toolbar to the spatial toolbar area.
func add_toolbar(container, control_target):
	add_control_to_container(container, control_target)
	return control_target
	
	
# Removes a toolbar to the spatial toolbar area.
func remove_toolbar(container, control_target):
	remove_control_from_container(container, control_target)

# Adds a control to the backup list for deletion, with a key.
func add_control_to_backup(container, control_target, control_key):
	backup_control_list[control_key] = [control_target, container]

# Removes a control from the backup list, with the right key.
func remove_control_in_backup(control_key):
	
	if backup_control_list.has(control_key):
		var control_backup = backup_control_list[control_key]
		remove_toolbar(control_backup[1], control_backup[0])


# Removes all currently held custom controls in ta


# Forwards 3D View screen inputs to you whenever you use the handles(object) function
# to tell Godot that you're handling a selected node.
#
# Return True to consume the event and False to pass it onto other editorss.
func forward_spatial_gui_input(camera, ev):
	
	if currently_selected_node != null:
		if currently_selected_node.has_method("receive_gui_input") == true:
			var result =  currently_selected_node.call("receive_gui_input", camera, ev)
			return result

	return false
	
	

# No idea what this did, not part of the EditorPlugin API atm
#func bind_event(ev):
#	print(ev)


func _exit_tree():
	#  Clean-up of the plugin goes here
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, snap_menu)
	snap_menu.queue_free()
	
	for string in NodeStrings:
		remove_custom_type(string)
	remove_spatial_gizmo_plugin(gizmo_plugin)
	pass
	
	
