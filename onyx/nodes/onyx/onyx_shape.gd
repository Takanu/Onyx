tool
extends CSGMesh

# /////////////////////////////////////////////////////////////////////////////
# INFO
# A container-type that allows for the generation of many different kinds of CSG shapes
# with customizable UVs, interactive handles, auto-updating origin points and other
# handy features.
#
# Add new generators by subclassing OnyxGenerator.

# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# INTERFACE (the important bits)

# - - func activate_node() - - 
# To save on load times when loading scenes, not all of the components
# required to modify the shape will be immediately loaded.  Use this function when performing
# cross-node interactions to ensure that it is fully ready to handle them.


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# STATICS

# The name given to the generator child.
const GENERATOR_NODE_NAME = "**GENERATOR NODE**"

# The name given to hollow objects
const HOLLOW_OBJECT_NAME = "**HOLLOW ONYX OBJECT**"

# The name for the node used to preview non-union boolean modes as a solid.
const BOOLEAN_PREVIEW_SOLID_NAME = "**BOOLEAN SOLID PREVIEW**"

# The name for the node used to preview non-union boolean modes as a wire.
const BOOLEAN_PREVIEW_WIRE_NAME = "**BOOLEAN WIRE PREVIEW**"

# The generator types.
enum ShapeType {
	BOX, 
	ROUNDED_BOX,
	CYLINDER,
	SPHERE,
	WEDGE,
	STAIRS,
	RAMP,
#
#	# Placeholders for future releases
#	CAPSULE,
# 	DONUT,
# 	TUBE_BOX,
}

# The dictionary used to find the script for each ShapeType.
const GENERATOR_SCRIPTS = {
	ShapeType.BOX : "res://addons/onyx/nodes/onyx/onyx_gen_box.gd",
	ShapeType.ROUNDED_BOX : "res://addons/onyx/nodes/onyx/onyx_gen_roundedbox.gd",
	ShapeType.CYLINDER : "res://addons/onyx/nodes/onyx/onyx_gen_cylinder.gd",
	ShapeType.SPHERE : "res://addons/onyx/nodes/onyx/onyx_gen_sphere.gd",
	ShapeType.WEDGE : "res://addons/onyx/nodes/onyx/onyx_gen_wedge.gd",
	ShapeType.STAIRS : "res://addons/onyx/nodes/onyx/onyx_gen_stairs.gd",
	ShapeType.RAMP : "res://addons/onyx/nodes/onyx/onyx_gen_ramp.gd",
}

# ////////////////////////////////////
# PUBLIC
# Made public through property lists 

# Used to select different shapes.
export(ShapeType) var shape_type = ShapeType.BOX  setget switch_generator

var uv_scale = Vector2(1.0, 1.0)
var flip_uvs_horizontally = false
var flip_uvs_vertically = false


# ////////////////////////////////////
# PRIVATE

# Used for managing geometric data in a more convenient way than in-built Godot types.
var _onyx_mesh = OnyxMesh.new()

# The currently selected shape generator, delegates all shape properties, control
# points and mesh building.
var _generator : Spatial

# Used to display the properties that the active shape generator makes available.
#
# NOTE - An array is used to ensure that when nodes are loaded from a scene the
# order of properties displayed remains the same.
#
var _gen_property_list : Array = []

# Used to store the properties of the active shape generator for future scene loads.
#
# NOTE - Stores the private property names, not the public-facing ones.
#
var _gen_property_values : Dictionary = {}

# If true, this node is currently selected in the editor
var is_selected : bool = false


# //////////////////
# HOLLOW MODE

# Enables and disables hollow mode
var hollow_enable : bool = false

# The object that if set, will be used to hollow out the main shape.
var hollow_object : CSGMesh = null

# Storage object for the hollow mesh, used during runtime.
var hollow_mesh : Mesh

# Hollow object material storage.
var hollow_material : Material

# The last-found position for the hollow object.  Used in save loads to 
# re-position the hollow when no generator exists.
var hollow_last_position : Vector3 = Vector3()


