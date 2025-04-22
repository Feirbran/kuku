# File: res://scripts/Player.gd
extends Node3D

# --- DATI DELLA CLASSE ASSEGNATA ---
@export var class_data: CharacterClassData = null

# --- STATO DINAMICO DEL GIOCATORE ---
var player_id: int = -1 
var fingers_remaining: int = 10 
var current_sanity: int = 100 
var active_ability_1_cooldown_timer: int = 0
var active_ability_2_cooldown_timer: int = 0

# --- Segnali (Utili per comunicare con UI o GameManager) ---
signal sanity_updated(player_id, new_sanity)
signal cooldown_updated(player_id, slot, remaining_rounds)
signal request_adjacent_info(requesting_player_id) # Per Sguardo Circolare
signal request_card_info(requesting_player_id, target_player_id) # Per Interrogatorio Diretto
signal request_dealer_choice(requesting_player_id) # Per Prima Voce
signal player_eliminated(player_id)
signal player_breakdown(player_id)


func _ready():
	if class_data != null:
		print("Player (ID ", player_id, ") inizializzato con la classe: ", class_data.display_name)
		# Connetti qui i segnali se necessario, es. per la passiva
		# if class_data.display_name == "La Comandante":
		#    GameManager.day_started.connect(_on_day_started) # Assumendo esista un segnale globale o singleton GameManager
	else:
		print("ATTENZIONE: Nessuna classe assegnata al Player (ID ", player_id, ") in _ready!")


# --- FUNZIONI PER GESTIRE LE ABILITÀ ---

# Modificata per accettare un bersaglio opzionale
func try_use_active_ability(slot: int, target_player_id: int = -1):
	var ability_data: ActiveAbilityData
	
	# 1. Controlli base (classe caricata?)
	if class_data == null:
		printerr("Player (ID ", player_id, "): Classe non caricata!")
		return false # Restituisce fallimento

	# 2. Ottieni dati abilità
	if slot == 1: ability_data = class_data.active_ability_1
	elif slot == 2: ability_data = class_data.active_ability_2
	else: printerr("Player (ID ", player_id, "): Slot non valido: ", slot); return false

	if ability_data == null:
		printerr("Player (ID ", player_id, "): Slot ", slot, " vuoto per classe ", class_data.display_name); return false

	# 3. Controlla Cooldown
	var current_cooldown_value = active_ability_1_cooldown_timer if slot == 1 else active_ability_2_cooldown_timer
	if current_cooldown_value > 0:
		print("Player (ID ", player_id, "): Abilità '", ability_data.ability_name, "' in cooldown per ", current_cooldown_value, " round.")
		return false

	# 4. Controlla Sanità
	if current_sanity < ability_data.sanity_cost:
		print("Player (ID ", player_id, "): Sanità insufficiente per '", ability_data.ability_name, "'. Richiesti: ", ability_data.sanity_cost, ", Hai: ", current_sanity)
		return false
		
	# 5. Controlla se l'abilità richiede un bersaglio e se è stato fornito
	#    (Aggiungeremo un campo 'requires_target' a ActiveAbilityData?)
	#    Per ora, lo controlliamo manualmente per Interrogatorio Diretto
	if ability_data.ability_name == "Interrogatorio Diretto" and target_player_id == -1:
		printerr("Player (ID ", player_id, "): 'Interrogatorio Diretto' richiede un bersaglio!")
		return false

	# --- Attivazione ---
	print("Player (ID ", player_id, ") attiva '", ability_data.ability_name, "'...")

	# Paga costo
	update_sanity(-ability_data.sanity_cost) # Usiamo la funzione helper

	# Imposta cooldown
	if slot == 1:
		active_ability_1_cooldown_timer = ability_data.cooldown_rounds
		emit_signal("cooldown_updated", player_id, 1, active_ability_1_cooldown_timer)
	elif slot == 2:
		active_ability_2_cooldown_timer = ability_data.cooldown_rounds
		emit_signal("cooldown_updated", player_id, 2, active_ability_2_cooldown_timer)
	print("Player (ID ", player_id, ") Cooldown per slot ", slot, " impostato a ", ability_data.cooldown_rounds, " round.")

	# Esegui Effetto
	_execute_ability_effect(ability_data, target_player_id)
	return true # Restituisce successo


