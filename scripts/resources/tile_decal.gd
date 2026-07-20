class_name TileDecal
extends Resource

## A decal/particle placed on one side of a wall tile.

enum Side { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

@export var side: int = Side.NORTH
@export var decal_id: String = ""         ## asset id from decal library
@export var offset: float = 0.5           ## position along the wall (0..1)
@export var decal_rotation: int = 0       ## 0 or 90 degrees
@export var z_order: int = 0              ## stacking order
@export var scale: float = 1.0            ## scale multiplier

static func create(s: int, did: String, off: float = 0.5, rot: int = 0, z: int = 0, scl: float = 1.0) -> TileDecal:
	var d := TileDecal.new()
	d.side = s; d.decal_id = did; d.offset = off; d.decal_rotation = rot; d.z_order = z; d.scale = scl
	return d
