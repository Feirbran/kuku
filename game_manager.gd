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
# --- Fine Export ---

var player_positions_node: Node3D = null
var num_players: int = 4
var dealer_index: int = 0
var current_player_index: int = 0
var players_data: Array[Dictionary] = []
var active_card_instances: Array[CardVisual] = []
var last_clicked_player_index: int = -1
var deck_visual_instance: Node3D = null # Nodo per visual mazzo centrale

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

	# Controllo marker mazzo
	if deck_position_marker == null:
		printerr("!!! ATTENZIONE: 'Deck Position Marker' non assegnato nell'Inspector!")

	player_positions_node = get_node_or_null("../PlayerPositions") # Adatta path se necessario
	if player_positions_node == null: printerr("!!! ERRORE: Impossibile trovare PlayerPositions!"); get_tree().quit(); return

	print("+++ GameManager pronto +++")

	# --- CREA VISUALE MAZZO (se possibile) ---
	if is_instance_valid(deck_position_marker) and card_scene != null:
		if is_instance_valid(deck_visual_instance): deck_visual_instance.queue_free() # Libera vecchia
		deck_visual_instance = card_scene.instantiate()
		if deck_visual_instance is CardVisual:
			var visual = deck_visual_instance as CardVisual
			add_child(visual)
			visual.global_transform = deck_position_marker.global_transform
			visual.position.y += 0.01 # Offset Y
			visual.show_back()
			visual.set_physics_active(false)
			print("Visuale mazzo creata.")
		else:
			printerr("ERRORE: Impossibile istanziare visuale mazzo come CardVisual."); deck_visual_instance = null
	# --- FINE CREAZIONE VISUALE MAZZO ---

	call_deferred("start_game", num_players)


func start_game(p_num_players: int):
	print("Richiesta partita con %d giocatori." % p_num_players); current_state = GameState.SETUP; num_players = p_num_players
	_reset_game(); if players_data.is_empty(): printerr("Reset fallito."); return
	dealer_index = 0; print("Inizio partita. Mazziere: %d" % dealer_index); call_deferred("_start_round")


func _reset_game():
	print("Resetting game...")
	for card_instance in active_card_instances: if is_instance_valid(card_instance): card_instance.queue_free()
	active_card_instances.clear(); players_data.clear()
	if DeckSetupScene == null: printerr("ERRORE: DeckSetupScene non trovato!"); return
	DeckSetupScene.reset_and_shuffle()
	if not player_positions_node: printerr("ERRORE: player_positions_node è null!"); return
	var available_spots = player_positions_node.get_child_count()
	if num_players <= 0: num_players = min(1, available_spots); if num_players <= 0: return
	if num_players > available_spots: num_players = available_spots
	print("Inizializzazione di %d giocatori..." % num_players)
	for i in range(num_players):
		var player_marker = player_positions_node.get_child(i) as Marker3D
		if not player_marker: printerr("ERRORE: Figlio %d non è Marker3D!" % i); continue
		players_data.append({ "card_data": [], "lives": 5, "marker": player_marker, "visual_cards": [], "has_swapped_this_round": false, "is_cpu": (i != 0), "is_out": false, "last_card": null })
	print("Giocatori inizializzati:", players_data.size())

	# Inizializza UI Vite
	if player_lives_labels.size() == players_data.size():
		for i in range(players_data.size()):
			if is_instance_valid(player_lives_labels[i]): player_lives_labels[i].text = "Vite P%d: %d" % [i, players_data[i].lives]; player_lives_labels[i].visible = true
	# Inizializza UI Ultima Mano
	if last_hand_textures.size() == players_data.size():
		for i in range(last_hand_textures.size()):
			if is_instance_valid(last_hand_textures[i]): last_hand_textures[i].visible = false
			if i < last_hand_labels.size() and is_instance_valid(last_hand_labels[i]): last_hand_labels[i].text = "P%d:" % i


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
func _on_card_clicked(card_visual: CardVisual): print("Click su carta ignorato (usare bottoni).")

# --- Azioni Gioco (Logica Interna) ---
func _player_action(player_index: int, action: String, target_player_index: int = -1):
	if player_index < 0 or player_index >= players_data.size() or players_data[player_index].is_out: return
	if players_data[player_index].has_swapped_this_round: return
	var my_card: CardData = _get_valid_carddata_from_player(player_index, "_pa my")
	var performed_action = false
	if action == "swap":
		var target_card: CardData = null
		if target_player_index < 0 or target_player_index >= players_data.size() or players_data[target_player_index].is_out or target_player_index == player_index:
			printerr("ERRORE: Target scambio non valido: %d" % target_player_index)
		else:
			target_card = _get_valid_carddata_from_player(target_player_index, "_pa target")
			if my_card == null or target_card == null: printerr("ERRORE: Dati carta mancanti!")
			# --- CONTROLLO RE VA QUI ---
			# elif my_card.rank_name == "K": print("Hai Re, non puoi."); return
			# elif target_card.rank_name == "K": print("Target ha Re, non puoi."); return
			else:
				print("Player %d scambia con %d" % [player_index, target_player_index])
				players_data[player_index].card_data[0] = target_card
				players_data[target_player_index].card_data[0] = my_card
				_update_player_card_visuals(player_index); _update_player_card_visuals(target_player_index)
				players_data[player_index].has_swapped_this_round = true; performed_action = true
	elif action == "hold":
		print("Player %d tiene la carta." % player_index)
		players_data[player_index].has_swapped_this_round = true; performed_action = true
	if performed_action:
		if player_index == 0: _update_player_action_buttons()
		# --- GESTIONE EFFETTO CAVALLO (Q) MANCANTE ---
		call_deferred("_advance_turn")
