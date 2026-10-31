# Guia de Modding do Harmony

Como criar habilidades e mudar a física **sem mexer no núcleo** (`harmony_body.gd`).
Tudo aqui usa texto normal, tipo `"dash"` (nada de `&"dash"`).

---

## 1. As 4 peças

| Peça | O que é |
|---|---|
| **HarmonyBody** | O personagem. Roda a física. Você quase nunca edita. |
| **Profile** (`.tres`) | Os números base de um personagem (velocidade, pulo...) + a lista das habilidades dele. Um personagem = um `.tres`. |
| **Habilidade** (`HarmonyAbility`) | Um script que "pluga" no corpo e muda o que ele faz (spindash, pulo duplo, dash...). |
| **Mods** | Mudam um número da física **temporariamente** (power-up, água) e se desfazem sozinhos. |

---

## 2. Criar uma habilidade em 3 passos

1. **Duplique o molde:** no painel FileSystem do Godot, abra `framework/harmony/abilities/`, clique em `harmony_ability_template.gd`, `Ctrl+D` e renomeie (ex.: `harmony_ability_meu_dash.gd`).
2. **Edite.** O molde já é um dash no ar funcionando: mude os números, apague o que não quer, escreva o que precisa.
3. **Ative** de UM destes jeitos:
   - Arraste o script em **Ability Scripts** do `.tres` do personagem (jeito mais simples), ou
   - Adicione um `Node` filho do `HarmonyBody` e coloque o script nele, ou
   - Por código: `body.add_ability(preload("caminho/do/arquivo.gd"))`

Para tirar: `body.remove_ability(MeuScript)` (ou apague o nó / tire do `.tres`).

---

## 3. Receitas rápidas

### 3.1 Mudar um número da física (gravidade, pulo...)
- **Para sempre:** abra o `.tres` do personagem e mude no Inspector.
- **Temporário (por código):**
```gdscript
body.mod_mul(self, "gravity", 0.5)     # gravidade pela metade
body.mod_add(self, "jump_force", 1.0)  # pulo +1
body.mod_set(self, "top_speed", 12.0)  # força um valor
body.remove_mods(self)                 # desfaz tudo que `self` mudou
```
O primeiro argumento (`self`) é só "quem mudou", para você desfazer depois. Se digitar um stat que não existe, o console avisa.

### 3.2 Dar um impulso
```gdscript
body.ground_speed = 12.0 * body.facing   # NO CHÃO: mexa em ground_speed
body.velocity.x = 8.0 * body.facing      # NO AR: mexa em velocity
```
`body.facing` é `1` (direita) ou `-1` (esquerda).

### 3.3 Carregar e soltar (tipo Peel Out)
Veja `abilities/harmony_ability_peelout.gd`: é o exemplo mais simples. Dentro de `process_ground()` ele conta frames segurando ↑ e, ao soltar, define `ground_speed`.

### 3.4 Power-up com tempo (tipo Speed Shoes)
Veja `abilities/harmony_ability_speed_shoes.gd`: aplica vários mods de uma vez com `mod_mul_all(self, {...})`, conta frames no `post_step()` e desfaz com `remove_mods(self)`.

### 3.5 Área no nível (água, gelo...) sem código
Use um `HarmonyPhysicsZone` (veja `harmony_physics_zone.gd`): `Area2D` com um `CollisionShape2D`; no Inspector, em Modifiers, escolha o stat, a operação e o valor.

### 3.6 Trocar de personagem na hora
```gdscript
body.profile = preload("res://framework/profiles/tails.tres")
```
(As habilidades antigas saem e as do novo `.tres` entram sozinhas.)

---

## 4. Estados e animações (texto simples)

Dentro de uma habilidade:

```gdscript
set_state("air_dash")    # o animator toca a animação "air_dash" sozinho
clear_state()            # volta ao normal
is_state("air_dash")     # true/false
state_frames()           # frames desde que o estado começou
```

- **Nome do estado = nome da animação** no `SpriteFrames`. Quer outro nome? `set_state("carregando", "dash_charge")` toca `dash_charge`.
- Se a animação **não existir**, o animator tenta a parecida em `state_fallbacks` (Inspector do animator; ex.: `spindash` cai em `crouch`). Se também não existir, segue a lógica normal.
- Uma habilidade só limpa o estado que **ela mesma** definiu. Se ela sair/for desligada, o estado dela some.
- Para ler de fora: `body.custom_state` (texto, `""` = nenhum) e o sinal `body.custom_state_changed(old, new)`.
- O HUD de debug mostra o estado atual.

> Se você copiou o animator para outro personagem (ex.: `BFsprites.gd`), copie também o bloco `# 1. Estado de habilidade` de `harmony_animator.gd`.

---

## 5. Botões próprios

No `_init()` da habilidade:
```gdscript
func _init() -> void:
    button_name = "air_dash"        # nome do botão
    button_key = KEY_X              # tecla padrão
    button_joy = JOY_BUTTON_X       # botão de controle padrão
```
- O botão é **criado sozinho** no InputMap (se ainda não existir). Não precisa ir em Project Settings.
- Use `button_pressed()` (apertou neste frame) e `button_held()` (segurando).
- Se você já criou um botão com o mesmo nome em Project Settings, o seu é respeitado.
- Também dá para mudar `button_name/key/joy` no Inspector da habilidade.