# //////////////////
# BOOLEAN PREVIEW

# A node created in edit-mode to visualize shapes involved in boolean operations.
# TODO - Do i need this?
#
var boolean_preview_node = null

# Using these for live material tests, not for user releases.
# export(Material) var boolean_wire_material : Material = null 
# export(Material) var boolean_solid_material : Material = null


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# INITIALIZATION

# Called right at the objects creation, the earliest """init""" call
#func _init():
#	print("[OnyxShape] ", self.get_name() , " - _init()")


# Called when the node enters the scene tree (either from code, editor reparenting or 
# other stuff.
func _enter_tree():
	
#	print("[OnyxShape] ", self.get_name() , " - _enter_tree()")

	# Use this to recover the preview node from duplications.
	if Engine.editor_hint == true:
		
		# We can assume that if we have a mesh, it's already been initialized.
		# Need to update boolean mode when reparenting occurs.
		if _onyx_mesh != null:
			_update_boolean_mode()


# Called when the node is "ready", i.e. when both the node and its children have 
# entered the scene tree. If the node has children, their _ready() callbacks get triggered 
# first, and the parent node will receive the ready notification afterwards.
func _ready():
	
#	print("[OnyxShape] ", self.get_name() , " - _ready()")
	
	if Engine.editor_hint == true:
		
		# If this is null, we can assume this node was just created and need
		# to setup the generator and mesh anew.
		if mesh == null:
			create_generator_data()
		
		# If not, we just need to recover the properties.
		else:
			load_generator_data()
		
		# Called to ask the boolean preview code if we need a new boolean shape or not.
		_update_boolean_mode()
		
		# If hollow mode is on, initialize the data for it.
		if hollow_enable == true:
			_create_hollow_object()
	
	# Required to build hollow data before the scene loads
	if Engine.editor_hint == false:
		_build_runtime_hollow_object()


# Called when the node is removed from the scene tree for any reason.
# (really m8, don't use this for deallocation, it will not end well)
func _exit_tree():
	
#	print("[OnyxShape] ", self.get_name() , " - _exit_tree()")
	pass


# This was used, maybe itll be used later
#func _notification(what):
#
#	if Engine.editor_hint == true:
#		if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
#			if _generator != null:
#				_generator.owner_global_transform = self.global_transform

#func _editor_transform_changed():
#	pass


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# SET/GETTERS
# If you're watching this Godot developers.... this is nice and all for 
# advanced usage but... why.

func _get_property_list():
	# print("[OnyxShape] ", self.get_name() , " - _get_property_list()")
	var props = [
		
		{
			"name" : "uv_options/uv_scale",
			"type" : TYPE_VECTOR2,
		},
		
		{
			"name" : "uv_options/flip_uvs_horizontally",
			"type" : TYPE_BOOL,
		},
		
		{
			"name" : "uv_options/flip_uvs_vertically",
			"type" : TYPE_BOOL,
		},
		
		{
			"name" : "hollow_mode/enable_hollow_mode",
			"type" : TYPE_BOOL,
		},
		
		# HOLLOW PRIVATE STORAGE /////
		
		{
			"name" : "hollow_mode/hollow_material",
			"type" : TYPE_OBJECT,
			"hint": PROPERTY_USAGE_STORAGE | PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Material"
		},
		
		{
			"name" : "hollow_mode/hollow_mesh",
			"type" : TYPE_OBJECT,
			"usage" : PROPERTY_USAGE_STORAGE,
		},

		{
			"name" : "hollow_last_position",
			"type" : TYPE_OBJECT,
			"usage" : PROPERTY_USAGE_STORAGE,
		},
		
		# GEN PRIVATE STORAGE /////
		
		{
			"name" : "_gen_property_list",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE,
		},
	]
	
	# Load properties from the current generator
	for property in _gen_property_list:
		props.append(property)
	
	
	
	return props

func _set(property, value):
	# print("[OnyxShape] ", self.get_name() , " - _set() : ", property, " ", value)
	
	# Same-value catcher.
	var old_value = self.get(property)
	if old_value != null:
		if old_value == value:
