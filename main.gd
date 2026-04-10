extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D
@onready var ui_label = $UI/Instructions

func _ready():
	# Center camera on player
	camera.position_smoothing_enabled = true
	update_ui()
	print("main script loaded!")


func _process(_delta):
	# Camera follows player
	if player and camera:
		camera.global_position = player.global_position
	
	# Update UI every frame (or use signals for efficiency)
	update_ui()

func update_ui():
	if ui_label:
		var form_name = "W" if player.current_form == player.CharacterForm.FORM_W else "が"
		var transform_ready = "READY" if player.can_transform else "COOLDOWN"
		ui_label.text = "Form: %s | Press T to Transform [%s]" % [form_name, transform_ready]
