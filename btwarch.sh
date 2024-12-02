#!/bin/bash

# ------------------------------------------------------
# Скрипт установки Arch Linux
# ------------------------------------------------------

TARGET_DISK="" # Если диск не указан, появится меню выбора диска
ADD_WINDOWS_TO_BOOT="y"
ENABLE_MOUNT_INTERNAL="y"
INSTALLING_GRAPHICAL_BOOT="y"
ROOT_PASSWORD="root"
USERNAME="test"
USER_PASSWORD="test"
HOSTNAME="ARCH_TEST"
TIMEZONE="Asia/Yekaterinburg"
LOCALE="ru_RU.UTF-8"
KEYMAP="ruwin_alt_sh-UTF-8"
TERMINAL_FONT="cyr-sun16"
REFLECTOR_COUNTRY="Russia"
VIDEO_DRIVER="vbox" # nvidia / vbox
INSTALLING_SOUND_SERVER="y"
INSTALLING_SPELL_CHECKER="y"
INSTALLING_PRINT_SERVER="y"
DE="kde" # kde / ""

# ------------------------------------------------------
# Флаги пересборки
# ------------------------------------------------------

UPDATE_GRUB=false
UPDATE_MKINITCPIO=false

# ------------------------------------------------------
# Первый этап установки
# ------------------------------------------------------

stage_1() {
    output_to_file

    logo
    show_constants
    uefi_check

    if [ "$TARGET_DISK" = "" ]; then
        disk_selection
    fi

    erasing_disk
    creating_partitions
    setting_filesystems
    creating_btrfs_volumes
    mounting_partitions
    preinstall_configuration
    installing_basic_packages
    saving_mount_points

    launch_archroot
    ending_archroot
}

# ------------------------------------------------------
# Выполнение в окружении archroot
# ------------------------------------------------------

stage_1_archroot() {
    output_to_file

    installing_bootloader
    setting_root_password

    exit
}

# ------------------------------------------------------
# Второй этап установки
# ------------------------------------------------------

stage_2() {
    output_to_file

    logo "Второй этап установки"

    cleaning_script_autorun
    creating_user
    enable_sudoers
    setting_network_identification
    enable_network
    setting_timezone
    setting_locale
    setting_pacman
    setting_reflector
    installing_yay
    installing_zram
    installing_snapper

    if [ "$INSTALLING_GRAPHICAL_BOOT" = "y" ]; then
        installing_graphical_boot
    fi

    if [ "$ADD_WINDOWS_TO_BOOT" = "y" ]; then
        adding_windows_to_boot_menu
    fi

    if [ "$ENABLE_MOUNT_INTERNAL" = "y" ]; then
        enable_mounting_internal_drives
    fi

    if [ "$VIDEO_DRIVER" = "nvidia" ]; then
        installing_nvidia
    elif [ "$VIDEO_DRIVER" = "vbox" ]; then
        installing_vbox
    fi

    if [ "$INSTALLING_SOUND_SERVER" = "y" ]; then
        installing_sound_server
    fi

    if [ "$INSTALLING_SPELL_CHECKER" = "y" ]; then
        installing_spell_checker
    fi

    if [ "$INSTALLING_PRINT_SERVER" = "y" ]; then
        installing_print_server
    fi

    if [ "$DE" = "kde" ]; then
        installing_kde
    fi

    installation_complete
}

# ------------------------------------------------------
# Вывод логотипа
# ------------------------------------------------------

logo() {
    clear

    print question line "  _     _             _             _      " && echo
    print question line " | |__ | |___      __/ \   _ __ ___| |__   " && echo
    print question line " | '_ \| __\ \ /\ / / _ \ | '__/ __| '_ \  " && echo
    print question line " | |_) | |_ \ V  V / ___ \| | | (__| | | | " && echo
    print question line " |_.__/ \__| \_/\_/_/   \_\_|  \___|_| |_| " && echo

    if [ -n "$1" ]; then
        echo
        echo "-----------------------"
        print accent line " $1 " && echo
        echo "-----------------------"
        echo
    fi
}

