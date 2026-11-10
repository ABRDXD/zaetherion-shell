#version 440
// The Media visualiser (view/strata/SpectrumBand.qml): the spectrum as bars leaning at 78°, rising from a
// hairline, with a faint reflection under it. One quad; the bins arrive as uniforms, so a frame costs the
// CPU only the 14 values it changes.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The band's size in pixels, the share of each slot a bar fills, where the baseline sits (`ground`: 0 top, 1
    // bottom), and the house shear (tan 12°).
    float bandWidth;
    float bandHeight;
    float fill;
    float ground;
    float shear;
    float bins;
    vec4 barColor;
    vec4 lineColor;
    // The spectrum, four bins to a vector (56 bins).
    vec4 s0;
    vec4 s1;
    vec4 s2;
    vec4 s3;
    vec4 s4;
    vec4 s5;
    vec4 s6;
    vec4 s7;
    vec4 s8;
    vec4 s9;
    vec4 s10;
    vec4 s11;
    vec4 s12;
    vec4 s13;
};

float bin(int i) {
    vec4 v = vec4(0.0);
    switch (i / 4) {
        case 0: v = s0; break;
        case 1: v = s1; break;
        case 2: v = s2; break;
        case 3: v = s3; break;
        case 4: v = s4; break;
        case 5: v = s5; break;
        case 6: v = s6; break;
        case 7: v = s7; break;
        case 8: v = s8; break;
        case 9: v = s9; break;
        case 10: v = s10; break;
        case 11: v = s11; break;
        case 12: v = s12; break;
        case 13: v = s13; break;
        default: break;
    }
    int k = i - (i / 4) * 4;
    return clamp(k == 0 ? v.x : k == 1 ? v.y : k == 2 ? v.z : v.w, 0.0, 1.0);
}

void main() {
    vec2 p = qt_TexCoord0 * vec2(bandWidth, bandHeight);
    float base = ground * bandHeight;
    // Unshear: a bar's edges lean right as they rise, as the house's 78° edges do.
    float x = p.x - (base - p.y) * shear;
    float slot = bandWidth / bins;
    float i = floor(x / slot);
    float inSlot = x - i * slot;
    float aa = 1.0;
    float side = smoothstep(0.0, aa, inSlot) * smoothstep(0.0, aa, slot * fill - inSlot);
    float v = (i >= 0.0 && i < bins) ? bin(int(i)) : 0.0;
    float up = base - p.y;
    // The bar above the baseline (at least a sliver, so silence still draws the comb); its reflection under.
    float h = max(1.5, v * base);
    float bar = side * smoothstep(-aa, 0.0, up) * (1.0 - smoothstep(h - aa, h, up));
    float below = -up;
    float mirror = side * smoothstep(0.0, aa, below) * (1.0 - smoothstep(0.0, max(1.0, h * 0.35), below)) * 0.28;
    // The baseline hairline.
    float rule = 1.0 - smoothstep(0.0, 1.0, abs(up));
    vec4 bc = vec4(barColor.rgb * barColor.a, barColor.a);
    vec4 lc = vec4(lineColor.rgb * lineColor.a, lineColor.a);
    vec4 c = bc * max(bar * (0.55 + 0.45 * v), mirror) + lc * rule * 0.8 * (1.0 - bar);
    fragColor = c * qt_Opacity;
}
