# game_manager.gd (Versione Completa Corretta per Errori Statici + Match)
extends Node3D
class_name GameManager

@export var card_scene: PackedScene = preload("res://scenes/CardVisual.tscn")

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
			# print("Skipping deal for player %d (is out)." % i) # Debug
			continue

		var player_marker: Marker3D = players_data[i]["marker"]
		if not player_marker:
			printerr("ERRORE: Marker del giocatore %d non valido! Skipping deal." % i)
			continue

		# Ci aspettiamo che draw_card() restituisca CardData o null
		var drawn_card_data: CardData = DeckSetupScene.draw_card()

		if drawn_card_data == null:
			printerr("ERRORE CRITICO: Mazzo finito durante la distribuzione iniziale!")
			# Qui potresti decidere cosa fare, es. terminare il round/partita
			current_state = GameState.GAME_OVER # O altra gestione
			return # Interrompe la distribuzione

		# Controllo di tipo aggiuntivo (opzionale, ma sicuro)
		if not drawn_card_data is CardData:
			printerr("ERRORE GRAVE: DeckSetupScene.draw_card() non ha restituito un CardData valido! Tipo restituito: %s" % typeof(drawn_card_data))
			current_state = GameState.GAME_OVER
			return

		# Aggiungi CardData all'array del giocatore (dovrebbe essere l'unico elemento)
		players_data[i]["card_data"].append(drawn_card_data)

		# Istanzia e configura la carta visuale
		var card_instance = card_scene.instantiate() as CardVisual
		if not card_instance:
			printerr("ERRORE: Istanziazione CardVisual fallita per giocatore %d!" % i)
			continue # Salta questo giocatore se la carta non si crea

		# Configura e aggiungi la carta visuale
		card_instance.card_data = drawn_card_data # Imposta i dati sulla carta visuale
		add_child(card_instance) # Aggiungi l'istanza come figlio del GameManager (o altro nodo adatto)
		players_data[i]["visual_cards"].append(card_instance) # Aggiungi CardVisual ai dati del giocatore
		active_card_instances.append(card_instance) # Aggiungi alla lista globale per pulizia

		# Posiziona e orienta la carta
		var card_position = player_marker.global_transform.origin + Vector3(0, 0.1, 0) # Leggermente sopra
		card_instance.global_transform.origin = card_position
		card_instance.look_at(main_camera.global_transform.origin, Vector3.UP)
		card_instance.rotation.x = deg_to_rad(-90) # Forza la carta ad essere piatta (potrebbe non servire)

		# Logica per mostrare fronte/retro e attivare fisica
		if i == 0: # Giocatore umano (assunto indice 0)
			card_instance.show_front()
			card_instance.set_physics_active(true) # Abilita fisica se cliccabile
		else: # CPU
			card_instance.show_back()
			card_instance.set_physics_active(false) # Disabilita fisica

	print("Carte distribuite.")

# --- Funzioni Utilità Giocatori ---

func get_player_to_left(player_index: int) -> int:
	# Trova il prossimo giocatore attivo in senso orario (indice decrescente)
	var current = player_index
	for _i in range(num_players): # Cerca al massimo N volte
		current = (current - 1 + num_players) % num_players
		if current == player_index: return -1 # Evita loop infinito se solo 1 giocatore
		if not players_data[current].is_out:
			return current
	return -1 # Nessun altro giocatore attivo trovato

func get_player_to_right(player_index: int) -> int:
	# Trova il prossimo giocatore attivo in senso anti-orario (indice crescente)
	var current = player_index
	for _i in range(num_players): # Cerca al massimo N volte
		current = (current + 1) % num_players
		if current == player_index: return -1 # Evita loop infinito se solo 1 giocatore
		if not players_data[current].is_out:
			return current
	return -1 # Nessun altro giocatore attivo

func get_next_active_player(start_index: int, clockwise: bool = false) -> int:
	# Trova il prossimo giocatore attivo in una data direzione partendo da start_index (escluso)
	if start_index < 0 or start_index >= players_data.size(): return -1 # Indice non valido

	var current = start_index
	for _i in range(players_data.size()): # Cerca al massimo N volte
		if clockwise:
			current = (current - 1 + players_data.size()) % players_data.size()
		else:
			current = (current + 1) % players_data.size()

		if current == start_index: return -1 # Fatto un giro completo, nessun altro attivo

		if not players_data[current].is_out:
			return current
	return -1 # Nessun altro giocatore attivo


