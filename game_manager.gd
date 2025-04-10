# game_manager.gd (Versione Definitiva Speriamo - Fix Match Finale)
extends Node3D
class_name GameManager

# Assegna la scena CardVisual.tscn qui nell'Inspector!
@export var card_scene: PackedScene
# Aggiungi queste righe vicino agli altri @export all'inizio
@export var swap_button: Button
@export var pass_button: Button
# Se avrai un bottone specifico per il mazziere (es. "Scambia con Mazzo") aggiungilo qui
# @export var swap_deck_button: Button
var player_positions_node: Node3D = null
var num_players: int = 4
var dealer_index: int = 0
var current_player_index: int = 0
var players_data: Array[Dictionary] = []
var active_card_instances: Array[CardVisual] = []
var last_clicked_player_index: int = -1

enum GameState { SETUP, DEALING, PLAYER_TURN, DEALER_SWAP, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP

# Assicurati che DeckSetupScene sia un Autoload


func _ready():
	if card_scene == null: printerr("!!! ERRORE: 'Card Scene' non assegnata nell'Inspector!"); get_tree().quit(); return
	player_positions_node = get_node_or_null("../PlayerPositions")
	if player_positions_node == null: printerr("!!! ERRORE: Impossibile trovare PlayerPositions!"); get_tree().quit(); return
	print("+++ GameManager pronto +++"); start_game(num_players)

func start_game(p_num_players: int):
	print("Richiesta partita con %d giocatori." % p_num_players); current_state = GameState.SETUP; num_players = p_num_players
	_reset_game(); if players_data.is_empty(): printerr("Reset fallito."); return
	dealer_index = 0; print("Inizio partita. Mazziere: %d" % dealer_index); _start_round()

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
		players_data.append({ "card_data": [], "lives": 5, "marker": player_marker, "visual_cards": [], "has_swapped_this_round": false, "is_cpu": (i != 0), "is_out": false })
	print("Giocatori inizializzati:", players_data.size())

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
	if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_turn")
	# Aggiorna stato bottoni alla fine dell'inizio round
	_update_player_action_buttons()
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

# --- Gestione Turni e Azioni ---
func _advance_turn():
	var next_player_candidate = -1; var current_check = current_player_index
	for _i in range(players_data.size()):
		current_check = (current_check + 1) % players_data.size()
		if current_check != dealer_index and not players_data[current_check].is_out:
			if not players_data[current_check].has_swapped_this_round: next_player_candidate = current_check; break
		if current_check == current_player_index: break
	if next_player_candidate != -1:
		current_player_index = next_player_candidate
		print("Avanzamento turno. Tocca a player %d." % current_player_index); current_state = GameState.PLAYER_TURN
		# --- GESTIONE SALTO CAVALLO (Q) MANCANTE ---
		if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_turn")
	else: _go_to_dealer_phase()

func _go_to_dealer_phase():
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out:
		print("Mazziere %d non valido/fuori." % dealer_index); call_deferred("_end_round"); return
	current_player_index = dealer_index; current_state = GameState.DEALER_SWAP
	print("Fase Mazziere (Player %d)." % current_player_index)
	if players_data[current_player_index].is_cpu: call_deferred("_make_cpu_dealer_turn")
func _on_pass_turn_button_pressed():
	if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
		print("Umano passa."); _player_action(0, "hold")
	elif current_state == GameState.DEALER_SWAP and current_player_index == 0 and dealer_index == 0 and not players_data[0].is_cpu:
		print("Mazziere umano non scambia."); _dealer_action("pass")
	else: print("Bottone Passa non valido ora.")
func _on_card_clicked(card_visual: CardVisual):
	if not is_instance_valid(card_visual): return
	if current_state != GameState.PLAYER_TURN or current_player_index != 0 or players_data[0].is_cpu or players_data[0].has_swapped_this_round: return
	var clicked_owner_index = -1
	for i in range(players_data.size()):
		if not players_data[i].is_out and not players_data[i].visual_cards.is_empty():
			if players_data[i].visual_cards[0] == card_visual: clicked_owner_index = i; break
	if clicked_owner_index == 0:
		print("Umano tenta scambio a sinistra.")
		var target_player_index = get_player_to_left(0)
		if target_player_index != -1: print("Tentativo scambio 0 -> %d" % target_player_index); _player_action(0, "swap", target_player_index)
		else: print("Nessun vicino a sinistra.")
	elif clicked_owner_index != -1: print("Cliccato su carta altrui (%d)." % clicked_owner_index)
	else: print("Click su carta non riconosciuta.")

# --- Azioni Specifiche ---
func _player_action(player_index: int, action: String, target_player_index: int = -1):
	if player_index < 0 or player_index >= players_data.size() or players_data[player_index].is_out: return
	if players_data[player_index].has_swapped_this_round: return
	var my_card: CardData = _get_valid_carddata_from_player(player_index, "_player_action my_card")
	if action == "swap":
		var target_card: CardData = null
		if target_player_index < 0 or target_player_index >= players_data.size() or players_data[target_player_index].is_out or target_player_index == player_index:
			printerr("ERRORE: Target scambio non valido: %d" % target_player_index); action = "hold"
		else:
			target_card = _get_valid_carddata_from_player(target_player_index, "_player_action target_card")
			if my_card == null or target_card == null: printerr("ERRORE: Dati carta mancanti!"); action = "hold"
			# else: # --- LOGICA RE/CAVALLO VA QUI ---
			pass
	if action == "swap":
		var card1 = _get_valid_carddata_from_player(player_index, "_player_action swap")
		var card2 = _get_valid_carddata_from_player(target_player_index, "_player_action swap")
		if card1 and card2:
			print("Player %d scambia con %d" % [player_index, target_player_index])
			players_data[player_index].card_data[0] = card2; players_data[target_player_index].card_data[0] = card1
			_update_player_card_visuals(player_index); _update_player_card_visuals(target_player_index)
			players_data[player_index].has_swapped_this_round = true
		else: printerr("ERRORE: Dati non validi per scambio finale!"); action = "hold"
	if action == "hold":
		print("Player %d tiene la carta." % player_index)
		players_data[player_index].has_swapped_this_round = true
	# --- GESTIONE EFFETTO CAVALLO (Q) MANCANTE ---
	call_deferred("_advance_turn")
func _dealer_action(action: String):
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out: call_deferred("_end_round"); return
	if action == "swap_deck":
		if DeckSetupScene == null or DeckSetupScene.cards_remaining() <= 0:
			print("Mazzo vuoto (%d carte)." % DeckSetupScene.cards_remaining()); action = "pass"
		else:
			var discarded_card: CardData = _get_valid_carddata_from_player(dealer_index, "_dealer_action discard")
			if discarded_card == null: printerr("ERRORE: Dati mazziere corrotti!"); action = "pass"
			else:
				print("Mazziere (%d) scambia col mazzo." % dealer_index); players_data[dealer_index].card_data.pop_front()
				var new_card: CardData = DeckSetupScene.draw_card()
				if new_card == null: printerr("ERRORE: Mazzo finito durante scambio!"); players_data[dealer_index].card_data.append(discarded_card); action = "pass"
				elif not new_card is CardData: printerr("ERRORE: Mazzo tipo non valido!"); players_data[dealer_index].card_data.append(discarded_card); action = "pass"
				else:
					if DeckSetupScene.has_method("discard_card"): DeckSetupScene.discard_card(discarded_card)
					players_data[dealer_index].card_data.append(new_card); _update_player_card_visuals(dealer_index)
	if action == "pass": print("Mazziere (%d) non scambia." % dealer_index)
	call_deferred("_end_round")

# --- Logica CPU ---
func _make_cpu_turn():
	if current_state != GameState.PLAYER_TURN or current_player_index < 0 or current_player_index >= players_data.size() or not players_data[current_player_index].is_cpu or players_data[current_player_index].is_out: return
	var cpu_player_index = current_player_index
	print("CPU (%d) pensa..." % cpu_player_index); if get_tree(): await get_tree().create_timer(randf_range(0.8, 1.5)).timeout
	var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_player_index, "_make_cpu_turn")
	if card_to_evaluate == null: _player_action(cpu_player_index, "hold"); return
	var my_card_value = get_card_value(card_to_evaluate)
	var target_player_index = get_player_to_left(cpu_player_index)
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
	current_state = GameState.REVEALING
	print("\n--- Fine Round ---"); print("Rivelazione...")
	reveal_all_cards(); if get_tree(): await get_tree().create_timer(3.0).timeout
	print("Determinazione perdente...")
	determine_loser_and_update_lives()
	var active_players_count = 0; for player_data in players_data: if not player_data.is_out: active_players_count += 1
	if active_players_count <= 1: _handle_game_over(active_players_count); return
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
# Sostituisci questa funzione in game_manager.gd

