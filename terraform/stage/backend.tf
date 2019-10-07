terraform {
  backend "gcs" {
    bucket  = "fresk-storage-bucket"
    prefix  = "terraform/stage/state"
  }
}
