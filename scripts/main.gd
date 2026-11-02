extends Control

@onready var top_bar: Label = $TopBar/HBox/TimeLabel
@onready var lena_stats: Label = $TopBar/HBox/LenaStats
@onready var masha_stats: Label = $TopBar/HBox/MashaStats
@onready var log_box: RichTextLabel = $SidePanel/Margin/VBox/LogBox
@onready var action_menu: PanelContainer = $ActionMenu
@onready var action_list: VBoxContainer = $ActionMenu/Margin/VBox
@onready var character_container: Control = $CharacterContainer
@onready var room_row: HBoxContainer = $BottomBar/Margin/RoomRow

var state: GameState
var room_buttons := {}
var money_label: Label

const ROOM_SHORT := {
	"зал": "Зал", "комната_лены": "Лена", "комната_маши": "Маша",
	"ванная": "Ванная", "туалет": "Туалет", "кладовка": "Кладовка",
	"кухня": "Кухня", "моя_комната": "Моя", "работа": "Работа", "магазин": "Магазин",
}

func _ready():
	state = GameState.new()
	add_child(state)
	state.time_changed.connect(_refresh_all)
	state.log_added.connect(func(t): if log_box: log_box.append_text(t + "\n\n"))
	state.money_changed.connect(_update_money)
	if state.has_signal("midnight_reached"):
		state.midnight_reached.connect(_on_midnight)
	if action_menu: action_menu.visible = false
	var sp = $SidePanel/Margin/VBox
	if sp.has_node("CallRow/CallLena"): sp.get_node("CallRow/CallLena").pressed.connect(func(): state.call_char(state.lena); _refresh_all())
	if sp.has_node("CallRow/CallMasha"): sp.get_node("CallRow/CallMasha").pressed.connect(func(): state.call_char(state.masha); _refresh_all())
	if sp.has_node("RestRow/Rest1"): sp.get_node("RestRow/Rest1").pressed.connect(func(): state.add_log(state.rest(1)); _refresh_all())
	if sp.has_node("RestRow/Rest3"): sp.get_node("RestRow/Rest3").pressed.connect(func(): state.add_log(state.rest(3)); _refresh_all())
	if sp.has_node("RestRow/Rest8"): sp.get_node("RestRow/Rest8").pressed.connect(func(): state.add_log(state.rest(8, "спишь")); _refresh_all())
	if sp.has_node("GroupBtn"): sp.get_node("GroupBtn").pressed.connect(_show_group_actions)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 15)
	money_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	$TopBar/HBox.add_child(money_label)
	_update_money()
	_build_room_bar()
	_apply_ui()
	_refresh_all()
	state.add_log("Работа: 8ч=+1000. Магазин: покупки. Обе вместе → общие действия.")

func _apply_ui():
	var theme = Theme.new()
	var panel = _box(Color(0.07, 0.07, 0.09, 0.78), 14)
	var button = _box(Color(0.16, 0.16, 0.2, 0.94), 10)
	var hover = _box(Color(0.28, 0.2, 0.26, 0.98), 10)
	var pressed = _box(Color(0.45, 0.22, 0.32, 1), 10)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("normal", "Button", button)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_color("font_color", "Button", Color(0.96, 0.94, 0.95))
	theme.set_color("font_hover_color", "Button", Color(1, 0.92, 0.95))
	theme.set_font_size("font_size", "Button", 15)
	theme.set_color("default_color", "Label", Color(0.95, 0.93, 0.94))
	theme.set_color("default_color", "RichTextLabel", Color(0.9, 0.88, 0.9))
	set_theme(theme)
	$TopBar.offset_bottom = 58
	$CharacterContainer.offset_left = 0
	$CharacterContainer.offset_top = 64
	$CharacterContainer.offset_right = 0
	$CharacterContainer.offset_bottom = -92
	$SidePanel.offset_left = -280
	$SidePanel.offset_top = 66
	$SidePanel.offset_bottom = -100
	$BottomBar.offset_top = -84
	if action_menu:
		action_menu.custom_minimum_size = Vector2(280, 0)

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	return box

func _open_action_menu():
	action_menu.visible = true
	action_menu.set_anchors_preset(Control.PRESET_CENTER_TOP)
	action_menu.offset_left = -150
	action_menu.offset_right = 150
	action_menu.offset_top = 110
	action_menu.offset_bottom = 560
	action_menu.z_index = 30

func _update_money():
	if money_label: money_label.text = "%d" % state.money

func _build_room_bar():
	for c in room_row.get_children(): c.queue_free()
	room_buttons.clear()
	for loc in state.LOCATIONS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(104, 62)
		btn.toggle_mode = true
		btn.pressed.connect(_on_room.bind(loc))
		room_row.add_child(btn)
		room_buttons[loc] = btn
	_update_room_bar()

func _update_room_bar():
	for loc in state.LOCATIONS:
		if not room_buttons.has(loc): continue
		var btn: Button = room_buttons[loc]
		var people = state.get_people_in_location(loc)
		var icons = ""
		for p in people: icons += "🔴" if p.key == "lena" else "🔵"
		if icons == "": icons = "·"
		btn.text = ROOM_SHORT.get(loc, loc) + "\n" + icons
		btn.button_pressed = (loc == state.player_location)
		btn.modulate = Color(1.15, 1.1, 0.85) if loc == state.player_location else Color(1, 1, 1)