# ------------------------------------------------------
# Вывод значений параметров
# ------------------------------------------------------

show_constants() {
    print info "Предустановленные значения:"

    echo
    echo -n "- Целевой диск: " && print accent line $TARGET_DISK

    if [ "$TARGET_DISK" = "" ]; then
        print accent line "будет выбран через меню"
    fi

    echo

    echo -n "- Установка графического режима загрузки системы: " && print accent line $INSTALLING_GRAPHICAL_BOOT && echo
    echo -n "- Добавить Windows в загрузочное меню: " && print accent line $ADD_WINDOWS_TO_BOOT && echo
    echo -n "- Пароль пользователя root: " && print accent line $ROOT_PASSWORD && echo
    echo -n "- Имя пользователя: " && print accent line $USERNAME && echo
    echo -n "- Пароль пользователя $USERNAME: " && print accent line $USER_PASSWORD && echo
    echo -n "- Сетевое имя компьютера: " && print accent line $HOSTNAME && echo
    echo -n "- Часовой пояс: " && print accent line $TIMEZONE && echo
    echo -n "- Язык системы: " && print accent line $LOCALE && echo
    echo -n "- Раскладка клавиатуры: " && print accent line $KEYMAP && echo
    echo -n "- Шрифт терминала: " && print accent line $TERMINAL_FONT && echo
    echo -n "- Страна поиска зеркал дистрибутива: " && print accent line $REFLECTOR_COUNTRY && echo
    echo -n "- Видеодрайвер: " && print accent line $VIDEO_DRIVER && echo
    echo -n "- Установка звуковой подсистемы: " && print accent line $INSTALLING_SOUND_SERVER && echo
    echo -n "- Установка службы проверки орфографии: " && print accent line $INSTALLING_SPELL_CHECKER && echo
    echo -n "- Установка службы печати: " && print accent line $INSTALLING_PRINT_SERVER && echo
    echo -n "- Графическое окружение: " && print accent line $DE && echo
}

# ------------------------------------------------------
# Проверка режима загрузки
# ------------------------------------------------------

uefi_check() {
    local platform_size=$(cat /sys/firmware/efi/fw_platform_size)

    if [[ $platform_size -ne 64 ]]; then
        print warning "Система должна быть запущена в режиме UEFI 64-бит"
        exit
    fi
}

# ------------------------------------------------------
# Выбор диска для установки
# ------------------------------------------------------

disk_selection() {
    local disks=($(lsblk -nd -o NAME,TYPE | awk '$2=="disk" {print "/dev/" $1}'))

    if [[ -z $disks ]]; then
        print warning "Подходящие для установки диски не найдены"
        exit
    fi

    echo
    lsblk -o NAME,SIZE
    echo

    for i in "${!disks[@]}"; do
        echo "$((i + 1)). ${disks[i]}"
    done

    echo "0. Отмена установки"

    while true; do
        echo
        print question line "Выберите диск для установки [0-${#disks[@]}]: "
        read -rp "" choice

        if [[ $choice =~ ^[0-9]+$ ]]; then
            if ((choice == 0)); then
                print info "Установка прервана" && echo && exit
            elif ((choice >= 1 && choice <= ${#disks[@]})); then
                TARGET_DISK="${disks[$((choice - 1))]}"
                break
            fi
        fi

        tput cuu1 && tput el && tput cuu1 && tput el
    done
}

# ------------------------------------------------------
# Предварительные настройки
# для повышения скорости установки
# ------------------------------------------------------

preinstall_configuration() {
    setting_pacman

    reflector --verbose --country $REFLECTOR_COUNTRY -l 10 --sort rate --save /etc/pacman.d/mirrorlist
}

# ------------------------------------------------------
# Стирание диска
# ------------------------------------------------------

erasing_disk() {
    echo
    print warning line "Все данные на диске "
    print accent line $TARGET_DISK
    print warning line " будут удалены!"
    echo

    while true; do
        echo
        print question line "Вы действительно хотите продолжить установку? (y/n):"
        read -rp "" confirm

        case $confirm in
            [Yy]*) return ;;
            [Nn]*) print info "Установка прервана" && echo && exit ;;
            *) tput cuu1 && tput el && tput cuu1 && tput el ;;
        esac
    done

    wipefs -a -f $TARGET_DISK
}

