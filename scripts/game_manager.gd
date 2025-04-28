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
@export var player_info_labels: Array[Label]		# Array per Label Nome e vite giocatori (Popolare nell'editor, Size 10)
@export var last_hand_labels: Array[Label]			# Opzionale: Array per Label nomi ultima mano (Popolare nell'editor, Size 10)
@export var last_hand_textures: Array[TextureRect]	# Array per TextureRect ultima mano (Popolare nell'editor, Size 10)
@export var deck_position_marker: Marker3D			# Marker per posizione mazzo centrale
@export var player_nodes: Array[Node]				# Array per contenere i nodi Player0..9 (Popolare nell'editor, Size 10)
@export var all_class_datas: Array[CharacterClassData] # <-- NUOVO: Array per contenere TUTTE le risorse *_class.tres (Popolare nell'editor, Size 10)
@export var player0_sanity_label: Label # Label per la Sanità di Player 0

@onready var cucu_notification_label: Label = %EffectLabelKUKU
@onready var notification_timer: Timer = %Timer
# --- Fine Export ---

# --- Variabili Interne ---
var player_positions_node: Node3D = null
var num_players: int = 10 
var dealer_index: int = 0
var current_player_index: int = 0
var players_data: Array[Dictionary] = [] # Conterrà dati NON di stato (id, marker, is_cpu, card_data, ecc.)
var active_card_instances: Array[CardVisual] = []
var last_clicked_player_index: int = -1 
const DECK_STACK_COUNT = 5
var deck_visual_instances: Array[Node3D] = []

enum GameState { SETUP, DEALING, PLAYER_TURN, DEALER_SWAP, REVEALING, END_ROUND, GAME_OVER }
var current_state: GameState = GameState.SETUP

# Assicurati che DeckSetupScene sia un Autoload o accessibile
# var DeckSetupScene # = Autoload o get_node(...)

func _ready():
    # Controlli essenziali all'avvio
    if card_scene == null: printerr("!!! ERRORE _ready: 'Card Scene' non assegnata!"); get_tree().quit(); return
    if player_nodes.size() != num_players: printerr("!!! ATTENZIONE _ready: 'player_nodes' non ha la dimensione corretta (%d vs %d)!" % [player_nodes.size(), num_players])
    if all_class_datas.size() != num_players: printerr("!!! ATTENZIONE _ready: 'all_class_datas' non ha la dimensione corretta (%d vs %d)!" % [all_class_datas.size(), num_players])
    if player_info_labels.size() != num_players and player_info_labels.size() > 0: printerr("!!! ATTENZIONE _ready: Numero Label vite (%d) non corrisponde a num_players (%d)!" % [player_info_labels.size(), num_players])
    if player_info_labels.size() != num_players and player_info_labels.size() > 0: printerr("!!! ATTENZIONE _ready: Numero Label classi (%d) non corrisponde a num_players (%d)!" % [player_info_labels.size(), num_players])

    # Controlli bottoni
    if swap_button == null or pass_button == null or swap_to_deck_button == null or pass_as_dealer_button == null:
        printerr("!!! ATTENZIONE _ready: Uno o più bottoni azione non assegnati!")

    # Setup Timer Notifiche
    if cucu_notification_label == null: printerr("ATTENZIONE _ready: Nodo CucuNotificationLabel non trovato!")
    if notification_timer == null: printerr("ATTENZIONE _ready: Nodo NotificationTimer non trovato!")
    else:
        if not notification_timer.is_connected("timeout", Callable(self, "_on_notification_timer_timeout")):
            notification_timer.connect("timeout", Callable(self, "_on_notification_timer_timeout"))

    # Recupero PlayerPositions
    player_positions_node = get_node_or_null("../PlayerPositions") 
    if player_positions_node == null: printerr("!!! ERRORE _ready: Impossibile trovare PlayerPositions!"); get_tree().quit(); return

    # Inizializza generatore casuale
    randomize()

    print("+++ GameManager pronto +++")

    # Crea Visuale Mazzo
    _create_deck_visual_stack() 

    # Avvio gioco differito
    call_deferred("start_game", num_players)
    
    
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    print("DEBUG: Mouse mode forzato a VISIBLE in GameManager._ready()")

func _create_deck_visual_stack():
    for instance in deck_visual_instances:
        if is_instance_valid(instance): instance.queue_free()
    deck_visual_instances.clear()

    if is_instance_valid(deck_position_marker) and card_scene != null:
        print("Creazione pila mazzo (%d istanze)..." % DECK_STACK_COUNT)
        for i in range(DECK_STACK_COUNT):
            var instance = card_scene.instantiate()
            if instance is CardVisual:
                var visual = instance as CardVisual
                add_child(visual)
                visual.global_position = deck_position_marker.global_position
                visual.global_position.y += 0.01 + i * 0.002
                # Assicurati che questa rotazione sia corretta per il tuo modello di carta
                visual.rotation_degrees = Vector3(90, 90, 0) # Esempio
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

    # Resetta lo stato del gioco (inclusa assegnazione classi)
    _reset_game()

    if players_data.size() != num_players:
        printerr("Reset fallito o incompleto. Dimensione players_data (%d) != num_players (%d)." % [players_data.size(), num_players])
        return

    # Assegna Mazziere Casuale
    if num_players > 0:
        dealer_index = randi() % num_players
    else:
        dealer_index = 0
        printerr("ATTENZIONE start_game: num_players è 0!")
    print("Inizio partita. Mazziere Casuale: Player %d" % dealer_index)

    # Avvia il primo round
    call_deferred("_start_round")