#			print("Same value assignment, BAIIIII")
			return true
	
	match property:
		
		# Super-class properties /////
		"material":
			material = value
#			_update_geometry()
			return true
		
		"operation":
			operation = value
			_update_boolean_mode()
			return true
		
		# Saved internal properties /////
		
#		"shape":
#			shape = value
#			return true
		
		# UVs /////
		
		"uv_options/uv_scale":
			uv_scale = value
			_update_geometry()
			_update_hollow_geometry()
			return true
			
		"uv_options/flip_uvs_horizontally":
			flip_uvs_horizontally = value
			_update_geometry()
			_update_hollow_geometry()
			return true
			
		"uv_options/flip_uvs_vertically":
			flip_uvs_vertically = value
			_update_geometry()
			_update_hollow_geometry()
			return true
		
		# Hollow Mode /////
		
		"hollow_mode/enable_hollow_mode":
			_update_hollow_enable(value)
			return true
			
		"hollow_mode/hollow_material":
			_update_hollow_material(value)
			return true
			
		"hollow_mode/hollow_mesh":
			hollow_mesh = value
			return true
		
		"hollow_last_position":
			hollow_last_position = value
			return true
		
		# Generator /////
		
		"_gen_property_list":
			_gen_property_list = value
			return true
	
	
	# Match with a generator property and save internally
	var i = 0
	for gen_property in _gen_property_list:
		
		# match it with the property name we wanted to publish.
		if property == gen_property["name"]:
			var private_name = gen_property["private_name"]
			
			if _generator != null:
				_generator._set(private_name, value)
				_gen_property_values[private_name] = value

			else:
				_gen_property_values[private_name] = value
			
			return true
			
		i += 1
	



func _get(property):
	# print("[OnyxShape] ", self.get_name() , " - _get() : ", property)
	match property:
		
		# Saved internal properties
		
#		"shape":
#			return shape
		
		# UVs /////
		
		"uv_options/uv_scale":
			return uv_scale
		"uv_options/flip_uvs_horizontally":
			return flip_uvs_horizontally
		"uv_options/flip_uvs_vertically":
			return flip_uvs_vertically
		
		# Hollow Mode /////
		
		"hollow_mode/enable_hollow_mode":
			return hollow_enable
		"hollow_mode/hollow_material":
			return hollow_material
		"hollow_mode/hollow_mesh":
			return hollow_mesh
		"hollow_last_position":
			return hollow_last_position
		
		# Generator /////
		
		"_gen_property_list":
			return _gen_property_list
	
	
	# Match with a generator property 
	var i = 0
	for gen_property in _gen_property_list:
		
		# match it with the property name we wanted to publish.
		if property == gen_property["name"]:
			var private_name = gen_property["private_name"]
			
			if _generator != null:
				return _generator.get(private_name)
				
		i += 1
	


# Used to prevent weird "disappearances" of the plugin.  smh...
func get_plugin():
	if Engine.editor_hint == true:
		return get_node("/root/EditorNode/Onyx")
	else:
		return null


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# PRIVATE FUNCTIONS

# /////////////////////////////////////////////////////////////////////////////
# NODE ACTIVATION

# To save on load times when loading scenes, not all of the components
# required to modify the shape will be immediately loaded.  Use this function when the node
# is selected or when performing cross-node interactions to ensure that it is fully ready 
# to handle them.
#
func activate_node():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	if _generator != null:
		return
	
#	print("[OnyxShape] ", self.get_name() , " - activate_node() : ")
	
	# Make a new generator
	var script = load(GENERATOR_SCRIPTS[shape_type])
	_generator = script.new()
	_generator.name = GENERATOR_NODE_NAME
	self.add_child(_generator)
	
	# Send property list data
	_load_genenerator_properties()
	_rebuild_genenerator_property_values()
	
	# Connect signals
	_generator.connect("shape_properties_updated", self, "update_all_geometry")
	_generator.connect("hollow_properties_updated", self, "_update_hollow_geometry")
	_generator.connect("property_list_changed", self, "update_gen_property_lists")
	_generator.connect("request_origin_move", self, "_move_origin")
	_generator.connect("request_origin_change", self, "_replace_origin")
	
	# !! No need to generate mesh data, will already be present from a scene load
	
	# Update gizmo and editor property menu
	update_gizmo()
	property_list_changed_notify()