# ------------------------------------------------------
# Разметка диска
# ------------------------------------------------------

creating_partitions() {
    parted $TARGET_DISK --script mklabel gpt

    parted $TARGET_DISK --script mkpart primary fat32 1MiB 513MiB
    parted $TARGET_DISK --script set 1 esp on

    parted $TARGET_DISK --script mkpart primary 513MiB 100%
}

# ------------------------------------------------------
# Создание файловых систем
# ------------------------------------------------------

setting_filesystems() {
    if [[ $(basename "${TARGET_DISK}") =~ ^nvme ]]; then
        PARTITION1="${TARGET_DISK}p1"
        PARTITION2="${TARGET_DISK}p2"
    else
        PARTITION1="${TARGET_DISK}1"
        PARTITION2="${TARGET_DISK}2"
    fi

    mkfs.fat -F32 "$PARTITION1"
    mkfs.btrfs -f "$PARTITION2"
}

# ------------------------------------------------------
# Создание подтомов btrfs
# ------------------------------------------------------

creating_btrfs_volumes() {
    mount $PARTITION2 /mnt

    btrfs sub cr /mnt/@
    btrfs sub cr /mnt/@home

    btrfs sub cr /mnt/@snapshots

    btrfs sub cr /mnt/@pkg
    btrfs sub cr /mnt/@log
    btrfs sub cr /mnt/@cache
    btrfs sub cr /mnt/@tmp

    umount /mnt
}

# ------------------------------------------------------
# Создание точек монтирования
# ------------------------------------------------------

mounting_partitions() {
    local root_part=$PARTITION2
    local mount_options="noatime,nodiratime,compress=lzo,space_cache=v2,ssd"

    mount -o $mount_options,subvol=@ $root_part /mnt

    mount -o x-mount.mkdir,$mount_options,subvol=@home $root_part /mnt/home
    mount -o x-mount.mkdir,$mount_options,subvol=@snapshots $root_part /mnt/.snapshots
    mount -o x-mount.mkdir,$mount_options,subvol=/ $root_part /mnt/.btrfsroot
    mount -o x-mount.mkdir,$mount_options,subvol=@pkg $root_part /mnt/var/cache/pacman/pkg/
    mount -o x-mount.mkdir,$mount_options,subvol=@log $root_part /mnt/var/log
    mount -o x-mount.mkdir,$mount_options,subvol=@cache $root_part /mnt/var/cache
    mount -o x-mount.mkdir,$mount_options,subvol=@tmp $root_part /mnt/var/tmp

    mkdir -m 700 /mnt/efi
    mount $PARTITION1 /mnt/efi
}

# ------------------------------------------------------
# Установка минимально необходимых пакетов
# ------------------------------------------------------

installing_basic_packages() {
    pacstrap /mnt base linux linux-firmware intel-ucode sudo networkmanager
}

# ------------------------------------------------------
# Сохранение точек монтирования
# ------------------------------------------------------

saving_mount_points() {
    genfstab -U -p /mnt >>/mnt/etc/fstab
}

# ------------------------------------------------------
# Переход в окружение archroot
# ------------------------------------------------------

launch_archroot() {
    local script_path=$0
    local script_name=$(basename $script_path)
    local stage_2_path="/var/tmp/$script_name"

    cp $script_path "/mnt$stage_2_path"
    chmod +x "/mnt$stage_2_path"

    mv "/var/tmp/btwarch.log" "/mnt/var/tmp/btwarch.log"

    arch-chroot /mnt $stage_2_path stage_1_archroot
}

