terraform {
  backend "gcs" {
    bucket = "bnboraxuseast1terraform00"
    prefix = "cvat"
  }
  required_providers {
    google = {
      version = "~> 4.0"
    }
    google-beta = {
      version = "~> 4.0"
    }
    random = {
      version = "~> 3.4"
    }
  }
  required_version = "1.3.6"
}
