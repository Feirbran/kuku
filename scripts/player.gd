# File: res://scripts/Player.gd
# Versione completa con gestione stato (dita, sanità, is_out) 
# e struttura base per attivazione abilità (inclusi costi sanità)

extends Node3D

# --- Segnali Emessi da questo Player ---
signal sanity_updated(player_id, new_sanity)           # Quando la sanità cambia
signal cooldown_updated(player_id, slot, remaining_rounds) # Quando un cooldown cambia
signal fingers_updated(player_id, remaining_fingers)  # Quando le dita cambiano
signal player_eliminated(player_id)                   # Quando il giocatore viene eliminato (dita <= 0)
signal player_breakdown(player_id)                    # Quando la sanità arriva a 0
# Aggiungi qui segnali specifici per abilità se necessario (es. per richiedere info al GM)
signal request_adjacent_info(requesting_player_id) 
signal request_card_info(requesting_player_id, target_player_id) 
signal request_dealer_choice(requesting_player_id) 

# --- Dati della Classe Assegnata ---
# Verrà popolata da GameManager tramite assign_class()
@export var class_data: CharacterClassData = null

# --- Stato Dinamico del Giocatore ---
var player_id: int = -1                 # ID univoco (0-9) assegnato dal GameManager
var fingers_remaining: int = 10        # Vite/Dita iniziali
var current_sanity: int = 100         # Sanità iniziale
var is_out: bool = false                # Se il giocatore è eliminato
var active_ability_1_cooldown_timer: int = 0 # Round rimanenti per cooldown slot 1
var active_ability_2_cooldown_timer: int = 0 # Round rimanenti per cooldown slot 2
# TODO: Aggiungere qui variabili per token (Vengeance, Intuizione) se necessario
# var vengeance_tokens: int = 0 
# var intuition_tokens: int = 0
# TODO: Aggiungere qui variabile per stato breakdown
# var is_in_breakdown: bool = false 

# --- Funzioni Base Godot ---

func _ready():
	# Codice eseguito all'avvio del nodo Player.
	# Al momento non fa molto, l'inizializzazione principale avviene in assign_class.
	# Potrebbe essere usato per ottenere riferimenti a nodi figli se Player.tscn diventasse più complesso.
	pass

# --- Inizializzazione e Stato ---

# Chiamata da GameManager all'inizio per configurare il giocatore
func assign_class(new_class_data: CharacterClassData, id: int):
	if new_class_data != null:
		self.class_data = new_class_data
		self.player_id = id
		print("Player (ID ", player_id, ") assegnata classe: ", class_data.display_name)
		
		# Resetta stato iniziale del giocatore:
		current_sanity = 100  # O valore base se diverso
		active_ability_1_cooldown_timer = 0
		active_ability_2_cooldown_timer = 0
		fingers_remaining = 10 
		is_out = false 
		# TODO: Resettare altri stati come token, breakdown, ecc.
		
		# Connetti segnali specifici della classe (se necessario, esempio per Pampinea)
		# if class_data.display_name == "La Comandante":
			# TODO: Connetti al segnale day_started del GameManager
			# if GameManager.has_signal("day_started"):
			#     if not GameManager.is_connected("day_started", Callable(self,"_on_day_started")):
			#         GameManager.day_started.connect(_on_day_started)
			# else:
			#     printerr("GameManager manca segnale day_started?")
			# print("Connessione segnale per Prima Voce (Pampinea) - IMPLEMENTARE!")

		# Emetti segnali iniziali per aggiornare l'UI
		emit_signal("sanity_updated", player_id, current_sanity)
		emit_signal("cooldown_updated", player_id, 1, 0)
		emit_signal("cooldown_updated", player_id, 2, 0)
		emit_signal("fingers_updated", player_id, fingers_remaining) 
	else:
		printerr("Tentativo di assegnare una classe nulla al Player (ID ", id, ")")

