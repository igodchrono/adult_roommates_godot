extends Node
class_name GameState

signal time_changed
signal location_changed
signal log_added(text: String)
signal money_changed

const DAYS = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]
const LOCATIONS = ["зал", "комната_лены", "комната_маши", "ванная", "туалет", "кладовка", "кухня", "моя_комната", "работа", "магазин"]
const SHOP_PRICES = {"чай": 100, "кофе": 200, "алкоголь": 300, "снотворное": 300}

var hour: int = 19
var day_index: int = 5
var day: String = "суббота"
var player_location: String = "зал"
var money: int = 2000
var inventory = {"чай": 1, "кофе": 0, "алкоголь": 0, "снотворное": 0}
var player_coffee: bool = false
var lena: CharacterData
var masha: CharacterData
var log_messages: Array[String] = []
var midnight_warned: bool = false
signal midnight_reached

func _ready():
	lena = CharacterData.new("lena", "Лена", 23)
	masha = CharacterData.new("masha", "Маша", 40)
	apply_schedule()

func get_time_str() -> String:
	return "%02d:00" % hour

func get_period() -> String:
	if hour >= 5 and hour < 12: return "утро"
	elif hour >= 12 and hour < 17: return "день"
	elif hour >= 17 and hour < 22: return "вечер"
	return "ночь"

func advance_time(hours: int = 1):
	if hours <= 0: return
	for _step in hours:
		var prev_hour = hour
		hour += 1
		if hour >= 24:
			hour -= 24
			day_index = (day_index + 1) % 7
			day = DAYS[day_index]
			_new_day()
			midnight_warned = true
			midnight_reached.emit()
			if player_coffee:
				add_log("Полночь. Кофе действует, можно ходить по комнатам.")
			else:
				player_location = "моя_комната"
				add_log("Полночь. Ты в своей комнате. Выпей кофе, если хочешь выйти.")
		if hour == 7:
			player_coffee = false
			for char in [lena, masha]:
				char.effects["no_sleep_night"] = false
		for char in [lena, masha]:
			char.tick_needs(1, char.is_asleep())
		apply_schedule()
		if prev_hour == 23 and hour == 0:
			pass
	time_changed.emit()

func _new_day():
	for char in [lena, masha]:
		char.clear_daily_effects()
		if char.drunk_level > 0:
			char.drunk_level = maxi(0, char.drunk_level - 1)
			if char.drunk_level == 0:
				char.effects["pass_out"] = false

func apply_schedule():
	for char in [lena, masha]:
		if char.state == "ест":
			char.restore_hunger()
		elif char.state == "умывается":
			char.restore_hygiene()
		if char.effects.get("need_toilet", false):
			if char.location != "туалет":
				_place(char, "туалет", "бодрствует", "%s пошла в туалет." % char.char_name)
			else:
				char.effects["need_toilet"] = false
			continue
		if char.state == "отключка" or char.effects.get("deep_sleep", false):
			_place(char, "комната_лены" if char.key == "lena" else "комната_маши", char.state, "")
			_react_emotion(char)
			continue
		if char.energy < 25 and (get_period() == "ночь" or char.energy < 12) and not char.effects.get("no_sleep_night", false):
			var room = "комната_лены" if char.key == "lena" else "комната_маши"
			if char.state != "спит":
				_randomize_sleep_state(char)
			_place(char, room, "спит", "%s устала и легла спать." % char.char_name)
			_react_emotion(char)
			continue
		if char.hunger < 30 and get_period() != "ночь":
			_place(char, "кухня", "ест", "%s проголодалась и пошла на кухню." % char.char_name)
			_react_emotion(char)
			continue
		if char.hygiene < 30 and get_period() != "ночь" and _get_scheduled(char.key, day, hour) != "работа":
			_place(char, "ванная", "умывается", "%s пошла умываться." % char.char_name)
			_react_emotion(char)
			continue
		var planned = _get_scheduled(char.key, day, hour)
		if planned == "работа":
			_place(char, "работа", "бодрствует", "")
			_react_emotion(char)
			continue
		var next_state = "бодрствует"
		if get_period() == "ночь" and not char.effects.get("no_sleep_night", false):
			if char.effects.get("pass_out", false) or char.drunk_level >= 2:
				next_state = "отключка"
			else:
				next_state = "спит"
				if char.state != "спит":
					_randomize_sleep_state(char)
		else:
			char.has_blanket = true
			if char.clothes == "голая" and not char.effects.get("deep_sleep", false):
				char.set_clothes("домашняя")
		_place(char, planned, next_state, "")
		_react_emotion(char)

