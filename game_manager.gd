# game_manager.gd (Versione Corretta per usare rank_name)
extends Node3D
class_name GameManager

@export var card_scene: PackedScene # Non serve più preload se lo assegniamo sempre nell'inspector

var player_positions_node: Node3D = null
var num_players: int = 4 # Imposta numero giocatori di default
var dealer_index: int = 0
var current_player_index: int = 0
var players_data: Array[Dictionary] = []
var active_card_instances: Array[CardVisual] = []
var last_clicked_player_index: int = -1

enum GameState { SETUP, DEALING, PLAYER_TURN, DEALER_SWAP, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP

# Assicurati che DeckSetupScene sia un Autoload o accessibile globalmente
# con le funzioni: reset_and_shuffle(), draw_card() -> CardData, discard_card(card: CardData), deck (Array[CardData])


func _ready():
	# Controllo essenziale che card_scene sia assegnata nell'inspector
	if card_scene == null:
		printerr("!!! ERRORE CRITICO: La variabile 'Card Scene' non è assegnata nell'Inspector per il nodo GameManager!")
		get_tree().quit() # Esce dal gioco se non è assegnata
		return

	# Cerca il nodo delle posizioni qui, è più sicuro
	player_positions_node = get_node_or_null("../PlayerPositions") # Adatta il path se necessario
	if player_positions_node:
		print("+++ Nodo PlayerPositions trovato in _ready +++")
		start_game(num_players) # Usa il numero di giocatori definito sopra o da altra logica
	else:
		printerr("!!! ERRORE CRITICO: Impossibile trovare PlayerPositions in _ready !!! Path: '../PlayerPositions'")
		# Considera di bloccare il gioco o mostrare un errore all'utente


func start_game(p_num_players: int):
	print("Richiesta partita con %d giocatori." % p_num_players)
	current_state = GameState.SETUP
	num_players = p_num_players

	_reset_game() # Pulisce e inizializza i dati dei giocatori
	if players_data.is_empty():
		printerr("Errore durante il reset, nessun giocatore inizializzato.")
		return # Esce se il reset fallisce

	dealer_index = 0 # Il primo mazziere è il giocatore 0
	print("Inizio partita. Mazziere iniziale: Giocatore %d" % dealer_index)
	_start_round()


func _reset_game():
	print("Resetting game...")
	# Pulisci le istanze delle carte precedenti
	for card_instance in active_card_instances:
		if is_instance_valid(card_instance):
			card_instance.queue_free()
	active_card_instances.clear()

	# Resetta i dati dei giocatori
	players_data.clear()

	# Prepara il mazzo
	if DeckSetupScene == null:
		printerr("ERRORE CRITICO: DeckSetupScene (Autoload?) non trovato!")
		return
	DeckSetupScene.reset_and_shuffle()

	if not player_positions_node:
		printerr("ERRORE: player_positions_node è null durante il reset!")
		return

	var available_spots = player_positions_node.get_child_count()
	if num_players <= 0:
		printerr("ERRORE: num_players deve essere maggiore di 0.")
		num_players = min(1, available_spots) # Prova con 1 giocatore se possibile
		if num_players <= 0: return # Esce se non ci sono posti

	if num_players > available_spots:
		printerr("ATTENZIONE: Richiesti %d giocatori, ma ci sono solo %d posizioni. Limitando a %d." % [num_players, available_spots, available_spots])
		num_players = available_spots

	# Inizializza i dati per ogni giocatore
	print("Inizializzazione di %d giocatori..." % num_players)
	for i in range(num_players):
		var player_marker = player_positions_node.get_child(i) as Marker3D
		if not player_marker:
			printerr("ERRORE: Figlio %d in PlayerPositions non è un Marker3D! Salto giocatore." % i)
			continue # Salta questo giocatore se il marker non è valido

