# game_manager.gddioca
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
@export var last_hand_textures: Array[TextureRect] # Array per TextureRect ultima mano (Size 4)
# --- Fine Export ---

var player_positions_node: Node3D = null
var num_players: int = 4
var dealer_index: int = 0
var current_player_index: int = 0
var players_data: Array[Dictionary] = []
var active_card_instances: Array[CardVisual] = []
var last_clicked_player_index: int = -1 # Non più usato per scambio principale

enum GameState { SETUP, DEALING, PLAYER_TURN, DEALER_SWAP, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP

# Assicurati che DeckSetupScene sia un Autoload


func _ready():
	# Controlli essenziali all'avvio
	if card_scene == null: printerr("!!! ERRORE: 'Card Scene' non assegnata nell'Inspector!"); get_tree().quit(); return
	if swap_button == null or pass_button == null or swap_to_deck_button == null or pass_as_dealer_button == null:
		printerr("!!! ATTENZIONE: Uno o più bottoni azione non assegnati nell'Inspector!") # Non blocca, ma avvisa
	if player_lives_labels.size() != num_players and player_lives_labels.size() > 0: # Permetti size 0 se non usati
		printerr("!!! ATTENZIONE: Numero di 'Player Lives Labels' (%d) non corrisponde a num_players (%d)!" % [player_lives_labels.size(), num_players])
	# Aggiungere controlli simili per last_hand_labels/textures se usati

	player_positions_node = get_node_or_null("../PlayerPositions") # Adatta path se necessario
	if player_positions_node == null: printerr("!!! ERRORE: Impossibile trovare PlayerPositions!"); get_tree().quit(); return

	print("+++ GameManager pronto +++")
	call_deferred("start_game", num_players) # Chiama start_game dopo che la scena è completamente pronta


func start_game(p_num_players: int):
	print("Richiesta partita con %d giocatori." % p_num_players); current_state = GameState.SETUP; num_players = p_num_players
	_reset_game(); if players_data.is_empty(): printerr("Reset fallito."); return
	dealer_index = 0; print("Inizio partita. Mazziere: %d" % dealer_index); call_deferred("_start_round") # Defer per sicurezza


func _reset_game():
	print("Resetting game...")
	# Pulisci istanze carte
	for card_instance in active_card_instances: if is_instance_valid(card_instance): card_instance.queue_free()
	active_card_instances.clear(); players_data.clear()

	# Resetta mazzo
	if DeckSetupScene == null: printerr("ERRORE: DeckSetupScene non trovato!"); return
	DeckSetupScene.reset_and_shuffle()

	# Verifica posizioni giocatori
	if not player_positions_node: printerr("ERRORE: player_positions_node è null!"); return
	var available_spots = player_positions_node.get_child_count()
	if num_players <= 0: num_players = min(1, available_spots); if num_players <= 0: return
	if num_players > available_spots: num_players = available_spots

	# Inizializza dati giocatori (incluso last_card)
	print("Inizializzazione di %d giocatori..." % num_players)
	for i in range(num_players):
		var player_marker = player_positions_node.get_child(i) as Marker3D
		if not player_marker: printerr("ERRORE: Figlio %d non è Marker3D!" % i); continue
		players_data.append({
			"card_data": [], "lives": 5, "marker": player_marker, "visual_cards": [],
			"has_swapped_this_round": false, "is_cpu": (i != 0), "is_out": false,
			"last_card": null # Campo per memorizzare l'ultima carta a fine round
		})
	print("Giocatori inizializzati:", players_data.size())

	# Inizializza UI Vite (dopo che players_data è stato popolato)
	if player_lives_labels.size() == players_data.size():
		for i in range(players_data.size()):
			if is_instance_valid(player_lives_labels[i]):
				player_lives_labels[i].text = "Vite P%d: %d" % [i, players_data[i].lives]
				player_lives_labels[i].visible = true # Assicura siano visibili
	# else: # Rimosso errore se non si usa questa feature
		# printerr("ERRORE: Numero di Label vite (%d) non corrisponde ai giocatori (%d)!" % [player_lives_labels.size(), players_data.size()])

