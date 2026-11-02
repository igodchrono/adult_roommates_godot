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
var lena: CharacterData
var masha: CharacterData
var log_messages: Array[String] = []
var midnight_warned: bool = false
signal midnight_reached

func _ready():
	lena = CharacterData.new("lena", "Лена", 24)
	masha = CharacterData.new("masha", "Маша", 22)
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
	var prev_hour = hour
	hour += hours
	while hour >= 24:
		hour -= 24
		day_index = (day_index + 1) % 7
		day = DAYS[day_index]
		_new_day()
		midnight_warned = false
	# Crossed midnight (00:00)
	if prev_hour > 0 and (prev_hour + hours) >= 24:
		if not midnight_warned:
			midnight_warned = true
			midnight_reached.emit()
			add_log("🌙 Уже полночь. Пора спать, или выпей кофе, если хочешь действовать ночью.")
	elif hour == 0 and prev_hour != 0 and not midnight_warned:
		midnight_warned = true
		midnight_reached.emit()
		add_log("🌙 Уже полночь. Пора спать, или выпей кофе, если хочешь действовать ночью.")
	apply_schedule()
	time_changed.emit()

func _new_day():
	for char in [lena, masha]:
		char.clear_daily_effects()
		if char.effects.get("no_sleep_night", false):
			char.set_state("спит")
			char.effects["no_sleep_night"] = false
		if char.drunk_level > 0:
			char.drunk_level = maxi(0, char.drunk_level - 1)
			if char.drunk_level == 0:
				char.effects["pass_out"] = false

func apply_schedule():
	for char in [lena, masha]:
		# Priority: need toilet after tea
		if char.effects.get("need_toilet", false):
			if char.location != "туалет":
				char.set_location("туалет")
				char.set_state("бодрствует")
				add_log("%s пошла в туалет." % char.char_name)
			else:
				# Already there — clear after this tick so they leave next hour
				char.effects["need_toilet"] = false
			continue
		if char.state == "отключка" or char.effects.get("deep_sleep", false):
			char.set_location("комната_лены" if char.key == "lena" else "комната_маши")
			continue
		var planned = _get_scheduled(char.key, day, hour)
		if planned == "работа":
			char.set_location("работа")
			char.set_state("бодрствует")
			continue
		char.set_location(planned)
		var period = get_period()
		if period == "ночь" and not char.effects.get("no_sleep_night", false):
			if char.effects.get("pass_out", false) or char.drunk_level >= 2:
				char.set_state("отключка")
			else:
				if char.state != "спит":
					_randomize_sleep_state(char)
				char.set_state("спит")
		else:
			if char.state != "отключка":
				char.set_state("бодрствует")
				char.has_blanket = true
				if char.clothes == "голая" and not char.effects.get("deep_sleep", false):
					char.set_clothes("домашняя")

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

func rest(hours: int, reason: String = "отдых") -> String:
	advance_time(hours)
	return "Ты %s. Прошло %d ч. Сейчас %s (%s)." % [reason, hours, get_time_str(), get_period()]

func work() -> String:
	advance_time(8)
	money += 1000
	money_changed.emit()
	return "Ты отработал 8 часов. +1000. Баланс: %d" % money

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
