extends RefCounted
## Shared farm geometry. Field, camera and bot all place things on the same grid.

const TILE_SPACING := 1.36
const TILE_HEIGHT := 0.34
const TILE_WIDTH := 1.12
const STUBBLE := 0.16


## Height of the walkable ground plane (top of the tiles).
static func ground_y() -> float:
	return TILE_HEIGHT * 0.45


## Center of the field in world space.
static func farm_center() -> Vector3:
	return Vector3(0.0, ground_y(), 0.0)
