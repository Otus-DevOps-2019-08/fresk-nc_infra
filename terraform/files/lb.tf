resource "google_compute_forwarding_rule" "app-forwarding-rule" {
  name       = "app-forwarding-rule"
  target     = "${google_compute_target_pool.app-target-pool.self_link}"
  port_range = "9292"
}

resource "google_compute_target_pool" "app-target-pool" {
  name = "app-target-pool"

  instances = "${google_compute_instance.app[*].self_link}"

  health_checks = [
    "${google_compute_http_health_check.app-healthcheck.name}",
  ]
}

resource "google_compute_http_health_check" "app-healthcheck" {
  name = "app-healthcheck"
  port = "9292"
}
