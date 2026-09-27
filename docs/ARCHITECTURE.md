# Teacher Prompter: архитектура MVP

Платформа: iPadOS 17.4+, Swift 5 (language mode), SwiftUI, SwiftData, Observation. Сервера нет, все данные хранятся локально на устройстве.

## 1. Архитектура приложения

Слои, от данных к экрану:

```
┌──────────────────────────── SwiftUI Views ─────────────────────────────┐
│ Library (уроки) · Editor · Import/Preview · Lesson Mode · Settings     │
└───────────────┬───────────────────────────────┬────────────────────────┘
                │                               │
      LessonSession (@Observable)        ImportDraft (@Observable)
      Current + Next, Undo, Pause,       черновик импорта: типы, порядок,
      таймер, часы урока                 merge/split — до сохранения
                │                               │
      LessonStore (структурные операции) LessonMaterialAnalyzer (протокол)
                │                         ├─ RuleBasedAnalyzer ← ScriptBuilder
                │                         └─ AIAssistedAnalyzer (этап 2)
                │                               │  VerbatimGuard (проверка дословности)
                │                         DocumentExtractor: PDF · PPTX · DOCX · TXT · MD
                ▼                               │  (ZipArchive + OOXMLExtractor, PDFKit)
      SwiftData: Lesson → LessonSection → LessonBlock, SourceDocument
```

Принципы:

- **Модели — единственный источник правды.** Статусы блоков, позиция урока (`currentBlockID`) и прошедшее время хранятся в SwiftData. Урок всегда продолжается с того же места, в том числе после закрытия приложения.
- **Временное состояние живёт в `LessonSession`:** отмена, баннер этапа, таймер, направление анимации.
- **Импорт отделён от хранения.** Анализатор выдаёт `ParsedScript`, учитель правит его в `ImportDraft`, и только потом `commit` создаёт модели.
- **Парсер не зависит от UI** (`ScriptBuilder`, `PedagogicalVocabulary`, `VerbatimGuard`) и покрыт тестами.
- **Язык интерфейса** задаёт собственный `Localizer` с типизированными ключами `enum L`: отсутствующий перевод — ошибка компиляции. Текст урока через него никогда не проходит.

## 2. Структура SwiftUI Views

```
TeacherPrompterApp
└─ RootView                           (демо-урок при первом запуске)
   └─ LessonsListView                 NavigationStack, группы «Fach + Klasse», поиск
      ├─ LessonRow                    кнопка «Starten»
      ├─ LessonEditorView             (push) метаданные, Sections, Blocks, drag & drop
      │  ├─ BlockRow / AddBlockMenu
      │  ├─ BlockEditorView           (sheet) текст, тип, слайд, таймер, «Show original», перевод
      │  ├─ ImportView(.append)       (sheet) добавить материал в урок
      │  └─ LessonModeView            (fullScreenCover)
      ├─ NewLessonSheet               (sheet)
      ├─ ImportView(.newLesson)       (sheet)
      │  └─ ImportPreviewView         (push) тип, секция, слайд, порядок, merge/split
      │     └─ DraftBlockEditor       (sheet)
      ├─ SettingsView                 (sheet) тема, язык UI, режимы урока
      └─ LessonModeView               (fullScreenCover)
         ├─ header: title · section · TimerPill · 12 / 34 · 18 / 45 min · A− A+ · 👁 · ▸ · ⏸ · …
         ├─ ThinProgressBar
         ├─ previous (серый, опционально зачёркнутый)
         ├─ CurrentBlockView          ~75 % высоты, крупный шрифт
         ├─ NextBlockView             ~22–24 %, мельче и бледнее, «NÄCHSTE FOLIE → 8»
         ├─ bottom bar                Zurück · подсказка · Überspringen · Erledigt
         ├─ overlays: SectionBannerView · UndoToast · PauseOverlay
         └─ .inspector → LessonOverviewView
```

## 3. Модели данных (SwiftData)

| Модель | Поля |
|--------|------|
| `Lesson` | `id, title, subject, classLevel, language, sections, currentBlockID, createdAt, modifiedAt, sourceDocuments, plannedMinutes, elapsedSeconds` |
| `LessonSection` | `id, title, order, lesson, blocks` |
| `LessonBlock` | `id, type (typeRaw), originalText, text, expectedAnswer, isCompleted, isImportant, isSkipped, estimatedDuration, timerDuration, slideNumber, notes, sourceDocumentID, order, textEditedAt, section` |
| `SourceDocument` | `id, filename, type (typeRaw), language, importedAt, lesson` |

- `BlockType` задаёт 9 типов: `say, question, expectedAnswer, action, experiment, slide, note, timer, transition`.
- `BlockStatus` задаёт 4 статуса: `upcoming, current, completed, skipped`. Статус `current` вычисляется по `Lesson.currentBlockID`, остальные — по флагам блока.
- Порядок хранится в полях `order`, потому что SwiftData не сохраняет порядок to-many связей. Отсортированные списки дают `orderedSections` и `orderedBlocks`.
- Связи Lesson → Section → Block и Lesson → SourceDocument удаляются каскадно.
- Черновик импорта описывают отдельные value-типы: `DraftSection` и `DraftBlock` (с флагом `isVerbatim`), `ParsedScript`, `ExtractedDocument`.

