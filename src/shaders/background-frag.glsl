#version 300 es
precision highp float;

uniform float u_Time;
uniform float u_TimeSpeed;

in vec2 fs_UV;

out vec4 out_Col;

float random(vec2 p) {
    return fract(
        sin(dot(p, vec2(12.9898, 78.233)))
        * 43758.5453
    );
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(a, b, u.x),
        mix(c, d, u.x),
        u.y
    );
}


void main() {
    vec2 p = fs_UV * 5.0;
    p.y -= u_Time * 0.45;

    float n = noise(p);
    float speedT = clamp(u_TimeSpeed / 10.0, 0.0, 1.0);

    vec3 coolBottom = vec3(0.02, 0.03, 0.12);
    vec3 coolTop    = vec3(0.10, 0.02, 0.18);

    vec3 hotBottom  = vec3(0.25, 0.04, 0.02);
    vec3 hotTop     = vec3(0.55, 0.12, 0.02);

    vec3 bottom = mix(coolBottom, hotBottom, speedT);
    vec3 top = mix(coolTop, hotTop, speedT);

    vec3 color = mix(bottom, top, fs_UV.y);

    color += (n - 0.5) * 0.08;

    out_Col = vec4(color, 1.0);
}