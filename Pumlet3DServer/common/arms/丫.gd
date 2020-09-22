extends "res://common/arms/BaseHitscanWeapon.gd"



func init():
	fire_rate_default = 1
	reload_time_default = 2.5
	clip_size_default = 2
	clip_remaining = clip_size_default
	ammo_default = 10
	ammo_remaining = ammo_default
	fire_mode_settings = [
		{
			"pattern": {
				Vector3(0.7, 0, -0.3): 12,
				Vector3(0.7, 0, -0.35): 12,
				Vector3(0.7, 0.01, -0.3): 12,
				Vector3(0.7, 0.01, -0.35): 12,
				Vector3(0.7, -0.01, -0.3): 12,
				Vector3(0.7, -0.01, -0.35): 12,
			},
			"transform": null,
			"parameters": [],
			"range": 50,
			"damage_falloff": 0.2,
			"push_force_falloff": 0.3,
			"self_push_speed": 0.5,
			"self_push_ticks": 10,
			"target_push_speed": 0.1,
			"target_push_ticks": 10,
			"velocity_push_factor": 0.1
		},
		{
			"pattern": {
				Vector3(-0.7, 0, -0.3): 12,
				Vector3(-0.7, 0, -0.35): 12,
				Vector3(-0.7, 0.01, -0.3): 12,
				Vector3(-0.7, 0.01, -0.35): 12,
				Vector3(-0.7, -0.01, -0.3): 12,
				Vector3(-0.7, -0.01, -0.35): 12,
			},
			"transform": null,
			"parameters": [],
			"range": 50,
			"damage_falloff": 0.2,
			"push_force_falloff": 0.3,
			"self_push_speed": 0.5,
			"self_push_ticks": 10,
			"target_push_speed": 0.1,
			"target_push_ticks": 10,
			"velocity_push_factor": 0.1
		}]
