class_name MapMeta
extends Resource

## Sidecar metadata for an ASCII map — per-cell texture overrides + decals.
## Serializes to .meta.json alongside the .txt map.

var version: int = 1

## Key: "x,y" string, value: Dictionary { "texture": String, "rotation": int, "decals": Array }
var cells: Dictionary = {}

func set_texture(x: int, y: int, texture_id: String, rotation: int = 0):
	var key := "%d,%d" % [x, y]
	if not cells.has(key): cells[key] = {}
	cells[key]["texture"] = texture_id
	cells[key]["rotation"] = rotation

func get_texture(x: int, y: int) -> String:
	var key := "%d,%d" % [x, y]
	if cells.has(key): return cells[key].get("texture", "")
	return ""

func get_rotation(x: int, y: int) -> int:
	var key := "%d,%d" % [x, y]
	if cells.has(key): return cells[key].get("rotation", 0)
	return 0

func add_decal(x: int, y: int, side: int, decal_id: String, offset: float = 0.5, rot: int = 0):
	var key := "%d,%d" % [x, y]
	if not cells.has(key): cells[key] = {}
	var decals: Array = cells[key].get("decals", [])
	decals.append({"side": side, "id": decal_id, "offset": offset, "rotation": rot, "z": decals.size(), "scale": 1.0})
	cells[key]["decals"] = decals

func remove_decal(x: int, y: int, index: int):
	var key := "%d,%d" % [x, y]
	if not cells.has(key): return
	var decals: Array = cells[key].get("decals", [])
	if index < 0 or index >= decals.size(): return
	decals.remove_at(index)
	cells[key]["decals"] = decals

func get_decals(x: int, y: int) -> Array:
	var key := "%d,%d" % [x, y]
	if cells.has(key): return cells[key].get("decals", [])
	return []

func has_any(x: int, y: int) -> bool:
	return cells.has("%d,%d" % [x, y])

func clear_cell(x: int, y: int):
	cells.erase("%d,%d" % [x, y])

func save_to_json(path: String):
	var data := {"version": version, "cells": {}}
	for key in cells:
		data["cells"][key] = cells[key]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))

func load_from_json(path: String):
	if not FileAccess.file_exists(path): return
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary: return
	version = data.get("version", 1)
	cells = data.get("cells", {})