func _reset_game():
    print("Resetting game...")

    # 1. Pulisci istanze carte giocatori
    for card_instance in active_card_instances:
        if is_instance_valid(card_instance): card_instance.queue_free()
    active_card_instances.clear()

    # 2. Pulisci dati giocatori precedenti
    players_data.clear()

    # 3. Pulisci visuale mazzo
    for instance in deck_visual_instances:
        if is_instance_valid(instance): instance.queue_free()
    deck_visual_instances.clear()

    # 4. Inizializza dati base (NON di stato) in players_data
    print("Inizializzazione dati base per %d giocatori..." % num_players)
    if not is_instance_valid(player_positions_node):
        printerr("ERRORE CRITICO _reset_game: PlayerPositions non valido!"); return
    var markers = player_positions_node.get_children()
    if markers.size() < num_players:
        printerr("ERRORE CRITICO _reset_game: Non ci sono abbastanza Marker3D (%d) per %d giocatori!" % [markers.size(), num_players])
        return

    for i in range(num_players):
        var player_marker = markers[i] if i < markers.size() else null
        if not player_marker is Marker3D:
            printerr("ATTENZIONE _reset_game: Elemento %d in PlayerPositions non è Marker3D!" % i)
            player_marker = null

        # Dizionario SENZA stato dinamico (vite, sanità, is_out verranno da Player.gd)
        var new_player_data = {
            "id": i,
            "marker": player_marker,
            "is_out": false, # Stato iniziale (verrà poi letto da Player.gd)
            "is_cpu": (i != 0),
            "card_data": [],
            "visual_cards": [],
            "has_swapped_this_round": false,
            "last_card": null
        }
        players_data.append(new_player_data)

    if players_data.size() != num_players:
        printerr("ERRORE INASPETTATO _reset_game: Dimensione players_data (%d) != num_players (%d)!" % [players_data.size(), num_players])
        return
    print("Dati base giocatori inizializzati. Numero elementi in players_data: %d" % players_data.size())

    # 5. Assegna Classi Casuali, ID e Connetti Segnali ai Nodi Player
    print("Assegnazione classi casuali e connessione segnali...")
    if all_class_datas.size() < num_players:
        printerr("ERRORE _reset_game: Non ci sono abbastanza classi definite in 'all_class_datas' (%d) per %d giocatori!" % [all_class_datas.size(), num_players]); return
    elif player_nodes.size() != num_players:
        printerr("ERRORE _reset_game: Numero di nodi in 'player_nodes' (%d) non corrisponde a num_players (%d)!" % [player_nodes.size(), num_players]); return
    else:
        var available_classes = all_class_datas.duplicate()
        available_classes.shuffle()

        # Loop per assegnare classe e connettere segnali
        for i in range(num_players):
            var player_node = player_nodes[i]

            if available_classes.is_empty(): printerr("ERRORE _reset_game: Finite le classi disponibili!"); break
            var chosen_class = available_classes.pop_front()

            if not is_instance_valid(player_node) or not player_node.has_method("assign_class"):
                printerr("ERRORE _reset_game: Nodo Player %d non valido o manca assign_class()." % i); continue

            # Chiama assign_class sul nodo Player
            player_node.assign_class(chosen_class, i)

            # Connetti segnale per aggiornamento vite UI
            if player_node.has_signal("fingers_updated") and not player_node.is_connected("fingers_updated", Callable(self, "_on_player_fingers_updated")):
                var err_f = player_node.connect("fingers_updated", Callable(self, "_on_player_fingers_updated"))
                if err_f != OK: printerr("Errore connessione fingers_updated per Player ", i, ": Codice ", err_f)

            # --- AGGIUNTO QUI: Connetti segnale SANITÀ SOLO per Player 0 ---
            if i == 0: # Connetti solo per il giocatore umano (ID 0)
                if player_node.has_signal("sanity_updated") and not player_node.is_connected("sanity_updated", Callable(self, "_on_player0_sanity_updated")):
                    var err_s = player_node.connect("sanity_updated", Callable(self, "_on_player0_sanity_updated"))
                    if err_s != OK: printerr("Errore connessione sanity_updated per Player 0: Codice ", err_s)
            # --- FINE AGGIUNTO ---

            # TODO: Connetti altri segnali necessari qui (es. player_eliminated?)

        print("Classi assegnate casualmente e segnali connessi.") # Spostato fuori dal loop

    # --- Stampa Assegnazione Classi (Già presente nel tuo codice) ---
    print("\n--- ASSEGNAZIONE PERSONAGGI GIOCATORI ---")
    if player_nodes.size() == num_players:
        for i in range(num_players):
            var p_node = player_nodes[i]
            if is_instance_valid(p_node) and p_node.class_data != null:
                var nome_personaggio = p_node.class_data.character_name
                var etichetta_tipo = "(CPU)"
                if i < players_data.size() and not players_data[i].is_cpu:
                    etichetta_tipo = "(Umano)"
                elif i >= players_data.size():
                    etichetta_tipo = "(?)"
                print("  Player %d %s: %s" % [i, etichetta_tipo, nome_personaggio])
            else:
                print("  Player %d: (Errore - Dati classe non disponibili)" % i)
    else:
        print("  ERRORE: Impossibile stampare assegnazione - numero nodi player non corretto.")
    print("---------------------------------------")