func _execute_ability_effect(ability_data: ActiveAbilityData, target_id: int):
	print(">>> ESECUZIONE EFFETTO per: ", ability_data.ability_name, " (Player ID ", player_id, ") Target ID: ", target_id)

	match ability_data.ability_name:
		# --- Pampinea ---
		"Sguardo Circolare":
			_effect_sguardo_circolare()
		"Interrogatorio Diretto":
			_effect_interrogatorio_diretto(target_id) 
			
		# --- Aggiungi qui altri case per altre abilità se/quando le implementi ---

		_:
			printerr("Player (ID ", player_id, "): Effetto non implementato per '", ability_data.ability_name, "'")


# --- Implementazione Effetti Specifici (Pampinea) ---

func _effect_sguardo_circolare():
	print("LOGICA EFFETTO: Sguardo Circolare (Pampinea)")
	# Questa funzione deve chiedere al GameManager o a un gestore dello stato di gioco
	# le informazioni sui giocatori adiacenti e le loro carte.
	# Esempio concettuale:
	# var adjacent_player_ids = GameManager.get_adjacent_players(player_id) # Funzione ipotetica
	# var results = {}
	# for adj_id in adjacent_player_ids:
	#     var card_data = GameManager.get_player_card(adj_id) # Funzione ipotetica
	#     if card_data:
	#         results[adj_id] = _get_card_rank_category(card_data) # Funzione helper locale
	#     else:
	#         results[adj_id] = "N/A"
	# print("Risultati Sguardo Circolare per Player ", player_id, ": ", results)
	# # TODO: Invece di stampare, inviare questi 'results' solo all'UI del giocatore 'player_id'.
	# # Potremmo emettere un segnale con i risultati:
	# emit_signal("request_adjacent_info", player_id) # GameManager risponderà con un altro segnale? O chiamerà una funzione di callback?
	# Oppure:
	# var info = GameManager.get_adjacent_card_info(player_id) # Funzione che fa tutto
	# UIManager.show_sguardo_circolare_info(player_id, info) # Mostra info all'UI giusta
	
	# Per ora, emettiamo solo un segnale generico per indicare la richiesta
	emit_signal("request_adjacent_info", player_id)
	print("Player ", player_id, " ha richiesto info sugli adiacenti (Sguardo Circolare).")


func _effect_interrogatorio_diretto(target_player_id: int):
	if target_player_id == -1: 
		printerr("Interrogatorio Diretto chiamato senza bersaglio valido!")
		return
	print("LOGICA EFFETTO: Interrogatorio Diretto (Pampinea) sul bersaglio ", target_player_id)
	# Simile a sopra, chiede info al GameManager sulla carta del bersaglio.
	# Esempio concettuale:
	# var target_card = GameManager.get_player_card(target_player_id)
	# var result_text = ""
	# if target_card:
	#     if target_card.rank in ["K", "Q", "J"]: # Assumendo che card abbia una prop 'rank'
	#         result_text = "Figura"
	#     else:
	#         result_text = "Altro"
	# else:
	#     result_text = "N/A"
	# print("Risultato Interrogatorio Diretto per Player ", player_id, " su Target ", target_player_id, ": ", result_text)
	# # TODO: Inviare 'result_text' solo all'UI del giocatore 'player_id'.
	# # Emettiamo un segnale per richiedere l'info:
	emit_signal("request_card_info", player_id, target_player_id)
	print("Player ", player_id, " ha richiesto info sulla carta del target ", target_player_id, " (Interrogatorio Diretto).")


# Funzione helper (esempio) per Sguardo Circolare
# func _get_card_rank_category(card):
#     if card.rank in ["K", "Q", "J"]: return "Figura"
#     if card.rank == "A": return "Asso"
#     if card.is_joker: return "Jolly" # Assumendo una prop 'is_joker'
#     # Altrimenti è un numero... (potrebbe essere più dettagliato)
#     return "Numero"


# --- Gestione Passiva Pampinea (Prima Voce) ---

