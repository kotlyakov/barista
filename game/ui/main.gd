extends Control
func _ready() -> void:
 var title = Label.new()
 title.text = "Путь баристы\nТехнический прототип; оформление не утверждено"
 title.position = Vector2(40,40)
 title.add_theme_font_size_override("font_size",32)
 add_child(title)