# 6. Aggiorna UI iniziale COMBINATA (Nome + Vite)
    #    Usa l'array player_info_labels (o player_lives_labels se non rinominato)
    if player_info_labels.size() == player_nodes.size(): 
        print("Aggiornamento label INFO iniziale (Nome + Vite)...") 
        # Questo loop usa 'j' come indice
        for j in range(player_nodes.size()): 
            # Definiamo la variabile per questo loop come 'player_node' usando l'indice 'j'
            var player_node = player_nodes[j] 
            var info_label = player_info_labels[j] if j < player_info_labels.size() and is_instance_valid(player_info_labels[j]) else null 
            
            # Controlla la validità della label e del NODO di questo ciclo ('player_node')
            if info_label and is_instance_valid(player_node):
                var char_name = "Player %d" % j # Default
                var current_lives = -1
                var is_player_out = true 

                # Accedi ai dati e metodi usando 'player_node' (la variabile di QUESTO loop)
                if player_node.class_data != null: 
                    char_name = player_node.class_data.character_name # <-- CORRETTO
                    
                if player_node.has_method("get_fingers_remaining"): 
                    current_lives = player_node.get_fingers_remaining() # <-- CORRETTO
                    
                is_player_out = player_node.is_out # <-- CORRETTO

                # Formatta il testo combinato
                info_label.text = "%s: %d Vite" % [char_name, current_lives] 
                info_label.visible = not is_player_out # Imposta visibilità
                
            elif info_label:
                info_label.visible = false # Nascondi se nodo player non valido
                
    elif player_info_labels.size() > 0: # Usa il nome dell'array corretto qui
        printerr("ATTENZIONE _reset_game: Numero Label info (%d) non corrisponde ai nodi Player (%d)!" % [player_info_labels.size(), player_nodes.size()])
        
        
    # 7. Aggiorna UI iniziale Ultima Mano (era Blocco 8)
    if last_hand_textures.size() == players_data.size():
        print("Resetting UI ultima mano...")
        for k in range(last_hand_textures.size()):
            var texture_rect = last_hand_textures[k] if k < last_hand_textures.size() and is_instance_valid(last_hand_textures[k]) else null
            if texture_rect: texture_rect.visible = false
            var name_label = last_hand_labels[k] if k < last_hand_labels.size() and is_instance_valid(last_hand_labels[k]) else null
            if name_label: name_label.text = "P%d:" % k
    elif last_hand_textures.size() > 0:
        printerr("ATTENZIONE _reset_game: Numero TextureRect ultima mano (%d) non corrisponde ai giocatori (%d)!" % [last_hand_textures.size(), players_data.size()])

    # 8. Fine Reset (era Blocco 9)
    print("Reset game completato.")

# FINE DELLA FUNZIONE _reset_game

# --- Gestione Round ---

func _start_round():
    # Controlla giocatori attivi leggendo dai NODI PLAYER
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
        # Pulisci visual cards
        for card_visual in player_data.visual_cards:
            if is_instance_valid(card_visual):
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
    # Assumendo che DeckSetupScene sia un Autoload/Singleton valido
    if DeckSetupScene == null or not DeckSetupScene.has_method("reset_and_shuffle"): 
        printerr("ERRORE CRITICO _start_round: DeckSetupScene non valido!"); return
    DeckSetupScene.reset_and_shuffle()
    _deal_initial_cards()

    if current_state == GameState.GAME_OVER: return # Mazzo finito durante distribuzione

    # Trova il prossimo giocatore attivo dopo il mazziere
    current_player_index = get_next_active_player(dealer_index, false) # Anti-orario
    if current_player_index == -1:
        printerr("ERRORE _start_round: Nessun giocatore attivo trovato dopo il mazziere!");
        _handle_game_over(active_players_count); return

    current_state = GameState.PLAYER_TURN
    print("Carte distribuite. Tocca a player %d." % current_player_index)

    # Aggiorna UI e avvia turno CPU se necessario
    _update_player_action_buttons()
    _update_deck_visual()

    var current_p_node = player_nodes[current_player_index] if current_player_index < player_nodes.size() else null
    if is_instance_valid(current_p_node) and not current_p_node.is_out and players_data[current_player_index].is_cpu:
        call_deferred("_make_cpu_turn")


func _deal_initial_cards():
    print("Distribuzione...");
    var main_camera = get_viewport().get_camera_3d()
    if not is_instance_valid(main_camera):
        printerr("ERRORE _deal_initial_cards: Camera non trovata!"); current_state = GameState.GAME_OVER; return

    for i in range(player_nodes.size()):
        var p_node = player_nodes[i]

        if not is_instance_valid(p_node) or p_node.is_out:
            if i < players_data.size(): players_data[i].card_data.clear()
            continue

        if i >= players_data.size(): # Sicurezza extra
            printerr("ERRORE _deal_initial_cards: Indice %d fuori range per players_data" % i); continue
        var player_data = players_data[i]
        var player_marker: Marker3D = player_data.get("marker", null)
        if not is_instance_valid(player_marker):
            printerr("ATTENZIONE _deal_initial_cards: Marker non valido per Player %d" % i); continue

        var drawn_card_data: CardData = DeckSetupScene.draw_card()
        if drawn_card_data == null: printerr("ERRORE _deal_initial_cards: Mazzo finito!"); current_state = GameState.GAME_OVER; return
        if not drawn_card_data is CardData: printerr("ERRORE _deal_initial_cards: draw_card() tipo non valido!"); current_state = GameState.GAME_OVER; return
        player_data["card_data"] = [drawn_card_data]

        var card_instance = card_scene.instantiate() as CardVisual
        if not card_instance: continue

        card_instance.card_data = drawn_card_data
        add_child(card_instance) # Aggiungi come figlio del GameManager

        player_data["visual_cards"] = [card_instance]
        active_card_instances.append(card_instance)

        # --- POSIZIONAMENTO E ROTAZIONE---
        # Nota l'offset Y a 0.5 e la rotazione X dopo look_at
        var card_position = player_marker.global_transform.origin + Vector3(0,0.5, 0)
        card_instance.global_transform.origin = card_position
        card_instance.look_at(main_camera.global_transform.origin, Vector3.UP); card_instance.rotation.x = deg_to_rad(180)
        card_instance.look_at(main_camera.global_transform.origin, Vector3.UP); card_instance.rotation.y = deg_to_rad(180)
        # FINE POSIZIONAMENTO E ROTAZIONE

        if i == 0 and not player_data.is_cpu: # Giocatore umano
            card_instance.show_front()
            card_instance.set_physics_active(true)
        else: # CPU
            card_instance.show_back()
            card_instance.set_physics_active(false)

    print("Carte distribuite.")
    _update_deck_visual()


# --- Gestione Turni e Azioni ---

