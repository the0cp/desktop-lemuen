extends Node2D

signal movement_requested(velocity: Vector2)
signal clicked_on_character
signal right_clicked
signal state_changed(new_state_name)
signal drag_requested(delta_x)

enum State { RELAX, MOVE, SIT, SLEEP, INTERACT }
var current_state = State.RELAX
var direction = 1
var speed = 100.0

var click_count = 0
var last_click_time = 0
const CLICK_TIMEOUT = 500 

var is_dragging = false
var last_global_mouse_x = 0.0
var accumulated_drag = 0.0
const DRAG_THRESHOLD = 5.0

@onready var anim = $AnimatedSprite2D
@onready var timer = $Timer

func _ready():
	randomize()
	
	timer.one_shot = false
	timer.start()
	
	if anim.sprite_frames.has_animation("interact"):
		anim.sprite_frames.set_animation_loop("interact", false)
	
	_change_state(State.RELAX)
	$Area2D.input_pickable = true
	$Area2D.input_event.connect(_on_input_event)
	timer.timeout.connect(_on_timer_timeout)
	anim.animation_finished.connect(_on_anim_finished)

func _process(_delta):
	if is_dragging:
		var current_mouse_x = DisplayServer.mouse_get_position().x
		var diff = current_mouse_x - last_global_mouse_x
		
		if diff != 0:
			emit_signal("drag_requested", diff)
			last_global_mouse_x = current_mouse_x
			accumulated_drag += abs(diff)

	if current_state == State.MOVE:
		var velocity = Vector2(direction * speed, 0)
		emit_signal("movement_requested", velocity)

func _change_state(new_state):
	if current_state == State.INTERACT and new_state == State.INTERACT:
		anim.frame = 0
		anim.play("interact")
		return

	current_state = new_state
	
	emit_signal("state_changed", State.keys()[new_state])
	
	match current_state:
		State.RELAX: anim.play("relax")
		State.MOVE: 
			anim.play("move")
			_update_facing()
		State.SIT: anim.play("sit")
		State.SLEEP: anim.play("sleep")
		State.INTERACT: 
			anim.play("interact")
			timer.stop() 

func _update_facing():
	anim.flip_h = (direction == -1)

func turn_around():
	direction *= -1
	_update_facing()

func _on_timer_timeout():
	if current_state == State.INTERACT: return
	
	var rnd = randf()
	if rnd < 0.4: _change_state(State.RELAX)
	elif rnd < 0.7: _change_state(State.MOVE)
	elif rnd < 0.9: _change_state(State.SIT)
	else: _change_state(State.SLEEP)
	
	timer.wait_time = randf_range(3.0, 6.0)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Input.set_default_cursor_shape(Input.CURSOR_MOVE)
				
				is_dragging = true
				last_global_mouse_x = DisplayServer.mouse_get_position().x
				accumulated_drag = 0.0
				timer.stop()
				
				if current_state != State.INTERACT:
					_change_state(State.INTERACT)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				
				is_dragging = false
				timer.start()
				
				if accumulated_drag < DRAG_THRESHOLD:
					_handle_click_logic()
				else:
					_change_state(State.RELAX)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			emit_signal("right_clicked")

func _handle_click_logic():
	var current_time = Time.get_ticks_msec()
	
	if current_time - last_click_time < CLICK_TIMEOUT:
		click_count += 1
	else:
		click_count = 1 
		
	last_click_time = current_time
	
	var trigger_interact = false
	
	match current_state:
		State.SIT:
			if click_count >= 2: trigger_interact = true
		State.SLEEP:
			if click_count >= 3: trigger_interact = true
		State.INTERACT:
			trigger_interact = true 
		_: 
			trigger_interact = true
	
	if trigger_interact:
		click_count = 0 
		emit_signal("clicked_on_character")
		_change_state(State.INTERACT)

func _on_anim_finished():
	if current_state == State.INTERACT:
		_change_state(State.RELAX)
		timer.start()