func determine_loser_and_update_lives():
	var lowest_card_value = 100 # Valore iniziale alto
	var losers_indices: Array[int] = []

	print("--- Valutazione Carte Fine Round ---") # Intestazione per chiarezza

	# 1. Stampa le carte di tutti i giocatori attivi
	for i in range(players_data.size()):
		if not players_data[i].is_out: # Solo giocatori in gioco
			var card_to_evaluate: CardData = _get_valid_carddata_from_player(i, "determine_loser_log")
			if card_to_evaluate:
				# Stampa indice giocatore, tipo (CPU/Umano), nome carta e valore base
				print("  Player %d (%s): %s (Valore base: %d)" % [
					i,
					"CPU" if players_data[i].is_cpu else "Umano",
					get_card_name(card_to_evaluate),
					get_card_value(card_to_evaluate)
				])
			else:
				# Se non riusciamo a leggere la carta, segnalalo
				printerr("  ERRORE: Impossibile leggere carta per Player %d!" % i)

	# 2. Determina chi perde (ignorando chi ha il Re)
	print("--- Calcolo Perdente ---")
	for i in range(players_data.size()):
		if not players_data[i].is_out: # Solo giocatori in gioco
			var card_to_evaluate: CardData = _get_valid_carddata_from_player(i, "determine_loser_calc")
			if card_to_evaluate == null: continue # Salta se dati corrotti

			# Controllo Re (K) - Chi ha il Re è salvo
			if card_to_evaluate.rank_name == "K":
				print("  -> Player %d è salvo (ha il Re)." % i)
				continue # Passa al prossimo giocatore

			# Calcola valore per confronto (solo per chi NON ha il Re)
			var card_value = get_card_value(card_to_evaluate)
			if card_value < lowest_card_value:
				lowest_card_value = card_value
				losers_indices.clear()
				losers_indices.append(i) # Nuovo minimo trovato
			elif card_value == lowest_card_value:
				losers_indices.append(i) # Aggiungi a pari merito

	# 3. Applica penalità
	if losers_indices.is_empty():
		print("Nessun perdente determinato in questo round (tutti salvi?).")
	else:
		# Stampa chi perde prima di applicare
		print("Perdente/i determinato/i (Valore più basso %d): Giocatore/i %s" % [lowest_card_value, str(losers_indices)])
		for loser_index in losers_indices:
			if loser_index >= 0: # Sicurezza
				lose_life(loser_index) # Applica la perdita di vita