var stealth_mode: bool = false
var stealth_target: CharacterData = null
var kernel_hours: int = 0

func load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func load_bg(loc: String) -> Texture2D:
	return load_tex("res://assets/backgrounds/%s.png" % loc)

func load_char_tex(char: CharacterData) -> Texture2D:
	var key = char.get_image_key()
	var tex = load_tex("res://assets/characters/%s/%s.png" % [char.key, key])
	if tex == null:
		tex = load_tex("res://assets/characters/%s/normal.png" % char.key)
	return tex




func show_action_image(action_id: String, char: CharacterData):
	var path = "res://assets/characters/%s/action_%s.png" % [char.key, action_id]
	var tex = load_tex(path)
	if tex == null:
		# fallback to state image
		tex = load_char_tex(char)
	if tex == null:
		return
	var popup = Window.new()
	popup.title = "%s — %s" % [char.char_name, action_id]
	popup.size = Vector2i(520, 640)
	popup.unresizable = true
	add_child(popup)
	popup.popup_centered()
	var rect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(rect)
	var close = Button.new()
	close.text = "Закрыть"
	close.position = Vector2(210, 580)
	close.pressed.connect(func(): popup.queue_free())
	popup.add_child(close)

func _on_room(loc: String):
	if action_menu:
		action_menu.visible = false
	if loc in ["комната_лены", "комната_маши"]:
		var inside = state.get_people_in_location(loc)
		if inside.size() > 0 and state.player_location != loc:
			_show_door(loc, inside[0])
			return
	if state.night_locked() and loc != "моя_комната":
		state.add_log("Без кофе с полуночи до 7:00 ты не выходишь из комнаты.")
		_refresh_all()
		return
	var check = state.can_enter_room(loc)
	if not check["ok"]:
		state.add_log(check["reason"])
		_refresh_all()
		return
	state.player_location = loc
	state.add_log("→ " + loc)
	stealth_mode = false
	stealth_target = null
	if state.is_night() and loc == "моя_комната":
		state.add_log("Ночь. Пора спать, или выпей кофе.")
	_refresh_all()

func _activity_label(char: CharacterData) -> String:
	if char.is_asleep():
		return "спит"
	if char.location in ["комната_лены", "комната_маши"] and state.hour in [6, 7, 8, 21, 22]:
		return "переодевается"
	return "бодрствует"

func _show_door(loc: String, char: CharacterData):
	var popup = Window.new()
	popup.title = "Дверь"
	popup.size = Vector2i(380, 340)
	popup.unresizable = true
	add_child(popup)
	popup.popup_centered()
	var m = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 16)
	popup.add_child(m)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	var info = Label.new()
	info.text = "%s: %s\nTrust %d  ·  тревожность %d%%\nТы ещё снаружи." % [char.char_name, _activity_label(char), char.relation, char.anxiety]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)

	var b_peep = Button.new()
	b_peep.text = "Подсмотреть"
	b_peep.custom_minimum_size = Vector2(320, 36)
	b_peep.pressed.connect(func():
		popup.queue_free()
		_start_minigame("peep", 0, char)
	)
	v.add_child(b_peep)

	var b_in = Button.new()
	b_in.text = "Войти"
	b_in.custom_minimum_size = Vector2(320, 36)
	b_in.pressed.connect(func():
		popup.queue_free()
		_enter_room(loc, char, false)
	)
	v.add_child(b_in)

	var b_quiet = Button.new()
	b_quiet.text = "Войти тихо"
	b_quiet.custom_minimum_size = Vector2(320, 36)
	b_quiet.pressed.connect(func():
		popup.queue_free()
		_enter_room(loc, char, true)
	)
	v.add_child(b_quiet)

	var b_leave = Button.new()
	b_leave.text = "Уйти"
	b_leave.custom_minimum_size = Vector2(320, 36)
	b_leave.pressed.connect(func(): popup.queue_free())
	v.add_child(b_leave)

func _enter_room(loc: String, char: CharacterData, quiet: bool):
	if char.offended_days > 0 and not char.is_vulnerable():
		state.add_log("%s обижена и не пускает." % char.char_name)
		_refresh_all()
		return
	if not char.is_asleep() and not char.is_vulnerable() and char.relation < 40:
		state.add_log("%s не пускает. (Trust < 40)" % char.char_name)
		_refresh_all()
		return
	state.player_location = loc
	if quiet:
		stealth_mode = true
		stealth_target = char
		if char.is_asleep() and not char.is_vulnerable():
			var stress = 20 - int(char.relation / 8.0) - int(char.arousal / 15.0)
			stress = clampi(stress, 2, 25)
			char.change_anxiety(stress)
			state.add_log("Тихий вход. %s не проснулась. Тревожность +%d (%d%%)." % [char.char_name, stress, char.anxiety])
			if char.anxiety >= 100:
				state.kick_out(char)
				stealth_mode = false
				stealth_target = null
		else:
			state.add_log("Ты вошёл тихо. %s уже не спит." % char.char_name)
	else:
		stealth_mode = false
		stealth_target = null
		if char.is_asleep() and not char.is_vulnerable():
			char.set_state("бодрствует")
			char.has_blanket = true
			if char.clothes == "голая":
				char.set_clothes("домашняя")
			state.add_log("Ты вошёл. %s проснулась." % char.char_name)
			if char.relation < 40:
				char.change_anxiety(35)
				state.kick_out(char)
			elif char.relation < 55:
				char.change_anxiety(12)
				char.change_mood(-6)
				state.add_log("%s недовольна, что её разбудили." % char.char_name)
		elif char.is_vulnerable():
			state.add_log("%s не просыпается." % char.char_name)
		else:
			if char.state == "умывается":
				char.set_state("бодрствует")
			state.add_log("Ты вошёл к %s." % char.char_name)
	_refresh_all()

