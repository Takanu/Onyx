tool
extends CSGMesh

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export(Dictionary) var test_dictionary = {}

func _ready():
	
	if test_dictionary.size() == 0:
		print("REGENERATING DICTIONARY")
		test_dictionary['help'] = 4
		test_dictionary['this'] = 2
		test_dictionary['thing'] = 0
		test_dictionary['is'] = 4
		test_dictionary['totally'] = 2
		test_dictionary['busted'] = 0