# game_manager.gd
extends Node3D
class_name GameManager

@export var card_scene: PackedScene = preload("res://scenes/CardVisual.tscn")
@export var card_offset_z: float = 0.1 # Offset per la carta visibile

var player_positions_node: Node3D = null
var num_players: int = 0
var dealer_index: int = 0
var current_turn_index: int = 0
var players_data: Array[Dictionary] = []
var active_card_instances: Array[CardVisual] = []

enum GameState { SETUP, DEALING, PLAYER_TURN, SWAPPING, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP

func _on_game_table_ready():
	print("Segnale ready di GameTable ricevuto.")
	player_positions_node = get_node("../PlayerPositions")
	if player_positions_node == null:
		printerr("!!! ERRORE CRITICO: Impossibile trovare PlayerPositions !!!")
		if get_parent() != null:
			print("Figli di GameTable:")
			for child in get_parent().get_children():
				print("- ", child.get_name())
		else:
			print("GameManager non ha un padre!")
	else:
		print("+++ Nodo PlayerPositions assegnato correttamente +++")
		start_game(4)

func start_game(p_num_players: int):
	print("Inizio partita con ", p_num_players, " giocatori.")
	current_state = GameState.SETUP
	num_players = p_num_players

	for card_instance in active_card_instances:
		if is_instance_valid(card_instance):
			card_instance.queue_free()
	active_card_instances.clear()
	players_data.clear()

	DeckSetupScene.reset_and_shuffle()

	if player_positions_node == null:
		printerr("ERRORE: player_positions_node è null in start_game!")
		return
	var available_spots = player_positions_node.get_child_count()
	if num_players > available_spots:
		printerr("ERRORE: Non ci sono abbastanza Marker3D per ", num_players, " giocatori!")
		num_players = available_spots

	for i in range(num_players):
		var player_marker = player_positions_node.get_child(i) as Marker3D
		if player_marker == null:
			printerr("ERRORE: Figlio ", i, " non è Marker3D!")
			continue
		players_data.append({
			"card_data": [], # Ora conterrà un array di carte
			"lives": 5,
			"marker": player_marker,
			"visual_cards": [] # Array per le istanze CardVisual
		})

	dealer_index = 0
	deal_initial_cards()
	current_turn_index = (dealer_index + 1) % num_players
	current_state = GameState.PLAYER_TURN
	print("Carte distribuite. Tocca al giocatore ", current_turn_index)

func deal_initial_cards():
	current_state = GameState.DEALING
	print("Distribuzione carte...")

	if player_positions_node == null:
		printerr("ERRORE: player_positions_node è null in deal_initial_cards!")
		return

	var num_initial_cards = 2
	var card_y_offset = 0.05
	var card_y_stack_offset = 0.01

	# Ottieni un riferimento alla camera principale (assumi che ce ne sia una con tag "MainCamera")
	var main_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(main_camera):
		printerr("ERRORE: Camera principale non trovata!")
		return

	for i in range(num_players):
		var player_marker: Marker3D = players_data[i]["marker"]
		if not player_marker:
			printerr("ERRORE: Marker del giocatore ", i, " non valido!")
			continue

		for j in range(num_initial_cards):
			var drawn_card_data: CardData = DeckSetupScene.draw_card()
			if drawn_card_data == null:
				printerr("ERRORE: Mazzo finito durante la distribuzione!")
				break

			players_data[i]["card_data"].append(drawn_card_data)
			var card_instance = card_scene.instantiate() as CardVisual
			if not card_instance:
				printerr("ERRORE: Istanza CardVisual fallita!")
				continue

			add_child(card_instance)
			card_instance.card_data = drawn_card_data
			players_data[i]["visual_cards"].append(card_instance)
			active_card_instances.append(card_instance)

			var card_position = player_marker.global_transform.origin + Vector3(0, card_y_offset + j * card_y_stack_offset, j * card_offset_z)
			card_instance.global_transform.origin = card_position

			if j == num_initial_cards - 1:
				# La carta più vicina segue la rotazione della camera e mostra il fronte
				card_instance.look_at(main_camera.global_transform.origin, Vector3.UP)
				card_instance.show_front()
				card_instance.set_physics_active(true)
			else:
				# Le altre carte mostrano il retro e sono ruotate
				card_instance.look_at(main_camera.global_transform.origin, Vector3.UP)
				card_instance.rotate_y(PI)
				card_instance.show_back()
				card_instance.set_physics_active(false)