## 4. Навигация между экранами

- **Уроки → Редактор:** `NavigationStack(path:)` с `navigationDestination(for: Lesson.self)`.
- **Уроки или Редактор → Lesson Mode:** `fullScreenCover`. На время урока отключается автоблокировка экрана (`isIdleTimerDisabled`).
- **Импорт:** sheet со своим `NavigationStack`: ввод → `navigationDestination(item:)` → Preview. После сохранения sheet закрывается, и новый урок открывается в редакторе.
- **Lesson Mode → Обзор:** `.inspector` (боковая колонка на iPad). **Lesson Mode → быстрое редактирование:** `contextMenu` → sheet `BlockEditorView`.
- Каждый sheet и cover получает `.appEnvironment()`, то есть язык UI и тему.

## 5. Логика Current + Next (`LessonSession`)

- `blocks` — все блоки урока в порядке секций и блоков.
- `current` — блок из `currentBlockID`, а если его нет, первый блок, который не `completed` и не `skipped`.
- `next` — следующий открытый блок после `current`. Если после него открытых нет, берётся открытый блок до него: так учитель не потеряет пропущенное после прыжка вперёд.
- `previousDone` — последний выполненный блок перед текущим (серая строка сверху).
- `effectiveSlide(of:)` — собственный `slideNumber` блока или последний номер слайда перед ним. `upcomingSlideChange` показывает «NÄCHSTE FOLIE → n», если у следующего блока другой слайд.
- `progress` — доля выполненных и пропущенных блоков. `position / total` даёт строку «14 / 32». Время считается как `elapsedSeconds` без пауз против `plannedMinutes`.

| Действие | Жест / клавиша | Эффект |
|----------|----------------|--------|
| `completeCurrent` | tap, Pencil, свайп ←, Space, → | current → completed, next → current. При смене секции крупно показывается её название |
| `goBack` | свайп →, ←, tap по серой строке | предыдущий блок снова становится current |
| `skipCurrent` | меню, кнопка | current → skipped |
| `moveCurrentToLater` | долгое нажатие | блок уходит в конец своей секции и остаётся открытым |
| `jump(to:)` | обзор | любой блок становится current, статусы остальных не меняются |
| `performUndo` | тост 6 с, ⌘Z | восстанавливает снимок (статусы, порядок, позицию) до последнего действия |
| `pause` / `resume` | ⏸, P | часы урока останавливаются, позиция сохраняется |
| `startTimer` | кнопка в Timer-блоке | таблетка обратного отсчёта в шапке. По окончании она тихо пульсирует, плюс haptic, где он есть |

Анимация: сначала задаётся направление, затем на следующем цикле run loop меняется блок. Текущий блок уходит вверх и растворяется, следующий поднимается снизу; при движении назад — наоборот.

Focus Mode скрывает шапку и нижнюю панель. На экране остаются текущий и следующий блоки, тонкий прогресс, слайд и таймер. Касание шапки или зоны Next показывает элементы управления на 4 секунды.

## 6. Поддержка немецкого языка

- **Язык интерфейса** (Deutsch / English / системный) не зависит от **языка урока** (`Lesson.language`). Возможна любая комбинация.
- При импорте язык определяется через `NLLanguageRecognizer` отдельно для каждого файла и для урока в целом. Перевод при этом никогда не запускается.
- Текст хранится и показывается как есть: `Text(String)` не интерпретирует Markdown. Кавычки „…“, символы ä ö ü Ä Ö Ü ß и регистр не меняются. В полях ввода автокоррекция выключена.
- Текстовые файлы читаются как UTF-8 (с BOM или без), UTF-16, а для старых немецких файлов Windows — как Windows-1252.
- Поиск использует `localizedStandardContains`: он не зависит от регистра и диакритики, поэтому «uberleitung» находит «Überleitung».
- Парсер знает немецкую педагогическую лексику (`PedagogicalVocabulary`). Сравнение идёт через свёртку: регистр, умлауты и `ß → ss`.
  - **Этапы:** Einstieg, Wiederholung, Hinführung, Erarbeitung, Sicherung, Transfer, Vertiefung, Abschluss, Experiment, Hausaufgabe и другие. Поддерживаются варианты «1. Einstieg (5 min)», «Phase 3: Sicherung», «## Erarbeitung II», «EINSTIEG».
  - **Метки:** Lehrertext, Lehrerimpuls, Lehrerfrage, Frage, (erwartete) Schülerantwort, Erwartungshorizont, Arbeitsauftrag, Experiment, Versuch, Beobachtung, Auswertung, Erklärung, Definition, Merksatz, Material, Arbeitsblatt, Partner-, Gruppen- и Einzelarbeit, Hausaufgabe, Hinweis, Überleitung и английские аналоги.
  - **Слайды:** «Folie 4», «Nächste Folie: 5», «Zu Folie 6 wechseln», «Slide 3».
  - **Время:** «5 Minuten», «10 min», «3'», «90 Sekunden».