# --- Gestione Azioni e Turni ---

func _on_pass_turn_button_pressed():
	# Verifica se è il turno del giocatore umano (0) e può passare
	if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
		print("Giocatore umano (0) passa il turno.")
		_player_action(0, "hold") # Registra l'azione di tenere
	# Verifica se è il turno del mazziere umano (0) e può passare (non scambiare col mazzo)
	elif current_state == GameState.DEALER_SWAP and current_player_index == 0 and dealer_index == 0 and not players_data[0].is_cpu:
		print("Mazziere umano (0) decide di non scambiare con il mazzo.")
		_dealer_action("pass")
	else:
		print("Bottone Passa non valido ora. Stato: %s, Giocatore: %d, Mazziere: %d" % [GameState.keys()[current_state], current_player_index, dealer_index])


func _on_card_clicked(card_visual: CardVisual):
	if not is_instance_valid(card_visual):
		printerr("ERRORE: _on_card_clicked ricevuto con card_visual non valida!")
		return

	# Ignora click se non è il turno del giocatore umano, o se ha già agito
	if current_state != GameState.PLAYER_TURN or current_player_index != 0 or players_data[0].is_cpu or players_data[0].has_swapped_this_round:
		# print("Click ignorato (Stato:%s, Player:%d, CPU?:%s, Swapped?:%s)" % [GameState.keys()[current_state], current_player_index, str(players_data[0].is_cpu), str(players_data[0].has_swapped_this_round)])
		return

	# Trova a chi appartiene la carta cliccata
	var clicked_owner_index = -1
	for i in range(players_data.size()):
		# Controlla solo giocatori attivi che hanno una visual card
		if not players_data[i].is_out and not players_data[i].visual_cards.is_empty():
			# Assumendo una sola carta visuale per giocatore
			if players_data[i].visual_cards[0] == card_visual:
				clicked_owner_index = i
				break

	# Se il giocatore clicca sulla PROPRIA carta
	if clicked_owner_index == 0:
		# Logica Semplificata: Cliccare sulla propria carta tenta di SCAMBIARE con il giocatore a sinistra
		print("Giocatore umano (0) tenta di scambiare con giocatore a sinistra.")
		var target_player_index = get_player_to_left(0)
		if target_player_index != -1:
			# --- CONTROLLO RE/CAVALLO MANCANTE ---
			# Qui dovresti controllare players_data[0].card_data[0].rank
			# e players_data[target_player_index].card_data[0].rank
			# Prima di chiamare _player_action
			print("Tentativo scambio tra 0 e %d" % target_player_index)
			_player_action(0, "swap", target_player_index)
		else:
			print("Nessun giocatore valido a sinistra con cui scambiare.")
	elif clicked_owner_index != -1:
		print("Hai cliccato sulla carta del giocatore %d. Puoi interagire solo con la tua." % clicked_owner_index)
	else:
		# Potrebbe essere stato cliccato lo sfondo o una carta non più valida
		print("Click su una carta non associata a un giocatore attivo.")


# --- Azioni Giocatore e CPU ---

