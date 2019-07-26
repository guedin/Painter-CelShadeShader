import lib-sampler.glsl
import lib-vectors.glsl

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
  vec3 V = vectors.eye;
  vec3 N = vectors.normal;
  vec3 L = vec3(light_main);
  float NdV = dot(N, V);
  float NdL = max(0.0, dot(N, L));

  vec3 color = getBaseColor(basecolor_tex, inputs.sparse_coord);
  vec3 shadow = textureSparse(shadow_tex, inputs.sparse_coord).rgb;
  float ao = textureSparse(custom_ao_tex, inputs.sparse_coord).r;
  float roughness = textureSparse(roughness_tex, inputs.sparse_coord).r;

  float highlightMask = 0.0;

  // First band
  if (NdL * ao < 0.5) {
    color = color * shadow;
  }

  // Dark band
  if (ao < dark_threshold)
  {
    color *= shadow;
  }

  // Highlight Management
  if (roughness > 0.1)
  {
    // Remap the Roughness from 0.1 - 1 to 0 - 1
    roughness = (roughness - 0.1) * (1 / (1 - 0.1));

    vec3 reflection = normalize(V + L);
    float highlightsRaw = pow(dot(N, reflection), 30);
    highlightMask = float( highlightsRaw > (1 - roughness - 0.1));
    color += highlightMask;
  }

  diffuseShadingOutput(color);
}