func _advance_turn():
    var next_player_candidate = -1
    var current_check = current_player_index

    for _i in range(player_nodes.size()): # Loop limitato a dimensione player_nodes
        current_check = (current_check + 1) % player_nodes.size() # Avanza ANTI-ORARIO
        var candidate_node = player_nodes[current_check] if current_check < player_nodes.size() else null

        # Condizioni: Nodo valido E non fuori E non è mazziere E non ha agito
        if is_instance_valid(candidate_node) and \
           not candidate_node.is_out and \
           current_check != dealer_index and \
           not players_data[current_check].has_swapped_this_round:

            next_player_candidate = current_check
            break # Trovato

        if current_check == current_player_index: # Giro completo
            print("DEBUG _advance_turn: Giro completo, nessun candidato trovato.")
            next_player_candidate = -1
            break

    if next_player_candidate != -1:
        current_player_index = next_player_candidate
        print("Avanzamento turno. Tocca a player %d." % current_player_index)
        current_state = GameState.PLAYER_TURN
        _update_player_action_buttons()
        _update_deck_visual()

        var current_p_node = player_nodes[current_player_index]
        if players_data[current_player_index].is_cpu and not current_p_node.is_out:
            call_deferred("_make_cpu_turn")
    else:
        print("DEBUG _advance_turn: Nessun giocatore valido per il turno, passo alla fase mazziere.")
        _go_to_dealer_phase()


func _go_to_dealer_phase():
    var dealer_node = player_nodes[dealer_index] if dealer_index >= 0 and dealer_index < player_nodes.size() else null

    if not is_instance_valid(dealer_node) or dealer_node.is_out:
        print("Mazziere %d non valido o fuori gioco. Termino il round." % dealer_index)
        call_deferred("_end_round"); return

    current_player_index = dealer_index
    current_state = GameState.DEALER_SWAP
    print("Fase Mazziere (Player %d)." % current_player_index)

    _update_player_action_buttons()
    _update_deck_visual()

    if players_data[current_player_index].is_cpu:
        call_deferred("_make_cpu_dealer_turn")


# --- Funzioni Handler Bottoni UI ---
# (Il codice fornito dall'utente qui è OK)
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

func _player_action(player_index: int, action: String, target_player_index: int = -1):
    var player_node = player_nodes[player_index] if player_index >= 0 and player_index < player_nodes.size() else null
    if not is_instance_valid(player_node) or player_node.is_out: return
    if players_data[player_index].has_swapped_this_round: return

    var my_card: CardData = _get_valid_carddata_from_player(player_index, "_pa my")
    var performed_action = false

    if action == "swap":
        var target_card: CardData = null
        var target_node = player_nodes[target_player_index] if target_player_index >= 0 and target_player_index < player_nodes.size() else null
        if not is_instance_valid(target_node) or target_node.is_out or target_player_index == player_index:
            printerr("ERRORE _player_action: Target scambio iniziale non valido: %d" % target_player_index)
        else:
            target_card = _get_valid_carddata_from_player(target_player_index, "_pa target")
            if my_card == null or target_card == null:
                printerr("ERRORE _player_action: Dati carta mancanti per swap!")
            elif my_card.rank_name == "K":
                print("Azione Bloccata: Hai il Re (K), non puoi iniziare uno scambio!")
            elif target_card.rank_name == "K":
                print("!!! KUKU !!! Player %d ha il Re (K)! Scambio fallito." % target_player_index)
                _show_effect_label("KUKU!", 1.5)
                players_data[player_index].has_swapped_this_round = true
                performed_action = true
            elif target_card.rank_name == "Q": # --- BLOCCO "SALTA!" CORRETTO ---
                print("!!! SALTA!!! Player %d ha la Regina (Q)! Scambio obbligato col successivo." % target_player_index)
                _show_effect_label("SALTA!", 1.5)
                var new_target_index = get_player_to_right(target_player_index)
                print("     -> Nuovo target calcolato: Player %d" % new_target_index)
                var new_target_node = player_nodes[new_target_index] if new_target_index >= 0 and new_target_index < player_nodes.size() else null
                
                if new_target_index == -1 or not is_instance_valid(new_target_node) or new_target_node.is_out:
                    printerr("ERRORE _player_action: Nuovo target (%d) dopo Salta non valido (inesistente o fuori gioco). Scambio annullato." % new_target_index)
                    players_data[player_index].has_swapped_this_round = true
                    performed_action = true
                else:
                    var new_target_card = _get_valid_carddata_from_player(new_target_index, "_pa new_target_salta")
                    if new_target_card == null:
                        printerr("ERRORE _player_action: Dati carta mancanti per NUOVO target %d dopo Salta!" % new_target_index)
                        players_data[player_index].has_swapped_this_round = true; performed_action = true
                    elif new_target_card.rank_name == "K":
                        print("!!! KUKU (Dopo Salta)!!! Player %d ha il Re! Scambio forzato fallito." % new_target_index)
                        _show_effect_label("KUKU!", 1.5)
                        players_data[player_index].has_swapped_this_round = true; performed_action = true
                    else:
                        print("Player %d scambia forzatamente con NUOVO target %d (dopo Salta)" % [player_index, new_target_index])
                        if my_card != null:
                            players_data[player_index].card_data[0] = new_target_card
                            players_data[new_target_index].card_data[0] = my_card
                            _update_player_card_visuals(player_index)
                            _update_player_card_visuals(new_target_index)
                            players_data[player_index].has_swapped_this_round = true
                            performed_action = true
                        else:
                            printerr("ERRORE CRITICO _player_action: my_card (di Player %d) è diventato null durante Salta!" % player_index)
                            players_data[player_index].has_swapped_this_round = true; performed_action = true
            else: # Scambio Normale A <-> B
                print("Player %d scambia con %d" % [player_index, target_player_index])
                players_data[player_index].card_data[0] = target_card
                players_data[target_player_index].card_data[0] = my_card
                _update_player_card_visuals(player_index); _update_player_card_visuals(target_player_index)
                players_data[player_index].has_swapped_this_round = true; performed_action = true

    elif action == "hold":
        print("Player %d tiene la carta." % player_index)
        players_data[player_index].has_swapped_this_round = true
        performed_action = true

    if performed_action:
        players_data[player_index].has_swapped_this_round = true
        if player_index == 0 and not players_data[player_index].is_cpu:
            _update_player_action_buttons()
        call_deferred("_advance_turn")