func reset_desperate_action_cooldown(day_num: int):
	# Usa il parametro 'day_num' invece di accedere a GameManager
	print("Player (ID ", player_id, "): Cooldown Azione Disperata resettato (Inizio Giorno ", day_num, ")")

	# Logica futura:
	# desperate_action_available = true
	# emit_signal("desperate_action_ready", player_id) 
	pass 

	
# Funzione per perdere una vita (chiamata da GameManager.lose_life)
func lose_finger():
	if is_out: return # Se già fuori, non fare nulla
		
	if fingers_remaining > 0:
		fingers_remaining -= 1
		print("Player (ID ", player_id, ") ha perso un dito! Rimaste: ", fingers_remaining)
		emit_signal("fingers_updated", player_id, fingers_remaining) # Notifica l'UI/GM
		
		# Controlla se il giocatore è eliminato ORA
		if fingers_remaining <= 0:
			_handle_elimination() 
			
		# TODO: Triggerare passive legate a perdita dito (es. Riscatto Nobile di Elissa)
		# if class_data and class_data.active_ability_2 and class_data.active_ability_2.ability_name == "Riscatto Nobile":
		#    # Attenzione: Era classificata come Attiva, ma triggerata qui
		#    print("Player (ID ", player_id, ") attiva Riscatto Nobile!")
		#    update_sanity(25) # Applico effetto direttamente o chiamo una _effect_ function?
		#    pass


# Funzione Getter per le dita (usata da GameManager per UI)
func get_fingers_remaining() -> int:
	return fingers_remaining

# Funzione interna per gestire l'eliminazione
func _handle_elimination():
	if is_out: return # Evita doppie chiamate
	print("!!!!!!!! Player (ID ", player_id, ") è stato ELIMINATO !!!!!!!!");
	is_out = true # Imposta lo stato interno
	emit_signal("player_eliminated", player_id) # Notifica il GameManager/altri
	# Logica aggiuntiva opzionale (nascondere nodo, disattivare processi)
	# visible = false 
	# set_process(false)
	pass


# --- Gestione Sanità ---

# Funzione per modificare la sanità (usata da costi abilità, effetti, ecc.)
func update_sanity(amount: int):
	if is_out: return # Non cambia sanità se fuori gioco
	
	var old_sanity = current_sanity
	current_sanity = clamp(current_sanity + amount, 0, 100) 
	
	if old_sanity != current_sanity:
		print("Player (ID ", player_id, ") sanità aggiornata a: ", current_sanity, " (Cambiamento: ", amount, ")")
		emit_signal("sanity_updated", player_id, current_sanity)
		
		# Controlla soglie critiche
		if current_sanity < 30 and old_sanity >= 30: 
			print("ATTENZIONE: Player (ID ", player_id, ") ha Sanità bassa!")
			# TODO: Applicare effetti negativi/penalità?
		elif current_sanity >= 30 and old_sanity < 30: 
			print("INFO: Player (ID ", player_id, ") ha recuperato Sanità sufficiente.")
			# TODO: Rimuovere effetti negativi?
			
		if current_sanity == 0 and old_sanity > 0: 
			_handle_breakdown() 

# Funzione interna per gestire il breakdown da Sanità 0
func _handle_breakdown():
	print("!!!!!! Player (ID ", player_id, ") ha avuto un BREAKDOWN (Sanità 0) !!!!!!")
	emit_signal("player_breakdown", player_id)
	# TODO: Implementare logica per perdita controllo, blocco skill, ecc.
	# var is_in_breakdown = true 
	pass


# --- Gestione Abilità Attive ---

