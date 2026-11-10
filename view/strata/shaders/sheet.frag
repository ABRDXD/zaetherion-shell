#version 440
// The room sheet alive (view/strata/SheetField.qml, Overdrive only): two hatch fields, one at the house's 78° and
// one across it at -12°, drift against each other into a slow moiré on the room's sheet, breathing with the
// engine and pulsing with the bass; a soft light follows the pointer. It keeps to the negative space: the
// keep-out mask (the room's own content, drawn small) fades it wherever the room draws a control, a plane or
// text, and it never draws on the title wedge.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    // The phase (0..1), the engine, the bass (0..1), the light's strength (0 with no pointer).
    float phase;
    float alive;
    float bass;
    float light;
    // The pointer, in pixels; the room's content rect (where the mask applies), and the wedge's rect, in pixels.
    vec2 pointer;
    vec4 contentBox;
    vec4 wedge;
    vec4 lineColor;
    vec4 glowColor;
};
layout(binding = 1) uniform sampler2D mask;

float hatch(vec2 p, float angle, float pitch, float shift) {
    vec2 d = vec2(cos(angle), sin(angle));
    float u = dot(p, d) / pitch + shift;
    float w = fwidth(u);
    // Distance to the nearest line's centre, in pitches; lines about a ninth of a pitch wide, antialiased.
    float f = abs(fract(u + 0.5) - 0.5);
    return 1.0 - smoothstep(0.055 - w, 0.055 + w, f);
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    float t = 6.2831853 * phase;
    // 78° lines (their normal at -12°) and -12° lines (their normal at 78°), drifting opposite ways.
    float a = hatch(px, radians(-12.0), 14.0, phase * 3.0);
    float b = hatch(px, radians(78.0), 15.0 + 1.5 * sin(t), -phase * 2.0);
    float moire = a * b;
    // Bands where the two fields beat, swelling with the bass.
    float beatBand = 0.5 + 0.5 * sin(dot(px, vec2(0.012, -0.031)) + t * 2.0);
    float field = (0.22 * (a + b) * 0.5 + 0.55 * moire) * (0.55 + 0.45 * beatBand) * (0.7 + 0.9 * bass);
    float spot = light * exp(-dot(px - pointer, px - pointer) / (2.0 * 140.0 * 140.0));
    // Keep out: the room's content (inside its rect) and the wedge.
    vec2 cuv = (px - contentBox.xy) / max(contentBox.zw, vec2(1.0));
    float inside = step(0.0, cuv.x) * step(cuv.x, 1.0) * step(0.0, cuv.y) * step(cuv.y, 1.0);
    float covered = inside * smoothstep(0.02, 0.25, texture(mask, clamp(cuv, 0.0, 1.0)).a);
    float onWedge = step(wedge.x, px.x) * step(px.x, wedge.x + wedge.z) * step(wedge.y, px.y) * step(px.y, wedge.y + wedge.w);
    float keep = (1.0 - covered) * (1.0 - onWedge);
    float alpha = clamp(field * lineColor.a + spot * 0.18, 0.0, 1.0) * keep * alive;
    vec3 colour = mix(lineColor.rgb, glowColor.rgb, clamp(spot * 1.5 + bass * 0.5, 0.0, 1.0));
    fragColor = vec4(colour * alpha, alpha) * qt_Opacity;
}
