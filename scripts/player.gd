# File: res://scripts/Player.gd
# Versione completa con gestione stato (dita, sanità, is_out)
# e struttura base per attivazione abilità/passive/cooldown

extends Node3D

# --- Segnali Emessi da questo Player ---
signal sanity_updated(player_id, new_sanity)           # Quando la sanità cambia
signal cooldown_updated(player_id, slot, remaining_rounds) # Quando un cooldown cambia
signal fingers_updated(player_id, remaining_fingers)  # Quando le dita cambiano
signal player_eliminated(player_id)                   # Quando il giocatore viene eliminato (dita <= 0)
signal player_breakdown(player_id)                    # Quando la sanità arriva a 0
# Segnali per richiedere info/azioni al GameManager (usati dagli effetti delle abilità)
signal request_adjacent_info(requesting_player_id)
signal request_card_info(requesting_player_id, target_player_id)
signal request_dealer_choice(requesting_player_id)
# Aggiungi altri segnali specifici se necessario

# --- Dati della Classe Assegnata ---
@export var class_data: CharacterClassData = null

# --- Stato Dinamico del Giocatore ---
var player_id: int = -1                 # ID univoco (0-9) assegnato dal GameManager
var fingers_remaining: int = 10        # Vite/Dita iniziali
var current_sanity: int = 100         # Sanità iniziale
var is_out: bool = false                # Se il giocatore è eliminato
var active_ability_1_cooldown_timer: int = 0 # Round rimanenti per cooldown slot 1
var active_ability_2_cooldown_timer: int = 0 # Round rimanenti per cooldown slot 2
var desperate_action_available: bool = true # Se l'azione disperata è utilizzabile

# TODO: Aggiungere variabili per token e altri stati specifici delle classi
# var vengeance_tokens: int = 0
# var intuition_tokens: int = 0
# var amulet_charges: int = 0
# var is_blinded: bool = false # Es. per Filostrato
# var is_passive_muted: bool = false # Es. per Lauretta
# var has_swap_immunity: bool = false # Es. per Elissa
# var temp_rank_boost: int = 0 # Es. per Emilia
# var peaceful_rounds_counter: int = 0 # Es. per Panfilo
# var has_free_ability_charge: bool = false # Es. per Panfilo


# --- Funzioni Base Godot ---

func _ready():
    # Potremmo spostare l'inizializzazione che dipende da altri nodi qui, usando await ready
    pass

# --- Inizializzazione e Stato ---

func assign_class(new_class_data: CharacterClassData, id: int):
    if new_class_data != null:
        self.class_data = new_class_data
        self.player_id = id
        print("Player (ID ", player_id, ") assegnata classe: ", class_data.character_name, " (", class_data.display_name, ")")

        # Resetta stato iniziale completo
        current_sanity = 100  # O valore base specifico classe?
        active_ability_1_cooldown_timer = 0
        active_ability_2_cooldown_timer = 0
        desperate_action_available = true
        fingers_remaining = 10
        is_out = false
        # TODO: Resettare token, stati alterati, ecc.
        # Esempio specifico per Neifile (basato sui parametri della sua passiva)
        # if class_data.passive_ability and class_data.passive_ability.ability_name == "Amuleto della Speranza":
        #     amulet_charges = class_data.passive_ability.passive_parameters.get("initial_charges", 0)
        # else:
        #     amulet_charges = 0

        # Connessione segnali specifici classe (se necessario) - Esempio Pampinea
        # if class_data.display_name == "La Comandante":
        #     if GameManager and GameManager.has_signal("day_started"):
        #         if not GameManager.is_connected("day_started", Callable(self,"_on_day_started")):
        #             var err = GameManager.connect("day_started", Callable(self,"_on_day_started"))
        #             if err != OK: printerr("Player ", player_id, ": Errore connessione day_started: ", err)
        #     else: printerr("Player ", player_id, ": GameManager o segnale day_started non trovati.")

        # Emetti segnali iniziali per UI
        emit_signal("sanity_updated", player_id, current_sanity)
        emit_signal("cooldown_updated", player_id, 1, 0)
        emit_signal("cooldown_updated", player_id, 2, 0)
        emit_signal("fingers_updated", player_id, fingers_remaining)
        # TODO: Emettere segnali per stato iniziale token/abilità disperata?

    else:
        printerr("Tentativo di assegnare una classe nulla al Player (ID ", id, ")")