func _player_action(player_index: int, action: String, target_player_index: int = -1):
	# Validazione indici e stato
	if player_index < 0 or player_index >= players_data.size() or players_data[player_index].is_out:
		printerr("ERRORE: Azione richiesta per giocatore non valido o fuori: %d" % player_index)
		return
	if players_data[player_index].has_swapped_this_round:
		print("Giocatore %d ha già agito in questo round." % player_index)
		# Non fare nulla se ha già agito, il turno avanzerà comunque se necessario
		# Potrebbe essere necessario chiamare _advance_turn se questo viene chiamato esternamente in modo errato
		return

	# --- IMPLEMENTARE QUI LOGICA RE (K) e CAVALLO (Q) ---
	var my_card: CardData = null
	# Estrazione sicura gestendo possibile nesting
	if not players_data[player_index].card_data.is_empty():
		var card_elem = players_data[player_index].card_data[0]
		if card_elem is CardData: my_card = card_elem
		elif card_elem is Array and not card_elem.is_empty() and card_elem[0] is CardData:
			print("ATTENZIONE _player_action (%d): Rilevata struttura dati annidata!" % player_index)
			my_card = card_elem[0]

	if action == "swap":
		# Validazione target
		if target_player_index < 0 or target_player_index >= players_data.size() or players_data[target_player_index].is_out or target_player_index == player_index:
			printerr("ERRORE: Tentativo di scambio con target non valido: %d" % target_player_index)
			action = "hold" # Forza a tenere se lo scambio non è valido
		else:
			# Controllo dati (sicurezza aggiuntiva)
			if players_data[player_index].card_data.is_empty() or players_data[target_player_index].card_data.is_empty():
				printerr("ERRORE CRITICO: Tentativo di scambio con dati carta mancanti!")
				action = "hold" # Forza a tenere
			# else if my_card and my_card.rank == "K":
			#     print("Giocatore %d ha il Re! Non può scambiare." % player_index)
			#     action = "hold"
			# else:
			#     var target_card_elem = players_data[target_player_index].card_data[0]
			#     var target_card: CardData = null
			#     if target_card_elem is CardData: target_card = target_card_elem
			#     elif target_card_elem is Array and not target_card_elem.is_empty() and target_card_elem[0] is CardData: target_card = target_card_elem[0]
			#
			#     if target_card and target_card.rank == "K":
			#         print("Giocatore %d ha il Re! Giocatore %d non può scambiare con lui." % [target_player_index, player_index])
			#         action = "hold"
			pass # Lascia passare lo scambio per ora (senza regole speciali)


	# Esecuzione Azione
	if action == "swap":
		# Qui lo scambio DEVE avvenire tra gli elementi [0], assumendo siano CardData
		# Estrazione sicura dei CardData reali prima dello scambio
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
		# Nessun aggiornamento visuale necessario

	# --- GESTIONE EFFETTO CAVALLO (Q) ---
	# if my_card and my_card.rank == "Q":
	#     print("Giocatore %d ha il Cavallo! Il prossimo giocatore salterà.")
	#     # Qui bisognerebbe impostare un flag o modificare _advance_turn
	#     pass

	# Avanza al prossimo turno dopo che l'azione è stata completata
	call_deferred("_advance_turn")


func _advance_turn():
	# Controlla se tutti i giocatori (non mazziere e non fuori) hanno agito
	var all_non_dealers_acted = true
	var next_player_candidate = -1
	var checked_players = 0
	var current_check = dealer_index # Partiamo dal mazziere e cerchiamo in giro

	while checked_players < players_data.size():
		current_check = (current_check + 1) % players_data.size()
		checked_players += 1
		# Considera solo giocatori attivi che non sono il mazziere
		if not players_data[current_check].is_out and current_check != dealer_index:
			if not players_data[current_check].has_swapped_this_round:
				all_non_dealers_acted = false
				next_player_candidate = current_check # Trovato il prossimo che deve agire
				break # Esci dal while appena trovi qualcuno che deve agire

	# Logica avanzamento
	if not all_non_dealers_acted and next_player_candidate != -1:
		# Passa al prossimo giocatore identificato
		current_player_index = next_player_candidate
		print("Avanzamento turno. Tocca al giocatore %d." % current_player_index)
		current_state = GameState.PLAYER_TURN
		# --- GESTIONE SALTO CAVALLO (Q) ---
		# Se il giocatore precedente aveva il cavallo, dovresti saltare questo 'current_player_index'
		# e trovare quello dopo ancora, poi avviare il turno della CPU se necessario.
		if players_data[current_player_index].is_cpu:
			call_deferred("_make_cpu_turn") # Avvia il turno della CPU
		# Se è umano, il gioco aspetta input (click o bottone)
	else:
		# Tutti i giocatori non-mazziere hanno agito (o sono fuori), passa alla fase del mazziere
		_go_to_dealer_phase()


func _go_to_dealer_phase():
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out:
		print("Mazziere (Giocatore %d) non valido o fuori dal gioco. Salto la sua fase." % dealer_index)
		call_deferred("_end_round") # Termina il round direttamente
		return

	current_player_index = dealer_index # Il focus è sul mazziere
	current_state = GameState.DEALER_SWAP
	print("Tutti gli altri hanno agito. Fase del Mazziere (Giocatore %d)." % current_player_index)

	# Se il mazziere è CPU, esegui la sua logica
	if players_data[current_player_index].is_cpu:
		call_deferred("_make_cpu_dealer_turn")
	# Se il mazziere è umano, aspetta input (es. bottone "Scambia con Mazzo" o "Passa")


