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

Добавил дополнительные параметры:
```
...
"image_description": "Some image for homework 5",
"disk_type": "pd-ssd",
"disk_size": 15,
"tags": [ "puma-server" ],
...
```

### Задание со *

Создал образ reddit-full:
```
packer build --var-file=variables.json immutable.json
```

Создал инстанс на основе образа reddit-full:
```
gcloud compute instances create reddit-app \
  --boot-disk-size=15GB \
  --image=reddit-full-1569449699 \
  --machine-type=g1-small \
  --tags=puma-server \
  --zone=europe-west1-b \
  --restart-on-failure
```

Добавил скрипт config-scripts/create-reddit-vm.sh для создания 
инстанса на основе образа reddit-full.

### Список полезных источников
* https://www.packer.io/docs/builders/googlecompute.html
* https://www.packer.io/docs/templates/user-variables.html
* https://www.packer.io/docs/provisioners/file.html
* http://cloudurable.com/blog/aws-ansible-packer-ssh-for-devops/index.html
* https://github.com/puma/puma/blob/master/docs/systemd.md
* https://habr.com/ru/company/southbridge/blog/255845/

## Homework 6. Практика IaC с использованием Terraform

Скачал Terraform https://www.terraform.io/downloads.html

```
terraform -v

Terraform v0.12.9
```

### Провайдеры

Добавил провайдера для терраформа:
```
terraform/main.tf

terraform {
  # Версия terraform
  required_version = "0.12.9"
}

provider "google" {
  # Версия провайдера
  version = "2.15"

  # ID проекта
  project = "formal-office-****"

  region = "europe-west-1"
}
```

Загрузил провайдер:
```
terraform init

Initializing the backend...

Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "google" (hashicorp/google) 2.15.0...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

### Ресурсы

Добавил ресурс:
```
resource "google_compute_instance" "app" {
  name = "reddit-app"
  machine_type = "g1-small"
  zone = "europe-west1-b"

  metadata = {
    # путь до публичного ключа
    ssh-keys = "appuser:${file("~/.ssh/appuser.pub")}"
  }

  boot_disk {
    initialize_params {
      image = "reddit-base"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }
}
```

Проверил и применил изменения:
```
terraform plan

terraform apply --auto-approve
```

Получил IP инстанса и подключился по ssh:
```
terraform show | grep nat_ip

ssh appuser@34.77.248.5
```

### Output vars

Создал файл c output переменными - outputs.tf
Записал туда IP инстанса:
```
output "app_external_ip" {
  value = google_compute_instance.app.network_interface[0].access_config[0].nat_ip
}
```

Выполнил `terraform refresh` чтобы переменная приняла значение.

Вывел переменную:
```
terraform output

app_external_ip = 34.77.248.5
```

### Добавление правила firewall

Добавил firewall правило:
```
resource "google_compute_firewall" "firewall_puma" {
  name = "allow-puma-default"

  # Название сети, в которой действует правило
  network = "default"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports = ["9292"]
  }

  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]

  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["reddit-app"]
}
```

Добавил тег внутрь ресурса app:
```
tags = ["reddit-app"]
```

Проверил и применил изменения
```
terraform plan
terraform apply --auto-approve
```

### Провижины

https://www.terraform.io/docs/provisioners/index.html

Добавил провижин внутрь ресурса app, который копирует файл puma.service:
```
provisioner "file" {
  source = "files/puma.service"
  destination = "/tmp/puma.service"
}
```

Добавил провижин внутрь ресурса app, который запускает приложение:
```
provisioner "remote-exec" {
  script = "files/deploy.sh"
}
```

Добавил параметры подключения для провижинов внутрь ресурса app:
```
connection {
  type = "ssh"
  host = self.network_interface[0].access_config[0].nat_ip
  user = "appuser"
  agent = false
  # путь до приватного ключа
  private_key = file("~/.ssh/appuser")
}
```

Так как провижинеры по умолчанию запускаются сразу после
создания ресурса (могут еще запускаться после его удаления),
чтобы проверить их работу, нужно удалить ресурс VM и создать
его снова.
Terraform предлагает команду taint, которая позволяет пометить
ресурс, который terraform должен пересоздать, при следующем
запуске terraform apply.

Говорим terraform'y пересоздать ресурс VM при следующем
применении изменений:

```
terraform taint google_compute_instance.app

