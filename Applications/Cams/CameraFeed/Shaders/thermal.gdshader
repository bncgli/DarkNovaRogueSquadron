shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float thermal_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float thermal_contrast : hint_range(0.5, 3.0) = 1.5;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;
uniform float noise_grain : hint_range(0.0, 0.2) = 0.03;

// High contrast FLIR thermal palette:
// 0.00 -> Black / Navy
// 0.25 -> Deep Violet / Purple
// 0.50 -> Crimson / Orange-Red
// 0.75 -> Bright Amber / Yellow
// 1.00 -> White / Thermal Bloom
vec3 get_thermal_color(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c_black = vec3(0.02, 0.01, 0.06);
	vec3 c_purple = vec3(0.42, 0.04, 0.62);
	vec3 c_orange = vec3(0.95, 0.32, 0.02);
	vec3 c_yellow = vec3(1.0, 0.88, 0.15);
	vec3 c_white = vec3(1.0, 1.0, 1.0);

	if (t < 0.25) {
		return mix(c_black, c_purple, t / 0.25);
	} else if (t < 0.50) {
		return mix(c_purple, c_orange, (t - 0.25) / 0.25);
	} else if (t < 0.75) {
		return mix(c_orange, c_yellow, (t - 0.50) / 0.25);
	} else {
		return mix(c_yellow, c_white, (t - 0.75) / 0.25);
	}
}

float pseudo_noise(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 src = texture(screen_texture, SCREEN_UV);
	
	// Calcolo luminosità standard
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	
	// Riconoscimento termico: motori, propulsori e reattori sono caldi (canali R ed emissioni luminose)
	float heat_boost = max(0.0, src.r - src.b) * 0.35 + max(0.0, src.g - src.b) * 0.15;
	float heat_val = clamp((lum + heat_boost) * thermal_contrast * thermal_intensity, 0.0, 1.0);
	
	// Micro disturbo sensore FLIR e linee di scansione termica
	float noise = (pseudo_noise(SCREEN_UV + vec2(TIME * 0.05, 0.0)) - 0.5) * noise_grain;
	float scanline = sin(SCREEN_UV.y * 400.0) * scanline_strength;
	
	float final_heat = clamp(heat_val + noise - scanline, 0.0, 1.0);
	vec3 thermal_rgb = get_thermal_color(final_heat);
	
	COLOR = vec4(thermal_rgb, 1.0);
}
