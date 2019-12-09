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
	
	print("HEY BUTTON PRESSED")
	print(owner_node)
	print(function_trigger)
	
	if is_pressed == true:
		
		# Untoggle all other buttons
		var container = get_parent()		
		for child in container.get_children():
			if child is BaseButton:
				
				if child.name != self.name:
					print(child.name)
					child.set_pressed(false)
					child._toggled(false)
		
		# Toggle this button and activate the function
		set_pressed(is_pressed)
		
		if owner_node != null && function_trigger != "":
			print("HEY CALLING OWNER")
			owner_node.call(function_trigger, true)
		
		
	# Otherwise if we are pressed, "unpress" and call the owner node.
	else:
		if pressed == true:
			set_pressed(is_pressed)
			
			if owner_node != null && function_trigger != "":
				print("HEY CALLING OWNER")
				owner_node.call(function_trigger, false)
