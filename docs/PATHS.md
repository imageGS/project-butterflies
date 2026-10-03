# PATHS — ассеты и их расположение

> **Читать до того, как что-то искать.** Все пути здесь проверены по факту, не по памяти.

---

## 1. Главное: папки `assets_anchor/` не существует

В `05_PROTOTYPE_AUDIT.md`, `06_ROADMAP.md` и `references/README.md` встречаются ссылки на `assets_anchor/`. **Это артефакт сборки пакета — такой папки в репозитории нет.**

Все ассеты прототипа лежат в корне репозитория, на штатных местах. Увидел упоминание `assets_anchor/` — подставь путь из таблиц ниже.

---

## 2. Инвентарь ассетов

Всего в репозитории: **408 PNG**, 460 `.import`, 51 аудиофайл.

### 2.1. Спрайты персонажей в мире (4 направления)

| Путь | Файлов | Размеры |
|---|---:|---|
| `sprites/npc/kitsu/` | 4 | 404×774 (front), **572×858** (back), 200×616 (left/right) |
| `sprites/npc/hayato/` | 4 | 563×815 (front), 545×798 (back), 281×706 (left/right) |
| `sprites/npc/` | 2 | `9_sprite.png` 600×600, `17_sprite.png` 410×600 |

**Соглашение:** `_front`, `_back`, `_left`, `_right`. Вид спереди и сзади крупнее профиля — персонаж повёрнут к камере и занимает больше места.

### 2.2. Портреты для диалогов

| Путь | Файлов | Размеры |
|---|---:|---|
| `sprites/npc/kitsu/dialogue/` | 11 | 143–154 × 187–202 |

Одиннадцать эмоций, все выровнены по размеру:

`Afraid`, `Amused`, `Angry`, `Cautious`, `Compassionate`, `Confident`, `Determined`, `Neutral`, `Sad`, `Surprised`, `Tired`

**Это готовый образец того, насколько гранулярно должна работать диалоговая система.** Эмоция — параметр реплики, не отдельная картинка в коде.

### 2.3. Предметы (8)

| Путь | Размеры |
|---|---|
| `sprites/items/` | от 26×129 (нож) до 120×124 (бронежилет) |

| Файл | Размер | Предмет |
|---|---|---|
| `bandage.png` | 56×57 | Бинт |
| `card.png` | 62×47 | Ключ-карта |
| `helmet.png` | 66×67 | Шлем |
| `knife.png` | 26×129 | Нож |
| `medkit.png` | 74×67 | Аптечка |
| `pistol.png` | 90×59 | Пистолет |
| `sack.png` | 64×65 | Мешок |
| `vest.png` | 120×124 | Бронежилет |

### 2.4. Объекты в мире (по 4 направления)

| Путь | Файлов |
|---|---:|
| `sprites/entity/backpack/` | 4 |
| `sprites/entity/ceiling_lamp/` | 1 |
| `sprites/entity/locker/` | 4 |
| `sprites/entity/trash_bin/` | 4 |
| `sprites/entity/tv/` | 5 (front_on / front_off) |
| `sprites/entity/wall_sconce/` | 3 |
| `sprites/entity/wending_machine/` | 4 |

Размеры 52×104 … 168×240.

### 2.5. Интерфейс

| Путь | Файлов | Что |
|---|---:|---|
| `assets/UI/` | 12 | HUD, диалоги, инвентарь, окна |
| `assets/UI/cursor/` | 10 | Курсоры (23–45 px) |
| `assets/UI/context/` | 5 | Иконки контекст-меню (23–37 px) |

**UI корень:**

| Файл | Размер | Что |
|---|---|---|
| `MAIN_HUD.png` | 514×289 | Основной HUD |
| `INV_BOX.png` | 205×176 | Инвентарь |
| `CHAR_BOX.png` | 74×176 | Панель персонажа |
| `DIALOGUE_BOX.png` | 205×53 | Диалоговое окно |
| `DIALOGUE_PORTRAIT_WINDOW.png` | 92×108 | Окно портрета |
| `UL_WINDOW.png` / `UL_BALL.png` | 90×97 / 51×51 | Верх-лево |
| `UR_BALL.png`, `DL_BALL.png`, `DR_BALL.png` | 43–44 | Остальные шары |
| `DL_WINDOW.png` | 91×94 | Низ-лево |
| `flashlight.png` | 24×83 | Индикатор фонаря |

**Курсоры (10):** `cursor_eye`, `cursor_gear`, `cursor_hand`, `cursor_left`, `cursor_locked`, `cursor_no_action`, `cursor_pinch`, `cursor_pointer`, `cursor_right`, `cursor_talk`

**Иконки действий (5):** `action_fist`, `action_hand`, `action_key`, `action_lockpick`, `action_talk`

### 2.6. Анимации рук от первого лица

**Самый ценный контент прототипа.** Все кадры **515×237**, точка отсчёта стабильна.

| Путь | PNG | Шагов анимации |
|---|---:|---:|
| `assets/hands/click/` | 18 | 18 |
| `assets/hands/heal/` | 54 | 54 |
| `assets/hands/punch/` | 18 | 18 |
| `assets/hands/take/` | 14 | 14 |
| `assets/hands/use/` | 14 | 14 |
| `assets/hands/lockpick/lockpick_start/` | 9 | 9 |
| `assets/hands/lockpick/lockpick_loop/` | 48 | 48 |
| **Итого** | **175** | |