func lose_finger():
    if is_out: return

    # TODO: Gestire passive che PREVENGONO la perdita (es. Amuleto Neifile)
    # Esempio Neifile:
    # if class_data and class_data.passive_ability and class_data.passive_ability.ability_name == "Amuleto della Speranza":
    #     if amulet_charges > 0:
    #         amulet_charges -= 1
    #         print("Player (ID ", player_id, ") usa una carica dell'Amuleto! Cariche rimaste: ", amulet_charges)
    #         emit_signal("amulet_charge_used", player_id, amulet_charges) # Segnale per UI?
    #         return # Perdita dito annullata

    if fingers_remaining > 0:
        fingers_remaining -= 1
        print("Player (ID ", player_id, ") ha perso un dito! Rimaste: ", fingers_remaining)
        emit_signal("fingers_updated", player_id, fingers_remaining)

        if fingers_remaining <= 0:
            _handle_elimination()
        else:
            # TODO: Gestire passive che si attivano DOPO aver perso un dito (es. Riscatto Nobile Elissa)
            # if class_data and class_data.active_ability_2 and class_data.active_ability_2.ability_name == "Riscatto Nobile":
            #     print("Player (ID ", player_id, ") attiva Riscatto Nobile!")
            #     update_sanity(25) # Valore dall'abilità resource?
            pass


func get_fingers_remaining() -> int:
    return fingers_remaining


func _handle_elimination():
    if is_out: return
    print("!!!!!!!! Player (ID ", player_id, ") è stato ELIMINATO !!!!!!!!");
    is_out = true
    emit_signal("player_eliminated", player_id)
    # Logica aggiuntiva (nascondi nodo, ecc.)
    # visible = false
    # set_process(false)
    pass


# --- Gestione Sanità ---

func update_sanity(amount: int):
    if is_out: return

    var old_sanity = current_sanity
    current_sanity = clamp(current_sanity + amount, 0, 100)

    if old_sanity != current_sanity:
        print("Player (ID ", player_id, ") sanità aggiornata a: ", current_sanity, " (Cambiamento: ", amount, ")")
        emit_signal("sanity_updated", player_id, current_sanity)

        if current_sanity < 30 and old_sanity >= 30:
            print("ATTENZIONE: Player (ID ", player_id, ") ha Sanità bassa!")
            # TODO: Applicare effetti negativi/penalità?
        elif current_sanity >= 30 and old_sanity < 30:
            print("INFO: Player (ID ", player_id, ") ha recuperato Sanità sufficiente.")
            # TODO: Rimuovere effetti negativi?

        if current_sanity == 0 and old_sanity > 0:
            _handle_breakdown()


func _handle_breakdown():
    print("!!!!!! Player (ID ", player_id, ") ha avuto un BREAKDOWN (Sanità 0) !!!!!!")
    emit_signal("player_breakdown", player_id)
    # TODO: Implementare logica per perdita controllo, blocco skill, ecc.
    # var is_in_breakdown = true
    pass


# --- Gestione Abilità Attive Standard ---

