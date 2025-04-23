# File: res://scripts/resources/active_ability_data.gd
# Modifica 'extends Resource' in 'extends AbilityBaseData' se usi la base comune
extends Resource # O extends AbilityBaseData 
class_name ActiveAbilityData


@export var ability_name: String = "Nome Abilità Attiva"
@export_multiline var description: String = "Descrizione dell'effetto attivo."
@export var icon: Texture2D 

# --- Specifici per Abilità Attive ---
@export var sanity_cost: int = 10
@export var cooldown_rounds: int = 3

# Definiamo alcuni tipi di bersaglio comuni
enum TargetType { SELF, ADJACENT_SINGLE , OTHER_PLAYER, ADJACENT_LEFT, ADJACENT_RIGHT, ADJACENT_BOTH, ALL_PLAYERS, NONE }
@export var target_type: TargetType = TargetType.NONE

# Definiamo alcune condizioni/fasi di attivazione
enum ActivationPhase { 
	ANY_TIME_ON_TURN, # In qualunque momento durante il proprio turno
	BEFORE_ACTION_CONFIRM, # Prima di confermare Scambia/Passa
	ON_TURN_START, # Appena inizia il turno
	ON_ROUND_START, # All'inizio del round (es. Annuncio Funesto)
	REQUIRES_LOW_CARD, # Se si ha una carta specifica (es. Asso, 2, 3...)
	AUTOMATIC_TRIGGER # Non attivata manualmente (es. Riscatto Nobile - forse meglio come passiva?) 
	# Aggiungere altri se necessario
}
@export var activation_phase: ActivationPhase = ActivationPhase.ANY_TIME_ON_TURN

# Potrebbe servire un campo per condizioni speciali (es. "Richiede Token Intuizione")
# Si potrebbe usare un array di stringhe o un altro enum
@export var special_requirements: Array[String] = [] # Es. ["REQUIRES_INTUITION_TOKEN", "REQUIRES_LOW_CARD_1_2_3"]
