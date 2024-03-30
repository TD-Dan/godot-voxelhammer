# VoxelHammer

<img src="https://badgen.net/badge/Godot/v%204.2.1/blue?icon=https://godotengine.org/themes/godotengine/assets/press/icon_monochrome_dark.svg"> <img src="https://badgen.net/badge/license/MIT/blue"> <img src="https://badgen.net/badge/version/v%200.1.1/cyan">

! BARELY USABLE: MULTIPLE COMMITS INCOMING !

Voxel plugin for Godot

Chunky voxels for minecraft style generating and rendering of 3d geometry

## Features:
- [x] Editor integration
- [x] Multithreaded cpu background processing for voxel and geometry data
- [ ] Multithreading prioritites with ~~TaskHammer~~ WorkerThreadPool
- [x] multitexture/material support inside one mesh
- [ ] support for transparent materials
- [ ] configurable voxel and chunk sizes
- [ ] chunk based terrain loader
- [ ] PaintStacks: Geometry generation with photoshop like layers
  - [x] Supported paint operations: noise, gradients, planes. Upcoming: spheres and rectangles

## Performance

Generating and meshing around 1 Million voxels/second on AMD FX-8320


## Examples and Tests:

https://github.com/TD-Dan/godot_voxelhammer-examples