func _dealer_action(action: String):
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out: call_deferred("_end_round"); return
	if action == "swap_deck":
		if DeckSetupScene == null or DeckSetupScene.cards_remaining() <= 0:
			print("Mazzo vuoto (%d carte)." % DeckSetupScene.cards_remaining()); action = "pass"
		else:
			var discarded_card: CardData = _get_valid_carddata_from_player(dealer_index, "_da discard")
			if discarded_card == null: printerr("ERRORE: Dati mazziere corrotti!"); action = "pass"
			# --- CONTROLLO RE MAZZIERE MANCANTE ---
			# elif discarded_card.rank_name == "K": print("Mazziere ha Re, non scambia."); action = "pass"
			else:
				print("Mazziere (%d) scambia col mazzo." % dealer_index); players_data[dealer_index].card_data.pop_front()
				var new_card: CardData = DeckSetupScene.draw_card()
				if new_card == null: printerr("ERRORE: Mazzo finito!"); players_data[dealer_index].card_data.append(discarded_card); action = "pass"
				elif not new_card is CardData: printerr("ERRORE: Mazzo tipo non valido!"); players_data[dealer_index].card_data.append(discarded_card); action = "pass"
				else:
					if DeckSetupScene.has_method("discard_card"): DeckSetupScene.discard_card(discarded_card)
					players_data[dealer_index].card_data.append(new_card); _update_player_card_visuals(dealer_index)
	if action == "pass": print("Mazziere (%d) non scambia." % dealer_index)
	_update_deck_visual(); _update_player_action_buttons(); call_deferred("_end_round")

# --- Logica CPU ---
func _make_cpu_turn():
	if current_state != GameState.PLAYER_TURN or current_player_index < 0 or current_player_index >= players_data.size() or not players_data[current_player_index].is_cpu or players_data[current_player_index].is_out: return
	var cpu_player_index = current_player_index
	print("CPU (%d) pensa..." % cpu_player_index); if get_tree(): await get_tree().create_timer(randf_range(0.8, 1.5)).timeout
	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_player_index, "_mct")
	if card_to_evaluate == null: _player_action(cpu_player_index, "hold"); return
	var my_card_value = get_card_value(card_to_evaluate)
	var target_player_index = get_player_to_left(cpu_player_index)
	var should_swap = false
	if my_card_value <= 5 and target_player_index != -1: should_swap = true # --- MANCA CONTROLLO RE ---
	if should_swap: _player_action(cpu_player_index, "swap", target_player_index)
	else: _player_action(cpu_player_index, "hold")
func _make_cpu_dealer_turn():
	if current_state != GameState.DEALER_SWAP or current_player_index != dealer_index or not players_data[dealer_index].is_cpu or players_data[dealer_index].is_out: return
	var cpu_dealer_index = dealer_index
	print("CPU Mazziere (%d) pensa..." % cpu_dealer_index); if get_tree(): await get_tree().create_timer(randf_range(0.8, 1.5)).timeout
	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_dealer_index, "_mcdt")
	if card_to_evaluate == null: _dealer_action("pass"); return
	var my_card_value = get_card_value(card_to_evaluate)
	var deck_available = (DeckSetupScene != null and DeckSetupScene.cards_remaining() > 0)
	var should_swap_deck = false
	if my_card_value <= 4 and deck_available: should_swap_deck = true # --- MANCA CONTROLLO RE ---
	if should_swap_deck: _dealer_action("swap_deck")
	else: _dealer_action("pass")

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
	var current = player_index; var size = players_data.size(); if size <= 1: return -1
	for _i in range(size): current = (current - 1 + size) % size; if current == player_index: return -1; if not players_data[current].is_out: return current
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
func _update_deck_visual():
	# print("--- DEBUG: _update_deck_visual chiamato ---") # Rimuovi o commenta se non serve più
	if not is_instance_valid(deck_visual_instance):
		# print("  -> DEBUG: deck_visual_instance non è valido.")
		return

	var cards_left = 0
	if DeckSetupScene != null and DeckSetupScene.has_method("cards_remaining"):
		cards_left = DeckSetupScene.cards_remaining()
		# print("  -> DEBUG: DeckSetupScene.cards_remaining() = %d" % cards_left)
	else:
		printerr("ERRORE: Impossibile chiamare cards_remaining()!");
		deck_visual_instance.visible = false
		# print("  -> DEBUG: Errore accesso DeckSetupScene, visible = false")
		return

	# Mostra/Nascondi
	deck_visual_instance.visible = (cards_left > 0)
	# print("  -> DEBUG: Impostato deck_visual_instance.visible = %s" % deck_visual_instance.visible)

	# --- NUOVA PARTE: SCALA Y PER SPESSORE ---
	if deck_visual_instance.visible:
		# Mappa il numero di carte (es. da 1 a 40) a una scala Y desiderata
		# Esempio: scala da 0.05 (quasi piatto) a 0.5 (mezzo spessore di una carta standard?)
		var min_scale_y = 0.05 # Scala minima con 1 carta
		var max_scale_y = 0.5  # Scala massima con 40 carte
		# Normalizza il conteggio carte (valore tra 0.0 e 1.0)
		var normalized_count = clamp(float(cards_left) / 40.0, 0.0, 1.0)
		# Calcola la scala Y interpolando linearmente
		var target_scale_y = lerp(min_scale_y, max_scale_y, normalized_count)

		# Applica la scala (assicurati che deck_visual_instance sia Node3D o discendente)
		deck_visual_instance.scale.y = target_scale_y
		# print("  -> DEBUG: Impostato deck_visual_instance.scale.y = %f" % target_scale_y) # Debug Scala
	else:
		# Opzionale: Resetta la scala quando è invisibile
		deck_visual_instance.scale.y = 1.0
		
		
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

#endregion
