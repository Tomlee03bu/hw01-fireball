#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform float u_Time;
uniform vec3 u_CamPos;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec3 fs_Pos;
in vec4 fs_ClipPos;
in vec3 fs_LocalPos;
in float fs_Displacement;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

//Control parameters
const vec3 red = vec3(0.95, 0.18, 0.02);
const vec3 orange = vec3(1.00, 0.42, 0.03);
const vec3 yellow = vec3(1.00, 0.70, 0.10);

// Approximate width of the outer silhouette near bottom and top
const float BASE_WIDTH = 1.15;
const float TOP_WIDTH  = 0.25;

// Approximate vertical range of the fireball in local space
const float Y_OFFSET = 1.5;
const float Y_RANGE  = 3.5;

//Masks for face stuff 
float ellipseMask(vec2 p, vec2 center, vec2 radius, float blur)
{
    vec2 q = p - center;

    q.x += 0.004 * sin(q.y * 18.0 + u_Time * 1.2);
    q.y += 0.007 * sin(q.x * 14.0 - u_Time * 5.0);

    vec2 e = q / radius;
    float d = length(e);

    return 1.0 - smoothstep(1.0, 1.0 + blur, d);
}

void main()
{
    // Material base color (before shading)
    vec4 diffuseColor = u_Color;

    // Calculate the diffuse term for Lambert shading
    float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
    // Avoid negative lighting values
    // diffuseTerm = clamp(diffuseTerm, 0, 1);

    float ambientTerm = 0.2;

    float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                        //to simulate ambient lighting. This ensures that faces that are not
                                                        //lit by our point light are not completely black.

    // Compute final shaded color
    //out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);


    //1: Building camera stuff

    vec3 camDir = normalize(u_CamPos);

    vec3 horizontalCam = vec3(camDir.x, 0.0, camDir.z);
    float horizontalLen = length(horizontalCam);

    vec3 right;

    if(horizontalLen > 0.001)
    {
        horizontalCam /= horizontalLen;
        right = normalize(cross(vec3(0.0, 1.0, 0.0), horizontalCam));
    }
    else
    {
        right = vec3(1.0, 0.0, 0.0);
    }

    vec3 up = vec3(0.0, 1.0, 0.0);

    float x = dot(fs_LocalPos, right);
    float y = dot(fs_LocalPos, up);

    float yNorm = clamp((y + Y_OFFSET) / Y_RANGE, 0.0, 1.0);

    //4: Approximate outerflame width

    float taperT = smoothstep(0.0, 1.0, yNorm);

    float outerWidth = mix(BASE_WIDTH, TOP_WIDTH, taperT);
    float normalizedX = clamp(abs(x) / outerWidth, 0.0, 1.0);

    //5: Getting ze color val
  
    // lower parts are brighter
    float bottomAmount = 1.0 - yNorm;

    // center parts are brighter
    float centerAmount = 1.0 - normalizedX;

    float xDist = normalizedX;

    // Moving where the yellow part is
    float hotCenterY = 0.28;

    float yDist = (yNorm - hotCenterY) / 0.65;
    float heatDist = length(vec2( xDist, yDist));
    float roundedAmount = 1.0 - smoothstep(0.15, 1.0,heatDist);
    float colorValue = roundedAmount + fs_Displacement * 0.1;

    colorValue = clamp(colorValue, 0.0, 1.0);

    //6: getting the color grad
    vec3 flameColor;

    float redToOrange = smoothstep(0.00, 0.55, colorValue);

    float orangeToYellow = smoothstep(0.45, 1.0, colorValue);

    flameColor = mix(red, orange, redToOrange);
    flameColor = mix(flameColor, yellow, orangeToYellow);

    //7: Face construction
    float signedX = x / outerWidth;
    vec2 faceUV = vec2(signedX, yNorm);

    // O__O
    
    float EYE_WIDTH = 0.175;
    float EYE_HEIGHT = 0.045;

    float EYE_PLACEMENT_LEFTRIGHT = 0.4;

    float leftEyeWhite = ellipseMask(

        faceUV,
        vec2(-EYE_PLACEMENT_LEFTRIGHT, 0.50),
        vec2(EYE_WIDTH, EYE_HEIGHT),
        0.05
        
        );

    float rightEyeWhite = ellipseMask(

        faceUV,
        vec2(EYE_PLACEMENT_LEFTRIGHT, 0.50),
        vec2(EYE_WIDTH, EYE_HEIGHT),
        0.05
        
        );

    //pupils

    float PUPIL_WIDTH = 0.075;
    float PUPIL_HEIGHT = 0.019;

    float PUPIL_PLACEMENT_LEFTRIGHT = 0.4;
    float PUPIL_PLACEMNET_UPDOWN = 0.49;

    float leftPupil = ellipseMask(

        faceUV,
        vec2(-PUPIL_PLACEMENT_LEFTRIGHT, PUPIL_PLACEMNET_UPDOWN),
        vec2(PUPIL_WIDTH, PUPIL_HEIGHT),
        0.08
    
    );

    float rightPupil = ellipseMask(
        
        faceUV,
        vec2(PUPIL_PLACEMENT_LEFTRIGHT, PUPIL_PLACEMNET_UPDOWN),
        vec2(PUPIL_WIDTH, PUPIL_HEIGHT),
        0.08
    
    );


    //mouth
    float mouth = ellipseMask(

        faceUV,
        vec2(-0.01, 0.315),
        vec2(0.45, 0.065),
        0.04
    
    );

    //coloersss
    vec3 eyeWhiteColor = vec3(0.90, 0.84, 0.67);
    vec3 pupilColor    = vec3(0.03, 0.025, 0.015);

    float eyeWhiteMask = max(leftEyeWhite, rightEyeWhite);
    flameColor = mix(flameColor, eyeWhiteColor, eyeWhiteMask);

    float pupilMask = max(leftPupil, rightPupil);

    flameColor = mix(flameColor, pupilColor, pupilMask);

    vec3 mouthColor = mix(red, orange, 0.35);
    flameColor = mix(flameColor, mouthColor, mouth);

    out_Col = vec4(flameColor, 1.0);

    }
