output "subnet_id" {
  description = "Subnet id"
  value       = module.cvat_vpc.subnets["${var.google_region}/${local.subnet_name}"].id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = module.cvat_vpc.network_name
}

output "project_name" {
  description = "name of the project"
  value       = module.cvat_project.project_name
}

output "project_id" {
  description = "id of the project"
  value       = module.cvat_project.project_id
}

output "postgres_instance_name" {
  description = "Instance name of the data base"
  value       = google_sql_database_instance.cvat_postgresql_db.name
}

output "postgres_instance_connection_name" {
  description = "Instance connection name of the data base"
  value       = google_sql_database_instance.cvat_postgresql_db.connection_name
}

output "postgres_private_ip" {
  description = "Private IP address for Postgres"
  value       = google_sql_database_instance.cvat_postgresql_db.private_ip_address
}

output "postgres_public_ip" {
  description = "Public IP address for Postgres"
  value       = google_sql_database_instance.cvat_postgresql_db.public_ip_address
}

output "compute_host_id" {
  description = "Host name of the virtual machine"
  value       = module.cvat_compute_instance.instances_details[0].id
}

output "compute_host_name" {
  description = "Host name of the virtual machine"
  value       = module.cvat_compute_instance.instances_details[0].name
}


output "compute_zone" {
  description = "The zone of the compute instance"
  value       = var.google_zone
}

output "compute_region" {
  description = "The region of the compute instance"
  value       = var.google_region
}

output "compute_internal_ip" {
  description = "ip address of the vm"
  value       = module.cvat_compute_instance.instances_details[0].network_interface[0].network_ip
}

output "compute_external_ip" {
  description = "ip address of the vm"
  value       = module.cvat_compute_instance.instances_details[0].network_interface[0].access_config[0].nat_ip
}

output "compute_sa" {
  description = "Service account for the compute machine"
  value       = module.cvat_service_accounts.email
}
output "redis_instance_id" {
  description = "Instance for redis"
  value       = module.cvat_memorystore.id
}

output "redis_instance_host" {
  description = "Instance for redis"
  value       = module.cvat_memorystore.host
}

output "folder_name" {
  description = "name of the folder this will be created in"
  value       = local.folder_name
}


