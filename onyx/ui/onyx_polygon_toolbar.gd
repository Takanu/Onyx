tool
extends HBoxContainer


# ////////////////////////////////////////////////////////////
# EDIT ELEMENTS
onready var move_button : Button = get_node("move")
onready var add_button : Button = get_node("add")
onready var insert_button : Button = get_node("insert")
onready var delete_button : Button = get_node("delete")

var edit_mode : int = 0
const EDIT_MODE_NONE = 0
const EDIT_MODE_MOVE = 1
const EDIT_MODE_ADD = 2
const EDIT_MODE_INSERT = 3
const EDIT_MODE_DELETE = 4

signal edit_mode_changed

# Used to prevent recursion loops when editing button states
var edit_lock : bool = false

# ////////////////////////////////////////////////////////////
func _enter_tree():
	print("entered tree")

# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Grab all the buttons we have
	
	# Link the three button signals (NOPE CASES RECURSION LOOP)
	move_button.connect("toggled", self, "_button_move_toggled")
	add_button.connect("toggled", self, "_button_add_toggled")
	insert_button.connect("toggled", self, "_button_insert_toggled")
	delete_button.connect("toggled", self, "_button_delete_toggled")
	print("finished connections")

# ////////////////////////////////////////////////////////////
# UI FUNCTIONS

# Arranges the buttons like a modal set, where only can be active at any time
func _set_edit_mode(new_edit_mode, is_pressed):
	
	if edit_lock == true:
		return
	
	edit_lock = true
	
	move_button.pressed = false
	add_button.pressed = false
	insert_button.pressed = false
	delete_button.pressed = false
	
	# If the one that was active becomes inactive, turn it off.
	# (dont need this rn)
#	if edit_mode != 0:
#		if edit_mode == new_edit_mode:
#			edit_mode = 0
#			edit_lock = false
#			return
	
	match new_edit_mode:
		EDIT_MODE_MOVE:
			move_button.pressed = true
		EDIT_MODE_ADD:
			add_button.pressed = true
		EDIT_MODE_INSERT:
			insert_button.pressed = true
		EDIT_MODE_DELETE:
			delete_button.pressed = true
	
	var old_edit_mode = edit_mode
	edit_mode = new_edit_mode
	
	# Only emit a signal if the edit mode actually changed.
	if old_edit_mode != new_edit_mode:
		emit_signal("edit_mode_changed", old_edit_mode, new_edit_mode)
		
	edit_lock = false



func _button_move_toggled(is_pressed):
	_set_edit_mode(EDIT_MODE_MOVE, is_pressed)

func _button_add_toggled(is_pressed):
	_set_edit_mode(EDIT_MODE_ADD, is_pressed)

func _button_insert_toggled(is_pressed):
	_set_edit_mode(EDIT_MODE_INSERT, is_pressed)

func _button_delete_toggled(is_pressed):
	_set_edit_mode(EDIT_MODE_DELETE, is_pressed)

