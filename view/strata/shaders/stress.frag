#version 440
// The wallpaper under load (view/strata/StressField.qml, OVERDRIVE_IDEAS #52, the T3 tier): the panel's four corners press
// on the desktop like a part in a polariscope, and fringes of equal stress spread out from them across the wallpaper,
// thinning with distance and stopping where the panel stands. It is drawn only when something changes (a room switch
// turns the fringes), so at rest it costs nothing. The panel's rect is in pixels.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 panel;
    // Which room (turns the fringes), the engine, and how strong the fringes are.
    float turn;
    float alive;
    float strength;
    vec4 lineColor;
    vec4 glowColor;
};

float load(vec2 p, vec2 at, float k) {
    vec2 d = p - at;
    // Shear the distance to the house's 78°, so the fringes lean with everything else.
    d.x += d.y * 0.2126;
    return k / (1.0 + length(d) / 140.0);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 near = clamp(p, panel.xy, panel.xy + panel.zw);
    float away = length(p - near);
    float s = load(p, panel.xy, 1.0) + load(p, panel.xy + vec2(panel.z, 0.0), 0.8)
            + load(p, panel.xy + vec2(0.0, panel.w), 0.9) + load(p, panel.xy + panel.zw, 1.1);
    float phase = s * 16.0 + turn * 0.7;
    float w = fwidth(phase);
    float d = abs(fract(phase) - 0.5);
    float fringe = 1.0 - smoothstep(0.0, max(0.09, w * 1.2), d);
    float fade = smoothstep(0.0, 24.0, away) * (1.0 - smoothstep(180.0, 760.0, away));
    float alpha = clamp(fringe * fade * strength * alive * lineColor.a, 0.0, 1.0);
    vec3 c = mix(lineColor.rgb, glowColor.rgb, clamp(s * 0.28, 0.0, 1.0));
    fragColor = vec4(c * alpha, alpha) * qt_Opacity;
}
