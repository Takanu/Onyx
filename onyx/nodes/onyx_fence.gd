tool
extends StaticBody

# ////////////////////////////////////////////////////////////
# INFO
# Create a static collision fence that lets you fence parts of your environment away from your players.


# ////////////////////////////////////////////////////////////
# SCRIPT EXPORTS

# The height of the fence.
export(int, 0, 100) var fence_height = 0

# The width of the fence.
export(int, 0, 100) var fence_width = 0

# Where the fence begins relative to the editor handle's Y position.
export(float, -50, 50) var fence_offset = 0

# The handles that make up the fence.
export(Array) var fence_handles


# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to.
var plugin

# The toolbar the fence will add to the editor to allow for the creation and deletion of handles.
var control = preload("res://addons/onyx/ui/tools/fence_toolbar.tscn")

# The wireframe visualization of the fence
var fence_geom = ImmediateGeometry.new()



# ////////////////////////////////////////////////////////////
# INITIALISATION

func _enter_tree():
	# add transform notifications
	set_notify_local_transform(true)
	set_notify_transform(true)
	set_ignore_transform_notification(false)
	
	
	# If we're in the editor, do all this cool stuff, otherwise don't.
	if Engine.editor_hint == true:
		
		# get the gizmo
		plugin = get_node("/root/EditorNode/Onyx")
		gizmo = plugin.create_spatial_gizmo(self)
	
	
	# ???
	else:
		pass
	
	
# ////////////////////////////////////////////////////////////
# SELECTION

func editor_select():
	fence_geom.material_override = mat_solid_color(plugin.WireframeCollision_Selected)
	control = plugin.add_toolbar("res://addons/onyx/ui/tools/fence_toolbar.tscn")
	
	# Setup the toolbar functions
	control.get_child(1).owner_node = self
	control.get_child(1).function_trigger = "toolbar_add_handles"
	
	control.get_child(2).owner_node = self
	control.get_child(2).function_trigger = "toolbar_remove_handles"
	
	
func editor_deselect():
	fence_geom.material_override = mat_solid_color(plugin.WireframeCollision_Unselected)
	plugin.remove_toolbar(control)
	
	
# ////////////////////////////////////////////////////////////
# TOOLBAR

# Toolbar function for adding more handles to the node.
func toolbar_add_handles(is_toggled):
	pass
	
	
# Toolbar function for removing existing handles to the node.
func toolbar_remove_handles(is_toggled):
	pass


	