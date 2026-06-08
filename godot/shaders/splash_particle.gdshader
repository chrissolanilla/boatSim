shader_type particles;
render_mode blend_add;

uniform sampler2D particle_texture : source_color;

void vertex() {
    // Make particles face camera
    vec4 scale = vec4(1.0, 1.0, 1.0, 1.0);
    TRANSFORM = scale;
}

void fragment() {
    // White/blue splash color
    vec4 color = vec4(0.7, 0.8, 0.95, 1.0);
    
    // Fade out over time
    float alpha = 1.0 - fract(1.0 - TIME);
    alpha = alpha * alpha;  // Smooth fade
    
    ACTIVE = true;
    ALBEDO = color.rgb;
    ALPHA = alpha * 0.7;
}