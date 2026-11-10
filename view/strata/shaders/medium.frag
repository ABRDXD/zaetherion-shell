#version 440
// The Medium as seen: the smoke lit by its own relief and glowing where it is hot, and the dust as points of light. Every colour is the theme's.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;
    float aspect;
    float time;
    float sky;          // 1: paint the deep sky behind it, 0: only the smoke, on nothing
    float gain;
    vec2 light;         // where the light comes from, uv
    vec4 accent;
    vec4 second;
    vec4 hot;
    vec4 deep;
};
layout(binding = 1) uniform sampler2D dye;
layout(binding = 2) uniform sampler2D dust;
layout(binding = 3) uniform sampler2D gas;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 d = texture(dye, uv);
    vec2 e = texel * 2.0;
    vec4 dl = texture(dye, uv - vec2(e.x, 0.0)), dr = texture(dye, uv + vec2(e.x, 0.0));
    vec4 db = texture(dye, uv - vec2(0.0, e.y)), dt = texture(dye, uv + vec2(0.0, e.y));
    float thickness = d.r + d.b + 0.4 * d.g;
    vec2 slope = vec2(dr.r + dr.b - dl.r - dl.b, dt.r + dt.b - db.r - db.b);
    vec2 toLight = normalize((light - uv) * vec2(aspect, 1.0) + 1e-5);
    float relief = dot(slope, toLight);

    float density = 1.0 - exp(-max(0.0, thickness - 0.05) * 1.7);
    float mixB = clamp(d.b / max(1e-4, d.r + d.b), 0.0, 1.0);
    vec3 body = mix(accent.rgb, second.rgb, mixB);
    vec3 soot = mix(body, deep.rgb, 0.55 * d.a);
    vec3 lit = soot * (0.46 + clamp(relief * 1.1, -0.34, 0.9));
    // Fire: through the theme's accent to its text colour, then white.
    float heat = clamp(d.g, 0.0, 2.0);
    vec3 flame = heat < 0.6 ? mix(vec3(0.0), body * 1.4, heat / 0.6) : mix(body * 1.4, mix(hot.rgb, vec3(1.0), 0.4), clamp((heat - 0.6) / 0.9, 0.0, 1.0));
    float flow = length(texture(gas, uv).xy);
    vec3 smoke = lit * density + flame * (0.55 + 0.45 * density) + body * density * clamp(flow * 0.12, 0.0, 0.35);

    // The dust: a soft point at each grain's true place, from this cell and its neighbours.
    float grains = 0.0;
    vec2 here = fract(uv / texel) - 0.5;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 cell = vec2(float(i), float(j));
            vec4 n = texture(dust, uv + cell * texel);
            if (n.z > 0.003) {
                vec2 q = cell + n.xy - here;
                grains += n.z * exp(-dot(q, q) * 2.6);
            }
        }
    }
    vec3 dustLight = mix(body, hot.rgb, 0.45 + 0.45 * clamp(heat + density, 0.0, 1.0)) * grains * (0.1 + 1.5 * density * density);

    vec3 colour = (smoke + dustLight) * gain;
    float alpha = clamp(max(max(colour.r, colour.g), colour.b) * 1.1 + density * 0.55, 0.0, 1.0);
    if (sky > 0.5) {
        colour += deep.rgb * (1.0 - density);
        alpha = 1.0;
    }
    colour = colour / (1.0 + 0.32 * colour);
    fragColor = vec4(colour, alpha) * qt_Opacity;
}
