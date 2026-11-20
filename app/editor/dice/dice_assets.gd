extends RefCounted
## The six original, low-poly meshes from dice_set.glb, normalized independently.
## Atlas values are mapped by face normal (never by importer-dependent vertex order).
## d10's printed zero means ten; d4 reads the common numeral at the upper apex.

const SOURCE := "res://editor/example_assets/dice_set.glb"
const SOURCE_SCENE := preload("res://editor/example_assets/dice_set.glb")
const FACE_MAP := preload("res://editor/dice/dice_face_map.gd")
const TYPES := [4, 6, 8, 10, 12, 20]
# Verified against rendered atlas contact sheets, not just vector alignment.
# These islands contain a glyph rotated 180 degrees relative to their UV axes.
const INVERTED_GLYPHS := {6: [2, 5, 6], 8: [1, 2, 3, 5, 6, 7], 10: [2, 5, 6, 9], 12: [2, 5], 20: [2, 3, 5, 20]}
static var _cache: Dictionary = {}

static func get_die(sides: int) -> Dictionary:
	if not sides in TYPES:
		return {}
	if _cache.is_empty():
		_build_cache()
	return _cache.get(sides, {})

static func _build_cache() -> void:
	var scene := SOURCE_SCENE.instantiate()
	var mappings: Dictionary = FACE_MAP.DATA
	for sides: int in TYPES:
		var source := scene.find_child("d%d_dice_0" % sides, true, false) as MeshInstance3D
		if source == null:
			push_error("Missing d%d mesh" % sides)
			continue
		var mesh := source.mesh as ArrayMesh
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var center := mesh.get_aabb().get_center()
		# Centroid of a tetrahedron, rather than the asymmetric bounding-box center.
		if sides == 4:
			center = Vector3.ZERO
			for point: Vector3 in vertices:
				center += point
			center /= vertices.size()
		var radius := 0.0
		for point: Vector3 in vertices:
			radius = maxf(radius, point.distance_to(center))
		var factor := 0.82 / radius
		for i in vertices.size():
			vertices[i] = (vertices[i] - center) * factor
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := mesh.surface_get_material(0).duplicate() as BaseMaterial3D
		# Keep the supplied pixel-art atlas crisp on small dice.
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		result.surface_set_material(0, material)
		var shape := ConvexPolygonShape3D.new()
		shape.points = vertices
		var faces: Array = []
		for entry: Dictionary in mappings["d%d" % sides]:
			var normal: Vector3 = entry.normal.normalized()
			var face_center: Vector3 = (entry.center - center) * factor
			var glyph_up: Vector3 = entry.up
			if int(entry.value) in INVERTED_GLYPHS.get(sides, []):
				glyph_up = -glyph_up
			glyph_up = (glyph_up - normal * glyph_up.dot(normal)).normalized()
			faces.append({"value": int(entry.value), "normal": normal, "center": face_center,
				"up": glyph_up})
		_cache[sides] = {"mesh": result, "shape": shape, "faces": faces,
			"read_bottom": sides == 4, "radius": 0.82, "source": SOURCE}
	scene.free()
