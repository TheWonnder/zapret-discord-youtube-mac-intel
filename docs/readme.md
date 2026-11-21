# ZapretMac для macOS 12+

ZapretMac помогает открывать Discord и YouTube без VPN. Приложение находится в строке меню macOS и поддерживает Intel и Apple Silicon.

Это форк [macOS-версии Flowseal](https://github.com/Flowseal/zapret-mac-discord-youtube), использующий движок [bol-van/zapret](https://github.com/bol-van/zapret).

## Установка

1. Скачайте [ZapretMac-macOS12-universal.dmg](https://github.com/TheWonnder/zapret-discord-youtube-mac-intel/releases/latest).
2. Откройте DMG и перетащите **ZapretMac** в папку **Applications**.
3. Запустите приложение. Если macOS не разрешает запуск, нажмите по нему правой кнопкой и выберите **«Открыть»**.
4. Отключите другие VPN с туннелированием.
5. Настройте DNS. Если обычный DNS не работает, установите [профиль Google DNS over HTTPS](https://github.com/paulmillr/encrypted-dns).

## Как пользоваться

Нажмите на букву **Z** в строке меню:

- **«Запустить»** — включает обход.
- **«Остановить»** — выключает обход и убирает его сетевые правила.
- **«Выбор стратегии»** — меняет способ обхода. Сначала попробуйте **SIMPLE FAKE**.
- **«Тест стратегий»** — проверяет доступные варианты и показывает, какие сработали лучше.
- **«Обновить конфиги»** — скачивает новые стратегии, списки и ресурсы из [Windows-сборки Flowseal](https://github.com/Flowseal/zapret-discord-youtube) и автоматически переводит их на macOS.
- **«Открыть списки»** — открывает папку с вашими настройками.

Если сайты не открываются, попробуйте другую стратегию или запустите тест. После обновления конфигов активный обход перезапускается автоматически.

Обновление конфигов не трогает ваши файлы `*-user.txt`.

## Свои домены и IP

Списки находятся в:

```text
~/Library/Application Support/ZapretMac/lists
```

Обычно достаточно изменить эти файлы:

- `list-general-user.txt` — домены, которые нужно добавить в обход.
- `list-exclude-user.txt` — домены, которые не нужно обрабатывать.
- `ipset-exclude-user.txt` — IP и подсети, которые не нужно обрабатывать.

Поддомены учитываются автоматически. После изменения списка повторно выберите текущую стратегию, чтобы применить изменения.

### Режим IPSet

- **none** — стандартный режим, рекомендуется начинать с него.
- **loaded** — дополнительно использовать адреса из `ipset-all.txt`.
- **any** — применять IP-правила ко всем адресам, кроме исключений. Может мешать другим сайтам.

GameFilter пока не поддерживается.

## Обновления приложения

На macOS 14+ приложение проверяет новые версии в этом репозитории. На macOS 12 и 13 автоматическое обновление приложения отключено, но кнопка **«Обновить конфиги»** работает.

## Сборка из исходников

Нужны Xcode Command Line Tools. Сборка:

```bash
./macos/build.sh
```

Результат появится в `dist`:

- `ZapretMac-macOS12-universal.dmg` — установочный образ.
- `ZapretMac-macOS-universal.zip` — ZIP с приложением.

## Остановка и удаление

Обычно достаточно выбрать **«Остановить»** в меню и удалить `ZapretMac.app`.

Если приложение закрыто, а обход остался активен:

```bash
sudo "/Library/Application Support/ZapretMac/stop.sh"
```

Пользовательские списки можно удалить отдельно:

```text
~/Library/Application Support/ZapretMac
```

## Источники

- [bol-van/zapret](https://github.com/bol-van/zapret) — основной движок.
- [Flowseal/zapret-mac-discord-youtube](https://github.com/Flowseal/zapret-mac-discord-youtube) — основа приложения.
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) — стратегии и списки для обновлений.
- [NewHichLan/zapret-mac-discord-youtube](https://github.com/NewHichLan/zapret-mac-discord-youtube) — отдельная адаптация исходного приложения для macOS 12.