	print("Distribuzione completata.")

func _process(delta):
	# Aggiorna la rotazione delle carte visibili per seguire la camera
	var main_camera = get_viewport().get_camera_3d()
	if is_instance_valid(main_camera):
		for i in range(num_players):
			if players_data[i].has("visual_cards") and not players_data[i]["visual_cards"].is_empty():
				var last_card = players_data[i]["visual_cards"].back()
				if is_instance_valid(last_card) and last_card.is_face_up:
					last_card.look_at(main_camera.global_transform.origin, Vector3.UP)

func swap_cards(player_index: int, card_index_player: int, target_player_index: int, card_index_target: int):
	if player_index < 0 or player_index >= num_players or \
	   target_player_index < 0 or target_player_index >= num_players or \
	   card_index_player < 0 or card_index_player >= players_data[player_index]["card_data"].size() or \
	   card_index_target < 0 or card_index_target >= players_data[target_player_index]["card_data"].size():
		printerr("Indici di scambio carte non validi!")
		return

	# Scambia i dati delle carte
	var temp_card = players_data[player_index]["card_data"][card_index_player]
	players_data[player_index]["card_data"][card_index_player] = players_data[target_player_index]["card_data"][card_index_target]
	players_data[target_player_index]["card_data"][card_index_target] = temp_card

	# Aggiorna la visualizzazione delle carte (potrebbe essere necessario rifare il posizionamento/mostrare)
	update_player_card_visuals(player_index)
	update_player_card_visuals(target_player_index)

func update_player_card_visuals(player_index: int):
	var player_data = players_data[player_index]
	var visual_cards = player_data["visual_cards"]
	var player_marker = player_data["marker"]
	var num_cards = player_data["card_data"].size()

	if not player_marker:
		printerr("ERRORE: Marker del giocatore ", player_index, " non valido!")
		return

	for i in range(num_cards):
		if i < visual_cards.size() and is_instance_valid(visual_cards[i]):
			var card_position = player_marker.global_transform.origin + Vector3(0, 6 , i * card_offset_z)
			visual_cards[i].global_transform.origin = card_position
			if i == num_cards - 1:
				visual_cards[i].show_front()
				visual_cards[i].set_physics_active(true) # Rendi cliccabile la carta visibile
			else:
				visual_cards[i].show_back()
				visual_cards[i].set_physics_active(false) # Disabilita i clic sulle carte coperte
			visual_cards[i].card_data = players_data[player_index]["card_data"][i] # Assicurati che i dati siano aggiornati
		else:
			printerr("ERRORE: Problema con le istanze CardVisual per il giocatore ", player_index)

# Funzione per ottenere l'indice del giocatore alla sinistra di un dato giocatore
func get_player_to_left(player_index: int) -> int:
	return (player_index - 1 + num_players) % num_players

# Funzione chiamata quando si clicca su una carta
func _on_card_clicked(card_visual: CardVisual):
	# Trova l'indice del giocatore a cui appartiene la carta cliccata
	var clicked_player_index = -1
	var clicked_card_index = -1
	for i in range(num_players):
		if players_data[i].has("visual_cards"):
			for j in range(players_data[i]["visual_cards"].size()):
				if players_data[i]["visual_cards"][j] == card_visual:
					clicked_player_index = i
					clicked_card_index = j
					break
			if clicked_player_index != -1:
				break

	if clicked_player_index != -1 and clicked_card_index == players_data[clicked_player_index]["visual_cards"].size() - 1:
		# Ottieni l'indice del giocatore alla sinistra
		var left_player_index = get_player_to_left(clicked_player_index)
		# Esegui lo scambio (ipotizzando che ogni giocatore abbia almeno una carta)
		if players_data[left_player_index]["card_data"].size() > 0:
			swap_cards(clicked_player_index, clicked_card_index, left_player_index, players_data[left_player_index]["card_data"].size() - 1)
		else:
			print("Il giocatore alla sinistra non ha carte da scambiare.")
	else:
		print("Puoi cliccare solo sulla tua carta visibile per scambiare.")
