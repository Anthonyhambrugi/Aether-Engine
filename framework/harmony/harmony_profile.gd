class_name HarmonyProfile
extends Resource
## Constantes de física do Harmony, em px/frame (60 ticks/s).
## Valores base = Sonic 2/3 (Sonic Physics Guide, SPG:Forces / SPG:Characters).
## Duplique um .tres em profiles/ pra criar outro personagem.
##
## UM PERSONAGEM = UM .tres: as constantes abaixo + o loadout de habilidades
## (`ability_scripts`, no fim). Trocar de personagem em runtime é só
## `body.profile = outro_profile`.
##
## IMPORTANTE: este Resource é a BASE e é compartilhado entre quem o usa.
## Não escreva nele em runtime pra fazer power-up/água/etc. — use os
## modificadores do corpo (`body.add_mod(...)`, ver harmony_stat_mod.gd),
## que mexem só em `body.stats` (a cópia efetiva daquele corpo).

enum SlipMethod { SONIC_1_2_CD, SONIC_3 }

@export_group("Chão")
@export var acceleration := 0.046875
@export var deceleration := 0.5
@export var friction := 0.046875
@export var top_speed := 6.0

@export_group("Rolar")
@export var roll_friction := 0.0234375
@export var roll_deceleration := 0.125
## Velocidade mínima pra começar a rolar (S1/2/3: 0.5, S&K: 1.0).
@export var roll_min_speed := 0.5
## Abaixo disso o personagem desenrola.
@export var unroll_speed := 0.5
## Limite de ground speed rolando (SPG sugere ~16). 0 = sem limite.
@export var roll_max_speed := 16.0
@export var roll_slope_uphill := 0.078125
@export var roll_slope_downhill := 0.3125

@export_group("Ladeiras")
@export var slope_factor := 0.125
## true = Sonic 3+: aplica o fator mesmo parado se >= 0.05078125.
## false = Sonic 1/2/CD: parado não é afetado.
@export var slope_when_stopped := true
@export var slip_method: SlipMethod = SlipMethod.SONIC_3
@export var slip_speed_threshold := 2.5
@export var control_lock_frames := 30

@export_group("Ar")
@export var air_acceleration := 0.09375
@export var gravity := 0.21875
## 0 = sem limite (S1/2/3). Sonic CD usa 16.
@export var max_fall_speed := 0.0
@export var jump_force := 6.5
@export var jump_release := 4.0
## true = clássico (o frame do pulo não move o personagem). false = estilo Mania.
@export var jump_frame_delay := true
## true = pode controlar no ar após pular rolando (Sonic CD / Mania).
@export var rolling_jump_air_control := false

@export_group("Tamanho")
@export var width_radius := 9.0
@export var height_radius := 19.0
@export var roll_width_radius := 7.0
@export var roll_height_radius := 14.0
@export var push_radius := 10.0

@export_group("Habilidades (loadout)")
## Scripts que extendem HarmonyAbility. O corpo cria um nó pra cada um
## automaticamente (e troca tudo junto se o profile mudar em runtime).
@export var ability_scripts: Array[Script] = []


# ---------------------------------------------------------------- reflexão
# Os "stats" são todas as variáveis numéricas/bool acima. É a lista que os
# modificadores aceitam (ex.: "top_speed", "gravity", "jump_force").

static var _stat_names: PackedStringArray = PackedStringArray()


static func stat_names() -> PackedStringArray:
	if _stat_names.is_empty():
		var tmp := HarmonyProfile.new()
		for prop in tmp.get_property_list():
			if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			if not (prop.type in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL]):
				continue
			if String(prop.name).begins_with("_"):
				continue
			_stat_names.append(prop.name)
	return _stat_names


static func has_stat(stat: StringName) -> bool:
	return stat_names().has(String(stat))


## Copia todos os stats (não o loadout) de outro profile pra este.
func copy_from(other: HarmonyProfile) -> void:
	for n in stat_names():
		set(n, other.get(n))
