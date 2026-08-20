const float GLOW_STRENGTH = 0.30;
const float GLOW_RADIUS_PX = 2.2;
const float GLOW_LUMA_THRESHOLD = 0.45;
const float GLOW_FALLOFF = 0.45;
const int GLOW_TAP_RADIUS = 2;

const vec3 LUMA_WEIGHTS = vec3(0.2126, 0.7152, 0.0722);

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(iChannel0, uv);

    vec2 texelStep = vec2(GLOW_RADIUS_PX) / iResolution.xy;

    vec3 bloom = vec3(0.0);
    float weightSum = 0.0;

    for (int y = -GLOW_TAP_RADIUS; y <= GLOW_TAP_RADIUS; y++) {
        for (int x = -GLOW_TAP_RADIUS; x <= GLOW_TAP_RADIUS; x++) {
            vec2 tap = vec2(float(x), float(y));
            float weight = exp(-dot(tap, tap) * GLOW_FALLOFF);
            vec2 tapUv = clamp(uv + tap * texelStep, vec2(0.0), vec2(1.0));
            vec3 tapColor = texture(iChannel0, tapUv).rgb;
            float luma = dot(tapColor, LUMA_WEIGHTS);
            bloom += tapColor * max(luma - GLOW_LUMA_THRESHOLD, 0.0) * weight;
            weightSum += weight;
        }
    }

    vec3 premultipliedBloom = bloom / weightSum * GLOW_STRENGTH * src.a;
    fragColor = vec4(min(src.rgb + premultipliedBloom, vec3(src.a)), src.a);
}
