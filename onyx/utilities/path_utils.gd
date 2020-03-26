tool
extends Node

# /////////////////////////////////////////////////////////////////////////////
# INFO
# Used to perform tasks around handling, building and measuring 2D and 3D
# paths, including:
#
# - Polygonal paths
# - Bezier paths
# - Interpolated paths
#


# ////////////////////////////////////////////////////////////
# DEPENDENCIES

# 2D and 3D vector math library
var VecUtils = load("res://addons/onyx/utilities/vector_utils.gd")


# ////////////////////////////////////////////////////////////
# ENUMERATORS

# NOT DONE - The interpolation mode defined for a path. 
enum PathInterpolationMode {
	QUADRATIC,
}


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# PUBLIC STATIC FUNCTIONS

# This is kind of a placeholder for now, I dont know much about 3D curve math omo

