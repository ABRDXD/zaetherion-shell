#version 440
// The Medium's dust (view/strata/Medium.qml): one possible grain per texel, about a million at the panel's size. xy is the grain's offset from its cell's centre, z its brightness,
// w the moment it was born. Each step every cell looks at itself and its eight neighbours for the grain the flow carries in, the brightest winning: particles moved entirely by a
// fragment shader, so the count costs no vertices and no CPU.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;
    float gasScale;     // dust cells per gas cell
    float dt;
    float time;
    float birth;        // chance per empty cell per step
    vec4 well;          // the hole: x, y, its horizon's radius
    float aspect;
};
layout(binding = 1) uniform sampler2D gas;
layout(binding = 2) uniform sampler2D dust;

float random(vec2 p, float salt) {
    vec3 q = fract(vec3(p.xyx) * 0.1031 + salt);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 kept = vec4(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 cell = vec2(float(i), float(j));
            vec4 n = texture(dust, uv + cell * texel);
            if (n.z <= 0.003)
                continue;
            vec2 at = cell + n.xy;
            vec2 v = texture(gas, uv + at * texel).xy * gasScale * dt;
            float s = length(v);
            if (s > 0.92)
                v *= 0.92 / s;
            vec2 next = at + v;
            if (abs(next.x) <= 0.5 && abs(next.y) <= 0.5 && n.z > kept.z)
                kept = vec4(next, n.z * (1.0 - 0.0012 * dt), n.w);
        }
    }
    if (kept.z <= 0.003 && random(uv / texel, fract(time * 0.618)) < birth * dt) {
        float a = random(uv / texel + 3.1, fract(time * 0.377));
        kept = vec4(random(uv / texel + 7.7, a) - 0.5, random(uv / texel + 1.3, a) - 0.5, 0.05 + 0.95 * a * a * a * a * a * a, time);
    }
    if (well.z > 0.0 && length((uv - well.xy) * vec2(aspect, 1.0)) < well.z * 1.08)
        kept = vec4(0.0);
    fragColor = kept;
}