func _refresh_all():
	if top_bar: top_bar.text = "%s  %s  ·  %s" % [state.day.capitalize(), state.get_time_str(), state.get_period()]
	if lena_stats: lena_stats.text = _hud_line(state.lena)
	if masha_stats: masha_stats.text = _hud_line(state.masha)
	_update_money()
	_draw_scene()
	_update_room_bar()

func _hud_line(c: CharacterData) -> String:
	return "%s   T%d  Э%d  Г%d\n%s · %s" % [c.char_name, c.relation, c.energy, c.hunger, c.emotion, c.mood]

func _draw_scene():
	for c in character_container.get_children(): c.queue_free()
	# background
	var bg = load_bg(state.player_location) if has_method("load_bg") else null
	if bg and has_node("Background"):
		if $Background is TextureRect:
			$Background.texture = bg
		elif $Background is ColorRect:
			pass  # keep color fallback
	if state.player_location == "работа":
		_draw_work(); return
	if state.player_location == "магазин":
		_draw_shop(); return
	if state.player_location == "туалет":
		_draw_toilet(); return
	if state.player_location == "ванная":
		_draw_bathroom(); return
	if state.player_location == "моя_комната":
		_draw_my_room()
	_add_chore_button()
	var people = state.get_people_in_location(state.player_location)
	
	# Peep option for private bedrooms
	if state.player_location in ["комната_лены", "комната_маши"] and people.size() > 0:
		var peep_btn = Button.new()
		peep_btn.text = "Подсмотреть через дверь"
		peep_btn.position = Vector2(40, 420)
		peep_btn.custom_minimum_size = Vector2(220, 36)
		peep_btn.pressed.connect(func():
			var target = people[0]
			_start_minigame("peep", 0, target)
		)
		character_container.add_child(peep_btn)

	if people.is_empty():
		var p = PanelContainer.new(); p.position = Vector2(250, 140); p.custom_minimum_size = Vector2(300, 90)
		var l = Label.new(); l.text = "Никого нет\nПозови или смени комнату"; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l); character_container.add_child(p); return
	_place_sprites(people)

func _draw_my_room():
	var panel = PanelContainer.new()
	panel.position = Vector2(30, 40)
	panel.custom_minimum_size = Vector2(240, 140)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title = Label.new()
	title.text = "Твоя комната"
	v.add_child(title)
	var sleep_b = Button.new()
	sleep_b.text = "Спать до 7:00"
	sleep_b.pressed.connect(func():
		state.add_log(state.sleep_until_morning())
		_refresh_all()
	)
	v.add_child(sleep_b)
	var coffee_b = Button.new()
	var n = state.inventory.get("кофе", 0)
	coffee_b.text = "Выпить кофе (%d)" % n
	coffee_b.disabled = n <= 0
	coffee_b.pressed.connect(func():
		state.add_log(state.drink_player_coffee())
		_refresh_all()
	)
	v.add_child(coffee_b)
	if state.player_coffee:
		var on = Label.new()
		on.text = "Кофе действует."
		v.add_child(on)
	character_container.add_child(panel)

func _place_sprites(people: Array):
	var count = people.size()
	var i = 0
	for char in people:
		var btn = TextureButton.new()
		var tex = load_char_tex(char)
		if tex:
			btn.texture_normal = tex
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(280, 520)
		btn.size = Vector2(280, 520)
		var x = 620.0 if count == 1 else (380.0 + i * 260.0)
		btn.position = Vector2(x, -10)
		btn.pivot_offset = Vector2(140, 260)
		btn.modulate = _emotion_color(char.emotion)
		btn.pressed.connect(_show_char_menu.bind(char))
		character_container.add_child(btn)
		_play_emotion(btn, char, x)
		var name = Label.new()
		name.text = char.char_name
		name.position = Vector2(x + 80, 490)
		name.add_theme_font_size_override("font_size", 18)
		character_container.add_child(name)
		i += 1
	if count >= 2:
		var both = Button.new()
		both.text = "Обе вместе"
		both.position = Vector2(40, 40)
		both.pressed.connect(_show_group_actions)
		character_container.add_child(both)