# ------------------------------------------------------
# Установка загрузчика
# ------------------------------------------------------

installing_bootloader() {
    pacman -S --noconfirm grub efibootmgr grub-btrfs os-prober
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch
    grub-mkconfig -o /boot/grub/grub.cfg
}

# ------------------------------------------------------
# Установка пароля пользователя root
# ------------------------------------------------------

setting_root_password() {
    echo "root:$ROOT_PASSWORD" | chpasswd
}

# ------------------------------------------------------
# Перезагрузка в установленную систему
# ------------------------------------------------------

ending_archroot() {
    mv "/mnt/var/tmp/btwarch.log" "/var/tmp/btwarch.log"

    echo
    print question line "Установка продолжится после перезагрузки и входа в систему пользователем root (Enter)"
    read -rp "" input

    local script_name=$(basename $0)
    local stage_2_path="/var/tmp/$script_name"
    local stage_param="stage_2"

    touch /mnt/root/.bash_profile

    if ! grep -q "$stage_2_path $stage_param" /mnt/root/.bash_profile; then
        echo "$stage_2_path $stage_param && sed -i '/$stage_2_path $stage_param/d' /mnt/root/.bash_profile" >>/mnt/root/.bash_profile
    fi

    mv "/var/tmp/btwarch.log" "/mnt/var/tmp/btwarch.log"

    umount -R /mnt
    reboot
}

# ------------------------------------------------------
# Удаление скрипта из автозагрузки
# ------------------------------------------------------

cleaning_script_autorun() {
    local script_path="$(realpath "$0")"

    sed -i "\|$script_path stage_2|d" /root/.bash_profile
}

# ------------------------------------------------------
# Создание пользователя
# ------------------------------------------------------

creating_user() {
    useradd -mg users $USERNAME
    usermod -aG power,wheel,audio,video,storage,optical,scanner,floppy,disk $USERNAME
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
}

# ------------------------------------------------------
# Включение sudo
# ------------------------------------------------------

enable_sudoers() {
    sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' "/etc/sudoers"
}

# ------------------------------------------------------
# Настройка сетевой идентификации
# ------------------------------------------------------

setting_network_identification() {
    echo $HOSTNAME >/etc/hostname

    echo "127.0.0.1 localhost" >>/etc/hosts
    echo "::1 localhost" >>/etc/hosts
    echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >>/etc/hosts
}

# ------------------------------------------------------
# Запуск сети
# ------------------------------------------------------

enable_network() {
    systemctl enable --now NetworkManager
}

# ------------------------------------------------------
# Установка часового пояса
# ------------------------------------------------------

setting_timezone() {
    timedatectl set-timezone $TIMEZONE
    timedatectl set-ntp true
    timedatectl set-local-rtc 0
}

# ------------------------------------------------------
# Настройка локализации
# ------------------------------------------------------

setting_locale() {
    sed -i '/^#en_US.UTF-8/s/^#//' /etc/locale.gen
    sed -i "/^#$LOCALE/s/^#//" /etc/locale.gen

    locale-gen

    echo "LANG=$LOCALE" >/etc/locale.conf

    localectl set-keymap $KEYMAP

    echo "FONT=\"${TERMINAL_FONT}\"" >>/etc/vconsole.conf
}

# ------------------------------------------------------
# Настройка менеджера пакетов
# ------------------------------------------------------

setting_pacman() {
    pacman-key --init
    pacman-key --populate archlinux

    local pacman_conf="/etc/pacman.conf"

    sed -i '/^#\[multilib\]/s/^#//' $pacman_conf
    sed -i '/^\[multilib\]/,/^$/ {/Include = \/etc\/pacman.d\/mirrorlist/s/^#//}' $pacman_conf

    sed -i '/^OPTIONS=/s/strip/!strip/; /^OPTIONS=/s/debug/!debug/' $pacman_conf

    sed -i '/^#ParallelDownloads/s/^#//; s/ParallelDownloads = [0-9]\+/ParallelDownloads = 15/' $pacman_conf
    sed -i '/^#Color/s/^#//' $pacman_conf
}

