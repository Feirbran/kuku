# card_visual.gd
extends Sprite3D
class_name CardVisual

@export var _card_data: CardData:
	set(new_data):
		set_card_data_internal(new_data)

var card_data: CardData = null
@export var texture_back: Texture2D
var is_face_up: bool = false

func _ready():
	if card_data == null:
		show_back()
	else:
		if is_face_up:
			show_front()
		else:
			show_back()
	# Configura l'Area3D per la rilevazione dei clic (assicurati che esista nella scena)
	if get_node_or_null("ClickArea"):
		get_node("ClickArea").connect("input_event", Callable(get_parent(), "_on_card_clicked").bind([self]))

func set_card_data_internal(new_data: CardData):
	if new_data == null:
		printerr("Tentativo di assegnare dati null a CardVisual")
		card_data = null
		texture = texture_back
		return

	card_data = new_data
	if is_face_up:
		show_front()
	else:
		show_back()

func show_front():
	if card_data != null and card_data.texture_front != null:
		texture = card_data.texture_front
		is_face_up = true
	else:
		texture = texture_back
		is_face_up = false

func show_back():
	if texture_back != null:
		texture = texture_back
	else:
		texture = null
	is_face_up = false

func flip():
	if is_face_up:
		show_back()
	else:
		show_front()

func get_value() -> int:
	if card_data != null:
		return card_data.value
	else:
		printerr("Tentativo di ottenere valore da CardVisual senza CardData!")
		return -1

func set_physics_active(active: bool):
	if get_node_or_null("ClickArea"):
		get_node("ClickArea").monitoring = active
		get_node("ClickArea").mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
