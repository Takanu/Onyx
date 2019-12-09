tool
extends Button

# ////////////////////////////////////////////////////////////
# INFO
# Allows a button to become part of a toggle set.  When one button is toggled on, any other button
# in the set will automatically toggle off.

# All buttons that are part of the same toggle set must be children of the same parent.


# ////////////////////////////////////////////////////////////
# FUNCTIONS

# The node that "owns" the toolbar and that will be the recipient of function triggers.
var owner_node

# The function to trigger when toggled on or off.  Must accept a 
var function_trigger = ""


# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _ready():
	pass


func _toggled(is_pressed):
	owner_node.call(function_trigger)