func _react_emotion(char: CharacterData):
	if char.is_asleep():
		return
	if player_location != char.location:
		return
	if char.emotion == char.shown_emotion:
		return
	char.shown_emotion = char.emotion
	add_log("%s (%s): %s" % [char.char_name, char.mood, _emotion_line(char)])

func _emotion_line(char: CharacterData) -> String:
	match char.emotion:
		"обида":
			return "Не хочет разговаривать."
		"усталость":
			return "Еле держится на ногах."
		"голод":
			return "Хочет есть."
		"дискомфорт":
			return "Хочет в ванную."
		"раздражение":
			return "Лучше её сейчас не трогать."
		"радость":
			return "Улыбается."
		_:
			return "Выглядит спокойно."

func _place(char: CharacterData, loc: String, next_state: String, msg: String):
	var changed = char.location != loc or char.state != next_state
	char.set_location(loc)
	char.set_state(next_state)
	if changed and msg != "":
		add_log(msg)

func _get_scheduled(key: String, d: String, h: int) -> String:
	var is_weekend = d in ["суббота", "воскресенье"]
	if key == "lena":
		if is_weekend:
			if h < 9: return "комната_лены"
			if h < 22: return "зал"
			return "комната_лены"
		else:
			if h < 7: return "комната_лены"
			if h < 9: return "ванная"
			if h < 18: return "работа"
			if h < 23: return "зал"
			return "комната_лены"
	else:
		if is_weekend:
			if h < 10: return "комната_маши"
			if h < 20: return "зал"
			return "комната_маши"
		else:
			if h < 8: return "комната_маши"
			if h < 10: return "ванная"
			if h < 18: return "работа"
			if h < 21: return "зал"
			return "комната_маши"

func night_locked() -> bool:
	return hour < 7 and not player_coffee

func drink_player_coffee() -> String:
	if inventory.get("кофе", 0) <= 0:
		return "Кофе нет. Купи в магазине."
	inventory["кофе"] -= 1
	player_coffee = true
	return "Ты выпил кофе. Этой ночью можно не спать и ходить по комнатам."

func sleep_until_morning() -> String:
	var hours = (7 - hour + 24) % 24
	if hours == 0:
		hours = 24
	player_coffee = false
	advance_time(hours)
	return "Ты поспал до утра. Сейчас %s." % get_time_str()

func rest(hours: int, reason: String = "отдых") -> String:
	advance_time(hours)
	return "Ты %s. Прошло %d ч. Сейчас %s (%s)." % [reason, hours, get_time_str(), get_period()]

func work() -> String:
	advance_time(8)
	money += 1000
	money_changed.emit()
	return "Ты отработал 8 часов. +1000. Баланс: %d" % money

func chore_for(loc: String) -> Dictionary:
	match loc:
		"зал":
			return {"name": "Убрать зал", "pay": 80}
		"кухня":
			return {"name": "Помыть посуду", "pay": 100}
		"ванная":
			return {"name": "Убрать ванную", "pay": 90}
		"кладовка":
			return {"name": "Разобрать кладовку", "pay": 70}
	return {}

func do_chore(loc: String) -> String:
	var job = chore_for(loc)
	if job.is_empty():
		return "Здесь нет бытовой работы."
	advance_time(1)
	money += int(job["pay"])
	money_changed.emit()
	return "%s. +%d. Баланс: %d. Сейчас %s." % [job["name"], job["pay"], money, get_time_str()]

func buy_item(item_key: String) -> String:
	if not SHOP_PRICES.has(item_key):
		return "Нет такого товара."
	var price = SHOP_PRICES[item_key]
	if money < price:
		return "Не хватает денег. Нужно %d, у тебя %d." % [price, money]
	money -= price
	inventory[item_key] = inventory.get(item_key, 0) + 1
	money_changed.emit()
	return "Куплено: %s (-%d). Осталось: %d" % [item_key, price, money]

