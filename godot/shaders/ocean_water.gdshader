shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float wave_time;
uniform float wave_height : hint_range(0, 0.5) = 0.12;
uniform float wave_speed : hint_range(0, 3) = 0.8;
uniform vec3 shallow_color : source_color = vec3(0.35, 0.75, 0.85);
uniform vec3 deep_color : source_color = vec3(0.05, 0.12, 0.25);
uniform float fresnel_strength : hint_range(0, 1) = 0.5;
uniform float foam_amount : hint_range(0, 1) = 0.3;
uniform float water_roughness : hint_range(0, 1) = 0.25;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    float t = wave_time * wave_speed;
    vec2 pos = world_pos.xz;
    
    // Multiple wave layers for realistic ocean motion
    float wave1 = sin(pos.x * 0.3 + t) * cos(pos.y * 0.25 + t * 0.7);
    float wave2 = sin(pos.x * 0.9 - t * 1.1) * 0.55;
    float wave3 = cos(pos.y * 0.7 + t * 0.9) * 0.45;
    float wave4 = sin((pos.x * 1.1 + pos.y * 0.8) + t * 1.2) * 0.35;
    
    float height = (wave1 + wave2 + wave3 + wave4) * wave_height;
    VERTEX.y += height;
    
    // Calculate normals for lighting
    float delta = 0.2;
    float h = height;
    float hx = (sin((pos.x + delta) * 0.3 + t) * cos(pos.y * 0.25 + t * 0.7) +
                sin((pos.x + delta) * 0.9 - t * 1.1) * 0.55) * wave_height;
    float hz = (sin(pos.x * 0.3 + t) * cos((pos.y + delta) * 0.25 + t * 0.7) +
                cos((pos.y + delta) * 0.7 + t * 0.9) * 0.45) * wave_height;
    
    vec3 tangent = vec3(1.0, (hx - h) / delta, 0.0);
    vec3 bitangent = vec3(0.0, (hz - h) / delta, 1.0);
    world_normal = normalize(cross(tangent, bitangent));
}

void fragment() {
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
    vec3 normal = normalize(world_normal);
    
    // Sun direction
    vec3 light_dir = normalize(vec3(1.0, 1.2, 0.6));
    vec3 light_color = vec3(1.0, 0.95, 0.85);
    
    // Basic diffuse lighting
    float diffuse = max(0.3, dot(normal, light_dir));
    
    // Specular highlight (sun glints on water)
    vec3 reflect_dir = reflect(-light_dir, normal);
    float specular = pow(max(0.0, dot(view_dir, reflect_dir)), 60.0);
    specular = specular * 0.5;
    
    // Fresnel effect (water reflects more at grazing angles)
    float fresnel = pow(1.0 - abs(dot(view_dir, normal)), 2.5);
    fresnel = fresnel * fresnel_strength;
    
    // Base water color (depth-based)
    float depth_factor = clamp((world_pos.y + 1.5) / 4.0, 0.0, 1.0);
    vec3 albedo = mix(deep_color, shallow_color, depth_factor);
    
    // Wave slope highlights (shows wave direction)
    float wave_slope = length(normal.xz);
    albedo += vec3(0.05, 0.08, 0.1) * wave_slope;
    
    // Sky reflection (subtle, not metallic)
    vec3 sky_reflection = mix(vec3(0.15, 0.25, 0.45), vec3(0.4, 0.6, 0.8), fresnel);
    
    // Combine lighting
    vec3 color = albedo * diffuse * light_color;
    color = mix(color, sky_reflection, fresnel * 0.4);
    color += specular * light_color;
    
    // Foam on steep wave slopes
    float foam = smoothstep(0.65, 0.9, wave_slope);
    foam = foam * foam_amount;
    foam = clamp(foam, 0.0, 0.4);
    vec3 foam_color = vec3(0.85, 0.92, 0.98);
    color = mix(color, foam_color, foam);
    
    ALBEDO = color;
    METALLIC = 0.03;
    ROUGHNESS = water_roughness;
    SPECULAR = 0.35;
}