# ------------------------------------------------------
# Настройка зеркал репозитория
# ------------------------------------------------------

setting_reflector() {
    pacman -S --noconfirm reflector rsync
    reflector --verbose --country $REFLECTOR_COUNTRY -l 20 --sort rate --save /etc/pacman.d/mirrorlist
}

# ------------------------------------------------------
# Установка пакетного менеджера
# ------------------------------------------------------

installing_yay() {
    pacman -S --noconfirm base-devel git go

    run_as_user "cd /var/tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"

    rm -rf /var/tmp/yay
}

# ------------------------------------------------------
# Установка виртуального файла подкачки
# ------------------------------------------------------

installing_zram() {
    sh -c "echo 0 > /sys/module/zswap/parameters/enabled"
    modprobe zram
    run_as_user "yay -S --noconfirm zram-generator"

    local zram_config="/etc/systemd/zram-generator.conf"

    echo "[zram0]" >$zram_config
    echo "zram-size = ram * 2" >>$zram_config
    echo "compression-algorithm = zstd" >>$zram_config
    echo "swap-priority = 100" >>$zram_config
    echo "fs-type = swap" >>$zram_config

    systemctl start systemd-zram-setup@zram0

    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=0 /' /etc/default/grub
    UPDATE_GRUB=true

    local swap_config="/etc/sysctl.d/99-swappiness.conf"

    echo "vm.swappiness = 180" >$swap_config
    echo "vm.watermark_boost_factor = 0" >>$swap_config
    echo "vm.watermark_scale_factor = 125" >>$swap_config
    echo "vm.page-cluster = 0" >>$swap_config

    sysctl --syst
}

# ------------------------------------------------------
# Установка приложения для создания снимков состояния
# ------------------------------------------------------

installing_snapper() {
    run_as_user "yay -S --noconfirm snapper snap-pac snapper-rollback"

    umount /.snapshots
    rm -r /.snapshots

    snapper -c root create-config /
    snapper -c home create-config /home

    mount -a

    btrfs subvol set-default 256 /

    sed -i 's|mountpoint = /btrfsroot|mountpoint = /.btrfsroot|' /etc/snapper-rollback.conf

    sed -i 's|TIMELINE_CREATE="yes"|TIMELINE_CREATE="no"|' /etc/snapper/configs/root

    sed -i 's|TIMELINE_LIMIT_HOURLY="[^"]*"|TIMELINE_LIMIT_HOURLY="1"|' /etc/snapper/configs/home
    sed -i 's|TIMELINE_LIMIT_DAILY="[^"]*"|TIMELINE_LIMIT_DAILY="7"|' /etc/snapper/configs/home
    sed -i 's|TIMELINE_LIMIT_WEEKLY="[^"]*"|TIMELINE_LIMIT_WEEKLY="0"|' /etc/snapper/configs/home
    sed -i 's|TIMELINE_LIMIT_MONTHLY="[^"]*"|TIMELINE_LIMIT_MONTHLY="0"|' /etc/snapper/configs/home
    sed -i 's|TIMELINE_LIMIT_YEARLY="[^"]*"|TIMELINE_LIMIT_YEARLY="0"|' /etc/snapper/configs/home

    systemctl enable --now snapper-timeline.timer
    systemctl enable --now snapper-cleanup.timer

    UPDATE_GRUB=true
}

# ------------------------------------------------------
# Установка графического режима загрузки системы
# ------------------------------------------------------

installing_graphical_boot() {
    run_as_user "yay -S --noconfirm plymouth"

    sed -i '/^HOOKS=/ s/)/ plymouth)/' /etc/mkinitcpio.conf
    UPDATE_MKINITCPIO=true

    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&quiet splash rd.udev.log_priority=3 vt.global_cursor_default=0 /' /etc/default/grub
    UPDATE_GRUB=true
}

