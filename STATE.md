# Project Butterflies — State of the Game

> Снапшот фактического состояния кода. Дата: 2026-08-04.
> Видение и планы — в `DESIGN.md`. Этот файл — «что работает сейчас».

## Флоу сцен

```
main_menu.tscn (интро-статика → кнопки)
  → intro.tscn (нарративный диалог, бой стекла)      [только первая игра]
  → dungeon/dungeon_gameplay.tscn (рейкастер-станция)
       ↔ shelter.tres — убежище (отдых, ТВ, выход)
       → battle/node.tscn — бой (при контакте с врагом)
```

Сцены: `scenes/menu/main_menu.tscn`, `scenes/intro/intro.tscn`, `scenes/dungeon/dungeon_gameplay.tscn`, `scenes/dungeon/safe_station.tscn`, `scenes/battle/node.tscn`.

Автолоады (project.godot): `EventBus`, `CursorManager`, `TransitionManager`, `PlayerStats`, `TemplateLibrary`.

## Управление (факт)

> **CRT_Display** (`scripts/ui/crt_display.gd`): `mouse_filter = STOP`, перенаправляет мышь в SubViewport через `push_input` + `accept_event()`. Следствие: `_unhandled_input` в `dungeon_gameplay.gd` **не получает мышиных событий** — все мышиные действия обрабатываются polling'ом в `_process` (`Input.is_mouse_button_pressed`).

| Ввод | Действие |
|------|----------|
| ЛКМ | Контекстное действие (открыть дверь/взаимодействовать/поднять) |
| ПКМ (удержание) | Контекст-меню с иконками; отпускание на иконке = выбор действия |
| W/S / ↑↓ | Вперёд/назад |
| A/D / ←→ | Поворот (8° шаг, 0.05s интервал) |
| Q/E | Стрейф влево/вправо |
| Shift | Бег |
| Края экрана (мышь) | Плавный непрерывный доворот (EDGE_TURN_ZONE 40px, inset 24px) |
| Tab | Инвентарь |
| L | Фонарик (тратит заряд) |
| R | Поворот предмета (в инвентаре / при drag) |
| M | Окно верхнее-левое (миникарта) |
| H | Окно нижнее-левое (статы) |
| 1-6 | Выбор ответа в диалоге |
| Esc (в режиме броска) | Отмена броска |
| F / SPACE | Взаимодействие вперёд (`try_interact`) |

## Системы

| Система | Файл | Строк | Роль |
|---------|------|-------|------|
| Координатор станций | `scripts/dungeon/dungeon_gameplay.gd` | 636 | Собирает 12 систем, `_process`, `_refresh`, бросок, шум, день/ночь, тайлы дверей |
| Рейкастер | `scripts/dungeon/dungeon_renderer.gd` | 804 | Стены, пол, спрайты, ZBuffer, туман, контур, полёт-дуга |
| Стены (проекция) | `scripts/dungeon/wall_drawer.gd` | 31 | Отрисовка стен по ZBuffer |
| Карта | `scripts/systems/map_manager.gd` | 262 | Тайлы, двери, проходимость, генерация из ASCII |
| Движение | `scripts/systems/player_movement.gd` | 211 | WASD/QE, коллизии, bob, поворот |
| Сущности | `scripts/systems/entity_manager.gd` | 243 | Спавн врагов/NPC/объектов из EntitySpawn |
| Взаимодействие | `scripts/systems/interaction_system.gd` | 543 | Ховер, tooltip, курсор, клики, контекст-меню, двери, объекты |
| ИИ врагов | `scripts/systems/enemy_ai.gd` | 177 | Патруль, обнаружение (конус), погоня |
| Диалоги | `scripts/systems/dialogue_system.gd` | 571 | Ветвление, проверки навыков, печать, звук |
| HUD | `scripts/systems/hud_system.gd` | 139 | Окна, инвентарь, шары, тряска |
| Освещение | `scripts/systems/lighting_system.gd` | 113 | Шейдер тумана, фонарик, сущностный свет (до 47) |
| Звук | `scripts/systems/audio_system.gd` | 79 | Шаги, фонарик, дыхание, шаги врагов |
| Атмосфера | `scripts/systems/awareness_system.gd` | 36 | Пассивная Интуиция по таймеру (~8s), лог-строки |
| Переходы | `scripts/systems/transition_system.gd` | 37 | Переход между станциями + карточка |
| Курсор | `scripts/systems/cursor_manager.gd` | 86 | Контекстные курсоры (virtual-режим для CRT) |
| События | `scripts/systems/event_bus.gd` | 7 | Глобальные сигналы |

### UI-скрипты
| Файл | Строк | Роль |
|------|-------|------|
| `scripts/ui/context_menu.gd` | 159 | Контекст-меню hold-PKM: иконки, hover-scale, aspect-fit, фолбэк-квадраты |
| `scripts/ui/inventory_panel.gd` | 501 | Грид инвентаря: drag&drop, тултип, ПКМ (использовать/бросить/осмотреть) |
| `scripts/ui/inventory_grid.gd` | 99 | Логика грида 6×5 (стек, размеры, can_place) |
| `scripts/ui/equipment_slots.gd` | 174 | Экипировка HEAD/BODY/WEAPON |
| `scripts/ui/log_box.gd` | 123 | Лог с таймстемпами, автоскролл |
| `scripts/ui/minimap_control.gd` | 39 | Миникарта 25×13 |
| `scripts/ui/stats_panel.gd` | 46 | Статы персонажа |
| `scripts/ui/cursor_visual.gd` | 39 | Виртуальный курсор внутри GameViewport |
| `scripts/ui/crt_display.gd` | 13 | CRT-оверлей + редирект мыши |
| `scripts/ui/flashlight_bar.gd` | 30 | Шкала фонарика |
| `scripts/ui/dust_particles.gd` | 170 | Пыль/туман пола |
| `scripts/ui/ripple_button.gd` | 90 | Кнопки с ripple-эффектом |
| `scripts/ui/station_card.gd` | 63 | Карточка станции при переходе |

