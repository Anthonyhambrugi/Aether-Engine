class_name HarmonyStatMod
extends RefCounted
## Um modificador de stat de física (power-up, zona de água, debuff...).
## Você quase nunca instancia isso direto — use os atalhos do HarmonyBody:
##
##   body.mod_mul(self, "top_speed", 2.0)          # dobra a top speed
##   body.mod_add(self, "gravity", -0.1)           # soma
##   body.mod_set(self, "slope_when_stopped", false)  # força um valor
##   body.mod_mul_all(self, {"top_speed": 2.0, "acceleration": 2.0})
##   body.remove_mods(self)                         # desfaz tudo da fonte
##
## `source` é qualquer coisa que identifique QUEM aplicou (o próprio nó da
## habilidade, uma String como "agua"...). Serve só pra você desfazer depois
## com remove_mods(source). Habilidades têm os mods removidos sozinhos
## quando saem do corpo.
##
## Como vários mods no mesmo stat se combinam:
##   valor = (base + soma dos ADD) * produto dos MULT
##   se existir algum SET, ganha o de maior `priority` (empate: o mais novo)
## Pra bool/enum só SET faz sentido (ADD/MULT são ignorados).

enum Op { ADD, MULT, SET }

var source: Variant
var stat: StringName
var op: Op = Op.MULT
var value: Variant = 1.0
var priority := 0


func _init(p_source: Variant = null, p_stat: String = "", p_op: Op = Op.MULT, p_value: Variant = 1.0, p_priority := 0) -> void:
	source = p_source
	stat = StringName(p_stat)
	op = p_op
	value = p_value
	priority = p_priority
