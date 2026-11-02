extends Node
class_name CharacterData

var key: String = ""
var char_name: String = ""
var age: int = 22
var relation: int = 35
var arousal: int = 15
var location: String = "зал"
var state: String = "бодрствует"
var clothes: String = "домашняя"
var mood: String = "нейтральное"
var drunk_level: int = 0
var anxiety: int = 0
var offended_days: int = 0
var has_blanket: bool = true

var effects := {
	"no_sleep_night": false,
	"pass_out": false,
	"deep_sleep": false,
	"need_toilet": false
}

func _init(p_key: String = "", p_name: String = "", p_age: int = 22):
	key = p_key
	char_name = p_name
	age = p_age

func change_relation(value: int):
	relation = clampi(relation + value, 0, 100)

func change_arousal(value: int):
	arousal = clampi(arousal + value, 0, 100)

func change_anxiety(value: int):
	if effects.get("deep_sleep", false):
		value = 0
	elif drunk_level >= 1:
		value = int(value * 0.25)
	anxiety = clampi(anxiety + value, 0, 100)

func set_location(loc: String):
	location = loc

func set_state(s: String):
	state = s

func set_clothes(c: String):
	clothes = c

func apply_effect(effect_name: String):
	if effects.has(effect_name):
		effects[effect_name] = true
	if effect_name == "pass_out":
		drunk_level = mini(3, drunk_level + 1)

func clear_daily_effects():
	effects["need_toilet"] = false
	if offended_days > 0:
		offended_days -= 1

func is_vulnerable() -> bool:
	return effects.get("deep_sleep", false) or drunk_level >= 2 or state == "отключка"

func is_asleep() -> bool:
	return state in ["спит", "отключка"] or effects.get("deep_sleep", false)

func needs_stealth() -> bool:
	if is_vulnerable():
		return false
	return relation < 60 or arousal < 50

func can_wake_for_nsfw() -> bool:
	return relation >= 70 and arousal >= 60

func get_image_key() -> String:
	if is_asleep():
		if clothes == "голая":
			return "sleep"
		return "sleep"
	if clothes == "голая":
		return "naked"
	if arousal >= 70:
		return "aroused"
	return "normal"

func status_short() -> String:
	var extra = ""
	if offended_days > 0:
		extra = " [обижена %dд]" % offended_days
	elif state == "отключка":
		extra = " [off]"
	elif effects.get("deep_sleep", false):
		extra = " [снотв]"
	elif effects.get("need_toilet", false):
		extra = " [toilet]"
	elif drunk_level > 0:
		extra = " [drunk %d]" % drunk_level
	elif anxiety > 0:
		extra = " [трев %d%%]" % anxiety
	return "%s: T%d L%d | %s | %s%s" % [char_name, relation, arousal, clothes, state, extra]
