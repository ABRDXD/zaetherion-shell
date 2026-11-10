#version 440
// The spacetime fabric (OrbitSystem): a grid mesh on a plane under the orbit, pressed down by every mass
// (Home, the rooms, the other systems' suns and their moons) and, while something is chosen, by a passing ripple.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 plane;
layout(location = 1) out float glow;
layout(location = 2) out float sink;
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
    // Wells: x, y on the plane (Home at 0, 0), depth, radius. Unused ones have depth 0.
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
    vec4 w18;
    vec4 w19;
    vec4 w20;
    vec4 w21;
    vec4 w22;
    vec4 w23;
    vec4 w24;
    vec4 w25;
    vec4 w26;
    vec4 w27;
    vec4 w28;
    vec4 w29;
    vec4 w30;
    vec4 w31;
    vec4 w32;
    vec4 w33;
    vec4 w34;
    vec4 w35;
    vec4 w36;
    vec4 w37;
    vec4 w38;
    vec4 w39;
    vec4 w40;
    vec4 w41;
    vec4 w42;
    vec4 w43;
    vec4 w44;
    vec4 w45;
    vec4 w46;
    vec4 w47;
    vec4 w48;
    vec4 w49;
    vec4 w50;
    vec4 w51;
    vec4 w52;
    vec4 w53;
    vec4 w54;
    vec4 w55;
    vec4 w56;
    vec4 w57;
    vec4 w58;
    vec4 w59;
    vec4 w60;
    vec4 w61;
    vec4 w62;
    vec4 w63;
    vec4 w64;
    vec4 w65;
    vec4 w66;
    vec4 w67;
    vec4 w68;
    vec4 w69;
    vec4 w70;
    vec4 w71;
    vec4 w72;
    vec4 w73;
    vec4 w74;
    vec4 w75;
    vec4 w76;
    vec4 w77;
    vec4 w78;
    vec4 w79;
};

out gl_PerVertex { vec4 gl_Position; };

float well(vec2 p, vec4 w) {
    vec2 d = p - w.xy;
    return w.z / (1.0 + dot(d, d) / (w.w * w.w));
}

void main() {
    vec2 p = qt_Vertex.xy - vec2(extent);
    float d = well(p, w0) + well(p, w1) + well(p, w2) + well(p, w3) + well(p, w4) + well(p, w5) + well(p, w6) + well(p, w7)
        + well(p, w8) + well(p, w9) + well(p, w10) + well(p, w11) + well(p, w12) + well(p, w13) + well(p, w14) + well(p, w15)
        + well(p, w16) + well(p, w17) + well(p, w18) + well(p, w19) + well(p, w20) + well(p, w21) + well(p, w22) + well(p, w23)
        + well(p, w24) + well(p, w25) + well(p, w26) + well(p, w27) + well(p, w28) + well(p, w29) + well(p, w30) + well(p, w31)
        + well(p, w32) + well(p, w33) + well(p, w34) + well(p, w35) + well(p, w36) + well(p, w37) + well(p, w38) + well(p, w39)
        + well(p, w40) + well(p, w41) + well(p, w42) + well(p, w43) + well(p, w44) + well(p, w45) + well(p, w46) + well(p, w47)
        + well(p, w48) + well(p, w49) + well(p, w50) + well(p, w51) + well(p, w52) + well(p, w53) + well(p, w54) + well(p, w55)
        + well(p, w56) + well(p, w57) + well(p, w58) + well(p, w59) + well(p, w60) + well(p, w61) + well(p, w62) + well(p, w63)
        + well(p, w64) + well(p, w65) + well(p, w66) + well(p, w67) + well(p, w68) + well(p, w69) + well(p, w70) + well(p, w71)
        + well(p, w72) + well(p, w73) + well(p, w74) + well(p, w75) + well(p, w76) + well(p, w77) + well(p, w78) + well(p, w79);
    // Overdrive: the wells breathe and the bass presses them; Home sends gravitational waves out across the
    // fabric, taller with the bass. All of it is multiplied by the engine, so Silent is exactly the still fabric.
    float home = length(p);
    d *= 1.0 + life.y * (0.10 * sin(6.2831853 * life.x) + 0.45 * life.z);
    float gw = life.y * spacing * (0.10 + 0.6 * life.z) * sin(home / (spacing * 2.2) - 6.2831853 * 3.0 * life.x)
        * exp(-home / (extent * 0.35));
    d += gw;
    float r = length(p - ripple.xy);
    float front = (r - ripple.z) / (spacing * 1.6);
    float wave = ripple.w * exp(-front * front) * sin(front * 2.4);
    plane = p;
    glow = abs(wave) / max(abs(ripple.w), 0.001) + life.y * abs(gw) / spacing * (0.5 + life.z);
    sink = d;
    d += wave;
    vec2 s = vec2(cx + p.x - p.y * sinE * shear, cy + p.y * sinE + drop + d * cosE);
    gl_Position = qt_Matrix * vec4(s, 0.0, 1.0);
}
