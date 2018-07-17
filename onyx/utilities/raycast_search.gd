#tool
extends Node

# ////////////////////////////////////////////////////////////
# INFO
# Used by Onyx to collect objects within areas, perform raycasts and get hit information within the Editor.
# Here's hoping Editor scripting evolves more in the future <3

# ////////////////////////////////////////////////////////////
# PROPERTIES
# used to fetch the bounds
var bounds_fetch = load("res://addons/onyx/utilities/raycast_bounds.gd").new()

# ////////////////////////////////////////////////////////////
# AREA SEARCH

# Returns an array of nodes that had collision shapes and are found to be inside an axis-aligned bounding box.
# WARNING - This is expensive on large scenes, as it has to search through all nodes in the scene.
func find_collision_in_bounds(bounds):
	
	# get the root scene node
	var nodes_to_search = []
	var found_nodes = []
	
	nodes_to_search.append(get_tree().get_root())
	
	while nodes_to_search.size() != 0:
		var target = nodes_to_search.pop_front()
		var target_area = bounds_fetch.get_collision_bounds(target)
		
		# If we got a valid bounding box and it intersects the one we have, add it.
		if target_area != null:
			if target_area.intersects(bounds):
				found_nodes.append(target)
	
	return found_nodes

	
# Returns an array of nodes that has collision or geometry and are found to be inside an axis-aligned bounding box.
# WARNING - This is expensive on large scenes, as it has to search through all nodes in the scene.
func find_nodes_in_area(area):
	
	# get the root scene node
	var nodes_to_search = []
	var found_nodes = []
	
	nodes_to_search.append(get_tree().get_root())
	
	while nodes_to_search.size() != 0:
		var target = nodes_to_search.pop_front()
		var target_area = bounds_fetch.get_node_bounds(target)
		
		# If we got a valid bounding box and it intersects the one we have, add it.
		if target_area != null:
			if target_area.intersects(bounds):
				found_nodes.append(target)
	
	return found_nodes