func _emotion_color(emotion: String) -> Color:
	match emotion:
		"радость":
			return Color(1, 0.92, 0.55)
		"обида":
			return Color(0.75, 0.65, 0.8)
		"усталость":
			return Color(0.7, 0.78, 0.95)
		"голод":
			return Color(1, 0.78, 0.55)
		"дискомфорт":
			return Color(0.7, 0.9, 0.85)
		"раздражение":
			return Color(1, 0.65, 0.6)
		"спит":
			return Color(0.65, 0.65, 0.75)
		_:
			return Color(1, 1, 1)

func _play_emotion(btn: Control, char: CharacterData, x: float):
	var bubble = Label.new()
	bubble.text = char.emotion
	bubble.position = Vector2(x + 70, 24)
	bubble.add_theme_font_size_override("font_size", 20)
	bubble.add_theme_color_override("font_color", _emotion_color(char.emotion))
	bubble.modulate.a = 0.0
	character_container.add_child(bubble)
	var pop = bubble.create_tween()
	pop.tween_property(bubble, "modulate:a", 1.0, 0.25)
	pop.parallel().tween_property(bubble, "position:y", 8.0, 0.35)
	var bob = bubble.create_tween()
	bob.tween_interval(0.35)
	bob.set_loops()
	bob.tween_property(bubble, "position:y", 0.0, 0.7)
	bob.tween_property(bubble, "position:y", 14.0, 0.7)
	var pulse = btn.create_tween()
	pulse.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.28)
	pulse.tween_property(btn, "scale", Vector2.ONE, 0.28)

func _draw_toilet():
	var people = state.get_people_in_location("туалет")
	var panel = PanelContainer.new()
	panel.position = Vector2(180, 60)
	panel.custom_minimum_size = Vector2(440, 340)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title = Label.new()
	title.text = "ТУАЛЕТ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)

	if people.is_empty():
		var empty = Label.new()
		empty.text = "Никого нет."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(empty)
	else:
		for char in people:
			var info = Label.new()
			info.text = "%s внутри.\nTrust %d · Lust %d" % [char.char_name, char.relation, char.arousal]
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(info)

			# Always: peep keyhole
			var peep_btn = Button.new()
			peep_btn.text = "Подсмотреть в замочную скважину (мини-игра)"
			peep_btn.custom_minimum_size = Vector2(380, 40)
			peep_btn.pressed.connect(func():
				_start_minigame("peep", 0, char)
			)
			v.add_child(peep_btn)

			if char.is_asleep() or char.is_vulnerable():
				var locked = Label.new()
				locked.text = "Пока не в сознании — только подсмотреть."
				locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(locked)
			elif char.relation < 60:
				var locked = Label.new()
				locked.text = "Кнопка 1 откроется при Trust ≥ 60"
				locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(locked)
			else:
				_add_kernel_button(v, char, "Кнопка 1", "slot_1", 4, 6)
				if char.relation >= 80 and char.arousal >= 60:
					_add_kernel_button(v, char, "Кнопка 2", "slot_2", 6, 8)
				else:
					var next = Label.new()
					next.text = "Кнопка 2: Trust ≥ 80 и возбуждение ≥ 60"
					next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					v.add_child(next)

	var leave = Button.new()
	leave.text = "Уйти"
	leave.pressed.connect(func():
		state.player_location = "зал"
		state.add_log("→ зал")
		_refresh_all()
	)
	v.add_child(leave)
	character_container.add_child(panel)
	_add_chore_button()

func _add_chore_button():
	var job = state.chore_for(state.player_location)
	if job.is_empty():
		return
	var b = Button.new()
	b.text = "%s   +%d" % [job["name"], job["pay"]]
	b.position = Vector2(24, 78)
	b.custom_minimum_size = Vector2(230, 42)
	b.pressed.connect(func():
		state.add_log(state.do_chore(state.player_location))
		_refresh_all()
	)
	character_container.add_child(b)

func _add_kernel_button(box: VBoxContainer, char: CharacterData, title: String, slot: String, rel_gain: int, ar_gain: int):
	var b = Button.new()
	b.text = title
	b.custom_minimum_size = Vector2(380, 40)
	b.pressed.connect(func(): _run_kernel(char, slot, 1, rel_gain, ar_gain))
	box.add_child(b)

func _show_square(slot: String):
	if has_node("SlotPreview"):
		$SlotPreview.queue_free()
	var rect = TextureRect.new()
	rect.name = "SlotPreview"
	rect.texture = load_tex("res://assets/ui/%s.png" % slot)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(160, 160)
	rect.position = Vector2(40, 80)
	rect.z_index = 25
	character_container.add_child(rect)