# /////////////////////////////////////////////////////////////////////////////
# GENERATOR LIFETIME FUNCTIONS

# Creates new generator data when the node is first created.
# This function should only be triggered when the node is first created.
func create_generator_data():

	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
#	print("[OnyxShape] ", self.get_name() , " - create_generator_data() : ")
	
	# Make a new generator
	var script = load(GENERATOR_SCRIPTS[shape_type])
	_generator = script.new()
	_generator.name = GENERATOR_NODE_NAME
	self.add_child(_generator)

	# Get property lists
	_gen_property_list = _generator.get_shape_properties()
	_rebuild_genenerator_property_values()
#
#	# Connect signals
	_generator.connect("shape_properties_updated", self, "update_all_geometry")
	_generator.connect("hollow_properties_updated", self, "_update_hollow_geometry")
	_generator.connect("property_list_changed", self, "update_gen_property_lists")
	_generator.connect("request_origin_move", self, "_move_origin")
	_generator.connect("request_origin_change", self, "_replace_origin")

	# Create mesh data
	_update_geometry()
	_update_hollow_geometry()

	# Update Gizmo and Editor Property List
	update_gizmo()
	property_list_changed_notify()

	use_collision = true
	


# Populates the generator with the currently saved property data.  
# Used on scene loads.
#
# TODO - Decide if this needs to still exist.
#
func load_generator_data():

	if Engine.editor_hint == false || is_inside_tree() == false:
			return
	
#	print("[OnyxShape] ", self.get_name() , " - load_generator_data() : ")
	
	
	

# Called as a SET/GETTER by generator_type to change the generator being used
func switch_generator(new_value):
	
	# print("received value for switching generator - ", new_value)

	if shape_type == new_value:
		return
	
#	print("[OnyxShape] ", self.get_name() , " - switch_generator() : ")
	
	# This has to be here for duplication and saving, when the object might no longer be in the tree.
	shape_type = new_value
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	# TODO - Work out how to handle undo/redo states here
	
	
	# Drop current property backups
	_gen_property_list.clear()
	var old_shape_aspects = null
	
	# Ask the generator what aspects of itself we should preserve for the next one
	if _generator != null:
		old_shape_aspects = _generator.get_shape_aspects()
		
		# Free the generator and associated properties
		_generator.disconnect("shape_properties_updated", self, "update_all_geometry")
		_generator.disconnect("hollow_properties_updated", self, "_update_hollow_geometry")
		_generator.disconnect("property_list_changed", self, "update_gen_property_lists")
		_generator.disconnect("request_origin_move", self, "_move_origin")
		_generator.disconnect("request_origin_change", self, "_replace_origin")
		remove_child(_generator)
	
	# Make a new generator
	var script = load(GENERATOR_SCRIPTS[new_value])
	_generator = script.new()
	_generator.name = GENERATOR_NODE_NAME
	self.add_child(_generator)
	
	# Modify property lists based on previously saved aspects
	if old_shape_aspects != null:
		_generator.load_shape_aspects(old_shape_aspects)
	
	# Get property lists
	_gen_property_list = _generator.get_shape_properties()
	_rebuild_genenerator_property_values()
	
	# Connect signals
	_generator.connect("shape_properties_updated", self, "update_all_geometry")
	_generator.connect("hollow_properties_updated", self, "_update_hollow_geometry")
	_generator.connect("property_list_changed", self, "update_gen_property_lists")
	_generator.connect("request_origin_move", self, "_move_origin")
	_generator.connect("request_origin_change", self, "_replace_origin")
	
	# Create mesh data
	_update_geometry()
	_update_hollow_geometry()
	
	# Update gizmo and editor property menu
	update_gizmo()
	property_list_changed_notify()


