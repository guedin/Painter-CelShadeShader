import lib-sampler.glsl
import lib-vectors.glsl
import lib-utils.glsl

//: param auto main_light
uniform vec4 light_main;

//: param auto channel_basecolor
uniform SamplerSparse basecolor_tex;

//: param auto channel_user0
uniform SamplerSparse shadow_tex;

//: param auto channel_ao
uniform SamplerSparse custom_ao_tex;

//: param auto channel_roughness
uniform SamplerSparse roughness_tex;

//: param auto channel_metallic
uniform SamplerSparse metallic_tex;

//: param auto channel_specularlevel 
uniform SamplerSparse spec_tex;

//: param custom {
//:   "default": 1,
//:   "min": 0.0,
//:   "max": 10.0,
//:   "label": "Light Height"
//: }
uniform float light_height;

//: param custom {
//:   "default": 0.5,
//:   "min": 0.0,
//:   "max": 1.0,
//:   "label": "Threshold"
//: }
uniform float threshold;

//: param custom {
//:   "default": 0.2,
//:   "min": 0.0,
//:   "max": 1.0,
//:   "label": "Dark threshold"
//: }
uniform float dark_threshold;

float CSHairHighlightMask(vec3 N, vec3 V, float Thickness, float FadeOutAdjust, float TargetDotRange, float Height, float Power)
{
    float Fresnel = abs(dot(N, V));
    Fresnel = clamp(((1 - Fresnel) - FadeOutAdjust), 0.0, 1.0);
    Fresnel = clamp((Fresnel * TargetDotRange), 0.0, 1.0);

    float LineGradientMask = abs(dot(N, vec3(0.0, 1.0, 0.0)) - Height);

    float Mask = LineGradientMask / Fresnel;
    if (Mask < 0)
    {
        Mask = 1.0;
    }
    Mask = pow((1 - Mask), Power);

    if (Mask > 1 - Thickness)
    {
        return 1.0;
    }
    else
    {
        return 0.0;
    }
}

float HighlightMask(vec3 N, vec3 V, vec3 L, float roughness, float spec)
{
  if (roughness > .05)
  {
    if (spec < 0.5 || spec > 0.75)
    {
      vec3 reflection = normalize(V + L);
      float highlightsRaw = pow(dot(N, reflection), 5);
      return float( highlightsRaw > (1 - roughness));
    }
    else
    {
      return CSHairHighlightMask(N, V, roughness, 0.01, 1, 0.5, 2.1);
    }
  }
}

void shade(V2F inputs)
{
  inputs.normal = normalize(inputs.normal);
  LocalVectors vectors = computeLocalFrame(inputs);
  vec3 light_pos = vec3(light_main.x, light_height, light_main.z);
  vec3 V = vectors.eye;
  vec3 N = vectors.normal;
  vec3 L = vec3(light_pos);
  float NdV = dot(N, V);
  float NdL = max(0.0, dot(N, L));

  vec3 color = getBaseColor(basecolor_tex, inputs.sparse_coord);
  vec3 shadow = sRGB2linear(textureSparse(shadow_tex, inputs.sparse_coord).rgb);
  float ao = textureSparse(custom_ao_tex, inputs.sparse_coord).r;
  float roughness = textureSparse(roughness_tex, inputs.sparse_coord).r;
  float metallic = textureSparse(metallic_tex, inputs.sparse_coord).r;
  float spec = textureSparse(spec_tex, inputs.sparse_coord).r;

  float highlightMask = 0.0;
  // First band
  if (spec < 0.75)
  {
    if (NdL * ao < threshold) 
    {
      color = color * shadow;
    }
    else
    {
      highlightMask = HighlightMask(N, V, L, roughness, spec);
      color = mix(color + highlightMask, color, pow(roughness, 1.5));
    }

    // Dark band
    if (ao < dark_threshold)
    {
      color *= shadow;
    }
  }
  // Metallic behavior
  else
  {
    vec3 baseColor = color;
    // First Color is lighter
    if (NdL * ao < threshold) 
    {
      color = baseColor + shadow;
    }
    else
    {
      // Base Color is Darkened
      color = mix(baseColor, baseColor * shadow, 0.6);

      // Highlight management
      color = mix(color, baseColor*2, HighlightMask(N, V, L, roughness, spec));
    }

    // Second band is Darker
    if (NdL * ao < threshold / 3)
    {
      color = baseColor * shadow;
    }

    // Fresnel Band is super dark
    if (NdV * ao < 0.35)
    {
      color = baseColor * shadow * 0.3;
    }
  }

  diffuseShadingOutput(color);
  //diffuseShadingOutput(vec3(NdV));
}