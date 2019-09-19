# fresk-nc_infra
fresk-nc Infra repository

## Homework 3. Знакомство с облачной инфраструктурой GCP

[Интерфейс GCP](https://console.cloud.google.com)

```
bastion_IP = 35.233.44.234
someinternalhost_IP = 10.132.0.3
```

### Создание VM и подключение к ним по ssh

Сгенерировал ssh ключ и положил в GCP Metadata SHH keys.
```
ssh-keygen -t rsa -f ~/.ssh/appuser -C appuser -P ""
```

Создал две виртуалки.
```
bastion
Zone: europe-west1-d
Machine type: f1-micro (1 vCPU, 0.6 GB memory)
External IP: 35.233.44.234
Image: ubuntu 16.04

someinternalhost
Zone: europe-west1-d
Machine type: f1-micro (1 vCPU, 0.6 GB memory)
Internal IP: 10.132.0.3
Image: ubuntu 16.04
```

Подключение по ssh к bastion:
```
ssh -i ~/.ssh/appuser appuser@35.233.44.234
```

Подключение по ssh к someinternalhost через bastion:
```
ssh-add -L
ssh-add ~/.ssh/appuser

ssh -i ~/.ssh/appuser -A appuser@35.233.44.234

ssh 10.132.0.3
```
Ключ -A для SSH Agent Forwarding.

Подключение по ssh к someinternalhost в одну команду:
```
ssh -i ~/.ssh/appuser -A -J appuser@35.233.44.234 appuser@10.132.0.3
```
Ключ -J для SSH ProxyJump

Подключение к someinternalhost по алиасу:
```
Добавил в ~/.ssh/config

Host bastion
    HostName 35.233.44.234
    User appuser
    ForwardAgent yes
    IdentityFile ~/.ssh/appuser

Host someinternalhost
    HostName 10.132.0.3
    ProxyJump bastion
    User appuser
    ForwardAgent yes
    IdentityFile ~/.ssh/appuser

После этого можно использовать - ssh someinternal
```

### VPN-сервер для серверов GCP

В настройках bastion разрешил в Брэндмауэре HTTP/HTTPS-трафик.

На bastion выполнил:
```
cat <<EOF> setupvpn.sh
#!/bin/bash
echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.4.list
echo "deb http://repo.pritunl.com/stable/apt xenial main" > /etc/apt/sources.list.d/pritunl.list
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 0C49F3730359A14518585931BC711F9BA15703C6
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
apt-get --assume-yes update
apt-get --assume-yes upgrade
apt-get --assume-yes install pritunl mongodb-org
systemctl start pritunl mongod
systemctl enable pritunl mongod
EOF

sudo bash setupvpn.sh
```

В результате установились mongodb и VPN-cервер pritunl.

Зашел на https://35.233.44.234/setup, выполнил инструкции установки.
Создал организацию, пользователя, сервер, привязал его к организации и запустил.
[Подробнее](https://docs.pritunl.com/docs/connecting).

Добавил правило в GCP -> VPC network -> Firewall rules -> Create firewall rule
```
Name: vpn-18294
Target tags: otus-vpn
IP ranges: 0.0.0.0/0
Protocols and ports: udp:18294
```

Добавил в настройках инстанса bastion в network tags новый тег - `otus-vpn`.

Вернулся в интерфейс pritunl(https://35.233.44.234), скачал конфигурационный файл юзера
на странице Users -> Click to download profile.

Запустил конфигурацию через Tunnelblick, зашел на someinternalhost
`ssh -i ~/.ssh/appuser appuser@10.132.0.3`

### Дополнительное задание

```
С помощью сервисов sslip.io/xip.io и реализуйте
использование валидного сертификата для панели управления
VPN-сервера
```

[ssli.io](https://sslip.io) - dns, который при запросе имени хоста со встроенным IP-адресом возвращает этот IP-адрес.

В настройках pritunl добавил домен `35-233-44-234.otus.sslip.io`, получил ошибку:
```
too many certificates already issued for: sslip.io: see https://letsencrypt.org/docs/rate-limits/"
```
Для xip.io аналогичная ошибка. Получилось для `35-233-44-234.nip.io`.

### Список полезных источников
* https://man.openbsd.org/ssh
* https://habr.com/ru/post/331348/
* https://habr.com/ru/post/435546/
