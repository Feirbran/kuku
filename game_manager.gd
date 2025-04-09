# game_manager.gd
extends Node3D
class_name GameManager

# Precarica la scena della carta (il modello visivo della carta)
@export var card_scene: PackedScene = preload("res://scenes/CardVisual.tscn")
#Variabile per identificare il giocatore umano
var local_player_index = 2
# Variabile per memorizzare il nodo PlayerPositions nella scena
var player_positions_node: Node3D = null
# Numero di giocatori nella partita
var num_players: int = 0
# Indice del giocatore che è il mazziere
var dealer_index: int = 0
# Indice del giocatore a cui tocca il turno corrente
var current_turn_index: int = 0
# Array per contenere i dati di ogni giocatore (carta, vite, posizione, nodo visuale)
var players_data: Array[Dictionary] = []
# Array per tenere traccia di tutte le istanze di carta attive nella scena
var active_card_instances: Array[CardVisual] = []

# Enumerazione per definire i diversi stati del gioco
enum GameState { SETUP, DEALING, PLAYER_TURN, SWAPPING, REVEALING, END_ROUND, GAME_OVER }
# Variabile per tenere traccia dello stato corrente del gioco
var current_state: GameState = GameState.SETUP

# Questa funzione viene chiamata automaticamente quando il nodo (GameManager) entra nell'albero della scena
func _ready():
	print("GameManager _ready() chiamato.")
	# Connette il segnale 'ready' del nodo radice 'GameTable' a una funzione in questo script
	# Questo assicura che il codice in _on_game_table_ready() venga eseguito solo quando tutta la scena GameTable è pronta
	if get_node("/root/GameTable").is_connected("ready", _on_game_table_ready) == false:
		get_node("/root/GameTable").ready.connect(_on_game_table_ready)
	# Verifica se la scena della carta è stata precaricata correttamente
	if card_scene == null:
		printerr("ERRORE: Card Scene non precaricata!")
		return
	# L'avvio del gioco ora avviene dopo che PlayerPositions è pronto nella funzione _on_game_table_ready()

# Questa funzione viene chiamata quando il segnale 'ready' del nodo 'GameTable' viene emesso
func _on_game_table_ready():
	print("Segnale ready di GameTable ricevuto.")
	# Ottiene il nodo 'PlayerPositions' accedendo al padre (GameTable) e poi al figlio 'PlayerPositions'
	player_positions_node = get_node("../PlayerPositions")
	# Verifica se il nodo 'PlayerPositions' è stato trovato
	if player_positions_node == null:
		printerr("!!! ERRORE CRITICO: Impossibile trovare PlayerPositions (nel segnale ready) !!!")
		# Stampa informazioni utili per il debug se il nodo non viene trovato
		if get_parent() != null:
			print("Figli di GameTable:")
			for child in get_parent().get_children():
				print("- ", child.get_name())
		else:
			print("GameManager non ha un padre!")
	else:
		print("+++ Nodo PlayerPositions assegnato correttamente (nel segnale ready) +++")
		# Avvia la partita solo se il nodo 'PlayerPositions' è stato trovato
		start_game(4)

# Questa funzione avvia una nuova partita
func start_game(p_num_players: int):
	print("Inizio partita con ", p_num_players, " giocatori.")
	current_state = GameState.SETUP
	num_players = p_num_players

	# Pulisce le carte attive e i dati dei giocatori da una partita precedente
	for card_instance in active_card_instances:
		if is_instance_valid(card_instance):
			card_instance.queue_free() # Elimina l'istanza del nodo carta
	active_card_instances.clear() # Svuota l'array delle carte attive
	players_data.clear() # Svuota l'array dei dati dei giocatori

	print("PRIMA di DeckSetupScene.reset_and_shuffle() (in start_game)")
	DeckSetupScene.reset_and_shuffle() # Resetta e mescola il mazzo usando l'istanza globale (Autoload)
	print("DOPO di DeckSetupScene.reset_and_shuffle() (in start_game)")

	# Verifica se il nodo 'PlayerPositions' è stato trovato
	if player_positions_node == null:
		printerr("ERRORE: player_positions_node è null in start_game!")
		return
	# Ottiene il numero di posizioni giocatore disponibili
	var available_spots = player_positions_node.get_child_count()
	# Se ci sono più giocatori del numero di posizioni, limita il numero di giocatori
	if num_players > available_spots:
		printerr("ERRORE: Non ci sono abbastanza Marker3D per ", num_players, " giocatori!")
		num_players = available_spots

	# Inizializza i dati per ogni giocatore
	for i in range(num_players):
		var player_marker = player_positions_node.get_child(i) as Marker3D
		# Verifica se il figlio è effettivamente un Marker3D
		if player_marker == null:
			printerr("ERRORE: Figlio ", i, " non è Marker3D!")
			continue
		# Aggiunge un dizionario all'array players_data per ogni giocatore
		players_data.append({
			"card_data": null, # Dati della carta del giocatore (inizialmente null)
			"lives": 5,       # Vite del giocatore
			"marker": player_marker, # Nodo Marker3D per la posizione del giocatore
			"visual_card": null # Nodo CardVisual della carta del giocatore (inizialmente null)
		})

	dealer_index = 0 # Imposta il primo giocatore come mazziere (potrebbe essere casuale in futuro)
	deal_initial_cards() # Chiama la funzione per distribuire le carte iniziali
	current_turn_index = (dealer_index + 1) % num_players # Imposta il primo giocatore a cui tocca (dopo il mazziere)
	current_state = GameState.PLAYER_TURN # Cambia lo stato del gioco al turno del giocatore
	print("Carte distribuite. Tocca al giocatore ", current_turn_index)

	# Itera su ogni giocatore
func deal_initial_cards():
	current_state = GameState.DEALING
	print("Distribuzione carte...")

	if player_positions_node == null:
		printerr("ERRORE: player_positions_node è null in deal_initial_cards!")
		return

	for i in range(num_players):
		var drawn_card_data: CardData = DeckSetupScene.draw_card()
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

		card_instance.global_transform.origin = player_marker.global_transform.origin + player_marker.transform.basis.z * 0.5 + Vector3(0, 0.02, 0)
		card_instance.global_transform.basis = player_marker.global_transform.basis

		# Assumi che tu abbia una variabile 'local_player_index' che indica l'indice del giocatore locale
		if i == local_player_index:
			card_instance.show_front() # Mostra il fronte per il giocatore locale
		else:
			card_instance.show_back()  # Mostra il retro per gli altri giocatori

		active_card_instances.append(card_instance)

	print("Distribuzione completata.")
# Qui puoi aggiungere altre funzioni del tuo game_manager (gestione del turno, ecc.)
