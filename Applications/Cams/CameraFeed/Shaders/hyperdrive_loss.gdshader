shader_type canvas_item;

uniform float noise_intensity : hint_range(0.0, 1.0) = 0.85;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.75;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec4 static_color : source_color = vec4(0.2, 0.75, 0.95, 1.0);
uniform vec4 background_color : source_color = vec4(0.03, 0.05, 0.08, 0.96);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float time = TIME * 14.0;
	
	// Linee di glitch orizzontale e salti di fase
	float jump = floor(uv.y * 32.0 + time);
	float glitch = step(0.90, hash(vec2(jump, floor(time))));
	uv.x += (hash(vec2(jump * 2.0, time)) - 0.5) * 0.09 * glitch * glitch_intensity;
	
	// Rumore bianco ad alta frequenza
	float n = hash(uv * vec2(280.0, 190.0) + vec2(time * 4.1, -time * 2.3));
	
	// Linee di scansione CRT
	float scanline = sin(uv.y * 350.0 + TIME * 12.0) * scanline_strength;
	
	// Fascia orizzontale di scorrimento tachionico
	float bar = sin(uv.y * 4.0 - TIME * 3.5);
	bar = smoothstep(0.75, 1.0, bar) * 0.2;
	
	float val = clamp(n * noise_intensity + bar - scanline, 0.0, 1.0);
	
	// Interpolazione tra sfondo profondo e bagliore statico tachionico
	vec3 col = mix(background_color.rgb, static_color.rgb, val * 0.5);
	col += vec3(pow(n, 3.5) * 0.55);
	
	COLOR = vec4(col, background_color.a);
}
