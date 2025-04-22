# File: res://scripts/resources/character_class_data.gd (NEL TUO PROGETTO KUKÙ)
extends Resource
class_name CharacterClassData

@export var display_name: String = "Nome Classe" # <--- RINOMINATO! (Era class_name)
@export var character_name: String = "Nome Personaggio" # Es. "Pampinea"
@export_multiline var class_description: String = "Descrizione della classe e del suo ruolo."

# Qui assegniamo le risorse specifiche delle abilità create in precedenza
@export var active_ability_1: ActiveAbilityData = null
@export var active_ability_2: ActiveAbilityData = null
@export var passive_ability: PassiveAbilityData = null

# Potremmo aggiungere altri dati specifici della classe se necessario
# @export var starting_sanity_modifier: int = 0
