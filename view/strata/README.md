# strata

Lazy Overdrive effect layers under a control keep-out mask (M8). Each stratum is created by a lease and destroyed on release, never just hidden. Empty in M0.

The first stratum is the orbit's spacetime fabric (`SpaceFabric.qml`, docs/ORBIT.md §0), a grid mesh under the orbit pressed down by every mass. It exists only while the orbit's Loader is active and is destroyed with it. Its tilt, masses and ripple are uniforms, so it costs no CPU per frame; at rest it draws nothing new. Shaders live in `shaders/` as GLSL sources plus the `.qsb` files `tools/make_shaders.py` compiles from them.
