extends Node
class_name Dialogues

const LENA = [
	{
		"min_rel": 0, "max_rel": 34, "min_ar": 0, "max_ar": 100,
		"text": "Лена даже не садится. «Говори короче.»",
		"options": [
			{"text": "Поздороваться", "lines": [
				{"min_rel": 0, "min_ar": 0, "relation": 2, "arousal": 0, "response": "«Привет. И всё?»"},
			]},
			{"text": "Сделать комплимент", "lines": [
				{"min_rel": 0, "min_ar": 0, "relation": -2, "arousal": 0, "response": "«Не надо. Мы почти не знакомы.»"},
				{"min_rel": 20, "min_ar": 30, "relation": 1, "arousal": 2, "response": "Она хмыкает, но не злится."},
			]},
			{"text": "Спросить, как день", "lines": [
				{"min_rel": 0, "min_ar": 0, "relation": 3, "arousal": 0, "response": "«Нормально. Устала.»"},
			]},
		]
	},
	{
		"min_rel": 35, "max_rel": 54, "min_ar": 0, "max_ar": 100,
		"text": "Лена опирается на косяк. «Ну, чего хотел?»",
		"options": [
			{"text": "Поболтать про работу", "lines": [
				{"min_rel": 35, "min_ar": 0, "relation": 4, "arousal": 0, "response": "«Дома лучше. Хоть ты не достаёшь.» усмехается."},
			]},
			{"text": "Сказать, что она хорошо выглядит", "lines": [
				{"min_rel": 35, "min_ar": 0, "relation": 4, "arousal": 4, "response": "«Спасибо.» короткий взгляд."},
				{"min_rel": 45, "min_ar": 40, "relation": 5, "arousal": 8, "response": "«Ты это специально?» голос тише, но она не уходит."},
			]},
			{"text": "Предложить чай", "lines": [
				{"min_rel": 35, "min_ar": 0, "relation": 3, "arousal": 0, "response": "«Можно. На кухне.»"},
			]},
			{"text": "Подойти слишком близко", "lines": [
				{"min_rel": 35, "min_ar": 0, "relation": -3, "arousal": 0, "response": "«Эй. Рано.» она отступает."},
				{"min_rel": 48, "min_ar": 35, "relation": 2, "arousal": 6, "response": "Она не отступает сразу. «Осторожнее.»"},
			]},
		]
	},
	{
		"min_rel": 55, "max_rel": 100, "min_ar": 0, "max_ar": 44,
		"text": "Лена улыбается уголком губ. «Соскучился?»",
		"options": [
			{"text": "Сказать, что да", "lines": [
				{"min_rel": 55, "min_ar": 0, "relation": 6, "arousal": 3, "response": "«Приятно.» садится ближе, без спешки."},
			]},
			{"text": "Спросить, как она на самом деле", "lines": [
				{"min_rel": 55, "min_ar": 0, "relation": 7, "arousal": 1, "response": "«Устала, но с тобой спокойнее.»"},
				{"min_rel": 70, "min_ar": 20, "relation": 5, "arousal": 4, "response": "«Хорошо. Правда. Не порть.»"},
			]},
			{"text": "Намекнуть на вечер вдвоём", "lines": [
				{"min_rel": 55, "min_ar": 0, "relation": 3, "arousal": 6, "response": "«Может. Не торопи.»"},
				{"min_rel": 70, "min_ar": 30, "relation": 4, "arousal": 8, "response": "«Если без давления — можно.»"},
			]},
		]
	},
	{
		"min_rel": 65, "max_rel": 100, "min_ar": 45, "max_ar": 100,
		"text": "Лена смотрит прямо. Дыхание чуть чаще. «Ты сегодня настойчивый.»",
		"options": [
			{"text": "Сказать, что она тебе нравится", "lines": [
				{"min_rel": 65, "min_ar": 45, "relation": 5, "arousal": 8, "response": "«Знаю.» подходит на шаг. «Я тоже не против компании.»"},
			]},
			{"text": "Предложить остаться рядом", "lines": [
				{"min_rel": 65, "min_ar": 45, "relation": 4, "arousal": 10, "response": "«Останься. Только пока я сама так решила.»"},
				{"min_rel": 80, "min_ar": 60, "relation": 6, "arousal": 12, "response": "«Иди сюда.» голос низкий, она ждёт твоей осторожности."},
			]},
			{"text": "Отшутиться и сбавить тон", "lines": [
				{"min_rel": 65, "min_ar": 45, "relation": 3, "arousal": -4, "response": "«Ладно, выдохнули.» она улыбается спокойнее."},
			]},
		]
	},
]