# /////////////////////////////////////////////////////////////////////////////
# GENERATOR PROPERTIES


# Builds a list of saved generator values.
# Should only be used when a generator is created for the first time.
func _rebuild_genenerator_property_values():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	# print("[OnyxShape] ", self.get_name() , 
	# 		" - _rebuild_genenerator_property_values()")

	_gen_property_values.clear()
	
	var property_keys : Array = []
	for property in _gen_property_list:
		property_keys.append(property["private_name"])
	
	for key in property_keys:
		var value = _generator.get(key)
		_gen_property_values[key] = value


# Feeds the generator all the properties that OnyxShape currently has saved.
func _load_genenerator_properties():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	# print("[OnyxShape] ", self.get_name() , 
	# 		" - _load_genenerator_properties()")
	
	var i = 0
	var values = _gen_property_values.values()
	var keys = _gen_property_values.keys()
	
	while i < keys.size():
		var property = keys[i]
		var value = values[i]
		
		_generator.set(property, value)
		i += 1


# /////////////////////////////////////////////////////////////////////////////
# SIGNAL FUNCTIONS


# Triggered when the shape_properties_updated signal is received from the generator.
func update_all_geometry():
	
#	print("[OnyxShape] ", self.get_name() , " - update_all_geometry()")
	
	_update_geometry()
	_update_hollow_geometry()

# Triggered when the property_list_changed signal is received from the generator. 
func update_gen_property_lists():

	_gen_property_list = _generator.get_shape_properties()
	_rebuild_genenerator_property_values()
	property_list_changed_notify()



# /////////////////////////////////////////////////////////////////////////////
# MESH UPDATERS

# Fetches up-to-date mesh data from the generator.
func _update_geometry():

	if Engine.editor_hint == false:
		return
	
	# print("[OnyxShape] ", self.get_name() , " - _update_geometry()")
	
	# Get the geometry from the generator.
	_onyx_mesh = _generator.update_geometry()
	
	# Optional UV Modifications
	var transform_vec = uv_scale
	if transform_vec.x == 0:
		transform_vec.x = 0.0001
	if transform_vec.y == 0:
		transform_vec.y = 0.0001
	
	if flip_uvs_vertically == true:
		transform_vec.y = transform_vec.y * -1.0
	if flip_uvs_horizontally == true:
		transform_vec.x = transform_vec.x * -1.0
	
	_onyx_mesh.multiply_uvs(transform_vec)
	
	# Create new mesh(es)
	var array_mesh = _onyx_mesh.render_array_meshes(material)
	set_mesh(array_mesh)
	
	# var helper = MeshDataTool.new()
	# var mesh = Mesh.new()

	# # Set the new mesh
	# var i = 0
	# for a_m in array_meshes:
	# 	helper.create_from_surface(a_m, 0)
	# 	print("MESH FORMAT - ", helper.get_format())
	# 	helper.commit_to_surface(mesh)
	# 	i += 1
	# 	# if i == 3:
	# 	# 	break

	# set_mesh(mesh)
	
	_update_boolean_geometry()
	update_gizmo()


# Internal function for updating the hollow mesh
func _update_hollow_geometry():
	
#	print("[OnyxShape] ", self.get_name() , " - _update_hollow_mesh()")
	
	if ( Engine.editor_hint == false || hollow_object == null || 
			hollow_enable == false ):
		return
	
	# Get the geometry from the generator.
	var hollow_onyx_mesh = _generator.update_hollow_geometry()
	
	# Optional UV Modifications
	var transform_vec = uv_scale
	if transform_vec.x == 0:
		transform_vec.x = 0.0001
	if transform_vec.y == 0:
		transform_vec.y = 0.0001
	
	if flip_uvs_vertically == true:
		transform_vec.y = transform_vec.y * -1.0
	if flip_uvs_horizontally == true:
		transform_vec.x = transform_vec.x * -1.0
	
	hollow_onyx_mesh.multiply_uvs(transform_vec)
	
	# Create new mesh(es)
	var array_mesh = hollow_onyx_mesh.render_array_meshes(material)
	hollow_object.set_mesh(array_mesh)
	hollow_mesh = array_mesh

	# Set the transform
	var new_location = _generator.get_hollow_origin()
	hollow_object.translation = new_location
	hollow_last_position = new_location
	
	update_gizmo()

