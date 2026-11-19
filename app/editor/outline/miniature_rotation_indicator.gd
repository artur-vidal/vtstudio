class_name MiniatureRotationIndicator
extends Node3D
## Disco no plano XZ: setor relativo à entrada no modo R e direção atual.

const SEGMENTS := 96
var _mesh := ImmediateMesh.new()
var _visual: MeshInstance3D
var _disc_material: StandardMaterial3D
var _sector_material: StandardMaterial3D
var _line_material: StandardMaterial3D
var _last_start := INF
var _last_angle := INF
var _last_radius := INF


func _ready() -> void:
	top_level = true
	global_basis = Basis.IDENTITY
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	_disc_material = _material(OutlineStyle.DRAG_COLOR, 0.18)
	_sector_material = _material(OutlineStyle.DRAG_COLOR.lightened(0.55), 0.48)
	_line_material = _material(OutlineStyle.DRAG_COLOR.lightened(0.65), 0.95)
	_disc_material.render_priority = 80
	_sector_material.render_priority = 81
	_line_material.render_priority = 82


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Indicador de edição: continua legível se a base estiver ligeiramente
	# enterrada no piso do mapa, sem precisar alterar a altura da miniatura.
	material.no_depth_test = true
	material.albedo_color = Color(color, alpha)
	return material


func show_angle(base: Vector3, start: float, angle: float, radius: float) -> void:
	global_position = base + Vector3.UP * 0.025
	if is_equal_approx(start, _last_start) and is_equal_approx(angle, _last_angle) and is_equal_approx(radius, _last_radius):
		return
	_last_start = start
	_last_angle = angle
	_last_radius = radius
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _disc_material)
	_fan(0.0, TAU, radius, 0.0)
	_mesh.surface_end()
	var sweep := fmod(angle - start, TAU)
	if absf(sweep) > 0.0001:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _sector_material)
		_fan(start, sweep, radius, 0.003)
		_mesh.surface_end()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _line_material)
	var thickness := maxf(0.015, radius * 0.012)
	for index in SEGMENTS:
		var a := TAU * index / SEGMENTS
		var b := TAU * (index + 1) / SEGMENTS
		var p := _point(a, radius, 0.006)
		var q := _point(b, radius, 0.006)
		var inner_p := _point(a, radius - thickness, 0.006)
		var inner_q := _point(b, radius - thickness, 0.006)
		_triangle(p, q, inner_p)
		_triangle(q, inner_q, inner_p)
	var direction := _point(angle, radius, 0.009)
	var side := Vector3(cos(angle), 0.0, -sin(angle)) * thickness * 0.65
	var center := Vector3(0.0, 0.009, 0.0)
	_triangle(center - side, center + side, direction + side)
	_triangle(center - side, direction + side, direction - side)
	_mesh.surface_end()


func _fan(start: float, sweep: float, radius: float, height: float) -> void:
	var steps := maxi(1, int(ceil(absf(sweep) / TAU * SEGMENTS)))
	for index in steps:
		_triangle(Vector3(0.0, height, 0.0), _point(start + sweep * index / steps, radius, height), _point(start + sweep * (index + 1) / steps, radius, height))


func _point(angle: float, radius: float, height: float) -> Vector3:
	return Vector3(-sin(angle) * radius, height, -cos(angle) * radius)


func _triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	_mesh.surface_add_vertex(a)
	_mesh.surface_add_vertex(b)
	_mesh.surface_add_vertex(c)
