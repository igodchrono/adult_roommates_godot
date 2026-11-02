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
	_refresh_all()
	state.add_log("Работа: 8ч=+1000. Магазин: покупки. Обе вместе → общие действия.")

func _update_money():
	if money_label: money_label.text = "  💰 %d" % state.money

func _build_room_bar():
	for c in room_row.get_children(): c.queue_free()
	room_buttons.clear()
	for loc in state.LOCATIONS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(95, 78)
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
	var check = state.can_enter_room(loc)
	if not check["ok"]:
		state.add_log(check["reason"])
		_refresh_all()
		return
	state.player_location = loc
	state.add_log("→ " + loc)
	if action_menu: action_menu.visible = false

	var people = state.get_people_in_location(loc)
	var sleeper: CharacterData = null
	for p in people:
		if p.is_asleep():
			sleeper = p
			break

	if check.get("stealth", false) or (sleeper != null and sleeper.needs_stealth()):
		stealth_mode = true
		stealth_target = sleeper if sleeper else (people[0] if people.size() > 0 else null)
		state.add_log(check.get("reason", "Осторожно..."))
		_refresh_all()
		if stealth_target:
			_show_sleep_choices(stealth_target)
		return

	stealth_mode = false
	stealth_target = null
	if state.is_night() and loc == "моя_комната":
		state.add_log("🌙 Ночь. Пора спать... Или выпей кофе и рискни зайти к ним.")
	_refresh_all()

func _show_sleep_choices(char: CharacterData):
	var popup = Window.new()
	popup.title = char.char_name + " спит"
	popup.size = Vector2i(360, 280)
	popup.unresizable = true
	add_child(popup)
	popup.popup_centered()

	var m = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 16)
	popup.add_child(m)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	var info = Label.new()
	info.text = "%s спит.\nТревожность: %d%%\nЧто сделать?" % [char.char_name, char.anxiety]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)

	var b_wake = Button.new()
	b_wake.text = "Разбудить"
	b_wake.custom_minimum_size = Vector2(300, 40)
	b_wake.pressed.connect(func():
		popup.queue_free()
		if char.can_wake_for_nsfw() or char.is_vulnerable():
			char.set_state("бодрствует")
			state.add_log("Ты будишь %s..." % char.char_name)
			stealth_mode = false
			_show_char_menu(char)
		else:
			# Risky wake — mini-game or fail
			state.add_log("Пытаешься разбудить осторожно...")
			_start_minigame("wake_nsfw", 1, char)
	)
	v.add_child(b_wake)

	var b_undress = Button.new()
	b_undress.text = "Раздеть"
	b_undress.custom_minimum_size = Vector2(300, 40)
	b_undress.pressed.connect(func():
		popup.queue_free()
		if char.is_vulnerable():
			_execute_action("undress", 0, char)
		else:
			_start_minigame("undress", 0, char)
	)
	v.add_child(b_undress)

	var b_leave = Button.new()
	b_leave.text = "Уйти"
	b_leave.custom_minimum_size = Vector2(300, 40)
	b_leave.pressed.connect(func():
		popup.queue_free()
		stealth_mode = false
		stealth_target = null
		state.player_location = "зал"
		state.add_log("Ты тихо уходишь. → зал")
		_refresh_all()
	)
	v.add_child(b_leave)

