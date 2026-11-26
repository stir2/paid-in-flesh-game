extends SceneTree
## Focused logical-route check; no player tuning or authored scenes are changed.
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var region := AbyssRegionConfig.new()
	for seed_value in [12, 5482856939356729]:
		region.global_seed = seed_value
		for limit in [1, 2, 3]:
			var settings := AbyssRouteConfig.new()
			settings.max_consecutive_fall_rooms = limit
			var generator := AbyssRouteGenerator.new(region, settings)
			var reverse := AbyssRouteGenerator.new(region, settings)
			var coords: Array[Vector2i] = []
			for y in range(-1, 2):
				for x in range(-1, 2): coords.append(Vector2i(x,y))
			var vertical: Dictionary = {}
			for chunk in coords:
				var layout := generator.debug_layout(chunk)
				check(generator.validate_chunk_layout(chunk), "Disconnected limited route")
				for edge: Array in layout.edges.values():
					if edge[0].x == edge[1].x:
						var upper: Vector2i = edge[0] if edge[0].y < edge[1].y else edge[1]
						vertical[upper] = true
			coords.reverse()
			for chunk in coords:
				check(generator.debug_layout(chunk).edges == reverse.debug_layout(chunk).edges, "Generation order changed limited routes")
			var longest := 0
			for upper: Vector2i in vertical:
				var steps := 0
				while vertical.has(upper+Vector2i(0,steps)): steps += 1
				longest = maxi(longest,steps)
			check(longest <= limit+1, "Combined routes exceeded fall-room limit across a chunk boundary")
			var fallback := generator._fallback_path(Rect2i(0,0,8,8),Vector2i.ZERO,Vector2i(0,7))
			var run := 0
			for i in range(1,fallback.size()):
				run = run+1 if fallback[i].x == fallback[i-1].x else 0
				check(run <= limit+1, "Fallback bypassed the fall limit")
	var legacy := AbyssRouteConfig.new()
	legacy.max_consecutive_fall_rooms = 0
	var configs: Array[Resource] = [region,legacy,AbyssTerrainConfig.new(),AbyssProgressionConfig.new()]
	var saved := AbyssRuntimeWorldSettings.capture(configs,load("res://Scenes/Underground/Rooms/authored_registry.tres"))
	saved["1"].erase("max_consecutive_fall_rooms")
	var restored: Array[Resource] = [region.duplicate(),AbyssRouteConfig.new(),AbyssTerrainConfig.new(),AbyssProgressionConfig.new()]
	check(AbyssRuntimeWorldSettings.restore_configuration(saved,restored).error.is_empty(), "Old save cannot restore")
	check(restored[1].max_consecutive_fall_rooms == 0, "Old save routing was silently changed")
	print("Fall route limit: ",checks," checks; failures=",failures)
	quit(1 if failures else 0)
