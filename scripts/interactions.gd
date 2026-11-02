extends Node
class_name Interactions

static func look_at(char: CharacterData) -> String:
	var text = "Ты смотришь на %s.\nОдежда: %s. Состояние: %s.\n" % [char.char_name, char.clothes, char.state]
	if char.arousal > 65:
		text += "Она явно возбуждена.\n"
	if char.state == "отключка":
		text += "Она крепко спит и не реагирует."
	return text

static func touch(char: CharacterData) -> String:
	if not _awake(char):
		return "%s сейчас не в сознании." % char.char_name
	if char.relation < 45:
		char.change_relation(-4)
		return "%s: «Эй, руки!»" % char.char_name
	char.change_arousal(8)
	char.change_relation(4)
	return "%s не отстраняется." % char.char_name

static func kiss(char: CharacterData) -> String:
	if not _awake(char):
		return "%s сейчас не в сознании." % char.char_name
	if char.relation < 55:
		return "%s отворачивается: «Рановато.»" % char.char_name
	char.change_arousal(12)
	char.change_relation(6)
	return "%s отвечает на поцелуй." % char.char_name

static func undress(char: CharacterData) -> String:
	if not _awake(char):
		return "%s сейчас не в сознании." % char.char_name
	if char.clothes == "голая":
		return "%s уже без верхней одежды." % char.char_name
	if char.relation < 60:
		char.change_mood(-4)
		return "%s: «Нет, не сейчас.»" % char.char_name
	char.set_clothes("голая")
	char.change_arousal(15)
	char.change_relation(4)
	char.change_mood(4)
	return "%s соглашается раздеться." % char.char_name

static func sex_missionary(char: CharacterData) -> String:
	if not _can_sex(char):
		return _refuse(char)
	char.change_arousal(20)
	char.change_relation(8)
	char.change_mood(6)
	return "Вы занимаетесь сексом. %s сама этого хочет." % char.char_name

static func sex_doggy(char: CharacterData) -> String:
	if not _can_sex(char):
		return _refuse(char)
	char.change_arousal(20)
	char.change_relation(8)
	char.change_mood(6)
	return "Вы занимаетесь сексом. %s не против." % char.char_name

static func sex_cowgirl(char: CharacterData) -> String:
	if not _can_sex(char):
		return _refuse(char)
	char.change_arousal(20)
	char.change_relation(8)
	char.change_mood(6)
	return "%s сама задаёт ритм." % char.char_name

static func sex_oral(char: CharacterData) -> String:
	if not _can_sex(char):
		return _refuse(char)
	char.change_arousal(16)
	char.change_relation(6)
	char.change_mood(4)
	return "%s соглашается на более близкую ласку." % char.char_name

static func sex_sleep(_char: CharacterData) -> String:
	return "Пока человек спит, этого нет."

static func sleep_together(char: CharacterData) -> String:
	if not _awake(char) or char.relation < 55:
		return "%s: «Не сегодня.»" % char.char_name
	char.set_state("спит")
	char.change_relation(4)
	char.change_mood(4)
	return "Вы ложитесь спать рядом с %s." % char.char_name

static func peep(char: CharacterData) -> String:
	var text = "Ты подсматриваешь за %s...\n" % char.char_name
	if char.clothes == "голая":
		text += "Она полностью голая."
		char.change_arousal(10)
	else:
		text += "Она в %s." % char.clothes
		char.change_arousal(5)
	return text

static func _awake(char: CharacterData) -> bool:
	return char.is_up()

static func _can_sex(char: CharacterData) -> bool:
	return _awake(char) and char.relation >= 65 and char.arousal >= 45

static func _refuse(char: CharacterData) -> String:
	if not _awake(char):
		return "%s сейчас не в сознании." % char.char_name
	if char.relation < 65:
		return "%s: «Я ещё не готова.» Trust %d." % [char.char_name, char.relation]
	return "Сначала нужно больше близости. Возбуждение %d." % char.arousal

static func both_undress(lena: CharacterData, masha: CharacterData) -> String:
	var results = []
	for char in [lena, masha]:
		results.append(undress(char))
	return "\n".join(results)

static func threesome_missionary(lena: CharacterData, masha: CharacterData) -> String:
	if not _can_sex(lena) or not _can_sex(masha):
		return "Обе должны бодрствовать, Trust от 65 и возбуждение от 45."
	for char in [lena, masha]:
		char.change_arousal(18)
		char.change_relation(6)
		char.change_mood(6)
	return "Вы проводите время втроём. Обе согласны."