# ------------------------------------------------------
# Добавление Windows в меню загрузки
# ------------------------------------------------------

adding_windows_to_boot_menu() {
    local efi_partitions=$(blkid -t TYPE=vfat -o device)

    if [[ -z $efi_partitions ]]; then
        exit
    fi

    local i=1
    local mount_success=false

    for partition in $efi_partitions; do
        local mount_dir="/mnt/efi_$i"
        mkdir -p $mount_dir

        mount $partition $mount_dir
        if [[ $? -eq 0 ]]; then
            mount_success=true
        fi

        ((i++))
    done

    if $mount_success; then
        sed -i '/^#GRUB_DISABLE_OS_PROBER/s/^#//' /etc/default/grub

        os-prober
        grub-mkconfig -o /boot/grub/grub.cfg
        UPDATE_GRUB=false

        local i=1

        for partition in $efi_partitions; do
            local mount_dir="/mnt/efi_$i"

            if mountpoint -q $mount_dir; then
                umount $mount_dir
            fi

            # Удаляем временные директории
            rmdir $mount_dir

            ((i++))
        done

        sed -i '/^GRUB_DISABLE_OS_PROBER/s/^/#/' /etc/default/grub
    fi
}

# ------------------------------------------------------
# Включение возможности монтирования внутренних дисков
# без ввода пароля, например NTFS
# ------------------------------------------------------

enable_mounting_internal_drives() {
    local polkit_rule="/etc/polkit-1/rules.d/10-udisks2-internal.rules"

    echo 'polkit.addRule(function(action, subject) {' >$polkit_rule
    echo 'if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||' >>$polkit_rule
    echo 'action.id == "org.freedesktop.udisks2.filesystem-mount") &&' >>$polkit_rule
    echo 'subject.isInGroup("disk")) {' >>$polkit_rule
    echo 'return polkit.Result.YES;' >>$polkit_rule
    echo '}' >>$polkit_rule
    echo '});' >>$polkit_rule

    systemctl restart polkit
}

# ------------------------------------------------------
# Установка драйвера nvidia
# ------------------------------------------------------

installing_nvidia() {
    run_as_user "yay -S --noconfirm nvidia-open"
    echo "options nvidia-drm modeset=1 fbdev=1" >/etc/modprobe.d/nvidia-drm.conf
}

# ------------------------------------------------------
# Установка драйвера virtual box
# ------------------------------------------------------

installing_vbox() {
    run_as_user "yay -S --noconfirm virtualbox-guest-utils"
    modprobe -a vboxguest vboxsf vboxvideo
    systemctl enable vboxservice.service
}

# ------------------------------------------------------
# Установка звуковой подсистемы
# ------------------------------------------------------

installing_sound_server() {
    run_as_user "yay -S --noconfirm pipewire pipewire-alsa pipewire-pulse wireplumber pipewire-jack"
}

# ------------------------------------------------------
# Установка службы проверки орфографии
# ------------------------------------------------------

installing_spell_checker() {
    run_as_user "yay -S --noconfirm hunspell hunspell-ru hunspell-en hyphen hyphen-ru libmythes mythes-ru"
}

# ------------------------------------------------------
# Установка службы печати
#
# gutenprint - набор драйверов для множества моделей принтеров (включая Epson и Canon).
# hplip — драйверы для принтеров HP.
# brother-cups-wrapper и brother-cups-lpr — драйверы для принтеров Brother.
# epson-inkjet-printer-escpr — драйверы для струйных принтеров Epson.
# ------------------------------------------------------

installing_print_server() {
    run_as_user "yay -S --noconfirm cups cups-pdf ghostscript gsfonts"
    systemctl enable --now cups.service
}

# ------------------------------------------------------
# Установка окружения KDE
# ------------------------------------------------------

