extends SceneTree
## Isolated runner required: autoloads can write user settings. No save slots used.
var failures := 0
var rooms_checked := 0
var approaches_checked := 0
var methods := {}
var traversals := 0
var planned_checked := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

# A conservative climb graph: use the real 30x36 body footprint and require
# continuous climbable tiles, rather than accepting an empty point or a landing
# elsewhere in the room. One-way platforms permit the tested upward approach.
func body_clear(room: AbyssAuthoredRoom, cell: Vector2i) -> bool:
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * room.tile_pixels
	var first := Vector2i((center - Vector2(14.9, 17.9)).floor() / room.tile_pixels)
	var last := Vector2i((center + Vector2(14.9, 17.9)).floor() / room.tile_pixels)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for key in ["Solid", "ConditionalWalls", "BreakableWalls", "Climbables"]:
				var layer := room.get_node_or_null(NodePath(key)) as TileMapLayer
				if layer != null and layer.collision_enabled and AbyssRoomTemplateValidator._has_collision(layer, Vector2i(x, y)):
					return false
	return true

func reachable_ladder(room: AbyssAuthoredRoom, center: Vector2i) -> Dictionary:
	var ladder := room.get_node("Climbables") as TileMapLayer
	var visited := {center: true}
	var pending: Array[Vector2i] = [center]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var adjacent: Vector2i = cell + direction
			if visited.has(adjacent) or not AbyssClimbableTiles.is_climbable(ladder, adjacent) or not body_clear(room, adjacent):
				continue
			visited[adjacent] = true
			pending.append(adjacent)
	return visited

func climb_from_below(room: AbyssAuthoredRoom, checkpoint: AbyssSpecialSpawnRequest) -> void:
	root.add_child(room)
	var player := load("res://Scenes/Player/player.tscn").instantiate() as Player
	root.add_child(player)
	player.global_position = room.position + Vector2(checkpoint.local_position.x, (room.room_size.y - 3) * room.tile_pixels)
	player.reset_movement()
	player.stamina.reset_stamina()
	for frame in 2: await physics_frame
	Input.action_press("Move Up")
	var reached := false
	for frame in 240:
		await physics_frame
		await process_frame
		if (player.global_position - Vector2(0, 18)).distance_to(room.position + checkpoint.local_position) < 20:
			reached = true
			break
	Input.action_release("Move Up")
	check(reached, "Actual player could not climb onto checkpoint platform: " + str(room.position))
	check(not checkpoint.progression.state.checkpoints.get(checkpoint.definition.id, {}).get("activated", false), "Approaching checkpoint auto-activated it")
	traversals += 1
	player.free()
	root.remove_child(room)

func connected_rooms(service: AbyssSpecialRooms, level: int, bounds: Vector2i) -> Dictionary:
	var visited := {}
	var pending: Array[Vector2i] = []
	for x in range(bounds.x, bounds.y):
		var coords := Vector2i(x, 0)
		if service.routes.get_room(coords).is_main_route:
			visited[coords] = true
			pending.append(coords)
			break
	while not pending.is_empty():
		var coords: Vector2i = pending.pop_back()
		var room := service.routes.get_room(coords)
		var neighbors := room.logical_neighbors()
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var adjacent: Vector2i = coords + direction
			if room.allows_open_adjacency(service.routes.get_room(adjacent)):
				neighbors.append(adjacent)
		for adjacent in neighbors:
			if adjacent.y < -32 or adjacent.y > 160 or service.level_at(adjacent) != level or visited.has(adjacent): continue
			visited[adjacent] = true
			pending.append(adjacent)
	return visited

func run() -> void:
	var registry := load("res://Scenes/Underground/Rooms/authored_registry.tres") as AbyssRoomTemplateRegistry
	for seed_value in [12345, 514087, 5482856939356729, 42, 8675309, 20261114]:
		var region := AbyssRegionConfig.new()
		region.global_seed = seed_value
		var config := load("res://Scenes/Underground/Generation/Config/short_campaign_progression.tres") as AbyssProgressionConfig
		var routes := AbyssRouteGenerator.new(region, AbyssRouteConfig.new(), config)
		var service := AbyssSpecialRooms.new(routes, config, AbyssProgressionState.new())
		service.ensure_checkpoint_access = true
		var selector := AbyssRoomTemplateSelector.new(registry, seed_value)
		selector.checkpoint_planner = service
		var terrain := AbyssTerrainConfig.new()
		var boundary := AbyssCavernBoundaryField.new(routes, selector, terrain)
		for level in range(1, 4):
			var count := 0
			var bounds := config.room_bounds(level, region.chunk_size.x)
			var connected := connected_rooms(service, level, bounds)
			for y in range(100):
				for x in range(bounds.x, bounds.y):
					var coords := Vector2i(x, y)
					if not service.has_checkpoint(coords): continue
					planned_checked += 1
					check(connected.has(coords), "Checkpoint in disconnected cavern: %s / %s" % [seed_value, coords])
					if count >= 4: continue
					var request := selector.select_room(routes, coords)
					var room := AbyssRoomTerrainBuilder.build(request, terrain, boundary, null, service)
					var checkpoint: AbyssSpecialSpawnRequest
					for spawn in room.spawn_requests:
						if spawn.kind == &"checkpoint": checkpoint = spawn
					check(checkpoint != null, "Missing checkpoint: %s / %s" % [seed_value, coords])
					if checkpoint != null:
						var center := Vector2i(checkpoint.local_position / room.tile_pixels)
						check(body_clear(room, center), "Checkpoint body clearance: %s / %s" % [seed_value, coords])
						var reachable := reachable_ladder(room, center)
						for id in request.requirements.route_openings:
							var side := ["north", "east", "south", "west"].find(String(id).get_slice(":", 0))
							var inside: Vector2i = request.requirements.route_openings[id] - AbyssRegionGenerator.DIRECTIONS[side] * 2
							check(reachable.has(inside), "No body-sized climb approach: %s / %s / %s" % [seed_value, coords, id])
							approaches_checked += 1
						if request.requirements.region == AbyssRoomData.Region.OPEN:
							check(reachable.has(Vector2i(center.x, room.room_size.y - 3)), "Open checkpoint unreachable from below")
							if traversals < 6:
								await climb_from_below(room, checkpoint)
						check(not service.state.checkpoints.get(checkpoint.definition.id, {}).get("activated", false), "Construction activated checkpoint")
						checkpoint.discover()
						check(not service.state.checkpoints[checkpoint.definition.id].activated, "Discovery activated checkpoint")
					methods[String(request.template_id) if request.method == AbyssRoomConstructionRequest.Method.AUTHORED else "procedural"] = true
					room.free()
					count += 1
					rooms_checked += 1
			check(count == 4, "Not enough checkpoint samples in level %d, seed %s" % [level, seed_value])
	check(methods.has("room_open_checkpoint") and methods.has("procedural"), "Access test missed authored or generated geometry")
	check(traversals == 6, "Missing actual player climb trials")
	print("Short checkpoint access: ", planned_checked, " connected placements, ", rooms_checked, " rooms, ", approaches_checked, " approaches, ", traversals, " actual climbs, templates=", methods.keys(), "; failures=", failures)
	quit(int(failures > 0))