# Tenta di usare l'abilità attiva nello slot specificato (1 o 2)
# Chiamata da GameManager (su input UI o decisione CPU)
func try_use_active_ability(slot: int, target_player_id: int = -1):
	if is_out: print("Player ", player_id, " è fuori, non può usare abilità."); return false
	# TODO: Controllare se è in breakdown? if is_in_breakdown: return false
	
	var ability_data: ActiveAbilityData
	
	# 1. Controlla classe caricata
	if class_data == null:
		printerr("Player (ID ", player_id, "): Classe non caricata!"); return false

	# 2. Ottieni dati abilità richiesta
	if slot == 1: ability_data = class_data.active_ability_1
	elif slot == 2: ability_data = class_data.active_ability_2
	else: printerr("Player (ID ", player_id, "): Slot abilità non valido: ", slot); return false

	if ability_data == null:
		printerr("Player (ID ", player_id, "): Slot ", slot, " vuoto per classe ", class_data.display_name); return false

	# 3. TODO: Controlla Fase di Attivazione (richiede info da GameManager sullo stato attuale)
	# var current_game_phase = GameManager.get_current_phase() # Ipotetico
	# match ability_data.activation_phase:
	#    ActiveAbilityData.ActivationPhase.BEFORE_ACTION_CONFIRM:
	#        if current_game_phase != GameManager.GameState.PLAYER_TURN: return false # O fase specifica pre-conferma
	#    ActiveAbilityData.ActivationPhase.ON_TURN_START:
	#        # Questo tipo di attivazione andrebbe gestito altrove, non qui?
	#        pass 
	#    # ... ecc ...

	# 4. Controlla Cooldown
	var current_cooldown_value = active_ability_1_cooldown_timer if slot == 1 else active_ability_2_cooldown_timer
	if current_cooldown_value > 0:
		print("Player (ID ", player_id, "): Abilità '", ability_data.ability_name, "' in cooldown per ", current_cooldown_value, " round.")
		return false

	# 5. Controlla Costo Sanità
	if current_sanity < ability_data.sanity_cost:
		print("Player (ID ", player_id, "): Sanità insufficiente per '", ability_data.ability_name, "'. Richiesti: ", ability_data.sanity_cost, ", Hai: ", current_sanity)
		return false

	# 6. TODO: Controlla Bersaglio (se richiesto)
	#    if ability_data.target_type == ActiveAbilityData.TargetType.OTHER_PLAYER and target_player_id == -1:
	#        printerr("Player (ID ", player_id, "): Abilità '", ability_data.ability_name, "' richiede un bersaglio!")
	#        return false
	#    if ability_data.target_type == ActiveAbilityData.TargetType.ADJACENT_SINGLE and target_player_id == -1:
	#        printerr("Player (ID ", player_id, "): Abilità '", ability_data.ability_name, "' richiede un bersaglio adiacente!")
	#        return false
	#    # ... altri controlli sul bersaglio (es. non fuori gioco?) ...

	# 7. TODO: Controlla Requisiti Speciali (Token, Carte)
	#    if ability_data.special_requirements.has("REQUIRES_INTUITION_TOKEN"):
	#        if intuition_tokens <= 0: return false
	#    if ability_data.special_requirements.has("REQUIRES_CARD_A_2_3_4"):
	#        var my_card = GameManager.get_my_card(player_id) # Funzione ipotetica
	#        if not my_card or not my_card.rank_name in ["A", "2", "3", "4"]: return false
	#    # ... ecc ...

	# --- Attivazione! ---
	print("Player (ID ", player_id, ") attiva '", ability_data.ability_name, "'...")

	# 8. Paga Costo Sanità
	if ability_data.sanity_cost > 0:
		update_sanity(-ability_data.sanity_cost)
		
	# 9. TODO: Consuma Token se necessario
	#    if ability_data.special_requirements.has("REQUIRES_INTUITION_TOKEN"):
	#        intuition_tokens -= 1 
	#        # Emetti segnale aggiornamento token?

	# 10. Imposta Cooldown (Implementeremo nel prossimo passo)
	# if ability_data.cooldown_rounds > 0:
	#     if slot == 1: active_ability_1_cooldown_timer = ability_data.cooldown_rounds
	#     elif slot == 2: active_ability_2_cooldown_timer = ability_data.cooldown_rounds
	#     emit_signal("cooldown_updated", player_id, slot, ability_data.cooldown_rounds)

	# 11. Esegui Effetto
	_execute_ability_effect(ability_data, target_player_id)
	
	return true # Successo


