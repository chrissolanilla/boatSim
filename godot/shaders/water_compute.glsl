#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D heightmap;
layout(set = 0, binding = 1, rgba32f) uniform image2D velocity_map;
layout(set = 0, binding = 2) uniform WaterParams {
	float time;
	float wind_speed;
	float wind_dir_x;
	float wind_dir_z;
	float wave_amplitude;
	float wave_length;
	float viscosity;
	float dt;
	float g;
	float interaction_strength;
	uint resolution;
	uint frame;
} params;

layout(set = 0, binding = 3) buffer InteractionBuffer {
	vec4 interactions[];
};

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(heightmap);
	
	if (pixel.x >= size.x || pixel.y >= size.y) return;
	
	vec4 current_h = imageLoad(heightmap, pixel);
	float height = current_h.x;
	float prev_height = current_h.y;
	
	// Simple wave propagation
	float laplacian = 0.0;
	float sample_offset = 1.0 / float(size.x);
	
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) continue;
			ivec2 neighbor = pixel + ivec2(dx, dy);
			if (neighbor.x >= 0 && neighbor.x < size.x && 
				neighbor.y >= 0 && neighbor.y < size.y) {
				float neighbor_h = imageLoad(heightmap, neighbor).x;
				laplacian += neighbor_h - height;
			}
		}
	}
	laplacian /= 4.0;
	laplacian *= float(size.x) * float(size.x);
	
	float new_height = height + params.dt * (params.g * laplacian - params.viscosity * (height - prev_height) / params.dt);
	
	imageStore(heightmap, pixel, vec4(new_height, height, 0.0, 0.0));
}