func lose_life(player_index: int):
	if player_index >= 0 and player_index < players_data.size() and not players_data[player_index].is_out:
		players_data[player_index].lives -= 1; print("Player %d perde vita! Vite: %d" % [player_index, players_data[player_index].lives])
		# --- AGGIORNA UI VITE QUI ---
		if players_data[player_index].lives <= 0:
			players_data[player_index].is_out = true; players_data[player_index].lives = 0; print(">>> Player %d eliminato! <<<" % player_index)
			if not players_data[player_index].visual_cards.is_empty():
				var card_visual = players_data[player_index].visual_cards[0]
				if is_instance_valid(card_visual): card_visual.hide()
func _handle_game_over(active_count: int):
	print("\n=== PARTITA FINITA! ==="); current_state = GameState.GAME_OVER
	if active_count == 1:
		for i in range(players_data.size()):
			if not players_data[i].is_out: print("VINCITORE: Player %d !" % i); break
	elif active_count == 0: print("Tutti eliminati!")
	else: print("Fine partita inattesa con %d attivi." % active_count)
	# --- AGGIUNGI UI FINE PARTITA/RIAVVIO QUI ---

#region Funzioni Ausiliarie (Helper)
#==================================

# --- Funzioni Utilità Giocatori (RIPRISTINATE E PRESENTI) ---
func get_player_to_left(player_index: int) -> int:
	var current = player_index; var size = players_data.size()
	if size <= 1: return -1
	for _i in range(size):
		current = (current - 1 + size) % size
		if current == player_index: return -1
		if not players_data[current].is_out: return current
	return -1
