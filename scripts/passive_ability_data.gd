# File: res://scripts/resources/passive_ability_data.gd
# Modifica 'extends Resource' in 'extends AbilityBaseData' se usi la base comune
extends Resource
class_name PassiveAbilityData


@export var ability_name: String = "Nome Abilità Passiva"
@export_multiline var description: String = "Descrizione dell'effetto passivo."
@export var icon: Texture2D

# --- Specifici per Abilità Passive ---
# Le passive spesso si attivano in risposta a eventi di gioco.
# La logica effettiva sarà probabilmente nello script del giocatore o della classe,
# ma la risorsa può definire a quale evento "ascoltare".
enum TriggerEvent {
	NONE, # Sempre attiva o gestita manualmente
	DAY_START, # Inizio di un nuovo Giorno (ogni 5 round)
	ROUND_START,
	ROUND_END,
	TURN_START,
	TURN_END,
	FINGER_LOST_SELF, # Quando il giocatore stesso perde un dito
	FINGER_LOST_OTHER, # Quando un altro giocatore perde un dito
	SANITY_CHANGE_SELF,
	SANITY_CHANGE_OTHER,
	RECEIVED_CARD_TYPE, # Quando riceve un tipo specifico di carta (es. Asso per Fiammetta)
	FORCED_SWAP_HIGH_CARD, # Quando costretto a scambiare K, Q, J (per Elissa)
	# Aggiungere altri eventi specifici necessari
}
@export var trigger_event: TriggerEvent = TriggerEvent.NONE

# Potrebbe servire un campo per parametri specifici della passiva
# Esempio: per "Favore Reale" di Emilia, potremmo specificare il guadagno di Sanità
# Usiamo un Dictionary per flessibilità
@export var passive_parameters: Dictionary = {"sanity_gain_on_kq_safe": 5}
