# game_manager.gd
extends Node3D
class_name GameManager

@export var card_scene: PackedScene = preload("res://scenes/CardVisual.tscn")

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
	player_positions_node = get_node("../PlayerPositions") # Vai al padre (GameTable) e poi al figlio PlayerPositions
	if player_positions_node == null:
		printerr("!!! ERRORE CRITICO: Impossibile trovare PlayerPositions (nel segnale ready) !!!")
		if get_parent() != null:
			print("Figli di GameTable:")
			for child in get_parent().get_children():
				print("- ", child.get_name())
		else:
			print("GameManager non ha un padre!")
	else:
		print("+++ Nodo PlayerPositions assegnato correttamente (nel segnale ready) +++")
		start_game(4) # Avvia il gioco SOLO se player_positions_node è valido
		
func start_game(p_num_players: int):
	print("Inizio partita con ", p_num_players, " giocatori.")
	current_state = GameState.SETUP
	num_players = p_num_players

	for card_instance in active_card_instances:
		if is_instance_valid(card_instance):
			card_instance.queue_free()
	active_card_instances.clear()
	players_data.clear()

	print("PRIMA di DeckSetupScene.reset_and_shuffle() (in start_game)")
	DeckSetupScene.reset_and_shuffle() # Usa l'istanza globale (nome dell'autoload)
	print("DOPO di DeckSetupScene.reset_and_shuffle() (in start_game)")

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
			"card_data": null, "lives": 5, "marker": player_marker, "visual_card": null
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

	for i in range(num_players):
		var drawn_card_data: CardData = DeckSetupScene.draw_card() # Usa l'istanza globale
		if drawn_card_data == null:
			printerr("ERRORE: Mazzo finito!")
			break
		players_data[i]["card_data"] = drawn_card_data
		var card_instance = card_scene.instantiate() as CardVisual
		if card_instance == null:
			printerr("ERRORE: Istanza CardVisual fallita!")
			continue
		add_child(card_instance)
		card_instance.card_data = drawn_card_data
		players_data[i]["visual_card"] = card_instance
		var player_marker: Marker3D = players_data[i]["marker"]
		card_instance.global_transform.origin = player_marker.global_transform.origin + Vector3(0, 0.02, 0)
		card_instance.show_back()
		active_card_instances.append(card_instance)

	print("Distribuzione completata.")

# Qui puoi aggiungere altre funzioni del tuo game_manager (gestione del turno, ecc.)