func get_player_to_right(player_index: int) -> int:
	var current = player_index; var size = players_data.size()
	if size <= 1: return -1
	for _i in range(size):
		current = (current + 1) % size
		if current == player_index: return -1
		if not players_data[current].is_out: return current
	return -1
func get_next_active_player(start_index: int, clockwise: bool = false) -> int:
	var size = players_data.size()
	if start_index < 0 or start_index >= size or size <= 1: return -1
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
	if not "card_data" in players_data[player_index] or players_data[player_index].card_data.is_empty(): return null
	var card_element = players_data[player_index].card_data[0]
	if card_element is CardData: return card_element
	elif card_element is Array and not card_element.is_empty() and card_element[0] is CardData:
		# print("ATTENZIONE (%s): Dati annidati per %d!" % [context, player_index]) # Tolto log invadente
		players_data[player_index].card_data[0] = card_element[0]; return card_element[0]
	else: printerr("ERRORE (%s): Tipo non valido in card_data[%d] per player %d!" % [context, 0, player_index]); return null

# CORRETTA: Ogni caso su una riga e usa rank_name
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

#endregion


# Funzione chiamata quando il bottone "Scambia" viene premuto
func _on_swap_button_pressed():
	# --- DEBUG AGGIUNTO ---
	# Stampa lo stato corrente ESATTO quando il bottone viene premuto
	print(">> Swap Button Pressed: State=%s, CurrentPlayer=%d, HasSwapped=%s" % [
		GameState.keys()[current_state],
		current_player_index,
		str(players_data[current_player_index].has_swapped_this_round) if current_player_index >= 0 and current_player_index < players_data.size() else "N/A"
	])
	# --- FINE DEBUG ---

	# Controlli: è il mio turno? Posso agire?
	# Assumiamo che il giocatore umano sia sempre l'indice 0
	if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
		print("Bottone 'Scambia' premuto dall'umano.")
		var target_player_index = get_player_to_right(0)
		if target_player_index != -1:
			# --- CONTROLLO RE/CAVALLO MANCANTE QUI ---
			print("Tentativo scambio (via bottone) tra Player 0 e Player %d (a destra)" % target_player_index)
			_player_action(0, "swap", target_player_index)
			 # Disabilita/Nascondi i bottoni azione dopo aver agito (da fare meglio dopo)
		else:
			print("Nessun giocatore valido a destra con cui scambiare.")
		# Stampa perché il bottone non è attivo (basato sullo stato stampato sopra)
			print("   -> Azione bottone Scambia non valida in questo stato/turno.")
			
			# Funzione per abilitare/disabilitare i bottoni azione del giocatore umano
func _update_player_action_buttons():
	# Controlla che i riferimenti ai bottoni siano validi (impostati nell'inspector)
	if not is_instance_valid(swap_button) or not is_instance_valid(pass_button):
		# Stampa un errore solo la prima volta o se cambiano da validi a invalidi
		# per non intasare il log.
		# printerr("ATTENZIONE: Riferimenti a SwapButton o PassButton non validi!")
		return # Non fare nulla se i bottoni non sono collegati

	# Determina se i bottoni devono essere attivi
	var enable_buttons = false # Default: disabilitati
	# Condizioni per abilitarli:
	# 1. È la fase del turno del giocatore
	# 2. È il turno del giocatore umano (indice 0)
	# 3. Il giocatore 0 non è una CPU (controllo di sicurezza)
	# 4. Il giocatore 0 non ha già agito in questo turno
	if current_state == GameState.PLAYER_TURN and \
	   current_player_index == 0 and \
	   not players_data[0].is_cpu and \
	   not players_data[0].has_swapped_this_round:
		enable_buttons = true

	# Applica lo stato ai bottoni
	swap_button.disabled = not enable_buttons
	pass_button.disabled = not enable_buttons

	# Qui potresti aggiungere logica per altri bottoni, come quello del mazziere
	# Esempio: Gestione bottone "Scambia con Mazzo" (se esiste)
	# if is_instance_valid(swap_deck_button):
	#    var enable_dealer_button = (current_state == GameState.DEALER_SWAP and current_player_index == 0 and not players_data[0].is_cpu)
	#    swap_deck_button.disabled = not enable_dealer_button
	#    # Potresti volerlo anche nascondere/mostrare invece che solo disabilitare
	#    # swap_deck_button.visible = enable_dealer_button