Взлом вызывается связкой: `lockpick_start` → `lockpick_loop` (цикл) → `lockpick_start` в обратном порядке.

> **Осторожно при подсчёте:** команда `ls | grep -c png` считает и `X.png`, и `X.png.import`, то есть удваивает результат. Реальное число кадров — 175, не 350.

### 2.7. Текстуры (99 PNG, все 256×256)

| Путь | PNG | Что |
|---|---:|---|
| `assets/textures/256x256/Wall/` | 14 | `Horror_Wall_01..14` |
| `assets/textures/256x256/Floor/` | 13 | `Horror_Floor_*` |
| `assets/textures/256x256/Metal/` | 14 | `Horror_Metal_*` |
| `assets/textures/256x256/Brick/` | 14 | Кирпич |
| `assets/textures/256x256/Stone/` | 14 | Камень |
| `assets/textures/256x256/Misc/` | 15 | Разное |
| `assets/textures/256x256/Stains/` | 15 | Пятна, загрязнения |

Плюс без указания размера: `assets/textures/decal/` (лежак, трещины, мусор, лужи), `assets/textures/wall/`, `assets/textures/floor/`, `assets/textures/train/`, `assets/textures/main_menu/`.

**Все тайловые, готовы для 3D почти без переделки.**

### 2.8. Шейдеры (11)

```
shaders/crtshader.gdshader          ← переносить: CRT-эффект
shaders/fog.gdshader                ← переносить
shaders/light_fog.gdshader          ← переносить
shaders/outline.gdshader            ← переносить: обводка при наведении
shaders/noise_transition.gdshader   ← переносить: переходы между сценами
shaders/ripple_button.gdshader      ← кнопки в меню
shaders/intro_background.gdshader   ← интро
shaders/glass_shatter.gdshader      ← интро (сцена со стеклом)
shaders/floor_shader.gdshader       ← только для рейкастера, выбросить
shaders/chase_glitch.gdshader       ← искажение при погоне, переосмыслить
shaders/melt.gdshader               ← использовался в боёвке, выбросить
```

### 2.9. Тексты и данные

| Путь | Что |
|---|---|
| `resources/items/items.json` | 8 предметов: названия, описания, **флейвор-тексты** (эталон тона) |
| `dialogues/kitsu/main.json` | Диалог Китсу |
| `dialogues/kitsu.json` | Диалог Китсу (альтернативный формат) |
| `dialogues/wanderer.json` | Странник |
| `dialogues/intro.json` | Интро |
| `resources/stations/maps/*.txt` | 5 ASCII-карт: планировки станций |

### 2.10. Аудио

| Путь | Файлов | Что |
|---|---:|---|
| `audio/sfx/footsteps/` | 15 | Шаги: `Tile_Mono_01..05`, `MetalSteps_01..05`, `LowMetal_Mono_01..05` |
| `audio/ui/dialogue/` | 6 | glass_break, explosion, kitsu, punch_1, punch_2, silhouette |
| `audio/ui/` | 3 | click, select, intro |
| `audio/sfx/` | 1 | flashlight.mp3 |
| `audio/sfx/breath/` | 1 | breath_01.ogg |
| `audio/music/` | 1 | intro_loop_2.ogg |
| `audio/music/old/` | 3 | scav_fight_1/2.mp3, chase.mp3 (из боёвки) |
| `audio/gore/` | 24 | **Выбросить** — звуки боя |
| `audio/` | 1 | male-scream.mp3 |

### 2.11. Видео

| Путь | Что | Судьба |
|---|---|---|
| `videos/heal.ogv` | Лечение | Забрать, переиспользуемо |
| `videos/punch.ogv`, `punchL.ogv`, `punchL2.ogv`, `punch.mp4` | Удары | Из боёвки, выбросить |

### 2.12. Прочее

| Путь | Что |
|---|---|
| `sprites/backgrond/dark_tonnel_1.webp` | Фон меню (опечатка в имени папки — `backgrond`) |
| `sprites/player/player_inventory.png` | Фигура игрока для инвентаря |
| `sprites/guts.png`, `sprites/logo.png` | Кровь, логотип |
| `font/Silver.ttf` | Шрифт |
| `func_godot_2025_12.zip` | Аддон FuncGodot, 8.6 МБ |

---

## 3. Концепт-референсы автора

| Путь | Размеров | Что |
|---|---:|---|
| `docs/references/concept/` | 7 PNG + 1 JPG | 1456×816 … 1920×1080 |

Это **утверждённое визуальное направление**, а не вдохновляющий материал. Смотреть обязательно, решения по арту сверять с ними.

---

## 4. Версия движка

```
project.godot: config_version=5, features = "4.7", Forward Plus
```

**Godot 4.7**, рендерер Forward+.

---

## 5. Что искать не надо

| Упоминается | Где на самом деле |
|---|---|
| `assets_anchor/` | Не существует. Смотри таблицы выше |
| `assets/textures/wall/default.png` | Есть, но это дефолт-заглушка |
| `audio/music/scav_fight_1.mp3` | `audio/music/old/scav_fight_1.mp3` — **баг прототипа**, ломавший боевую сцену |
| `res://main.gd` в корне | Не существует, лежал бы в `scripts/scenes/main.gd` |
| `UI_BACK.png` в корне | Есть в `assets/textures/UI_BACK.png` |
