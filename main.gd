extends Node2D

var window: Window
const BASE_WIDTH = 300 
const BASE_HEIGHT = 200

var fractional_overflow = Vector2.ZERO 

var polygon_cache = {} 
var last_frame_index = -1
var last_animation_name = ""
var last_flip_h = false

var taskbar_height = 0 

var tray_icon: StatusIndicator
var context_menu: PopupMenu
var taskbar_hider_node = null

@onready var pet = $LemuenPet

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	
	window = get_window()
	
	get_viewport().transparent_bg = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, 0)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true, 0)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, 0)
	
	var current_screen = DisplayServer.window_get_current_screen()
	var screen_rect = DisplayServer.screen_get_size(current_screen)
	var work_rect = DisplayServer.screen_get_usable_rect(current_screen)
	
	taskbar_height = screen_rect.y - work_rect.end.y
	
	var final_width = BASE_WIDTH
	var final_height = BASE_HEIGHT + taskbar_height
	
	window.size = Vector2i(final_width, final_height)
	
	var target_x = work_rect.end.x - final_width - 50
	var target_y = screen_rect.y - final_height
	
	window.position = Vector2i(target_x, target_y)
	
	pet.position = Vector2(final_width / 2.0, BASE_HEIGHT)
	
	if not pet.movement_requested.is_connected(_on_pet_movement_requested):
		pet.movement_requested.connect(_on_pet_movement_requested)
	
	if not pet.clicked_on_character.is_connected(_on_pet_clicked):
		pet.clicked_on_character.connect(_on_pet_clicked)
	
	if not pet.state_changed.is_connected(_on_pet_state_changed):
		pet.state_changed.connect(_on_pet_state_changed)
	
	if not pet.right_clicked.is_connected(_on_pet_right_clicked):
		pet.right_clicked.connect(_on_pet_right_clicked)

	if not pet.has_user_signal("drag_requested"):
		pet.add_user_signal("drag_requested")
	
	if not pet.drag_requested.is_connected(_on_pet_drag_requested):
		pet.drag_requested.connect(_on_pet_drag_requested)

	taskbar_hider_node = get_node_or_null("TaskbarManager")
	_setup_system_tray()

func _setup_system_tray():
	context_menu = PopupMenu.new()
	context_menu.add_item("Exit", 0)
	context_menu.id_pressed.connect(_on_menu_item_pressed)
	add_child(context_menu)
	
	tray_icon = StatusIndicator.new()
	add_child(tray_icon)
	
	var anim_sprite = pet.get_node("AnimatedSprite2D")
	if anim_sprite and anim_sprite.sprite_frames.has_animation("relax"):
		tray_icon.icon = anim_sprite.sprite_frames.get_frame_texture("relax", 0)
	
	tray_icon.tooltip = "Lemuen"
	tray_icon.menu = context_menu.get_path()

func _on_menu_item_pressed(id):
	if id == 0:
		get_tree().quit()

func _process(_delta):
	_update_passthrough_region_precise()

func _on_pet_movement_requested(velocity: Vector2):
	var delta = get_process_delta_time()
	
	var frame_movement = velocity * delta
	fractional_overflow += frame_movement
	var pixel_step = Vector2i(fractional_overflow)
	
	if pixel_step != Vector2i.ZERO:
		window.position += pixel_step
		fractional_overflow -= Vector2(pixel_step)
		
		var current_screen = DisplayServer.window_get_current_screen()
		var work_rect = DisplayServer.screen_get_usable_rect(current_screen)
		
		if window.position.x > work_rect.end.x - BASE_WIDTH:
			if velocity.x > 0: 
				pet.turn_around()
		elif window.position.x < work_rect.position.x:
			if velocity.x < 0: 
				pet.turn_around()

func _on_pet_drag_requested(delta_x):
	if window:
		var new_pos = window.position
		new_pos.x += int(delta_x)
		
		var current_screen = DisplayServer.window_get_current_screen()
		var work_rect = DisplayServer.screen_get_usable_rect(current_screen)
		
		if new_pos.x < work_rect.position.x - BASE_WIDTH + 50:
			new_pos.x = work_rect.position.x - BASE_WIDTH + 50
		elif new_pos.x > work_rect.end.x - 50:
			new_pos.x = work_rect.end.x - 50
			
		window.position = new_pos

func _on_pet_clicked():
	pass
	
func _on_pet_right_clicked():
	if context_menu:
		context_menu.position = Vector2i(DisplayServer.mouse_get_position())
		context_menu.popup()

func _on_pet_state_changed(state_name):
	if state_name == "SIT":
		if window:
			pass

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if taskbar_hider_node and taskbar_hider_node.has_method("EnforceToolWindowStyle"):
			taskbar_hider_node.EnforceToolWindowStyle()

func _update_passthrough_region_precise():
	if not is_instance_valid(pet):
		return

	var anim_sprite = pet.get_node_or_null("AnimatedSprite2D")
	if not anim_sprite or not anim_sprite.sprite_frames:
		return
		
	if anim_sprite.frame == last_frame_index and anim_sprite.animation == last_animation_name and anim_sprite.flip_h == last_flip_h:
		return
		
	last_frame_index = anim_sprite.frame
	last_animation_name = anim_sprite.animation
	last_flip_h = anim_sprite.flip_h
	
	var cache_key = last_animation_name + str(last_frame_index) + str(last_flip_h)
	
	if polygon_cache == null:
		polygon_cache = {}
	
	if polygon_cache.has(cache_key):
		DisplayServer.window_set_mouse_passthrough(polygon_cache[cache_key])
		return
	
	var frame_tex = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
	if not frame_tex:
		return
	
	var img = frame_tex.get_image()
	if not img:
		return
		
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(img)
	
	var polygons = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, img.get_size()), 0.01)
	
	if polygons.size() == 0:
		return
		
	var all_points = PackedVector2Array()
	
	var center_pos = pet.position + anim_sprite.position
	var tex_size = Vector2(img.get_width(), img.get_height())
	var offset_vec = Vector2.ZERO
	if anim_sprite.centered:
		offset_vec -= tex_size / 2.0
	offset_vec += anim_sprite.offset
	var scale_vec = anim_sprite.scale
	
	for poly in polygons:
		for point in poly:
			var transformed_point = point
			if anim_sprite.flip_h:
				transformed_point.x = tex_size.x - transformed_point.x
			transformed_point += offset_vec
			transformed_point *= scale_vec
			transformed_point += center_pos
			all_points.append(transformed_point)
			
	if all_points.size() == 0:
		return

	var hull_points = Geometry2D.convex_hull(all_points)
	var dilated_polygons = Geometry2D.offset_polygon(hull_points, 3.0)
	
	var final_polygon = PackedVector2Array()
	
	if dilated_polygons.size() > 0:
		final_polygon = dilated_polygons[0]
	else:
		final_polygon = hull_points
		
	DisplayServer.window_set_mouse_passthrough(final_polygon)
	polygon_cache[cache_key] = final_polygon
