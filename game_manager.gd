# game_manager.gd
extends Node3D
class_name GameManager

# Precarichiamo la scena della carta visiva per efficienza
@export var card_scene: PackedScene = preload("res://scenes/CardVisual.tscn") # Assicurati che questo percorso sia corretto!

# --- Variabile per PlayerPositions ---
# NON usiamo @onready qui. Definiamo solo la variabile.
var player_positions_node: Node3D = null

# Variabili per lo stato del gioco
var num_players: int = 0
var dealer_index: int = 0
var current_turn_index: int = 0

# Struttura dati giocatori
var players_data: Array[Dictionary] = []
# Array per carte visive
var active_card_instances: Array[CardVisual] = []

# Enum per stati
enum GameState { SETUP, DEALING, PLAYER_TURN, SWAPPING, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP

# Chiamato quando il nodo GameManager (e i suoi figli) è pronto
func _ready():
	print("GameManager pronto.")

	# --- Assegnazione PlayerPositions DENTRO _ready ---
	player_positions_node = $PlayerPositions # O get_node("PlayerPositions")
	if player_positions_node == null:
		# Questo NON dovrebbe succedere ora, basandoci sul debug precedente!
		printerr("!!! ERRORE CRITICO: Impossibile trovare PlayerPositions anche dentro _ready() !!!")
		return # Non possiamo continuare
	else:
		print("+++ Nodo PlayerPositions assegnato correttamente in _ready() +++")

	# Controlla se abbiamo caricato la scena della carta
	if card_scene == null:
		printerr("ERRORE: Card Scene non precaricata!")
		return

	# --- RIPRISTINIAMO L'AVVIO DEL GIOCO ---
	start_game(4)
	# --- FINE CODICE TEMPORANEO PER TEST ---


# Funzione per iniziare una nuova partita (versione originale)
func start_game(p_num_players: int):
	print("Inizio partita con ", p_num_players, " giocatori.")
	current_state = GameState.SETUP
	num_players = p_num_players

	# Pulizia
	for card_instance in active_card_instances:
		if is_instance_valid(card_instance):
			card_instance.queue_free()
	active_card_instances.clear()
	players_data.clear()

	# --- CORREZIONE DeckManager ---
	deck_manager.reset_and_shuffle() # Usa DeckManager, non game_manager

	# Controlla posti (ora usa la variabile membro player_positions_node)
	if player_positions_node == null: # Controllo extra per sicurezza
		printerr("ERRORE: player_positions_node è null in start_game!")
		return
	var available_spots = player_positions_node.get_child_count()
	if num_players > available_spots:
		printerr("ERRORE: Non ci sono abbastanza Marker3D per ", num_players, " giocatori!")
		num_players = available_spots

	# Inizializza giocatori
	for i in range(num_players):
		var player_marker = player_positions_node.get_child(i) as Marker3D
		if player_marker == null:
			printerr("ERRORE: Figlio ", i, " non è Marker3D!")
			continue
		players_data.append({
			"card_data": null, "lives": 5, "marker": player_marker, "visual_card": null
		})

	dealer_index = 0
	# Distribuzione
	deal_initial_cards() # Chiama la versione originale
	current_turn_index = (dealer_index + 1) % num_players
	current_state = GameState.PLAYER_TURN
	print("Carte distribuite. Tocca al giocatore ", current_turn_index)


# Funzione per distribuire le carte iniziali (versione originale)
func deal_initial_cards():
	current_state = GameState.DEALING
	print("Distribuzione carte...")

	if player_positions_node == null: # Controllo extra per sicurezza
		printerr("ERRORE: player_positions_node è null in deal_initial_cards!")
		return

	for i in range(num_players):
		# --- CORREZIONE DeckManager ---
		var drawn_card_data: CardData = deck_manager.draw_card() # Usa DeckManager
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

# ... (eventuali altre funzioni che avevi possono rimanere) ...
