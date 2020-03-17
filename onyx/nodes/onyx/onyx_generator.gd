tool
extends Spatial

# /////////////////////////////////////////////////////////////////////////////
# INFO

# A generator used by OnyxShape to build and manage the data and
# control points that makes up a shape.
#
# This class sets up important function interfaces and convenience functions
# for generators.


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# INTERFACE (the important bits)

# GEOMETRY ///////////////

# update_geometry() - Returns geometry for this generator.


# update_hollow_geometry() - Returns geometry for the hollow component
# of this generator.


# PROPERTY LISTS ///////////////


# get_shape_properties() - Returns every property that the shape needs to both make
# public and be saved by the owner.
#
# NOTE - For individual property updates use the signal "shape_properties_updated"


# ORIGIN ///////////////

# update_origin_mode() - Returns the movement difference required to move
# the owner when the origin mode changes.

# update_origin_position(new_location = null) - Returns the movement difference 
# required to move the owner when the object properties change.

# NOTE - Not all generators will require the origin point to auto-update.
# NOTE - These functions will return null if not overridden.


# ASPECT ///////////////

# get_shape_aspects() - Returns general details about the shapes size and form.

# set_shape_aspects(aspects) - Applies given aspects that the shape will use to determine
# it's shape.  Used when the owner switches shape types



# /////////////////////////////////////////////////////////////////////////////
# STATICS

# An enumerator used by get/set_shape_aspects to define general qualities of a shape
# so that when the owner switches one shape for another, the new shape still conforms
# to a general set of expectations.
#
# Shapes can utilize as many or as few as they'd like.
enum ShapeAspects {
	BOUNDING_BOX,		# the size and area of the shape
	HOLLOW_THICKNESS,		# if it had a hollow, what it's general thickness was
	HEIGHT,				# if height was important, what that total was
	
	START_POINT_POS,		# if it used a path, where it started
	START_POINT_ROT,
	START_POINT_SCL,
	
	END_POINT_POS,		# if it used a path, where it ended.
	END_POINT_ROT,
	END_POINT_SCL,
}



# /////////////////////////////////////////////////////////////////////////////
# SIGNALS

# Signals used by OnyxShape to understand when to request data
# or perform actions from the Generator.


# Called when any shape property is updated.  The signal includes
# the properties that changed as an argument.
#
signal shape_properties_updated

# Called when any hollow property is updated.  This allows the 
# container to just update the hollow mesh instead of also updating
# the normal shape.
#
# The signal includes the properties that changed as an argument.
#
signal hollow_properties_updated


# Called when the list of public-facing properties it offers changes.
# 
# Could be triggered when a selected enum causes some properties to disappear
# and others to appear for example.
#
signal property_list_changed


# Called when the origin point needs to be moved using a translation vector.
#
signal request_origin_move


# Called when the origin point needs to be changed using a new global position.
#
signal request_origin_change



# /////////////////////////
# PRIVATE

# The face set script, used for managing geometric data.
#
# TODO - Determine if this is actually necessary to store or not.
# var onyx_mesh = OnyxMesh.new()

# The control points that will be displayed in the editor to interact with the node.
var active_controls : Dictionary = {}

# Old control points that are saved every time a handle has finished moving.
var previous_active_controls : Dictionary = {}


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# INITIALIZATION


# Global initialisation
func _enter_tree():
	print("[OnyxGenerator] ", self, " - _enter_tree()")
	pass


# Called when the node enters the scene tree for the first time.
func _ready():
	print("[OnyxGenerator] ", self, " - _ready()")
	
	if Engine.editor_hint == true:
		
		# Ensure the old_handles variable match the current handles we have for undo/redo.
		previous_active_controls = get_control_data()


# Used to perform some basic deallocation where necessary
func _exit_tree():
	print("[OnyxGenerator] ", self, " - _exit_tree()")
	
	# Trigger this to ensure nothing is left behind.
	if Engine.editor_hint == true:
		editor_deselect()
		active_controls.clear()
		previous_active_controls.clear()
	
	return


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# PROPERTY HANDLING

