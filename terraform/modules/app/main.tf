resource "google_compute_instance" "app" {
  name = "reddit-app-${var.env}"
  machine_type = "g1-small"
  zone = var.zone
  tags = ["reddit-app"]
  labels = {
    env = var.env
    group = "app"
  }
  boot_disk {
    initialize_params { image = var.app_disk_image }
  }
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
  }
  metadata = {
    # путь до публичного ключа
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
  #  source      = "${path.module}/files/puma.service"
  #  destination = "/tmp/puma.service"
  #}

  #provisioner "remote-exec" {
  #  inline = [
  #    "sudo echo DATABASE_URL=${var.db_ip} > /tmp/puma.env",
  #  ]
  #}

  #provisioner "remote-exec" {
  #  script = "${path.module}/files/deploy.sh"
  #}
}

resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip-${var.env}"
}

resource "google_compute_firewall" "firewall_puma" {
  name = "allow-puma-default-${var.env}"
  network = "default"
  allow {
    protocol = "tcp"
    ports = ["9292", "80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["reddit-app"]
}
