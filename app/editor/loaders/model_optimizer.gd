class_name ModelOptimizer
extends RefCounted
## Otimiza cópias das malhas estáticas, nunca os recursos de origem.
## O orçamento é um alvo: superfícies que não simplificam são preservadas.

const CACHE_DIR := 'user://model_geometry_v1'
const VERSION := 3

var warnings := PackedStringArray()
var report: Dictionary = {}
var use_disk_cache := true


func optimize(root: Node3D, triangle_budget: int = 100000) -> Dictionary:
	warnings.clear()
	report = {'before': 0, 'after': 0, 'cache_hits': 0, 'skipped': 0}
	var instances: Array[MeshInstance3D] = []
	_collect(root, instances)
	for instance in instances:
		report.before += triangle_count(instance.mesh)
	var ratio := minf(1.0, float(maxi(1, triangle_budget)) / maxf(1.0, report.before))
	# Recursos compartilhados são convertidos uma única vez por objeto.
	var converted: Dictionary = {}
	for instance in instances:
		var source := instance.mesh
		if source == null:
			continue
		if instance.skin != null or not _supported(source):
			report.skipped += 1
			continue
		if not converted.has(source):
			converted[source] = _optimize_mesh(source as ArrayMesh, ratio)
		instance.mesh = converted[source]
	for instance in instances:
		report.after += triangle_count(instance.mesh)
	if report.skipped > 0:
		warnings.append('%d malha(s) preservada(s): skin, blend shapes ou formato não suportado.' % report.skipped)
	if report.after > triangle_budget:
		warnings.append('O modelo ficou com %d triângulos; o alvo de %d não pôde ser atingido com segurança.' % [report.after, triangle_budget])
	return report


static func triangle_count(mesh: Mesh) -> int:
	var count := 0
	if mesh == null:
		return count
	if not mesh is ArrayMesh:
		return int(mesh.get_faces().size() / 3.0)
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
			var indices: int = mesh.surface_get_array_index_len(surface)
			count += int((indices if indices > 0 else mesh.surface_get_array_len(surface)) / 3.0)
	return count


func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


func _supported(mesh: Mesh) -> bool:
	if not mesh is ArrayMesh or mesh.get_blend_shape_count() > 0 or mesh.get_surface_count() == 0:
		return false
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var format: int = mesh.surface_get_format(surface)
		if format & (Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS | Mesh.ARRAY_FLAG_USE_2D_VERTICES):
			return false
	return true


func _optimize_mesh(source: ArrayMesh, ratio: float) -> ArrayMesh:
	var surfaces: Array = []
	var targets: Array[int] = []
	var formats: Array[int] = []
	for surface in source.get_surface_count():
		surfaces.append(source.surface_get_arrays(surface))
		formats.append(source.surface_get_format(surface))
		var size := source.surface_get_array_index_len(surface)
		if size == 0:
			size = source.surface_get_array_len(surface)
		targets.append(maxi(1, int(size / 3.0 * ratio)))
	# Materiais ficam fora do cache: mudanças de textura/material são aplicadas
	# imediatamente, inclusive quando a geometria não mudou.
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes([VERSION, Engine.get_version_info().string, surfaces, formats, targets]))
	var cache_path := CACHE_DIR.path_join(digest.finish().hex_encode() + '.res')
	var result: ArrayMesh
	if use_disk_cache and FileAccess.file_exists(cache_path):
		result = ResourceLoader.load(cache_path, '', ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if result != null and result.get_surface_count() == source.get_surface_count():
			report.cache_hits += 1
		else:
			result = null
	if result == null:
		var importer := ImporterMesh.new()
		for surface in surfaces.size():
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, surfaces[surface], [], {}, null, '', _custom_flags(formats[surface]))
		importer.generate_lods(60.0, 0.0, [])
		result = ArrayMesh.new()
		for surface in surfaces.size():
			var arrays: Array = importer.get_surface_arrays(surface)
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			var base_size: int = indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
			# Promove um LOD a malha principal: reduz também o custo de perto.
			for level in importer.get_surface_lod_count(surface):
				var candidate := importer.get_surface_lod_indices(surface, level)
				if candidate.size() > 0 and candidate.size() < base_size and base_size / 3.0 > targets[surface]:
					indices = candidate
					base_size = candidate.size()
			arrays[Mesh.ARRAY_INDEX] = indices if not indices.is_empty() else null
			var lods: Dictionary = {}
			for level in importer.get_surface_lod_count(surface):
				var candidate := importer.get_surface_lod_indices(surface, level)
				if candidate.size() > 0 and candidate.size() < base_size:
					lods[importer.get_surface_lod_size(surface, level)] = candidate
			_compact(arrays, lods)
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods, _custom_flags(formats[surface]))
		if result.get_surface_count() != source.get_surface_count():
			warnings.append('Falha na conversão da geometria; mantendo a malha original.')
			return source
		if use_disk_cache:
			var directory_error := DirAccess.make_dir_recursive_absolute(CACHE_DIR)
			if directory_error == OK:
				var save_error := ResourceSaver.save(result, cache_path)
				if save_error != OK:
					warnings.append('Não foi possível salvar o cache: %s' % error_string(save_error))
			else:
				warnings.append('Não foi possível criar a pasta de cache: %s' % error_string(directory_error))
	# Mantém limites e nomes originais; overrides por superfície continuam válidos.
	result.custom_aabb = source.get_aabb()
	for surface in source.get_surface_count():
		result.surface_set_name(surface, source.surface_get_name(surface))
		result.surface_set_material(surface, source.surface_get_material(surface))
	return result


## Remove vértices não referenciados pela malha principal nem pelos LODs.
func _compact(arrays: Array, lods: Dictionary) -> void:
	if arrays[Mesh.ARRAY_INDEX] == null:
		return
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		return
	var vertex_remap: Dictionary = {}
	var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var old_vertices: Array[int] = []
	var buffers: Array = [indices]
	for key in lods:
		buffers.append(lods[key])
	for buffer in buffers:
		for index in buffer:
			if not vertex_remap.has(index):
				vertex_remap[index] = old_vertices.size()
				old_vertices.append(index)
	for channel in Mesh.ARRAY_INDEX:
		if arrays[channel] == null or arrays[channel].is_empty():
			continue
		var original: Variant = arrays[channel]
		var compacted: Variant = original.duplicate()
		var stride: int = int(original.size() / float(vertex_count))
		compacted.resize(old_vertices.size() * stride)
		for vertex in old_vertices.size():
			for component in stride:
				compacted[vertex * stride + component] = original[old_vertices[vertex] * stride + component]
		arrays[channel] = compacted
	for index in indices.size():
		indices[index] = vertex_remap[indices[index]]
	arrays[Mesh.ARRAY_INDEX] = indices
	for key in lods:
		var buffer: PackedInt32Array = lods[key]
		for index in buffer.size():
			buffer[index] = vertex_remap[buffer[index]]
		lods[key] = buffer


func _custom_flags(format: int) -> int:
	var flags := 0
	for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:
		flags |= format & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift)
	return flags
