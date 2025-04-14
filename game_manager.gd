# game_manager.gddioca
# Quarto giorno di sviluppo non voglio ancora morire, peccato che la parte grafica sia un incubo ma vabbè sta vita è fatta per soffrire e io sono qui per ballare fra uomini
# game_manager.gd (Tuo Codice + Correzione Finale get_card_value - Indentazione TAB)
extends Node3D
class_name GameManager

# --- Export per Scene e UI ---
@export var card_scene: PackedScene						# Scena CardVisual.tscn
@export var swap_button: Button						# Bottone Scambia (a dx)
@export var pass_button: Button						# Bottone Passa (normale)
@export var swap_to_deck_button: Button				# Bottone Scambia con Mazzo (Mazziere)
@export var pass_as_dealer_button: Button			# Bottone Passa (Mazziere)
@export var player_lives_labels: Array[Label]		# Array per Label vite giocatori (Size 4)
@export var last_hand_labels: Array[Label]			# Opzionale: Array per Label nomi ultima mano (Size 4)
@export var last_hand_textures: Array[TextureRect]	# Array per TextureRect ultima mano (Size 4)
@export var deck_position_marker: Marker3D			# Marker per posizione mazzo centrale
# REDATTO @export var notification_popup_scene: PackedScene # Scena per il popup "Cucù" (Blocco Re)
@onready var cucu_notification_label: Label = %EffectLabelKUKU
@onready var notification_timer: Timer = %KukuTimer
# --- Fine Export ---

var player_positions_node: Node3D = null
var num_players: int = 4
var dealer_index: int = 0
var current_player_index: int = 0
var players_data: Array[Dictionary] = []
var active_card_instances: Array[CardVisual] = []
var last_clicked_player_index: int = -1
const DECK_STACK_COUNT = 5 # Quante carte "visive" per la pila (puoi aggiustare 3, 5, 7...)
var deck_visual_instances: Array[Node3D] = [] # Array per contenere le istanze della pila

enum GameState { SETUP, DEALING, PLAYER_TURN, DEALER_SWAP, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP
# Assicurati che DeckSetupScene sia un Autoload


func _ready():
	# Controlli essenziali all'avvio
	if card_scene == null: printerr("!!! ERRORE: 'Card Scene' non assegnata!"); get_tree().quit(); return
	# Controlli bottoni (opzionali ma utili)
	if swap_button == null or pass_button == null or swap_to_deck_button == null or pass_as_dealer_button == null:
		printerr("!!! ATTENZIONE: Uno o più bottoni azione non assegnati!")
	# Controllo label vite (opzionale)
	if player_lives_labels.size() != num_players and player_lives_labels.size() > 0:
		printerr("!!! ATTENZIONE: Numero Label vite (%d) non corrisponde a num_players (%d)!" % [player_lives_labels.size(), num_players])
 # Inizializza il generatore di numeri casuali (fallo solo una volta)
	randomize()
	if cucu_notification_label == null:
		printerr("ATTENZIONE _ready: Nodo CucuNotificationLabel non trovato! Controllare percorso in @onready.")
	if notification_timer == null:
		printerr("ATTENZIONE _ready: Nodo NotificationTimer non trovato! Controllare percorso in @onready.")
	else:
		# Connetti il segnale timeout del timer alla funzione che nasconderà la label
		if not notification_timer.is_connected("timeout", Callable(self, "_on_notification_timer_timeout")):
			notification_timer.connect("timeout", Callable(self, "_on_notification_timer_timeout"))
	# ----------------------------------

	# --- Controlli essenziali all'avvio (codice esistente) ---
	if card_scene == null: printerr("!!! ERRORE: 'Card Scene' non assegnata!"); get_tree().quit(); return
	# ... (altri controlli in _ready) ...

	# --- Recupero PlayerPositions (codice esistente) ---
	player_positions_node = get_node_or_null("../PlayerPositions") # Adatta path se necessario
	if player_positions_node == null: printerr("!!! ERRORE: Impossibile trovare PlayerPositions!"); get_tree().quit(); return

	print("+++ GameManager pronto +++")

	# --- CREA VISUALE MAZZO (codice esistente) ---
	# ... (codice per creare la pila del mazzo) ...

	# --- Avvio gioco (codice esistente) ---
	call_deferred("start_game", num_players)
	# Controllo marker mazzo
	if deck_position_marker == null:
		printerr("!!! ATTENZIONE: 'Deck Position Marker' non assegnato nell'Inspector!")

	player_positions_node = get_node_or_null("../PlayerPositions") # Adatta path se necessario
	if player_positions_node == null: printerr("!!! ERRORE: Impossibile trovare PlayerPositions!"); get_tree().quit(); return

	print("+++ GameManager pronto +++")

	# --- CREA VISUALE MAZZO (se possibile) ---
	# Pulisci vecchie istanze (ora dall'array) se presenti da esecuzioni precedenti in editor?
	for instance in deck_visual_instances:
		if is_instance_valid(instance):
			instance.queue_free()
	deck_visual_instances.clear() # Svuota l'array

	# Crea la pila visuale del mazzo se il marker è valido
	if is_instance_valid(deck_position_marker) and card_scene != null:
		print("Creazione pila mazzo (%d istanze)..." % DECK_STACK_COUNT)
		# Ciclo per creare N istanze una sopra l'altra
		for i in range(DECK_STACK_COUNT):
			var instance = card_scene.instantiate() # Istanzia una carta visuale
			if instance is CardVisual:
				var visual = instance as CardVisual
				add_child(visual) # Aggiungi come figlio di GameManager

				# Imposta posizione base dal marker
				visual.global_position = deck_position_marker.global_position
				# Applica offset verticale CRESCENTE per creare la pila
				# Aggiusta il moltiplicatore (es. 0.002 o 0.003) per cambiare la spaziatura
				visual.global_position.y += 0.01 + i * 0.002