func _draw_bathroom():
	var people = state.get_people_in_location("ванная")
	var panel = PanelContainer.new()
	panel.position = Vector2(180, 60)
	panel.custom_minimum_size = Vector2(440, 340)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title = Label.new()
	title.text = "ВАННАЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)
	if people.is_empty():
		var empty = Label.new()
		empty.text = "Никого нет."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(empty)
	else:
		for char in people:
			var info = Label.new()
			info.text = "%s в ванной.\nTrust %d · Lust %d · Тревожность %d%%" % [char.char_name, char.relation, char.arousal, char.anxiety]
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(info)
			var peep_btn = Button.new()
			peep_btn.text = "Подсмотреть (мини-игра)"
			peep_btn.custom_minimum_size = Vector2(380, 40)
			peep_btn.pressed.connect(func():
				_start_minigame("peep", 0, char)
			)
			v.add_child(peep_btn)
			if char.relation >= 65 or char.is_vulnerable():
				var enter_btn = Button.new()
				enter_btn.text = "Зайти (NSFW)"
				enter_btn.custom_minimum_size = Vector2(380, 40)
				enter_btn.pressed.connect(func():
					state.add_log("Ты входишь в ванную к %s..." % char.char_name)
					_show_char_menu(char)
				)
				v.add_child(enter_btn)
			else:
				var locked = Label.new()
				locked.text = "Зайти при Trust ≥ 65 или если уязвима"
				locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				locked.add_theme_color_override("font_color", Color(0.75, 0.7, 0.4))
				v.add_child(locked)
	var leave = Button.new()
	leave.text = "Уйти"
	leave.pressed.connect(func():
		state.player_location = "зал"
		state.add_log("→ зал")
		_refresh_all()
	)
	v.add_child(leave)
	character_container.add_child(panel)

func _draw_work():
	var panel = PanelContainer.new(); panel.position = Vector2(200, 80); panel.custom_minimum_size = Vector2(400, 260)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 12); panel.add_child(v)
	var t = Label.new(); t.text = "РАБОТА"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size", 22); v.add_child(t)
	var i = Label.new(); i.text = "Смена 8 часов · +1000"; i.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(i)
	var wb = Button.new(); wb.text = "Работать (8ч, +1000)"; wb.custom_minimum_size = Vector2(280, 44)
	wb.pressed.connect(func(): state.add_log(state.work()); _refresh_all()); v.add_child(wb)
	var lb = Button.new(); lb.text = "Уйти"; lb.pressed.connect(func(): state.player_location = "зал"; state.add_log("→ зал"); _refresh_all()); v.add_child(lb)
	character_container.add_child(panel)

func _draw_shop():
	var panel = PanelContainer.new(); panel.position = Vector2(140, 30); panel.custom_minimum_size = Vector2(500, 400)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 8); panel.add_child(v)
	var t = Label.new(); t.text = "МАГАЗИН"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size", 22); v.add_child(t)
	var bal = Label.new(); bal.text = "Деньги: %d" % state.money; bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(bal)
	v.add_child(HSeparator.new())
	for it in [["чай", 100, "Чай — потом в туалет"], ["кофе", 200, "Кофе — не спит ночью"], ["алкоголь", 300, "Алкоголь — пьянеет"], ["снотворное", 300, "Снотворное — крепкий сон"]]:
		var row = HBoxContainer.new()
		var lbl = Label.new(); lbl.text = "%s (%d)" % [it[2], it[1]]; lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(lbl)
		var buy = Button.new(); buy.text = "Купить"; buy.custom_minimum_size = Vector2(90, 32)
		buy.pressed.connect(func(): state.add_log(state.buy_item(it[0])); _refresh_all()); row.add_child(buy)
		v.add_child(row)
	v.add_child(HSeparator.new())
	var inv = Label.new()
	inv.text = "Инвентарь: чай %d | кофе %d | алк %d | снот %d" % [state.inventory.get("чай",0), state.inventory.get("кофе",0), state.inventory.get("алкоголь",0), state.inventory.get("снотворное",0)]
	inv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; inv.add_theme_font_size_override("font_size", 12); v.add_child(inv)
	var lb = Button.new(); lb.text = "Уйти"; lb.pressed.connect(func(): state.player_location = "зал"; state.add_log("→ зал"); _refresh_all()); v.add_child(lb)
	character_container.add_child(panel)

func _make_group_card() -> PanelContainer:
	var card = PanelContainer.new(); card.custom_minimum_size = Vector2(240, 180)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 8); card.add_child(v)
	var h = ColorRect.new(); h.custom_minimum_size = Vector2(240, 8); h.color = Color(0.5, 0.9, 0.5); v.add_child(h)
	var t = Label.new(); t.text = "ОБЕ ВМЕСТЕ"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size", 16); v.add_child(t)
	var bd = Button.new(); bd.text = "Общий диалог"; bd.pressed.connect(_start_group_dialog); v.add_child(bd)
	var ba = Button.new(); ba.text = "Действия с обеими"; ba.pressed.connect(_show_group_actions); v.add_child(ba)
	return card

func _make_char_card(char: CharacterData) -> PanelContainer:
	var card = PanelContainer.new(); card.custom_minimum_size = Vector2(220, 340)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 5); card.add_child(v)
	var h = ColorRect.new(); h.custom_minimum_size = Vector2(220, 8)
	h.color = Color(0.9, 0.35, 0.4) if char.key == "lena" else Color(0.35, 0.55, 0.95); v.add_child(h)
	var n = Label.new(); n.text = char.char_name; n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; n.add_theme_font_size_override("font_size", 18); v.add_child(n)
	var tr = Label.new(); tr.text = "Trust %d" % char.relation; tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tr)
	var lu = Label.new(); lu.text = "Lust %d" % char.arousal; lu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(lu)
	var cl = Label.new(); cl.text = char.clothes; cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cl.add_theme_color_override("font_color", Color(0.7,0.7,0.75)); v.add_child(cl)
	var st = Label.new(); st.text = char.state; st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(st)
	var sp = Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(sp)
	var btn = Button.new(); btn.text = "Действия"; btn.pressed.connect(_show_char_menu.bind(char)); v.add_child(btn)
	var ir = HBoxContainer.new()
	for ik in ["чай", "кофе", "алкоголь", "снотворное"]:
		if state.inventory.get(ik, 0) > 0:
			var ib = Button.new(); ib.text = ik.substr(0, 3); ib.custom_minimum_size = Vector2(46, 26)
			ib.pressed.connect(func(): state.add_log(state.offer_item(char, ik)); _refresh_all()); ir.add_child(ib)
	if ir.get_child_count() > 0: v.add_child(ir)
	card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _show_char_menu(char))
	return card

