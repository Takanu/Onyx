tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Shared toolset for Flux-type nodes, dealing with node management

# ////////////////////////////////////////////////////////////
# INITIALIZATION

# ???


# ////////////////////////////////////////////////////////////
# HANDLE MANAGEMENT FUNCTIONS

# ???


# ////////////////////////////////////////////////////////////
# ARCHIVE
# An attempt to use physics ray-tracing to fetch results.  Cannot be used with Godot as physics cannot be used in the editor right now.
func build_raycasted_location_array():
	pass
	
#	print("RAAAYYYZZZZ")
#
#	var results = []
#	var space_state = get_world().direct_space_state
#
#	var bounds = face_set.get_bounds()
#	var start_height = bounds.position.y + bounds.size.y
#	var upper_pos = bounds.position + bounds.size
#	var lower_pos = bounds.position
#
#	var points_found = 0
#
#	while points_found < spawn_count:
#
#		# get the start and end point
#		var x = rand_range(lower_pos.x, upper_pos.x)
#		var z = rand_range(lower_pos.z, upper_pos.z)
#
#		var start = Vector3(x, start_height, z)
#		var end = Vector3(x, lower_pos.y, z)
#
#		# see if we catch something
#		var raycast_result = space_state.intersect_ray(start, end)
#		print(raycast_result)
#		if raycast_result.empty() == false:
#			results.append(raycast_result["position"])
#
#		points_found += 1
#
#	spawn_locations = results
				
				