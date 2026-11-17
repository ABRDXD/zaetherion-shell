# wallgen

Claude B's generated wallpapers (17 November 2026), kept so they can be redrawn or varied. numpy and Pillow only;
fonts are the system's (League Gothic, JetBrains Mono Nerd Font). Claude A's typeset engine is `tools/typeset/`.

- `range.py OUT [aerial|ascii_view|survey]`: one procedural mountain range (`terrain.py`: Perlin ridges, a
  column-marching perspective render) drawn three ways, after the owner's references: `range-fog.png` (fog peaks
  with an Angular HUD that reads the scene), `range-ascii.png` (the view in characters, with Z214's light notch) and
  `range-survey.png` (a contour map). Caches the heightmap as `OUT/hm.npy`.
- `posters.py OUT`: the three `aether-*` type posters (League Gothic sheared −12°, Hematite colours).

NULL's Z214 notch is Claude A's: `tools/typeset/extract.py <face> <layers> --notch` (the face stays untouched).

All geometry keeps the Angular rules (0°, −12°, 78°; one signal accent) and leaves the island's top centre light
(Z214).
