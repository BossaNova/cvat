/******************************************
  Folder random id suffix configuration
 *****************************************/
resource "random_id" "random_folder_id" {
  byte_length = 2
}

locals {
  qualifier_name       = "${var.environment}-${var.qualifier}"
  folder_name          = "${local.target_name}-${var.qualifier == "" ? var.environment : local.qualifier_name}-folder"
  project_name         = "${local.target_name}-${var.qualifier == "" ? var.environment : local.qualifier_name}"
  network_name         = "${local.target_name}-${var.qualifier == "" ? var.environment : local.qualifier_name}-vpc"
  subnet_name          = "${local.network_name}-subnet"
  secondary_range_name = "${local.subnet_name}-range"
  db_name              = "${local.target_name}-${var.qualifier == "" ? var.environment : local.qualifier_name}-postgres"
  host_name            = "${local.target_name}-${var.qualifier == "" ? var.environment : local.qualifier_name}-host"
  memstore_name        = "${local.target_name}-${var.qualifier == "" ? var.environment : local.qualifier_name}-memstore"
  private_ip_name      = "${local.target_name}-${var.qualifier == "" ? var.environment : local.qualifier_name}-sql-private-ip"
  owners_members = var.owners == null ? {
    developer-admins = "group:gcp-developers-admins@bossanova.com"
  } : var.owners
  editors_members = var.editors == null ? {
    cvat-operators = "group:gcp-cvat-operations@bossanova.com",
    developers     = "group:gcp-developers@bossanova.com",
  } : var.editors
}


resource "google_folder" "cvat_folder" {
  display_name = "${local.folder_name}-${random_id.random_folder_id.hex}"
  parent       = "organizations/${var.bossanova_org}"
}

resource "google_folder_iam_member" "cvat_folder_owners_binding" {
  for_each = local.owners_members
  folder   = google_folder.cvat_folder.id
  role     = "roles/owner"
  member   = each.value
}

resource "google_folder_iam_member" "cvat_folder_editors_binding" {
  for_each = local.editors_members
  folder   = google_folder.cvat_folder.id
  role     = "roles/editor"
  member   = each.value
}

module "cvat_project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 11.1"

  name                = local.project_name
  project_id          = local.project_name
  random_project_id   = true
  billing_account     = var.billing_id
  org_id              = var.bossanova_org
  folder_id           = google_folder.cvat_folder.id
  auto_create_network = false
  activate_apis = [
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "redis.googleapis.com",
    "sql-component.googleapis.com",
    "storage-component.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
  labels = {
    use        = local.target_name
    env        = var.environment
    created_by = "terraform"
  }
}

module "cvat_service_accounts" {
  source      = "terraform-google-modules/service-accounts/google"
  version     = "~> 4.1"
  project_id  = module.cvat_project.project_id
  prefix      = "${local.project_name}-sa"
  names       = ["primary"]
  description = "Terraform created Service account for CVAT"
}

resource "google_project_iam_member" "cvat_project_sql_binding" {
  project = module.cvat_project.project_id
  role    = "roles/cloudsql.editor"
  member  = module.cvat_service_accounts.iam_email
}

resource "google_project_iam_member" "cvat_project_memcache_binding" {
  project = module.cvat_project.project_id
  role    = "roles/memcache.editor"
  member  = module.cvat_service_accounts.iam_email
}

resource "google_project_iam_member" "cvat_project_logging_writer" {
  project = module.cvat_project.project_id
  role    = "roles/logging.logWriter"
  member  = module.cvat_service_accounts.iam_email
}

resource "google_project_iam_member" "cvat_project_monitoring_writer" {
  project = module.cvat_project.project_id
  role    = "roles/monitoring.metricWriter"
  member  = module.cvat_service_accounts.iam_email
}

module "cvat_vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 5.2"

  project_id   = module.cvat_project.project_id
  network_name = local.network_name
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name           = local.subnet_name
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = var.google_region
      subnet_private_access = "true"
    },
  ]

  secondary_ranges = {
    "${local.project_name}-subnet" = [
      {
        range_name    = local.secondary_range_name
        ip_cidr_range = "192.168.64.0/24"
      },
    ]
  }
}