### Прочее
- `scripts/managers/item_catalog.gd` (67) — предметы из `items.json`
- `scripts/managers/skill_check.gd` (47) — d20 + навык ≥ DC, криты
- `scripts/managers/transition_manager.gd` (59) — fade-to-black
- `scripts/scenes/player_stats.gd` (115) — глобальное состояние, инвентарь, флаги
- `scripts/scenes/item.gd` (41), `scripts/scenes/combatant.gd` (73), `scripts/scenes/limb.gd` (40)
- `scripts/scenes/main.gd` (1060) — бой
- `scripts/scenes/main_menu.gd` (73), `scripts/intro/intro.gd` (113)
- `scripts/battle/` — `block_minigame.gd` (181), `crosshair.gd` (93)
- `scripts/editor/` — `station_editor.gd` (1601), `dialogue_editor.gd` (673)

## Контент

- **Предметы** (`resources/items/items.json`): 9 — medkit, bandage, pistol, vest, card, sack, knife, battery, helmet.
- **Станции** (`resources/stations/`): shelter, akio, new_station, train_car, tunnel_akio_shelter (+ карты ASCII).
- **Шаблоны сущностей** (`resources/templates/entities/`): контейнеры (backpack, locker, medkit_container, trash_bin, wending_machine), предметы (8), свет (ceiling_lamp, wall_sconce), npc (kitsu), rest (bed), tv.
- **Бестиарий** (`resources/bestiary/`): только `rat.tres` (6 конечностей с действиями).
- **Диалоги** (`dialogues/`): `intro.json`, `kitsu/main.json`.
- **Текстуры/спрайты**: стены, пол, NPC, враги (bunny/scav), предметы, деколи, UI-курсоры, CRT.

## Реализованные механики (недавние)

- **Двери/замки**: тайлы `TILE_DOOR`/`TILE_LOCKED`, `open_door`, `_setup_doors`; ключ-карта (`card`), взлом (Находчивость vs lock_dc), выбить (Стойкость vs smash_dc + шум). Состояние в `PlayerStats.flags` (`door_x_y_open`).
- **Контекст-меню**: hold-PKM, горизонтальный ряд иконок, hover-scale, выбор по отпусканию. Маппинг по объекту: дверь (карта/взлом/кулак), объект (взаимодействие/кулак), NPC (разговор), враг (атака). Иконки — фолбэк-квадраты до добавления PNG в `assets/UI/context/`.
- **Бросок**: из инвентаря (ПКМ → «Бросить»), направление = взгляд игрока, DDA до последнего проходимого тайла, `THROW_MAX_DIST = 4.0`, полёт с дугой (`ceiling_lift = sin(t·π)`, высота `0.4 + dist·0.08`), предмет остаётся на полу как `ground_item` (size 0.3), шум при приземлении.
- **CRT-редирект**: мышь перенаправляется через `push_input`, все мышиные действия — через polling в `_process`.
- **День/ночь**: `game_time`, фактор дня, изменение `light_ambient`/`player_light_intensity`/fog.
- **Шум**: `_emit_noise(x, y, radius)` → список `_noise_events` (TTL 3s). **Пока никто не реагирует.**
- **Фонарик**: заряд (`flashlight_energy`), батарейки, aim по мыши.
- **Миникарта**, **контурная обводка** при ховере, **прыжок bob**, **анимация движения врагов** (smoothstep).

## Известные пробелы / мёртвый код

- **Шум «мёртвый»**: события записываются, но не читаются — враги не идут на источник шума (нет INVESTIGATE-состояния). `radius` не используется.
- **Контейнеры = одноразовый лут**: `interact_object` "container" берёт первый предмет из `data.loot` и кладёт в инвентарь. Настоящего инвентаря у контейнера нет (см. план в DESIGN.md).
- `enemy_ai.gd:167` — `stuck_count` сбрасывается, но не используется.
- Свет: хуки `emergency` и `flicker` задекларированы, но не потребляются на рендере.
- `dungeon_gameplay.gd:52` — `shelter_mode` deprecated.
- Артефакты в корне: `func_godot_2025_12.zip`, `tmp_test_templates.gd.uid`, `.tmp`-файлы сцен.
- DESIGN.md местами устарел (WASD-управление, `test_dungeon_mechanics.gd`) — см. актуальный DESIGN.md.

## Верификация

Головной запуск сцены:
```
"D:\Project Butterflies\Godot_v4.7-stable_win64.exe" --headless --quit-after 100 --path "D:\Project Butterflies\project-butterflies" "res://scenes/dungeon/dungeon_gameplay.tscn"
```
Ожидание: выход без ошибок (EXIT:0).
