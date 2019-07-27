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
//:   "default": 0.1,
//:   "min": 0.0,
//:   "max": 1.0,
//:   "label": "Dark threshold"
//: }
uniform float dark_threshold;

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


  // First band
  if (NdL * ao < threshold) {
    color = color * shadow;
  }

  // Dark band
  if (ao < dark_threshold)
  {
    color *= shadow;
  }

  // Highlight Management
  float highlightMask = 0.0;
  if (roughness > 0.1)
  {
    // Remap the Roughness from 0.1 - 1 to 0 - 1
    roughness = (roughness - 0.1) * (1 / (1 - 0.1));

    vec3 reflection = normalize(V + L);
    float highlightsRaw = pow(dot(N, reflection), 10);
    highlightMask = float( highlightsRaw > (1 - roughness));
    // color += highlightMask;
    color = mix(color + highlightMask, color, pow(roughness, 0.8));
  }

  diffuseShadingOutput(color);
  //diffuseShadingOutput(vec3(highlightMask));
}