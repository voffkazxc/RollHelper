# MicroSIP Assistant (Call Listener) - Handoff

Дата среза: 2026-08-08

## Смена парадигмы (Август 2026)
Старая архитектура на базе AHK (`main.ahk` + `call_listen_server.py`) **устарела**. Мы полностью отказались от AutoHotkey, SoundPad и локального HTTP-сервера для автослуха. 

Текущая активная разработка — это единое standalone Python-приложение с графическим интерфейсом на Tkinter: `tools/call_listener/microsip_assistant.py`.

## Цель модуля `microsip_assistant.py`
Автоматизировать процесс обзвона в MicroSIP:
1. Автоматически обнаружить начало звонка.
2. Проиграть предзаписанное голосовое приветствие прямо в микрофон MicroSIP.
3. Дождаться ответа клиента, захватывая звук через WASAPI Loopback.
4. Проанализировать ответ локальной VAD и Whisper-моделью.
5. Принять решение (Positive / Manual) и автоматически завершить звонок, если ответ распознан как позитивный.

## Архитектура
- **GUI:** `tkinter`, один главный поток. Отображает статус, эквалайзер, логи решений, позволяет настраивать горячие клавиши и выбирать устройства.
- **Audio Capture:** `pyaudiowpatch` (WASAPI Loopback). Выполняется в отдельном фоновом потоке. Инициализация COM-объектов `PyAudio` происходит строго внутри фонового потока, чтобы избежать ошибки `[Errno -9999] Unanticipated host error`. Формат выбирается динамически (Float32, Int16, Int32), каналы сводятся в моно для VAD.
- **Audio Playback:** `sounddevice` + `soundfile`. Запускается в фоновом потоке, проигрывает `greeting.wav` в виртуальный кабель (MicroSIP mic).
- **VAD (Voice Activity Detection):** `silero-vad` (PyTorch). Детектирует начало и конец речи клиента.
- **ASR (Speech Recognition):** `faster-whisper` (CTranslate2). Модель `base`, мультиязычный фоллбэк (ru -> uk -> auto). Переводит речь в текст.
- **Call State Tracking:** Отслеживает изменения в `AppData/Roaming/MicroSIP/microsip.ini` (ищет флаги `CALL_START` и `CALL_END`).
- **Hotkeys:** Библиотека `keyboard`. Настроены глобальные хуки для кнопок "Позвонить" (Ctrl+F6), "Сбросить" (End) и "Обновить" (Ctrl+F5).

## Состояние аудио-тракта
Из-за особенностей работы виртуальных кабелей (APO) SteelSeries Sonar, WASAPI Loopback на виртуальных эндпоинтах `[33] SteelSeries Sonar - Gaming [Loopback]` возвращал абсолютную тишину (RMS = 0). 

Рабочий захват звука осуществляется с физического устройства, куда Sonar маршрутизирует звук:
- `client_device` по умолчанию: `[29] Headset Earphone (Jabra Link 380) [Loopback]`.
Конфигурация хранится в `config.json`.

## Главные файлы
- `tools/call_listener/microsip_assistant.py`: Точка входа, весь UI и бизнес-логика.
- `tools/call_listener/test_loopback_capture.py`: Изолированный скрипт для отладки WASAPI Loopback, поиска активных устройств и вывода живого RMS/Peak. Используется для дебага без GUI.
- `tools/call_listener/config.json`: Файл настроек приложения (выбранные аудиоустройства, горячие клавиши). Создается автоматически.
- `tools/call_listener/stderr.log`: Перехват ошибок, падающих мимо GUI.

## Текущие ограничения и задачи
- Скрипт требует Python 3.13 с установленными зависимостями (`torch`, `faster-whisper`, `pyaudiowpatch`, `sounddevice`, `numpy`, `scipy`).
- Сейчас мы перешли к финальному тестированию интеграции с MicroSIP (обработка `CALL_START`, воспроизведение аудио и захват).
