# game_manager.gd
# Versione corretta con assegnazione casuale classi e gestione stato delegata a Player.gd
extends Node3D
class_name GameManager

# --- Export per Scene, UI e Dati ---
@export var card_scene: PackedScene						# Scena CardVisual.tscn
@export var swap_button: Button						# Bottone Scambia (a dx)
@export var pass_button: Button						# Bottone Passa (normale)
@export var swap_to_deck_button: Button				# Bottone Scambia con Mazzo (Mazziere)
@export var pass_as_dealer_button: Button			# Bottone Passa (Mazziere)
@export var player_lives_labels: Array[Label]		# Array per Label vite giocatori (Popolare nell'editor, Size 10)
@export var last_hand_labels: Array[Label]			# Opzionale: Array per Label nomi ultima mano (Popolare nell'editor, Size 10)
@export var last_hand_textures: Array[TextureRect]	# Array per TextureRect ultima mano (Popolare nell'editor, Size 10)
@export var deck_position_marker: Marker3D			# Marker per posizione mazzo centrale
@export var player_nodes: Array[Node]				# Array per contenere i nodi Player0..9 (Popolare nell'editor, Size 10)
@export var all_class_datas: Array[CharacterClassData] # <-- NUOVO: Array per contenere TUTTE le risorse *_class.tres (Popolare nell'editor, Size 10)

@onready var cucu_notification_label: Label = %EffectLabelKUKU
@onready var notification_timer: Timer = %Timer
# --- Fine Export ---

# --- Variabili Interne ---
var player_positions_node: Node3D = null
var num_players: int = 10 # Dovrebbe corrispondere alla dimensione degli array esportati
var dealer_index: int = 0
var current_player_index: int = 0
var players_data: Array[Dictionary] = [] # Conterrà dati NON di stato (id, marker, is_cpu, card_data, ecc.)
var active_card_instances: Array[CardVisual] = []
var last_clicked_player_index: int = -1 # Probabilmente non più usato se si usano bottoni UI
const DECK_STACK_COUNT = 5
var deck_visual_instances: Array[Node3D] = []

enum GameState { SETUP, DEALING, PLAYER_TURN, DEALER_SWAP, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP

# Assicurati che DeckSetupScene sia un Autoload o accessibile in altro modo
# var DeckSetupScene = preload("res://path/to/deck_setup_scene.gd") # Esempio se non è Autoload

func _ready():
    # Controlli essenziali all'avvio
    if card_scene == null: printerr("!!! ERRORE _ready: 'Card Scene' non assegnata!"); get_tree().quit(); return
    if player_nodes.size() != num_players: printerr("!!! ATTENZIONE _ready: 'player_nodes' non ha la dimensione corretta (%d vs %d)!" % [player_nodes.size(), num_players])
    if all_class_datas.size() != num_players: printerr("!!! ATTENZIONE _ready: 'all_class_datas' non ha la dimensione corretta (%d vs %d)!" % [all_class_datas.size(), num_players])
    if player_lives_labels.size() != num_players and player_lives_labels.size() > 0: printerr("!!! ATTENZIONE _ready: Numero Label vite (%d) non corrisponde a num_players (%d)!" % [player_lives_labels.size(), num_players])
    
    # Controlli bottoni (opzionali ma utili)
    if swap_button == null or pass_button == null or swap_to_deck_button == null or pass_as_dealer_button == null:
        printerr("!!! ATTENZIONE _ready: Uno o più bottoni azione non assegnati!")
        
    # Setup Timer Notifiche
    if cucu_notification_label == null: printerr("ATTENZIONE _ready: Nodo CucuNotificationLabel non trovato! Controllare percorso in @onready.")
    if notification_timer == null: printerr("ATTENZIONE _ready: Nodo NotificationTimer non trovato! Controllare percorso in @onready.")
    else:
        if not notification_timer.is_connected("timeout", Callable(self, "_on_notification_timer_timeout")):
            notification_timer.connect("timeout", Callable(self, "_on_notification_timer_timeout"))

    # Recupero PlayerPositions
    player_positions_node = get_node_or_null("../PlayerPositions") # Adatta path se necessario
    if player_positions_node == null: printerr("!!! ERRORE _ready: Impossibile trovare PlayerPositions!"); get_tree().quit(); return

    # Inizializza generatore casuale
    randomize()
    
    print("+++ GameManager pronto +++")

    # --- Crea Visuale Mazzo ---
    _create_deck_visual_stack() # Spostato in funzione helper

    # --- Avvio gioco differito ---
    call_deferred("start_game", num_players)

func _create_deck_visual_stack():
    # Pulisci istanze precedenti
    for instance in deck_visual_instances:
        if is_instance_valid(instance): instance.queue_free()
    deck_visual_instances.clear()

    # Crea la pila visuale del mazzo se il marker e la scena sono validi
    if is_instance_valid(deck_position_marker) and card_scene != null:
        print("Creazione pila mazzo (%d istanze)..." % DECK_STACK_COUNT)
        for i in range(DECK_STACK_COUNT):
            var instance = card_scene.instantiate()
            if instance is CardVisual:
                var visual = instance as CardVisual
                add_child(visual)
                visual.global_position = deck_position_marker.global_position
                visual.global_position.y += 0.01 + i * 0.002 # Offset per pila
                visual.rotation_degrees = Vector3(90, 90, 0) # <-- USA LA TUA ROTAZIONE CORRETTA!
                visual.show_back()
                visual.set_physics_active(false)
                deck_visual_instances.append(visual)
            else:
                printerr("ERRORE: Istanza %d non è CardVisual." % i)
                if is_instance_valid(instance): instance.queue_free()

        if not deck_visual_instances.is_empty(): print("Visuale mazzo (pila) creata.")
        else: printerr("ERRORE: Nessuna istanza valida creata per la pila del mazzo.")
    elif not is_instance_valid(deck_position_marker):
        printerr("ERRORE _create_deck_visual_stack: deck_position_marker non valido!")
    elif card_scene == null:
        printerr("ERRORE _create_deck_visual_stack: card_scene non assegnata!")


func start_game(p_num_players: int):
    print("Richiesta partita con %d giocatori." % p_num_players)
    current_state = GameState.SETUP
    num_players = p_num_players

    # Resetta lo stato del gioco (inclusa assegnazione classi ora)
    _reset_game()

    # Controlla se il reset è andato a buon fine (se players_data è popolato)
    if players_data.size() != num_players:
        printerr("Reset fallito o incompleto. Dimensione players_data (%d) non corrisponde a num_players (%d)." % [players_data.size(), num_players])
        return

    # Assegna Mazziere Casuale
    if num_players > 0:
        dealer_index = randi() % num_players
    else:
        dealer_index = 0
        printerr("ATTENZIONE start_game: num_players è 0 o meno!")
    print("Inizio partita. Mazziere Casuale: Player %d" % dealer_index)
    
    # Avvia il primo round
    call_deferred("_start_round")


func _reset_game():
    print("Resetting game...")
    
    # 1. Pulisci istanze carte dei giocatori precedenti
    for card_instance in active_card_instances:
        if is_instance_valid(card_instance): card_instance.queue_free()
    active_card_instances.clear()
    
    # 2. Pulisci i dati dei giocatori precedenti
    players_data.clear()

    # 3. Pulisci la visuale del mazzo precedente
    for instance in deck_visual_instances:
        if is_instance_valid(instance): instance.queue_free()
    deck_visual_instances.clear()

