# Adult Roommates — Godot 4

Версия игры на Godot 4.

## Как запустить

1. Скачай и установи **Godot 4.2+** (https://godotengine.org)
2. Открой Godot → Import → укажи папку `adult_roommates_godot`
3. Открой проект
4. Нажми F5 (Play)

## Что уже есть

- Система времени (часы + день недели)
- Две соседки (Лена и Маша)
- Локации
- Клик по персонажу → меню действий
- Позвать персонажа
- Отдых / сон (промотка времени)
- Групповые действия
- Статы Trust / Lust

## Что добавить самому

1. **Фоны** — положи jpg/png в `assets/backgrounds/`  
   Имена: `зал.jpg`, `ванная.jpg` и т.д.  
   Потом в `main.gd` загружай TextureRect.

2. **Спрайты персонажей** — `assets/characters/lena/normal.png` и т.д.  
   В `_draw_characters()` вместо Button можно ставить TextureRect + Area2D для клика.

3. **Диалоги** — можно сделать отдельную сцену DialogueBox.

4. **Сохранение** — через `FileAccess` + JSON.

## Структура

```
adult_roommates_godot/
├── project.godot
├── scenes/main.tscn
├── scripts/
│   ├── main.gd
│   ├── game_state.gd
│   ├── character.gd
│   └── interactions.gd
└── assets/
```

## Дальше

Можно улучшать UI под стиль Living With Sister:
- Полноэкранный фон
- Большой спрайт справа
- Плавающее меню по центру
- Нижний диалоговый бокс
