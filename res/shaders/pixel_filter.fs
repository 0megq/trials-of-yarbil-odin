#version 330

in vec2 fragTexCoord;
uniform sampler2D texture0;
out vec4 finalColor;

vec2 uv_klems(vec2 uv, vec2 texture_size) {
	vec2 pixels = uv * texture_size + 0.5;

	//tweak fractional values of the texture coordinate
	vec2 fl = floor(pixels);
	vec2 fr = fract(pixels);
	vec2 aa = fwidth(pixels) * 0.75;

	fr = smoothstep(vec2(0.5) - aa, vec2(0.5) + aa, fr);
	
	return (fl + fr - 0.5) / texture_size;
}

void main() {
	finalColor = texture(texture0, uv_klems(fragTexCoord, vec2(textureSize(texture0, 0))));
}
	