		players_data.append({
			"card_data": [],          # Array che conterrà il CardData (DEVE rimanere [CardDataObject])
			"lives": 5,               # Vite iniziali ("dita")
			"marker": player_marker,  # Riferimento al Marker3D per la posizione
			"visual_cards": [],       # Array che conterrà l'istanza CardVisual
			"has_swapped_this_round": false, # Flag per tracciare l'azione del turno
			"is_cpu": (i != 0),      # Giocatore 0 è umano, gli altri CPU (configurabile)
			"is_out": false           # Flag per indicare se il giocatore è eliminato
		})
	print("Giocatori inizializzati:", players_data.size())


func _start_round():
	# Verifica se il gioco è finito prima di iniziare il round
	var active_players_count = 0
	for player_data in players_data:
		if not player_data.is_out:
			active_players_count += 1
	if active_players_count <= 1:
		_handle_game_over(active_players_count)
		return # Non iniziare un nuovo round se il gioco è finito

	print("\n--- Inizia un nuovo round. Mazziere: Giocatore %d ---" % dealer_index)
	current_state = GameState.DEALING

	# Pulisci carte e resetta flag per i giocatori attivi
	for i in range(players_data.size()):
		var player_data = players_data[i]
		# Pulisci carte visuali precedenti
		for card_visual in player_data.visual_cards:
			if is_instance_valid(card_visual):
				active_card_instances.erase(card_visual) # Rimuovi da lista globale
				card_visual.queue_free()
		player_data.visual_cards.clear()
		player_data.card_data.clear()
		# Resetta flag solo se il giocatore è in gioco
		if not player_data.is_out:
			player_data.has_swapped_this_round = false
		else: # Se è fuori, considera come se avesse già agito per saltarlo
			player_data.has_swapped_this_round = true


	DeckSetupScene.reset_and_shuffle()
	_deal_initial_cards()

	# Se la distribuzione fallisce (es. mazzo vuoto subito), gestisci errore
	if current_state == GameState.GAME_OVER: return

	# Determina il primo giocatore (a destra del mazziere) saltando chi è fuori
	current_player_index = get_next_active_player(dealer_index, false) # false = anti-orario

	if current_player_index == -1:
		printerr("ERRORE CRITICO: Nessun giocatore attivo trovato per iniziare il turno dopo la distribuzione!")
		current_state = GameState.GAME_OVER
		_handle_game_over(0) # Gestisci fine partita per errore
		return

	current_state = GameState.PLAYER_TURN
	print("Distribuzione completata. Tocca al giocatore %d." % current_player_index)

	# Se il primo giocatore è CPU, avvia il suo turno
	if players_data[current_player_index].is_cpu:
		call_deferred("_make_cpu_turn")


func _deal_initial_cards():
	print("Distribuzione carte...")
	var main_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(main_camera):
		printerr("ERRORE CRITICO: Camera principale non trovata durante la distribuzione!")
		current_state = GameState.GAME_OVER # Blocca se non c'è camera
		return

	for i in range(players_data.size()):
		# Salta la distribuzione per i giocatori eliminati
		if players_data[i].is_out:
			continue

		var player_marker: Marker3D = players_data[i]["marker"]
		if not player_marker:
			printerr("ERRORE: Marker del giocatore %d non valido! Skipping deal." % i)
			continue

		# Ci aspettiamo che draw_card() restituisca CardData o null
		var drawn_card_data: CardData = DeckSetupScene.draw_card()

		if drawn_card_data == null:
			printerr("ERRORE CRITICO: Mazzo finito durante la distribuzione iniziale!")
			current_state = GameState.GAME_OVER
			return

		# Controllo di tipo aggiuntivo
		if not drawn_card_data is CardData:
			printerr("ERRORE GRAVE: DeckSetupScene.draw_card() non ha restituito un CardData valido! Tipo restituito: %s" % typeof(drawn_card_data))
			current_state = GameState.GAME_OVER
			return

		# Aggiungi CardData all'array del giocatore
		players_data[i]["card_data"].append(drawn_card_data)

		# Istanzia e configura la carta visuale (ora card_scene non dovrebbe essere null)
		var card_instance = card_scene.instantiate() as CardVisual
		if not card_instance:
			printerr("ERRORE: Istanziazione CardVisual fallita per giocatore %d! Controlla che CardVisual.tscn non abbia errori." % i)
			# Se l'istanza fallisce, potrebbe esserci un errore nello script di CardVisual o nella scena stessa
			continue

		# Configura e aggiungi la carta visuale
		card_instance.card_data = drawn_card_data
		add_child(card_instance)
		players_data[i]["visual_cards"].append(card_instance)
		active_card_instances.append(card_instance)