func try_use_active_ability(slot: int, target_player_id: int = -1):
    if is_out: print("Player ", player_id, " è fuori."); return false
    # TODO: if is_in_breakdown: print("Player ", player_id, " è in breakdown."); return false

    var ability_data: ActiveAbilityData
    if class_data == null: printerr("Player ", player_id, ": Classe non caricata!"); return false

    if slot == 1: ability_data = class_data.active_ability_1
    elif slot == 2: ability_data = class_data.active_ability_2
    else: printerr("Player ", player_id, ": Slot ", slot, " non valido."); return false

    if ability_data == null: printerr("Player ", player_id, ": Slot ", slot, " vuoto per classe ", class_data.display_name); return false

    # 1. Controlla Cooldown (Implementeremo logica completa dopo)
    var current_cooldown = active_ability_1_cooldown_timer if slot == 1 else active_ability_2_cooldown_timer
    if current_cooldown > 0:
        print("Player ", player_id, ": Abilità '", ability_data.ability_name, "' in cooldown per ", current_cooldown, " round.")
        return false

    # 2. Controlla Costo Sanità
    if current_sanity < ability_data.sanity_cost:
        print("Player ", player_id, "): Sanità insufficiente per '", ability_data.ability_name, "'.")
        return false

    # 3. TODO: Controlla Fase Attivazione (richiede info da GameManager)
    #    var current_game_phase = GameManager.get_current_phase()
    #    if not _check_activation_phase(ability_data.activation_phase, current_game_phase): return false

    # 4. TODO: Controlla Bersaglio Valido (se richiesto dall'abilità)
    #    if not _check_target(ability_data.target_type, target_player_id): return false

    # 5. TODO: Controlla Requisiti Speciali (Token, Carte specifiche)
    #    if not _check_special_requirements(ability_data.special_requirements): return false

    # --- Attivazione! ---
    print("Player ", player_id, " attiva '", ability_data.ability_name, "'...")

    # 6. Paga Costo Sanità
    if ability_data.sanity_cost > 0:
        update_sanity(-ability_data.sanity_cost)

    # 7. TODO: Consuma Token se necessario
    #    _consume_tokens(ability_data.special_requirements)

    # 8. Imposta Cooldown (Implementeremo logica completa dopo)
    if ability_data.cooldown_rounds > 0:
        if slot == 1: active_ability_1_cooldown_timer = ability_data.cooldown_rounds
        elif slot == 2: active_ability_2_cooldown_timer = ability_data.cooldown_rounds
        emit_signal("cooldown_updated", player_id, slot, ability_data.cooldown_rounds)

    # 9. Esegui Effetto
    _execute_ability_effect(ability_data, target_player_id)

    return true


func _execute_ability_effect(ability_data: ActiveAbilityData, target_id: int):
    print(">>> ESECUZIONE EFFETTO per: ", ability_data.ability_name, " (Player ID ", player_id, ") Target ID: ", target_id)
    match ability_data.ability_name:
        # Pampinea
        "Sguardo Circolare": _effect_sguardo_circolare()
        "Interrogatorio Diretto": _effect_interrogatorio_diretto(target_id)
        # Dioneo
        "Catena Infernale": _effect_catena_infernale()
        "Puntura Cinica": _effect_puntura_cinica(target_id)
        # Filomena
        "Lampo d'Intuito": _effect_lampo_d_intuito() # Dovrà gestire la scelta
        "Presagio": _effect_presagio(target_id)
        # Emilia
        "Messa in Scena": _effect_messa_in_scena()
        "Ritocco Vitale": _effect_ritocco_vitale()
        # Fiammetta
        "Atto Disperato": _effect_atto_disperato()
        "Rivalsa Ardente": _effect_rivalsa_ardente(target_id) # Target qui è ipotetico, gestito nello swap
        # Filostrato
        "Tuffo nel Vuoto": _effect_tuffo_nel_vuoto()
        "Annuncio Funesto": _effect_annuncio_funesto()
        # Lauretta
        "Lingua Annodata": _effect_lingua_annodata(target_id)
        "Paragone Pungente": _effect_paragone_pungente(target_id)
        # Neifile
        "Squarcio di Verità": _effect_squarcio_di_verita()
        "Soffio Vitale": _effect_soffio_vitale(target_id)
        # Elissa
        "Volontà Indomita": _effect_volonta_indomita()
        "Riscatto Nobile": _effect_riscatto_nobile() # Chiamata da lose_finger? O è attiva? Rivedere design
        # Panfilo
        "Imposizione Storica": _effect_imposizione_storica(target_id)
        "Eco del Passato": _effect_eco_del_passato(target_id)
        # Default
        _: printerr("Effetto non implementato per ", ability_data.ability_name)


# --- Implementazione Effetti Specifici (TUTTI PLACEHOLDER) ---

