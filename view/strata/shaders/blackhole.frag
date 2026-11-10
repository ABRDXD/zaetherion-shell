#version 440
// A Schwarzschild black hole, traced per pixel (view/strata/BlackHole.qml, on the NVIDIA card through shell-heavy.qml). Each ray is bent by the
// real null-geodesic equation in units of the Schwarzschild radius, a'' = -1.5 h^2 x / r^5, so the far side of the disk shows over the top of
// the shadow and again beneath it. The disk lies in the orbit's own plane, at the orbit's own tilt; its near side is Doppler-brightened.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec2 centre;    // the hole on screen, px
    float radius;   // the shadow's radius, px
    float tilt;     // the camera's elevation over the plane, radians
    float time;     // seconds
    vec4 accent;    // the theme's: the disk's body
    vec4 hot;       // the theme's text colour: the disk's inner edge
    vec4 deep;      // the theme's background: the sky
};
layout(binding = 1) uniform sampler2D sky;     // the Medium as seen, bent by the rays that escape

const int STEPS = 96;
const float SHADOW = 2.598;
const float DISTANCE = 26.0;
const float SHEAR = 0.21256;

float hash(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float streaks(float r, float a) {
    float bands = sin(r * 7.3 + 1.7 * sin(r * 1.9)) * 0.5 + sin(r * 17.0 + a * 2.0) * 0.28 + sin(r * 3.1 - a) * 0.22;
    return 0.62 + 0.38 * bands;
}

vec3 background(vec3 d) {
    vec3 cell = floor(d * 240.0);
    float h = hash(cell);
    float star = smoothstep(0.9968, 1.0, h) * (0.4 + 0.6 * hash(cell + 3.0));
    float haze = 0.5 + 0.5 * sin(d.x * 3.1 + sin(d.y * 4.3 + d.z * 2.1) * 1.7);
    return deep.rgb * (0.55 + 0.45 * haze * haze) + vec3(star);
}

void main() {
    vec2 p = qt_TexCoord0 * size - centre;
    p.x += p.y * SHEAR;     // the panel's verticals lean; the sky leans with them
    float k = (SHADOW / DISTANCE) / max(1.0, radius);
    float s = sin(tilt), c = cos(tilt);
    vec3 eye = DISTANCE * vec3(0.0, s, c);
    vec3 forward = -normalize(eye);
    vec3 right = vec3(1.0, 0.0, 0.0);
    vec3 up = normalize(cross(right, forward));
    vec3 pos = eye;
    vec3 vel = normalize(forward + right * (p.x * k) + up * (-p.y * k));
    vec3 h = cross(pos, vel);
    float h2 = dot(h, h);

    vec3 light = vec3(0.0);
    float through = 1.0;
    bool captured = false;
    for (int i = 0; i < STEPS; i++) {
        float r2 = dot(pos, pos);
        float r = sqrt(r2);
        if (r < 1.02) {
            captured = true;
            break;
        }
        if (r > DISTANCE * 1.15 && dot(pos, vel) > 0.0)
            break;
        float dt = clamp(0.085 * r, 0.03, 1.6);
        // Rays that pass far from the hole are nearly straight and take large steps.
        vel += -1.5 * h2 * pos / (r2 * r2 * r) * dt;
        vec3 next = pos + vel * dt;
        if (pos.y * next.y < 0.0) {
            vec3 hit = mix(pos, next, pos.y / (pos.y - next.y));
            float R = length(hit.xz);
            if (R > 2.7 && R < 10.5) {
                float angle = atan(hit.z, hit.x);
                float omega = sqrt(0.5 / (R * R * R));
                float grain = streaks(R, angle - time * omega * 6.0);
                vec3 tangent = normalize(vec3(-hit.z, 0.0, hit.x));
                float g = 1.0 / max(0.25, 1.0 - sqrt(0.5 / R) * dot(tangent, normalize(vel)));
                float edge = smoothstep(2.7, 3.3, R) * (1.0 - smoothstep(6.5, 10.5, R));
                float heat = clamp(pow(3.0 / R, 1.5) * g * g, 0.0, 1.6);
                // All from the theme: a dim accent outside, the accent itself, and the theme's text colour at the white-hot inner edge.
                vec3 ember = accent.rgb * 0.34;
                vec3 tone = heat < 0.5 ? mix(ember, accent.rgb, heat * 2.0) : mix(accent.rgb, mix(hot.rgb, vec3(1.0), 0.35), clamp(heat - 0.5, 0.0, 1.0));
                float alpha = edge * grain * 0.86;
                light += through * alpha * tone * g * g * g * (0.18 + 1.25 * heat);
                through *= 1.0 - alpha * 0.92;
            }
        }
        pos = next;
    }
    vec3 colour = light;
    if (!captured) {
        // Where the bent ray would have met the sky, had it come straight from the eye: the screen position to read the Medium at.
        vec3 v = normalize(vel);
        float along = dot(v, forward);
        vec2 seen = centre;
        if (along > 0.02) {
            vec2 q = vec2(dot(v, right), -dot(v, up)) / (along * k);
            q.x -= q.y * SHEAR;
            seen = centre + q;
        }
        colour += through * (along > 0.02 ? texture(sky, clamp(seen / size, vec2(0.0), vec2(1.0))).rgb : background(v));
    }
    // A filmic shoulder, so the Doppler side blooms instead of clipping.
    colour = colour / (colour + 0.82) * 1.5;
    fragColor = vec4(colour, 1.0) * qt_Opacity;
}