The resource google_compute_instance.app in the module root
has been marked as tainted!
```

Применил изменения:
```
terraform plan
terraform apply --auto-approve
```

### Input vars

Входные переменные позволяют параметризировать
конфигурационные файлы. Для того чтобы использовать входную переменную ее нужно 
сначала определить в одном из конфигурационных файлов.

Создал файл variables.tf:
```
variable project {
  description = "Project ID"
}
variable region {
  description = "Region"
  # Значение по умолчанию
  default = "europe-west1"
}
variable public_key_path {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}
variable disk_image {
  description = "Disk image"
}

```
Чтобы получить значение пользовательской
переменной внутри ресурса используется синтаксис `var.var_name`.

Заменил в main.tf захардкоженные значения на переменные.

Определил переменные используя специальный файл
terraform.tfvars, из которого тераформ загружает значения
автоматически при каждом запуске:
```
project = "formal-office-*****"
public_key_path = "~/.ssh/appuser.pub"
disk_image = "reddit-base"
```

### Задание со *

Добавил в метаданные проекта два ssh ключа:
```
resource "google_compute_project_metadata" "default" {
  metadata = {
    ssh-keys = "appuser1:${file(var.public_key_path)}appuser2:${file(var.public_key_path)}"
  }
}
```

Если в интерфейсе добавить третий ключ, а потом выполнить `terraform apply`,
то добавленный ключ удалится.

### Задание с **

Создал google_compute_forwarding_rule
```
resource "google_compute_forwarding_rule" "app-forwarding-rule" {
  name       = "app-forwarding-rule"
  target     = "${google_compute_target_pool.app-target-pool.self_link}"
  port_range = "9292"
}
```

Создал google_compute_target_pool
```
resource "google_compute_target_pool" "app-target-pool" {
  name = "app-target-pool"

  instances = [
    "${google_compute_instance.app.self_link}",
    "${google_compute_instance.app2.self_link}",
  ]  

  health_checks = [
    "${google_compute_http_health_check.app-healthcheck.name}",
  ]
}
```

Создал google_compute_http_health_check
```
resource "google_compute_http_health_check" "app-healthcheck" {
  name = "app-healthcheck"
  port = "9292"
}
```

Скопировал конфиг инстанса app, назвал app2

Проверил и применил конфиг
```
terraform plan
terraform apply --auto-approve
```

Зашел по адресу балансера, убедился, что открывается приложение.
Зашел по ssh на один из инстансов и отключил puma, убедился, что
приложение по прежнему открывается.

Избавился от app2, так как такой подход мешает масштабированию.
В app добавил параметр `count = var.instances_count`, который равен 2.
В google_compute_target_pool заменил параметр `instances`:
```
instances = "${google_compute_instance.app[*].self_link}"
```

Добавил output переменную
```
output "lb_external_ip" {
  value = google_compute_forwarding_rule.app-forwarding-rule.ip_address
}
```

### Список полезных источников
* https://cloud.google.com/load-balancing/docs/https/
* https://www.terraform.io/docs/providers/google/r/compute_forwarding_rule.html
* https://www.terraform.io/docs/providers/google/r/compute_target_pool.html
* https://www.terraform.io/docs/providers/google/r/compute_http_health_check.html

## Homework 7. Принципы организации инфраструктурного кода и работа над инфраструктурой в команде на примере Terraform.

Добавил ресурс - правило firewall для 22 порта
```
resource "google_compute_firewall" "firewall_ssh" {
  name = "default-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}
```

`terraform apply` вызвал ошибку
```
* google_compute_firewall.firewall_ssh: 1 error(s) occurred:
* google_compute_firewall.firewall_ssh: Error creating firewall: googleapi: Error 409:
The resource 'projects/infra-/global/firewalls/default-allow-ssh' already exists,
alreadyExists
```

Возникает т.к. terraform ничего не знает о существующем правиле
файервола (а всю информацию, об известных ему ресурсах, он
хранит в state файле), то при выполнении команды apply
terraform пытается создать новое правило файервола. Для того
чтобы сказать terraform-у не создавать новое правило, а управлять
уже имеющимся, в его "записную книжку" (state файл) о всех
ресурсах, которыми он управляет, нужно занести информацию о
существующем правиле.

```
terraform import google_compute_firewall.firewall_ssh default-allow-ssh

terraform apply
```

### Взаимосвязи ресурсов

Добавил ресурс с IP-адресом
```
resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip"
}
```

Добавил этот IP-адрес в конфиг инстанса
```
network_interface {
 network = "default"
 access_config {
   nat_ip = google_compute_address.app_ip.address
 }
}
```

Ссылку в одном ресурсе на атрибуты другого тераформ
понимает как зависимость одного ресурса от другого. Это влияет
на очередность создания и удаления ресурсов при применении
изменений.

Применил изменения
```
terraform destroy
terraform apply
```

### Структуризация ресурсов

С помощью packer создал два имаджа:
* reddit-app, содержащий ruby
* reddit-db, содержащий mongodb

Разбил main.tf на app.tf, db.tf и vpc.tf

### Модули

Создал модули app, db и vpc:
```
modules/
  app/
    main.tf
    outputs.tf
    variables.tf
  db/
    main.tf
    outputs.tf
    variables.tf
  vpc/
    main.tf
    variables.tf
