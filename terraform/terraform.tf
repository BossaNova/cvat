terraform {
  backend "gcs" {
    bucket = "bnboraxuseast1terraform00"
    prefix = "cvat"
  }
  required_providers {
    google = {
      version = "~> 4.0"
    }
  }
  required_version = "1.2.8"
}
