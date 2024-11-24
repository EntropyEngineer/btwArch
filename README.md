# btwArch

Скрипт установки и конфигурирования Arch Linux

## Описание
Скрипт позволяет произвести установку Arch Linux в автоматическом режиме, предварительно указав необходимые значения конфигурации.

Скрипт имеет некоторые, неизменяемые через значения конфигурации, особенности:
- установка микрокода intel
- работа только с EFI загрузкой
- установка загрузчика grub
- основная файловая система btrfs
- отсутствует swap раздел, вместо него используется zram
- включена поддержка работы со снимками файловой системы snapper
- под драйвером nvidia подразумевается новый драйвер для карт >= 30xx серии

## Как пользоваться
1. Подготовьте скрипт к работе, для этого измените значения параметров в начале скрипта на необходимые вам. Скрипт можно отредактировать непосредственно перед запуском после следующего шага, не обязательно делать это заранее.
2. Загрузитесь в среду установки Arch Linux, используя загрузочный образ. Скопируйте скрипт в сеанс установки. Сделать это можно несколькими способами: скачать скрипт из репозитория или запустить ssh сервер и передать по протоколу sftp.
3. Сделайте скрипт исполняемым, проверьте значения конфигурации и запустите скрипт.
4. После завершения первого этапа установки будет предложено перезагрузить машину. После перезагрузки войдите в систему пользователем root, установка продолжится.

Лог установки можно посмотреть в файле /var/tmp/btwarch.log

### Включение доступа для загрузки скрипта по sftp

```bash
# задаём пароль пользователя root
passwd
# запускаем ssh сервер
systemctl start sshd
# смотрим сетевой адрес
ip a show
```

## Что происходит при выполнении скрипта

### Первый этап
- Проверка режима загрузки (поддерживается только EFI)
- Выбор диска для установки (если не прописан в параметрах)
- Стирание диска
- Разметка диска
- Создание файловых систем (fat32 для загрузчика и btrfs для системы)
- Создание подтомов btrfs
- Создание точек монтирования
- Установка минимально необходимых пакетов
- Сохранение точек монтирования

#### Переход в окружение archroot
- Установка загрузчика (grub)
- Установка пароля пользователя root

#### Перезагрузка в установленную систему

### Второй этап
- Удаление скрипта из автозагрузки
- Создание пользователя
- Включение sudo
- Настройка сетевой идентификации
- Запуск сети
- Установка часового пояса
- Настройка локализации
- Настройка менеджера пакетов (pacman)
- Настройка зеркал репозитория (reflector)
- Установка пакетного менеджера (yay)
- Установка виртуального файла подкачки (zram)
- Установка приложения для создания снимков состояния (snapper)
- Установка графического режима загрузки системы (если включено в параметрах)
- Добавление Windows в меню загрузки (если включено в параметрах)
- Установка драйвера nvidia или virtualbox guest additions
- Установка звуковой подсистемы (если включено в параметрах)
- Установка службы проверки орфографии (если включено в параметрах)
- Установка службы печати (если включено в параметрах)
- Установка окружения KDE (если включено в параметрах)