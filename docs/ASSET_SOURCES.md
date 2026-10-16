# Asset Sources And Licenses

Checked 2026-10-16. Budget: EUR 0. No accounts, paid services, project uploads,
system-wide installations, publication or purchases were used. The downloaded
source assets remain alongside their local derivatives. Both providers identify
the selected assets as CC0 1.0: commercial use, modification and distribution
inside a game or with its source are permitted; attribution is optional.
These are provider license declarations, not an independent legal warranty.

## Wheelchair 01

- Author: Garreth Dean, distributed by Poly Haven.
- Asset: https://polyhaven.com/a/wheelchair_01
- License evidence: https://polyhaven.com/license
- File manifest: https://api.polyhaven.com/files/wheelchair_01
- Local notice: [LICENSE.txt](../assets/wheelchair/LICENSE.txt).
- Local source: [wheelchair_01.gltf](../assets/wheelchair/wheelchair_01.gltf),
  [wheelchair_01.bin](../assets/wheelchair/wheelchair_01.bin), three JPG textures
  in [assets/wheelchair/textures](../assets/wheelchair/textures).
- Selected 1K glTF with Base Color, OpenGL Normal and packed AO/Roughness/Metallic.
  Actual source: 29,445 vertices, 40,252 triangles, one material, approximately
  0.824 x 1.104 x 1.091 metres, forward +Z.

Direct download URLs:

```text
https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/wheelchair_01/wheelchair_01_1k.gltf
https://dl.polyhaven.org/file/ph-assets/Models/gltf/4k/wheelchair_01/wheelchair_01.bin
https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wheelchair_01/wheelchair_01_diff_1k.jpg
https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wheelchair_01/wheelchair_01_nor_gl_1k.jpg
https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wheelchair_01/wheelchair_01_arm_1k.jpg
```

The BIN and three texture MD5 values matched the official manifest when
downloaded. Local source SHA-256 fingerprints:

| File | SHA-256 |
| --- | --- |
| glTF | `6A59D638CEB35E46FE543F4B8B5E94B00FE2C6F15045C1D3CD7D9F46DE34F645` |
| BIN | `66C7C1779171228F1A4691EC572A0346A258F65A88CA71ECC72B81B3BC765996` |
| Diffuse | `15BE1E2A5BD86A4C20F99157E8337016F873D4E4F2D3EFFC656729430214AC00` |
| Normal | `534469BF7BB00549FB383F533B7FCC0A7B4256FE59F42EC7495D1F121700F392` |
| ARM | `29F5B9AAB6D63CA1A218F8E34D03A78E9C92E8D643A8728978882223139C9192` |

The preparation tool separates connected geometry into frame, two rear wheels,
two casters and two forks, retaining every source triangle, UV, normal and
tangent. It generates LODs for these rigid parts. Rear axle centres are at
native Y=0.3431, Z=-0.1484; caster axles Y=0.1095, Z=0.5069; fork steering
axes Y=0.22, Z=0.465. Forks steer without rolling. The model is rotated 180
degrees around Y and scaled 1.4 to fit the existing arcade vehicle envelope.
This is not a certified real-world wheelchair dimension or physics simulation.

Local derivative: [chair_prepared.scn](../assets/wheelchair/chair_prepared.scn).
Metallic multiplier 0.75, normal strength 0.7, roughness texture green channel
clamped to at least 0.42. Additional footplates/supports are local GDScript
geometry. Original engine models remain unchanged under the existing mount.

## Casual Man, Rigged

- Provider/credit: Grab3D. No individual human artist is named in the package.
- Asset: https://grab3d.com/models/characters/man/
- Download: https://grab3d.com/dl/man-rigged/man-rigged.glb
- Manifest: https://grab3d.com/dl/man-rigged/manifest.json
- License file: https://grab3d.com/dl/man/LICENSE.txt
- Local unmodified evidence: [LICENSE.txt](../assets/rider/LICENSE.txt) and
  [source-manifest.json](../assets/rider/source-manifest.json).
- Local source: [man-rigged.glb](../assets/rider/man-rigged.glb), 13,051,272 bytes.
- Source SHA-256: `C41F2BFC62B03A8DD8FBAE37D201D4C73BBA3806678984C6895F59A7CBF22C4F`.

**AI-assisted origin:** the provider declares a Meshy-generated base mesh and
textures, Blender cleanup, automatic Meshy skinning/walk/run and Blender-added
finger bones. This is not a wholly hand-authored or scanned human. Retain this
disclosure when distributing; platforms such as Steam may require an AI-content
declaration. No project data was uploaded to Meshy or Grab3D during this work.

Actual imported rigged variant: 167,662 vertices, 244,257 triangles, 54 bones,
one material, three embedded 2048 x 2048 PBR textures; Godot also extracts these
as adjacent JPGs on import. Do not confuse this with the website's 498K/4K static
variant. Standing source height is approximately 1.8 m; runtime scale is 1.4
to match the enlarged chair. Imported walk/run clips are disabled.

Local derivative: [rider_mesh.res](../assets/rider/rider_mesh.res). Source vertex,
index and skin arrays are preserved. Metallic=0, specular=0.25, normal strength
0.65. A hue-mask recolours olive/yellow-green texture regions to a warm brown
without replacing fabric detail; this also warms the shoe soles. Source GLB and
extracted JPGs remain unchanged. No skin shader, hair simulation or cloth solver.

A 61,063-triangle derivative with generated LODs was tested but rejected after
actual renders showed clothing cracks. The final rider has **no generated mesh
LODs** and retains the complete topology. This is a remaining optimisation task,
not a low-poly/crowd-ready result. Source and prepared resources coexist, so the
rendered triangle budget does not describe total memory use or exported size.

Seat, ankle and wrist markers drive a two-segment skeleton pose. Disable idle
with `idle_enabled=false` on the Presentation node. Stock acceleration uses a
simple wheel-phase push gesture; motorised driving uses supported hands and
does not force manual pushing. This is authored animation, not biomechanics.

## Selection Rationale

The first suitable wheelchair was accepted: complete frame, wheels, spokes,
brakes, upholstery and clear CC0 provenance. No alternative chair was imported.
Three human candidates were considered:

1. [CesiumMan](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CesiumMan):
   CC BY 4.0 sample, rejected for visible Cesium branding and unsuitable outfit.
2. [Innerscene human base / MakeHuman-MPFB](https://www.innerscene.com/tools/library/3d-parts/human-base-mesh-with-editable-53-bone-rig-8e7c8ab1):
   CC0 candidate, rejected because clothing would require additional production.
3. Grab3D Casual Man: clothed, rigged, directly downloadable with local license
   evidence. Selected despite stylised proportions and disclosed AI origin.

No rejected candidate is bundled. The result is more anatomically detailed than
the original primitives, but remains stylised rather than photorealistic. The
old helmet/goggles are not part of the selected character.

## Rebuild Locally

After importing the source assets with Godot 4.7.2:

```powershell
& $godot --headless --path . --editor --import
& $godot --headless --path . --script res://tools/prepare_presentation.gd
& $godot --headless --path . --fixed-fps 60 --script res://tests/upgrade_test.gd
```

Prepared resources are included; normal project startup does not require the
preparation tool, network access, Blender or an additional plugin. Runtime
assembly is in [racer_visuals.gd](../scripts/racer_visuals.gd), shared by workshop
and race through the same player node. No external model is used as a collider.