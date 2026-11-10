#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 sheetSize;
    float drive;
    float phase;
    float fraction;
    float impulse;
    float completion;
    float count;
    vec4 anchor0;
    vec4 anchor1;
    vec4 anchor2;
    vec4 inkColor;
    vec4 signalColor;
};
const float slope = 4.704630109;
float seam(float y, float aspect) { return aspect * .58 + (.5-y)/slope; }
vec2 warp(vec2 p, float aspect, float compress) {
    float cut=seam(p.y,aspect);
    p.x = p.x <= cut ? p.x : cut+(p.x-cut)/compress;
    return p;
}
float band(float v, float pitch, float px) {
    float d=abs(fract(v/pitch+.5)-.5)*pitch;
    return 1.-smoothstep(px,px+max(fwidth(v),.25),d);
}
void main() {
    float aspect=sheetSize.x/max(sheetSize.y,1.);
    vec2 p=vec2(qt_TexCoord0.x*aspect,qt_TexCoord0.y);
    vec4 anchors[3]=vec4[3](anchor0,anchor1,anchor2);
    float compress=.18+.82*sqrt(clamp(fraction,0.,1.));
    // Breathing follows both urgency and the lease, and never touches the control layer.
    compress*=1.+.045*drive*(1.-fraction)*sin(phase*6.2831853);
    vec2 q=warp(p,aspect,compress);
    float crowd=0.;
    for (int i=0;i<3;i++) for(int j=i+1;j<3;j++) {
        if(float(j)>=count) continue;
        float close=anchors[i].w*anchors[j].w*clamp(1.-abs(anchors[i].z-anchors[j].z)/60.,0.,1.);
        vec2 mid=(anchors[i].xy+anchors[j].xy)*.5*vec2(aspect,1.);
        crowd+=close*exp(-8.*dot(p-mid,p-mid));
    }
    float arrivals[3];
    float earliest=1e9;
    for(int i=0;i<3;i++) {
        arrivals[i]=1e9;
        if(float(i)>=count) continue;
        vec2 a=warp(anchors[i].xy*vec2(aspect,1.),aspect,compress);
        arrivals[i]=anchors[i].z+length(q-a)*1800.*(1.+1.6*crowd);
        earliest=min(earliest,arrivals[i]);
    }
    float sum=0.;
    for(int i=0;i<3;i++) if(float(i)<count) sum+=exp(-(arrivals[i]-earliest)/24.);
    float field=earliest-24.*log(max(sum,.00001));
    float original=field;
    // Flow is a small displacement of the equal-time surface; impulse propagates from all anchors.
    field+=drive*13.*sin(field/180.-phase*6.2831853);
    field+=impulse*36.*sin(original/90.-impulse*12.);
    float minor=band(field,60.,1.0);
    float major=band(field,300.,3.0);
    float cut=seam(p.y,aspect);
    float fault=1.-smoothstep(.001,.004,abs(p.x-cut));
    float future=step(cut,p.x);
    float paperPressure=future*(1.-fraction)*.055;
    float a=(minor*.30+major*.36+fault*.75+paperPressure)*drive*step(.5,count);
    // Completion is a single finite FlashGate-granted crest, never an idle flash.
    a+=completion*.15*exp(-abs(p.x-cut)*16.);
    vec3 colour=mix(inkColor.rgb,signalColor.rgb,clamp(major+crowd*.5+fault+completion,0.,1.));
    a=clamp(a,0.,.9);
    fragColor=vec4(colour*a,a)*qt_Opacity;
}
