variable project {
  description = "Project ID"
}
variable region {
  description = "Region"
  default = "europe-west2"
}
variable zone {
  description = "Zone"
  default     = "europe-west2-b"
}
variable public_key_path {
  description = "Path to the public key used for ssh access"
}
variable private_key_path {
  description = "Path to the private key used for ssh access"
}
variable app_disk_image {
  description = "Disk image for reddit app"
  default = "reddit-app"
}
variable db_disk_image {
  description = "Disk image for reddit db"
  default = "reddit-db"
}
variable env {
  description = "Environment"
  default     = "prod"
}
