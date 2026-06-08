shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float time : hint_range(0, 1000) = 0.0;
uniform float wave_height : hint_range(0, 1) = 0.15;
uniform float wave_frequency : hint_range(0, 2) = 0.5;
uniform float wave_speed : hint_range(0, 3) = 1.0;
uniform vec3 deep_color : source_color = vec3(0.02, 0.05, 0.12);
uniform vec3 shallow_color : source_color = vec3(0.08, 0.35, 0.55);
uniform float fresnel_strength : hint_range(0, 2) = 0.8;
uniform float glossiness : hint_range(0, 1) = 0.95;

varying vec3 vertex_world;

void vertex() {
    vertex_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Simple wave math
    vec2 pos = vertex_world.xz;
    float t = time * wave_speed;
    
    float wave1 = sin(pos.x * wave_frequency + t) * cos(pos.y * wave_frequency * 0.7 + t * 0.8);
    float wave2 = sin(pos.x * wave_frequency * 2.3 - t * 1.2) * 0.5;
    float wave3 = cos(pos.y * wave_frequency * 1.8 + t * 0.9) * 0.3;
    float wave4 = sin((pos.x * 0.8 + pos.y * 0.6) * wave_frequency * 3.0 + t * 1.5) * 0.2;
    
    float height = (wave1 + wave2 + wave3 + wave4) * wave_height;
    VERTEX.y += height;
}

void fragment() {
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - vertex_world);
    
    // Fake normals from position
    vec3 normal = vec3(0.0, 1.0, 0.0);
    
    // Fresnel effect (water reflects more at grazing angles)
    float fresnel = pow(1.0 - abs(dot(view_dir, normal)), fresnel_power);
    
    // Color based on height (shallow vs deep)
    float depth_factor = clamp((vertex_world.y + 2.0) / 5.0, 0.0, 1.0);
    vec3 albedo = mix(deep_color, shallow_color, depth_factor);
    
    // Simple fake reflection (sky color)
    vec3 sky_reflection = mix(vec3(0.1, 0.2, 0.4), vec3(0.4, 0.7, 0.9), view_dir.y * 0.5 + 0.5);
    
    // Combine
    vec3 final_color = mix(albedo, sky_reflection, fresnel * 0.7);
    
    // Add white foam on wave peaks
    float foam = smoothstep(0.6, 0.9, abs(normal.x)) * 0.3;
    foam += smoothstep(0.6, 0.9, abs(normal.z)) * 0.3;
    final_color = mix(final_color, vec3(0.95, 0.98, 1.0), foam);
    
    ALBEDO = final_color;
    METALLIC = 0.95;
    ROUGHNESS = 0.08;
    SPECULAR = 0.9;
}