    # 4. Inizializza i dati base per ogni giocatore nell'array players_data
    print("Inizializzazione dati base per %d giocatori..." % num_players)
    if not is_instance_valid(player_positions_node):
        printerr("ERRORE CRITICO _reset_game: PlayerPositions non valido!"); return
    var markers = player_positions_node.get_children()
    if markers.size() < num_players:
        printerr("ERRORE CRITICO _reset_game: Non ci sono abbastanza Marker3D (%d) per %d giocatori!" % [markers.size(), num_players])
        return

    # Loop per creare la struttura dati base in players_data
    for i in range(num_players):
        var player_marker = markers[i] if i < markers.size() else null
        if not player_marker is Marker3D:
            printerr("ATTENZIONE _reset_game: Elemento %d in PlayerPositions non è Marker3D!" % i)
            player_marker = null

        # Crea il dizionario SENZA stato dinamico (vite, sanità, ecc.)
        var new_player_data = {
            "id": i,
            "marker": player_marker,
            "is_out": false, # Questo verrà poi sincronizzato con lo stato del nodo Player
            "is_cpu": (i != 0), # Esempio: Player 0 è umano
            "card_data": [], # Carta attuale (dati)
            "visual_cards": [], # Carta attuale (visuale)
            "has_swapped_this_round": false,
            "last_card": null # Carta a fine round precedente
            # Considera se aggiungere qui il riferimento al nodo:
            # "node": player_nodes[i] if i < player_nodes.size() else null 
        }
        players_data.append(new_player_data)

    # Controllo sicurezza
    if players_data.size() != num_players:
        printerr("ERRORE INASPETTATO _reset_game: Dopo inizializzazione, players_data ha %d elementi invece di %d!" % [players_data.size(), num_players])
        return

    print("Dati base giocatori inizializzati. Numero elementi in players_data: %d" % players_data.size())
    
    # 5. Assegna Classi Casuali, ID e Connetti Segnali ai Nodi Player
    print("Assegnazione classi casuali e connessione segnali...")
    if all_class_datas.size() < num_players: # Controllo se abbiamo abbastanza classi definite!
        printerr("ERRORE _reset_game: Non ci sono abbastanza classi definite in 'all_class_datas' (%d) per %d giocatori!" % [all_class_datas.size(), num_players])
        # Gestire questo caso? Uscire? Usare una classe di default? Per ora usciamo.
        return
    elif player_nodes.size() != num_players:
        printerr("ERRORE _reset_game: Numero di nodi in 'player_nodes' (%d) non corrisponde a num_players (%d)!" % [player_nodes.size(), num_players])
        return
    else:
        # Tutto sembra ok, procediamo con l'assegnazione
        var available_classes = all_class_datas.duplicate() # Copia per mescolare
        available_classes.shuffle() # Mescola casualmente
        
        for i in range(num_players):
            var player_node = player_nodes[i]
            
            if available_classes.is_empty(): # Sicurezza extra
                printerr("ERRORE _reset_game: Finite le classi disponibili!")
                break

            var chosen_class = available_classes.pop_front() # Prende e rimuove la classe
            
            if not is_instance_valid(player_node) or not player_node.has_method("assign_class"):
                printerr("ERRORE _reset_game: Nodo Player %d non valido o manca assign_class()." % i)
                continue

            # Chiama assign_class sul nodo Player passando la classe scelta e l'ID
            player_node.assign_class(chosen_class, i)
            
            # Connetti il segnale per l'aggiornamento delle vite
            # Ci assicuriamo di connettere una sola volta
            if player_node.has_signal("fingers_updated") and not player_node.is_connected("fingers_updated", Callable(self, "_on_player_fingers_updated")):
                var err = player_node.connect("fingers_updated", Callable(self, "_on_player_fingers_updated"))
                if err != OK: printerr("Errore connessione fingers_updated per Player ", i, ": Codice ", err)
            
            # TODO: Connetti qui altri segnali da Player a GameManager se necessario 
            # Esempio: player_node.player_eliminated.connect(_on_player_eliminated)
            
        print("Classi assegnate casualmente e segnali connessi.")

    # 6. Aggiorna l'UI iniziale delle Vite leggendo dai Nodi Player
    if player_lives_labels.size() == player_nodes.size():
        print("Aggiornamento label vite iniziale...")
        for j in range(player_nodes.size()):
            var player_node = player_nodes[j]
            var label = player_lives_labels[j] if j < player_lives_labels.size() and is_instance_valid(player_lives_labels[j]) else null
            
            if label and is_instance_valid(player_node) and player_node.has_method("get_fingers_remaining"):
                var current_lives = player_node.get_fingers_remaining()
                label.text = "Vite P%d: %d" % [j, current_lives]
                label.visible = not player_node.is_out # Legge lo stato is_out dal nodo Player
            elif label:
                label.visible = false
    elif player_lives_labels.size() > 0:
        printerr("ATTENZIONE _reset_game: Numero Label vite (%d) non corrisponde ai nodi Player (%d)!" % [player_lives_labels.size(), player_nodes.size()])

    # 7. Aggiorna l'UI iniziale dell'Ultima Mano
    if last_hand_textures.size() == players_data.size():
        print("Resetting UI ultima mano...")
        for k in range(last_hand_textures.size()):
            var texture_rect = last_hand_textures[k] if k < last_hand_textures.size() and is_instance_valid(last_hand_textures[k]) else null
            if texture_rect: texture_rect.visible = false
            var name_label = last_hand_labels[k] if k < last_hand_labels.size() and is_instance_valid(last_hand_labels[k]) else null
            if name_label: name_label.text = "P%d:" % k
    elif last_hand_textures.size() > 0:
        printerr("ATTENZIONE _reset_game: Numero TextureRect ultima mano (%d) non corrisponde ai giocatori (%d)!" % [last_hand_textures.size(), players_data.size()])

    # 8. Fine Reset
    print("Reset game completato.")

func _handle_game_over(active_count: int):
    print("\n=== PARTITA FINITA! ===")
    current_state = GameState.GAME_OVER
    _update_player_action_buttons() # Disabilita bottoni

    if active_count == 1:
        # Trova l'unico vincitore rimasto
        for i in range(player_nodes.size()):
            var p_node = player_nodes[i]
            # Controlla se il nodo è valido e non è fuori
            if is_instance_valid(p_node) and not p_node.is_out: 
                print("VINCITORE: Player %d !" % i) 
                # Qui potresti voler accedere al nome del personaggio/classe dal nodo:
                # if p_node.has_method("get_class_display_name"): # Funzione helper ipotetica in Player.gd
                #    print("Classe: ", p_node.get_class_display_name())
                break # Trovato il vincitore, esci dal loop
    elif active_count == 0:
        print("Tutti eliminati! Nessun vincitore.")
    else:
        # Questo caso non dovrebbe accadere se la logica è corretta, ma è una sicurezza
        print("Fine partita inattesa con %d giocatori attivi." % active_count)

    # --- AGGIUNGERE QUI UI FINE PARTITA / OPZIONE RIAVVIO ---
    # Esempio: Mostra un pannello di fine partita
    # $UINode/GameOverPanel.show_results(vincitore_id) # Esempio

# --- Gestione Round ---
# (Funzioni _start_round, _deal_initial_cards, _advance_turn, _go_to_dealer_phase...)
# Queste funzioni potrebbero necessitare di leggere 'is_out' da player_nodes[index].is_out
# invece che da players_data[index].is_out per coerenza futura.
# Per ora, il codice che hai fornito sembra usare players_data[index].is_out.
# Lasciamo così per ora, ma è un punto da rivedere per la sincronizzazione dello stato.
# ... (INCOLLA QUI LE TUE FUNZIONI _start_round, _deal_initial_cards, _advance_turn, _go_to_dealer_phase) ...

func _start_round():
    # Controllo stato is_out leggendo DAI NODI PLAYER (più corretto)
    var active_players_count = 0
    for i in range(player_nodes.size()):
        var p_node = player_nodes[i]
        if is_instance_valid(p_node) and not p_node.is_out:
            active_players_count += 1
            # Sincronizza players_data.is_out (se lo usi ancora altrove)
            if i < players_data.size(): players_data[i].is_out = false
        elif i < players_data.size():
            players_data[i].is_out = true # Assicura sincronia
             