func _dealer_action(action: String):
    var dealer_node = player_nodes[dealer_index] if dealer_index >= 0 and dealer_index < player_nodes.size() else null
    if not is_instance_valid(dealer_node) or dealer_node.is_out:
        printerr("Azione mazziere annullata: Indice %d non valido o fuori." % dealer_index); call_deferred("_end_round"); return

    var dealer_card: CardData = _get_valid_carddata_from_player(dealer_index, "_da get")
    if dealer_card == null and action == "swap_deck": # Non può scambiare se non ha carta
         printerr("ERRORE CRITICO (_dealer_action): Mazziere %d non ha dati carta validi per scambiare!" % dealer_index)
         action = "pass"

    if action == "swap_deck":
        if dealer_card != null and dealer_card.rank_name == "K":
            print("Mazziere (%d) ha il Re (K)! Non può scambiare col mazzo. Azione forzata a 'pass'." % dealer_index)
            action = "pass"
        else:
            if DeckSetupScene == null or not DeckSetupScene.has_method("cards_remaining") or DeckSetupScene.cards_remaining() <= 0:
                print("Mazzo vuoto o non accessibile. Mazziere (%d) passa." % dealer_index)
                action = "pass"
            else:
                # Scambio effettivo
                if not players_data[dealer_index].card_data.is_empty():
                    players_data[dealer_index].card_data.pop_front()
                else: # Sicurezza extra se il controllo dealer_card sopra fallisse
                     printerr("ERRORE _dealer_action: card_data del mazziere %d è vuoto prima dello scambio!" % dealer_index)
                     action = "pass"; dealer_card = null 
                
                if action == "swap_deck": # Ricontrolla se forzato a pass
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
                        print("Mazziere (%d) scambia col mazzo. Scarta %s, Pesca %s." % [dealer_index, get_card_name(dealer_card), get_card_name(new_card)])
                        players_data[dealer_index].card_data.append(new_card)
                        _update_player_card_visuals(dealer_index)
                        if DeckSetupScene.has_method("discard_card") and dealer_card != null:
                            DeckSetupScene.discard_card(dealer_card)

    if action == "pass":
        print("Mazziere (%d) non scambia (passa)." % dealer_index)

    _update_deck_visual()
    _update_player_action_buttons()
    if get_tree(): await get_tree().create_timer(0.5).timeout
    call_deferred("_end_round")


func _make_cpu_dealer_turn():
    var cpu_dealer_node = player_nodes[dealer_index] if dealer_index >= 0 and dealer_index < player_nodes.size() else null
    if current_state != GameState.DEALER_SWAP or \
       current_player_index != dealer_index or \
       not is_instance_valid(cpu_dealer_node) or \
       cpu_dealer_node.is_out or \
       not players_data[dealer_index].is_cpu: return

    var cpu_dealer_index = dealer_index
    print("CPU Mazziere (%d) pensa..." % cpu_dealer_index)
    if get_tree(): await get_tree().create_timer(randf_range(1.5, 3.0)).timeout

    var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_dealer_index, "_mcdt")
    if card_to_evaluate == null:
        printerr("ERRORE (_make_cpu_dealer_turn): CPU Mazziere %d non ha dati carta!" % cpu_dealer_index); _dealer_action("pass"); return

    var my_card_value = get_card_value(card_to_evaluate)
    var deck_available = (DeckSetupScene != null and DeckSetupScene.has_method("cards_remaining") and DeckSetupScene.cards_remaining() > 0)
    var should_swap_deck = false

    if card_to_evaluate.rank_name == "K":
        print("CPU Mazziere (%d) ha il Re (K). Non scambia col mazzo." % cpu_dealer_index); should_swap_deck = false
    elif not deck_available:
        print("CPU Mazziere (%d) non può scambiare (mazzo vuoto/invalido)." % cpu_dealer_index); should_swap_deck = false
    elif my_card_value <= 4:
        print("CPU Mazziere (%d) ha carta bassa (%d) e mazzo disponibile. Scambia col mazzo." % [cpu_dealer_index, my_card_value]); should_swap_deck = true
    else:
        print("CPU Mazziere (%d) ha carta alta (%d). Passa." % [cpu_dealer_index, my_card_value]); should_swap_deck = false

    if should_swap_deck: _dealer_action("swap_deck")
    else: _dealer_action("pass")


func _make_cpu_turn():
    var cpu_node = player_nodes[current_player_index] if current_player_index >= 0 and current_player_index < player_nodes.size() else null
    if current_state != GameState.PLAYER_TURN or \
       not is_instance_valid(cpu_node) or \
       cpu_node.is_out or \
       not players_data[current_player_index].is_cpu: return

    var cpu_player_index = current_player_index
    print("CPU (%d) pensa..." % cpu_player_index)
    if get_tree(): await get_tree().create_timer(randf_range(1.5, 3.0)).timeout

    var card_to_evaluate: CardData = _get_valid_carddata_from_player(cpu_player_index, "_mct")
    if card_to_evaluate == null:
        printerr("ERRORE (_make_cpu_turn): CPU %d non ha dati carta!" % cpu_player_index); _player_action(cpu_player_index, "hold"); return

    var my_card_value = get_card_value(card_to_evaluate)
    var target_player_index = get_player_to_left(cpu_player_index) # Scambia a SINISTRA
    var target_node = player_nodes[target_player_index] if target_player_index != -1 else null
    var should_swap = false

    if card_to_evaluate.rank_name == "K":
        print("CPU (%d) ha il Re (K). Non scambia." % cpu_player_index); should_swap = false
    elif not is_instance_valid(target_node) or target_node.is_out:
        print("CPU (%d) non ha un target valido a sinistra. Passa." % cpu_player_index); should_swap = false
    elif my_card_value <= 5: # Logica CPU per decidere scambio
        print("CPU (%d) ha carta bassa (%d). Tenta lo scambio con P%d." % [cpu_player_index, my_card_value, target_player_index]); should_swap = true
    else:
        print("CPU (%d) ha carta alta (%d). Passa." % [cpu_player_index, my_card_value]); should_swap = false

    if should_swap: _player_action(cpu_player_index, "swap", target_player_index)
    else: _player_action(cpu_player_index, "hold")


