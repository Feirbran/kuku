# File: res://scripts/Player.gd
extends Node3D

# --- Segnali ---
signal sanity_updated(player_id, new_sanity)
signal cooldown_updated(player_id, slot, remaining_rounds)
signal fingers_updated(player_id, remaining_fingers) # <-- NUOVO SEGNALE PER VITE
signal player_eliminated(player_id)
signal player_breakdown(player_id)
# ... (altri segnali per abilità) ...

# --- Dati Classe ---
@export var class_data: CharacterClassData = null

# --- Stato Giocatore ---
var player_id: int = -1 
var fingers_remaining: int = 10 # Valore di default
var current_sanity: int = 100 
var is_out: bool = false # <-- AGGIUNTO STATO 'is_out' INTERNO
var active_ability_1_cooldown_timer: int = 0
var active_ability_2_cooldown_timer: int = 0

func _ready():
	# ... (codice _ready esistente) ...
	pass

# Chiamata da GameManager all'inizio
func assign_class(new_class_data: CharacterClassData, id: int):
	if new_class_data != null:
		self.class_data = new_class_data
		self.player_id = id
		print("Player (ID ", player_id, ") assegnata classe: ", class_data.display_name)
		
		# Connetti segnali specifici classe...
		# if class_data.display_name == "La Comandante": ...

		# Resetta stato iniziale del giocatore:
		current_sanity = 100 
		active_ability_1_cooldown_timer = 0
		active_ability_2_cooldown_timer = 0
		fingers_remaining = 10 # <-- Assicura il valore iniziale a 10
		is_out = false # <-- Assicura che non sia fuori all'inizio
		
		# Emetti segnali iniziali per UI
		emit_signal("sanity_updated", player_id, current_sanity)
		emit_signal("cooldown_updated", player_id, 1, 0)
		emit_signal("cooldown_updated", player_id, 2, 0)
		emit_signal("fingers_updated", player_id, fingers_remaining) # Emetti stato iniziale vite
	else:
		printerr("Tentativo di assegnare una classe nulla al Player (ID ", id, ")")

# --- Funzione per perdere una vita (chiamata da GameManager) ---
func lose_finger():
	if is_out: # Se già fuori, non fare nulla
		return 
		
	if fingers_remaining > 0:
		fingers_remaining -= 1
		print("Player (ID ", player_id, ") ha perso un dito! Rimaste: ", fingers_remaining)
		emit_signal("fingers_updated", player_id, fingers_remaining) # Notifica l'UI
		
		# Controlla se il giocatore è eliminato ORA
		if fingers_remaining <= 0:
			_handle_elimination() # Chiama la funzione interna per gestire l'eliminazione
			
		# TODO: Qui puoi aggiungere logica per triggerare passive legate alla perdita di dita
		# if class_data and class_data.passive_ability.name == "Riscatto Nobile":
		#    _effect_riscatto_nobile() 

# --- Funzione Getter (opzionale ma buona pratica) ---
func get_fingers_remaining() -> int:
	return fingers_remaining

# --- Funzione interna per gestire l'eliminazione ---
func _handle_elimination():
	print("!!!!!!!! Player (ID ", player_id, ") è stato ELIMINATO !!!!!!!!");
	is_out = true # Imposta lo stato interno
	emit_signal("player_eliminated", player_id) # Notifica il GameManager/altri
	# Qui puoi anche nascondere il nodo o disattivare processi se necessario
	# visible = false 
	# set_process(false)
	
# ... (resto delle funzioni: try_use_active_ability, _execute_ability_effect, 
#      end_of_round_update, update_sanity, _handle_breakdown, ecc.) ...