		# Posiziona e orienta la carta
		var card_position = player_marker.global_transform.origin + Vector3(0, 0.1, 0)
		card_instance.global_transform.origin = card_position
		card_instance.look_at(main_camera.global_transform.origin, Vector3.UP)
		card_instance.rotation.x = deg_to_rad(-90)

		# Logica per mostrare fronte/retro e attivare fisica
		if i == 0: # Giocatore umano
			card_instance.show_front()
			card_instance.set_physics_active(true)
		else: # CPU
			card_instance.show_back()
			card_instance.set_physics_active(false)

	print("Carte distribuite.")

# --- Funzioni Utilità Giocatori ---

func get_player_to_left(player_index: int) -> int:
	var current = player_index
	for _i in range(num_players):
		current = (current - 1 + num_players) % num_players
		if current == player_index: return -1
		if not players_data[current].is_out:
			return current
	return -1

func get_player_to_right(player_index: int) -> int:
	var current = player_index
	for _i in range(num_players):
		current = (current + 1) % num_players
		if current == player_index: return -1
		if not players_data[current].is_out:
			return current
	return -1

func get_next_active_player(start_index: int, clockwise: bool = false) -> int:
	if start_index < 0 or start_index >= players_data.size(): return -1
	var current = start_index
	for _i in range(players_data.size()):
		if clockwise: current = (current - 1 + players_data.size()) % players_data.size()
		else: current = (current + 1) % players_data.size()
		if current == start_index: return -1
		if not players_data[current].is_out:
			return current
	return -1


# --- Gestione Azioni e Turni ---

func _on_pass_turn_button_pressed():
	if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
		print("Giocatore umano (0) passa il turno.")
		_player_action(0, "hold")
	elif current_state == GameState.DEALER_SWAP and current_player_index == 0 and dealer_index == 0 and not players_data[0].is_cpu:
		print("Mazziere umano (0) decide di non scambiare con il mazzo.")
		_dealer_action("pass")
	else:
		print("Bottone Passa non valido ora. Stato: %s, Giocatore: %d, Mazziere: %d" % [GameState.keys()[current_state], current_player_index, dealer_index])


func _on_card_clicked(card_visual: CardVisual):
	if not is_instance_valid(card_visual):
		printerr("ERRORE: _on_card_clicked ricevuto con card_visual non valida!")
		return

	if current_state != GameState.PLAYER_TURN or current_player_index != 0 or players_data[0].is_cpu or players_data[0].has_swapped_this_round:
		return

	var clicked_owner_index = -1
	for i in range(players_data.size()):
		if not players_data[i].is_out and not players_data[i].visual_cards.is_empty():
			if players_data[i].visual_cards[0] == card_visual:
				clicked_owner_index = i
				break

	if clicked_owner_index == 0:
		print("Giocatore umano (0) tenta di scambiare con giocatore a sinistra.")
		var target_player_index = get_player_to_left(0)
		if target_player_index != -1:
			# --- CONTROLLO RE/CAVALLO MANCANTE ---
			print("Tentativo scambio tra 0 e %d" % target_player_index)
			_player_action(0, "swap", target_player_index)
		else:
			print("Nessun giocatore valido a sinistra con cui scambiare.")
	elif clicked_owner_index != -1:
		print("Hai cliccato sulla carta del giocatore %d. Puoi interagire solo con la tua." % clicked_owner_index)
	else:
		print("Click su una carta non associata a un giocatore attivo.")


# --- Azioni Giocatore e CPU ---

func _player_action(player_index: int, action: String, target_player_index: int = -1):
	if player_index < 0 or player_index >= players_data.size() or players_data[player_index].is_out:
		printerr("ERRORE: Azione richiesta per giocatore non valido o fuori: %d" % player_index)
		return
	if players_data[player_index].has_swapped_this_round:
		print("Giocatore %d ha già agito in questo round." % player_index)
		return

