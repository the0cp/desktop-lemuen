extends Node2D

var window: Window
const BASE_WIDTH = 300 
const BASE_HEIGHT = 280 
const LINE_STEP = 10 
const MAX_DIALOG_HEIGHT = 70
const MIN_DIALOG_HEIGHT = 10

var fractional_overflow = Vector2.ZERO 

var polygon_cache = {} 
var last_frame_index = -1
var last_animation_name = ""
var last_flip_h = false
var last_ui_visible = false
var last_ui_size = Vector2.ZERO

var taskbar_height = 0 

var tray_icon: StatusIndicator
var context_menu: PopupMenu
var taskbar_hider_node = null

var dialog_panel: PanelContainer
var dialog_label: Label
var dialog_timer: Timer
var dialog_scroll: ScrollContainer
var scroll_tween: Tween 

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
	_setup_dialog_ui()

func _input(event):
	if dialog_panel.visible and dialog_panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				dialog_scroll.scroll_vertical -= LINE_STEP
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				dialog_scroll.scroll_vertical += LINE_STEP

func scroll_to_bottom():
	if scroll_tween and scroll_tween.is_valid() and scroll_tween.is_running():
		scroll_tween.kill()
	
	await get_tree().process_frame
	
	if dialog_scroll and is_instance_valid(dialog_scroll):
		var v_bar = dialog_scroll.get_v_scroll_bar()
		if v_bar and is_instance_valid(v_bar):
			var target_scroll = v_bar.max_value
			var current_scroll = dialog_scroll.scroll_vertical
			
			if abs(target_scroll - current_scroll) < 1.0:
				dialog_scroll.scroll_vertical = target_scroll
				return

			scroll_tween = create_tween()
			scroll_tween.set_ease(Tween.EASE_OUT)
			scroll_tween.set_trans(Tween.TRANS_QUAD)
			
			var duration = 2 + min(abs(target_scroll - current_scroll) / 100.0, 3.0) 

			scroll_tween.tween_property(dialog_scroll, "scroll_vertical", target_scroll, duration)
			await scroll_tween.finished

func _setup_system_tray():
	context_menu = PopupMenu.new()
	context_menu.add_item("Exit", 0)
	context_menu.id_pressed.connect(_on_menu_item_pressed)
	add_child(context_menu)
	
	tray_icon = StatusIndicator.new()
	add_child(tray_icon)
	
	var tex = load("res://icon.png")
	if tex:
		tray_icon.icon = tex
	
	tray_icon.tooltip = "Lemuen"
	tray_icon.menu = context_menu.get_path()

