extends Control

@onready var log_box: RichTextLabel = $SidePanel/Margin/VBox/LogBox if has_node("SidePanel/Margin/VBox/LogBox") else null
@onready var action_menu: PanelContainer = $ActionMenu if has_node("ActionMenu") else null
@onready var action_list: VBoxContainer = $ActionMenu/Margin/VBox if has_node("ActionMenu/Margin/VBox") else null

var state: GameState
var bg_rect: TextureRect
var sprite_container: Control
var top_ui: Control

func _ready():
	_setup_ui_layers()

	state = GameState.new()
	add_child(state)
	state.time_changed.connect(_refresh_all)
	state.log_added.connect(func(t): if log_box: log_box.append_text(t + "\n\n"))
	state.midnight_alert.connect(_show_midnight_popup)

	_refresh_all()
	state.add_log("Добро пожаловать. Обрати внимание на действия.")

func _setup_ui_layers():
	bg_rect = TextureRect.new()
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg_rect)

	sprite_container = Control.new()
	sprite_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sprite_container)

	top_ui = Control.new()
	top_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(top_ui)

	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(20, 20)
	top_ui.add_child(top_bar)

	var time_lbl = Label.new()
	time_lbl.name = "TimeLabel"
	top_bar.add_child(time_lbl)

	if not action_menu:
		action_menu = PanelContainer.new()
		action_menu.position = Vector2(400, 150)
		action_menu.custom_minimum_size = Vector2(300, 400)
		action_menu.visible = false
		add_child(action_menu)

		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		action_menu.add_child(margin)

		action_list = VBoxContainer.new()
		action_list.add_theme_constant_override("separation", 8)
		margin.add_child(action_list)

func _refresh_all():
	if top_ui.has_node("HBoxContainer/TimeLabel"):
		top_ui.get_node("HBoxContainer/TimeLabel").text = "%s | %s" % [state.day.capitalize(), state.get_time_str()]

	_update_background()
	_draw_characters()

func _update_background():
	var loc_name = state.player_location
	var path_png = "res://assets/backgrounds/%s.png" % loc_name
	var path_jpg = "res://assets/backgrounds/%s.jpg" % loc_name

	if ResourceLoader.exists(path_png):
		bg_rect.texture = load(path_png)
	elif ResourceLoader.exists(path_jpg):
		bg_rect.texture = load(path_jpg)
	else:
		bg_rect.texture = null

func _draw_characters():
	for c in sprite_container.get_children():
		c.queue_free()

	var people = state.get_people_in_location(state.player_location)
	var x_pos = 150.0

	for char in people:
		var sprite = TextureRect.new()
		var img_key = char.get_image_key()
		var path = "res://assets/characters/%s/%s.png" % [char.key, img_key]

		if ResourceLoader.exists(path):
			sprite.texture = load(path)
		else:
			sprite.custom_minimum_size = Vector2(300, 500)
			var color = Color(0.9, 0.3, 0.4) if char.key == "lena" else Color(0.3, 0.5, 0.9)
			var rect = ColorRect.new()
			rect.color = color
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sprite.add_child(rect)

		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.position = Vector2(x_pos, 100)
		sprite.custom_minimum_size = Vector2(400, 600)
		sprite.mouse_filter = Control.MOUSE_FILTER_STOP

		sprite.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_char_menu(char)
		)

		sprite_container.add_child(sprite)
		x_pos += 350.0

func _show_char_menu(char: CharacterData):
	for c in action_list.get_children():
		c.queue_free()

	var title = Label.new()
	title.text = "%s (T:%d L:%d)" % [char.char_name, char.relation, char.arousal]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_list.add_child(title)
	action_list.add_child(HSeparator.new())

	var actions = [
		["Поговорить", "talk"],
		["Прикоснуться", "touch"],
		["Поцеловать", "kiss"]
	]

	if char.clothes != "голая":
		actions.append(["Раздеть", "undress"])

	if char.has_blanket and char.is_asleep():
		actions.append(["Снять одеяло", "remove_blanket"])

	if state.player_location in ["ванная", "туалет"]:
		actions.append(["Подсмотреть", "peep"])

	if char.is_asleep() and char.arousal >= 50:
		actions.append(["Действия во сне", "sleep_actions"])

	for act in actions:
		var btn = Button.new()
		btn.text = act[0]
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_action_pressed.bind(act[1], char))
		action_list.add_child(btn)

	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(func(): action_menu.visible = false)
	action_list.add_child(close_btn)

	action_menu.visible = true