# --- Fine Round e Punteggio ---

func _end_round():
    if current_state == GameState.GAME_OVER: return

    _update_player_action_buttons()
    current_state = GameState.REVEALING
    print("\n--- Fine Round ---"); print("Rivelazione...")

    reveal_all_cards()
    if get_tree(): await get_tree().create_timer(3.0).timeout

    print("Determinazione perdente...")
    determine_loser_and_update_lives()

    var active_players_count = 0
    for node in player_nodes:
        if is_instance_valid(node) and not node.is_out: active_players_count += 1

    if active_players_count <= 1: _handle_game_over(active_players_count); return

    _update_last_hand_display()
    if get_tree(): await get_tree().create_timer(2.0).timeout

    var old_dealer = dealer_index
    dealer_index = get_next_active_player(dealer_index, false) # Usa la versione basata sui nodi

    if dealer_index == -1:
        printerr("ERRORE _end_round: Impossibile trovare nuovo mazziere attivo!"); _handle_game_over(active_players_count); return

    print("Mazziere passa da %d a %d." % [old_dealer, dealer_index])
    call_deferred("_start_round")


func reveal_all_cards():
    for i in range(player_nodes.size()):
        var p_node = player_nodes[i]
        if is_instance_valid(p_node) and not p_node.is_out:
            if i < players_data.size() and not players_data[i].visual_cards.is_empty():
                var card_visual = players_data[i].visual_cards[0] as CardVisual
                if is_instance_valid(card_visual): card_visual.show_front()


func determine_loser_and_update_lives():
    var lowest_card_value = 100
    var losers_indices: Array[int] = []

    print("--- Valutazione Carte Fine Round ---")
    for i in range(player_nodes.size()):
        var p_node = player_nodes[i]
        if is_instance_valid(p_node) and not p_node.is_out:
            var card_to_evaluate: CardData = _get_valid_carddata_from_player(i, "det_loser_log")
            if i < players_data.size(): players_data[i].last_card = card_to_evaluate # Salva per UI
            else: printerr("ERRORE det_loser: Indice %d fuori range per players_data!" % i); continue

            if card_to_evaluate:
                var card_value = get_card_value(card_to_evaluate)
                var cpu_tag = "CPU" if players_data[i].is_cpu else "Umano"
                print("  Player %d (%s): %s (Val: %d)" % [i, cpu_tag, get_card_name(card_to_evaluate), card_value])

                if card_to_evaluate.rank_name != "K":
                    if card_value < lowest_card_value:
                        lowest_card_value = card_value; losers_indices.clear(); losers_indices.append(i)
                    elif card_value == lowest_card_value:
                        losers_indices.append(i)
            else:
                printerr("  ERRORE: Impossibile leggere carta per Player %d!" % i)
        elif i < players_data.size():
            players_data[i].last_card = null # Assicura sia null se fuori

    print("--- Calcolo Perdente ---")
    for i in range(player_nodes.size()): # Stampa chi è salvo per chiarezza
        var p_node = player_nodes[i]
        if is_instance_valid(p_node) and not p_node.is_out:
            if i < players_data.size() and players_data[i].last_card != null and players_data[i].last_card.rank_name == "K":
                print("  -> Player %d salvo (Re)." % i)

    if losers_indices.is_empty():
        print("Nessun perdente in questo round.")
    else:
        print("Perdente/i (Val %d): %s" % [lowest_card_value, str(losers_indices)])
        for loser_index in losers_indices:
            if loser_index >= 0: lose_life(loser_index) # Chiama la funzione aggiornata


func lose_life(player_index: int):
    if player_index >= 0 and player_index < player_nodes.size():
        var player_node = player_nodes[player_index]
        if is_instance_valid(player_node) and player_node.has_method("lose_finger"):
            print("GameManager dice a Player ", player_index, " di perdere un dito.")
            player_node.lose_finger()

            # Sincronizza is_out in players_data se lo usi ancora altrove
            if player_node.is_out:
                if player_index < players_data.size():
                    if not players_data[player_index].is_out:
                        players_data[player_index].is_out = true
                        print(">>> GameManager ha registrato Player ", player_index, " come eliminato (in players_data). <<<")
        else:
            printerr("ERRORE in lose_life: Nodo Player ", player_index, " non valido o manca metodo lose_finger().")
    else:
        printerr("ERRORE in lose_life: Indice giocatore non valido: ", player_index)


func _handle_game_over(active_count: int):
    print("\n=== PARTITA FINITA! ===")
    current_state = GameState.GAME_OVER
    _update_player_action_buttons()

    if active_count == 1:
        for i in range(player_nodes.size()):
            var p_node = player_nodes[i]
            if is_instance_valid(p_node) and not p_node.is_out:
                print("VINCITORE: Player %d !" % i)
                break
    elif active_count == 0:
        print("Tutti eliminati! Nessun vincitore.")
    else:
        print("Fine partita inattesa con %d giocatori attivi." % active_count)

    # --- AGGIUNGERE QUI UI FINE PARTITA / OPZIONE RIAVVIO ---


#region Funzioni Ausiliarie (Helper)
#==================================

# --- Funzioni Utilità Giocatori (Usano player_nodes per is_out) ---

func get_player_to_left(player_index: int) -> int:
    var size = player_nodes.size(); if size <= 1: return -1
    var current = player_index
    for _i in range(size - 1):
        current = (current - 1 + size) % size
        var candidate_node = player_nodes[current] if current < size else null
        if is_instance_valid(candidate_node) and not candidate_node.is_out: return current
    return -1

func get_player_to_right(player_index: int) -> int:
    var current = player_index; var size = player_nodes.size()
    if size <= 1: return -1
    for _i in range(size - 1):
        current = (current + 1) % size
        var candidate_node = player_nodes[current] if current < size else null
        if is_instance_valid(candidate_node):
            if not candidate_node.is_out: return current
    return -1