	# Estrazione sicura della carta del giocatore (gestendo possibile nesting rimasto da debug)
	var my_card: CardData = null
	if not players_data[player_index].card_data.is_empty():
		var card_elem = players_data[player_index].card_data[0]
		if card_elem is CardData: my_card = card_elem
		elif card_elem is Array and not card_elem.is_empty() and card_elem[0] is CardData:
			print("ATTENZIONE _player_action (%d): Rilevata struttura dati annidata!" % player_index)
			my_card = card_elem[0] # Estrae quello interno

	if action == "swap":
		# Validazione target e dati
		if target_player_index < 0 or target_player_index >= players_data.size() or players_data[target_player_index].is_out or target_player_index == player_index:
			printerr("ERRORE: Tentativo di scambio con target non valido: %d" % target_player_index)
			action = "hold"
		elif players_data[player_index].card_data.is_empty() or players_data[target_player_index].card_data.is_empty():
			printerr("ERRORE CRITICO: Tentativo di scambio con dati carta mancanti!")
			action = "hold"
		else:
			# Estrazione sicura della carta del target
			var target_card_elem = players_data[target_player_index].card_data[0]
			var target_card: CardData = null
			if target_card_elem is CardData: target_card = target_card_elem
			elif target_card_elem is Array and not target_card_elem.is_empty() and target_card_elem[0] is CardData:
				target_card = target_card_elem[0]

			# --- IMPLEMENTARE QUI LOGICA RE (K) e CAVALLO (Q) ---
			# Esempio controllo Re:
			# if my_card and my_card.rank_name == "K":
			#     print("Giocatore %d ha il Re! Non può iniziare uno scambio." % player_index)
			#     action = "hold"
			# elif target_card and target_card.rank_name == "K":
			#     print("Giocatore %d ha il Re! Giocatore %d non può scambiare con lui." % [target_player_index, player_index])
			#     action = "hold"
			pass # Lascia passare lo scambio per ora

	# Esecuzione Azione
	if action == "swap":
		# Estrazione sicura finale prima dello scambio effettivo
		var p1_card_elem = players_data[player_index].card_data[0]
		var p2_card_elem = players_data[target_player_index].card_data[0]
		var card1: CardData = null
		if p1_card_elem is CardData: card1 = p1_card_elem
		elif p1_card_elem is Array and not p1_card_elem.is_empty() and p1_card_elem[0] is CardData: card1 = p1_card_elem[0]
		var card2: CardData = null
		if p2_card_elem is CardData: card2 = p2_card_elem
		elif p2_card_elem is Array and not p2_card_elem.is_empty() and p2_card_elem[0] is CardData: card2 = p2_card_elem[0]

		if card1 == null or card2 == null:
			printerr("ERRORE CRITICO: Impossibile estrarre CardData validi per lo scambio tra %d e %d!" % [player_index, target_player_index])
			action = "hold" # Non scambiare se i dati sono corrotti
		else:
			print("Giocatore %d scambia con giocatore %d" % [player_index, target_player_index])
			# Scambia gli effettivi CardData (sovrascrive l'elemento 0)
			# Si assume che la struttura sia sempre [CardData] dopo questo punto
			players_data[player_index].card_data[0] = card2
			players_data[target_player_index].card_data[0] = card1
			# Aggiorna le visuali
			_update_player_card_visuals(player_index)
			_update_player_card_visuals(target_player_index)
			players_data[player_index].has_swapped_this_round = true

	# Se l'azione è (o è diventata) "hold"
	if action == "hold":
		print("Giocatore %d tiene la sua carta." % player_index)
		players_data[player_index].has_swapped_this_round = true

	# --- GESTIONE EFFETTO CAVALLO (Q) ---
	# if my_card and my_card.rank_name == "Q":
	#     print("Giocatore %d ha il Cavallo! Il prossimo giocatore salterà.")
	#     # Impostare flag o modificare _advance_turn
	#     pass

	# Avanza al prossimo turno
	call_deferred("_advance_turn")


func _advance_turn():
	var all_non_dealers_acted = true
	var next_player_candidate = -1
	var checked_players = 0
	var current_check = dealer_index

	while checked_players < players_data.size():
		current_check = (current_check + 1) % players_data.size()
		checked_players += 1
		if not players_data[current_check].is_out and current_check != dealer_index:
			if not players_data[current_check].has_swapped_this_round:
				all_non_dealers_acted = false
				next_player_candidate = current_check
				break