# PAMPINEA
func _effect_sguardo_circolare(): print("TODO Player ", player_id, ": Implementa Sguardo Circolare"); emit_signal("request_adjacent_info", player_id)
func _effect_interrogatorio_diretto(target_id): print("TODO Player ", player_id, ": Implementa Interrogatorio Diretto su ", target_id); emit_signal("request_card_info", player_id, target_id)
# DIONEO
func _effect_catena_infernale(): print("TODO Player ", player_id, ": Implementa Catena Infernale (segnale a GM)")
func _effect_puntura_cinica(target_id): print("TODO Player ", player_id, ": Implementa Puntura Cinica su ", target_id); # GameManager.apply_sanity_damage(target_id, -25)?
# FILOMENA
func _effect_lampo_d_intuito(): print("TODO Player ", player_id, ": Implementa Lampo d'Intuito (gestire scelta UI)")
func _effect_presagio(target_id): print("TODO Player ", player_id, ": Implementa Presagio su ", target_id)
# EMILIA
func _effect_messa_in_scena(): print("TODO Player ", player_id, ": Implementa Messa in Scena (imposta stato 'faking_kuku')")
func _effect_ritocco_vitale(): print("TODO Player ", player_id, ": Implementa Ritocco Vitale (imposta stato 'temp_rank_boost')")
# FIAMMETTA
func _effect_atto_disperato(): print("TODO Player ", player_id, ": Implementa Atto Disperato (chiedi carta a GM, termina turno)")
func _effect_rivalsa_ardente(target_id): print("TODO Player ", player_id, ": Implementa Rivalsa Ardente (imposta stato 'force_next_swap')") # Logica complessa nello scambio
# FILOSTRATO
func _effect_tuffo_nel_vuoto(): print("TODO Player ", player_id, ": Implementa Tuffo nel Vuoto (imposta stato 'is_blinded')")
func _effect_annuncio_funesto(): print("TODO Player ", player_id, ": Implementa Annuncio Funesto (imposta stato 'predicted_finger_loss')")
# LAURETTA
func _effect_lingua_annodata(target_id): print("TODO Player ", player_id, ": Implementa Lingua Annodata su ", target_id); # GameManager.apply_status(target_id, "passive_muted", 2_rounds)?
func _effect_paragone_pungente(target_id): print("TODO Player ", player_id, ": Implementa Paragone Pungente su ", target_id); # Richiedi carte, confronta, segnale UI
# NEIFILE
func _effect_squarcio_di_verita(): print("TODO Player ", player_id, ": Implementa Squarcio di Verità (segnale a GM/UI globale)")
func _effect_soffio_vitale(target_id): print("TODO Player ", player_id, ": Implementa Soffio Vitale su ", target_id); # GameManager.apply_sanity_heal(target_id, 8)?
# ELISSA
func _effect_volonta_indomita(): print("TODO Player ", player_id, ": Implementa Volontà Indomita (imposta stato 'swap_immunity')")
func _effect_riscatto_nobile(): print("TODO Player ", player_id, ": Implementa Riscatto Nobile (chiamato da lose_finger?)") # Probabilmente passiva triggerata
# PANFILO
func _effect_imposizione_storica(target_id): print("TODO Player ", player_id, ": Implementa Imposizione Storica su ", target_id); # Segnale a GM per forzare scambio
func _effect_eco_del_passato(target_id): print("TODO Player ", player_id, ": Implementa Eco del Passato da ", target_id); # Chiedi ultima abilità a GM, attivala


# --- Gestione Cooldown ---

# Chiamata da GameManager a inizio/fine round
func decrement_cooldowns():
    var changed1 = false; var changed2 = false
    if active_ability_1_cooldown_timer > 0: active_ability_1_cooldown_timer -= 1; changed1 = true
    if active_ability_2_cooldown_timer > 0: active_ability_2_cooldown_timer -= 1; changed2 = true
    if changed1: emit_signal("cooldown_updated", player_id, 1, active_ability_1_cooldown_timer)
    if changed2: emit_signal("cooldown_updated", player_id, 2, active_ability_2_cooldown_timer)

# Chiamata da GameManager all'inizio di ogni nuovo "Giorno"
func reset_desperate_action_cooldown(day_num: int):
    print("Player (ID ", player_id, "): Cooldown Azione Disperata resettato (Inizio Giorno ", day_num, ")")
    desperate_action_available = true
    # TODO: Emettere segnale per UI Azione Disperata?
    pass


# --- Gestione Abilità Passive (Struttura Placeholder) ---

