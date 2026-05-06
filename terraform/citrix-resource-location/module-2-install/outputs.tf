output "resource_location_id" {
  description = "ID der Citrix Cloud Resource Location (Zone) – für Modul 3"
  value       = citrix_zone.resource_location.id
}
output "resource_location_name" {
  description = "Name der Resource Location"
  value       = citrix_zone.resource_location.name
}