func _make_cpu_turn():
	# Validazioni iniziali
	if current_state != GameState.PLAYER_TURN or current_player_index < 0 or current_player_index >= players_data.size() or not players_data[current_player_index].is_cpu or players_data[current_player_index].is_out:
		# printerr("Chiamata _make_cpu_turn non valida.") # Debug eccessivo?
		return

	var cpu_player_index = current_player_index
	print("CPU (Giocatore %d) sta pensando..." % cpu_player_index)
	await get_tree().create_timer(randf_range(0.8, 1.5)).timeout # Pausa

	# --- DEBUG ESTRAZIONE CARTA CPU ---
	var cpu_card_container = players_data[cpu_player_index].card_data
	print("DEBUG CPU (%d) - Check pre-valutazione. Tipo card_data: %s, Contenuto: %s" % [cpu_player_index, typeof(cpu_card_container), str(cpu_card_container)])

	if cpu_card_container.is_empty():
		printerr("ERRORE CRITICO: CPU %d ha array card_data vuoto in _make_cpu_turn!" % cpu_player_index)
		_player_action(cpu_player_index, "hold"); return # Forza a tenere

	var card_element_zero = cpu_card_container[0]
	print("DEBUG CPU (%d) - Check pre-valutazione. Tipo card_data[0]: %s, Contenuto: %s" % [cpu_player_index, typeof(card_element_zero), str(card_element_zero)])
	# --- FINE DEBUG ---

	# Tenta di ottenere il CardData corretto, gestendo possibile nesting
	var card_to_evaluate: CardData = null
	if card_element_zero is CardData:
		card_to_evaluate = card_element_zero
	elif card_element_zero is Array and not card_element_zero.is_empty() and card_element_zero[0] is CardData:
		print("ATTENZIONE CPU (%d): Rilevata struttura dati annidata [[CardData]]! Estraggo elemento interno." % cpu_player_index)
		card_to_evaluate = card_element_zero[0] # Estrae l'oggetto CardData dall'array interno
	else:
		printerr("ERRORE CRITICO: Impossibile determinare CardData valido da card_data[0] per CPU %d. Tipo: %s" % [cpu_player_index, typeof(card_element_zero)])
		_player_action(cpu_player_index, "hold"); return # Forza a tenere

	# Controllo finale dopo estrazione/assegnazione
	if card_to_evaluate == null:
		printerr("ERRORE CRITICO: card_to_evaluate è null dopo i controlli per CPU %d." % cpu_player_index)
		_player_action(cpu_player_index, "hold"); return # Forza a tenere

	# Logica Decisionale CPU (BASE)
	var my_card_value = get_card_value(card_to_evaluate) # Usa l'oggetto CardData verificato
	var target_player_index = get_player_to_left(cpu_player_index)

	# --- CONTROLLI RE/CAVALLO MANCANTI ---
	var should_swap = false
	# Esempio: Scambia se la carta è <= 5 E c'è un vicino valido E non hai il Re
	if my_card_value <= 5 and target_player_index != -1: # and card_to_evaluate.rank != "K":
		# Qui controlla anche se il target ha il Re
		# var target_card_elem = players_data[target_player_index].card_data[0] # Estrazione sicura necessaria!
		# var target_card: CardData = null
		# if target_card_elem is CardData: target_card = target_card_elem
		# elif target_card_elem is Array and not target_card_elem.is_empty() and target_card_elem[0] is CardData: target_card = target_card_elem[0]
		# if not (target_card and target_card.rank == "K"):
			should_swap = true

	# Esegui Azione CPU
	if should_swap:
		_player_action(cpu_player_index, "swap", target_player_index)
	else:
		_player_action(cpu_player_index, "hold")
	# Nota: _player_action chiama già call_deferred("_advance_turn")


