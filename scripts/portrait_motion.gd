extends TextureRect
## Portrait-only motion; anchored at the bottom of the card.
var species_id = ""
var clock = 0.0

func _process(delta: float) -> void:
	clock += delta
	var phase = clock * 2.5 + float(species_id.hash() % 12) + float(get_instance_id() % 37) * 0.271
	pivot_offset = Vector2(size.x * 0.5, size.y)
	scale = Vector2(1.0 + sin(phase) * 0.012, 1.0 - sin(phase) * 0.012)
	rotation = sin(phase * 0.65) * (0.018 if species_id in ["luna", "cloud"] else 0.008)