installing_kde() {
    # Установка зависимостей
    run_as_user "yay -S --noconfirm pipewire-jack ttf-joypixels qt6-multimedia-ffmpeg"
    # Установка окружения KDE
    run_as_user "yay -S --needed --noconfirm plasma-desktop discover plasma-nm plasma-pa kdeplasma-addons kde-gtk-config breeze-gtk plasma-browser-integration kwrited plasma-systemmonitor plasma-disks kscreen gsettings-desktop-schemas"

    # Назначение темы Breeze для GTK
    gsettings set org.gnome.desktop.interface gtk-theme Breeze

    # Установка менеджера входа
    run_as_user "yay -S --noconfirm sddm-kcm"
    systemctl enable sddm

    # Настройка менеджера входа на работу через Wayland
    mkdir -p /etc/sddm.conf.d
    local sddm_config="/etc/sddm.conf.d/10-wayland.conf"

    echo "[General]" >$sddm_config
    echo "DisplayServer=wayland" >>$sddm_config
    echo "GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell" >>$sddm_config
    echo >>$sddm_config
    echo "[Wayland]" >>$sddm_config
    echo "CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --inputmethod qtvirtualkeyboard" >>$sddm_config
    echo "" >>$sddm_config
    echo "[Theme]" >>$sddm_config
    echo "Current=breeze" >>$sddm_config
    echo "EnableAvatars=true" >>$sddm_config
    echo "DisableAvatarsThreshold=7" >>$sddm_config

    # Установка темы графического загрузчика KDE plasma
    if command -v plymouth &>/dev/null; then
        run_as_user "yay -S --noconfirm plymouth-kcm breeze-plymouth"
        plymouth-set-default-theme "breeze"
        UPDATE_MKINITCPIO=true
    fi

    # Установка конфигуратора службы печати
    if command -v cups &>/dev/null; then
        run_as_user "yay -S --noconfirm print-manager"
    fi

    # Установка минимального набора программ
    run_as_user "yay -S --noconfirm konsole dolphin partitionmanager ark kate gwenview spectacle okular btrfs-assistant"
}

# ------------------------------------------------------
# Завершение установки
# ------------------------------------------------------

installation_complete() {
    if [ $UPDATE_GRUB = true ] ; then
        grub-mkconfig -o /boot/grub/grub.cfg
    fi

    if [ $UPDATE_MKINITCPIO = true ] ; then
        mkinitcpio -P
    fi

    reboot
}

# ------------------------------------------------------
# Вывод цветного текста
# ------------------------------------------------------

print() {
    local color

    if [[ "$2" = "line" ]]; then
        local text=$3
    else
        local text=$2
        echo
    fi

    case $1 in
        info) color="\e[32m" ;;
        warning) color="\e[31m" ;;
        question) color="\e[36m" ;;
        accent) color="\e[33m" ;;
        *) color="\e[0m" ;;
    esac

    if [[ "$2" = "line" ]]; then
        echo -ne "${color}${text}\e[0m"
    else
        echo -e "${color}${text}\e[0m"
    fi
}

# ------------------------------------------------------
# Сохранение вывода в файл
# ------------------------------------------------------

output_to_file() {
    exec > >(tee -a /var/tmp/btwarch.log) 2>&1
}

# ------------------------------------------------------
# Выполнение команды от имени пользователя
# ------------------------------------------------------

run_as_user() {
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/$USERNAME >/dev/null
    su $USERNAME -c "$1"
    rm -f /etc/sudoers.d/$USERNAME
}

# ------------------------------------------------------
# Включение доступа по ssh для пользователя root
# (только для целей отладки)
# ------------------------------------------------------

enable_root_ssh() {
    pacman -S --noconfirm openssh

    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

    systemctl enable --now sshd

    ip a show
}

setfont cyr-sun16

if [ "$EUID" -ne 0 ]; then
    echo -e "\nСкрипт должен быть запущен от пользователя root\n"
    exit 1
fi

if [ $# -eq 0 ]; then
    stage_1
else
    if declare -f $1 >/dev/null; then
        $1
    else
        echo -e "\nФункция '$1' не найдена\n"
        exit
    fi
fi
