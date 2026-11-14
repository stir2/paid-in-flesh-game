class_name AbyssLevelBoundary
extends TileMapLayer
## Separate indestructible collision, leaving authored source layers untouched.
var progression: AbyssSpecialRooms
var gate: Dictionary = {}
var gate_cells: Array[Vector2i] = []
func configure(service: AbyssSpecialRooms, definition: Dictionary) -> void:
	# The gate actor covers its opening; the rest of the boundary must look solid.
	self_modulate.a = 0.0
	var rock := TileMapLayer.new()
	rock.name = "BoundaryRock"
	rock.tile_set = tile_set
	rock.collision_enabled = false
	rock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for cell in get_used_cells():
		if not gate_cells.has(cell):
			rock.set_cell(cell, AbyssTerrainArt.SOURCE, Vector2i.ZERO)
	AbyssTerrainArt.refresh_layer(rock)
	add_child(rock)
	progression = service
	gate = definition
	service.state.changed.connect(_refresh)
	_refresh()
func _refresh() -> void:
	for cell in gate_cells:
		if progression.is_gate_unlocked(gate):
			erase_cell(cell)
		else:
			set_cell(cell,0,Vector2i.ZERO)