    if active_players_count <= 1: _handle_game_over(active_players_count); return
    
    print("\n--- Inizia Round. Mazziere: %d ---" % dealer_index); current_state = GameState.DEALING
    
    # Pulisci carte round precedente e resetta flag 'has_swapped'
    for i in range(players_data.size()):
        var player_data = players_data[i]
        # Pulisci visual cards (active_card_instances verrà pulito implicitamente?)
        # Assicurati che active_card_instances venga gestito correttamente se non fai clear qui
        for card_visual in player_data.visual_cards:
            if is_instance_valid(card_visual):
                # Rimuovi da active_card_instances se lo usi per altro
                if active_card_instances.has(card_visual): active_card_instances.erase(card_visual)
                card_visual.queue_free()
        player_data.visual_cards.clear()
        player_data.card_data.clear()
        
        # Reset flag swap solo per chi è IN gioco
        var p_node = player_nodes[i] if i < player_nodes.size() else null
        if is_instance_valid(p_node) and not p_node.is_out:
            player_data.has_swapped_this_round = false
        else:
            player_data.has_swapped_this_round = true # Se è fuori, considera che abbia già "agito"

    # Prepara il mazzo e distribuisci
    if DeckSetupScene == null: printerr("ERRORE CRITICO: DeckSetupScene è null!"); return
    DeckSetupScene.reset_and_shuffle()
    _deal_initial_cards()
    
    if current_state == GameState.GAME_OVER: return # Se il mazzo finisce durante la distribuzione
    
    # Trova il prossimo giocatore attivo dopo il mazziere
    current_player_index = get_next_active_player(dealer_index, false) # Anti-orario
    if current_player_index == -1:
        printerr("ERRORE _start_round: Nessun giocatore attivo trovato dopo il mazziere!");
        _handle_game_over(active_players_count); # Usa il conteggio aggiornato
        return
        
    current_state = GameState.PLAYER_TURN
    print("Carte distribuite. Tocca a player %d." % current_player_index)
    
    # Aggiorna UI e avvia turno CPU se necessario
    _update_player_action_buttons()
    _update_deck_visual()
    
    # Controlla is_cpu da players_data (ok), ma verifica validità nodo
    var current_p_node = player_nodes[current_player_index] if current_player_index < player_nodes.size() else null
    if is_instance_valid(current_p_node) and not current_p_node.is_out and players_data[current_player_index].is_cpu:
        call_deferred("_make_cpu_turn")


func _deal_initial_cards():
    print("Distribuzione..."); 
    var main_camera = get_viewport().get_camera_3d()
    if not is_instance_valid(main_camera): 
        printerr("ERRORE _deal_initial_cards: Camera non trovata!"); 
        current_state = GameState.GAME_OVER; return

    # Iteriamo sui nodi Player collegati nell'editor
    for i in range(player_nodes.size()): 
        var p_node = player_nodes[i]
        
        # Salta se il nodo non è valido o il giocatore è fuori (legge da Player.gd)
        if not is_instance_valid(p_node) or p_node.is_out: 
            if i < players_data.size(): players_data[i].card_data.clear() # Pulisci i dati carta nel dizionario se fuori
            continue
            
        # Ottieni i dati corrispondenti dall'array players_data (per marker, card_data, ecc.)
        if i >= players_data.size():
            printerr("ERRORE _deal_initial_cards: Indice %d fuori range per players_data (size %d)" % [i, players_data.size()])
            continue
            
        var player_data = players_data[i] 
        var player_marker: Marker3D = player_data.get("marker", null) # Usa get per sicurezza
        
        if not is_instance_valid(player_marker): 
            printerr("ATTENZIONE _deal_initial_cards: Marker non valido per Player %d" % i)
            continue 

        # Pesca la carta
        var drawn_card_data: CardData = DeckSetupScene.draw_card()
        if drawn_card_data == null: 
            printerr("ERRORE _deal_initial_cards: Mazzo finito!"); current_state = GameState.GAME_OVER; return
        if not drawn_card_data is CardData: 
            printerr("ERRORE _deal_initial_cards: draw_card() tipo non valido!"); current_state = GameState.GAME_OVER; return
            
        player_data["card_data"] = [drawn_card_data] # Imposta i dati carta nel dizionario

        # Istanzia la scena CardVisual
        var card_instance = card_scene.instantiate() as CardVisual
        if not card_instance: continue
        
        card_instance.card_data = drawn_card_data # Assegna i dati alla visuale
        add_child(card_instance) # Aggiungi come figlio del GameManager 
        
        player_data["visual_cards"] = [card_instance] # Salva riferimento alla visuale nel dizionario
        active_card_instances.append(card_instance) # Tieni traccia globale se serve

        # --- POSIZIONAMENTO E ROTAZIONE---
        # Nota l'offset Y a 0.5 e la rotazione X dopo look_at
        var card_position = player_marker.global_transform.origin + Vector3(0,0.5, 0)
        card_instance.global_transform.origin = card_position
        card_instance.look_at(main_camera.global_transform.origin, Vector3.UP); card_instance.rotation.x = deg_to_rad(180)
        card_instance.look_at(main_camera.global_transform.origin, Vector3.UP); card_instance.rotation.y = deg_to_rad(180)
        # FINE POSIZIONAMENTO E ROTAZIONE
        
        # Mostra Fronte/Retro e Fisica (basato su is_cpu preso da players_data)
        if i == 0 and not player_data.is_cpu: # Giocatore umano
            card_instance.show_front()
            card_instance.set_physics_active(true) 
        else: # CPU
            card_instance.show_back()
            card_instance.set_physics_active(false)
            
    print("Carte distribuite.")
    _update_deck_visual() # Aggiorna la visuale del mazzo
    
# FINE FUNZIONE _deal_initial_cards
# --- Gestione Turni e Azioni ---
# (Funzioni _advance_turn, _go_to_dealer_phase...)
# Assicurati che queste usino lo stato 'is_out' corretto (da player_node o players_data sincronizzato)
# ... (INCOLLA QUI LE TUE FUNZIONI _advance_turn, _go_to_dealer_phase) ...
func _advance_turn():
    var next_player_candidate = -1
    var current_check = current_player_index
    
    # Ciclo limitato per sicurezza (max giocatori - 1 tentativi)
    for _i in range(player_nodes.size()):
        current_check = (current_check + 1) % player_nodes.size() # Avanza ANTI-ORARIO (assumendo 0..N)
        
        # Ottieni il nodo del giocatore candidato
        var candidate_node = player_nodes[current_check] if current_check < player_nodes.size() else null
        
        # Condizioni per essere il prossimo:
        # 1. Nodo valido e non fuori gioco
        # 2. Non è il mazziere attuale
        # 3. Non ha già agito in questo round (flag in players_data)
        if is_instance_valid(candidate_node) and \
            not candidate_node.is_out and \
            current_check != dealer_index and \
            not players_data[current_check].has_swapped_this_round:
               
                next_player_candidate = current_check
                break # Trovato il prossimo giocatore valido

