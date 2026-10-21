shader_type canvas_item;

// Color del fondo que quieres eliminar (por defecto verde)
uniform vec4 key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
// Tolerancia para capturar variaciones del verde
uniform float threshold : hint_range(0.0, 1.0) = 0.3;
// Suavizado de bordes
uniform float softness : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    vec4 current_color = texture(TEXTURE, UV);
    
    // Distancia entre el color actual y el color clave
    float diff = distance(current_color.rgb, key_color.rgb);
    
    // Calcula la transparencia según la tolerancia y el suavizado
    float alpha = smoothstep(threshold, threshold + softness, diff);
    
    COLOR = vec4(current_color.rgb, current_color.a * alpha);
}