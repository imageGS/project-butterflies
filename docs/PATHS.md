# Пути к ассетам

## Важно папки `assets_anchor` не существует

В `05_PROTOTYPE_AUDIT.md`, `06_ROADMAP.md` и `referencesREADME.md`
встречаются ссылки на `assets_anchor`. Это артефакт от сборки пакета —
папки с таким именем нет и не было.

Все ассеты прототипа лежат в корне этого репозитория, на штатных местах

 Что  Где  Сколько 
---------
 Спрайты предметов  `spritesitems`  8 
 Спрайты NPC (Китсу, Хаято, странник)  `spritesnpc`  42 
 Спрайты объектов  `spritesentity`  56 
 Интерфейс, курсоры, иконки  `assetsUI`  54 
 Анимации рук (7 наборов)  `assetshands`  350 
 Текстуры 256×256  `assetstextures`  246 
 Шейдеры  `shaders`  22 
 Диалоги (JSON)  `dialogues`  4 
 Тексты предметов  `resourcesitemsitems.json`  — 
 Звуки  `audio`  110 
 Планировки станций (ASCII)  `resourcesstationsmaps.txt`  5 

Читая упоминание `assets_anchor` — подставляй путь из этой таблицы.