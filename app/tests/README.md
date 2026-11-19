# Model optimization

Run with Godot 4.7:

```sh
godot --headless --path app --script res://tests/model_optimizer_test.gd
```

The test covers static model reduction, disk cache reuse, material replacement,
shared instances, original resource preservation, bounds, unindexed meshes,
UV/custom-channel/tangent and LOD remapping, skin/blend-shape exclusion, opt-out,
and both local scenes and external-file loading using the example assets.

`ModelObject` optimizes geometry once during setup. `triangle_budget` defaults
to 100,000 across all rendered mesh instances in that object. It is a target,
not a hard limit: some surfaces cannot be simplified enough. Reports expose
`before`, `after`, `cache_hits` and `skipped`; warnings explain exclusions and
unmet budgets. `optimize_geometry = false` keeps the original geometry.
`MiniatureSpawner` exposes equivalent settings for externally loaded models.

The optimizer promotes a generated LOD to the highest-detail mesh and retains
coarser LODs. It compacts unused vertices while preserving surface ordering,
names, normals, tangents, UVs and custom attributes. Normalization uses original
bounds; picking uses the optimized triangle geometry. The original source
resources/files remain untouched.

Geometry is cached under `user://model_geometry_v1` with a SHA-256 key over
geometry contents, surface formats, per-surface targets, optimizer version and
Godot version. Materials and textures are rebound from the current model and
are never cached by this layer. It therefore handles external texture changes
without serving stale materials. Cache write failure does not prevent loading.
Deleting this directory regenerates the cache on subsequent loads.

Limitations: skin/bone data, blend shapes, 2D vertices, non-triangle primitives
and non-ArrayMesh resources are preserved. First-time conversion is synchronous;
disk cache avoids repeating simplification, but reading and hashing geometry
still has a cost. Textures are not resized or compressed by this change, and
double-sided materials remain intact. Simplification is lossy: inspect unfamiliar
models and increase the budget or disable optimization if details are lost.

The external Prisioneira GLB produces existing Godot warnings about differing
UV maps for normal/metallic textures; the runtime GLTF loader cannot represent
those material mappings. Geometry optimization preserves the available channels
but does not repair that importer limitation.

## Picking regression

```sh
godot --headless --path app --script res://tests/model_picking_test.gd
```

Checks actual physics ray queries against two separated meshes: empty space
inside the combined bounds must miss, both meshes must hit from either side,
and space above the surface must miss. Repeats with object translation/rotation
and a nonuniform local scale multiplier. The static concave collision is built
once during setup from the optimized mesh, including all nested transforms.
It represents the initial geometry; skeletal animation and shader deformation
do not update it each frame. Texture transparency is not a geometric hole.