	# Inizializza UI Ultima Mano (nascondi texture)
	if last_hand_textures.size() == players_data.size():
		for i in range(last_hand_textures.size()):
			if is_instance_valid(last_hand_textures[i]): last_hand_textures[i].visible = false
			# Opzionale: inizializza label nomi
			if i < last_hand_labels.size() and is_instance_valid(last_hand_labels[i]): last_hand_labels[i].text = "P%d:" % i


# --- Gestione Round ---
func _start_round():
	var active_players_count = 0; for player_data in players_data: if not player_data.is_out: active_players_count += 1
	if active_players_count <= 1: _handle_game_over(active_players_count); return

	print("\n--- Inizia Round. Mazziere: %d ---" % dealer_index); current_state = GameState.DEALING
	# Pulisci dati round precedente
	for i in range(players_data.size()):
		var player_data = players_data[i]
		for card_visual in player_data.visual_cards: if is_instance_valid(card_visual): active_card_instances.erase(card_visual); card_visual.queue_free()
		player_data.visual_cards.clear(); player_data.card_data.clear() # Svuota array carte
		if not player_data.is_out: player_data.has_swapped_this_round = false
		else: player_data.has_swapped_this_round = true # Giocatori fuori non agiscono

	# Il mazzo viene resettato all'inizio di ogni round dal DeckManager stesso
	DeckSetupScene.reset_and_shuffle()
	_deal_initial_cards()
	if current_state == GameState.GAME_OVER: return # Se distribuzione fallisce

	# Trova primo giocatore
	current_player_index = get_next_active_player(dealer_index, false) # Anti-orario da dx mazziere
	if current_player_index == -1: printerr("ERRORE: Nessun giocatore attivo!"); _handle_game_over(0); return

	current_state = GameState.PLAYER_TURN; print("Carte distribuite. Tocca a player %d." % current_player_index)
	_update_player_action_buttons() # Aggiorna stato bottoni per il primo giocatore
	if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_turn") # Avvia CPU


func _deal_initial_cards():
	print("Distribuzione..."); var main_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(main_camera): printerr("ERRORE: Camera 3D non trovata!"); current_state = GameState.GAME_OVER; return

	for i in range(players_data.size()):
		if players_data[i].is_out: continue # Salta eliminati
		var player_marker: Marker3D = players_data[i]["marker"]; if not player_marker: continue # Salta se manca marker

		# Pesca carta
		var drawn_card_data: CardData = DeckSetupScene.draw_card()
		if drawn_card_data == null: printerr("ERRORE CRITICO: Mazzo finito durante distribuzione!"); current_state = GameState.GAME_OVER; return # Termina
		if not drawn_card_data is CardData: printerr("ERRORE GRAVE: draw_card() tipo non valido!"); current_state = GameState.GAME_OVER; return

		# Assegna dati e crea visuale
		players_data[i]["card_data"] = [drawn_card_data] # Metti carta nell'array
		var card_instance = card_scene.instantiate() as CardVisual; if not card_instance: continue # Salta se istanza fallisce

		card_instance.card_data = drawn_card_data # Assegna dati alla visuale
		add_child(card_instance) # Aggiunge come figlio di GameManager
		players_data[i]["visual_cards"] = [card_instance] # Metti visuale nell'array
		active_card_instances.append(card_instance)

		# Posiziona e orienta
		var card_position = player_marker.global_transform.origin + Vector3(0, 0.1, 0)
		card_instance.global_transform.origin = card_position
		card_instance.look_at(main_camera.global_transform.origin, Vector3.UP); card_instance.rotation.x = deg_to_rad(-90)

		# Mostra fronte/retro
		if i == 0: card_instance.show_front(); card_instance.set_physics_active(true) # Umano
		else: card_instance.show_back(); card_instance.set_physics_active(false) # CPU

	print("Carte distribuite.")


# --- Gestione Turni e Azioni ---

func _advance_turn():
	# Trova il prossimo giocatore non-mazziere che deve agire
	var next_player_candidate = -1; var current_check = current_player_index
	for _i in range(players_data.size()):
		current_check = (current_check + 1) % players_data.size()
		# Controlla se è un giocatore valido, non mazziere, e non ha agito
		if current_check != dealer_index and not players_data[current_check].is_out and not players_data[current_check].has_swapped_this_round:
			next_player_candidate = current_check; break # Trovato
		if current_check == current_player_index: break # Fatto giro completo

