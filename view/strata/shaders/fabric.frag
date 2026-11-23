#version 440
// The spacetime fabric's lines: a fine grid and every fourth line stronger, antialiased in screen space,
// thinned out when zoomed far out, deeper where the masses press it, faded out at its edges.
layout(location = 0) in vec2 plane;
layout(location = 1) in float glow;
layout(location = 2) in float sink;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The plane: Home's point on screen, the tilt, the house shear, the fabric's half-size, how far
    // under the orbit's plane it lies, and the grid's spacing (all in scene pixels).
    float cx;
    float cy;
    float sinE;
    float cosE;
    float shear;
    float extent;
    float drop;
    float spacing;
    vec4 lineColor;
    vec4 glowColor;
    // A ripple: its centre on the plane, the wavefront's radius, its height.
    vec4 ripple;
    // Overdrive's life: x the breathing phase (0..1), y the engine (0 in Silent), z the bass (0..1).
    vec4 life;
    // Wells: x, y on the plane (Home at 0, 0), depth, radius.
    vec4 w0;
    vec4 w1;
    vec4 w2;
    vec4 w3;
    vec4 w4;
    vec4 w5;
    vec4 w6;
    vec4 w7;
    vec4 w8;
    vec4 w9;
    vec4 w10;
    vec4 w11;
    vec4 w12;
    vec4 w13;
    vec4 w14;
    vec4 w15;
    vec4 w16;
    vec4 w17;
};

float grid(vec2 g) {
    vec2 fw = max(fwidth(g), vec2(0.0001));
    vec2 a = abs(fract(g - 0.5) - 0.5) / fw;
    float line = 1.0 - min(min(a.x, a.y), 1.0);
    // Too dense to read (far out): let it go.
    return line * (1.0 - smoothstep(0.2, 0.5, max(fw.x, fw.y)));
}

void main() {
    vec2 g = plane / spacing;
    float minor = grid(g), major = grid(g / 4.0);
    // Deeper is brighter and leans to the signal colour: the wells read as wells.
    float deep = clamp(sink / (spacing * 2.5), 0.0, 1.0);
    float line = max(minor * (0.28 + 0.5 * deep), major * (0.6 + 0.4 * deep));
    // Fades out well inside the mesh's edge, and a little everywhere far from the masses.
    float fade = 1.0 - smoothstep(extent * 0.25, extent * 0.62, length(plane * vec2(1.0, 1.2)));
    float ripple = clamp(glow, 0.0, 1.0);
    vec3 c = mix(lineColor.rgb, glowColor.rgb, clamp(deep * 0.45 + ripple, 0.0, 1.0));
    // Strongest near the masses, faint out in the open: the field, not graph paper.
    float near = clamp(sink / (spacing * 1.2), 0.0, 1.0);
    float alpha = line * fade * (lineColor.a * (0.4 + 1.4 * near) + 0.5 * ripple);
    fragColor = vec4(c, 1.0) * clamp(alpha, 0.0, 1.0) * qt_Opacity;
}