func _show_char_menu(char: CharacterData):
	if not action_menu or not action_list: return
	for c in action_list.get_children(): c.queue_free()
	var title = Label.new()
	title.text = char.char_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	action_list.add_child(title)
	var sub = Label.new()
	sub.text = "Trust %d  Lust %d  настр. %d · %s" % [char.relation, char.arousal, char.mood_value, char.emotion]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_list.add_child(sub)
	action_list.add_child(HSeparator.new())
	var asleep = char.is_asleep()
	if asleep:
		_add_action_button("Смотреть", func(): _execute_action("look", 0, char))
		_add_action_button("Разбудить", func(): _wake_character(char))
		var note = Label.new()
		note.text = "Остальные действия — в разработке,\nпока человек спит их нет."
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_list.add_child(note)
	else:
		_add_action_button("Смотреть", func(): _execute_action("look", 0, char))
		_add_action_button("Диалог", func(): _start_dialog(char))
		_add_action_button("Прикоснуться", func(): _affection(char, "touch"))
		_add_action_button("Поцеловать", func(): _affection(char, "kiss"))
		if char.relation >= 60:
			_add_action_button("Кнопка 1", func(): _run_kernel(char, "slot_1", 1, 4, 6))
		if char.relation >= 65 and char.arousal >= 45:
			_add_action_button("Кнопка 2", func(): _run_kernel(char, "slot_2", 2, 5, 8))
			_add_action_button("Кнопка 3", func(): _run_kernel(char, "slot_3", 2, 5, 8))
			_add_action_button("Кнопка 4", func(): _run_kernel(char, "slot_4", 2, 5, 8))
		elif char.relation >= 50:
			var h = Label.new()
			h.text = "Кнопки 2–4: Trust ≥ 65 и возбуждение ≥ 45"
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			action_list.add_child(h)
	var cb = Button.new()
	cb.text = "Закрыть"
	cb.pressed.connect(func(): action_menu.visible = false)
	action_list.add_child(cb)
	_open_action_menu()

func _add_action_button(text: String, cb: Callable):
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 32)
	b.pressed.connect(cb)
	action_list.add_child(b)

func _affection(char: CharacterData, kind: String):
	if action_menu:
		action_menu.visible = false
	state.add_log(_apply_affection(char, kind))
	if not stealth_mode:
		state.advance_time(1)
	_refresh_all()

func _apply_affection(char: CharacterData, kind: String) -> String:
	if char.is_asleep() or char.is_vulnerable():
		return "%s сейчас не в сознании. Сначала разбуди." % char.char_name
	if kind == "touch":
		if char.relation < 35:
			char.change_relation(-4)
			char.change_mood(-8)
			char.change_anxiety(10)
			return "%s отстраняется. Trust %d, настроение %d." % [char.char_name, char.relation, char.mood_value]
		char.change_relation(4)
		char.change_arousal(8)
		char.change_mood(5)
		char.change_anxiety(-4)
		return "%s не против. Trust %d, возбуждение %d, настроение %d." % [char.char_name, char.relation, char.arousal, char.mood_value]
	if char.relation < 50:
		char.change_relation(-2)
		char.change_mood(-6)
		char.change_anxiety(8)
		return "%s: «Рановато». Trust %d." % [char.char_name, char.relation]
	char.change_relation(6)
	char.change_arousal(12)
	char.change_mood(8)
	char.change_anxiety(-6)
	return "Поцелуй, %s. Trust %d, возбуждение %d, настроение %d." % [char.char_name, char.relation, char.arousal, char.mood_value]

func _wake_character(char: CharacterData):
	if action_menu:
		action_menu.visible = false
	if char.effects.get("deep_sleep", false) or char.drunk_level >= 2 or char.state == "отключка":
		state.add_log("%s слишком крепко спит и не просыпается." % char.char_name)
		char.change_anxiety(5)
		_refresh_all()
		return
	char.set_state("бодрствует")
	char.has_blanket = true
	if char.clothes == "голая":
		char.set_clothes("домашняя")
	char.effects["no_sleep_night"] = true
	stealth_mode = false
	if char.relation >= 60:
		char.change_relation(2)
		char.change_mood(6)
		char.anxiety = maxi(0, char.anxiety - 10)
		state.add_log("%s просыпается спокойно. «Что случилось?»" % char.char_name)
	elif char.relation >= 40:
		char.change_relation(-4)
		char.change_mood(-8)
		char.change_anxiety(12)
		state.add_log("%s просыпается недовольно. Trust -4, тревожность %d%%." % [char.char_name, char.anxiety])
	else:
		char.change_anxiety(30)
		state.add_log("%s просыпается злая." % char.char_name)
		state.kick_out(char)
	_refresh_all()