## 7. Защита оригинального текста

1. `LessonBlock.originalText` записывается один раз, при импорте, и приложение его больше не меняет.
2. `text` меняется только в двух местах: в `applyUserEdit(_:)`, который вызывается по кнопке «Fertig» в редакторе, и в `restoreOriginal()` по кнопке «Original wiederherstellen». Других путей записи нет.
3. Редактор блока показывает оригинал («Original anzeigen») и отметку «bearbeitet».
4. Парсер меняет только **структуру**: убирает метки вроде «Lehrertext:» и пробелы по краям. Метки, которые несут смысл («Merksatz: …», «Gruppenarbeit – 5 Minuten»), остаются в тексте. Слова, пунктуация и кавычки не трогаются.
5. Каждый результат анализатора, включая будущий AI, проходит через `VerbatimGuard`. Текст блока должен дословно встречаться в источнике (нормализуются только пробелы). Иначе в Preview появляется предупреждение «nicht wörtlich in der Quelle».
6. Merge и Split в Preview работают только со строками источника: Split режет по строкам, а для одной строки — по границам предложений (`NLTokenizer`).
7. Перевод доступен только по кнопке «Übersetzung anzeigen». Системный лист `translationPresentation` вызывается без `replacementAction`, поэтому перевод можно только посмотреть, заменить им текст нельзя.
8. `TextSuggestion` (в `AI/`) — модель для будущих подсказок AI. Решение по умолчанию — `.keepOriginal`. Текст меняется только при `.accept` или `.edited`, причём через тот же `applyUserEdit`.

## 8. Логика импорта материалов

```
Вставка / файлы ─► DocumentExtractor ─► [ExtractedDocument]
                    PDF: PDFKit (альбомные страницы считаются слайдами, книжные — текстом)
                    PPTX: ZIP → presentation.xml (порядок) → слайды (заголовок, содержимое)
                          → notesSlide (заметки докладчика, обычно это Lehrertext)
                    DOCX: ZIP → document.xml → абзацы; стили Heading/Überschrift → «# » (это секция)
                    TXT / MD: определение кодировки
          ─► LessonMaterialAnalyzer.analyze(docs, mode)
                    RuleBasedAnalyzer → ScriptBuilder (построчный разбор):
                      пустая строка → конец блока
                      маркер слайда → Slide-блок, дальше блоки наследуют slideNumber
                      заголовок этапа → новая Section
                      метка «X:» → тип блока, текст после двоеточия (или вся строка, если метка значимая)
                      без метки → Say, а если текст заканчивается на «?» → Question (только предложение типа)
                    VerbatimGuard.annotate
          ─► ImportDraft ─► ImportPreviewView
                    учитель меняет тип, удаляет, объединяет, делит, переставляет, правит текст
          ─► commit → Lesson (новый или дополненный) + SourceDocument
```

- Режимы: «Struktur erkennen» (по умолчанию) и «Jeder Absatz = ein Block» (простой вариант MVP из п. 14).
- Несколько файлов (например, `Zellmembran.pptx` и `Unterrichtsverlauf.docx`) разбираются последовательно. Сопоставлять их между собой (плана и слайдов) будет этап 2 с AI.
- **Этап 2 (`AIAssistedAnalyzer`):** модель должна возвращать только структуру — диапазоны в исходном тексте и тип. Блоки нарезаются из исходника, поэтому изменить слова невозможно по построению. После этого снова `VerbatimGuard`, затем тот же Preview.

## 9. Основные экраны: где код

| Экран | Файл |
|-------|------|
| Lesson Mode | `LessonMode/LessonModeView.swift`, `CurrentBlockView.swift`, `NextBlockView.swift`, `LessonOverviewView.swift`, `LessonModeOverlays.swift` |
| Логика урока | `LessonMode/LessonSession.swift` |
| Уроки | `Library/LessonsListView.swift`, `NewLessonSheet.swift` |
| Редактор | `Editor/LessonEditorView.swift`, `BlockEditorView.swift`, `BlockRow.swift` |
| Импорт | `Import/ImportView.swift`, `ImportPreviewView.swift`, `ImportDraft.swift`, `ScriptBuilder.swift`, `PedagogicalVocabulary.swift`, `DocumentExtractor.swift`, `OOXMLExtractor.swift`, `ZipArchive.swift`, `VerbatimGuard.swift` |
| Настройки | `Settings/SettingsView.swift`, `App/AppSettings.swift` |
| Локализация UI | `Localization/Localizer.swift` |

## Ограничения MVP

- Сопоставление нескольких документов между собой и AI-анализ отложены до этапа 2.
- Из PDF берётся только текстовый слой, OCR сканов не делается.
- Не поддерживаются `.key`, `.pages`, `.doc` и `.ppt`.
- Управления Keynote или PowerPoint нет. Для этого предусмотрены поле `slideNumber` и индикатор смены слайда.
- Перетаскивать блоки мышью или пальцем можно только внутри секции. Между секциями блок переносится через меню «In Abschnitt verschieben».