        # Sicurezza anti-loop infinito se tutti avessero già agito o fossero fuori/mazziere
        if current_check == current_player_index:
            # Abbiamo fatto un giro completo senza trovare nessuno
            print("DEBUG _advance_turn: Giro completo, nessun candidato trovato.")
            next_player_candidate = -1 # Assicura che sia -1
            break

    # Se abbiamo trovato un candidato valido
    if next_player_candidate != -1:
        current_player_index = next_player_candidate
        print("Avanzamento turno. Tocca a player %d." % current_player_index)
        current_state = GameState.PLAYER_TURN
        _update_player_action_buttons()
        _update_deck_visual()
        
        # Controlla se è CPU e avvia il suo turno
        var current_p_node = player_nodes[current_player_index] # Sappiamo che è valido da sopra
        if players_data[current_player_index].is_cpu and not current_p_node.is_out: # Controllo ridondante is_out ma sicuro
            call_deferred("_make_cpu_turn")
    # Se non è stato trovato nessun candidato (tutti hanno agito o sono fuori/mazziere)
    else:
        print("DEBUG _advance_turn: Nessun giocatore valido per il turno, passo alla fase mazziere.")
        _go_to_dealer_phase()


func _go_to_dealer_phase():
    # Controlla se l'indice del mazziere è valido e se il nodo corrispondente è valido e in gioco
    var dealer_node = player_nodes[dealer_index] if dealer_index >= 0 and dealer_index < player_nodes.size() else null
    
    if not is_instance_valid(dealer_node) or dealer_node.is_out:
        print("Mazziere %d non valido o fuori gioco. Termino il round." % dealer_index)
        call_deferred("_end_round") # Termina il round se il mazziere non è valido
        return
        
    # Imposta lo stato e l'indice corrente
    current_player_index = dealer_index
    current_state = GameState.DEALER_SWAP
    print("Fase Mazziere (Player %d)." % current_player_index)
    
    # Aggiorna UI
    _update_player_action_buttons()
    _update_deck_visual()
    