func _make_cpu_dealer_turn():
	# Validazioni
	if current_state != GameState.DEALER_SWAP or current_player_index != dealer_index or not players_data[dealer_index].is_cpu or players_data[dealer_index].is_out:
		# printerr("Chiamata _make_cpu_dealer_turn non valida.")
		return

	var cpu_dealer_index = dealer_index
	print("CPU Mazziere (Giocatore %d) sta pensando..." % cpu_dealer_index)
	await get_tree().create_timer(randf_range(0.8, 1.5)).timeout

	# Logica Estrazione Carta (simile a _make_cpu_turn, per sicurezza)
	var dealer_card_container = players_data[cpu_dealer_index].card_data
	if dealer_card_container.is_empty():
		printerr("ERRORE CRITICO: CPU Mazziere %d ha array card_data vuoto!" % cpu_dealer_index)
		_dealer_action("pass"); return # Passa se non ha carte
	var card_element_zero = dealer_card_container[0]
	var card_to_evaluate: CardData = null
	if card_element_zero is CardData: card_to_evaluate = card_element_zero
	elif card_element_zero is Array and not card_element_zero.is_empty() and card_element_zero[0] is CardData:
		print("ATTENZIONE CPU Mazziere (%d): Rilevata struttura dati annidata [[CardData]]!" % cpu_dealer_index)
		card_to_evaluate = card_element_zero[0]
	else:
		printerr("ERRORE CRITICO: Impossibile determinare CardData per CPU Mazziere %d." % cpu_dealer_index)
		_dealer_action("pass"); return # Passa se c'è errore dati
	if card_to_evaluate == null:
		printerr("ERRORE CRITICO: card_to_evaluate è null per CPU Mazziere %d." % cpu_dealer_index)
		_dealer_action("pass"); return # Passa

	# Logica Decisionale Mazziere CPU
	var my_card_value = get_card_value(card_to_evaluate)
	# Assumendo che DeckSetupScene.deck sia accessibile e sia l'array del mazzo
	var deck_available = (DeckSetupScene != null and not DeckSetupScene.deck.is_empty())

	var should_swap_deck = false
	# Esempio: Scambia con mazzo se carta <= 4 e mazzo disponibile e non hai il Re
	if my_card_value <= 4 and deck_available: # and card_to_evaluate.rank != "K":
		should_swap_deck = true

	# Esegui Azione Mazziere CPU
	if should_swap_deck:
		_dealer_action("swap_deck")
	else:
		_dealer_action("pass")
	# Nota: _dealer_action chiama già call_deferred("_end_round")


func _dealer_action(action: String):
	# Validazioni
	if dealer_index < 0 or dealer_index >= players_data.size() or players_data[dealer_index].is_out:
		printerr("ERRORE: Azione richiesta per mazziere non valido o fuori: %d" % dealer_index)
		call_deferred("_end_round"); return # Prova a terminare il round comunque

	if action == "swap_deck":
		# Controlla se il mazzo ha carte
		if DeckSetupScene == null or DeckSetupScene.deck.is_empty():
			print("Il mazzo è vuoto o DeckSetupScene non accessibile, il mazziere non può scambiare.")
			action = "pass" # Tratta come se avesse passato
		else:
			# Verifica dati prima dello scambio
			if players_data[dealer_index].card_data.is_empty():
				printerr("ERRORE CRITICO: Mazziere %d tenta di scambiare ma non ha carta!" % dealer_index)
				action = "pass"
			else:
				print("Mazziere (Giocatore %d) scambia con il mazzo." % dealer_index)
				# Estrai la vecchia carta (gestendo possibile nesting)
				var card_elem = players_data[dealer_index].card_data[0]
				var discarded_card: CardData = null
				if card_elem is CardData: discarded_card = card_elem
				elif card_elem is Array and not card_elem.is_empty() and card_elem[0] is CardData:
					discarded_card = card_elem[0] # Estraggo quello interno da scartare

				# Rimuovi l'elemento (sia esso CardData o l'Array esterno nel caso di nesting)
				players_data[dealer_index].card_data.pop_front()

				# Pesca la nuova carta
				var new_card = DeckSetupScene.draw_card()

				# Gestisci casi di errore pesca/scarto
				if new_card == null: # Mazzo finito proprio ora?
					printerr("ERRORE: Mazzo finito durante lo scambio del mazziere!")
					# Rimetti la carta vecchia? O lascia senza carta? Per ora rimettiamo.
					if discarded_card: players_data[dealer_index].card_data.append(discarded_card) # Ri-appendi quella scartata
					action = "pass" # Considera come se avesse passato
				else:
					# Scarta la vecchia carta (se valida e la funzione discard esiste)
					if discarded_card and DeckSetupScene.has_method("discard_card"):
						DeckSetupScene.discard_card(discarded_card)

					# Aggiungi la nuova carta e aggiorna visuale
					players_data[dealer_index].card_data.append(new_card) # Aggiunge sempre all'array (che ora è vuoto)
					_update_player_card_visuals(dealer_index)

	# Se l'azione è (o è diventata) "pass"
	if action == "pass":
		print("Mazziere (Giocatore %d) non scambia." % dealer_index)
		# Non fare nulla alla carta

	# Concludi il round dopo l'azione del mazziere (o il passaggio forzato)
	call_deferred("_end_round")