	if not all_non_dealers_acted and next_player_candidate != -1:
		current_player_index = next_player_candidate
		print("Avanzamento turno. Tocca al giocatore %d." % current_player_index)
		current_state = GameState.PLAYER_TURN
		# --- GESTIONE SALTO CAVALLO (Q) --- (Mancante)
		if players_data[current_player_index].is_cpu:
			call_deferred("_make_cpu_turn")
	else:
		_go_to_dealer_phase()

func _go_to_dealer_phase():
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out:
		print("Mazziere (Giocatore %d) non valido o fuori dal gioco. Salto la sua fase." % dealer_index)
		call_deferred("_end_round")
		return

	current_player_index = dealer_index
	current_state = GameState.DEALER_SWAP
	print("Tutti gli altri hanno agito. Fase del Mazziere (Giocatore %d)." % current_player_index)

	if players_data[current_player_index].is_cpu:
		call_deferred("_make_cpu_dealer_turn")


func _make_cpu_turn():
	# Validazioni iniziali
	if current_state != GameState.PLAYER_TURN or current_player_index < 0 or current_player_index >= players_data.size() or not players_data[current_player_index].is_cpu or players_data[current_player_index].is_out:
		return

	var cpu_player_index = current_player_index
	print("CPU (Giocatore %d) sta pensando..." % cpu_player_index)
	await get_tree().create_timer(randf_range(0.8, 1.5)).timeout

	# Estrazione sicura della carta CPU
	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_player_index, "_make_cpu_turn")
	if card_to_evaluate == null:
		_player_action(cpu_player_index, "hold"); return # Forza hold se non si può leggere la carta

	# Logica Decisionale CPU (BASE)
	var my_card_value = get_card_value(card_to_evaluate)
	var target_player_index = get_player_to_left(cpu_player_index)

	# --- CONTROLLI RE/CAVALLO MANCANTI ---
	var should_swap = false
	if my_card_value <= 5 and target_player_index != -1: # and card_to_evaluate.rank_name != "K":
		# Estraggo carta target per controllo RE
		# var target_card = _get_valid_carddata_from_player(target_player_index, "_make_cpu_turn target check")
		# if not (target_card and target_card.rank_name == "K"):
			should_swap = true

	# Esegui Azione CPU
	if should_swap: _player_action(cpu_player_index, "swap", target_player_index)
	else: _player_action(cpu_player_index, "hold")


func _make_cpu_dealer_turn():
	# Validazioni
	if current_state != GameState.DEALER_SWAP or current_player_index != dealer_index or not players_data[dealer_index].is_cpu or players_data[dealer_index].is_out:
		return

	var cpu_dealer_index = dealer_index
	print("CPU Mazziere (Giocatore %d) sta pensando..." % cpu_dealer_index)
	await get_tree().create_timer(randf_range(0.8, 1.5)).timeout

	# Estrazione sicura carta mazziere
	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_dealer_index, "_make_cpu_dealer_turn")
	if card_to_evaluate == null:
		_dealer_action("pass"); return

	# Logica Decisionale Mazziere CPU
	var my_card_value = get_card_value(card_to_evaluate)
	var deck_available = (DeckSetupScene != null and not DeckSetupScene.deck.is_empty())
	var should_swap_deck = false
	if my_card_value <= 4 and deck_available: # and card_to_evaluate.rank_name != "K":
		should_swap_deck = true

	# Esegui Azione Mazziere CPU
	if should_swap_deck: _dealer_action("swap_deck")
	else: _dealer_action("pass")


