variable "bossanova_org" {
  description = "the organization number from google"
  type        = string
}
variable "environment" {
  description = "Environment this build is for"
  type        = string
}

variable "qualifier" {
  description = "Qualifier used to make this build unique"
  type        = string
  default     = ""
}

variable "billing_id" {
  description = "The Billing Id to use for this build"
  type        = string
}

variable "google_region" {
  description = "region this project will run in"
  type        = string
  default     = "us-east1"
}

variable "google_zone" {
  description = "zone this project will run in"
  type        = string
  default     = "us-east1-c"
}

variable "owners" {
  description = "Map(string) name=>member (user:email@domain.com, serviceAccount: my-other-app@appspot.gserviceaccount.com, or group:group@domain.com"
  type        = map(string)
  default     = null
}

variable "editors" {
  description = "Map(string) name=>member (user:email@domain.com, serviceAccount: my-other-app@appspot.gserviceaccount.com, or group:group@domain.com"
  type        = map(string)
  default     = null
}

variable "machine_type" {
  description = "Machine type to use for the CVAT server see https://cloud.google.com/compute/docs/machine-types for machine types"
  default     = "e2-medium"
  type        = string
}