# --- Funzione Aggiornata per Visuale ---
func _update_player_card_visuals(player_index: int):
	if player_index < 0 or player_index >= players_data.size(): return
	var player_data = players_data[player_index]
	if player_data.is_out: return
	if player_data.card_data.is_empty() or player_data.visual_cards.is_empty(): return

	var card_visual = player_data.visual_cards[0] as CardVisual
	var card_data_element = player_data.card_data[0]
	var card_to_display: CardData = null
	if card_data_element is CardData: card_to_display = card_data_element
	elif card_data_element is Array and not card_data_element.is_empty() and card_data_element[0] is CardData:
		# print("ATTENZIONE UpdateVisuals (%d): Rilevata struttura dati annidata!" % player_index) # Log meno invadente
		card_to_display = card_data_element[0]
	else:
		printerr("ERRORE UpdateVisuals (%d): Impossibile determinare CardData valido! Tipo: %s" % [player_index, typeof(card_data_element)])
		if is_instance_valid(card_visual): card_visual.hide()
		return

	if not is_instance_valid(card_visual): return
	if card_to_display == null:
		if is_instance_valid(card_visual): card_visual.hide()
		return

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
	await get_tree().create_timer(3.0).timeout
	print("Determinazione perdente...")
	determine_loser_and_update_lives()
	var active_players_count = 0
	for player_data in players_data:
		if not player_data.is_out: active_players_count += 1
	if active_players_count <= 1:
		_handle_game_over(active_players_count); return
	await get_tree().create_timer(2.0).timeout
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
			var player_data = players_data[i]
			# --- DEBUG ESTRAZIONE CARTA PERDENTE ---
			var card_container = player_data.card_data
			# print("DEBUG Perdente (%d) - Check. Tipo card_data: %s, Contenuto: %s" % [i, typeof(card_container), str(card_container)])
			if card_container.is_empty():
				printerr("ERRORE: Giocatore attivo %d senza carta alla fine del round!" % i)
				continue
			var card_element_zero = card_container[0]
			# print("DEBUG Perdente (%d) - Check. Tipo card_data[0]: %s, Contenuto: %s" % [i, typeof(card_element_zero), str(card_element_zero)])
			var card_to_evaluate: CardData = null
			if card_element_zero is CardData: card_to_evaluate = card_element_zero
			elif card_element_zero is Array and not card_element_zero.is_empty() and card_element_zero[0] is CardData:
				# print("ATTENZIONE Perdente (%d): Rilevata struttura dati annidata!" % i)
				card_to_evaluate = card_element_zero[0]
			else:
				printerr("ERRORE CRITICO Perdente (%d): Impossibile determinare CardData valido!" % i)
				continue
			if card_to_evaluate == null:
				printerr("ERRORE CRITICO Perdente (%d): card_to_evaluate è null!" % i)
				continue
			# --- FINE DEBUG ESTRAZIONE ---

			# --- CONTROLLO RE (K) --- (Logica base)
			if card_to_evaluate.rank == "K":
				print("Giocatore %d ha il Re (%s). È salvo." % [i, get_card_name(card_to_evaluate)])
				continue

			var card_value = get_card_value(card_to_evaluate)
			print("Giocatore %d ha %s (Valore: %d)" % [i, get_card_name(card_to_evaluate), card_value])

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

# CORRETTA: Ogni caso su una riga
func get_card_value(card: CardData) -> int:
	if card == null:
		printerr("get_card_value chiamata con card null!")
		return 100 # Valore alto per errore

	match card.rank:
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
			printerr("Rank non riconosciuto in get_card_value: ", card.rank)
			return 0 # Valore di default per rank sconosciuto

func get_card_name(card: CardData) -> String:
	if card: return card.rank + " " + card.suit
	return "Carta Invalida"