# /////////////////////////////////////////////////////////////////////////////
# SUBTRACTION / INTERSECTION BOOLEAN PREVIEW

# Used to decide what happens when the boolean mode is switched.
func _update_boolean_mode():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return

	var is_parent_combiner = get_parent().is_class("CSGCombiner")
	var is_parent_csg = (get_parent().is_class("CSGShape") && !is_parent_combiner)
	
	
	print("[OnyxShape] ", self.get_name() , " - _update_boolean_mode()")
	
	# DELETIONS /////
	# If the parent is neither CSG nor Combiner, we should never enable preview
	if is_parent_combiner == false && is_parent_csg == false:
		print("1")
		_delete_boolean_preview()
		return

	# if we were at 0 or we no longer have a CSG parent, abandon!
	if operation == 0 && is_parent_csg == true :
		print("2")
		_delete_boolean_preview()
		return
	
	# IF THE PARENT IS A COMBINER AND HAS AN OPERATION OF 0, also delete.
	if is_parent_combiner:
		if get_parent().operation == 0:
			print("3")
			_delete_boolean_preview()
			return


	# CREATIONS /////
	# OTHERWISE create a boolean if needed and give the geometry with a new material
	if operation != 0 && is_parent_csg:
		print("4")
		_create_boolean_preview()
		return

	# OTHERWISE IF WE HAVE A COMBINER PARENT, we need to see what it does first
	if is_parent_combiner:
		if get_parent().operation != 0:
			print("5")
			_create_boolean_preview()
			return


# Used to create a node used for previewing the mesh when using a non-union boolean mode.
# DO NOT DIRECTLY CALL THIS, USE _UPDATE_BOOLEAN_PREVIEW() AS VERIFICATION.
func _create_boolean_preview():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
#	print("[OnyxShape] ", self.get_name() , " - _create_boolean_preview()")
	
	# Create the solid
	if has_node(BOOLEAN_PREVIEW_SOLID_NAME) == false:
		boolean_preview_node = MeshInstance.new()
		boolean_preview_node.set_name(BOOLEAN_PREVIEW_SOLID_NAME)
		add_child(boolean_preview_node)
	
	# Create the wire
	if has_node(BOOLEAN_PREVIEW_WIRE_NAME) == false:
		var boolean_wire = MeshInstance.new()
		boolean_wire.set_name(BOOLEAN_PREVIEW_WIRE_NAME)
		add_child(boolean_wire)
		
	_update_boolean_geometry()


# Used to remove a pre-existing boolean preview.  Only works when the node's operation mode
# is set to Union.
func _delete_boolean_preview():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
#	print("[OnyxShape] ", self.get_name() , " - _delete_boolean_preview()")
	
	if has_node(BOOLEAN_PREVIEW_SOLID_NAME) == true:
		boolean_preview_node = get_node(BOOLEAN_PREVIEW_SOLID_NAME)
		
		remove_child(boolean_preview_node)
		boolean_preview_node.free()
		boolean_preview_node = null
	
	if has_node(BOOLEAN_PREVIEW_WIRE_NAME) == true:
		var boolean_wire = get_node(BOOLEAN_PREVIEW_WIRE_NAME)
		
		remove_child(boolean_wire)
		boolean_wire.free()
		boolean_wire = null


# Used to render the boolean preview.
func _update_boolean_geometry():
	
	if Engine.editor_hint == false || is_inside_tree() == false :
		return
	
