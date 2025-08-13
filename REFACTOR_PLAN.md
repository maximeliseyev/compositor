Metal NodeGraph Refactor Plan
=============================

Owner: Metal/NodeGraph
Status: In progress
Tracking: This file will be updated as tasks are completed.

Goals
- Move all NodeGraph rendering to Metal with clean layering and strong performance.
- Adopt a maintainable project layout aligned with Swift and Metal best practices.
- Reduce CPU work, minimize per-frame allocations, and prepare for future features.

High-level Phases
1) Styling and constants centralization
2) Shader modularization and types alignment
3) Pipeline state management and caching
4) Vertex data model and per-frame buffers (instanced rendering)
5) Async/await and command-buffer lifecycle hygiene
6) Dependency injection and API cleanup
7) Project structure and Xcode groups alignment
8) Validation (performance, memory, visual)

---

Phase 1 — Styling and constants (UI/NodeGraph)
- [x] Extract NodeGraphRenderStyle from Views/NodeGraph/MetalNodeGraphCanvas.swift to Views/NodeGraph/Rendering/NodeGraphRenderStyle.swift
- [x] Document all style constants (background, grid, connections, selection, node body, outline)
- [x] Replace magic values in MetalNodeGraphCanvas with constants

Notes/Progress:
- Style struct moved and referenced by canvas. All magic numbers for colors/thickness are centralized.

Phase 2 — Shader modularization
Target layout under Metal/Shaders/:
- UI/
  - [x] UIVertex.metal (ui_vertex)
  - [x] UIPrimitives.metal (ui_fragment, ui_rounded_rect_fragment)
- Compute/
  - [x] Blur.metal (gaussian_blur_compute, box_blur_compute)
  - [x] Edge.metal (edge_detection_compute)
  - [x] Merge.metal (merge_fragment)
- Utils/
  - [x] Color.metal (rgb2hsv, hsv2rgb)
  - [x] Types.metal (BlurParams, ColorCorrectionParams, MergeParams)

Tasks:
- [x] Split Metal/Shaders.metal into files above
- [x] Update build phase and library lookups (function names unchanged)
- [x] Add file-level comments and keep functions grouped by domain

Phase 3 — Pipeline state management
- [ ] Cache UI pipeline(s) once in MetalNodeGraphCanvas.Coordinator (grid/lines)
- [ ] Cache node pipeline for rounded-rects
- [ ] Consider moving shared pipeline cache into MetalRenderer (with a key-based cache)

Acceptance:
- No pipeline recreation inside the per-frame path; profiler shows no repeated state compilation.

Phase 4 — Vertex data and per-frame buffers
- [ ] Build a single dynamic MTLBuffer per frame for grid lines
- [ ] Build a single dynamic MTLBuffer per frame for connections
- [ ] Switch node rendering to instanced rendering (one quad + per-instance data: position, size, radius, colors, flags)
- [ ] Avoid creating multiple small buffers per node per frame

Acceptance:
- No per-node buffer allocations in the draw loop; allocations happen in bulk or via ring buffers.

Phase 5 — Async/await and command-buffer lifecycle
- [ ] Remove synchronous waitUntilCompleted() in all non-UI paths
- [ ] Use completion handlers or async awaiting where appropriate
- [ ] Keep main-thread free of GPU waits

Acceptance:
- No blocking waits on main actor; smooth UI while heavy GPU work runs.

Phase 6 — Dependency injection and API cleanup
- [ ] Pass MetalRenderingManager via Environment / init where needed
- [ ] Keep TextureManager owned by renderer and injected into nodes that need it
- [ ] Define light-weight protocols for rendering/texture services to ease testing

Phase 7 — Project structure and Xcode groups
- [ ] Create Views/NodeGraph/Rendering/ and move canvas + style files there
- [ ] Reorganize Metal/Shaders into UI/Compute/Utils subfolders
- [ ] Ensure Target Membership is correct for all moved files

Phase 8 — Validation
- Performance:
  - [ ] FPS smoke test on typical graphs (small/medium/large)
  - [ ] GPU capture to verify no redundant state changes
- Memory:
  - [ ] Track transient allocations per frame; confirm buffer reuse
- Visual:
  - [ ] Compare grid, nodes, selection against design spec (colors, radii, outline thickness)

---

Live Progress Log
- [x] 2025-08-13: Plan created; Phase 1 completed (style extraction, constants documented)
- [x] 2025-08-13: MetalNodeGraphCanvas renders grid, connections, selection, node body and selection outline on GPU
- [x] 2025-08-13: UI contrast improved (dark gray background, light gray grid)

Risks / Considerations
- Shader split requires updating PBX project; ensure no duplicate functions or missing includes
- Instanced rendering requires careful per-instance layout; keep Swift and Metal structs in sync (alignment!)
- Avoid introducing stalls by reallocating buffers; prefer ring buffers or set*Bytes for very small payloads
- Maintain @MainActor boundaries; capture required values before hopping to background queues