func offer_item(char: CharacterData, item_key: String) -> String:
	if inventory.get(item_key, 0) <= 0:
		return "Нет в инвентаре: %s" % item_key
	inventory[item_key] -= 1
	match item_key:
		"чай":
			char.effects["need_toilet"] = true
			char.change_relation(3)
			# Сразу планируем поход — при следующем обновлении/часе пойдёт
			# Если уже не спит крепко — идём почти сразу
			if not char.effects.get("deep_sleep", false) and char.state != "отключка":
				char.set_location("туалет")
				char.set_state("бодрствует")
				return "%s выпила чай и пошла в туалет." % char.char_name
			return "%s выпила чай. Когда проснётся — пойдёт в туалет." % char.char_name
		"кофе":
			char.effects["no_sleep_night"] = true
			char.change_arousal(5)
			return "%s выпила кофе. Ночью не уснёт." % char.char_name
		"алкоголь":
			char.apply_effect("pass_out")
			char.change_arousal(10)
			char.change_relation(4)
			return "%s выпила. Пьянеет (уровень %d)." % [char.char_name, char.drunk_level]
		"снотворное":
			char.effects["deep_sleep"] = true
			char.set_state("спит")
			char.set_location("комната_лены" if char.key == "lena" else "комната_маши")
			return "%s приняла снотворное и крепко заснула." % char.char_name
	return "Отдал %s." % item_key

func add_log(text: String):
	log_messages.append(text)
	if log_messages.size() > 15:
		log_messages.pop_front()
	log_added.emit(text)

func get_people_in_location(loc: String) -> Array:
	var people = []
	if lena.location == loc: people.append(lena)
	if masha.location == loc: people.append(masha)
	return people

func call_char(char: CharacterData):
	char.set_location(player_location)
	char.set_state("бодрствует")
	add_log("%s пришла в %s" % [char.char_name, player_location])

# --- Access rules ---

func _randomize_sleep_state(char: CharacterData):
	var roll = randf()
	if roll < 0.30:
		char.has_blanket = true
		char.set_clothes("домашняя")
	elif roll < 0.60:
		char.has_blanket = false
		char.set_clothes("домашняя")
	elif roll < 0.80:
		char.has_blanket = true
		char.set_clothes("голая")
	else:
		char.has_blanket = false
		char.set_clothes("голая")

func can_enter_room(loc: String) -> Dictionary:
	# Returns {ok: bool, reason: String, stealth: bool}
	# Toilet: always allow approach (peep UI handles access)
	if loc == "туалет":
		return {"ok": true, "reason": "", "stealth": false}
	var private = ["комната_лены", "комната_маши", "ванная"]
	if loc not in private:
		return {"ok": true, "reason": "", "stealth": false}

	var people = get_people_in_location(loc)
	if people.is_empty():
		return {"ok": true, "reason": "", "stealth": false}

	for char in people:
		if char.offended_days > 0 and not char.is_vulnerable():
			return {"ok": false, "reason": "%s обижена и не пускает." % char.char_name, "stealth": false}

		# High trust = free entry
		if char.relation >= 55:
			continue

		# Vulnerable (drunk / pills / pass out) = free entry
		if char.is_vulnerable():
			continue

		# Low love and she's there awake = blocked
		if not char.is_asleep() and char.relation < 40:
			return {"ok": false, "reason": "%s не хочет, чтобы ты заходил. (Trust < 40)" % char.char_name, "stealth": false}

		# Asleep + low love = stealth mode
		if char.is_asleep() and char.needs_stealth():
			return {"ok": true, "reason": "Осторожно... она спит. Режим скрытности.", "stealth": true}

	return {"ok": true, "reason": "", "stealth": false}

func is_night() -> bool:
	return get_period() == "ночь"

func kick_out(char: CharacterData):
	char.anxiety = 0
	char.offended_days = 2
	char.change_relation(-20)
	player_location = "зал"
	add_log("%s проснулась! Тебя выгнали. Обижена 2 дня. Trust -20." % char.char_name)
