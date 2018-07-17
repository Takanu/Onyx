tool
extends EditorPlugin

# ////////////////////////////////////////////////////////////
# PROPERTIES

# Core node types
const OnyxCube = preload("./nodes/onyx_cube.gd")
const OnyxSprinkle  = preload("./nodes/onyx_sprinkle.gd")

# Gizmo types

const SnapGizmo = preload("./gizmos/snap_gizmo.gd")


# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	# Give this node a name so any other node can access it using "node/EditorNode/Onyx"
	name = "Onyx"
	
    # Initialization of the plugin goes here
	add_custom_type("OnyxNode", "Spatial", preload("./nodes/onyx_node.gd"), null)
	add_custom_type("OnyxCube", "CSGMesh", preload("./nodes/onyx_cube.gd"), null)
	add_custom_type("OnyxSprinkle", "Spatial", preload("./nodes/onyx_sprinkle.gd"), null)
	
	pass
	
	
func create_spatial_gizmo(for_spatial):
	
	if for_spatial is OnyxCube:
		var gizmo = SnapGizmo.new(self, for_spatial)
		return gizmo
	
	if for_spatial is OnyxSprinkle:
		var gizmo = SnapGizmo.new(self, for_spatial)
		return gizmo
		


func _exit_tree():
    # Clean-up of the plugin goes here
	remove_custom_type("OnyxCube")
	pass