# Used to prevent weird "disappearances" of the plugin.  smh...
func get_plugin():
	if Engine.editor_hint == true:
		return get_node("/root/EditorNode/Onyx")
	else:
		return null


# Returns the list of custom shape properties that an owner should save and display.
func get_shape_properties() -> Dictionary:
	print("[OnyxGenerator] ", self, 
			" - get_shape_properties() - Override this function!")
	return {}


# Returns a set of custom properties used to tell the owner general aspects of it's
# shape, helping the owner set new properties for the next shape.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func get_shape_aspects() -> Dictionary:
	print("[OnyxGenerator] ", self, 
			" - get_shape_aspects() - Override this function!")
	return {}


# Used by the owner to implant parts of the last shape generator to a new one.
#
# NOTE - Conforms to the SHAPE_ASPECTS constant.
# 
func set_shape_aspects(aspects : Dictionary):
	print("[OnyxGenerator] ", self, 
			" - set_shape_aspects() - Override this function!")
	pass



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# MESH GENERATION


# Creates new geometry to reflect the shapes current properties, then returns it.
func update_geometry() -> OnyxMesh:
	print("[OnyxGenerator] ", self, 
			" - update_geometry() - Override this function!")
	return OnyxMesh.new()


# Creates new geometry to reflect the hollow shapes current properties, 
# then returns it.
func update_hollow_geometry() -> OnyxMesh:
	print("[OnyxGenerator] ", self, 
			" - update_hollow_geometry() - Override this function!")
	return OnyxMesh.new()


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# ORIGIN POINT UPDATERS


# Updates the origin location when the corresponding property is changed.
#
# NOTE - Does not have to be overridden, not all shapes should auto-update origin points.
#
func _update_origin_mode() :
	pass


# Updates the origin position for the currently-active Origin Mode, either by building 
# a new one using it's own properties or through a new position.  
#
# DOES NOT update the origin when the origin property has changed, for use with handle commits.
#
# NOTE - Does not have to be overridden, not all shapes should auto-update origin points.
#
func _update_origin_position():
	pass

# Gets the hollow origin based on it's properties.  
#
# NOTE - Doesn't always have to be overridden.
#
func get_hollow_origin():
	return Vector3(0, 0, 0)


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# HANDLE GENERATION AND MAINTENANCE


# Clears and rebuilds the control list from scratch.
func build_control_points():
	print("[OnyxGenerator] ", self, 
			" - build_handles() - Override this function!")
	pass


# Ensures the data in the current control list reflects the shape properties.
func refresh_control_data():
	print("[OnyxGenerator] ", self, 
			" - refresh_control_data() - Override this function!")
	pass


# Used by the convenience functions handle_changed and handle_committed to apply
# handle updates generated by the Gizmo (AKA - When someone moves a control point)
func update_control_from_gizmo(control):
	print("[OnyxGenerator] ", self, 
			" - update_control_from_gizmo() - Override this function!")
	pass


# Used to apply the control point data to the shape's property list.
func apply_control_attributes():
	print("[OnyxGenerator] ", self, 
			" - apply_handle_attributes() - Override this function!")
	pass


# Used when certain controls have a relationship with each other, such as
# the old behaviour of OnyxCube where opposite control points would equal the same
# once the control points were committed.
#
# NOTE - Does not have to be inherited, not all shapes should auto-update origin points.
#
func balance_control_data():
	pass


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# CONTROL POINT MANAGEMENT FUNCTIONS


# Used when this object is selected for the control points to be built and displayed.
func build_controls():
	
	print("[OnyxGenerator] ", self, " - build_controls()")
	
	if Engine.editor_hint == true:
		build_control_points()
		refresh_control_data()
		previous_active_controls = get_control_data()