#	print("[OnyxShape] ", self.get_name() , " - _update_boolean_geometry()")
	
	# If we have a boolean preview, decide what to do.
	if has_node(BOOLEAN_PREVIEW_SOLID_NAME) == true:
		boolean_preview_node = get_node(BOOLEAN_PREVIEW_SOLID_NAME)
		var boolean_wire = get_node(BOOLEAN_PREVIEW_WIRE_NAME)

		# Get the materials
		var wire_mat : Material
		var solid_mat : Material

		# IF the parent is the CSGCombiner, inherit it's operation mode.
		var current_op : int
		if get_parent().is_class("CSGCombiner"):
			current_op = get_parent().operation
		else:
			current_op = self.operation

		if current_op == 1:
			wire_mat = get_plugin().get("bpreview_int_wire_mat")
			solid_mat = get_plugin().get("bpreview_int_solid_mat")
		elif current_op == 2:
			wire_mat = get_plugin().get("bpreview_sub_wire_mat")
			solid_mat = get_plugin().get("bpreview_sub_solid_mat")

		print(wire_mat, solid_mat)

		# SOLID /////
		# # Set the solid mesh using the current mesh
		var solid_mesh : Mesh = mesh.duplicate(false)
		var surface_count = solid_mesh.get_surface_count()

		for i in range(surface_count):
			solid_mesh.surface_set_material(i, solid_mat)
		boolean_preview_node.set_mesh(solid_mesh)
		
		# WIRE /////
		# var mat = get_plugin().get("boolean_preview_wire_mat")
		var wire_mesh = OnyxMesh.extract_wireframe_from_mesh(solid_mesh, 
				wire_mat)
		boolean_wire.set_mesh(wire_mesh)


# /////////////////////////////////////////////////////////////////////////////
# HOLLOW MAINTENANCE FUNCTIONS

# Updates the hollow_enable property.
func _update_hollow_enable(value):
	
	if Engine.editor_hint == false:
		return
	
	# If we're not yet inside the tree, set the value and return.
	if is_inside_tree() == false:
		hollow_enable = value
		return
	
	# REMEMBER THAT SAVING A SCENE CAUSES PROPERTIES TO BE RE-APPLIED, INSURANCE POLICY
	if hollow_enable == value:
		return
	
#	print("[Onyx] ", self.get_name() , " - _update_hollow_enable()")
	
	hollow_enable = value
	
	# if true, get the current class and instance it 
	if value == true:
		_create_hollow_object()
	else:
		_delete_hollow_object()
		


# Setter for hollow materials
func _update_hollow_material(value):
	
	if hollow_material == value:
		return
	
	# print("[Onyx] ", self.get_name() , " - _update_hollow_material()")
		
	hollow_material = value
	
	if hollow_object != null:
		hollow_object.material = value


# Creates the hollow object, won't generate new mesh data if it doesn't have to.
func _create_hollow_object():
		
#	print("[Onyx] ", self.get_name() , " - _create_hollow_object()")
	
	# REMEMBER THAT RE-SAVING A SCRIPT CAUSES IT TO BE RELOADED, MUST HAVE INSURANCE POLICY
	if Engine.editor_hint == false || hollow_object != null:
		print("Hollow object already found, returning!")
		return
	
	if has_node(HOLLOW_OBJECT_NAME):
		print("""Hollow object already exists in the scene, 
				assigning and returning!""")
		hollow_object = self.get_node(HOLLOW_OBJECT_NAME)
		return
	
	# Build the node
	hollow_object = CSGMesh.new()
	hollow_object.set_name(HOLLOW_OBJECT_NAME)
	add_child(hollow_object)
	
	# Check for mesh before generating one
	if hollow_mesh != null:
		hollow_object.set_mesh(hollow_mesh)
	else:
		_update_hollow_geometry()
	
	# Set the origin and operation mode
	if _generator != null:
		hollow_object.translation = _generator.get_hollow_origin()
	else:
		hollow_object.translation = hollow_last_position
	
	# Set the operation mode to subtract
	hollow_object.operation = 2
	
	# If the parent has a material, let the child inherit it.
	if hollow_material != null:
		hollow_object.material = hollow_material
	elif material != null:
		hollow_material = self.material
	
	# print("new hollow object - ", hollow_object)