# Chiamata da GameManager alla fine del round
func end_of_round_update():
    # print("DEBUG Player ", player_id, ": Eseguo aggiornamenti fine round.")
    # Qui gestiamo passive che triggerano su ROUND_END
    if class_data and class_data.passive_ability:
        var passive = class_data.passive_ability
        if passive.trigger_event == PassiveAbilityData.TriggerEvent.ROUND_END:
            _execute_passive_effect(passive)

# Smistamento per logica passiva
func _execute_passive_effect(passive_data: PassiveAbilityData):
    print(">>> ESECUZIONE PASSIVA per: ", passive_data.ability_name, " (Player ID ", player_id, ")")
    match passive_data.ability_name:
        # Filomena
        "Intuito Macabro": _passive_intuito_macabro(passive_data)
        # Emilia
        "Favore Reale": _passive_favore_reale(passive_data)
        # Panfilo
        "Flusso Narrativo": _passive_flusso_narrativo(passive_data)
        # Aggiungi qui altri case per passive che triggerano su ROUND_END
        _: print("Nessuna logica ROUND_END implementata per passiva ", passive_data.ability_name)


# --- Implementazione Logica Passiva Specifica (Placeholder) ---

func _passive_intuito_macabro(p_data: PassiveAbilityData): print("TODO Player ", player_id, ": Implementa logica Intuito Macabro")
func _passive_favore_reale(p_data: PassiveAbilityData): print("TODO Player ", player_id, ": Implementa logica Favore Reale")
func _passive_flusso_narrativo(p_data: PassiveAbilityData): print("TODO Player ", player_id, ": Implementa logica Flusso Narrativo")

# --- Altri Handler per Passive (Trigger diversi da ROUND_END) ---
# Questi andrebbero connessi a segnali specifici del GameManager o chiamati da altre funzioni Player.gd

# func _on_day_started(day_num): # Connesso a GameManager.day_started SE Pampinea
#     if class_data and class_data.passive_ability.ability_name == "Prima Voce":
#         print("Player ", player_id, " (Pampinea): Attivazione Passiva 'Prima Voce'!")
#         emit_signal("request_dealer_choice", player_id)

# func _on_card_received(new_card: CardData): # Chiamato quando riceve carta
#     if class_data and class_data.passive_ability.ability_name == "Animo Ardente":
#          _passive_animo_ardente(new_card, class_data.passive_ability.passive_parameters)

# func _passive_animo_ardente(card, params): print("TODO Player ", player_id, ": Implementa Animo Ardente")

# func _on_other_player_lost_finger(other_player_id): # Connesso a segnale GM
#     if class_data and class_data.passive_ability.ability_name == "Rassegnazione":
#         _passive_rassegnazione() # Non serve danno sanità qui, l'effetto è non subirlo

# func _passive_rassegnazione(): print("TODO Player ", player_id, ": Implementa Rassegnazione")

# func _on_targeted_by_effect(effect_data): # Connesso a segnale GM o chiamato da funzione apply_effect?
#     if class_data and class_data.passive_ability.ability_name == "Scetticismo":
#         _passive_scetticismo(effect_data, class_data.passive_ability.passive_parameters)

# func _passive_scetticismo(effect, params): print("TODO Player ", player_id, ": Implementa Scetticismo")

# func _on_sanity_lost(amount, source): # Connesso a segnale GM o chiamato da update_sanity?
#     if class_data and class_data.passive_ability.ability_name == "Orgoglio Nobile":
#         var reduction = _passive_orgoglio_nobile(amount, source, class_data.passive_ability.passive_parameters)
#         return reduction # Ritorna la riduzione da applicare? Modello da definire.

# func _passive_orgoglio_nobile(amount, source, params): print("TODO Player ", player_id, ": Implementa Orgoglio Nobile"); return 0


# Nota: La gestione delle passive triggerate da eventi specifici (FINGER_LOST_OTHER, RECEIVED_CARD_TYPE, ecc.)
# richiederà che il GameManager emetta segnali appropriati o che Player.gd controlli la passiva
# all'interno delle funzioni rilevanti (es. check Animo Ardente quando si riceve una carta,
# check Amuleto dentro lose_finger, check Rassegnazione quando arriva segnale da GM, ecc.).