const MASHA = [
	{
		"min_rel": 0, "max_rel": 34, "min_ar": 0, "max_ar": 100,
		"text": "Маша держит чашку двумя руками. «А… привет.»",
		"options": [
			{"text": "Поздороваться тихо", "lines": [
				{"min_rel": 0, "min_ar": 0, "relation": 3, "arousal": 0, "response": "«Привет.» она чуть расслабляет плечи."},
			]},
			{"text": "Сказать, что она милая", "lines": [
				{"min_rel": 0, "min_ar": 0, "relation": -1, "arousal": 0, "response": "«Не надо так сразу…» отводит глаза."},
				{"min_rel": 25, "min_ar": 20, "relation": 2, "arousal": 2, "response": "Краснеет, но не убегает."},
			]},
			{"text": "Спросить про день", "lines": [
				{"min_rel": 0, "min_ar": 0, "relation": 4, "arousal": 0, "response": "«Нормально. Много людей.»"},
			]},
		]
	},
	{
		"min_rel": 35, "max_rel": 54, "min_ar": 0, "max_ar": 100,
		"text": "Маша улыбается несмело. «Ты чего?»",
		"options": [
			{"text": "Сказать, что она милая", "lines": [
				{"min_rel": 35, "min_ar": 0, "relation": 5, "arousal": 3, "response": "«Правда?» прячет улыбку."},
				{"min_rel": 45, "min_ar": 40, "relation": 4, "arousal": 7, "response": "«Ты так смотришь…» голос тише."},
			]},
			{"text": "Предложить сесть рядом", "lines": [
				{"min_rel": 35, "min_ar": 0, "relation": 4, "arousal": 2, "response": "Подвигается, оставляя место."},
				{"min_rel": 45, "min_ar": 35, "relation": 3, "arousal": 6, "response": "Садится вплотную и не отодвигается."},
			]},
			{"text": "Пошутить грубо", "lines": [
				{"min_rel": 35, "min_ar": 0, "relation": -4, "arousal": 0, "response": "«Не надо так.» дуется."},
			]},
		]
	},
	{
		"min_rel": 55, "max_rel": 100, "min_ar": 0, "max_ar": 44,
		"text": "Маша смотрит снизу вверх. «Я рада, что ты зашёл.»",
		"options": [
			{"text": "Сказать, что тоже рад", "lines": [
				{"min_rel": 55, "min_ar": 0, "relation": 6, "arousal": 2, "response": "Улыбка становится спокойной. «Тогда посиди.»"},
			]},
			{"text": "Спросить, чего она хочет", "lines": [
				{"min_rel": 55, "min_ar": 0, "relation": 5, "arousal": 3, "response": "«Просто побыть. Без спешки.»"},
				{"min_rel": 70, "min_ar": 25, "relation": 4, "arousal": 6, "response": "«Можно ближе. Если ты тоже этого хочешь.»"},
			]},
			{"text": "Похвалить, как ей идёт домашний свитер", "lines": [
				{"min_rel": 55, "min_ar": 0, "relation": 4, "arousal": 4, "response": "«Спасибо…» теребит рукав."},
			]},
		]
	},
	{
		"min_rel": 65, "max_rel": 100, "min_ar": 45, "max_ar": 100,
		"text": "Маша не отводит взгляд. Щёки тёплые. «Я думала о тебе.»",
		"options": [
			{"text": "Сказать, что ты тоже", "lines": [
				{"min_rel": 65, "min_ar": 45, "relation": 6, "arousal": 8, "response": "«Тогда не уходи сразу.» берёт тебя за рукав."},
			]},
			{"text": "Спросить, можно ли остаться", "lines": [
				{"min_rel": 65, "min_ar": 45, "relation": 5, "arousal": 10, "response": "Кивает. «Можно. Я скажу, если захочу остановиться.»"},
				{"min_rel": 80, "min_ar": 60, "relation": 4, "arousal": 12, "response": "«Хочу, чтобы ты был рядом. Сама так решила.»"},
			]},
			{"text": "Предложить просто обняться и успокоиться", "lines": [
				{"min_rel": 65, "min_ar": 45, "relation": 7, "arousal": -2, "response": "Обнимает крепко и выдыхает. «Так тоже хорошо.»"},
			]},
		]
	},
]

static func get_random_dialog(char: CharacterData) -> Dictionary:
	if char.offended_days > 0:
		return {
			"text": "%s смотрит в сторону. «Я ещё злюсь.»" % char.char_name,
			"options": [
				{"text": "Извиниться", "relation": 4, "arousal": 0, "response": "«Ладно. Но не сразу.»"},
				{"text": "Настоять", "relation": -4, "arousal": 0, "response": "«Оставь меня.»"},
			]
		}
	var pool = _pool(char)
	var raw = pool[randi() % pool.size()]
	var options: Array = []
	for opt in raw["options"]:
		var line = _pick_line(char, opt["lines"])
		options.append({
			"text": opt["text"],
			"relation": line["relation"],
			"arousal": line["arousal"],
			"response": line["response"],
		})
	var mood_note = "Настроение: %s. Доверие %d, возбуждение %d." % [char.mood, char.relation, char.arousal]
	return {"text": raw["text"] + "\n" + mood_note, "options": options}

static func _pool(char: CharacterData) -> Array:
	var all = LENA if char.key == "lena" else MASHA
	var fit: Array = []
	for d in all:
		if char.relation < d["min_rel"] or char.relation > d["max_rel"]:
			continue
		if char.arousal < d["min_ar"] or char.arousal > d["max_ar"]:
			continue
		fit.append(d)
	if fit.is_empty():
		return [all[0]]
	return fit

static func _pick_line(char: CharacterData, lines: Array) -> Dictionary:
	var best = lines[0]
	for line in lines:
		if char.relation >= int(line["min_rel"]) and char.arousal >= int(line["min_ar"]):
			best = line
	return best
