@tool

extends Node

class_name PaintableVoxels


## Allows parent Node to be live painted rith mouse input
##
## + Connects to parent CollisionObject3D to listen for input_events
## + modifies voxel data according to its settings
##
## ! warns if it does not have a proper parent, does NOT modify scene tree!
