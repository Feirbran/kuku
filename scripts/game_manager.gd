# game_manager.gd
extends Node3D
class_name GameManager

# Precarichiamo la scena della carta visiva per efficienza
@export var card_scene: PackedScene = preload("res://scenes/CardVisual.tscn")

# Riferimenti ai nodi importanti nella scena (verranno assegnati in _ready)
@onready var player_positions_node: Node3D = $PlayerPositions
# Nota: Il simbolo '$' è una scorciatoia per get_node().
# "$PlayerPositions" equivale a get_node("PlayerPositions").
# Assicurati che il nodo nell'albero della scena si chiami ESATTAMENTE "PlayerPositions".

# Variabili per lo stato del gioco
var num_players: int = 0
var dealer_index: int = 0
var current_turn_index: int = 0 # Chi è di turno

# Struttura per memorizzare i dati dei giocatori (semplice per ora)
# Ogni elemento sarà un dizionario: {"card_data": CardData, "lives": 5, "marker": Marker3D, "visual_card": CardVisual}
var players_data: Array[Dictionary] = []

# Array per tenere traccia delle istanze delle carte visive sul tavolo
var active_card_instances: Array[CardVisual] = []

# Enum per gli stati del gioco (li useremo più avanti)
enum GameState { SETUP, DEALING, PLAYER_TURN, SWAPPING, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP

# Chiamato quando il nodo GameManager (e i suoi figli) è pronto
func _ready():
	print("GameManager pronto.")
	# Controlla se abbiamo effettivamente caricato la scena della carta
	if card_scene == null:
		printerr("ERRORE: Card Scene non precaricata!")
		return
	if player_positions_node == null:
		printerr("ERRORE: Nodo PlayerPositions non trovato!")
		return

	# --- INIZIO CODICE TEMPORANEO PER TEST ---
	# Normalmente, chiameresti start_game() da un pulsante della UI.
	# Per ora, avviamo una partita con 4 giocatori appena il gioco parte.
	start_game(4)
	# --- FINE CODICE TEMPORANEO PER TEST ---


# Funzione per iniziare una nuova partita
func start_game(p_num_players: int):
	print("Inizio partita con ", p_num_players, " giocatori.")
	current_state = GameState.SETUP
	num_players = p_num_players

	# --- Pulizia prima di iniziare ---
	# Rimuovi le carte visive dalla partita precedente
	for card_instance in active_card_instances:
		if is_instance_valid(card_instance): # Controlla se il nodo esiste ancora
			card_instance.queue_free() # Rimuove il nodo dalla scena in modo sicuro
	active_card_instances.clear()
	players_data.clear() # Svuota i dati dei giocatori precedenti

	# --- Preparazione Mazzo e Giocatori ---
	game_manager.reset_and_shuffle() # Usa l'Autoload per resettare e mescolare

	# Controlla se ci sono abbastanza posti per i giocatori
	var available_spots = player_positions_node.get_child_count()
	if num_players > available_spots:
		printerr("ERRORE: Non ci sono abbastanza Marker3D in PlayerPositions per ", num_players, " giocatori!")
		num_players = available_spots # Limita i giocatori ai posti disponibili

	# Inizializza i dati per ogni giocatore
	for i in range(num_players):
		var player_marker = player_positions_node.get_child(i) as Marker3D
		if player_marker == null:
			printerr("ERRORE: Il figlio ", i, " di PlayerPositions non è un Marker3D!")
			continue # Salta questo giocatore se il marker non è valido

		players_data.append({
			"card_data": null, # La carta verrà assegnata durante la distribuzione
			"lives": 5, # Numero iniziale di dita/vite (puoi cambiarlo)
			"marker": player_marker, # Riferimento al suo segnaposto
			"visual_card": null # La carta visiva verrà assegnata durante la distribuzione
		})

	# Scegli un mazziere iniziale (es. il primo giocatore)
	dealer_index = 0

	# --- Distribuzione Carte ---
	deal_initial_cards()

	# Imposta il primo giocatore (es. quello dopo il mazziere)
	current_turn_index = (dealer_index + 1) % num_players
	current_state = GameState.PLAYER_TURN # Pronto per il primo turno (logica da implementare)
	print("Carte distribuite. Tocca al giocatore ", current_turn_index)


# Funzione per distribuire le carte iniziali
func deal_initial_cards():
	current_state = GameState.DEALING
	print("Distribuzione carte...")

	for i in range(num_players):
		# Pesca una carta DAL MAZZO DI DATI
		var drawn_card_data: CardData = game_manager.draw_card()
		if drawn_card_data == null:
			printerr("ERRORE: Il mazzo è finito durante la distribuzione iniziale!")
			# Qui potresti dover gestire un errore grave
			break # Interrompi la distribuzione

		# Aggiorna i dati del giocatore
		players_data[i]["card_data"] = drawn_card_data

		# Crea un'istanza della SCENA VISIVA della carta
		var card_instance = card_scene.instantiate() as CardVisual
		if card_instance == null:
			printerr("ERRORE: Impossibile istanziare CardVisual!")
			continue

		# Aggiungi la carta visiva come figlio del GameManager (o potresti metterla sotto il marker)
		add_child(card_instance)

		# ----- COLLEGAMENTO CHIAVE: Assegna i dati alla carta visiva -----
		card_instance.card_data = drawn_card_data
		# Grazie alla "setter" in CardVisual.gd, questo imposterà anche la texture (prob. coperta)

		# Aggiorna i dati del giocatore con la sua carta visiva
		players_data[i]["visual_card"] = card_instance

		# Posiziona la carta visiva sul tavolo
		var player_marker: Marker3D = players_data[i]["marker"]
		card_instance.global_transform.origin = player_marker.global_transform.origin + Vector3(0, 0.02, 0) # Leggermente sollevata
		# Potresti voler ruotare la carta per orientarla verso il centro o il giocatore
		# card_instance.look_at(Vector3.ZERO, Vector3.UP) # Esempio: falla guardare verso il centro

		# Assicurati che la carta sia coperta all'inizio
		card_instance.show_back()

		# Tieni traccia dell'istanza della carta visiva
		active_card_instances.append(card_instance)

	print("Distribuzione completata.")

# --- Qui andranno le funzioni per gestire i turni, gli scambi, ecc. ---
# func player_turn(player_index):
#     pass
# func resolve_swaps():
#     pass
# func reveal_cards():
#     pass
# func end_round():
#     pass