# Questa funzione dovrebbe essere connessa (in _ready) al segnale 'day_started' 
# emesso dal GameManager, MA SOLO se questo player è Pampinea.
func _on_day_started():
	# Doppio controllo, anche se la connessione avviene solo per Pampinea
	if class_data and class_data.display_name == "La Comandante": 
		print("Player ", player_id, " (Pampinea): Attivazione Passiva 'Prima Voce'!")
		# TODO: Segnala all'UI di questo giocatore di mostrare l'interfaccia
		# per scegliere il mazziere per il primo round del giorno.
		# L'UI poi comunicherà la scelta al GameManager.
		emit_signal("request_dealer_choice", player_id)


# --- FUNZIONI DI AGGIORNAMENTO STATO ---

func end_of_round_update():
	if active_ability_1_cooldown_timer > 0:
		active_ability_1_cooldown_timer -= 1
		emit_signal("cooldown_updated", player_id, 1, active_ability_1_cooldown_timer)
	if active_ability_2_cooldown_timer > 0:
		active_ability_2_cooldown_timer -= 1
		emit_signal("cooldown_updated", player_id, 2, active_ability_2_cooldown_timer)
	# print("Player (ID ", player_id, ") fine round. Cooldowns: S1=", active_ability_1_cooldown_timer, ", S2=", active_ability_2_cooldown_timer)


func lose_finger():
	if fingers_remaining > 0:
		fingers_remaining -= 1
		print("Player (ID ", player_id, ") ha perso un dito! Rimaste: ", fingers_remaining)
		# TODO: Gestire trigger passivi su perdita dito (es. Elissa)
		if fingers_remaining <= 0:
			_handle_elimination()

# Modificata per emettere segnale
func update_sanity(change: int):
	var old_sanity = current_sanity
	current_sanity = clamp(current_sanity + change, 0, 100) 
	if old_sanity != current_sanity: # Emetti solo se cambia
		print("Player (ID ", player_id, ") sanità aggiornata a: ", current_sanity)
		emit_signal("sanity_updated", player_id, current_sanity)
		# Controlla soglie
		if current_sanity < 30: print("ATTENZIONE: Sanità bassa!")
		if current_sanity == 0: _handle_breakdown()


func _handle_elimination():
	print("!!!!!!!! Player (ID ", player_id, ") è stato ELIMINATO !!!!!!!!");
	emit_signal("player_eliminated", player_id)
	# Potrebbe nascondersi o disattivarsi
	# set_process(false)
	# set_physics_process(false)
	# visible = false 
	pass

func _handle_breakdown():
	print("!!!!!! Player (ID ", player_id, ") ha avuto un BREAKDOWN !!!!!!")
	emit_signal("player_breakdown", player_id)
	# Imposta stato interno, blocca azioni, ecc.
	pass

# Funzione per assegnare classe e ID (chiamata da fuori, es. GameManager)
func assign_class(new_class_data: CharacterClassData, id: int):
	if new_class_data != null:
		self.class_data = new_class_data
		self.player_id = id
		# Chiama _ready manualmente o sposta la logica qui? 
		# Meglio mettere la logica di connessione segnali qui.
		if class_data.display_name == "La Comandante":
			# TODO: Connetti al segnale day_started del GameManager
			# Assumendo GameManager sia un singleton autoload:
			# if GameManager.has_signal("day_started"):
			#     GameManager.day_started.connect(_on_day_started)
			# else:
			#     printerr("GameManager non ha il segnale 'day_started'?")
			print("Connessione segnale per Prima Voce (Pampinea) - IMPLEMENTARE!")
			
		print("Player (ID ", player_id, ") assegnata classe: ", class_data.display_name)
		# Resetta stato
		current_sanity = 100 
		active_ability_1_cooldown_timer = 0
		active_ability_2_cooldown_timer = 0
		fingers_remaining = 10
		# Emetti segnali iniziali per UI
		emit_signal("sanity_updated", player_id, current_sanity)
		emit_signal("cooldown_updated", player_id, 1, 0)
		emit_signal("cooldown_updated", player_id, 2, 0)
	else:
		printerr("Tentativo di assegnare una classe nulla al Player (ID ", id, ")")
