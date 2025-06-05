#version 330

in vec4 fragColor;
in vec2 fragTexCoord;

uniform sampler2D texture0;
uniform vec4 col_override;

out vec4 finalColor;

void main() {
	vec4 texelColor = texture(texture0, fragTexCoord);
	finalColor = vec4(mix(texelColor.rgb, col_override.rgb, col_override.a), texelColor.a);
	// finalColor = fragColor;
}