# Sonic Physics para Godot 4

Física do Sonic Physics Guide (Sonic Retro) em GDScript, modular. Testado no Godot 4.3.

## Arquivos
| Arquivo | Função |
|---|---|
| `sonic_player.gd` | Núcleo (extends **CharacterBody2D**). Física, sensores, estado, API pública. |
| `sonic_config.gd` | Recurso com as constantes (valores do Genesis). |
| `sonic_camera.gd` | Câmera do guia (bordas, foco, lag do spin dash). |
| `sonic_ability.gd` | Base das habilidades (ganchos). |
| `abilities/sonic_spindash.gd` | Spin dash, escrito como habilidade. |
| `sonic_animator.gd` | Liga o estado às animações (AnimatedSprite2D ou AnimationPlayer). |
| `sonic_audio.gd` | Sons a partir dos sinais do player. |

## Cena
```
Sonic (CharacterBody2D + sonic_player.gd)
├─ CollisionShape2D      ← define o tamanho do corpo (RectangleShape2D 19x39 = Genesis)
├─ AnimatedSprite2D
├─ AnimationPlayer
├─ Camera2D + sonic_camera.gd
├─ AudioStreamPlayer
├─ SonicSpindash         (Node com abilities/sonic_spindash.gd)
├─ SonicAnimator         (Node com sonic_animator.gd)
└─ SonicAudio            (Node com sonic_audio.gd)
```
- **Colisão:** os raios do corpo vêm do `CollisionShape2D` (Rectangle, Capsule ou Circle). Rectangle 19x39 dá width radius 9 e height radius 19. O shape é redimensionado sozinho ao rolar/pular (15x29). Os sensores usam a **collision_mask do próprio corpo** (Inspector > Collision > Mask): ponha o terreno numa layer que esteja na máscara. O corpo se exclui dos raios sozinho.
- **Escala:** a tela original é 320x224 e os valores são em pixels do Mega Drive. Em resolução maior, use viewport 320x224 com `stretch/mode = viewport` (veja o `project.godot`) ou `Camera2D.zoom`.
- **Config:** crie um `.tres` de `SonicConfig` e arraste no campo Config do player. `SonicConfig.sonic_2()` / `sonic_3k()` existem para uso por código. Para speed shoes/Super, troque com `player.set_config(outra_config)`.

## Estado, sinais e API
`player.state` (StringName): `idle run jump fall roll crouch look_up balance push hurt dead` + estados de habilidades (`spindash`). Sinal `state_changed(old, new)`.

Sinais: `jumped`, `landed`, `started_rolling`, `got_hurt`, `died`, `ability_event(nome, dado)`, `camera_lag_requested(frames)`.

Métodos: `hurt_from(x)`, `die()`, `launch(vx, vy)` (molas verticais), `spring_horizontal(speed, lock)`, `begin_roll()`, `snap_to_ground()`, `set_config()`, `get_ability(Script)`.

Campos úteis: `gsp xsp ysp ground_angle grounded rolling jumping crouching facing control_lock velocity`.

Entrada: actions `sonic_left/right/up/down/jump` são criadas sozinhas. Para IA/replay, `use_builtin_input = false` e preencha `input_*`/`jump_pressed`. **F3** liga/desliga o debug draw.

## Criando uma habilidade
Crie um script `extends SonicAbility` e adicione como filho do player. Ganchos (todos opcionais): `ground_step()`, `air_step()`, `try_jump()`, `on_landed()`, `on_hurt()`, `interrupt()`. Retornar `true` em `ground_step`/`air_step` = "cuidei deste frame" (o player pula a física normal). Use `player.custom_state = &"nome"` pra sobrescrever o estado (a animação de mesmo nome toca) e `player.ability_event.emit(&"evento", dado)` pra som/efeito.

```gdscript
class_name SonicPeelOut extends SonicAbility
func ground_step() -> bool:
	if player.looking_up and player.jump_pressed:
		# ...carregar, e no fim: player.gsp = 12.0 * player.facing; player.begin_roll()
		return true
	return false
```

## Animação e áudio
- `SonicAnimator`: nome da animação = nome do estado (mapeie com `animation_names`, ex.: `{"run": "walk"}`). Se a animação não existir usa a próxima do fallback (`fall→run`, `spindash→roll`...). Vira o sprite por `facing`, rotaciona com o terreno e acelera a animação com a velocidade.
- `SonicAudio`: arraste os sons (jump, roll, hurt, death, land). Sons de habilidades vão em `extra_sounds` (`spindash_charge`, `spindash_release`). O tom do spin dash sobe a cada aperto.

## Implementado
Corrida, ladeiras 360° (4 modos), slip/fall (S1/S2/CD e S3K), pulo variável, air drag, rolamento, agachar/olhar pra cima, balançar na borda, dano, morte, spin dash, câmera com lag. Diferenças do guia original estão em comentários do código (ângulo vem da normal do raycast; air drag = xsp/32).

## Teste
`godot --headless --path . -s test_headless.gd` roda a demo e imprime PASS/FAIL (corpo pelo CollisionShape2D, top speed, rolar, pulo, spin dash, câmera).