				# Applica la rotazione che hai trovato funzionare per sdraiarla!
				# Assicurati sia corretta (es. X=90, Y=90, Z=0?)
				visual.rotation_degrees = Vector3(90, 90, 0) # <-- USA LA TUA ROTAZIONE!

				visual.show_back() # Mostra dorso
				visual.set_physics_active(false) # Non cliccabile
				deck_visual_instances.append(visual) # Aggiungi all'array
			else:
				# Gestione errore se l'istanza non è del tipo giusto
				printerr("ERRORE: Istanza %d non è CardVisual." % i)
				if is_instance_valid(instance): instance.queue_free() # Pulisci istanza fallita

		# Controlla se sono state create istanze valide
		if not deck_visual_instances.is_empty(): print("Visuale mazzo (pila) creata.")
		else: printerr("ERRORE: Nessuna istanza valida creata per la pila del mazzo.")
	elif not is_instance_valid(deck_position_marker):
		printerr("ERRORE: deck_position_marker non valido in _ready!") # Log se marker non valido
	# --- FINE CREAZIONE VISUALE MAZZO ---

	call_deferred("start_game", num_players)

func _on_game_table_ready():
	print("Segnale ready da GameTable ricevuto!")
	# Aggiungi qui eventuale codice necessario
	pass

func start_game(p_num_players: int):
	print("Richiesta partita con %d giocatori." % p_num_players)
	current_state = GameState.SETUP
	num_players = p_num_players # Imposta num_players PRIMA di chiamare _reset_game

	_reset_game() # Chiama il reset che ora popola players_data

	# Controlla DOPO il reset se è andato a buon fine
	if players_data.is_empty():
		printerr("Reset fallito. players_data è ancora vuoto dopo _reset_game(). Controllare errori precedenti.")
		return # Esce da start_game

	# --- MODIFICA QUI: ASSEGNAZIONE MAZZIERE CASUALE ---
	if num_players > 0:
		dealer_index = randi() % num_players # Indice casuale da 0 a num_players-1
	else:
		dealer_index = 0 # Sicurezza nel caso improbabile che num_players sia 0
		printerr("ATTENZIONE: num_players è 0 o meno in start_game!")

	# Aggiorna il messaggio di log per riflettere la casualità
	print("Inizio partita. Mazziere Casuale: Player %d" % dealer_index)
	# ------------------------------------------------------

	call_deferred("_start_round") # Usa call_deferred per assicurare che _ready sia completato
	
func _reset_game():
	print("Resetting game...")
	# Pulisci istanze carte GIOCATORI (codice esistente OK)
	for card_instance in active_card_instances:
		if is_instance_valid(card_instance):
			card_instance.queue_free()
	active_card_instances.clear()
	players_data.clear() # Svuota i dati vecchi

	# --- NUOVO/MODIFICATO: Pulisci visuale mazzo (ARRAY) ---
	for instance in deck_visual_instances: # Itera sull'array
		if is_instance_valid(instance):
			instance.queue_free() # Cancella ogni istanza
	deck_visual_instances.clear() # Svuota l'array

	# --- NUOVO: INIZIALIZZAZIONE DATI GIOCATORI ---
	print("Inizializzazione dati per %d giocatori..." % num_players)
	if not is_instance_valid(player_positions_node):
		printerr("ERRORE CRITICO: PlayerPositions non valido durante il reset!")
		# Non possiamo continuare senza posizioni, quindi players_data resterà vuoto
		# e l'errore "Reset fallito" verrà giustamente stampato in start_game.
		return # Esce dalla funzione _reset_game

	var markers = player_positions_node.get_children()
	if markers.size() < num_players:
		printerr("ERRORE CRITICO: Non ci sono abbastanza Marker3D in PlayerPositions (%d) per %d giocatori!" % [markers.size(), num_players])
		# Anche qui, non possiamo inizializzare correttamente.
		return # Esce dalla funzione _reset_game

	for i in range(num_players):
		var player_marker = markers[i] if i < markers.size() else null
		if not player_marker is Marker3D:
			printerr("ATTENZIONE: Elemento %d in PlayerPositions non è un Marker3D!" % i)
			player_marker = null # Non usare un nodo non valido

		var new_player_data = {
			"id": i,
			"marker": player_marker, # Assegna il marker trovato (o null se c'è stato un problema)
			"lives": 3, # Numero iniziale di vite (puoi cambiarlo)
			"is_out": false,
			"is_cpu": (i != 0), # Giocatore 0 è umano, gli altri CPU (puoi cambiarlo)
			"card_data": [], # Array per i dati della carta (inizialmente vuoto)
			"visual_cards": [], # Array per le istanze CardVisual (inizialmente vuoto)
			"has_swapped_this_round": false,
			"last_card": null # Carta tenuta alla fine del round precedente
		}
		players_data.append(new_player_data)

	# Piccolo controllo per sicurezza
	if players_data.size() != num_players:
		printerr("ERRORE INASPETTATO: Dopo l'inizializzazione, players_data ha %d elementi invece di %d!" % [players_data.size(), num_players])
		# Potrebbe indicare un problema nel loop sopra o nei controlli marker
		# Non svuotiamo players_data qui, ma segnaliamo il problema grave.

	print("Dati giocatori inizializzati. Numero elementi in players_data: %d" % players_data.size())
	# --- FINE INIZIALIZZAZIONE DATI GIOCATORI ---

