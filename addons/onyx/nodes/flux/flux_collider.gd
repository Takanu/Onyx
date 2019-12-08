tool
extends StaticBody

# ////////////////////////////////////////////////////////////
# INFO
# Create a static collision fence that lets you fence parts of your environment away from your players.


# ////////////////////////////////////////////////////////////
# SCRIPT EXPORTS

# The base height of the fence.
export(int, 0, 100) var fence_base_height = 0

# The width of the fence.
export(int, 0, 100) var fence_base_width = 0

# Where the fence begins relative to the editor handle's Y position.
export(float, -50, 50) var fence_offset = 0

# All the handles that the fence is using to define itself (including ones not being shown).
export(Dictionary) var fence_xy_points

# The adjusted height of each fence handle point.
export(Dictionary) var fence_z_points

# The width of the fence at each handle point.
export(Dictionary) var fence_width_points


# ////////////////////////////////////////////////////////////
# PROPERTIES

# The plugin this node belongs to.
var plugin

# The toolbar the fence will add to the editor to allow for the creation and deletion of handles.
var control = preload("res://addons/onyx/ui/tools/fence_toolbar.tscn")

# The wireframe visualization of the fence
var fence_geom = ImmediateGeometry.new()

# The faces that will make up the fence using our FaceArray kit.
var fence_faces = preload("res://addons/onyx/utilities/geometry/face_array.gd").new()

# Geometry that will be used exclusively for creating collision points for toolbar operators.
var click_collision = []

# The handles currently being shown to the user and that are editable.
var gizmo_handles

# This enumerator changes depending on the tool selected on the toolbar.
enum FenceEditMode {ADD, DELETE, POSITION, SCALE}
var fence_edit_mode = FenceEditMode.ADD

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
		
		
# If no handles are in the exported property, build some.
func initialise_handles():
	
	
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
	
	control.get_child(3).owner_node = self
	control.get_child(3).function_trigger = "toolbar_move_handles"
	
	control.get_child(4).owner_node = self
	control.get_child(4).function_trigger = "toolbar_scale_handles"
	
	
func editor_deselect():
	fence_geom.material_override = mat_solid_color(plugin.WireframeCollision_Unselected)
	plugin.remove_toolbar(control)
	
	
	
# ////////////////////////////////////////////////////////////
# TOOLBAR

# Clears any GUI-related signals that have been assigned.
func reset_signals():
	plugin.disconnect("onyx_viewport_clicked", self, "receive_viewport_click")
	

# Turns on mouse input and collision code to enable more points to be added to the fence.
func toolbar_add_handles(is_toggled):
	print("ADDDD")
	fence_edit_mode = FenceEditMode.ADD
	
	# generate handles
	gizmo_handles = []
	
	var i = 0
	var vector_xy_pool = fence_xy_points.values()
	var vector_z_pool = fence_z_points.values()
	
	while vector_xy_pool.size() != i:
		var new_vector = Vector3()
		
		new_vector.x = vector_xy_pool[i].x
		new_vector.y = vector_xy_pool[i].y
		new_vector.z = fence_z_points[i]
		
		gizmo_handles.append(new_vector)
		
		i += 1
	
	
	# generate click collision
	
	
	# generate displays
	
	pass
	
	
# Turns on mouse input and collision code to enable points to be removed from the fence.
func toolbar_remove_handles(is_toggled):
	print("REMMMOOOOOVE")
	fence_edit_mode = FenceEditMode.DELETE
	
	# generate handles
	
	# generate click collision
	
	pass

# Turns on mouse input and collision code to enable points to be removed from the fence.
func toolbar_move_handles(is_toggled):
	print("MOOOOOVE")
	fence_edit_mode = FenceEditMode.POSITION
	
	# generate handles
	
	pass

# Turns on mouse input and collision code to enable points to be removed from the fence.
func toolbar_scale_handles(is_toggled):
	print("SCAAAALE")
	fence_edit_mode = FenceEditMode.SCALE
	
	# generate handles
	
	pass


func receive_viewport_click(camera, event):
	pass


# ////////////////////////////////////////////////////////////
# BUILDERS

# Generates geometry that's just used for collision visualisation in the editor.
func generate_geometry():
	pass


# Uses the currently generated geometry to build a valid collision shape.
func generate_shape_collision():
	pass
	
	
# Uses the current points to generate collision cuboids for detecting click editing.
func generate_click_collision():
	
	
	
	
	pass
	
# ////////////////////////////////////////////////////////////
# HELPERS
	
func mat_solid_color(color):
	var mat = SpatialMaterial.new()
	mat.render_priority = mat.RENDER_PRIORITY_MAX
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.flags_no_depth_test = true
	mat.albedo_color = color
	
	return mat