extends Node
class_name Interactions

static func look_at(char: CharacterData) -> String:
	var text = "Ты смотришь на %s.\nОдежда: %s. Состояние: %s.\n" % [char.char_name, char.clothes, char.state]
	if char.arousal > 65:
		text += "Она явно возбуждена.\n"
	if char.state == "отключка":
		text += "Она в полной отключке. Можно делать почти что угодно."
	return text

static func touch(char: CharacterData) -> String:
	if char.state in ["спит", "отключка"]:
		char.change_arousal(12)
		return "Ты осторожно касаешься %s..." % char.char_name
	if char.relation < 45:
		char.change_relation(-4)
		return "%s: «Эй, руки!»" % char.char_name
	char.change_arousal(14)
	char.change_relation(5)
	return "Ты касаешься %s. Она не отстраняется." % char.char_name

static func kiss(char: CharacterData) -> String:
	if char.state == "отключка":
		char.change_arousal(8)
		return "Ты целуешь %s, пока она в отключке." % char.char_name
	if char.relation < 55 and char.state != "спит":
		return "%s отворачивается: «Рановато...»" % char.char_name
	char.change_arousal(18)
	char.change_relation(7)
	return "Ты целуешь %s. Она отвечает." % char.char_name

static func undress(char: CharacterData) -> String:
	if char.clothes == "голая":
		return "%s уже голая." % char.char_name
	if char.relation < 60 and char.state not in ["спит", "отключка"]:
		return "%s: «Нет... не сейчас.»" % char.char_name
	char.set_clothes("голая")
	char.change_arousal(25)
	char.change_relation(9)
	return "Ты раздеваешь %s. Теперь она полностью обнажена." % char.char_name

static func sex_missionary(char: CharacterData) -> String:
	if not _can_sex(char):
		return _refuse(char)
	char.change_arousal(35)
	char.change_relation(12)
	return "Ты берёшь %s в миссионерской. Она громко стонет." % char.char_name

static func sex_doggy(char: CharacterData) -> String:
	if not _can_sex(char):
		return _refuse(char)
	char.change_arousal(38)
	char.change_relation(13)
	return "Ты берёшь %s сзади. Она выгибается навстречу." % char.char_name

static func sex_cowgirl(char: CharacterData) -> String:
	if not _can_sex(char):
		return _refuse(char)
	char.change_arousal(36)
	char.change_relation(14)
	return "%s садится сверху и двигается сама." % char.char_name

static func sex_oral(char: CharacterData) -> String:
	if char.relation < 60 and char.state not in ["спит", "отключка"]:
		return "%s: «Я ещё не готова...»" % char.char_name
	char.change_arousal(28)
	char.change_relation(10)
	return "%s берёт тебя в рот." % char.char_name

static func sex_sleep(char: CharacterData) -> String:
	if char.state not in ["спит", "отключка"]:
		return "Она не спит."
	char.change_arousal(30)
	char.change_relation(8)
	return "Пока %s без сознания, ты осторожно входишь..." % char.char_name

static func sleep_together(char: CharacterData) -> String:
	if char.relation < 55 and char.state != "отключка":
		return "%s: «Не сегодня...»" % char.char_name
	char.set_state("спит")
	char.change_relation(6)
	return "Вы засыпаете вместе с %s." % char.char_name

static func peep(char: CharacterData) -> String:
	var text = "Ты подсматриваешь за %s...\n" % char.char_name
	if char.clothes == "голая":
		text += "Она полностью голая."
		char.change_arousal(10)
	else:
		text += "Она в %s." % char.clothes
		char.change_arousal(5)
	return text

static func _can_sex(char: CharacterData) -> bool:
	return (char.relation >= 65 or char.state in ["спит", "отключка"]) and (char.arousal >= 45 or char.state in ["спит", "отключка"])

static func _refuse(char: CharacterData) -> String:
	if char.relation < 65:
		return "%s: «Я ещё не готова...»" % char.char_name
	return "Она ещё недостаточно возбуждена."

# Group
static func both_undress(lena: CharacterData, masha: CharacterData) -> String:
	var results = []
	for char in [lena, masha]:
		if char.clothes != "голая":
			if char.relation >= 55 or char.state in ["спит", "отключка"]:
				char.set_clothes("голая")
				char.change_arousal(20)
				results.append("%s теперь голая." % char.char_name)
			else:
				results.append("%s пока не готова." % char.char_name)
		else:
			results.append("%s уже голая." % char.char_name)
	return "\n".join(results)

static func threesome_missionary(lena: CharacterData, masha: CharacterData) -> String:
	for char in [lena, masha]:
		char.change_arousal(30)
		char.change_relation(10)
	return "Секс втроём. Обе стонут и смотрят друг на друга."
