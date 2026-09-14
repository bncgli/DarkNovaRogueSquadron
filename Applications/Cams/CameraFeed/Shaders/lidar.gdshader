shader_type canvas_item;

uniform sampler2D feed_texture : repeat_disable, filter_linear;
uniform float sweep_speed : hint_range(0.1, 2.0) = 0.4;
uniform float grid_density : hint_range(20.0, 200.0) = 90.0;
uniform float edge_threshold : hint_range(0.02, 0.5) = 0.08;
uniform vec3 lidar_color_cyan : source_color = vec3(0.0, 0.92, 1.0);
uniform vec3 lidar_color_green : source_color = vec3(0.1, 1.0, 0.35);

void fragment() {
	vec2 uv = UV;
	vec2 texel_size = 1.0 / vec2(textureSize(feed_texture, 0));
	
	vec4 center = texture(feed_texture, uv);
	vec4 c_left = texture(feed_texture, uv - vec2(texel_size.x * 1.5, 0.0));
	vec4 c_right = texture(feed_texture, uv + vec2(texel_size.x * 1.5, 0.0));
	vec4 c_top = texture(feed_texture, uv - vec2(0.0, texel_size.y * 1.5));
	vec4 c_bottom = texture(feed_texture, uv + vec2(0.0, texel_size.y * 1.5));
	
	// Calcolo bordi geometrie (Sobel / Laplacian Edge Detection)
	float lum_c = dot(center.rgb, vec3(0.299, 0.587, 0.114));
	float lum_l = dot(c_left.rgb, vec3(0.299, 0.587, 0.114));
	float lum_r = dot(c_right.rgb, vec3(0.299, 0.587, 0.114));
	float lum_t = dot(c_top.rgb, vec3(0.299, 0.587, 0.114));
	float lum_b = dot(c_bottom.rgb, vec3(0.299, 0.587, 0.114));
	
	float edge = abs(lum_l - lum_r) + abs(lum_t - lum_b);
	float is_surface = step(0.04, lum_c);
	float is_edge = smoothstep(edge_threshold, edge_threshold + 0.1, edge);
	
	// Reticolo a matrice di punti / campionamento raycast lidar
	vec2 grid_uv = fract(uv * vec2(grid_density, grid_density * 0.75));
	float dot_dist = length(grid_uv - vec2(0.5));
	float point_cloud = step(dot_dist, 0.18) * is_surface;
	
	// Linee di livello topografiche / curve di livello di profondità
	float depth_iso = sin(lum_c * 40.0 + uv.y * 15.0);
	float topo_lines = smoothstep(0.85, 0.95, depth_iso) * is_surface * 0.5;
	
	// Scanner Sweep Beam (raggio di scansione radar/lidar verticale)
	float sweep_y = fract(TIME * sweep_speed);
	float sweep_dist = abs(uv.y - sweep_y);
	float sweep_beam = smoothstep(0.12, 0.0, sweep_dist);
	
	// Composizione vettoriale HUD Lidar Verde / Ciano
	vec3 base_dark = vec3(0.01, 0.03, 0.05);
	vec3 surface_tint = mix(lidar_color_green * 0.25, lidar_color_cyan * 0.35, lum_c) * is_surface;
	vec3 edge_color = lidar_color_cyan * is_edge * 1.4;
	vec3 points_color = mix(lidar_color_green, lidar_color_cyan, 0.5) * point_cloud * 1.2;
	vec3 sweep_color = lidar_color_cyan * sweep_beam * (is_surface * 0.6 + 0.15);
	vec3 topo_color = lidar_color_green * topo_lines;
	
	vec3 final_color = base_dark + surface_tint + edge_color + points_color + topo_color + sweep_color;
	
	COLOR = vec4(final_color, 1.0);
}