func _dealer_action(action: String):
	# Validazioni
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out:
		printerr("ERRORE: Azione richiesta per mazziere non valido o fuori: %d" % dealer_index)
		call_deferred("_end_round"); return

	if action == "swap_deck":
		if DeckSetupScene == null or DeckSetupScene.deck.is_empty():
			print("Il mazzo è vuoto o DeckSetupScene non accessibile, il mazziere non può scambiare.")
			action = "pass"
		else:
			# Estrazione sicura carta da scartare
			var discarded_card: CardData = _get_valid_carddata_from_player(dealer_index, "_dealer_action discard check")
			if discarded_card == null:
				printerr("ERRORE CRITICO: Mazziere %d tenta di scambiare ma dati carta corrotti!" % dealer_index)
				action = "pass"
			else:
				print("Mazziere (Giocatore %d) scambia con il mazzo." % dealer_index)
				# Rimuovi l'elemento vecchio (ora sappiamo che discarded_card è il CardData)
				players_data[dealer_index].card_data.pop_front()

				var new_card: CardData = DeckSetupScene.draw_card()
				if new_card == null:
					printerr("ERRORE: Mazzo finito durante lo scambio del mazziere!")
					players_data[dealer_index].card_data.append(discarded_card) # Rimetti vecchio se pesca fallisce
					action = "pass"
				elif not new_card is CardData:
					printerr("ERRORE GRAVE: Mazzo ha restituito tipo non valido (%s) durante scambio mazziere!" % typeof(new_card))
					players_data[dealer_index].card_data.append(discarded_card) # Rimetti vecchio
					action = "pass"
				else:
					# Scarta e aggiungi nuova
					if DeckSetupScene.has_method("discard_card"): DeckSetupScene.discard_card(discarded_card)
					players_data[dealer_index].card_data.append(new_card)
					_update_player_card_visuals(dealer_index)

	if action == "pass":
		print("Mazziere (Giocatore %d) non scambia." % dealer_index)

	call_deferred("_end_round")


# --- Funzione Aggiunta per Aggiornare Visuale ---
func _update_player_card_visuals(player_index: int):
	if player_index < 0 or player_index >= players_data.size(): return
	var player_data = players_data[player_index]
	if player_data.is_out: return

	# Estrazione sicura CardData
	var card_to_display: CardData = _get_valid_carddata_from_player(player_index, "_update_player_card_visuals")
	var card_visual = player_data.visual_cards[0] as CardVisual if not player_data.visual_cards.is_empty() else null

	if not is_instance_valid(card_visual): return # Non fare nulla se la visuale non è valida
	if card_to_display == null:
		# print("Dati carta non validi per visual player %d, nascondo." % player_index) # Log invadente
		card_visual.hide() # Nascondi se dati non validi
		return

	# Aggiorna e mostra/nascondi
	card_visual.card_data = card_to_display
	if player_index == 0 and not player_data.is_cpu: card_visual.show_front()
	else: card_visual.show_back()

# --- Fine Round e Punteggio ---

func _end_round():
	if current_state == GameState.GAME_OVER: return
	current_state = GameState.REVEALING
	print("\n--- Fine Round ---")
	print("Rivelazione carte...")
	reveal_all_cards()
	# Await più robusto
	if get_tree() != null: await get_tree().create_timer(3.0).timeout
	else: printerr("Tree is null in _end_round before await!")

	print("Determinazione perdente...")
	determine_loser_and_update_lives()
	var active_players_count = 0
	for player_data in players_data:
		if not player_data.is_out: active_players_count += 1
	if active_players_count <= 1:
		_handle_game_over(active_players_count); return

	if get_tree() != null: await get_tree().create_timer(2.0).timeout
	else: printerr("Tree is null in _end_round after await!")


	var old_dealer = dealer_index
	dealer_index = get_next_active_player(dealer_index, false)
	if dealer_index == -1:
		printerr("ERRORE CRITICO: Impossibile trovare un nuovo mazziere attivo!")
		_handle_game_over(active_players_count); return
	print("Mazziere passa da %d a %d." % [old_dealer, dealer_index])
	call_deferred("_start_round")

func reveal_all_cards():
	for i in range(players_data.size()):
		if not players_data[i].is_out and not players_data[i].visual_cards.is_empty():
			var card_visual = players_data[i].visual_cards[0] as CardVisual
			if is_instance_valid(card_visual):
				card_visual.show_front()