	# Ora l'aggiornamento dell'UI può funzionare perché players_data è popolato
	# Inizializza UI Vite
	if player_lives_labels.size() == players_data.size(): # Ora size() dovrebbe essere > 0
		print("Aggiornamento label vite...")
		for i in range(players_data.size()):
			if is_instance_valid(player_lives_labels[i]):
				player_lives_labels[i].text = "Vite P%d: %d" % [i, players_data[i].lives]
				player_lives_labels[i].visible = true
	elif player_lives_labels.size() > 0: # Logga solo se le label esistono ma non corrispondono
		printerr("ATTENZIONE: Numero Label vite (%d) non corrisponde ai giocatori inizializzati (%d)!" % [player_lives_labels.size(), players_data.size()])


	# Inizializza UI Ultima Mano
	if last_hand_textures.size() == players_data.size(): # Ora size() dovrebbe essere > 0
		print("Resetting UI ultima mano...")
		for i in range(last_hand_textures.size()):
			if is_instance_valid(last_hand_textures[i]):
				last_hand_textures[i].visible = false
			# Assicurati che l'indice sia valido anche per l'array delle label nomi
			if i < last_hand_labels.size() and is_instance_valid(last_hand_labels[i]):
				last_hand_labels[i].text = "P%d:" % i # Resetta anche il nome
	elif last_hand_textures.size() > 0: # Logga solo se le texture esistono ma non corrispondono
		printerr("ATTENZIONE: Numero TextureRect ultima mano (%d) non corrisponde ai giocatori inizializzati (%d)!" % [last_hand_textures.size(), players_data.size()])