func _on_action_pressed(action_id: String, char: CharacterData):
	action_menu.visible = false
	match action_id:
		"talk":
			char.change_relation(2)
			state.add_log("Ты поговорил с %s" % char.char_name)
		"touch":
			char.change_arousal(10)
			state.add_log("Ты прикоснулся к %s" % char.char_name)
		"kiss":
			char.change_arousal(15)
			state.add_log("Ты поцеловал %s" % char.char_name)
		"undress":
			char.set_clothes("голая")
			state.add_log("Ты раздел %s" % char.char_name)
		"remove_blanket":
			char.has_blanket = false
			state.add_log("Ты снял одеяло с %s" % char.char_name)
		"peep":
			_start_minigame("peep", char)
		"sleep_actions":
			char.change_arousal(20)
			state.add_log("Ты взаимодействовал со спящей %s" % char.char_name)

	_refresh_all()

func _start_minigame(action_id: String, char: CharacterData):
	var popup = Window.new()
	popup.title = "Скрытность"
	popup.size = Vector2i(300, 300)
	popup.unresizable = true
	add_child(popup)
	popup.popup_centered()

	var circle = Button.new()
	circle.text = "●"
	circle.add_theme_font_size_override("font_size", 32)
	circle.custom_minimum_size = Vector2(60, 60)
	circle.position = Vector2(randi_range(30, 210), randi_range(30, 210))
	popup.add_child(circle)

	var done = [false]
	circle.pressed.connect(func():
		if done[0]: return
		done[0] = true
		popup.queue_free()
		if action_id == "peep":
			state.add_log("Успех! Ты подсмотрел за %s." % char.char_name)
			char.change_arousal(15)
		_refresh_all()
	)

	get_tree().create_timer(2.5).timeout.connect(func():
		if done[0]: return
		done[0] = true
		popup.queue_free()
		char.change_anxiety(35)
		state.add_log("Провал! %s заметила. Тревожность: %d%%" % [char.char_name, char.anxiety])
		if char.anxiety >= 100:
			state.add_log("!!! %s разозлилась и выгнала тебя!" % char.char_name)
			char.anxiety = 0
			char.change_relation(-20)
			state.player_location = "зал"
		_refresh_all()
	)

func _show_midnight_popup():
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Уже полночь. Пора спать, или выпей кофе, если хочешь сделать что-то ночью."
	dialog.title = "Время спать"
	add_child(dialog)
	dialog.popup_centered()

func _ready():
	# 1. Создаем базовые слои (VN стиль)
	_setup_ui_layers()
	
	state = GameState.new()
	add_child(state)
	state.time_changed.connect(_refresh_all)
	state.log_added.connect(func(t): if log_box: log_box.append_text(t + "\n\n"))
	state.midnight_alert.connect(_show_midnight_popup)
	
	_refresh_all()
	state.add_log("Добро пожаловать. Используй меню комнат.")

func _setup_ui_layers():
	# Слой фона (Z-0)
	bg_rect = TextureRect.new()
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg_rect)
	
	# Слой спрайтов (Z-1)
	sprite_container = Control.new()
	sprite_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sprite_container)

	# Верхний UI (Время, Статы)
	top_ui = Control.new()
	top_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(top_ui)
	
	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(20, 20)
	top_ui.add_child(top_bar)
	
	var time_lbl = Label.new()
	time_lbl.name = "TimeLabel"
	top_bar.add_child(time_lbl)
	
	# Окно действий (по центру)
	if not action_menu:
		action_menu = PanelContainer.new()
		action_menu.position = Vector2(400, 150)
		action_menu.custom_minimum_size = Vector2(300, 400)
		action_menu.visible = false
		add_child(action_menu)
		
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		action_menu.add_child(margin)
		
		action_list = VBoxContainer.new()
		action_list.add_theme_constant_override("separation", 8)
		margin.add_child(action_list)

func _refresh_all():
	if top_ui.has_node("HBoxContainer/TimeLabel"):
		top_ui.get_node("HBoxContainer/TimeLabel").text = "%s | %s" % [state.day.capitalize(), state.get_time_str()]
	
	_update_background()
	_draw_characters()
	
func _update_background():
	var loc_name = state.player_location
	var path_png = "res://assets/backgrounds/%s.png" % loc_name
	var path_jpg = "res://assets/backgrounds/%s.jpg" % loc_name
	
	if ResourceLoader.exists(path_png):
		bg_rect.texture = load(path_png)
	elif ResourceLoader.exists(path_jpg):
		bg_rect.texture = load(path_jpg)
	else:
		bg_rect.texture = null

