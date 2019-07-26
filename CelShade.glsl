import lib-sampler.glsl
import lib-vectors.glsl

//: param auto main_light
uniform vec4 light_main;

//: param auto channel_basecolor
uniform SamplerSparse basecolor_tex;

//: param auto texture_curvature
uniform SamplerSparse curvature_tex;

//: param auto texture_position
uniform SamplerSparse position_tex;

//: param auto channel_user0
uniform SamplerSparse shadow_tex;

//: param auto channel_ao
uniform SamplerSparse custom_ao_tex;

//: param custom {
//:  "default": 0.4,
//:   "min": 0.0,
//:   "max": 1.0,
//:   "label": "Unlit outline thickness"
//: }
uniform float unlit_outline_thickness;

//: param custom {
//:   "default": 0.1,
//:   "min": 0.0,
//:   "max": 1.0,
//:   "label": "Lit outline thickness"
//: }
uniform float lit_outline_thickness;

//: param custom {
//:   "default": false,
//:   "label": "Use curvature"
//: }
uniform bool use_curvature;


void shade(V2F inputs)
{
  inputs.normal = normalize(inputs.normal);
  LocalVectors vectors = computeLocalFrame(inputs);
  vec3 V = vectors.eye;
  vec3 N = vectors.normal;
  vec3 L = vec3(light_main);
  float NdV = dot(N, V);
  float NdL = max(0.0, dot(N, L));
  if (use_curvature) {
    float curv = textureSparse(curvature_tex, inputs.sparse_coord).r;
    NdV = 1.0 - curv;
  }
  if (NdV < mix(unlit_outline_thickness, lit_outline_thickness, NdL)) {
    return;
  }
  vec3 color = getBaseColor(basecolor_tex, inputs.sparse_coord);
  vec3 shadow = textureSparse(shadow_tex, inputs.sparse_coord).rgb;
  float ao = textureSparse(custom_ao_tex, inputs.sparse_coord).r;
  if (NdL * ao < 0.5) {
    color = color * shadow;
  }

  diffuseShadingOutput(color);
}