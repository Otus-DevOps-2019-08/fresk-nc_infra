resource "google_compute_instance" "db" {
  name = "reddit-db-${var.env}"
  machine_type = "g1-small"
  zone = var.zone
  tags = ["reddit-db"]
  labels = {
    env = var.env
    group = "db"
  }
  boot_disk {
    initialize_params {
      image = var.db_disk_image
    }
  }
  network_interface {
    network = "default"
    access_config {}
  }
  metadata = {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }

  #connection {
  #  type        = "ssh"
  #  host        = self.network_interface[0].access_config[0].nat_ip
  #  user        = "appuser"
  #  agent       = false
  #  private_key = file(var.private_key_path)
  #}

  #provisioner "file" {
  #  source      = "${path.module}/files/mongod.conf"
  #  destination = "/tmp/mongod.conf"
  #}

  #provisioner "remote-exec" {
  #  script = "${path.module}/files/deploy.sh"
  #}
}

resource "google_compute_firewall" "firewall_mongo" {
  name = "allow-mongo-default-${var.env}"
  network = "default"
  allow {
    protocol = "tcp"
    ports = ["27017"]
  }
  target_tags = ["reddit-db"]
  source_tags = ["reddit-app"]
}