# Used when this object is deselected to hide the control points.
func clear_controls():
	
	print("[OnyxGenerator] ", self, " - clear_controls()")
	
	if Engine.editor_hint == true:
		active_controls.clear()
	

# (CONVENIENCE FUNC) Use when creating control points to automate the process
# of updating the Generator when one of it's handles changes.
#
func modify_control(control):
	
	print("[OnyxGenerator] ", self, " - modify_control()")
	
#	print("********************************")
#	print("[Onyx] ", self.get_name() , " - handle_change()")
	
	update_control_from_gizmo(control)
	_process_property_update()
#	print("********************************")
	

# (CONVENIENCE FUNC) Use when creating control points to submit the final control
# point, occurring when the user clicks off the point.
#
# NOTE - This should only finish committing information, restore_state will finalize 
# movement and other opeirations.
#
func commit_control(control):
#	print("********************************")
	print("[OnyxGenerator] ", self, " - commit_control()")
	
	update_control_from_gizmo(control)
	apply_control_attributes()
	
	_update_origin_position()
	_process_property_update()
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	previous_active_controls = get_control_data()
	
#	print("********************************")

# Used by the ControlPoint to get the global transform of the owning node.
func get_global_transform():
	return self.global_transform

# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# STATE MANAGEMENT


# Returns a list of control data from each point.
func get_control_data() -> Dictionary:
	
	print("[OnyxGenerator] ", self, " - get_control_data()")
	
	var result = {}
	for control in active_controls.values():
		result[control.control_name] = control.get_control_data()
	
	return result

# Changes all current control point data with a previously set list of control data.
func set_control_data(data : Dictionary):
	
	print("[OnyxGenerator] ", self, " - get_control_data()")

	for data_key in data.keys():
		active_controls[data_key].set_control_data(data[data_key])
	
#	print("Setting done!")



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# UNDO/REDO STATES


# Returns a state that can be used to undo or redo a previous change to the shape.
func get_gizmo_redo_state(control_point):
	var saved_translation = self.global_transform.origin
	return [get_control_data(), saved_translation]
	
	# TODO - why does the below code exist when it would never get executed....
	
	# If it has this method, it will have an origin setting.  This must then be preserved.
	_update_origin_position()
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	previous_active_controls = get_control_data()


# Returns a state specifically for undo functions in SnapGizmo.
func get_gizmo_undo_state(control_point):
	var saved_translation = self.global_transform.origin
	return [previous_active_controls.duplicate(false), saved_translation]


# Restores the state of the shape to a previous given state.
func restore_state(state):
	print("[OnyxGenerator] ", self, " - restore_state()")
	
	var new_controls = state[0]
	var stored_location = state[1]
	
#	print("RESTORING STATE -", state)
	
	set_control_data(new_controls)
	previous_active_controls = new_controls.duplicate(true)
	apply_control_attributes()
	
	_process_origin_change(stored_location)
	balance_control_data()
	
	_process_property_update()


# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

func editor_select():
	print("[OnyxGenerator] ", self, " - editor_select()")
	
	if Engine.editor_hint == true:
#		is_selected = true
		build_controls()
	
	
func editor_deselect():
	print("[OnyxGenerator] ", self.name, " - editor_deselect()")
	
	if Engine.editor_hint == true:
#		is_selected = false
		clear_controls()
	


# ////////////////////////////////////////////////////////////
# SIGNAL CONVENIENCE FUNCTIONS

# Used when a property is updated to perform some necessary
# control point and property refreshes, followed by calling the property
# signal.
func _process_property_update():
	refresh_control_data()
	emit_signal("shape_properties_updated")


func _process_hollow_property_update():
	emit_signal("hollow_properties_updated")


func _process_origin_move(movement_vec : Vector3):
	emit_signal("request_origin_move", movement_vec)


func _process_origin_change(translation : Vector3):
	emit_signal("request_origin_change", translation)