func _refresh_all():
	if top_bar: top_bar.text = "%s   %s   (%s)" % [state.day.capitalize(), state.get_time_str(), state.get_period()]
	if lena_stats: lena_stats.text = state.lena.status_short()
	if masha_stats: masha_stats.text = state.masha.status_short()
	_update_money()
	_draw_scene()
	_update_room_bar()

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
		btn.pressed.connect(_show_char_menu.bind(char))
		character_container.add_child(btn)
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

			# High trust: enter for NSFW
			if char.relation >= 65 or char.is_vulnerable():
				var enter_btn = Button.new()
				enter_btn.text = "Зайти к ней (NSFW)"
				enter_btn.custom_minimum_size = Vector2(380, 40)
				enter_btn.pressed.connect(func():
					state.add_log("Ты входишь в туалет к %s..." % char.char_name)
					_show_char_menu(char)
				)
				v.add_child(enter_btn)
			else:
				var locked = Label.new()
				locked.text = "Зайти можно при Trust ≥ 65\n(или если пьяная / под снотворным)"
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
	var title = Label.new(); title.text = char.char_name; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 18); action_list.add_child(title)
	var sub = Label.new(); sub.text = "Trust %d · Lust %d" % [char.relation, char.arousal]; sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; action_list.add_child(sub)
	action_list.add_child(HSeparator.new())
	var asleep = char.is_asleep() or char.is_vulnerable()
	var all_a = [
		["Смотреть", 0, "look", 0, 0],
		["Диалог", 1, "dialog", 0, 0],
		["Прикоснуться", 1, "touch", 25, 0],
		["Подсмотреть", 1, "peep", 30, 0],
		["Снять одеяло", 0, "blanket", 0, 0],
		["Поцеловать", 1, "kiss", 45, 20],
		["Раздеть", 1, "undress", 55, 35],
		["Спать вместе", 8, "sleep", 50, 0],
		["Оральный", 2, "sex_o", 60, 45],
		["Миссионерская", 2, "sex_m", 65, 50],
		["Собачка", 2, "sex_d", 70, 55],
		["Наездница", 2, "sex_c", 70, 55],
		["Секс во сне", 2, "sex_s", 40, 0],
		["Разбудить для NSFW", 1, "wake_nsfw", 70, 60],
	]
	var shown = 0
	for a in all_a:
		var ok = false
		var id = a[2]
		# Progressive sleep NSFW: blanket -> undress -> deep acts
		# Without blanket/undress only: touch, look, peep, handjob, oral sleep
		if asleep:
			var naked = char.clothes == "голая"
			var uncovered = not char.has_blanket
			match id:
				"look", "peep", "touch":
					ok = true
				"blanket":
					ok = char.has_blanket
				"undress":
					ok = (uncovered or char.is_vulnerable()) and not naked
				"hand":
					ok = true  # hand while sleep always possible (stealth)
				"sex_o":
					ok = true  # oral while sleep basic
				"kiss":
					ok = uncovered or char.is_vulnerable()
				"sex_s", "sex_m", "sex_d", "sex_c":
					# full NSFW only after blanket off AND naked
					ok = uncovered and naked
				"wake_nsfw":
					ok = char.can_wake_for_nsfw() or char.is_vulnerable()
				"dialog", "sleep":
					ok = false
				_:
					ok = char.relation >= a[3] and char.arousal >= a[4]
		else:
			if id in ["sex_s", "blanket", "hand"]:
				ok = false
			elif id == "undress" and char.clothes == "голая":
				ok = false
			else:
				ok = char.relation >= a[3] and char.arousal >= a[4]
		if not ok:
			continue
		shown += 1
		var b = Button.new()
		b.text = a[0]
		b.custom_minimum_size = Vector2(200, 32)
		if id == "dialog":
			b.pressed.connect(_start_dialog.bind(char))
		else:
			b.pressed.connect(_do_action.bind(id, a[1], char))
		action_list.add_child(b)
	if shown <= 2 and not asleep:
		var h = Label.new()
		h.text = "Больше при росте Trust/Lust"
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_theme_color_override("font_color", Color(0.75, 0.7, 0.4))
		action_list.add_child(h)
	var cb = Button.new(); cb.text = "Закрыть"; cb.pressed.connect(func(): action_menu.visible = false); action_list.add_child(cb)
	action_menu.visible = true
	action_menu.position = Vector2(430, 120)
	action_menu.z_index = 20