# Funzione "smistamento" per chiamare l'effetto specifico (Placeholder)
func _execute_ability_effect(ability_data: ActiveAbilityData, target_id: int):
	print(">>> ESECUZIONE EFFETTO per: ", ability_data.ability_name, " (Player ID ", player_id, ") Target ID: ", target_id)
	
	# Qui useremo 'match ability_data.ability_name:'
	match ability_data.ability_name:
		"Sguardo Circolare": _effect_sguardo_circolare() # Implementata sotto (placeholder)
		"Interrogatorio Diretto": _effect_interrogatorio_diretto(target_id) # Implementata sotto (placeholder)
		# Aggiungi qui i case per le altre abilità quando le implementi
		_: printerr("Effetto non implementato per ", ability_data.ability_name)

# --- Implementazione Effetti Specifici (Placeholder) ---

func _effect_sguardo_circolare():
	print("TODO Player ", player_id, ": Implementa logica Sguardo Circolare")
	# Emetti segnale al GameManager o UI per ottenere/mostrare info
	# emit_signal("request_adjacent_info", player_id) 
	pass 

func _effect_interrogatorio_diretto(target_player_id: int):
	if target_player_id == -1: printerr("Sguardo Circolare: Target non valido!"); return
	print("TODO Player ", player_id, ": Implementa logica Interrogatorio Diretto su Target ", target_player_id)
	# Emetti segnale al GameManager o UI per ottenere/mostrare info
	# emit_signal("request_card_info", player_id, target_player_id)
	pass
	
# Aggiungi qui altre funzioni _effect_...


# --- Gestione Cooldown e Aggiornamenti Fine Round ---

# Funzione per decrementare i cooldown (Chiamata da GameManager a inizio/fine round)
func decrement_cooldowns():
	var changed1 = false
	var changed2 = false
	if active_ability_1_cooldown_timer > 0:
		active_ability_1_cooldown_timer -= 1
		changed1 = true
	if active_ability_2_cooldown_timer > 0:
		active_ability_2_cooldown_timer -= 1
		changed2 = true
		
	# Emetti segnali solo se il cooldown è cambiato
	if changed1: emit_signal("cooldown_updated", player_id, 1, active_ability_1_cooldown_timer)
	if changed2: emit_signal("cooldown_updated", player_id, 2, active_ability_2_cooldown_timer)


# Funzione chiamata da GameManager alla fine del round (per passive, ecc.)
# Nota: Potremmo aver bisogno di più info passate dal GM (es. chi ha perso dito)
func end_of_round_update():
	print("DEBUG Player ", player_id, ": Eseguo aggiornamenti fine round.")
	# Qui possiamo gestire passive che triggerano a ROUND_END
	if class_data and class_data.passive_ability:
		var passive = class_data.passive_ability
		if passive.trigger_event == PassiveAbilityData.TriggerEvent.ROUND_END:
			# Chiama una funzione helper per gestire la logica della passiva specifica
			_execute_passive_effect(passive)


# --- Gestione Abilità Passive (Esempio Smistamento) ---

func _execute_passive_effect(passive_data: PassiveAbilityData):
	print(">>> ESECUZIONE PASSIVA per: ", passive_data.ability_name, " (Player ID ", player_id, ")")
	match passive_data.ability_name:
		"Intuito Macabro": _passive_intuito_macabro(passive_data)
		"Favore Reale": _passive_favore_reale(passive_data)
		"Flusso Narrativo": _passive_flusso_narrativo(passive_data)
		# Aggiungi qui altri case per passive che triggerano su ROUND_END
		_: print("Nessuna logica ROUND_END implementata per passiva ", passive_data.ability_name)

# --- Implementazione Logica Passiva Specifica (Placeholder) ---

