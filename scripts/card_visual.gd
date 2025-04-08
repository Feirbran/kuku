# card_visual.gd
extends Sprite3D
class_name CardVisual

# Variabile per contenere i dati della carta (seme, valore, texture, ecc.)
# La setter `set_card_data` verrà chiamata automaticamente quando assegnamo un valore a questa variabile
@export var card_data: CardData:
	set(new_data):
		set_card_data(new_data)

# Texture per il retro della carta (opzionale, da impostare nell'inspector)
@export var texture_back: Texture2D

var is_face_up: bool = false # La carta è scoperta o coperta?

# Chiamato quando il nodo è pronto
func _ready():
	# All'inizio, se non abbiamo dati, mostra il retro (se esiste)
	if card_data == null:
		show_back()
	else:
		# Se i dati sono stati assegnati prima di _ready, mostra la faccia corretta
		if is_face_up:
			show_front()
		else:
			show_back()

# Funzione per impostare i dati E aggiornare la texture
func set_card_data(new_data: CardData):
	if new_data == null:
		printerr("Tentativo di assegnare dati null a CardVisual")
		card_data = null
		texture = texture_back # Mostra il retro se i dati sono null
		return

	card_data = new_data
	# Aggiorna la texture visibile in base allo stato (coperta/scoperta)
	if is_face_up:
		show_front()
	else:
		# Se abbiamo appena ricevuto i dati, probabilmente vogliamo mostrarla coperta all'inizio
		# o potremmo voler decidere lo stato prima di chiamare questa funzione.
		# Per ora, la mettiamo coperta di default quando i dati vengono impostati.
		show_back()


# Mostra il fronte della carta
func show_front():
	if card_data != null and card_data.texture_front != null:
		texture = card_data.texture_front
		is_face_up = true
	else:
		# Se non c'è texture fronte, mostra il retro o nulla
		texture = texture_back
		is_face_up = false # Considerala coperta se non può mostrare il fronte

# Mostra il retro della carta
func show_back():
	if texture_back != null:
		texture = texture_back
	else:
		# Se non c'è texture per il retro, potremmo renderla invisibile o mostrare un placeholder
		texture = null # Rende lo sprite invisibile se non ha texture
	is_face_up = false

# Funzione per girare la carta
func flip():
	if is_face_up:
		show_back()
	else:
		show_front()

# Funzione utile per ottenere il valore della carta per le comparazioni
func get_value() -> int:
	if card_data != null:
		return card_data.value
	else:
		printerr("Tentativo di ottenere valore da CardVisual senza CardData!")
		return -1 # Un valore non valido