func _show_group_actions():
	if not action_menu or not action_list: return
	for c in action_list.get_children(): c.queue_free()
	var t = Label.new(); t.text = "Обе вместе"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size", 18); action_list.add_child(t)
	for a in [["Раздеть обеих", "both_undress", 1], ["Трогать обеих", "both_touch", 1], ["Целовать обеих", "both_kiss", 1], ["Секс втроём", "threesome", 2]]:
		var b = Button.new(); b.text = a[0]; b.custom_minimum_size = Vector2(200, 36)
		b.pressed.connect(func():
			var r = ""
			match a[1]:
				"both_undress": r = Interactions.both_undress(state.lena, state.masha)
				"both_touch": r = Interactions.touch(state.lena) + "\n" + Interactions.touch(state.masha)
				"both_kiss": r = Interactions.kiss(state.lena) + "\n" + Interactions.kiss(state.masha)
				"threesome": r = Interactions.threesome_missionary(state.lena, state.masha)
			state.add_log(r)
	show_action_image(aid, char); state.advance_time(a[2]); state.add_log("[+%d ч] → %s" % [a[2], state.get_time_str()])
			action_menu.visible = false; _refresh_all()
		); action_list.add_child(b)
	var cb = Button.new(); cb.text = "Закрыть"; cb.pressed.connect(func(): action_menu.visible = false); action_list.add_child(cb)
	action_menu.visible = true
	action_menu.position = Vector2(430, 120)
	action_menu.z_index = 20

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

func _execute_action(aid: String, hours: int, char: CharacterData):
	var r = ""
	match aid:
		"look": r = Interactions.look_at(char)
		"touch": r = Interactions.touch(char)
		"kiss": r = Interactions.kiss(char)
		"undress": r = Interactions.undress(char)
		"blanket":
			char.has_blanket = false
			char.change_arousal(12)
			r = "Ты осторожно снимаешь одеяло с %s..." % char.char_name
		"hand":
			char.change_arousal(18)
			r = "Ты трогаешь %s рукой, пока она спит..." % char.char_name
		"peep": r = Interactions.peep(char)
		"sex_m": r = Interactions.sex_missionary(char)
		"sex_d": r = Interactions.sex_doggy(char)
		"sex_c": r = Interactions.sex_cowgirl(char)
		"sex_o": r = Interactions.sex_oral(char)
		"sex_s": r = Interactions.sex_sleep(char)
		"sleep": r = Interactions.sleep_together(char)
		"wake_nsfw":
			if char.can_wake_for_nsfw():
				char.set_state("бодрствует")
				char.change_arousal(15)
				r = "Ты будишь %s. Она смотрит с желанием..." % char.char_name
			else:
				r = "Она ещё не готова, чтобы её будили для этого."
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
	box.offset_left = 40
	box.offset_right = -300
	box.offset_top = -280
	box.offset_bottom = -110
	add_child(box)
	var v = VBoxContainer.new()
	box.add_child(v)
	var who = Label.new()
	who.text = char.char_name
	who.add_theme_font_size_override("font_size", 16)
	v.add_child(who)
	var tl = Label.new()
	tl.text = dialog["text"]
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tl)
	for opt in dialog["options"]:
		var b = Button.new()
		b.text = opt["text"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			char.change_relation(opt["relation"])
			char.change_arousal(opt["arousal"])
			state.add_log("Ты: %s\n%s: %s" % [opt["text"], char.char_name, opt["response"]])
			state.advance_time(1)
			if is_instance_valid(box):
				box.queue_free()
			_refresh_all()
		)
		v.add_child(b)


func _on_midnight():
	var d = AcceptDialog.new()
	d.title = "Полночь"
	d.dialog_text = "Уже полночь. Пора спать, или выпей кофе, если хочешь сделать что-то ночью."
	add_child(d)
	d.popup_centered()
	d.confirmed.connect(func(): d.queue_free())
	d.canceled.connect(func(): d.queue_free())