func determine_loser_and_update_lives():
	var lowest_card_value = 100
	var losers_indices: Array[int] = []
	print("Valutazione carte per perdita round:")
	for i in range(players_data.size()):
		if not players_data[i].is_out:
			# Estrazione sicura della carta per valutazione
			var card_to_evaluate: CardData = _get_valid_carddata_from_player(i, "determine_loser")
			if card_to_evaluate == null:
				printerr("ERRORE: Impossibile valutare carta per giocatore attivo %d!" % i)
				continue # Salta giocatore se dati corrotti

			# --- CONTROLLO RE (K) --- (Usa rank_name)
			if card_to_evaluate.rank_name == "K":
				print("Giocatore %d ha il Re (%s). È salvo." % [i, get_card_name(card_to_evaluate)])
				continue # Il Re non può perdere

			var card_value = get_card_value(card_to_evaluate)
			print("Giocatore %d ha %s (Valore: %d)" % [i, get_card_name(card_to_evaluate), card_value])

			# Aggiorna lista perdenti
			if card_value < lowest_card_value:
				lowest_card_value = card_value
				losers_indices.clear(); losers_indices.append(i)
			elif card_value == lowest_card_value:
				losers_indices.append(i)

	if losers_indices.is_empty():
		print("Nessun perdente determinato.")
	else:
		print("Perdente/i (Valore più basso: %d): %s" % [lowest_card_value, str(losers_indices)])
		for loser_index in losers_indices:
			if loser_index >= 0: lose_life(loser_index)


func lose_life(player_index: int):
	if player_index >= 0 and player_index < players_data.size() and not players_data[player_index].is_out:
		players_data[player_index].lives -= 1
		print("Giocatore %d ha perso una vita! Vite rimaste: %d" % [player_index, players_data[player_index].lives])
		# AGGIORNA UI VITE QUI
		if players_data[player_index].lives <= 0:
			players_data[player_index].is_out = true
			players_data[player_index].lives = 0
			print(">>> Giocatore %d è stato eliminato! <<<" % player_index)
			if not players_data[player_index].visual_cards.is_empty():
				var card_visual = players_data[player_index].visual_cards[0]
				if is_instance_valid(card_visual):
					print("Nascondo la carta del giocatore eliminato %d" % player_index)
					card_visual.hide()

func _handle_game_over(active_count: int):
	print("\n==================="); print("=== PARTITA FINITA! ==="); print("===================")
	current_state = GameState.GAME_OVER
	if active_count == 1:
		for i in range(players_data.size()):
			if not players_data[i].is_out: print("VINCITORE: Giocatore %d !" % i); break
	elif active_count == 0: print("Tutti i giocatori sono stati eliminati (Pareggio o Errore?)")
	else: print("Stato di fine partita inatteso con %d giocatori attivi." % active_count)
	# AGGIUNGI UI FINE PARTITA/RIAVVIO

# --- Funzioni Ausiliarie Carte ---

# Funzione helper per estrarre CardData in modo sicuro, gestendo nesting
func _get_valid_carddata_from_player(player_index: int, context: String = "Unknown") -> CardData:
	if player_index < 0 or player_index >= players_data.size():
		printerr("ERRORE (%s): Indice giocatore non valido: %d" % [context, player_index])
		return null
	if players_data[player_index].card_data.is_empty():
		# Non è necessariamente un errore se capita durante lo scambio, ma logghiamolo
		# print("Attenzione (%s): Array card_data vuoto per giocatore %d." % [context, player_index])
		return null

	var card_element = players_data[player_index].card_data[0]
	if card_element is CardData:
		return card_element # Caso normale e corretto
	elif card_element is Array and not card_element.is_empty() and card_element[0] is CardData:
		print("ATTENZIONE (%s): Rilevata struttura dati annidata [[CardData]] per giocatore %d! Estraggo elemento interno." % [context, player_index])
		return card_element[0] # Estrae quello interno
	else:
		printerr("ERRORE CRITICO (%s): Impossibile determinare CardData valido da card_data[0] per giocatore %d. Tipo: %s" % [context, player_index, typeof(card_element)])
		return null

# CORRETTA: Usa rank_name
func get_card_value(card: CardData) -> int:
	if card == null:
		printerr("get_card_value chiamata con card null!")
		return 100 # Valore alto per errore

	match card.rank_name: # <--- CORRETTO
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
			printerr("Rank non riconosciuto in get_card_value: ", card.rank_name) # <--- CORRETTO
			return 0 # Valore di default per rank sconosciuto

# CORRETTA: Usa rank_name
func get_card_name(card: CardData) -> String:
	if card:
		return card.rank_name + " " + card.suit # <--- CORRETTO
	return "Carta Invalida"
