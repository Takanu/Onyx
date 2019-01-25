tool
extends Object

# ////////////////////////////////////////////////////////////
# INFO
# A class dedicated to managing handle sets, used by snap_gizmo to populate an EditorSpatialGizmo.
# The dictionary format is designed to enable categorization of handle types for complex custom nodes.

# The main handle dictionary, that organises handles in a friendly and manageable way.
var handles = {}


# ////////////////////////////////////////////////////////////
# INITIALISERS

func add_handle_set(name, handles, snap_triangles, lines):
	
	if name == null:
		print("HandleSet : add_handle_set - No name provided.")
		return
	
	if handles.size() == 0:
		print("HandleSet : add_handle_set - No handles included.")
		return
	
	# add to normal dictionary
	handles[name] = [handles, snap_triangles, lines]
	

# ////////////////////////////////////////////////////////////
# GETTERS

# Returns just the handles in a way that can be used with an EditorSpatialGizmo.
# If include_keys is left blank, all handle sets will be included.  Otherwise only those specified will be included.
func get_handle_array(include_keys):
	
	var result = []
	var keys = []
	
	# Handle key masking
	if include_keys.size() != 0:
		for key in include_keys:
			if handles.keys().has(key) == true:
				keys.append(key)
		
	else:
		keys = handles.keys()
	
	
	for key in keys:
		var handle_set = handles[key]
		var handle_points = handle_set[0]
		
		for handle in handle_points:
			result.append(handle)
			
	return result
	
	
# Returns a handle including the name of the set it came from, its snapping triangles and debug lines.
# If the index is from a handle array that only included a selective group of handle keys, you must use it
# here to correctly fetch the right handle.
func get_handle_with_index(index, include_keys):
	
	var result = []
	var keys = []
	
	# Handle key masking
	if include_keys.size() != 0:
		for key in include_keys:
			if handles.keys().has(key) == true:
				keys.append(key)
		
	else:
		keys = handles.keys()
		
	
	var current_index = 0
	
	# Fetching handles
	for key in keys:
		var handle_set = handles[key]
		var handle_points = handle_set[0]
		var handle_triangles = handle_set[1]
		var handle_lines = handle_set[2]
		
		# If the size of the array is greater than the current search, the point is here.
		if current_index + handle_points.size() > index:
			var set_index = index - current_index
			
			var handle = handle_points[set_index]
			var triangles = handle_triangles[set_index]
			var lines = handle_lines[set_index]
			
			return [key, handle, triangles, lines]
			
		# Otherwise add it to the current index and continue
		else:
			current_index += handle_points.size()
			

# ////////////////////////////////////////////////////////////
# MAINTENANCE

func clear():
	handles = {}



