extends Node
class_name GameState

signal time_changed
signal log_added(text: String)
signal midnight_alert

const DAYS = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]
const LOCATIONS = ["зал", "комната_лены", "комната_маши", "ванная", "туалет", "кладовка", "кухня", "моя_комната", "работа", "магазин"]

var hour: int = 19
var day_index: int = 5
var day: String = "суббота"
var player_location: String = "зал"
var lena: CharacterData
var masha: CharacterData
var log_messages: Array[String] = []

func _ready():
	lena = CharacterData.new("lena", "Лена", 24)
	masha = CharacterData.new("masha", "Маша", 22)
	apply_schedule()

func get_time_str() -> String:
	return "%02d:00" % hour

func advance_time(hours: int = 1):
	if hours <= 0: return
	
	var old_hour = hour
	hour += hours
	while hour >= 24:
		hour -= 24
		day_index = (day_index + 1) % 7
		day = DAYS[day_index]
		_new_day()
		
	# Проверка на полночь
	if old_hour < 24 and hour == 0:
		midnight_alert.emit()
		
	apply_schedule()
	time_changed.emit()

func _new_day():
	for char in [lena, masha]:
		char.clear_daily_effects()
		if char.is_asleep():
			char.randomize_sleep_state()
		if char.drunk_level > 0:
			char.drunk_level = maxi(0, char.drunk_level - 1)
			if char.drunk_level == 0:
				char.effects["pass_out"] = false

func apply_schedule():
	for char in [lena, masha]:
		if char.effects.get("need_toilet", false):
			if char.location != "туалет":
				char.set_location("туалет")
				char.set_state("бодрствует")
				add_log("%s пошла в туалет." % char.char_name)
			else:
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
			if char.state != "спит":
				char.randomize_sleep_state()
		else:
			if char.state != "отключка":
				char.set_state("бодрствует")

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

func get_period() -> String:
	if hour >= 5 and hour < 12: return "утро"
	elif hour >= 12 and hour < 17: return "день"
	elif hour >= 17 and hour < 22: return "вечер"
	return "ночь"

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