func _setup_dialog_ui():
	dialog_panel = PanelContainer.new()
	dialog_label = Label.new()
	dialog_timer = Timer.new()
	dialog_scroll = ScrollContainer.new()
	
	dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var empty_style = StyleBoxFlat.new()
	empty_style.set_bg_color(Color(0, 0, 0, 0))
	empty_style.content_margin_top = 0
	empty_style.content_margin_bottom = 0
	empty_style.content_margin_left = 0
	empty_style.content_margin_right = 0
	
	dialog_scroll.add_theme_stylebox_override("scroll_v", empty_style)
	dialog_scroll.add_theme_stylebox_override("scroll_h", empty_style)
	
	dialog_scroll.add_theme_stylebox_override("grabber", empty_style)
	dialog_scroll.add_theme_stylebox_override("grabber_pressed", empty_style)
	dialog_scroll.add_theme_stylebox_override("grabber_highlight", empty_style)
	
	dialog_scroll.add_theme_constant_override("grabber_min_size", 0)
	dialog_scroll.add_theme_constant_override("scroll_v_separation", 0)
	
	add_child(dialog_panel)
	dialog_panel.add_child(dialog_scroll)
	dialog_scroll.add_child(dialog_label)
	add_child(dialog_timer)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	dialog_panel.add_theme_stylebox_override("panel", style)
	
	dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	dialog_panel.visible = false
	
	dialog_timer.one_shot = true
	dialog_timer.timeout.connect(func(): dialog_panel.visible = false)

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
	var quotes = [
		"ドクター、この部屋を執務室にする時にちゃんと調べたの？あなたを狙撃できる場所が船上に一ヶ所あるわよ。どこって？教えてあげたら、そこを私のプライベートルームにしてくれる？",
		"こんなに長く一緒に働いてきたのに、どうして今日までこの儀式を先送りにしてたの？忙しすぎて手が回らなかったのなら、私を頼ってくれればよかったのに。",
		"紹介はいい。各員の情報はインプット済みよ。",
		"ドクター、今日はどんなところに行ってきたの？",
		"患者の収容に関する規定の再検討に、医薬品の共同開発に関する書類へのサインもお願い。移動区画の引き渡しに関しては私の提案をもう一度見直して……えっ、笑顔が怖い？そう思ったなら、頑張ってさっさと仕事を終わらせないとね？",
		"部屋間違いじゃないわ、ここがあなたの執務室よ。リフォームに加えて、ピストルクラッカーと聖典プロジェクターボールもおまけに付けておいたからね。エルが銃でポップコーンを作ろうとして執務室を爆破したからだろって……それはそうだけど、ラテラーノでは「痕跡の残ってない爆発はノーカウント」って言葉があるの。",
		"私の署名を見つけた？ああ、『植物学総論』ね。確かに寄稿したわ。仕事でじゃなくて、寝たきりの間に色んなお花が届きすぎたからかな。モスティマが一番バタバタしてた時なんか、花の咲いたジャガイモまで持ってくる始末だったのよ。そうやっていつも花に囲まれてたから、詳しくならない方が難しいでしょ。",
		"手の擦り傷？ああ、何人か小突いただけよ。外回りで出会う人がみんな怪我人を思い遣ってくれるとは限らないでしょう。それでフィアメッタがカンカンに怒っちゃったから、私も「ほどほどに」懲らしめてあげたの。私がなんとも思わなくたって、友達にまで気にするなって無理強いはできないからね。",
		"枢機卿の業務ガイドはアップルパイ三つ分くらい分厚いけど、実際やってみたらそんなに複雑じゃないのよ。ラテラーノに来たばかりの人が順応できてるかとか、修道院にいる人への安全配慮は行き届いてるのかとかの確認くらいで……ほら、こういうのがなければ、今のラテラーノをラテラーノたらしめてるものがなくなっちゃうでしょ？",
		"アイスミルクよし、りんごの気付け薬よし、アイマスクも耳栓も全部よし。そろそろ入場だからちゃんと持っていってね。私の好きな映画が気になるって言ったのはそっちでしょ。『聖戒破壊者』シリーズはどれも最高だけど、万が一あなたにスプラッター耐性がなかった場合に備えとかないと、でしょ？",
		"目を逸らさなくてもいいのよ、ドクター。車椅子からまだ離れられないのは事実だし、すぐには癒えない傷だってあるけど……どうしても可哀想に思うのなら、自律作業プラットフォームの使用権限を全部私に解放してくれない？移動用かレース用かって？それはまあいいじゃない。",
		"人の視線には敏感なの？ごめんなさい、常に周りの人を観察するのがクセになっちゃってて。じっくり観察してやっと、その人を排除しないといけない理由、あるいは守るべき理由が見えてくるの。自分はどちら側か気になる？安心して仕事に打ち込んでいいわよ、ドクター。",
		"ん？ただこの窓に落ちた影を眺めてただけ。寝たきりの時期にできた習慣みたいなものよ。この影、何に見えると思う？",
		"はじめまして、ドクター。私のことはレミュアンでいいわ。さて、まずは第七庁の枢機卿と仕事の話をするか、それともエルの姉にあの子の職場を案内するか、どちらを選ぶかはあなた次第よ。",
		"このシーン、流血表現をカットしちゃってるわよね？"
	]
	
	var txt = quotes.pick_random()
	dialog_label.text = txt
	
	dialog_label.add_theme_font_size_override("font_size", 12)
	dialog_label.custom_minimum_size.x = 220
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	dialog_panel.size = Vector2.ZERO
	await get_tree().process_frame 
	
	dialog_label.set_deferred("size", Vector2.ZERO)
	await get_tree().process_frame 
	await get_tree().process_frame 
	
	var required_height = dialog_label.get_minimum_size().y
	
	var final_height = max(required_height, MIN_DIALOG_HEIGHT) 
	final_height = min(final_height, MAX_DIALOG_HEIGHT)
	
	var style: StyleBoxFlat = dialog_panel.get_theme_stylebox("panel")
	var style_margin_y = style.content_margin_top + style.content_margin_bottom
	
	dialog_panel.custom_minimum_size.y = final_height + style_margin_y
	
	dialog_panel.position.x = (BASE_WIDTH - dialog_panel.size.x) / 2.0
	dialog_panel.position.y = 20
	
	dialog_scroll.scroll_vertical = 0
	
	dialog_panel.visible = true
	await get_tree().process_frame 
	await scroll_to_bottom()
	
	dialog_timer.start(3.5)
	
func _on_pet_right_clicked():
	if context_menu:
		context_menu.position = Vector2i(DisplayServer.mouse_get_position())
		context_menu.popup()

func _on_pet_state_changed(_state_name):
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
	
	var is_ui_visible = false
	var ui_size = Vector2.ZERO
	if dialog_panel and dialog_panel.visible:
		is_ui_visible = true
		ui_size = dialog_panel.size
		
	if anim_sprite.frame == last_frame_index and anim_sprite.animation == last_animation_name and anim_sprite.flip_h == last_flip_h and is_ui_visible == last_ui_visible and ui_size == last_ui_size:
		return
		
	last_frame_index = anim_sprite.frame
	last_animation_name = anim_sprite.animation
	last_flip_h = anim_sprite.flip_h
	last_ui_visible = is_ui_visible
	last_ui_size = ui_size
	
	var cache_key = last_animation_name + str(last_frame_index) + str(last_flip_h) + str(last_ui_visible) + str(last_ui_size)
	
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

	if is_ui_visible:
		var r = dialog_panel.get_rect()
		all_points.append(r.position)
		all_points.append(r.position + Vector2(r.size.x, 0))
		all_points.append(r.position + r.size)
		all_points.append(r.position + Vector2(0, r.size.y))

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