---

## 6. Ganchos (hooks)

Escreva só os que precisar, com **exatamente** estes nomes.

| Gancho | Quando roda | Devolve |
|---|---|---|
| `process_ground()` | Todo frame no chão, **antes** da física | `true` = você cuida do frame todo (a física normal **não** roda) |
| `process_air()` | Todo frame no ar, antes da física | idem |
| `on_jump_pressed()` | Apertou pulo no chão | `true` = o pulo normal não acontece |
| `on_air_jump_pressed()` | Apertou pulo no ar (pulo duplo...) | `true` = você usou o aperto |
| `pre_step()` / `post_step()` | Todo frame, antes / depois da física | nada |
| `on_jumped()` | Acabou de pular | nada |
| `on_landed()` | Pousou | nada |
| `on_left_ground()` | Saiu do chão | nada |
| `on_roll_changed(rolling)` | Começou / parou de rolar | nada |
| `on_wall_hit(side)` | Bateu na parede (-1 esq., +1 dir.) | nada |
| `on_path_changed(path_id)` | Trocou de caminho A/B (loops) | nada |
| `on_stats_changed()` | `body.stats` foi recalculado | nada |
| `on_attached()` / `on_detached()` | Entrou / saiu do corpo | nada |
| `on_enabled_changed(enabled)` | Ligou / desligou (`enabled`) | nada |

Duas habilidades disputando o mesmo gancho `bool`: ganha a de maior `priority`.

---

## 7. O que você pode usar do `body`

| O quê | Para que serve |
|---|---|
| `body.velocity` | Velocidade em px/frame (x, y). **y positivo = para baixo.** |
| `body.ground_speed` | Velocidade ao longo do chão (só vale no chão) |
| `body.ground_angle` | Ângulo do chão em radianos (0 = plano) |
| `body.facing` | `1` direita, `-1` esquerda |
| `body.state` | `HarmonyBody.State.GROUND` ou `HarmonyBody.State.AIR` |
| `body.rolling`, `body.jumping` | Está rolando / em pulo (bola) |
| `body.control_lock` | Frames de controle travado (ladeira íngreme) |
| `body.input_left/right/up/down` | Direcionais segurados |
| `body.input_jump_pressed` / `input_jump_held` | Pulo apertado neste frame / segurado |
| `body.stats` | A física **efetiva** (base + mods). Só leia. |
| `body.force_roll(true/false)` | Forçar entrar/sair do rolamento |
| `body.add_ability(...)`, `remove_ability(...)`, `get_ability(Script)`, `has_ability(Script)` | Gerenciar habilidades |

---

## 8. Stats (os números que os mods aceitam)

Chão: `acceleration` `deceleration` `friction` `top_speed`
Rolar: `roll_friction` `roll_deceleration` `roll_min_speed` `unroll_speed` `roll_max_speed` `roll_slope_uphill` `roll_slope_downhill`
Ladeiras: `slope_factor` `slope_when_stopped` `slip_method` `slip_speed_threshold` `control_lock_frames`
Ar: `air_acceleration` `gravity` `max_fall_speed` `jump_force` `jump_release` `jump_frame_delay` `rolling_jump_air_control`
Tamanho: `width_radius` `height_radius` `roll_width_radius` `roll_height_radius` `push_radius`

Unidades: **pixels por frame**, 60 frames por segundo.

---

## 9. Erros comuns

1. **Impulso no chão que "não pega".** No chão a `velocity` é recalculada a partir de `ground_speed` todo frame. No chão mexa em `ground_speed`; no ar, em `velocity`.
2. **Física parou.** Devolver `true` em `process_ground()`/`process_air()` significa "eu cuido do frame todo". Se quer só dar um empurrão e deixar a física seguir, devolva `false`.
3. **Mudou o `profile` por código.** Não faça: ele é compartilhado entre todos que o usam. Use mods (`mod_mul`, `mod_add`, `mod_set`).
4. **Esqueceu de limpar.** Se a habilidade muda estado ou mods, limpe em `on_landed()` / `on_enabled_changed()` com `clear_state()` e `body.remove_mods(self)`.
5. **Nome de estado igual a uma animação do chão.** `"dash"` é a animação de correr rápido. Use nomes próprios (`"air_dash"`).
6. **Scripts antigos com `&"nome"`.** Ainda funcionam, mas use texto normal.

---

## 10. Usando IA para programar

Cole isto no começo da conversa para a IA seguir o padrão do projeto:

```
Projeto Godot 4 "Harmony" (física estilo Sonic). Regras:
- Leia framework/docs/MODDING.md antes de qualquer coisa.
- NUNCA edite harmony_body.gd para criar habilidade nova. Copie
  framework/harmony/abilities/harmony_ability_template.gd e extenda HarmonyAbility.
- Use texto normal ("dash"), nunca &"dash".
- Mudar física: body.mod_mul/mod_add/mod_set (nunca escreva em body.profile).
- No chão mexa em body.ground_speed; no ar, em body.velocity.
- Estado/animação: set_state("nome") / clear_state(). O nome do estado é o nome da animação.
- Botão próprio: button_name / button_key / button_joy no _init().
- Limpe estados e mods em on_landed() e on_enabled_changed().
```

Para conferir que nada quebrou, rode `framework/tests/smoke_test.tscn` e veja se tudo imprime `PASS`.