func _passive_intuito_macabro(p_data: PassiveAbilityData):
	print("TODO Player ", player_id, ": Implementa logica Intuito Macabro (Filomena)")
	# 1. Controlla se ha fatto una predizione valida su chi perdeva dito
	#    (Richiede stato salvato della predizione e info dal GM su chi ha perso)
	#    Se indovina -> update_sanity(p_data.passive_parameters.guess_sanity_reward)
	# 2. Controlla se è sopravvissuto al round
	#    var i_lost_finger = ... (chiedi a GM o controlla stato interno?)
	#    if not i_lost_finger:
	#        var my_card = ... (chiedi a GM?)
	#        if my_card and get_card_value(my_card) in p_data.passive_parameters.token_gain_on_survival_ranks:
	#           # Gain intuition token (se non al max)
	#           print("Guadagnato Token Intuizione!")
	pass

func _passive_favore_reale(p_data: PassiveAbilityData):
	print("TODO Player ", player_id, ": Implementa logica Favore Reale (Emilia)")
	# 1. Controlla se ha perso dito nel round (vedi sopra)
	# 2. Se non ha perso, controlla la carta che aveva (last_card?)
	#    var my_last_card = ... 
	#    if my_last_card and my_last_card.rank_name in p_data.passive_parameters.condition_ranks:
	#        update_sanity(p_data.passive_parameters.sanity_gain)
	pass
	
func _passive_flusso_narrativo(p_data: PassiveAbilityData):
	print("TODO Player ", player_id, ": Implementa logica Flusso Narrativo (Panfilo)")
	# 1. Controlla se ha perso dito nel round
	# 2. Se non ha perso, incrementa contatore peaceful_rounds_counter
	# 3. Se ha perso, resetta contatore a 0
	# 4. Se contatore >= p_data.passive_parameters.peaceful_rounds_needed:
	#    # Concedi carica gratuita se non già presente (max 1)
	#    # has_free_ability_charge = true
	#    print("Ottenuta carica gratuita abilità!")
	#    # Resetta contatore? O si resetta solo quando la carica viene usata? Da definire.
	pass
	
# --- Altri Handler per Passive (Trigger diversi da ROUND_END) ---

# Esempio per Pampinea: connessa al segnale day_started del GM
# func _on_day_started():
#     if class_data and class_data.display_name == "La Comandante": 
#         print("Player ", player_id, " (Pampinea): Attivazione Passiva 'Prima Voce'!")
#         emit_signal("request_dealer_choice", player_id)

# Esempio per Fiammetta: connessa a un ipotetico segnale card_received del GM o chiamata internamente
# func _on_card_received(new_card: CardData):
#     if class_data and class_data.passive_ability.ability_name == "Animo Ardente":
#        var params = class_data.passive_ability.passive_parameters
#        if new_card and new_card.rank_name == params.trigger_rank:
#            if vengeance_tokens < params.max_tokens:
#                vengeance_tokens += 1
#                print("Player ", player_id, " guadagna Token Vengeance!")
#                # Emetti segnale UI token?

# Esempio per Filostrato: connessa a un ipotetico segnale other_player_lost_finger del GM
# func _on_other_player_lost_finger(other_player_id: int, sanity_damage_to_apply: int):
#     if class_data and class_data.passive_ability.ability_name == "Rassegnazione":
#         print("Player ", player_id, " (Filostrato): Ignora perdita sanità per P", other_player_id)
#         return 0 # Modifica il danno a 0
#     else:
#         return sanity_damage_to_apply # Danno normale

# Assicurati che questa funzione venga chiamata dal match in _execute_ability_effect

func _get_card_rank_category(card: CardData) -> String:
	if card == null: return "N/A"
	# Assumendo che CardData abbia 'rank_name' (String: "A".."K") e opz. 'is_jolly' (bool)
	if card.has("is_jolly") and card.is_jolly: return "Jolly" 
	
	match card.rank_name:
		"K": return "Re"
		"Q": return "Regina/Cavallo" 
		"J": return "Fante"
		"A": return "Asso"
		_: 
			# Controlla se il rank è un numero valido come stringa
			if card.rank_name.is_valid_int():
				return "Numero"
			else:
				# Se non è un numero e non è una figura/asso/jolly, è sconosciuto
				return "Sconosciuto (%s)" % card.rank_name 