    # Se il mazziere è CPU, avvia il suo turno
    if players_data[current_player_index].is_cpu: # Assumiamo che se il nodo è valido, anche i dati is_cpu sono ok
        call_deferred("_make_cpu_dealer_turn")


# --- Funzioni Handler Bottoni UI ---
# (Queste funzioni sembrano OK, assumono player 0 = umano)
# ... (INCOLLA QUI LE TUE FUNZIONI _on_..._pressed) ...
func _on_pass_turn_button_pressed():
    print(">> Pass Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
    if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
        print("Umano passa (tiene)."); _player_action(0, "hold")
    else: print("     -> Azione bottone Passa non valida ora.")
func _on_swap_button_pressed():
    print(">> Swap Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
    if current_state == GameState.PLAYER_TURN and current_player_index == 0 and not players_data[0].is_cpu and not players_data[0].has_swapped_this_round:
        print("Bottone 'Scambia' premuto.")
        var target_player_index = get_player_to_right(0) # Scambia a DESTRA
        if target_player_index != -1:
            print("Tentativo scambio (bottone) 0 -> %d (dx)" % target_player_index); _player_action(0, "swap", target_player_index)
        else: print("Nessun giocatore valido a destra.")
    else: print("     -> Azione bottone Scambia non valida ora.")
func _on_swap_to_deck_pressed():
    print(">> SwapDeck Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
    if current_state == GameState.DEALER_SWAP and current_player_index == 0 and not players_data[0].is_cpu:
        print("Bottone 'Scambia con Mazzo' premuto."); _dealer_action("swap_deck")
    else: print("     -> Azione 'Scambia con Mazzo' non valida ora.")
func _on_pass_as_dealer_pressed():
    print(">> PassDealer Button Pressed: State=%s, Player=%d" % [GameState.keys()[current_state], current_player_index])
    if current_state == GameState.DEALER_SWAP and current_player_index == 0 and not players_data[0].is_cpu:
        print("Bottone 'Passa (Mazziere)' premuto."); _dealer_action("pass")
    else: print("     -> Azione 'Passa (Mazziere)' non valida ora.")
func _on_card_clicked(_card_visual: CardVisual):
    print("Click su carta ignorato (usare bottoni).")


# --- Azioni Gioco (Logica Interna) ---
# (Funzioni _player_action, _dealer_action, _make_cpu_dealer_turn, _make_cpu_turn...)
# Assicurati che queste usino lo stato 'is_out' corretto (da player_node o players_data sincronizzato)
# e che my_card / target_card vengano letti da players_data[index].card_data
# ... (INCOLLA QUI LE TUE FUNZIONI _player_action, _dealer_action, _make_cpu_dealer_turn, _make_cpu_turn) ...
func _player_action(player_index: int, action: String, target_player_index: int = -1):
    # Controllo iniziale se il nodo player è valido e in gioco
    var player_node = player_nodes[player_index] if player_index >= 0 and player_index < player_nodes.size() else null
    if not is_instance_valid(player_node) or player_node.is_out:
        # printerr("_player_action: Player %d non valido o fuori." % player_index) # Debug opzionale
        return
        
    # Controllo se ha già agito (da players_data)
    if players_data[player_index].has_swapped_this_round:
        # print("_player_action: Player %d ha già agito." % player_index) # Debug opzionale
        return

    var my_card: CardData = _get_valid_carddata_from_player(player_index, "_pa my")
    var performed_action = false

    # --- Logica per azione SWAP ---
    if action == "swap":
        var target_card: CardData = null
        # Validazione target INIZIALE (Player B)
        var target_node = player_nodes[target_player_index] if target_player_index >= 0 and target_player_index < player_nodes.size() else null
        if not is_instance_valid(target_node) or target_node.is_out or target_player_index == player_index:
            printerr("ERRORE _player_action: Target scambio iniziale non valido: %d" % target_player_index)
        else:
            # Target iniziale valido, ottieni le carte
            target_card = _get_valid_carddata_from_player(target_player_index, "_pa target")
            if my_card == null or target_card == null:
                printerr("ERRORE _player_action: Dati carta mancanti per swap!")
            # Controlla se TU (Player A) hai il Re
            elif my_card.rank_name == "K":
                print("Azione Bloccata: Hai il Re (K), non puoi iniziare uno scambio!")
            # Controlla se il TARGET INIZIALE (Player B) ha il Re
            elif target_card.rank_name == "K":
                print("!!! KUKU !!! Player %d ha il Re (K)! Scambio fallito." % target_player_index)
                _show_effect_label("KUKU!", 1.5)
                players_data[player_index].has_swapped_this_round = true
                performed_action = true
            # Controlla se il TARGET INIZIALE (Player B) ha la Regina
            elif target_card.rank_name == "Q":
                print("!!! SALTA!!! Player %d ha la Regina (Q)! Scambio obbligato col successivo." % target_player_index)
                _show_effect_label("SALTA!", 1.5)
                # Trova il NUOVO target (Player C), a DESTRA di B
                var new_target_index = get_player_to_right(target_player_index)
                print("     -> Nuovo target calcolato: Player %d" % new_target_index)
                # Validazione NUOVO target (Player C)
                var new_target_node = player_nodes[new_target_index] if new_target_index >= 0 and new_target_index < player_nodes.size() else null
                if not is_instance_valid(new_target_node) or new_target_node.is_out or new_target_index == player_index:
                    printerr("ERRORE _player_action: Nuovo target (%d) dopo Salta non valido. Scambio annullato." % new_target_index)
                    players_data[player_index].has_swapped_this_round = true
                    performed_action = true
                else:
                    # Nuovo target valido, prendi la sua carta
                    var new_target_card = _get_valid_carddata_from_player(new_target_index, "_pa new_target")
                    if new_target_card == null:
                        printerr("ERRORE _player_action: Dati carta mancanti per NUOVO target %d!" % new_target_index)
                        players_data[player_index].has_swapped_this_round = true; performed_action = true
                    # CONTROLLO RE SUL NUOVO TARGET (Player C)
                    elif new_target_card.rank_name == "K":
                        print("!!! KUKU (Dopo Salta)!!! Player %d ha il Re! Scambio fallito." % new_target_index)
                        _show_effect_label("KUKU!", 1.5)
                        players_data[player_index].has_swapped_this_round = true; performed_action = true
                    else:
                        # Esegui lo scambio A <-> C
                        print("Player %d scambia con NUOVO target %d (dopo Salta)" % [player_index, new_target_index])
                        players_data[player_index].card_data[0] = new_target_card        # A prende carta C
                        players_data[new_target_index].card_data[0] = my_card            # C prende carta A
                        _update_player_card_visuals(player_index); _update_player_card_visuals(new_target_index)
                        players_data[player_index].has_swapped_this_round = true; performed_action = true
            # Se nessun caso speciale, esegui lo scambio normale A <-> B
            else:
                print("Player %d scambia con %d" % [player_index, target_player_index])
                players_data[player_index].card_data[0] = target_card
                players_data[target_player_index].card_data[0] = my_card
                _update_player_card_visuals(player_index); _update_player_card_visuals(target_player_index)
                players_data[player_index].has_swapped_this_round = true; performed_action = true

    # --- Logica per azione HOLD ---
    elif action == "hold":
        print("Player %d tiene la carta." % player_index)
        players_data[player_index].has_swapped_this_round = true
        performed_action = true

    # --- Azioni Comuni se un'azione valida è stata eseguita ---
    if performed_action:
        players_data[player_index].has_swapped_this_round = true # Assicura sia settato
        # Aggiorna i bottoni solo se è il giocatore umano
        if player_index == 0 and not players_data[player_index].is_cpu:
            _update_player_action_buttons()
            
        call_deferred("_advance_turn") # Avanza al prossimo turno


func _dealer_action(action: String):
    # Validazione iniziale mazziere (nodo e stato)
    var dealer_node = player_nodes[dealer_index] if dealer_index >= 0 and dealer_index < player_nodes.size() else null
    if not is_instance_valid(dealer_node) or dealer_node.is_out:
        printerr("Azione mazziere annullata: Indice %d non valido o fuori." % dealer_index)
        call_deferred("_end_round")
        return

    var dealer_card: CardData = _get_valid_carddata_from_player(dealer_index, "_da get")
    if dealer_card == null:
        printerr("ERRORE CRITICO (_dealer_action): Mazziere %d non ha dati carta validi!" % dealer_index)
        action = "pass" # Forza 'pass'

    # Se l'azione è scambiare col mazzo...
    if action == "swap_deck":
        # --- CONTROLLO RE MAZZIERE ---
        if dealer_card != null and dealer_card.rank_name == "K":
            print("Mazziere (%d) ha il Re (K)! Non può scambiare col mazzo. Azione forzata a 'pass'." % dealer_index)
            action = "pass"
        else:
            # Prosegui solo se il mazziere non ha il Re
            if DeckSetupScene == null or not DeckSetupScene.has_method("cards_remaining") or DeckSetupScene.cards_remaining() <= 0:
                print("Mazzo vuoto o non accessibile. Mazziere (%d) passa." % dealer_index)
                action = "pass"
            else:
                # --- SCAMBIO EFFETTIVO COL MAZZO ---
                # Rimuovi la carta vecchia (già recuperata in dealer_card)
                # Assicurati che card_data non sia vuoto prima di pop_front
                if not players_data[dealer_index].card_data.is_empty():
                    players_data[dealer_index].card_data.pop_front()
                else:
                    printerr("ERRORE _dealer_action: card_data del mazziere %d è vuoto prima dello scambio!" % dealer_index)
                    action = "pass" # Non può scambiare se non ha carta da dare
                    # Riassegna dealer_card a null per sicurezza
                    dealer_card = null
                    
                # Se l'azione non è stata forzata a 'pass' per mancanza di carta iniziale
                if action == "swap_deck":
                    var new_card: CardData = DeckSetupScene.draw_card()
                    if new_card == null:
                        printerr("ERRORE: Mazzo finito durante lo scambio del mazziere!")
                        if dealer_card != null: players_data[dealer_index].card_data.append(dealer_card) # Rimetti vecchia
                        action = "pass"
                    elif not new_card is CardData:
                        printerr("ERRORE: Mazzo ha restituito un tipo non valido!")
                        if dealer_card != null: players_data[dealer_index].card_data.append(dealer_card) # Rimetti vecchia
                        action = "pass"
                    else:
                        # Scambio riuscito
                        print("Mazziere (%d) scambia col mazzo. Scarta %s, Pesca %s." % [dealer_index, get_card_name(dealer_card), get_card_name(new_card)])
                        players_data[dealer_index].card_data.append(new_card) # Aggiungi nuova
                        _update_player_card_visuals(dealer_index)
                        if DeckSetupScene.has_method("discard_card") and dealer_card != null:
                            DeckSetupScene.discard_card(dealer_card) # Scarta vecchia
                        # Azione swap_deck completata

    # Se l'azione (originale o forzata) è "pass"
    if action == "pass":
        print("Mazziere (%d) non scambia (passa)." % dealer_index)

    # Azioni finali comuni
    _update_deck_visual()
    _update_player_action_buttons()
    if get_tree(): await get_tree().create_timer(0.5).timeout
    call_deferred("_end_round")

func _make_cpu_dealer_turn():
    # Controlli validità stato e nodo CPU mazziere
    var cpu_dealer_node = player_nodes[dealer_index] if dealer_index >= 0 and dealer_index < player_nodes.size() else null
    if current_state != GameState.DEALER_SWAP or \
        current_player_index != dealer_index or \
        not is_instance_valid(cpu_dealer_node) or \
        cpu_dealer_node.is_out or \
        not players_data[dealer_index].is_cpu:
            return

    var cpu_dealer_index = dealer_index # Solo per leggibilità
    print("CPU Mazziere (%d) pensa..." % cpu_dealer_index)
    if get_tree(): await get_tree().create_timer(randf_range(1.5, 3.0)).timeout

    var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_dealer_index, "_mcdt")
    if card_to_evaluate == null:
        printerr("ERRORE (_make_cpu_dealer_turn): CPU Mazziere %d non ha dati carta!" % cpu_dealer_index)
        _dealer_action("pass")
        return

    var my_card_value = get_card_value(card_to_evaluate)
    var deck_available = (DeckSetupScene != null and DeckSetupScene.has_method("cards_remaining") and DeckSetupScene.cards_remaining() > 0)
    var should_swap_deck = false

    # --- CONTROLLO RE CPU MAZZIERE ---
    if card_to_evaluate.rank_name == "K":
        print("CPU Mazziere (%d) ha il Re (K). Non scambia col mazzo." % cpu_dealer_index)
        should_swap_deck = false
    elif not deck_available:
        print("CPU Mazziere (%d) non può scambiare (mazzo vuoto/invalido)." % cpu_dealer_index)
        should_swap_deck = false
    # Logica di scambio (se carta <= 4 e mazzo disponibile)
    elif my_card_value <= 4:
        print("CPU Mazziere (%d) ha carta bassa (%d) e mazzo disponibile. Scambia col mazzo." % [cpu_dealer_index, my_card_value])
        should_swap_deck = true
    else:
        print("CPU Mazziere (%d) ha carta alta (%d) o mazzo non disponibile. Passa." % [cpu_dealer_index, my_card_value])
        should_swap_deck = false

    # Esegui l'azione decisa
    if should_swap_deck: _dealer_action("swap_deck")
    else: _dealer_action("pass")


func _make_cpu_turn():
    # Controlli validità stato e nodo CPU corrente
    var cpu_node = player_nodes[current_player_index] if current_player_index >= 0 and current_player_index < player_nodes.size() else null
    if current_state != GameState.PLAYER_TURN or \
        not is_instance_valid(cpu_node) or \
        cpu_node.is_out or \
        not players_data[current_player_index].is_cpu:
            return

    var cpu_player_index = current_player_index # Solo per leggibilità
    print("CPU (%d) pensa..." % cpu_player_index)
    if get_tree(): await get_tree().create_timer(randf_range(1.5, 3.0)).timeout

    var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_player_index, "_mct")
    if card_to_evaluate == null:
        printerr("ERRORE (_make_cpu_turn): CPU %d non ha dati carta!" % cpu_player_index)
        _player_action(cpu_player_index, "hold") # Passa per sicurezza
        return

    var my_card_value = get_card_value(card_to_evaluate)
    # Scambia a SINISTRA (come da commento originale)
    var target_player_index = get_player_to_left(cpu_player_index)
    var target_node = player_nodes[target_player_index] if target_player_index != -1 else null

    var should_swap = false
    # --- CONTROLLO RE CPU ---
    if card_to_evaluate.rank_name == "K":
        print("CPU (%d) ha il Re (K). Non scambia." % cpu_player_index)
        should_swap = false
    elif not is_instance_valid(target_node) or target_node.is_out: # Usa validità nodo target
        print("CPU (%d) non ha un target valido a sinistra. Passa." % cpu_player_index)
        should_swap = false
    # Logica di scambio (se carta <= 5)
    elif my_card_value <= 5:
        print("CPU (%d) ha carta bassa (%d). Tenta lo scambio con P%d." % [cpu_player_index, my_card_value, target_player_index])
        should_swap = true
    else:
        print("CPU (%d) ha carta alta (%d). Passa." % [cpu_player_index, my_card_value])
        should_swap = false

    # Esegui l'azione decisa
    if should_swap: _player_action(cpu_player_index, "swap", target_player_index)
    else: _player_action(cpu_player_index, "hold")
        

# --- Fine Round e Punteggio ---
# (Funzioni _end_round, reveal_all_cards, determine_loser_and_update_lives...)
# Assicurati che usino lo stato 'is_out' corretto (da player_node o players_data sincronizzato)
# ... (INCOLLA QUI LE TUE FUNZIONI _end_round, reveal_all_cards, determine_loser_and_update_lives) ...

func _end_round():
    if current_state == GameState.GAME_OVER: return
    
    _update_player_action_buttons() # Disabilita bottoni
    current_state = GameState.REVEALING
    print("\n--- Fine Round ---"); print("Rivelazione...")
    
    reveal_all_cards()
    if get_tree(): await get_tree().create_timer(3.0).timeout # Pausa per vedere carte
    
    print("Determinazione perdente...")
    determine_loser_and_update_lives() # Chiama la funzione che ora usa lose_life()
    
    # Conta giocatori attivi dopo l'eventuale perdita di vite
    var active_players_count = 0
    for node in player_nodes:
        if is_instance_valid(node) and not node.is_out:
            active_players_count += 1
            
    # Controlla fine partita
    if active_players_count <= 1:
        _handle_game_over(active_players_count)
        return # Non procedere oltre se la partita è finita
        
    _update_last_hand_display() # Mostra le carte giocate nel round
    if get_tree(): await get_tree().create_timer(2.0).timeout # Pausa per vedere ultima mano
    
    # Passa il mazziere
    var old_dealer = dealer_index
    # Usa la versione che legge 'is_out' dai nodi player per coerenza
    dealer_index = get_next_active_player(dealer_index, false) 
    
    if dealer_index == -1:
        printerr("ERRORE _end_round: Impossibile trovare nuovo mazziere attivo!");
        _handle_game_over(active_players_count); # Gestisci come fine partita anomala
        return
        
    print("Mazziere passa da %d a %d." % [old_dealer, dealer_index])
    call_deferred("_start_round") # Avvia il prossimo round


func reveal_all_cards():
    # Itera sui dati per sapere quali carte visuali mostrare
    for i in range(players_data.size()):
        var p_node = player_nodes[i] if i < player_nodes.size() else null
        # Mostra solo se il nodo è valido e il giocatore NON è fuori
        if is_instance_valid(p_node) and not p_node.is_out:
            if not players_data[i].visual_cards.is_empty():
                var card_visual = players_data[i].visual_cards[0] as CardVisual
                if is_instance_valid(card_visual):
                    card_visual.show_front()


func determine_loser_and_update_lives():
    var lowest_card_value = 100 # Valore più alto possibile
    var losers_indices: Array[int] = []
    
    print("--- Valutazione Carte Fine Round ---")
    # Prima leggi e stampa tutte le carte dei giocatori attivi
    for i in range(player_nodes.size()):
        var p_node = player_nodes[i]
        if is_instance_valid(p_node) and not p_node.is_out:
            # Leggi la carta da players_data (dovrebbe essere aggiornata correttamente)
            var card_to_evaluate: CardData = _get_valid_carddata_from_player(i, "det_loser_log")
            players_data[i].last_card = card_to_evaluate # Salva per UI ultima mano
            
            if card_to_evaluate:
                var card_value = get_card_value(card_to_evaluate)
                var cpu_tag = "CPU" if players_data[i].is_cpu else "Umano"
                print("  Player %d (%s): %s (Val: %d)" % [i, cpu_tag, get_card_name(card_to_evaluate), card_value])
                
                # Calcola il perdente mentre cicli (escludendo Re subito)
                if card_to_evaluate.rank_name != "K":
                    if card_value < lowest_card_value:
                        lowest_card_value = card_value
                        losers_indices.clear()
                        losers_indices.append(i)
                    elif card_value == lowest_card_value:
                        losers_indices.append(i)
            else:
                printerr("  ERRORE: Impossibile leggere carta per Player %d!" % i)
                players_data[i].last_card = null # Assicura sia null se errore
        else:
            # Se giocatore è fuori, assicurati che last_card sia null
            if i < players_data.size(): players_data[i].last_card = null
            
    print("--- Calcolo Perdente ---")
    # Stampa chi è salvo per via del Re (informativo)
    for i in range(player_nodes.size()):
        var p_node = player_nodes[i]
        if is_instance_valid(p_node) and not p_node.is_out:
            var card_to_evaluate: CardData = players_data[i].last_card
            if card_to_evaluate != null and card_to_evaluate.rank_name == "K":
                print("  -> Player %d salvo (Re)." % i)
                
    # Applica la perdita di vita ai perdenti trovati
    if losers_indices.is_empty():
        print("Nessun perdente in questo round.")
    else:
        print("Perdente/i (Val %d): %s" % [lowest_card_value, str(losers_indices)])
        for loser_index in losers_indices:
            if loser_index >= 0: # Sicurezza extra sull'indice
                lose_life(loser_index) # Chiama la funzione che ora delega a Player.gd

func lose_life(player_index: int):
    # Controlla se l'indice è valido e se abbiamo un riferimento valido al nodo Player
    if player_index >= 0 and player_index < player_nodes.size():
        var player_node = player_nodes[player_index] # Ottieni il nodo Player dall'array
        if is_instance_valid(player_node) and player_node.has_method("lose_finger"):
            print("GameManager dice a Player ", player_index, " di perdere un dito.")
            player_node.lose_finger() # Chiama la funzione sul nodo Player

            # AGGIORNAMENTO OPZIONALE: Sincronizza is_out in players_data se necessario
            # (Questa parte potrebbe essere gestita meglio con segnali da Player a GM)
            if player_node.is_out: # Leggiamo lo stato is_out aggiornato dal nodo Player
                if player_index < players_data.size(): # Sicurezza
                    # Solo se usi ancora players_data[i].is_out in altre parti del codice
                    if not players_data[player_index].is_out: 
                        players_data[player_index].is_out = true
                        print(">>> GameManager ha registrato Player ", player_index, " come eliminato (in players_data). <<<")
        else:
            printerr("ERRORE in lose_life: Nodo Player ", player_index, " non valido o non ha il metodo lose_finger().")
    else:
        printerr("ERRORE in lose_life: Indice giocatore non valido: ", player_index)

# --- Funzioni Ausiliarie (Helper) ---
# (Funzioni get_player_to_left, get_player_to_right, get_next_active_player...)
# Rivedi queste per usare 'is_out' dai nodi player per maggiore coerenza
# ... (INCOLLA QUI LE TUE FUNZIONI get_..., _get_valid_carddata, get_card_value, ecc.) ...

# Riveduta per usare lo stato is_out dai nodi Player
func get_player_to_left(player_index: int) -> int:
    var size = player_nodes.size()
    if size <= 1: return -1

    var current = player_index
    for _i in range(size - 1): # Max size-1 controlli
        current = (current - 1 + size) % size
        var candidate_node = player_nodes[current] if current < size else null
        if is_instance_valid(candidate_node) and not candidate_node.is_out:
            return current # Trovato giocatore attivo a sinistra
    return -1 # Nessun altro giocatore attivo trovato

# Riveduta per usare lo stato is_out dai nodi Player e debug pulito
func get_player_to_right(player_index: int) -> int:
    # print("--- DEBUG: get_player_to_right chiamato per index: %d ---" % player_index) # Rimuovi/commenta se troppo verboso
    var current = player_index; var size = player_nodes.size()
    if size <= 1: return -1
    
    for _i in range(size - 1): # Max size-1 controlli
        current = (current + 1) % size
        var candidate_node = player_nodes[current] if current < size else null
        # print("  -> DEBUG: Controllo indice %d..." % current) # Rimuovi/commenta se troppo verboso
        if is_instance_valid(candidate_node):
            # print("     -> DEBUG: Nodo valido. is_out = %s" % candidate_node.is_out) # Rimuovi/commenta se troppo verboso
            if not candidate_node.is_out:
                # print("     -> DEBUG: Trovato player attivo %d, ritorno." % current) # Rimuovi/commenta se troppo verboso
                return current
        # else: print("     -> DEBUG: Nodo non valido all'indice %d" % current) # Rimuovi/commenta se troppo verboso
        
        # Sicurezza anti-loop (anche se range(size-1) dovrebbe bastare)
        # if current == player_index: break 

    # print("--- DEBUG: get_player_to_right finito senza trovare attivi, ritorno -1 ---") # Rimuovi/commenta se troppo verboso
    return -1

# Riveduta per usare lo stato is_out dai nodi Player
func get_next_active_player(start_index: int, clockwise: bool = false) -> int:
    var size = player_nodes.size()
    if start_index < 0 or start_index >= size or size <= 1: return -1
    
    var current = start_index
    for _i in range(size - 1): # Max size-1 controlli
        if clockwise: current = (current - 1 + size) % size
        else: current = (current + 1) % size
        
        var candidate_node = player_nodes[current] if current < size else null
        if is_instance_valid(candidate_node) and not candidate_node.is_out:
            return current # Trovato il prossimo attivo
            
    return -1 # Non trovato nessun altro attivo

# Questa funzione helper è OK perché legge da players_data che contiene i dati della carta
func _get_valid_carddata_from_player(player_index: int, context: String = "?") -> CardData:
    if player_index < 0 or player_index >= players_data.size():
        printerr("ERRORE (%s): Indice player %d fuori range per players_data (%d)" % [context, player_index, players_data.size()])
        return null
    if not players_data[player_index].has("card_data"):
        printerr("ERRORE (%s): Player %d non ha 'card_data' in players_data" % [context, player_index])
        return null
    if players_data[player_index].card_data.is_empty():
        # printerr("ATTENZIONE (%s): card_data per Player %d è vuoto." % [context, player_index]) # Potrebbe essere normale tra i round
        return null
        
    # Gestisce sia CardData direttamente che Array[CardData] per errore precedente?
    var card_element = players_data[player_index].card_data[0]
    if card_element is CardData:
        return card_element
    # Fallback per struttura errata precedente (Array in Array) - Rimuovere se non serve più
    elif card_element is Array and not card_element.is_empty() and card_element[0] is CardData:
        printerr("ATTENZIONE (%s): Corretta struttura errata Array[Array[CardData]] per Player %d." % [context, player_index])
        players_data[player_index].card_data[0] = card_element[0] # Corregge in-place
        return card_element[0]
    else:
        printerr("ERRORE (%s): Tipo non valido (%s) in card_data[0] per Player %d!" % [context, typeof(card_element), player_index])
        return null


# Funzioni get_card_value, get_card_name sembrano OK
func get_card_value(card: CardData) -> int:
    if card == null:
        printerr("get_card_value chiamata con card null!")
        return 100 # Valore molto alto per indicare errore/carta non valida

    # Usa match sul nome del rango della carta (che è una stringa)
    match card.rank_name: 
        "A": 
            return 1
        "2": 
            return 2
        "3": 
            return 3
        "4": 
            return 4
        "5": 
            return 5
        "6": 
            return 6
        "7": 
            return 7
        "J": # Fante
            return 8 
        "Q": # Cavallo / Regina
            return 9  
        "K": # Re
            return 10 
        _: # Caso default per sicurezza, se il rank non è uno di quelli attesi
            printerr("Rank non riconosciuto in get_card_value: '", card.rank_name, "'")
            return 0 # Restituisce 0 per rank sconosciuto (o un altro valore di errore)

        _:
            printerr("Rank non riconosciuto in get_card_value: ", card.rank_name)
            return 0
func get_card_name(card: CardData) -> String:
    if card: return card.rank_name + " " + card.suit
    return "Carta Invalida"

# Funzione _update_player_card_visuals sembra OK (legge dati da players_data)
func _update_player_card_visuals(player_index: int):
    # Controllo indice per players_data
    if player_index < 0 or player_index >= players_data.size(): return
    
    var player_data = players_data[player_index]
    # Controllo indice per player_nodes e validità nodo
    var player_node = player_nodes[player_index] if player_index < player_nodes.size() else null
    if not is_instance_valid(player_node) or player_node.is_out:
        # Nascondi carte se il giocatore è fuori o nodo non valido?
        if not player_data.visual_cards.is_empty():
            var existing_visual = player_data.visual_cards[0] as CardVisual
            if is_instance_valid(existing_visual): existing_visual.hide()
        return

    var card_to_display: CardData = _get_valid_carddata_from_player(player_index, "_update_vis")
    var card_visual = player_data.visual_cards[0] as CardVisual if not player_data.visual_cards.is_empty() else null
    
    if not is_instance_valid(card_visual):
        # printerr("_update_player_card_visuals: Nessuna CardVisual per Player %d" % player_index) # Potrebbe essere normale
        return
        
    if card_to_display == null:
        card_visual.hide() # Nascondi se non ci sono dati carta
        return
        
    card_visual.card_data = card_to_display # Aggiorna dati interni della visuale
    card_visual.visible = true # Assicura sia visibile (potrebbe essere stata nascosta)
    
    # Logica per mostrare fronte/retro
    if player_index == 0 and not player_data.is_cpu:
        card_visual.show_front()
    else:
        card_visual.show_back()

# Funzioni _update_deck_visual, _update_player_action_buttons, _update_last_hand_display sembrano OK
# ... (INCOLLA QUI LE TUE FUNZIONI _update_deck_visual, _update_player_action_buttons, _update_last_hand_display) ...
func _update_deck_visual():
    if deck_visual_instances.is_empty(): return

    var cards_left = 0
    if DeckSetupScene != null and DeckSetupScene.has_method("cards_remaining"):
        cards_left = DeckSetupScene.cards_remaining()
    else:
        printerr("ERRORE in _update_deck_visual: Impossibile chiamare cards_remaining()!")
        for instance in deck_visual_instances:
            if is_instance_valid(instance): instance.visible = false
        return

    var show_stack = (cards_left > 0)
    for instance in deck_visual_instances:
        if is_instance_valid(instance): instance.visible = show_stack

func _update_player_action_buttons():
    var normal_swap_valid = is_instance_valid(swap_button)
    var normal_pass_valid = is_instance_valid(pass_button)
    var dealer_swap_valid = is_instance_valid(swap_to_deck_button)
    var dealer_pass_valid = is_instance_valid(pass_as_dealer_button)

    var enable_player_buttons = false
    var enable_dealer_buttons = false

    # Controlli più robusti usando player_nodes
    var current_p_node = player_nodes[current_player_index] if current_player_index >= 0 and current_player_index < player_nodes.size() else null
    if is_instance_valid(current_p_node) and not current_p_node.is_out:
        # Player 0 (Umano) e nel suo turno normale
        if current_state == GameState.PLAYER_TURN and \
            current_player_index == 0 and \
            not players_data[0].is_cpu and \
            not players_data[0].has_swapped_this_round:
                enable_player_buttons = true

        # Player 0 (Umano) e nella fase mazziere
        if current_state == GameState.DEALER_SWAP and \
            current_player_index == 0 and \
            not players_data[0].is_cpu:
                enable_dealer_buttons = true
            
    # Aggiorna visibilità/disabilitazione
    if normal_swap_valid: swap_button.visible = enable_player_buttons; swap_button.disabled = not enable_player_buttons
    if normal_pass_valid: pass_button.visible = enable_player_buttons; pass_button.disabled = not enable_player_buttons
    if dealer_swap_valid: swap_to_deck_button.visible = enable_dealer_buttons; swap_to_deck_button.disabled = not enable_dealer_buttons
    if dealer_pass_valid: pass_as_dealer_button.visible = enable_dealer_buttons; pass_as_dealer_button.disabled = not enable_dealer_buttons


func _update_last_hand_display():
    if last_hand_textures.size() == 0: return
    # Assumiamo che last_hand_textures e labels abbiano dimensione num_players (verificato in _ready)
    if last_hand_textures.size() != num_players or last_hand_labels.size() != num_players:
        printerr("ERRORE _update_last_hand: Disallineamento dimensioni array UI Ultima Mano!")
        return # Non possiamo procedere

    for i in range(num_players):
        var label = last_hand_labels[i] if is_instance_valid(last_hand_labels[i]) else null
        var texture_rect = last_hand_textures[i] if is_instance_valid(last_hand_textures[i]) else null
        if not texture_rect: continue

        # Ottieni la carta dall'array players_data (che viene aggiornato in determine_loser)
        var last_card: CardData = players_data[i].last_card if i < players_data.size() and players_data[i].has("last_card") else null

        # Aggiorna nome
        if label: label.text = "P%d:" % i

        # Aggiorna immagine carta
        if last_card != null and is_instance_valid(last_card.texture_front):
            texture_rect.texture = last_card.texture_front
            texture_rect.visible = true
            # if label: label.text += " " + get_card_name(last_card) # Opzionale: mostra nome carta
        else:
            texture_rect.texture = null
            texture_rect.visible = false

# Funzioni Notifiche (_show_cucu_king_notification, _show_effect_label, _on_notification_timer_timeout) sembrano OK
# ... (INCOLLA QUI LE TUE FUNZIONI _show_..., _on_notification_timer_timeout) ...
func _show_cucu_king_notification(king_holder_index: int):
    if cucu_notification_label == null or notification_timer == null:
        printerr("ERRORE ShowNotify: CucuNotificationLabel o NotificationTimer non trovati/validi.")
        return
    var message = "CUCÙ!\nGiocatore %d è protetto dal Re!" % king_holder_index
    cucu_notification_label.text = message
    cucu_notification_label.visible = true
    if cucu_notification_label is Control:
        var viewport_rect = get_viewport().get_visible_rect()
        cucu_notification_label.position = viewport_rect.position + viewport_rect.size / 2.0 - cucu_notification_label.size / 2.0
        # print("DEBUG: Posizionata CucuNotificationLabel a ", cucu_notification_label.position) # Debug opzionale
    var display_duration = 2.5
    notification_timer.wait_time = display_duration
    notification_timer.start()
    # print("DEBUG: Mostrata notifica Cucù su CucuNotificationLabel.") # Debug opzionale

func _show_effect_label(text_to_show: String, duration: float = 1.5):
    # print(">>> DEBUG: Chiamata _show_effect_label con testo: ", text_to_show, " per ", duration, " sec.") # Debug opzionale
    if not is_instance_valid(cucu_notification_label):
        printerr("EffectLabel (cucu_notification_label) non assegnato o non valido!")
        print(">>> EFFETTO TESTUALE: %s <<<" % text_to_show) # Fallback
        return
    cucu_notification_label.text = text_to_show
    cucu_notification_label.visible = true
    # print(">>> DEBUG: cucu_notification_label reso visibile.") # Debug opzionale
    if notification_timer:
        notification_timer.stop()
        notification_timer.wait_time = duration
        notification_timer.start()
        # print(">>> DEBUG: notification_timer avviato per ", duration, " sec.") # Debug opzionale
    else:
        printerr("Impossibile avviare notification_timer!")
    
func _on_notification_timer_timeout():
    if is_instance_valid(cucu_notification_label):
        cucu_notification_label.visible = false
        # print(">>> DEBUG: cucu_notification_label nascosta dal timer.") # Debug opzionale
    # else: # Non serve loggare se non è più valida
        # print(">>> DEBUG: Tentativo di nascondere cucu_notification_label, ma non è più valida.") 


# Funzione Handler per segnale da Player.gd (aggiunta correttamente dall'utente)
func _on_player_fingers_updated(p_id: int, p_fingers: int):
    # print("HANDLER: Ricevuto fingers_updated da Player ", p_id, ". Dita rimaste: ", p_fingers) # Debug opzionale
    if p_id >= 0 and p_id < player_lives_labels.size():
        var label = player_lives_labels[p_id]
        if is_instance_valid(label):
            label.text = "Vite P%d: %d" % [p_id, p_fingers]
            # Aggiorna visibilità qui è opzionale, potrebbe gestirla _reset_game o _start_round
            # In alternativa, leggi lo stato 'is_out' dal nodo player per decidere
            # var p_node = player_nodes[p_id] if p_id < player_nodes.size() else null
            # if is_instance_valid(p_node): label.visible = not p_node.is_out
        else:
            printerr("HANDLER: Label vite per Player ", p_id, " non valida!")
    else:
        printerr("HANDLER: ID Player ", p_id, " non valido per l'array delle label vite.")

#endregion