func get_next_active_player(start_index: int, clockwise: bool = false) -> int:
    var size = player_nodes.size()
    if start_index < 0 or start_index >= size or size <= 1: return -1
    var current = start_index
    for _i in range(size - 1):
        if clockwise: current = (current - 1 + size) % size
        else: current = (current + 1) % size
        var candidate_node = player_nodes[current] if current < size else null
        if is_instance_valid(candidate_node) and not candidate_node.is_out: return current
    return -1

# --- Funzioni CardData / Visuals ---

# Legge da players_data
func _get_valid_carddata_from_player(player_index: int, context: String = "?") -> CardData:
    if player_index < 0 or player_index >= players_data.size():
        printerr("ERRORE (%s): Indice player %d fuori range per players_data (%d)" % [context, player_index, players_data.size()]); return null
    if not players_data[player_index].has("card_data"):
        printerr("ERRORE (%s): Player %d non ha 'card_data'" % [context, player_index]); return null
    if players_data[player_index].card_data.is_empty(): return null
    var card_element = players_data[player_index].card_data[0]
    if card_element is CardData: return card_element
    # Fallback per vecchia struttura errata (da rimuovere se pulito)
    elif card_element is Array and not card_element.is_empty() and card_element[0] is CardData:
        printerr("ATTENZIONE (%s): Corretta struttura errata per Player %d." % [context, player_index])
        players_data[player_index].card_data[0] = card_element[0]; return card_element[0]
    else:
        printerr("ERRORE (%s): Tipo non valido (%s) in card_data[0] per Player %d!" % [context, typeof(card_element), player_index]); return null

# Corretta
func get_card_value(card: CardData) -> int:
    if card == null: printerr("get_card_value chiamata con card null!"); return 100
    match card.rank_name:
        "A": return 1
        "2": return 2
        "3": return 3
        "4": return 4
        "5": return 5
        "6": return 6
        "7": return 7
        "J": return 8
        "Q": return 9
        "K": return 10
        _: printerr("Rank non riconosciuto in get_card_value: '", card.rank_name, "'"); return 0

func get_card_name(card: CardData) -> String:
    if card: return card.rank_name + " " + card.suit
    return "Carta Invalida"

# Controlla nodo player prima di accedere a players_data
func _update_player_card_visuals(player_index: int):
    var player_node = player_nodes[player_index] if player_index >= 0 and player_index < player_nodes.size() else null
    if not is_instance_valid(player_node) or player_node.is_out:
        # Nascondi visuale se giocatore fuori / nodo non valido
        if player_index < players_data.size() and not players_data[player_index].visual_cards.is_empty():
            var existing_visual = players_data[player_index].visual_cards[0] as CardVisual
            if is_instance_valid(existing_visual): existing_visual.hide()
        return

    # Se il nodo è valido E non fuori, procedi
    if player_index >= players_data.size(): printerr("ERRORE _update_vis: Indice %d fuori range per players_data" % player_index); return
    var player_data = players_data[player_index]
    var card_to_display: CardData = _get_valid_carddata_from_player(player_index, "_update_vis")
    var card_visual = player_data.visual_cards[0] as CardVisual if not player_data.visual_cards.is_empty() else null

    if not is_instance_valid(card_visual): return
    if card_to_display == null: card_visual.hide(); return

    card_visual.card_data = card_to_display
    card_visual.visible = true

    if player_index == 0 and not player_data.is_cpu: card_visual.show_front()
    else: card_visual.show_back()


# --- Funzioni Aggiornamento UI (sembrano OK) ---

func _update_deck_visual():
    if deck_visual_instances.is_empty(): return
    var cards_left = 0
    # Assumendo DeckSetupScene sia Autoload o valido
    if DeckSetupScene != null and DeckSetupScene.has_method("cards_remaining"):
        cards_left = DeckSetupScene.cards_remaining()
    else:
        printerr("ERRORE in _update_deck_visual: DeckSetupScene non valido!");
        for instance in deck_visual_instances: if is_instance_valid(instance): instance.visible = false
        return
    var show_stack = (cards_left > 0)
    for instance in deck_visual_instances: if is_instance_valid(instance): instance.visible = show_stack

func _update_player_action_buttons():
    var normal_swap_valid = is_instance_valid(swap_button)
    var normal_pass_valid = is_instance_valid(pass_button)
    var dealer_swap_valid = is_instance_valid(swap_to_deck_button)
    var dealer_pass_valid = is_instance_valid(pass_as_dealer_button)
    var enable_player_buttons = false
    var enable_dealer_buttons = false

    var current_p_node = player_nodes[current_player_index] if current_player_index >= 0 and current_player_index < player_nodes.size() else null
    if is_instance_valid(current_p_node) and not current_p_node.is_out:
        # Assumendo Player 0 sia umano e leggendo is_cpu/has_swapped da players_data
        if current_player_index < players_data.size(): # Sicurezza
            if current_state == GameState.PLAYER_TURN and \
               current_player_index == 0 and \
               not players_data[0].is_cpu and \
               not players_data[0].has_swapped_this_round:
                enable_player_buttons = true
            if current_state == GameState.DEALER_SWAP and \
               current_player_index == 0 and \
               not players_data[0].is_cpu:
                enable_dealer_buttons = true

    if normal_swap_valid: swap_button.visible = enable_player_buttons; swap_button.disabled = not enable_player_buttons
    if normal_pass_valid: pass_button.visible = enable_player_buttons; pass_button.disabled = not enable_player_buttons
    if dealer_swap_valid: swap_to_deck_button.visible = enable_dealer_buttons; swap_to_deck_button.disabled = not enable_dealer_buttons
    if dealer_pass_valid: pass_as_dealer_button.visible = enable_dealer_buttons; pass_as_dealer_button.disabled = not enable_dealer_buttons

