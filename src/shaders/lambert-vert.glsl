#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform float u_Time;

uniform float u_NoiseScale;
uniform float u_FlameStretch;


in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec3 fs_Pos;
out vec3 fs_LocalPos;
out float fs_Displacement;

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.
const float PI = 3.14159265;
const float TWO_PI = 6.28318530;

float random1(float seed)
{
    return fract(sin(seed * 12.9898) * 43758.5453);
}

//taken from some shader toy
float random3D(vec3 p)
{
    return fract(
        sin(dot(p, vec3(12.9898, 78.233, 37.719)))
        * 43758.5453
    );
}

float noise3D(vec3 p)
{
    vec3 cell = floor(p);
    vec3 local = fract(p);

    vec3 u = local * local * (3.0 - 2.0 * local);

    float n000 = random3D(cell + vec3(0.0, 0.0, 0.0));
    float n100 = random3D(cell + vec3(1.0, 0.0, 0.0));
    float n010 = random3D(cell + vec3(0.0, 1.0, 0.0));
    float n110 = random3D(cell + vec3(1.0, 1.0, 0.0));

    float n001 = random3D(cell + vec3(0.0, 0.0, 1.0));
    float n101 = random3D(cell + vec3(1.0, 0.0, 1.0));
    float n011 = random3D(cell + vec3(0.0, 1.0, 1.0));
    float n111 = random3D(cell + vec3(1.0, 1.0, 1.0));

    float x00 = mix(n000, n100, u.x);
    float x10 = mix(n010, n110, u.x);
    float x01 = mix(n001, n101, u.x);
    float x11 = mix(n011, n111, u.x);

    float y0 = mix(x00, x10, u.y);
    float y1 = mix(x01, x11, u.y);

    return mix(y0, y1, u.z);
}

float fbm(vec3 p)
{
    float value = 0.0;
    float amplitude = 0.5;

    for(int i = 0; i < 4; i++)
    {
        value += amplitude * noise3D(p);
        p *= 2.0;          // higher frequency each octave
        amplitude *= 0.5;  // lower amplitude each octave
    }

    return value;
}

float flameTipInfluence(vec3 p, float yNorm, float flameAngle, float flameHeight, float angleWidth, float heightWidth
)
{
    float angle = atan(p.z, p.x);
    float angleDist = abs(mod(angle - flameAngle + PI, TWO_PI) - PI);
    float angleInfluence = 1.0 - smoothstep(0.0, angleWidth, angleDist);
    float heightDist = abs(yNorm - flameHeight);
    float heightInfluence = 1.0 - smoothstep(0.0, heightWidth, heightDist);
    float poleMask = 1.0 - smoothstep(0.92, 1.0, yNorm);

    return angleInfluence * heightInfluence * poleMask;
}

void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.
    vec3 p = vs_Pos.xyz;
    //1: Making da base
    
    //map so [0, 1]
    float yNorm = clamp(p.y * 0.5 + 0.5, 0.0, 1.0);

    float taperT = smoothstep(0.0, 1.0, yNorm);

    //scaling factor for the width
    float taper = mix(1.15, 0.25, taperT);

    p.x *= taper;
    p.z *= taper;

    //2: Making top flaming thingy part
    float maxDisplacement = 0.0;
    float bestAngle = 0.0;
    
    //20 tips
    for(int i = 0; i < 20; i++)
    {
        float seed = float(i);
        
        //params for varying stuff 
        float baseAngle = random1(seed + 1.0) * TWO_PI;
        float baseHeight = mix(0.4, 0.9, random1(seed + 10.0));
        float angleWidth = mix(0.4, 0.8, random1(seed + 20.0));
        float heightWidth = mix(0.12, 0.22, random1(seed + 30.0));
        float baseStretch = mix(0.3, 0.8, random1(seed + 40.0));

        //moving components based on time
        float phase = random1(seed + 50.0) * TWO_PI;
        float speed = mix(1.0, 3.0, random1(seed + 60.0));

        float flameAngle = baseAngle + 0.5 * sin(u_Time * speed + phase);
        float flameHeight = baseHeight + 0.02 * sin(u_Time * speed + phase);
        float stretch= u_FlameStretch*(baseStretch + 0.32 * sin(u_Time * speed + phase));

        //influence
        float influence = flameTipInfluence(p, yNorm, flameAngle, flameHeight, angleWidth, heightWidth);

        float displacement = stretch * influence;
        if(displacement > maxDisplacement)
        {
            maxDisplacement = displacement;
            bestAngle =flameAngle;
        }
        
        //maxDisplacement = max(maxDisplacement, displacement);
    }

    //p.y += maxDisplacement;
    vec2 spreadDir = vec2(cos(bestAngle), sin(bestAngle));

    // outward spread
    p.x += spreadDir.x * maxDisplacement * 0.15;
    p.z += spreadDir.y * maxDisplacement * 0.15;

    // upward movement
    p.y += maxDisplacement * 0.85;

    //3. creating da detail

    float detail = fbm(vs_Pos.xyz * u_NoiseScale - vec3(0.0, u_Time * 3., 0.0));
    p+= normalize(vs_Nor.xyz)*detail * .2;

    fs_Displacement =maxDisplacement + detail;
  

    vec4 modifiedPos = vec4(p, 1.0);
    vec4 modelposition = u_Model * modifiedPos ;   // Temporarily store the transformed vertex positions for use below

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies


    
    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
    
    fs_LocalPos = p;

    fs_Pos = modelposition.xyz;
}