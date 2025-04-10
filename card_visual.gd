# card_visual.gd (Versione Rivista e Semplificata)
extends Sprite3D
class_name CardVisual

# Assegna la texture del dorso nell'Inspector
@export var texture_back: Texture2D

# Variabile che contiene i dati della carta.
# Ha un setter che aggiorna la visuale quando viene modificata.
var card_data: CardData = null:
	set(new_data):
		#print("Setting card_data: ", new_data) # Debug
		var changed = card_data != new_data
		card_data = new_data
		# Aggiorna la visuale solo se il nodo è pronto e i dati sono cambiati
		if is_inside_tree() and changed:
			_update_visuals()

# Stato interno
var is_face_up: bool = false

# Riferimenti ai figli (assicurati che esistano in CardVisual.tscn)
@onready var card_animator: AnimationPlayer = get_node_or_null("CardAnimator")
@onready var click_area = get_node_or_null("ClickArea") # Es. Area3D

func _ready():
	# All'avvio mostra sempre il dorso come stato predefinito
	show_back()

	# Connetti segnale click (assicurati che il parent abbia _on_card_clicked)
	if click_area and get_parent() and get_parent().has_method("_on_card_clicked"):
		# Collega input_event di Area3D o CollisionObject3D
		if click_area.has_signal("input_event"):
			click_area.connect("input_event", Callable(get_parent(), "_on_card_clicked").bind(self))
		else:
			printerr("ClickArea non ha il segnale input_event?")
	elif click_area:
		printerr("Parent di CardVisual (%s) non ha _on_card_clicked." % get_parent().name if get_parent() else "N/A")


# Aggiorna la texture basandosi sullo stato is_face_up
# Viene chiamato automaticamente quando card_data viene impostato
func _update_visuals():
	if is_face_up:
		show_front()
	else:
		show_back()

# Mostra il fronte della carta
func show_front():
	is_face_up = true
	if card_data != null and card_data.texture_front != null:
		self.texture = card_data.texture_front
		# Rimuoviamo il flip orizzontale per ora, dovrebbe bastare cambiare texture
		self.scale.x = 1.0
		# print("Mostro fronte: ", card_data.rank_name) # Debug
	else:
		# Se non abbiamo dati validi, mostra nulla o texture di errore, NON il dorso
		printerr("Impossibile mostrare fronte: card_data (%s) o texture_front (%s) non validi." % [str(card_data != null), str(card_data.texture_front != null) if card_data else "N/A"])
		self.texture = null # O assegna una texture di errore placeholder
		self.scale.x = 1.0

	# stop_rotation_animation() # Gestione animazione opzionale

# Mostra il dorso della carta
func show_back():
	is_face_up = false
	if texture_back != null:
		self.texture = texture_back
	else:
		printerr("Texture_back non assegnata a CardVisual nell'inspector!")
		self.texture = null # Fallback a nulla se manca dorso
	self.scale.x = 1.0

	# start_rotation_animation() # Gestione animazione opzionale

# Inverte la faccia visibile della carta
func flip():
	if is_face_up:
		show_back()
	else:
		show_front()

# Restituisce il valore della carta (da CardData)
func get_value() -> int:
	if card_data != null:
		return card_data.value
	printerr("CardVisual: Tentativo di get_value con card_data null.")
	return -1 # Valore di errore

# Abilita/disabilita l'interazione fisica/click
func set_physics_active(active: bool):
	if click_area:
		# Adatta in base al tipo di nodo ClickArea (CollisionObject3D, Area3D, Control)
		var collision_shape = click_area.get_node_or_null("CollisionShape3D") # Se ClickArea è Area3D/CollisionObject3D
		if collision_shape:
			collision_shape.disabled = not active
		elif click_area is Control: # Se ClickArea fosse un nodo Control
			click_area.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
		# Potrebbe servire anche input_pickable per Sprite3D se non usi Area3D
		# self.input_pickable = active


# --- Funzioni Animazione (invariate, verifica nomi animazioni) ---
func start_rotation_animation():
	if is_instance_valid(card_animator) and card_animator.has_animation("SlowRotateX"):
		card_animator.play("SlowRotateX")

func stop_rotation_animation():
	if is_instance_valid(card_animator) and card_animator.is_playing():
		card_animator.stop()