func _update_last_hand_display():
    if last_hand_textures.size() == 0: return
    if last_hand_textures.size() != num_players or last_hand_labels.size() != num_players:
        printerr("ERRORE _update_last_hand: Disallineamento UI Ultima Mano!"); return

    for i in range(num_players):
        var label = last_hand_labels[i] if is_instance_valid(last_hand_labels[i]) else null
        var texture_rect = last_hand_textures[i] if is_instance_valid(last_hand_textures[i]) else null
        if not texture_rect: continue

        var last_card: CardData = players_data[i].last_card if i < players_data.size() and players_data[i].has("last_card") else null

        if label: label.text = "P%d:" % i
        if last_card != null and is_instance_valid(last_card.texture_front):
            texture_rect.texture = last_card.texture_front; texture_rect.visible = true
        else:
            texture_rect.texture = null; texture_rect.visible = false

# --- Funzioni Notifiche (sembrano OK) ---

func _show_cucu_king_notification(king_holder_index: int):
    if cucu_notification_label == null or notification_timer == null:
        printerr("ERRORE ShowNotify: Label/Timer notifiche non trovati."); return
    var message = "CUCÙ!\nGiocatore %d è protetto dal Re!" % king_holder_index
    cucu_notification_label.text = message; cucu_notification_label.visible = true
    if cucu_notification_label is Control:
        var viewport_rect = get_viewport().get_visible_rect()
        cucu_notification_label.position = viewport_rect.position + viewport_rect.size / 2.0 - cucu_notification_label.size / 2.0
    notification_timer.wait_time = 2.5; notification_timer.start()

func _show_effect_label(text_to_show: String, duration: float = 1.5):
    if not is_instance_valid(cucu_notification_label):
        printerr("EffectLabel non assegnato!"); print("EFFETTO: %s" % text_to_show); return
    cucu_notification_label.text = text_to_show; cucu_notification_label.visible = true
    if notification_timer:
        notification_timer.stop(); notification_timer.wait_time = duration; notification_timer.start()
    else: printerr("Impossibile avviare notification_timer!")

func _on_notification_timer_timeout():
    if is_instance_valid(cucu_notification_label): cucu_notification_label.visible = false

# --- Handler Segnali da Player ---

func _on_player_fingers_updated(p_id: int, p_fingers: int):
    # print("HANDLER: Ricevuto fingers_updated da Player ", p_id, ". Dita rimaste: ", p_fingers) # Debug opzionale
    if p_id >= 0 and p_id < player_info_labels.size():
        var label = player_info_labels[p_id]
        if is_instance_valid(label):
            label.text = "Vite P%d: %d" % [p_id, p_fingers]
            # Considera aggiornare visibilità basata su p_fingers o stato is_out del nodo player
            # var p_node = player_nodes[p_id] if p_id < player_nodes.size() else null
            # if is_instance_valid(p_node): label.visible = not p_node.is_out
        else: printerr("HANDLER: Label vite per Player ", p_id, " non valida!")
    else: printerr("HANDLER: ID Player ", p_id, " non valido per l'array delle label vite.")


# _________________________ABILITà DA QUI IN POI____________________________________________

# Restituisce gli ID dei giocatori attivi a sinistra e destra di un dato ID
# Ritorna un array: [id_sinistra, id_destra] (-1 se un vicino non è valido/attivo)
func get_adjacent_players(p_id: int) -> Array[int]:
    # Chiama le funzioni helper che già avevamo e che usano player_nodes
    # per trovare i vicini attivi.
    var left_id = get_player_to_left(p_id)  # Dovrebbe già esistere
    var right_id = get_player_to_right(p_id) # Dovrebbe già esistere
    # print("DEBUG GM: Adiacenti per P%d -> Sx:%d, Dx:%d" % [p_id, left_id, right_id]) # Debug opzionale
    return [left_id, right_id]


# Restituisce l'oggetto CardData del giocatore specificato
# Ritorna null se l'indice non è valido, il giocatore non ha dati carta, 
# o i dati non sono un oggetto CardData valido.
func get_player_card_data(p_id: int) -> CardData:
    # Chiama la funzione helper interna che già esisteva e leggeva da players_data
    # Passiamo un contesto generico per il log di errore interno (se presente)
    var card: CardData = _get_valid_carddata_from_player(p_id, "GM_get_card_request")
    # print("DEBUG GM: Richiesta carta P%d -> %s" % [p_id, get_card_name(card)]) # Debug opzionale
    return card

#func _unhandled_input(event):
    ## Attiva Abilità 1 di Player 0 premendo F1 (solo se è il suo turno)
    #if event.is_action_pressed("ui_accept") and current_player_index == 0 and current_state == GameState.PLAYER_TURN : # Usa un tasto dedicato, es. F1 mappato in Input Map
         #print("DEBUG: Tentativo attivazione Abilità 1 per Player 0...")
         #if player_nodes.size() > 0 and is_instance_valid(player_nodes[0]):
             ## Chiama la funzione nel Player, passando -1 come target (non serve per Sguardo Circolare)
             #var success = player_nodes[0].try_use_active_ability(1, -1) 
             #if success:
                 #print("DEBUG: try_use_active_ability(1) ha restituito true.")
             #else:
                 #print("DEBUG: try_use_active_ability(1) ha restituito false (controllare condizioni).")
                
                
func _on_player0_sanity_updated(p_id: int, p_sanity: int):
    # Questo handler riceve l'update solo per Player 0 (p_id sarà 0)
    # print("HANDLER: Ricevuto sanity_updated da Player 0. Sanità: ", p_sanity) # Debug opzionale
    
    # Controlla se la label esportata è valida
    if is_instance_valid(player0_sanity_label):
        # Aggiorna il testo della label usando il formato percentuale
        # NOTA: In GDScript, per stampare un carattere '%', devi scrivere '%%'
        player0_sanity_label.text = "Sanità: %d%%" % p_sanity # Es: "Sanità: 85%"
        
        # OPZIONALE: Cambia colore testo in base alla percentuale
        if p_sanity < 30:
            player0_sanity_label.modulate = Color.ORANGE # O Color.RED
        else:
            player0_sanity_label.modulate = Color.WHITE # Colore normale
            
    else:
        printerr("HANDLER: player0_sanity_label non valida!")


#endregion