func _draw_characters():
	for c in sprite_container.get_children():
		c.queue_free()
		
	var people = state.get_people_in_location(state.player_location)
	var x_pos = 150.0
	
	for char in people:
		var sprite = TextureRect.new()
		var img_key = char.get_image_key()
		var path = "res://assets/characters/%s/%s.png" % [char.key, img_key]
		
		if ResourceLoader.exists(path):
			sprite.texture = load(path)
		else:
			# Заглушка если нет картинки
			sprite.custom_minimum_size = Vector2(300, 500)
			var color = Color(0.9, 0.3, 0.4) if char.key == "lena" else Color(0.3, 0.5, 0.9)
			var rect = ColorRect.new()
			rect.color = color
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sprite.add_child(rect)
			
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.position = Vector2(x_pos, 100)
		sprite.custom_minimum_size = Vector2(400, 600)
		sprite.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Клик по персонажу
		sprite.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_char_menu(char)
		)
		
		sprite_container.add_child(sprite)
		x_pos += 350.0

func _show_char_menu(char: CharacterData):
	for c in action_list.get_children():
		c.queue_free()
		
	var title = Label.new()
	title.text = "%s (T:%d L:%d)" % [char.char_name, char.relation, char.arousal]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_list.add_child(title)
	action_list.add_child(HSeparator.new())

	var actions = [
		["Поговорить", "talk"],
		["Прикоснуться", "touch"],
		["Поцеловать", "kiss"]
	]
	
	if char.clothes != "голая":
		actions.append(["Раздеть", "undress"])
		
	if char.has_blanket and char.is_asleep():
		actions.append(["Снять одеяло", "remove_blanket"])
		
	if state.player_location in ["ванная", "туалет"]:
		actions.append(["Подсмотреть", "peep"])
		
	if char.is_asleep() and char.arousal >= 50:
		actions.append(["Действия во сне", "sleep_actions"])

	for act in actions:
		var btn = Button.new()
		btn.text = act[0]
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_action_pressed.bind(act[1], char))
		action_list.add_child(btn)
		
	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(func(): action_menu.visible = false)
	action_list.add_child(close_btn)
	
	action_menu.visible = true

func _on_action_pressed(action_id: String, char: CharacterData):
	action_menu.visible = false
	match action_id:
		"talk":
			char.change_relation(2)
			state.add_log("Ты поговорил с %s" % char.char_name)
		"touch":
			char.change_arousal(10)
			state.add_log("Ты прикоснулся к %s" % char.char_name)
		"kiss":
			char.change_arousal(15)
			state.add_log("Ты поцеловал %s" % char.char_name)
		"undress":
			char.set_clothes("голая")
			state.add_log("Ты раздел %s" % char.char_name)
		"remove_blanket":
			char.has_blanket = false
			state.add_log("Ты снял одеяло с %s" % char.char_name)
		"peep":
			_start_minigame("peep", char)
		"sleep_actions":
			char.change_arousal(20)
			state.add_log("Ты взаимодействовал со спящей %s" % char.char_name)
			
	_refresh_all()

func _start_minigame(action_id: String, char: CharacterData):
	var popup = Window.new()
	popup.title = "Скрытность"
	popup.size = Vector2i(300, 300)
	popup.unresizable = true
	add_child(popup)
	popup.popup_centered()
	
	var circle = Button.new()
	circle.text = "●"
	circle.add_theme_font_size_override("font_size", 32)
	circle.custom_minimum_size = Vector2(60, 60)
	circle.position = Vector2(randi_range(30, 210), randi_range(30, 210))
	popup.add_child(circle)
	
	var done = [false]
	circle.pressed.connect(func():
		if done[0]: return
		done[0] = true
		popup.queue_free()
		if action_id == "peep":
			state.add_log("Успех! Ты подсмотрел за %s." % char.char_name)
			char.change_arousal(15)
		_refresh_all()
	)
	
	get_tree().create_timer(2.5).timeout.connect(func():
		if done[0]: return
		done[0] = true
		popup.queue_free()
		char.change_anxiety(35)
		state.add_log("Провал! %s заметила. Тревожность: %d%%" % [char.char_name, char.anxiety])
		if char.anxiety >= 100:
			state.add_log("!!! %s разозлилась и выгнала тебя!" % char.char_name)
			char.anxiety = 0
			char.change_relation(-20)
			state.player_location = "зал"
		_refresh_all()
	)

func _show_midnight_popup():
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Уже полночь. Пора спать, или выпей кофе, если хочешь сделать что-то ночью."
	dialog.title = "Время спать"
	add_child(dialog)
	dialog.popup_centered()