	# Se trovato, passa il turno a lui
	if next_player_candidate != -1:
		current_player_index = next_player_candidate
		print("Avanzamento turno. Tocca a player %d." % current_player_index); current_state = GameState.PLAYER_TURN
		_update_player_action_buttons() # Aggiorna UI per il nuovo giocatore
		# --- GESTIONE SALTO CAVALLO (Q) MANCANTE QUI ---
		if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_turn")
	# Se non trovato, passa alla fase del mazziere
	else:
		_go_to_dealer_phase()


func _go_to_dealer_phase():
	# Validazione mazziere
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out:
		print("Mazziere %d non valido/fuori." % dealer_index); call_deferred("_end_round"); return # Salta fase

	current_player_index = dealer_index # Mazziere diventa giocatore corrente
	current_state = GameState.DEALER_SWAP # Imposta stato corretto
	print("Fase Mazziere (Player %d)." % current_player_index)
	_update_player_action_buttons() # Aggiorna UI per fase mazziere
	if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_dealer_turn") # Se CPU, agisce


# --- Funzioni Handler Bottoni UI ---

func _on_pass_turn_button_pressed():
	print(">> Pass Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
	# Azione Umano: Passa (tiene carta) nel suo turno normale
	if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
		print("Umano passa (tiene)."); _player_action(0, "hold")
	# Questa logica ora è gestita da _on_pass_as_dealer_pressed
	# elif current_state == GameState.DEALER_SWAP and current_player_index == 0 and dealer_index == 0 and not players_data[0].is_cpu:
	#	print("Mazziere umano non scambia."); _dealer_action("pass")
	else:
		print("   -> Azione bottone Passa non valida ora.")


func _on_swap_button_pressed():
	print(">> Swap Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
	# Azione Umano: Scambia a destra nel suo turno normale
	if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
		print("Bottone 'Scambia' premuto.")
		var target_player_index = get_player_to_right(0) # Scambia a destra
		if target_player_index != -1:
			# --- CONTROLLO RE/CAVALLO MANCANTE QUI ---
			print("Tentativo scambio (bottone) 0 -> %d (dx)" % target_player_index)
			_player_action(0, "swap", target_player_index)
		else: print("Nessun giocatore valido a destra.")
	else: print("   -> Azione bottone Scambia non valida ora.")


func _on_swap_to_deck_pressed():
	print(">> SwapDeck Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
	# Azione Mazziere Umano: Scambia con mazzo
	if current_state == GameState.DEALER_SWAP and current_player_index == 0 and not players_data[0].is_cpu:
		print("Bottone 'Scambia con Mazzo' premuto.")
		_dealer_action("swap_deck")
	else:
		print("   -> Azione 'Scambia con Mazzo' non valida ora.")


func _on_pass_as_dealer_pressed():
	print(">> PassDealer Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
	# Azione Mazziere Umano: Passa (non scambia con mazzo)
	if current_state == GameState.DEALER_SWAP and current_player_index == 0 and not players_data[0].is_cpu:
		print("Bottone 'Passa (Mazziere)' premuto.")
		_dealer_action("pass")
	else:
		print("   -> Azione 'Passa (Mazziere)' non valida ora.")


func _on_card_clicked(card_visual: CardVisual):
	# Scambio al click disabilitato
	print("Click su carta ignorato (usare bottoni).")


# --- Azioni Gioco (Logica Interna) ---

func _player_action(player_index: int, action: String, target_player_index: int = -1):
	# Validazioni e flag già agito
	if player_index < 0 or player_index >= players_data.size() or players_data[player_index].is_out: return
	if players_data[player_index].has_swapped_this_round: print("Player %d ha già agito!" % player_index); return

	var my_card: CardData = _get_valid_carddata_from_player(player_index, "_pa my")
	var performed_action = false

	if action == "swap":
		var target_card: CardData = null
		# Validazione target
		if target_player_index < 0 or target_player_index >= players_data.size() or players_data[target_player_index].is_out or target_player_index == player_index:
			printerr("ERRORE: Target scambio non valido: %d" % target_player_index)
		else:
			target_card = _get_valid_carddata_from_player(target_player_index, "_pa target")
			if my_card == null or target_card == null:
				printerr("ERRORE: Dati carta mancanti per scambio!")
			else:
				# --- CONTROLLO RE VA QUI PRIMA DI ESEGUIRE ---
				# if my_card.rank_name == "K": print("Hai Re, non puoi scambiare."); return
				# elif target_card.rank_name == "K": print("Target ha Re, non puoi scambiare."); return
				# Esegui lo scambio se controlli passano
				print("Player %d scambia con %d" % [player_index, target_player_index])
				players_data[player_index].card_data[0] = target_card
				players_data[target_player_index].card_data[0] = my_card
				_update_player_card_visuals(player_index); _update_player_card_visuals(target_player_index)
				players_data[player_index].has_swapped_this_round = true
				performed_action = true

	elif action == "hold":
		# Se l'azione è esplicitamente "hold"
		print("Player %d tiene la carta." % player_index)
		players_data[player_index].has_swapped_this_round = true
		performed_action = true

	# Aggiorna UI e avanza solo se azione completata
	if performed_action:
		if player_index == 0: _update_player_action_buttons() # Disabilita bottoni UMANO dopo azione
		# --- GESTIONE EFFETTO CAVALLO (Q) MANCANTE ---
		call_deferred("_advance_turn")


func _dealer_action(action: String):
	# Validazione mazziere
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out: call_deferred("_end_round"); return

	if action == "swap_deck":
		# Controllo disponibilità mazzo
		if DeckSetupScene == null or DeckSetupScene.cards_remaining() <= 0:
			print("Mazzo vuoto (%d carte)." % DeckSetupScene.cards_remaining()); action = "pass"
		else:
			var discarded_card: CardData = _get_valid_carddata_from_player(dealer_index, "_da discard")
			if discarded_card == null: printerr("ERRORE: Dati mazziere corrotti!"); action = "pass"
			# --- CONTROLLO RE MAZZIERE MANCANTE QUI ---
			# elif discarded_card.rank_name == "K": print("Mazziere ha Re, non scambia."); action = "pass"
			else:
				# Esegui scambio con mazzo
				print("Mazziere (%d) scambia col mazzo." % dealer_index)
				players_data[dealer_index].card_data.pop_front() # Rimuove vecchio CardData
				var new_card: CardData = DeckSetupScene.draw_card()
				# Gestione errori pesca
				if new_card == null: printerr("ERRORE: Mazzo finito durante scambio!"); players_data[dealer_index].card_data.append(discarded_card); action = "pass"
				elif not new_card is CardData: printerr("ERRORE: Mazzo tipo non valido!"); players_data[dealer_index].card_data.append(discarded_card); action = "pass"
				else: # Successo
					if DeckSetupScene.has_method("discard_card"): DeckSetupScene.discard_card(discarded_card)
					players_data[dealer_index].card_data.append(new_card); _update_player_card_visuals(dealer_index)

	# Se azione è "pass" (o è diventata "pass")
	if action == "pass":
		print("Mazziere (%d) non scambia." % dealer_index)

	# Disabilita/Nascondi bottoni dopo azione mazziere e vai a fine round
	_update_player_action_buttons()
	call_deferred("_end_round")


# --- Logica CPU ---
# (Le funzioni _make_cpu_turn e _make_cpu_dealer_turn rimangono invariate)
func _make_cpu_turn():
	if current_state != GameState.PLAYER_TURN or current_player_index < 0 or current_player_index >= players_data.size() or not players_data[current_player_index].is_cpu or players_data[current_player_index].is_out: return
	var cpu_player_index = current_player_index
	print("CPU (%d) pensa..." % cpu_player_index); if get_tree(): await get_tree().create_timer(randf_range(0.8, 1.5)).timeout
	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_player_index, "_make_cpu_turn")
	if card_to_evaluate == null: _player_action(cpu_player_index, "hold"); return
	var my_card_value = get_card_value(card_to_evaluate)
	var target_player_index = get_player_to_left(cpu_player_index) # CPU scambia a sinistra
	var should_swap = false
	if my_card_value <= 5 and target_player_index != -1: # and card_to_evaluate.rank_name != "K":
		should_swap = true # --- MANCA CONTROLLO RE TARGET ---
	if should_swap: _player_action(cpu_player_index, "swap", target_player_index)
	else: _player_action(cpu_player_index, "hold")
func _make_cpu_dealer_turn():
	if current_state != GameState.DEALER_SWAP or current_player_index != dealer_index or not players_data[dealer_index].is_cpu or players_data[dealer_index].is_out: return
	var cpu_dealer_index = dealer_index
	print("CPU Mazziere (%d) pensa..." % cpu_dealer_index); if get_tree(): await get_tree().create_timer(randf_range(0.8, 1.5)).timeout
	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_dealer_index, "_make_cpu_dealer_turn")
	if card_to_evaluate == null: _dealer_action("pass"); return
	var my_card_value = get_card_value(card_to_evaluate)
	var deck_available = (DeckSetupScene != null and DeckSetupScene.cards_remaining() > 0)
	var should_swap_deck = false
	if my_card_value <= 4 and deck_available: # and card_to_evaluate.rank_name != "K":
		should_swap_deck = true
	if should_swap_deck: _dealer_action("swap_deck")
	else: _dealer_action("pass")

# --- Fine Round e Punteggio ---
func _end_round():
	if current_state == GameState.GAME_OVER: return
	_update_player_action_buttons() # Assicura bottoni disabilitati all'inizio
	current_state = GameState.REVEALING
	print("\n--- Fine Round ---"); print("Rivelazione...")
	reveal_all_cards(); if get_tree(): await get_tree().create_timer(3.0).timeout
	print("Determinazione perdente...")
	determine_loser_and_update_lives() # Salva anche ultima mano qui dentro ora

	# Controllo fine partita
	var active_players_count = 0; for player_data in players_data: if not player_data.is_out: active_players_count += 1
	if active_players_count <= 1: _handle_game_over(active_players_count); return

	# Aggiorna display ultima mano
	_update_last_hand_display() # Chiamata alla funzione UI

	if get_tree(): await get_tree().create_timer(2.0).timeout # Pausa prima del prossimo round

	# Ruota mazziere
	var old_dealer = dealer_index
	dealer_index = get_next_active_player(dealer_index, false)
	if dealer_index == -1: printerr("ERRORE: No nuovo mazziere!"); _handle_game_over(active_players_count); return
	print("Mazziere passa da %d a %d." % [old_dealer, dealer_index]);
	call_deferred("_start_round") # Avvia prossimo round


func reveal_all_cards():
	for i in range(players_data.size()):
		if not players_data[i].is_out and not players_data[i].visual_cards.is_empty():
			var card_visual = players_data[i].visual_cards[0] as CardVisual
			if is_instance_valid(card_visual): card_visual.show_front()


func determine_loser_and_update_lives():
	var lowest_card_value = 100; var losers_indices: Array[int] = []
	print("--- Valutazione Carte Fine Round ---")
	# Stampa carte e salva ultima mano
	for i in range(players_data.size()):
		if not players_data[i].is_out:
			var card_to_evaluate: CardData = _get_valid_carddata_from_player(i, "det_loser_log")
			players_data[i].last_card = card_to_evaluate # Salva carta per display
			if card_to_evaluate: print("  Player %d (%s): %s (Val: %d)" % [i, "CPU" if players_data[i].is_cpu else "Umano", get_card_name(card_to_evaluate), get_card_value(card_to_evaluate)])
			else: printerr("  ERRORE: Impossibile leggere carta Player %d!" % i); players_data[i].last_card = null
		else:
			players_data[i].last_card = null # Nessuna carta per giocatori fuori

	# Calcola perdente
	print("--- Calcolo Perdente ---")
	for i in range(players_data.size()):
		if not players_data[i].is_out:
			var card_to_evaluate: CardData = players_data[i].last_card # Usa carta salvata
			if card_to_evaluate == null: continue
			if card_to_evaluate.rank_name == "K": print("  -> Player %d salvo (Re)." % i); continue
			var card_value = get_card_value(card_to_evaluate)
			if card_value < lowest_card_value: lowest_card_value = card_value; losers_indices.clear(); losers_indices.append(i)
			elif card_value == lowest_card_value: losers_indices.append(i)

	# Applica penalità
	if losers_indices.is_empty(): print("Nessun perdente.")
	else: print("Perdente/i (Val %d): %s" % [lowest_card_value, str(losers_indices)]); for loser_index in losers_indices: if loser_index >= 0: lose_life(loser_index)


func lose_life(player_index: int):
	if player_index >= 0 and player_index < players_data.size() and not players_data[player_index].is_out:
		players_data[player_index].lives -= 1; print("Player %d perde vita! Vite: %d" % [player_index, players_data[player_index].lives])
		# Aggiorna Label Vite
		if player_lives_labels.size() > player_index and is_instance_valid(player_lives_labels[player_index]):
			player_lives_labels[player_index].text = "Vite P%d: %d" % [player_index, players_data[player_index].lives]
		# Controllo eliminazione
		if players_data[player_index].lives <= 0:
			players_data[player_index].is_out = true; players_data[player_index].lives = 0; print(">>> Player %d eliminato! <<<" % player_index)
			if not players_data[player_index].visual_cards.is_empty():
				var card_visual = players_data[player_index].visual_cards[0]
				if is_instance_valid(card_visual): card_visual.hide()


func _handle_game_over(active_count: int):
	print("\n=== PARTITA FINITA! ==="); current_state = GameState.GAME_OVER
	_update_player_action_buttons() # Disabilita tutti i bottoni a fine partita
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
	var current = player_index; var size = players_data.size(); if size <= 1: return -1
	for _i in range(size): current = (current - 1 + size) % size; if current == player_index: return -1; if not players_data[current].is_out: return current
	return -1
func get_player_to_right(player_index: int) -> int:
	print("--- DEBUG: get_player_to_right chiamato per index: %d ---" % player_index)
	var current = player_index; var size = players_data.size()
	if size <= 1: print("  -> DEBUG: Size <= 1, ritorno -1"); return -1

	for i in range(size): # Uso contatore per chiarezza nel log
		current = (current + 1) % size
		print("  -> DEBUG: Controllo indice %d..." % current)
		if current == player_index: print("  -> DEBUG: Giro completo, ritorno -1"); return -1 # Fatto giro completo

		# Controllo robusto dati giocatore
		if current < players_data.size() and players_data[current].has("is_out"):
			var is_player_out = players_data[current].is_out
			print("    -> DEBUG: Player %d 'is_out' = %s" % [current, is_player_out])
			if not is_player_out:
				print("    -> DEBUG: Trovato player attivo %d, ritorno." % current)
				return current # Trovato giocatore attivo
			else:
				print("    -> DEBUG: Player %d è fuori, continuo ricerca." % current)
		else:
			# Questo caso non dovrebbe succedere se players_data è corretto
			printerr("    -> ERRORE: Indice %d non valido o manca 'is_out'!" % current)
			# Decidi se continuare o fermarti in caso di dati corrotti
			# Per ora continuiamo la ricerca loggando l'errore

	print("--- DEBUG: get_player_to_right finito senza trovare attivi, ritorno -1 ---")
	return -1 # Nessun altro giocatore attivo trovato
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
		players_data[player_index].card_data[0] = card_element[0]; return card_element[0] # Corregge e restituisce
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
	if card: return card.rank_name + " " + card.suit # Usa rank_name
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
	# Permetti size 0 se non si usa la feature
	if last_hand_textures.size() == 0: return
	if last_hand_textures.size() != players_data.size():
		printerr("ERRORE: Numero TextureRect ultima mano non corrisponde ai giocatori!")
		return
	var labels_valid = last_hand_labels.size() == players_data.size()

	for i in range(players_data.size()):
		var label = last_hand_labels[i] if labels_valid and i < last_hand_labels.size() and is_instance_valid(last_hand_labels[i]) else null
		var texture_rect = last_hand_textures[i] if i < last_hand_textures.size() and is_instance_valid(last_hand_textures[i]) else null
		if not texture_rect: continue # Salta se manca TextureRect

		var last_card: CardData = players_data[i].last_card # Prende da dati salvati

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

#endregion
