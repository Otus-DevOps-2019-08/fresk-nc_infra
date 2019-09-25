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

## Homework 4. Практика управления ресурсами GCP через gcloud

```
testapp_IP = 35.241.146.103
testapp_port = 9292
```

Установил gcloud. [Инструкция](https://cloud.google.com/sdk/docs/quickstart-macos).

Создал инстанс для провеки:
```
gcloud compute instances create reddit-app \
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure
  
Created [https://www.googleapis.com/compute/v1/projects/formal-office-*****/zones/europe-west1-d/instances/reddit-app].
NAME        ZONE            MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
reddit-app  europe-west1-d  g1-small                   10.132.0.4   35.241.146.103  RUNNING
```

Подключился по ssh, установил Ruby и Bundler:
```
ssh appuser@35.241.146.103

sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential
```

Добавил ключи и репозиторий MongoDB:
```
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
sudo bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
```

Установил MongoDB:
```
sudo apt update
sudo apt install -y mongodb-org
```

Во время установки получил ошибку:
```
W: GPG error: http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 Release: The following signatures couldn't be verified because the public key is not available: NO_PUBKEY D68FA50FEA312927
E: The repository 'http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 Release' is not signed.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
N: See apt-secure(8) manpage for repository creation and user configuration details.
```

Скачал ключи как описано в [официальной документации](https://docs.mongodb.com/v3.2/tutorial/install-mongodb-on-ubuntu/):
```
wget -qO - https://www.mongodb.org/static/pgp/server-3.2.asc | sudo apt-key add -
```
Еще раз попробовал установить - ОК.

Запустил MongoDB:
```
sudo systemctl start mongod
```

Добавил в автозапуск:
```
sudo systemctl enable mongod
```

Проверил работу MongoDB:
```
sudo systemctl status mongod

mongod.service - High-performance, schema-free document-oriented database
   Loaded: loaded (/lib/systemd/system/mongod.service; enabled; vendor preset: enabled)
   Active: active (running) since Sat 2019-09-21 15:56:18 UTC; 3min 6s ago
     Docs: https://docs.mongodb.org/manual
 Main PID: 10058 (mongod)
    Tasks: 19
   Memory: 30.0M
      CPU: 956ms
   CGroup: /system.slice/mongod.service
           └─10058 /usr/bin/mongod --quiet --config /etc/mongod.conf
```

Склонировал репозиторий с приложением:
```
cd /home/appuser
git clone -b monolith https://github.com/express42/reddit.git
```

Установил зависимости приложения:
```
cd reddit && bundle install
```

Запустил сервер:
```
puma -d
```

Проверил, что сервер запустился и нашел порт:
```
ps aux | grep puma

appuser  10841  1.0  1.5 515356 26724 ?        Sl   16:03   0:00 puma 3.10.0 (tcp://0.0.0.0:9292) [reddit]
appuser  10855  0.0  0.0  12916  1016 pts/0    S+   16:03   0:00 grep --color=auto puma
```

Открыл порт в firewall:
VPC Network -> Firewall rules -> Create firewall rule
```
name: default-puma-server
targets: puma-server
IP ranges: 0.0.0.0/0
protocols/ports: tcp:9292
```

Открыл интерфейс по адресу http://35.241.146.103:9292

### Дополнительное задание

Создание VM с указанием startup-script:
```
gcloud compute instances create reddit-app \
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure \
  --metadata-from-file startup-script=startup_script.sh
  
Created [https://www.googleapis.com/compute/v1/projects/formal-office-*****/zones/europe-west1-d/instances/reddit-app].
NAME        ZONE            MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
reddit-app  europe-west1-d  g1-small                   10.132.0.5   35.241.146.103  RUNNING
```

Создание firewall rule с помощью gcloud:
```
gcloud compute firewall-rules create default-puma-server \
  --action allow \
  --target-tags puma-server \
  --rules tcp:9292

Creating firewall...⠏Created [https://www.googleapis.com/compute/v1/projects/formal-office-*****/global/firewalls/default-puma-server].
Creating firewall...done.
NAME                 NETWORK  DIRECTION  PRIORITY  ALLOW     DENY  DISABLED
default-puma-server  default  INGRESS    1000      tcp:9292        False
```

### Список полезных источников
* https://cloud.google.com/vpc/docs/using-firewalls
* https://cloud.google.com/compute/docs/startupscript

## Homework 5. Сборка образов VM при помощи Packer

Установил Packer - https://www.packer.io/downloads.html

```
packer -v

1.4.3
```

Создал ADC(Application Default Credentials) для работы с GCP:
```
gcloud auth application-default login
```

Создал конфиг packer/ubuntu16.json:
```
{
  "builders": [
    {
      "type": "googlecompute",
      "project_id": "formal-office-*****",
      "image_name": "reddit-base-{{timestamp}}",
      "image_family": "reddit-base",
      "source_image_family": "ubuntu-1604-lts",
      "zone": "europe-west1-b",
      "ssh_username": "appuser",
      "machine_type": "f1-micro"
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "script": "scripts/install_ruby.sh",
      "execute_command": "sudo {{.Path}}"
    },
    {
      "type": "shell",
      "script": "scripts/install_mongodb.sh",
      "execute_command": "sudo {{.Path}}"
    }
  ]
}
```

Скопировал скрипты с прошлого ДЗ install_ruby.sh и install_mongodb.sh в папку packer/scripts

Запустил проверку шаблона:
```
cd packer
packer validate ./ubuntu16.json

Template validated successfully.
```

Запустил билд образа:
```
packer build ubuntu16.json

--> googlecompute: A disk image was created: reddit-base-1569440112
```

Создал новый инстанс:
```
gcloud compute instances create reddit-app \
  --boot-disk-size=10GB \
  --image=reddit-base-1569440112 \
  --machine-type=g1-small \
  --tags=puma-server \
  --zone=europe-west1-b \
  --restart-on-failure
  
Created [https://www.googleapis.com/compute/v1/projects/formal-office-*****/zones/europe-west1-b/instances/reddit-app].
NAME        ZONE            MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
reddit-app  europe-west1-b  g1-small                   10.132.0.7   34.77.191.194  RUNNING
```

Подключился по ssh:
```
ssh appuser@34.77.191.194
```

Установил и запустил приложение
```
git clone -b monolith https://github.com/express42/reddit.git
cd reddit && bundle install
puma -d
ps aux | grep puma

appuser   2637  3.5  1.5 515368 26668 ?        Sl   19:56   0:00 puma 3.10.0 (tcp://0.0.0.0:9292) [reddit]
```

Создал firewall правило:
```
gcloud compute firewall-rules create default-puma-server \
  --action allow \
  --target-tags puma-server \
  --rules tcp:9292
  
Creating firewall...⠏Created [https://www.googleapis.com/compute/v1/projects/formal-office-*****/global/firewalls/default-puma-server].
Creating firewall...done.
NAME                 NETWORK  DIRECTION  PRIORITY  ALLOW     DENY  DISABLED
default-puma-server  default  INGRESS    1000      tcp:9292        False  
```

### Самостоятельное задание

Объявил переменные в ubuntu16.json
```
{
  "variables": {
    "project_id": null,
    "source_image_family": null,
    "machine_type": "f1-micro"
  },
  "builders": [
    {
      "type": "googlecompute",
      "project_id": "{{user `project_id`}}",
      "image_name": "reddit-base-{{timestamp}}",
      "image_family": "reddit-base",
      "source_image_family": "{{user `source_image_family`}}",
      "zone": "europe-west1-b",
      "ssh_username": "appuser",
      "machine_type": "f1-micro"
    }
  ],
  "provisioners": [
    {
      "type": "shell",
      "script": "scripts/install_ruby.sh",
      "execute_command": "sudo {{.Path}}"
    },
    {
      "type": "shell",
      "script": "scripts/install_mongodb.sh",
      "execute_command": "sudo {{.Path}}"
    }
  ]
}
```

Запустил валидацию:
```
packer validate ./ubuntu16.json

Error initializing core: 2 errors occurred:
	* required variable not set: project_id
	* required variable not set: source_image_family
```

Добавил файл с переменными и запустил валидацию:
```
packer validate --var-file=variables.json ./ubuntu16.json

Template validated successfully.
```	