# Deletes the hollow object node and defaults all hollow data.
func _delete_hollow_object():
	
#	print("[Onyx] ", self.get_name() , " - _delete_hollow_data()")
	
	remove_child(hollow_object)
		
	if hollow_object != null:
		hollow_object.queue_free()
		
	hollow_enable = false
	hollow_object = null
	hollow_mesh = null
	
	print("deleted hollow object - ", hollow_object)


# Creates a hollow object node when it is loaded at runtime.
func _build_runtime_hollow_object():
	
	# print("[Onyx] ", self.get_name() , " - _build_runtime_hollow_object()")
	
	if Engine.editor_hint == false:
		if hollow_mesh != null:

			hollow_object = CSGMesh.new()
			hollow_object.set_name(HOLLOW_OBJECT_NAME)
			add_child(hollow_object)
			
			hollow_object.operation = 2
			hollow_object.set_mesh(hollow_mesh)
			hollow_object.material = hollow_material

# ////////////////////////////////////////////////////////////
# GIZMO INTERFACE

# Used by ControlPointGizmo to get the currently active set of control points.
func get_gizmo_control_points() -> Array:
	
	if _generator != null:
		return _generator.acv_controls.values()
	else:
		return []



# ////////////////////////////////////////////////////////////
# ORIGIN AUTO-UPDATE FUNCTIONS

# Called when the origin position anchoring switches using the
# difference in movement required to change position.
#
# Only trigger from a signal.
func _move_origin(movement_vec : Vector3):
	
#	print("[OnyxShape] ", self.get_name() , " - _move_origin()")
	
	var global_t = self.global_transform
	
	var new_loc = self.global_transform.xform(self.translation + movement_vec)
	var old_loc = self.global_transform.xform(self.translation)
	var new_translation = new_loc - old_loc
	#print("MOVING LOCATION: ", old_loc, " -> ", new_loc)
	#print("TRANSLATION: ", new_translation)
	
	# set it
	global_translate(new_translation)
	translate_children(new_translation * -1)
	
	# Boolean Preview Overrides
	if has_node(BOOLEAN_PREVIEW_SOLID_NAME) == true:
		get_node(BOOLEAN_PREVIEW_SOLID_NAME).set_translation(Vector3(0, 0, 0))
	if has_node(BOOLEAN_PREVIEW_WIRE_NAME) == true:
		get_node(BOOLEAN_PREVIEW_WIRE_NAME).set_translation(Vector3(0, 0, 0))


# Called when the shape has changed and the origin needs to move
# into the correct position, using the movement difference.
#
# Only trigger from a signal.
func _replace_origin(new_loc : Vector3):
	
#	print("[OnyxShape] ", self.get_name() , " - _move_origin()")

	var old_loc = self.global_transform.origin
	var new_translation = new_loc - old_loc
	
	# set it
	global_translate(new_translation)
	translate_children(new_translation * -1)
	
	# Boolean Preview Overrides
	if has_node(BOOLEAN_PREVIEW_SOLID_NAME) == true:
		get_node(BOOLEAN_PREVIEW_SOLID_NAME).set_translation(Vector3(0, 0, 0))
	if has_node(BOOLEAN_PREVIEW_WIRE_NAME) == true:
		get_node(BOOLEAN_PREVIEW_WIRE_NAME).set_translation(Vector3(0, 0, 0))
	


# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

func editor_select():
	if Engine.editor_hint == true:
		is_selected = true
		activate_node()
		_generator.build_controls()
		_generator.editor_select()
	
	
func editor_deselect():
	if Engine.editor_hint == true:
		is_selected = false
		
		if _generator != null:
			_generator.clear_controls()
			_generator.editor_deselect()


# ////////////////////////////////////////////////////////////
# CHILD MANAGEMENT
func translate_children(translation):
	
#	print("[Onyx] ", self.get_name() , " - translate_children()")
	
	for child in get_children():
		if child.name != _generator.name:
			child.global_translate(translation)