module "cvat_firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 5.2"

  project_id   = module.cvat_project.project_id
  network_name = module.cvat_vpc.network_name

  rules = [{
    name                    = "allow-ssh-ingress"
    description             = "Allow ssh ingress from the internet"
    direction               = "INGRESS"
    priority                = 1000
    ranges                  = ["0.0.0.0/0"]
    source_tags             = null
    source_service_accounts = null
    target_tags             = null
    target_service_accounts = null
    flow_logs               = false
    log_config              = null
    allow = [{
      protocol = "tcp"
      ports    = ["22"]
    }]
    deny = []
    },
    {
      name                    = "allow-http-ingress"
      description             = "Allow http ingress from the internet"
      direction               = "INGRESS"
      priority                = 2010
      ranges                  = ["0.0.0.0/0"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = ["frontend"]
      target_service_accounts = null
      flow_logs               = false
      log_config              = null
      allow = [{
        protocol = "tcp"
        ports    = ["8080", "80"]
      }]
      deny = []
    },
    {
      name                    = "allow-https-ingress"
      description             = "Allow https ingress from the internet"
      direction               = "INGRESS"
      priority                = 2000
      ranges                  = ["0.0.0.0/0"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = ["frontend"]
      target_service_accounts = null
      flow_logs               = false
      log_config              = null
      allow = [{
        protocol = "tcp"
        ports    = ["443"]
      }]
      deny = []
    },
    {
      name                    = "allow-postgres-ingress"
      description             = "Allow postgres ingress from the internet"
      direction               = "INGRESS"
      priority                = 2100
      ranges                  = ["0.0.0.0/0"]
      source_tags             = null
      source_service_accounts = null
      target_tags             = []
      target_service_accounts = null
      flow_logs               = false
      log_config              = null
      allow = [{
        protocol = "tcp"
        ports    = ["5432"]
      }]
      deny = []
    },
  ]
}

resource "google_compute_global_address" "cvat_private_ip_block" {
  name          = local.private_ip_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  ip_version    = "IPV4"
  prefix_length = 20
  network       = module.cvat_vpc.network_id
  project       = module.cvat_project.project_id
}

resource "google_service_networking_connection" "cvat_private_vpc_connection" {
  network                 = module.cvat_vpc.network_self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cvat_private_ip_block.name]
}

resource "google_sql_database_instance" "cvat_postgresql_db" {
  provider = google-beta

  name             = local.db_name
  region           = local.google_region
  database_version = "POSTGRES_14"

  depends_on = [google_service_networking_connection.cvat_private_vpc_connection]

  project             = module.cvat_project.project_id
  deletion_protection = false
  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled       = false
      private_network    = module.cvat_vpc.network_id
      allocated_ip_range = null
      require_ssl        = false
    }
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    backup_configuration {
      enabled                        = true
      location                       = null
      start_time                     = "03:00"
      point_in_time_recovery_enabled = false
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = null
      }
      transaction_log_retention_days = null
    }
    maintenance_window {
      day          = 6
      hour         = 23
      update_track = "stable"
    }
  }
}

resource "google_project_iam_member" "cvat_sa_iam_binding" {
  project = module.cvat_project.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${module.cvat_service_accounts.email}"
}

resource "random_password" "user_password" {
  keepers = {
    name = google_sql_database_instance.cvat_postgresql_db.name
  }

  length     = 32
  special    = false
  depends_on = [google_sql_database_instance.cvat_postgresql_db]
}

resource "google_sql_user" "cvat_user" {
  project  = module.cvat_project.project_id
  name     = "cvat_master"
  password = random_password.user_password.result
  instance = google_sql_database_instance.cvat_postgresql_db.name
  depends_on = [
    google_sql_database_instance.cvat_postgresql_db,
  ]
}

resource "google_sql_database" "database" {
  name     = "cvat"
  instance = google_sql_database_instance.cvat_postgresql_db.name
  project  = module.cvat_project.project_id
}

module "cvat_static_address" {
  source  = "terraform-google-modules/address/google"
  version = "~> 3.1"

  project_id   = module.cvat_project.project_id
  region       = var.google_region
  global       = false
  purpose      = "GCE_ENDPOINT"
  address_type = "EXTERNAL"

  names = [
    "${local.network_name}-static-ip",
  ]
}

module "cvat_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.8"

  region               = var.google_region
  project_id           = module.cvat_project.project_id
  subnetwork           = module.cvat_vpc.subnets_ids[0]
  source_image_family  = "ubuntu-pro-fips-2004-lts"
  source_image_project = "ubuntu-os-pro-cloud"
  name_prefix          = "cvat-server"
  machine_type         = var.machine_type
  tags                 = ["frontend"]

  service_account = {
    email  = module.cvat_service_accounts.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

module "cvat_compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~>7.8"

  region              = var.google_region
  zone                = var.google_zone
  subnetwork          = module.cvat_vpc.subnets_ids[0]
  hostname            = local.host_name
  instance_template   = module.cvat_instance_template.self_link
  deletion_protection = false
  access_config = [
    {
      nat_ip       = module.cvat_static_address.addresses[0]
      network_tier = "PREMIUM"
    }
  ]
}

module "cvat_memorystore" {
  source  = "terraform-google-modules/memorystore/google"
  version = "5.0.0"

  name                    = local.memstore_name
  project                 = module.cvat_project.project_id
  display_name            = "CVAT Redis Cache"
  enable_apis             = false
  authorized_network      = module.cvat_vpc.network_name
  location_id             = var.google_zone
  read_replicas_mode      = "READ_REPLICAS_DISABLED"
  memory_size_gb          = 1
  redis_version           = "REDIS_5_0"
  region                  = var.google_region
  replica_count           = 1
  tier                    = "BASIC"
  transit_encryption_mode = "DISABLED"

  maintenance_policy = {
    day = "SUNDAY"
    start_time = {
      hours   = 3
      minutes = 15
      seconds = 0
      nanos   = 0
    }
  }
  labels = {
    use         = "cvat"
    created_by  = "terraform"
    environment = lower(var.environment)
  }
}
