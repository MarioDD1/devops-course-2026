# Конфигурация виртуальной машины

## 1. Параметры машины

ОС: Ubuntu Server 24.04 LTS.
Гипервизор: VirtualBox.

Параметры VirtualBox:
- Оперативная память: 2048
- Процессоры: 3
- Виртуальный диск: 25

## 2. Сетевые интерфейсы

Адаптер 1: NAT, обеспечивает доступ в интернет.
Адаптер 2: Host-only, обеспечивает связь с Windows.
Адрес Host-only на момент настройки: 192.168.56.101.
Для enp0s8 включён DHCP в /etc/netplan/60-host-only.yaml.

## 3. Правило проброса портов

Протокол: TCP.
Адрес хоста: 127.0.0.1.
Порт хоста: 2222.
Адрес гостя: не задан.
Начальный порт гостя: 22.
После усиления SSH порт гостя изменён на 2222.

## 4. Учётные записи

sa — исходная учётная запись администратора.
devops — отдельная учётная запись, включена в группу sudo.
Пользователь devops входит по ключу Ed25519.

Закрытый ключ находится только на Windows:
~/.ssh/devops_vm

Открытый ключ на сервере:
~devops/.ssh/authorized_keys

Права каталога .ssh: 700.
Права authorized_keys: 600.

## 5. Служба SSH

Отдельный файл настроек:
/etc/ssh/sshd_config.d/00-devops-hardening.conf

Исходный файл сохранён:
/etc/ssh/sshd_config.backup

Порядок восстановления после исходного снимка:
1. Установить openssh-server.
2. Создать devops и включить его в sudo.
3. Разместить открытый ключ, установить права и проверить вход.
4. Создать файл настройки с параметрами, приведёнными ниже.
5. Выполнить sudo sshd -t и проверить sudo sshd -T.
6. Выполнить:
   sudo systemctl disable --now ssh.socket
   sudo systemctl enable --now ssh.service
   sudo systemctl restart ssh
7. Изменить гостевой порт проброса с 22 на 2222.
8. Проверить новое подключение, сохраняя прежнюю сессию открытой.

## 6. Межсетевой экран

Порядок настройки:
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw logging medium
sudo ufw enable

Правило SSH создаётся до включения экрана.

## 7. Снимки состояния

01-clean-install — до настройки пользователя devops и защиты SSH.
02-keys-configured — после проверки входа по ключу.
03-ssh-hardened — после изменения порта и запрета паролей/root.

## 8. Локальное имя

В hosts Windows добавлено:
192.168.56.101 devops.local

В Ubuntu выполнено:
sudo hostnamectl set-hostname devops-vm

В /etc/hosts Ubuntu добавлено:
127.0.1.1 devops-vm.devops.local devops-vm

## 9. Настройка SSH-клиента Windows

Файл: ~/.ssh/config

Host devops
    HostName 127.0.0.1
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes

Host devops.local
    HostName devops.local
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes

## 10. Проверка

Скрипт: scripts/audit.sh.
Запуск: bash scripts/audit.sh
Успешная проверка возвращает 0.
При временном MaxAuthTries 10 проверка возвращает 1.
После проверки восстановлено MaxAuthTries 3.

## 11. Фактические сетевые адреса

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp0s3           UP             10.0.2.15/24 metric 100 fd17:625c:f037:2:a00:27ff:feeb:22c0/64 fe80::a00:27ff:feeb:22c0/64 
enp0s8           UP             192.168.56.101/24 metric 100 fe80::a00:27ff:fe18:c04/64 
docker0          DOWN           172.17.0.1/16 
```

## 12. Содержимое файла SSH

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

## 13. Конфигурация Host-only

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: true
      optional: true
```

## 14. Фактические правила UFW

```text
Status: active
Logging: on (medium)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                  
2222/tcp                   LIMIT IN    Anywhere                   # SSH rate-limited
80/tcp                     ALLOW IN    Anywhere                   # HTTP
443/tcp                    ALLOW IN    Anywhere                   # HTTPS
22/tcp (v6)                ALLOW IN    Anywhere (v6)             
2222/tcp (v6)              LIMIT IN    Anywhere (v6)              # SSH rate-limited
80/tcp (v6)                ALLOW IN    Anywhere (v6)              # HTTP
443/tcp (v6)               ALLOW IN    Anywhere (v6)              # HTTPS

```
