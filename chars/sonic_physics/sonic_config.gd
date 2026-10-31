class_name SonicConfig
extends Resource
## Constantes de física do Sonic (Sonic Physics Guide / Sonic Retro).
## Unidades: pixels por frame a 60 Hz. O guia usa subpixels: 1 px = 256 spx.

@export_group("Corrida")
@export var acceleration := 12.0 / 256.0      ## 0.046875
@export var deceleration := 128.0 / 256.0     ## 0.5
@export var friction := 12.0 / 256.0          ## 0.046875
@export var top_speed := 6.0

@export_group("Rolamento")
@export var roll_friction := 6.0 / 256.0      ## metade do atrito normal
@export var roll_deceleration := 32.0 / 256.0
@export var roll_min_speed := 1.0             ## S2: 0.5 | S3K: 1.0
@export var unroll_speed := 0.5               ## S2: ~0 (só desenrola parado) | S3K: 0.5
@export var crouch_speed_limit := 1.0         ## agacha se |gsp| < isto (S2: ~0)
@export var roll_max_x_speed := 16.0          ## 0 = sem limite

@export_group("Ar")
@export var air_acceleration := 24.0 / 256.0
@export var gravity := 56.0 / 256.0           ## 0.21875
@export var hurt_gravity := 48.0 / 256.0
@export var jump_force := 6.5
@export var jump_release_cap := 4.0           ## soltar o pulo limita ysp a -4
@export var roll_jump_lock := true            ## pulo vindo do rolamento sem controle aéreo (S2/S3K). CD/Mania: false
@export var hurt_x_force := 2.0
@export var hurt_y_force := -4.0

@export_group("Ladeiras")
@export var slope_factor := 32.0 / 256.0      ## 0.125
@export var roll_uphill_slope_factor := 20.0 / 256.0
@export var roll_downhill_slope_factor := 80.0 / 256.0
@export var slip_speed_threshold := 2.5
@export var control_lock_frames := 30
@export var s3k_slope_rules := true           ## true: regras de slip/fall do S3K; false: S1/S2/CD
@export var snap_large_angle_change := true   ## comportamento dos jogos originais em quinas de tile

@export_group("Corpo (raios em px)")
@export var push_radius := 10.0
@export var width_radius := 9.0
@export var height_radius := 19.0
@export var roll_width_radius := 7.0
@export var roll_height_radius := 14.0

@export_group("Sensores")
@export var angle_steps := 256                ## quantiza o ângulo (256 = como o Mega Drive)


static func sonic_3k() -> SonicConfig:
	return SonicConfig.new()


static func sonic_2() -> SonicConfig:
	var c := SonicConfig.new()
	c.roll_min_speed = 0.5
	c.unroll_speed = 0.0001
	c.crouch_speed_limit = 0.0001
	c.s3k_slope_rules = false
	return c