```

Переместил туда конфиги из db.tf, app.tf и vpc.tf

В корневой main.tf добавил подключение модулей:
```
module "app" {
  source          = "./modules/app"
  public_key_path = var.public_key_path
  zone            = var.zone
  app_disk_image  = var.app_disk_image
}

module "db" {
  source          = "./modules/db"
  public_key_path = var.public_key_path
  zone            = var.zone
  db_disk_image   = var.db_disk_image
}

module "vpc" {
  source        = "./modules/vpc"
}
```

Для подключение модулей выполнинл `terraform get`.

### Переиспользование модулей

Создал
```
terraform/
  prod/
    main.tf
    outputs.tf
    terraform.tfvars
    variables.tf
  stage/
    main.tf
    outputs.tf
    terraform.tfvars
    variables.tf
```

Содержимое для этих файлов взял из аналогичных файлов в папке terraform,
после чего удалил их.

В stage source_ranges = ["0.0.0.0/0"]
В prod source_ranges = ["80.250.215.124/32"] 

### Работа с реестром модулей

Список модулей https://registry.terraform.io/browse/modules?provider=google

Подключил модуль `storage-bucket`:
```
provider "google" {
  version = "~> 2.15"
  project = var.project
  region  = var.region
}

module "storage-bucket" {
  source  = "SweetOps/storage-bucket/google"
  version = "0.3.0"

  name     = "fresk-storage-bucket"
  location = var.region
}

output storage-bucket_url {
  value = module.storage-bucket.url
}
```

### Задание со *

Добавил gcs бекенд, для хранения стейта в сторадже:
```
terraform {
  backend "gcs" {
    bucket  = "fresk-storage-bucket"
    prefix  = "terraform/prod/state"
  }
}
```

### Задание с **

Добавил провижины для modules/app, чтобы скачать и запустить приложение.
Добавил конфиг для mongodb, где поменял `bindIp: 127.0.0.1` на `bindIp: 0.0.0.0`,
и соотвественно провижины для modules/db для загрузки этого конфига.

### Список полезных источников
* https://www.terraform.io/docs/backends/types/gcs.html
* https://github.com/coreos/docs/blob/master/os/using-environment-variables-in-systemd-units.md
* https://docs.mongodb.com/manual/reference/configuration-options/