func _show_group_actions():
	if not action_menu or not action_list: return
	for c in action_list.get_children(): c.queue_free()
	var t = Label.new(); t.text = "Обе вместе"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size", 18); action_list.add_child(t)
	var both_awake = state.lena.state == "бодрствует" and state.masha.state == "бодрствует" and not state.lena.is_vulnerable() and not state.masha.is_vulnerable()
	if not both_awake:
		var n = Label.new()
		n.text = "Только когда обе бодрствуют."
		action_list.add_child(n)
	elif state.lena.relation >= 60 and state.masha.relation >= 60:
		_add_action_button("Кнопка обеих", func():
			_run_kernel(state.lena, "slot_1", 0, 4, 6)
			_run_kernel(state.masha, "slot_2", 1, 4, 6)
		)
		if state.lena.relation >= 80 and state.masha.relation >= 80 and state.lena.arousal >= 60 and state.masha.arousal >= 60:
			_add_action_button("Кнопка вместе", func():
				_run_kernel(state.lena, "slot_3", 0, 6, 8)
				_run_kernel(state.masha, "slot_4", 2, 6, 8)
			)
		else:
			var h = Label.new()
			h.text = "Вместе: у обеих Trust ≥ 80 и возбуждение ≥ 60"
			h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			action_list.add_child(h)
	else:
		var h2 = Label.new()
		h2.text = "Нужен Trust ≥ 60 у обеих."
		action_list.add_child(h2)
	var cb = Button.new(); cb.text = "Закрыть"; cb.pressed.connect(func(): action_menu.visible = false); action_list.add_child(cb)
	_open_action_menu()

func _start_group_dialog():
	var popup = Window.new(); popup.title = "Общий диалог"; popup.size = Vector2i(520, 360); popup.unresizable = true
	add_child(popup); popup.popup_centered()
	var m = MarginContainer.new(); m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]: m.add_theme_constant_override(s, 14)
	popup.add_child(m)
	var inner = VBoxContainer.new(); inner.add_theme_constant_override("separation", 8); m.add_child(inner)
	var tl = Label.new(); tl.text = "Лена и Маша смотрят на тебя. «Ну, чего хотел?»"; tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.custom_minimum_size = Vector2(480, 50); inner.add_child(tl)
	for opt in [
		{"text": "Предложить вместе посмотреть фильм", "rel": 5, "aru": 3, "resp": "Обе соглашаются. Вечер проходит тепло."},
		{"text": "Сказать, что обе сегодня красивые", "rel": 6, "aru": 10, "resp": "Лена усмехается, Маша краснеет."},
		{"text": "Намекнуть на совместный вечер", "rel": 4, "aru": 15, "resp": "Между ними пробегает взгляд. «Интересно...»"},
		{"text": "Просто поболтать", "rel": 4, "aru": 0, "resp": "Лёгкий разговор. Настроение лучше."},
	]:
		var b = Button.new(); b.text = opt["text"]; b.custom_minimum_size = Vector2(480, 36); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			state.lena.change_relation(opt["rel"]); state.masha.change_relation(opt["rel"])
			state.lena.change_arousal(opt["aru"]); state.masha.change_arousal(opt["aru"])
			state.lena.change_mood(opt["rel"]); state.masha.change_mood(opt["rel"])
			state.add_log("Ты: %s\n%s" % [opt["text"], opt["resp"]])
			state.add_log("(Trust %+d, Lust %+d обеим)" % [opt["rel"], opt["aru"]])
			state.advance_time(1); popup.queue_free(); _refresh_all()
		); inner.add_child(b)
	var cb = Button.new(); cb.text = "Закрыть"; cb.pressed.connect(func(): popup.queue_free()); inner.add_child(cb)

func _do_action(aid: String, hours: int, char: CharacterData):
	if stealth_mode and char.needs_stealth() and aid not in ["look", "dialog"]:
		_start_minigame(aid, hours, char)
		return
	_execute_action(aid, hours, char)

func _run_kernel(char: CharacterData, slot: String, hours: int, rel_gain: int, ar_gain: int):
	if action_menu:
		action_menu.visible = false
	if not char.is_up():
		state.add_log("%s не в сознании. Кнопка не сработала." % char.char_name)
		_refresh_all()
		return
	char.change_relation(rel_gain)
	char.change_arousal(ar_gain)
	char.change_mood(3)
	state.add_log("...")
	_open_time_lock(slot, hours)