	# Aggiungiamo un print finale per confermare che _reset_game è completato
	print("Reset game completato. Players_data size: %d" % players_data.size())


# --- Gestione Round ---
func _start_round():
	var active_players_count = 0; for player_data in players_data: if not player_data.is_out: active_players_count += 1
	if active_players_count <= 1: _handle_game_over(active_players_count); return
	print("\n--- Inizia Round. Mazziere: %d ---" % dealer_index); current_state = GameState.DEALING
	for i in range(players_data.size()):
		var player_data = players_data[i]
		for card_visual in player_data.visual_cards: if is_instance_valid(card_visual): active_card_instances.erase(card_visual); card_visual.queue_free()
		player_data.visual_cards.clear(); player_data.card_data.clear()
		if not player_data.is_out: player_data.has_swapped_this_round = false
		else: player_data.has_swapped_this_round = true
	DeckSetupScene.reset_and_shuffle(); _deal_initial_cards()
	if current_state == GameState.GAME_OVER: return
	current_player_index = get_next_active_player(dealer_index, false)
	if current_player_index == -1: printerr("ERRORE: Nessun giocatore attivo!"); _handle_game_over(0); return
	current_state = GameState.PLAYER_TURN; print("Carte distribuite. Tocca a player %d." % current_player_index)
	_update_player_action_buttons(); _update_deck_visual()
	if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_turn")

func _deal_initial_cards():
	print("Distribuzione..."); var main_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(main_camera): printerr("ERRORE: Camera non trovata!"); current_state = GameState.GAME_OVER; return
	for i in range(players_data.size()):
		if players_data[i].is_out: continue
		var player_marker: Marker3D = players_data[i]["marker"]; if not player_marker: continue
		var drawn_card_data: CardData = DeckSetupScene.draw_card()
		if drawn_card_data == null: printerr("ERRORE: Mazzo finito!"); current_state = GameState.GAME_OVER; return
		if not drawn_card_data is CardData: printerr("ERRORE: draw_card() tipo non valido!"); current_state = GameState.GAME_OVER; return
		players_data[i]["card_data"] = [drawn_card_data]
		var card_instance = card_scene.instantiate() as CardVisual; if not card_instance: continue
		card_instance.card_data = drawn_card_data; add_child(card_instance)
		players_data[i]["visual_cards"] = [card_instance]; active_card_instances.append(card_instance)
		var card_position = player_marker.global_transform.origin + Vector3(0, 0.1, 0)
		card_instance.global_transform.origin = card_position
		card_instance.look_at(main_camera.global_transform.origin, Vector3.UP); card_instance.rotation.x = deg_to_rad(-90)
		if i == 0: card_instance.show_front(); card_instance.set_physics_active(true)
		else: card_instance.show_back(); card_instance.set_physics_active(false)
	print("Carte distribuite.")
	_update_deck_visual() # Aggiorna visibilità mazzo

# --- Gestione Turni e Azioni ---
func _advance_turn():
	var next_player_candidate = -1; var current_check = current_player_index
	for _i in range(players_data.size()):
		current_check = (current_check + 1) % players_data.size()
		if current_check != dealer_index and not players_data[current_check].is_out and not players_data[current_check].has_swapped_this_round:
			next_player_candidate = current_check; break
		if current_check == current_player_index: break
	if next_player_candidate != -1:
		current_player_index = next_player_candidate
		print("Avanzamento turno. Tocca a player %d." % current_player_index); current_state = GameState.PLAYER_TURN
		_update_player_action_buttons(); _update_deck_visual()
		# --- GESTIONE SALTO CAVALLO (Q) MANCANTE ---
		if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_turn")
	else: _go_to_dealer_phase()
func _go_to_dealer_phase():
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out:
		print("Mazziere %d non valido/fuori." % dealer_index); call_deferred("_end_round"); return
	current_player_index = dealer_index; current_state = GameState.DEALER_SWAP
	print("Fase Mazziere (Player %d)." % current_player_index)
	_update_player_action_buttons(); _update_deck_visual()
	if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_dealer_turn")

# --- Funzioni Handler Bottoni UI ---
func _on_pass_turn_button_pressed():
	print(">> Pass Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
	if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
		print("Umano passa (tiene)."); _player_action(0, "hold")
	else: print("   -> Azione bottone Passa non valida ora.")
func _on_swap_button_pressed():
	print(">> Swap Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
	if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
		print("Bottone 'Scambia' premuto.")
		var target_player_index = get_player_to_right(0)
		if target_player_index != -1:
			print("Tentativo scambio (bottone) 0 -> %d (dx)" % target_player_index); _player_action(0, "swap", target_player_index)
		else: print("Nessun giocatore valido a destra.")
	else: print("   -> Azione bottone Scambia non valida ora.")
func _on_swap_to_deck_pressed():
	print(">> SwapDeck Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
	if current_state == GameState.DEALER_SWAP and current_player_index == 0 and not players_data[0].is_cpu:
		print("Bottone 'Scambia con Mazzo' premuto."); _dealer_action("swap_deck")
	else: print("   -> Azione 'Scambia con Mazzo' non valida ora.")
func _on_pass_as_dealer_pressed():
	print(">> PassDealer Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
	if current_state == GameState.DEALER_SWAP and current_player_index == 0 and not players_data[0].is_cpu:
		print("Bottone 'Passa (Mazziere)' premuto."); _dealer_action("pass")
	else: print("   -> Azione 'Passa (Mazziere)' non valida ora.")
func _on_card_clicked(_card_visual: CardVisual): print("Click su carta ignorato (usare bottoni).")

# --- Azioni Gioco (Logica Interna) ---
#AZIONI GIOCATORE UMANO
func _player_action(player_index: int, action: String, target_player_index: int = -1):
	if player_index < 0 or player_index >= players_data.size() or players_data[player_index].is_out:
		print("Azione annullata: Giocatore %d non valido o fuori." % player_index)
		return
	if players_data[player_index].has_swapped_this_round:
		print("Azione annullata: Giocatore %d ha già agito." % player_index)
		return # Già agito

	var my_card: CardData = _get_valid_carddata_from_player(player_index, "_pa my")
	if my_card == null:
		printerr("ERRORE CRITICO (_player_action): Giocatore %d non ha dati carta validi!" % player_index)
		# Forse forzare un 'hold' o gestire l'errore in modo più robusto?
		# Per ora, terminiamo l'azione per evitare crash.
		return

	var performed_action = false # Flag per sapere se avanzare il turno

	if action == "swap":
		# --- CONTROLLO 1: Non puoi scambiare SE HAI il Re ---
		if my_card.rank_name == "K":
			print("Player %d ha il Re (K)! Non può scambiare. Azione forzata a 'hold'." % player_index)
			action = "hold" # Forza l'azione a tenere la carta
		else:
			# Prosegui solo se non hai il Re
			var target_card: CardData = null
			# Controlla se il target è valido
			if target_player_index < 0 or target_player_index >= players_data.size() or players_data[target_player_index].is_out or target_player_index == player_index:
				printerr("ERRORE: Target scambio non valido: %d" % target_player_index)
				# Se il target non è valido, l'azione di scambio fallisce, ma il giocatore deve comunque passare?
				# Decidiamo che se il target è invalido, il giocatore passa automaticamente.
				action = "hold"
			else:
				target_card = _get_valid_carddata_from_player(target_player_index, "_pa target")
				if target_card == null:
					printerr("ERRORE CRITICO (_player_action): Giocatore target %d non ha dati carta validi!" % target_player_index)
					# Anche qui, forziamo hold per sicurezza
					action = "hold"
				# --- CONTROLLO 2: Non puoi scambiare SE IL TARGET HA il Re ---
				elif target_card.rank_name == "K": # Blocco perché il TARGET ha il Re
					print("Tentativo di scambio fallito! Player %d ha il Re (K)." % target_player_index)
					players_data[player_index].has_swapped_this_round = true
					performed_action = true

					# --- AGGIUNTA CHIAMATA UI ---
					_show_cucu_king_notification(target_player_index)
					# --- FINE AGGIUNTA ---
				else:
					# --- SCAMBIO EFFETTIVO --- (Solo se entrambi i controlli Re passano)
					print("Player %d scambia con %d" % [player_index, target_player_index])
					# Esegui lo scambio dei dati carta
					players_data[player_index].card_data[0] = target_card
					players_data[target_player_index].card_data[0] = my_card
					# Aggiorna la visuale per entrambi
					_update_player_card_visuals(player_index)
					_update_player_card_visuals(target_player_index)
					players_data[player_index].has_swapped_this_round = true # Scambio avvenuto
					performed_action = true
					# --- Qui andrà la logica del Cavallo (Q) se lo scambio avviene ---

	# Se l'azione (originale o forzata) è "hold"
	if action == "hold":
		print("Player %d tiene la carta." % player_index)
		players_data[player_index].has_swapped_this_round = true # Passare conta come azione
		performed_action = true

	# Avanza il turno solo se un'azione valida (o un tentativo fallito ma valido) è stata eseguita
	if performed_action:
		# Aggiorna i bottoni se è il giocatore umano
		if player_index == 0:
			call_deferred("_update_player_action_buttons") # Defer per sicurezza

		# --- GESTIONE EFFETTO CAVALLO (Q) MANCANTE --- (Andrà qui, controllando my_card/target_card se c'è stato scambio)

		call_deferred("_advance_turn") # Avanza al prossimo giocatore
	else:
		# Questo non dovrebbe accadere se la logica sopra è corretta, ma è una sicurezza
		printerr("ATTENZIONE (_player_action): Nessuna azione eseguita per player %d. Controllare logica." % player_index)

#AZIONI MAZZIERE
func _dealer_action(action: String):
	# Validazione iniziale mazziere
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out:
		printerr("Azione mazziere annullata: Indice %d non valido o fuori." % dealer_index)
		call_deferred("_end_round") # Termina il round se il mazziere non è valido
		return

	var dealer_card: CardData = _get_valid_carddata_from_player(dealer_index, "_da get")
	if dealer_card == null:
		printerr("ERRORE CRITICO (_dealer_action): Mazziere %d non ha dati carta validi!" % dealer_index)
		action = "pass" # Forza 'pass' se mancano i dati

	# Se l'azione è scambiare col mazzo...
	if action == "swap_deck":
		# --- CONTROLLO RE MAZZIERE ---
		if dealer_card != null and dealer_card.rank_name == "K":
			print("Mazziere (%d) ha il Re (K)! Non può scambiare col mazzo. Azione forzata a 'pass'." % dealer_index)
			action = "pass" # Forza l'azione a passare
		else:
			# Prosegui solo se il mazziere non ha il Re
			if DeckSetupScene == null or not DeckSetupScene.has_method("cards_remaining") or DeckSetupScene.cards_remaining() <= 0:
				print("Mazzo vuoto o non accessibile. Mazziere (%d) passa." % dealer_index)
				action = "pass" # Forza 'pass' se il mazzo è vuoto/invalido
			else:
				# --- SCAMBIO EFFETTIVO COL MAZZO ---
				# Rimuovi la carta vecchia (già recuperata in dealer_card)
				players_data[dealer_index].card_data.pop_front() # Assumendo ci sia sempre una sola carta

				# Pesca la nuova
				var new_card: CardData = DeckSetupScene.draw_card()

				# Controlli sulla carta pescata
				if new_card == null:
					printerr("ERRORE: Mazzo finito durante lo scambio del mazziere!")
					# Rimetto la vecchia carta al mazziere per sicurezza
					players_data[dealer_index].card_data.append(dealer_card)
					action = "pass" # Fallback a passare
				elif not new_card is CardData:
					printerr("ERRORE: Mazzo ha restituito un tipo non valido!")
					# Rimetto la vecchia carta al mazziere per sicurezza
					players_data[dealer_index].card_data.append(dealer_card)
					action = "pass" # Fallback a passare
				else:
					# Scambio riuscito
					print("Mazziere (%d) scambia col mazzo. Scarta %s, Pesca %s." % [dealer_index, get_card_name(dealer_card), get_card_name(new_card)])
					# Aggiungi la nuova carta ai dati del mazziere
					players_data[dealer_index].card_data.append(new_card)
					# Aggiorna la visuale del mazziere
					_update_player_card_visuals(dealer_index)
					# Scarta la vecchia nel mazzo degli scarti (se esiste la funzione)
					if DeckSetupScene.has_method("discard_card"):
						DeckSetupScene.discard_card(dealer_card)

					# L'azione "swap_deck" è completata con successo qui.

	# Se l'azione (originale o forzata) è "pass"
	if action == "pass":
		print("Mazziere (%d) non scambia (passa)." % dealer_index)
		# Nessuna modifica alle carte richiesta

	# Azioni finali comuni ad entrambi i casi (swap o pass)
	_update_deck_visual() # Aggiorna la visuale del mazzo (potrebbe essere cambiata)
	_update_player_action_buttons() # Nascondi i bottoni azione
	call_deferred("_end_round") # Passa alla fase di fine round

func _make_cpu_dealer_turn():
	# Controlli iniziali validità stato e giocatore
	if current_state != GameState.DEALER_SWAP or current_player_index != dealer_index or current_player_index < 0 or current_player_index >= players_data.size() or not players_data[dealer_index].is_cpu or players_data[dealer_index].is_out:
		return # Esce se non è il turno della CPU mazziere valida

	var cpu_dealer_index = dealer_index
	print("CPU Mazziere (%d) pensa..." % cpu_dealer_index)
	if get_tree(): # Aggiunto controllo esistenza albero scene
		await get_tree().create_timer(randf_range(0.8, 1.5)).timeout

	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_dealer_index, "_mcdt")
	if card_to_evaluate == null:
		printerr("ERRORE (_make_cpu_dealer_turn): CPU Mazziere %d non ha dati carta validi!" % cpu_dealer_index)
		_dealer_action("pass") # Passa per sicurezza
		return

	var my_card_value = get_card_value(card_to_evaluate)
	# Controllo disponibilità mazzo migliorato
	var deck_available = (DeckSetupScene != null and DeckSetupScene.has_method("cards_remaining") and DeckSetupScene.cards_remaining() > 0)

	var should_swap_deck = false
	# --- CONTROLLO RE CPU MAZZIERE ---
	if card_to_evaluate.rank_name == "K":
		print("CPU Mazziere (%d) ha il Re (K). Non scambia col mazzo." % cpu_dealer_index)
		should_swap_deck = false # Non scambiare MAI col mazzo se hai il Re
	elif not deck_available:
		print("CPU Mazziere (%d) non può scambiare (mazzo vuoto/invalido)." % cpu_dealer_index)
		should_swap_deck = false # Non può scambiare se il mazzo non è disponibile
	# Logica di scambio (semplice: scambia se la carta è <= 4 e il mazzo è disponibile)
	elif my_card_value <= 4:
		print("CPU Mazziere (%d) ha carta bassa (%d) e mazzo disponibile. Scambia col mazzo." % [cpu_dealer_index, my_card_value])
		should_swap_deck = true
	else:
		print("CPU Mazziere (%d) ha carta alta (%d) o mazzo non disponibile. Passa." % [cpu_dealer_index, my_card_value])
		should_swap_deck = false

	# Esegui l'azione decisa
	if should_swap_deck:
		_dealer_action("swap_deck")
	else:
		_dealer_action("pass")

# --- Logica CPU ---
func _make_cpu_turn():
	# Controlli iniziali validità stato e giocatore
	if current_state != GameState.PLAYER_TURN or current_player_index < 0 or current_player_index >= players_data.size() or not players_data[current_player_index].is_cpu or players_data[current_player_index].is_out:
		return # Esce se non è il turno di una CPU valida

	var cpu_player_index = current_player_index
	print("CPU (%d) pensa..." % cpu_player_index)
	if get_tree(): # Aggiunto controllo esistenza albero scene
		await get_tree().create_timer(randf_range(0.8, 1.5)).timeout

	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_player_index, "_mct")
	if card_to_evaluate == null:
		printerr("ERRORE (_make_cpu_turn): CPU %d non ha dati carta validi!" % cpu_player_index)
		_player_action(cpu_player_index, "hold") # Passa per sicurezza
		return

	var my_card_value = get_card_value(card_to_evaluate)
	var target_player_index = get_player_to_left(cpu_player_index) # Confermiamo: scambia a SINISTRA

	var should_swap = false
	# --- CONTROLLO RE CPU ---
	if card_to_evaluate.rank_name == "K":
		print("CPU (%d) ha il Re (K). Non scambia." % cpu_player_index)
		should_swap = false # Non scambiare MAI se hai il Re
	elif target_player_index == -1:
		print("CPU (%d) non ha un target valido a sinistra. Passa." % cpu_player_index)
		should_swap = false # Non può scambiare se non c'è un target
	# Logica di scambio (semplice: scambia se la carta è <= 5)
	elif my_card_value <= 5:
		print("CPU (%d) ha carta bassa (%d). Tenta lo scambio con P%d." % [cpu_player_index, my_card_value, target_player_index])
		should_swap = true
		# NOTA: La CPU non sa se il target ha un Re. Tenterà lo scambio,
		# ma sarà la funzione _player_action a bloccarlo se necessario.
	else:
		print("CPU (%d) ha carta alta (%d). Passa." % [cpu_player_index, my_card_value])
		should_swap = false

	# Esegui l'azione decisa
	if should_swap:
		_player_action(cpu_player_index, "swap", target_player_index)
	else:
		_player_action(cpu_player_index, "hold")
		
# --- Fine Round e Punteggio ---
func _end_round():
	if current_state == GameState.GAME_OVER: return
	_update_player_action_buttons(); current_state = GameState.REVEALING
	print("\n--- Fine Round ---"); print("Rivelazione...")
	reveal_all_cards(); if get_tree(): await get_tree().create_timer(3.0).timeout
	print("Determinazione perdente...")
	determine_loser_and_update_lives()
	var active_players_count = 0; for player_data in players_data: if not player_data.is_out: active_players_count += 1
	if active_players_count <= 1: _handle_game_over(active_players_count); return
	_update_last_hand_display()
	if get_tree(): await get_tree().create_timer(2.0).timeout
	var old_dealer = dealer_index
	dealer_index = get_next_active_player(dealer_index, false)
	if dealer_index == -1: printerr("ERRORE: No nuovo mazziere!"); _handle_game_over(active_players_count); return
	print("Mazziere passa da %d a %d." % [old_dealer, dealer_index]); call_deferred("_start_round")
func reveal_all_cards():
	for i in range(players_data.size()):
		if not players_data[i].is_out and not players_data[i].visual_cards.is_empty():
			var card_visual = players_data[i].visual_cards[0] as CardVisual
			if is_instance_valid(card_visual): card_visual.show_front()
func determine_loser_and_update_lives():
	var lowest_card_value = 100; var losers_indices: Array[int] = []
	print("--- Valutazione Carte Fine Round ---")
	for i in range(players_data.size()):
		if not players_data[i].is_out:
			var card_to_evaluate: CardData = _get_valid_carddata_from_player(i, "det_loser_log")
			players_data[i].last_card = card_to_evaluate
			if card_to_evaluate: print("  Player %d (%s): %s (Val: %d)" % [i, "CPU" if players_data[i].is_cpu else "Umano", get_card_name(card_to_evaluate), get_card_value(card_to_evaluate)])
			else: printerr("  ERRORE: Impossibile leggere Player %d!" % i); players_data[i].last_card = null
		else: players_data[i].last_card = null
	print("--- Calcolo Perdente ---")
	for i in range(players_data.size()):
		if not players_data[i].is_out:
			var card_to_evaluate: CardData = players_data[i].last_card
			if card_to_evaluate == null: continue
			if card_to_evaluate.rank_name == "K": print("  -> Player %d salvo (Re)." % i); continue
			var card_value = get_card_value(card_to_evaluate)
			if card_value < lowest_card_value: lowest_card_value = card_value; losers_indices.clear(); losers_indices.append(i)
			elif card_value == lowest_card_value: losers_indices.append(i)
	if losers_indices.is_empty(): print("Nessun perdente.")
	else: print("Perdente/i (Val %d): %s" % [lowest_card_value, str(losers_indices)]); for loser_index in losers_indices: if loser_index >= 0: lose_life(loser_index)
func lose_life(player_index: int):
	if player_index >= 0 and player_index < players_data.size() and not players_data[player_index].is_out:
		players_data[player_index].lives -= 1; print("Player %d perde vita! Vite: %d" % [player_index, players_data[player_index].lives])
		if player_lives_labels.size() > player_index and is_instance_valid(player_lives_labels[player_index]):
			player_lives_labels[player_index].text = "Vite P%d: %d" % [player_index, players_data[player_index].lives]
		if players_data[player_index].lives <= 0:
			players_data[player_index].is_out = true; players_data[player_index].lives = 0; print(">>> Player %d eliminato! <<<" % player_index)
			if not players_data[player_index].visual_cards.is_empty():
				var card_visual = players_data[player_index].visual_cards[0]
				if is_instance_valid(card_visual): card_visual.hide()
func _handle_game_over(active_count: int):
	print("\n=== PARTITA FINITA! ==="); current_state = GameState.GAME_OVER
	_update_player_action_buttons()
	if active_count == 1:
		for i in range(players_data.size()):
			if not players_data[i].is_out: print("VINCITORE: Player %d !" % i); break
	elif active_count == 0: print("Tutti eliminati!")
	else: print("Fine partita inattesa con %d attivi." % active_count)
	# --- AGGIUNGERE UI FINE PARTITA/RIAVVIO QUI ---

#region Funzioni Ausiliarie (Helper)
#==================================

# --- Funzioni Utilità Giocatori ---
func get_player_to_left(player_index: int) -> int:
	var size = players_data.size()
	if size <= 1:
		# print("DEBUG (get_left): Size <= 1, return -1") # Debug opzionale
		return -1

	var current = player_index
	# Iteriamo al massimo 'size - 1' volte, perché non serve controllare subito il giocatore di partenza
	for _i in range(size - 1):
		current = (current - 1 + size) % size # Calcola indice a sinistra
		# print("DEBUG (get_left): Checking index %d" % current) # Debug opzionale

		# Controlliamo se l'indice è valido e se il giocatore non è fuori
		# Aggiunto controllo 'has("is_out")' per sicurezza extra
		if current < players_data.size() and players_data[current].has("is_out"):
			if not players_data[current].is_out:
				# print("DEBUG (get_left): Found active player %d, returning." % current) # Debug opzionale
				return current # Trovato giocatore attivo
			# else: print("DEBUG (get_left): Player %d is out." % current) # Debug opzionale
		# else: print("DEBUG (get_left): Index %d invalid or missing 'is_out'." % current) # Debug opzionale

	# Se il loop finisce, significa che non abbiamo trovato nessun altro giocatore attivo
	# print("DEBUG (get_left): Loop finished, no active player found, return -1") # Debug opzionale
	return -1
func get_player_to_right(player_index: int) -> int:
	# Aggiunto Debug dettagliato per chiarezza
	print("--- DEBUG: get_player_to_right chiamato per index: %d ---" % player_index)
	var current = player_index; var size = players_data.size()
	if size <= 1: print("  -> DEBUG: Size <= 1, ritorno -1"); return -1
	for i in range(size): # Uso contatore per chiarezza nel log
		current = (current + 1) % size
		print("  -> DEBUG: Controllo indice %d..." % current)
		if current == player_index: print("  -> DEBUG: Giro completo, ritorno -1"); return -1
		if current < players_data.size() and players_data[current].has("is_out"):
			var is_player_out = players_data[current].is_out
			print("    -> DEBUG: Player %d 'is_out' = %s" % [current, is_player_out])
			if not is_player_out: print("    -> DEBUG: Trovato player attivo %d, ritorno." % current); return current
			else: print("    -> DEBUG: Player %d è fuori, continuo ricerca." % current)
		else: printerr("    -> ERRORE: Indice %d non valido o manca 'is_out'!" % current)
	print("--- DEBUG: get_player_to_right finito senza trovare attivi, ritorno -1 ---")
	return -1
func get_next_active_player(start_index: int, clockwise: bool = false) -> int:
	var size = players_data.size(); if start_index < 0 or start_index >= size or size <= 1: return -1
	var current = start_index
	for _i in range(size):
		if clockwise: current = (current - 1 + size) % size
		else: current = (current + 1) % size
		if current == start_index: continue
		if not players_data[current].is_out: return current
	return -1

# --- Funzioni CardData / Visuals ---
func _get_valid_carddata_from_player(player_index: int, context: String = "?") -> CardData:
	if player_index < 0 or player_index >= players_data.size(): return null
	if not players_data[player_index].has("card_data") or players_data[player_index].card_data.is_empty(): return null
	var card_element = players_data[player_index].card_data[0]
	if card_element is CardData: return card_element
	elif card_element is Array and not card_element.is_empty() and card_element[0] is CardData:
		players_data[player_index].card_data[0] = card_element[0]; return card_element[0]
	else: printerr("ERRORE (%s): Tipo non valido in card_data[0]!" % context); return null

# CORRETTA DEFINITIVAMENTE (v6!): Ogni caso su una riga e usa rank_name
func get_card_value(card: CardData) -> int:
	if card == null:
		printerr("get_card_value chiamata con card null!")
		return 100 # Valore alto per errore

	match card.rank_name: # Usa rank_name
		"A": return 1
		"2": return 2
		"3": return 3
		"4": return 4
		"5": return 5
		"6": return 6
		"7": return 7
		"J": return 8  # Fante
		"Q": return 9  # Cavallo
		"K": return 10 # Re (Valore base)
		_:
			printerr("Rank non riconosciuto in get_card_value: ", card.rank_name)
			return 0 # Valore di default per rank sconosciuto

func get_card_name(card: CardData) -> String:
	if card: return card.rank_name + " " + card.suit
	return "Carta Invalida"
func _update_player_card_visuals(player_index: int):
	if player_index < 0 or player_index >= players_data.size(): return
	var player_data = players_data[player_index]; if player_data.is_out: return
	var card_to_display: CardData = _get_valid_carddata_from_player(player_index, "_update_vis")
	var card_visual = player_data.visual_cards[0] as CardVisual if not player_data.visual_cards.is_empty() else null
	if not is_instance_valid(card_visual): return
	if card_to_display == null: card_visual.hide(); return
	card_visual.card_data = card_to_display
	if player_index == 0 and not player_data.is_cpu: card_visual.show_front()
	else: card_visual.show_back()

# --- Funzione Aggiornamento Visual Mazzo ---
# --- Funzione Aggiornamento Visual Mazzo (STACK) ---
func _update_deck_visual():
	# Se non abbiamo istanze nella pila, non fare nulla
	if deck_visual_instances.is_empty():
		# print("Nessuna istanza visuale per il mazzo.") # Debug opzionale
		return

	# Controlla quante carte reali sono rimaste
	var cards_left = 0
	if DeckSetupScene != null and DeckSetupScene.has_method("cards_remaining"):
		cards_left = DeckSetupScene.cards_remaining()
	else:
		printerr("ERRORE in _update_deck_visual: Impossibile chiamare cards_remaining()!")
		# Nascondi tutte le istanze in caso di errore
		for instance in deck_visual_instances:
			if is_instance_valid(instance): instance.visible = false
		return

	# Determina se la pila intera deve essere visibile
	var show_stack = (cards_left > 0)
	# Applica la visibilità a TUTTE le istanze nella pila
	for instance in deck_visual_instances:
		if is_instance_valid(instance):
			instance.visible = show_stack

	# --- OPZIONALE: Scalare o mostrare meno carte (COME PRIMA) ---
# --- Funzione Aggiornamento Bottoni UI ---
func _update_player_action_buttons():
	# Assicura che le variabili export siano state assegnate nell'inspector
	var normal_swap_valid = is_instance_valid(swap_button)
	var normal_pass_valid = is_instance_valid(pass_button)
	var dealer_swap_valid = is_instance_valid(swap_to_deck_button)
	var dealer_pass_valid = is_instance_valid(pass_as_dealer_button)

	# Stati di default
	var enable_player_buttons = false
	var enable_dealer_buttons = false

	# Controlla se il giocatore corrente è valido prima di accedere a players_data
	# e se players_data[0] esiste (sicurezza extra)
	if current_player_index >= 0 and current_player_index < players_data.size() and players_data.size() > 0:
		# Condizioni per turno normale giocatore umano
		if current_state == GameState.PLAYER_TURN and \
		   current_player_index == 0 and \
		   not players_data[0].is_cpu and \
		   not players_data[0].has_swapped_this_round:
			enable_player_buttons = true

		# Condizioni per turno mazziere umano
		if current_state == GameState.DEALER_SWAP and \
		   current_player_index == 0 and \
		   not players_data[0].is_cpu:
			enable_dealer_buttons = true

	# Aggiorna bottoni normali
	if normal_swap_valid:
		swap_button.disabled = not enable_player_buttons
		swap_button.visible = enable_player_buttons
	if normal_pass_valid:
		pass_button.disabled = not enable_player_buttons
		pass_button.visible = enable_player_buttons

	# Aggiorna bottoni mazziere
	if dealer_swap_valid:
		swap_to_deck_button.disabled = not enable_dealer_buttons
		swap_to_deck_button.visible = enable_dealer_buttons
	if dealer_pass_valid:
		pass_as_dealer_button.disabled = not enable_dealer_buttons
		pass_as_dealer_button.visible = enable_dealer_buttons


# --- Funzione Aggiornamento UI Ultima Mano ---
func _update_last_hand_display():
	# Validazione array export
	if last_hand_textures.size() == 0: return # Se non si usa la feature
	if last_hand_textures.size() != players_data.size():
		printerr("ERRORE: Numero TextureRect ultima mano non corrisponde ai giocatori!")
		return
	var labels_valid = last_hand_labels.size() == players_data.size() # Se si usano label nomi

	for i in range(players_data.size()):
		var label = last_hand_labels[i] if labels_valid and i < last_hand_labels.size() and is_instance_valid(last_hand_labels[i]) else null
		var texture_rect = last_hand_textures[i] if i < last_hand_textures.size() and is_instance_valid(last_hand_textures[i]) else null
		if not texture_rect: continue # Salta se manca TextureRect

		var last_card: CardData = players_data[i].last_card if players_data.size() > i and players_data[i].has("last_card") else null # Accesso sicuro

		# Aggiorna nome (Opzionale)
		if label: label.text = "P%d:" % i

		# Aggiorna immagine carta
		if last_card != null and is_instance_valid(last_card.texture_front):
			texture_rect.texture = last_card.texture_front
			texture_rect.visible = true
			# if label: label.text += " " + get_card_name(last_card) # Aggiunge nome carta
		else:
			# Nascondi se giocatore era fuori o carta non valida
			texture_rect.texture = null
			texture_rect.visible = false
			# if label: label.text += " -"
# Funzione per mostrare la notifica "Cucù" (Blocco Re)

func _on_notification_timer_timeout():
	if cucu_notification_label != null:
		cucu_notification_label.visible = false # Nasconde la label
		print("DEBUG: Timeout notifica, CucuNotificationLabel nascosta.")
	else:
		printerr("ERRORE Timeout: CucuNotificationLabel è null!")

# Funzione per mostrare la notifica "Cucù" (Blocco Re) - VERSIONE CON LABEL/TIMER (Indentato con Tab)
func _show_cucu_king_notification(king_holder_index: int):
	# Controllo 1: I riferimenti alla Label e al Timer sono validi?
	if cucu_notification_label == null or notification_timer == null:
		printerr("ERRORE ShowNotify: CucuNotificationLabel o NotificationTimer non trovati/validi.")
		return # Non possiamo mostrare la notifica

	# Prepara il messaggio
	var message = "CUCÙ!\nGiocatore %d è protetto dal Re!" % king_holder_index

	# Imposta il testo nella Label
	cucu_notification_label.text = message

	# Rendi la Label VISIBILE
	cucu_notification_label.visible = true

	# --- Posizionamento (Opzionale, ma utile se la vuoi centrata) ---
	# Assicurati che la label (o il suo contenitore Panel) sia un nodo Control
	if cucu_notification_label is Control:
		var viewport_rect = get_viewport().get_visible_rect()
		 # Nota: .size potrebbe essere (0,0) se non impostato, centra il punto in alto a sx
		cucu_notification_label.position = viewport_rect.position + viewport_rect.size / 2.0 - cucu_notification_label.size / 2.0
		print("DEBUG: Posizionata CucuNotificationLabel a ", cucu_notification_label.position)
	# ----------------------------------------------------------------

	# Avvia il timer per nascondere la label dopo un po'
	var display_duration = 2.5 # Secondi
	notification_timer.wait_time = display_duration
	notification_timer.start()

	print("DEBUG: Mostrata notifica Cucù su CucuNotificationLabel.")
	
#endregion
