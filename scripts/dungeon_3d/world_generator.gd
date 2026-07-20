class_name WorldGenerator
extends Node3D

# =============================================================================
# Generates blocky 3D geometry from ASCII map data.
# Grid X = world X (east-west), Grid Y = world Z (north-south), Height = world Y.
# =============================================================================

const WALL_HEIGHT: float = 2.0
const TILE_SIZE: float = 1.0

var _map_data: Array = []
var _height_data: Array = []
var _wall_material: Material

func _init(mat: Material = null):
	_wall_material = mat

func build_from_map(map_data: Array, height_data: Array):
	_clear()
	_map_data = map_data; _height_data = height_data
	if _map_data.is_empty(): return
	
	_build_floor()
	_build_walls()
	_build_ceiling()

func _clear():
	for c in get_children():
		c.queue_free()

func _build_floor():
	var h: int = _map_data.size()
	var w: int = _map_data[0].size()
	
	var body := StaticBody3D.new()
	body.name = "FloorCollision"
	add_child(body)
	body.owner = self
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(w) + 2.0, 0.1, float(h) + 2.0)
	col.shape = shape
	col.position = Vector3(float(w) * 0.5, -0.05, float(h) * 0.5)
	body.add_child(col)
	col.owner = body
	
	var plane := MeshInstance3D.new()
	plane.name = "FloorMesh"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(w, h)
	plane.mesh = mesh
	plane.position = Vector3(float(w) * 0.5, 0.0, float(h) * 0.5)
	plane.rotation_degrees = Vector3(90, 0, 0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.17)
	mat.roughness = 1.0
	plane.material_override = mat
	
	add_child(plane)
	plane.owner = self

func _build_ceiling():
	var h: int = _map_data.size()
	var w: int = _map_data[0].size()
	
	var plane := MeshInstance3D.new()
	plane.name = "Ceiling"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(w, h)
	plane.mesh = mesh
	plane.position = Vector3(float(w) * 0.5, WALL_HEIGHT, float(h) * 0.5)
	plane.rotation_degrees = Vector3(-90, 0, 0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.1)
	mat.roughness = 1.0
	plane.material_override = mat
	
	add_child(plane)
	plane.owner = self

func _build_walls():
	var h: int = _map_data.size()
	var w: int = _map_data[0].size()
	
	if not _wall_material:
		_wall_material = StandardMaterial3D.new()
		_wall_material.albedo_color = Color(0.35, 0.35, 0.4)
		_wall_material.roughness = 1.0
	
	var merged_cells: Array[bool] = []
	merged_cells.resize(h * w)
	merged_cells.fill(false)
	
	for z in h:
		for x in w:
			if merged_cells[z * w + x]: continue
			var tile: int = _map_data[z][x] as int
			if tile != 1 and tile != 6: continue  # TILE_WALL(1) or TILE_BLOCKED(6)
			
			var run_w: int = 1
			while x + run_w < w and _map_data[z][x + run_w] in [1, 6] and not merged_cells[z * w + x + run_w]:
				run_w += 1
			
			var volume := _create_wall_block(x, z, run_w, 1)
			volume.name = "Wall_%d_%d_%d" % [x, z, run_w]
			add_child(volume)
			volume.owner = self
			
			for dx in run_w:
				merged_cells[z * w + x + dx] = true

func _create_wall_block(gx: int, gz: int, gw: int, gh: int) -> Node3D:
	var body := StaticBody3D.new()
	
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(float(gw) * TILE_SIZE, WALL_HEIGHT, float(gh) * TILE_SIZE)
	mesh.mesh = box
	mesh.position = Vector3(float(gx) + float(gw) * 0.5, WALL_HEIGHT * 0.5, float(gz) + float(gh) * 0.5)
	mesh.material_override = _wall_material
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	col.position = mesh.position
	
	body.add_child(mesh)
	mesh.owner = body
	body.add_child(col)
	col.owner = body
	
	return body