func _open_time_lock(slot: String, hours: int):
	kernel_hours = maxi(kernel_hours, hours)
	if has_node("KernelLock"):
		return
	var lock = Control.new()
	lock.name = "KernelLock"
	lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock.mouse_filter = Control.MOUSE_FILTER_STOP
	lock.z_index = 50
	add_child(lock)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	lock.add_child(dim)
	var rect = TextureRect.new()
	rect.texture = load_tex("res://assets/ui/%s.png" % slot)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_preset(Control.PRESET_CENTER)
	rect.offset_left = -140
	rect.offset_right = 140
	rect.offset_top = -200
	rect.offset_bottom = 80
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.add_child(rect)
	var exit_btn = Button.new()
	exit_btn.text = "Выйти"
	exit_btn.set_anchors_preset(Control.PRESET_CENTER)
	exit_btn.offset_left = -90
	exit_btn.offset_right = 90
	exit_btn.offset_top = 110
	exit_btn.offset_bottom = 156
	exit_btn.pressed.connect(func():
		var h = kernel_hours
		kernel_hours = 0
		lock.queue_free()
		if h > 0:
			state.advance_time(h)
			state.add_log("[+%d ч] → %s" % [h, state.get_time_str()])
		_refresh_all()
	)
	lock.add_child(exit_btn)

func _execute_action(aid: String, hours: int, char: CharacterData):
	var r = ""
	match aid:
		"look": r = Interactions.look_at(char)
		"touch": r = Interactions.touch(char)
		"kiss": r = Interactions.kiss(char)
		"peep": r = Interactions.peep(char)
		"sleep": r = Interactions.sleep_together(char)
		"undress", "sex_m", "sex_d", "sex_c", "sex_o", "sex_s", "hand", "blanket", "wake_nsfw":
			if not char.is_up():
				r = "%s не в сознании." % char.char_name
			else:
				char.change_relation(4)
				char.change_arousal(6)
				r = "..."
				_open_time_lock("slot_1", hours)
				state.add_log(r)
				if action_menu:
					action_menu.visible = false
				return
	state.add_log(r)
	show_action_image(aid, char)
	if not stealth_mode and hours > 0:
		state.advance_time(hours)
		state.add_log("[+%d ч] → %s" % [hours, state.get_time_str()])
	if action_menu: action_menu.visible = false
	_refresh_all()

func _start_minigame(aid: String, hours: int, char: CharacterData):
	if action_menu: action_menu.visible = false
	var popup = Window.new()
	popup.title = "Скрытность!"
	popup.size = Vector2i(400, 320)
	popup.unresizable = true
	add_child(popup)
	popup.popup_centered()
	var layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(layer)
	var info = Label.new()
	info.text = "Кликни на кружок за 3 сек!\nТревожность: %d%%" % char.anxiety
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(20, 10)
	info.custom_minimum_size = Vector2(360, 50)
	layer.add_child(info)
	var circle = Button.new()
	circle.text = "●"
	circle.add_theme_font_size_override("font_size", 28)
	circle.custom_minimum_size = Vector2(64, 64)
	circle.position = Vector2(randi_range(40, 280), randi_range(80, 200))
	layer.add_child(circle)
	var done = [false]
	circle.pressed.connect(func():
		if done[0]: return
		done[0] = true
		popup.queue_free()
		state.add_log("✓ Успех! Действие выполнено тихо.")
		_execute_action(aid, 0, char)
	)
	get_tree().create_timer(3.0).timeout.connect(func():
		if done[0]: return
		done[0] = true
		popup.queue_free()
		char.change_anxiety(25)
		state.add_log("✗ Не успел! Тревожность %s: %d%%" % [char.char_name, char.anxiety])
		if char.anxiety >= 100:
			state.kick_out(char)
			stealth_mode = false
			stealth_target = null
		_refresh_all()
	)

func _start_dialog(char: CharacterData):
	if action_menu: action_menu.visible = false
	var dialog = Dialogues.get_random_dialog(char)
	_show_dialogue_box(char, dialog)

func _show_dialogue_box(char: CharacterData, dialog: Dictionary):
	if has_node("DialogueBox"):
		$DialogueBox.queue_free()
	var box = PanelContainer.new()
	box.name = "DialogueBox"
	box.z_index = 30
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 24
	box.offset_right = -24
	box.offset_top = -250
	box.offset_bottom = -96
	add_child(box)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var who = Label.new()
	who.text = char.char_name
	who.add_theme_font_size_override("font_size", 18)
	left.add_child(who)
	var tl = Label.new()
	tl.text = dialog["text"]
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(tl)
	var right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	for opt in dialog["options"]:
		var b = Button.new()
		b.text = opt["text"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			char.change_relation(opt["relation"])
			char.change_arousal(opt["arousal"])
			char.change_mood(opt["relation"] * 2)
			var reply = opt["response"]
			if int(opt["arousal"]) >= 8:
				reply = "..."
			state.add_log("Ты: %s\n%s: %s\n(Trust %+d, возбуждение %+d)" % [opt["text"], char.char_name, reply, opt["relation"], opt["arousal"]])
			state.advance_time(1)
			if is_instance_valid(box):
				box.queue_free()
			_refresh_all()
		)
		right.add_child(b)


func _on_midnight():
	var d = AcceptDialog.new()
	d.title = "Полночь"
	d.dialog_text = "Уже полночь. Пора спать, или выпей кофе, если хочешь сделать что-то ночью."
	add_child(d)
	d.popup_centered()
	d.confirmed.connect(func(): d.queue_free())
	d.canceled.connect(func(): d.queue_free())
