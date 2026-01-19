# ===============================
# SOCKET SITES MODULE OUTPUTS
# ===============================

# Basic Site Information
# output "site_ids" {
#   description = "Map of site names to their IDs"
#   value = {
#     for site_name, site_module in module.socket-site : site_name => site_module.site_id
#   }
# }

# output "site_names" {
#   description = "List of all created site names"
#   value = [for site_name in keys(module.socket-site) : site_name]
# }

# output "sites_by_type" {
#   description = "Sites grouped by their type"
#   value = {
#     for site_type in distinct([for site in local.sites_data : site.type]) : site_type => [
#       for site in local.sites_data : site.name if site.type == site_type
#     ]
#   }
# }

# output "sites_by_connection_type" {
#   description = "Sites grouped by their connection type"
#   value = {
#     for connection_type in distinct([for site in local.sites_data : site.connection_type]) : connection_type => [
#       for site in local.sites_data : site.name if site.connection_type == connection_type
#     ]
#   }
# }

# # Site Details
# output "site_details" {
#   description = "Detailed information for all sites"
#   value = {
#     for site_name, site_module in module.socket-site : site_name => {
#       site_id          = site_module.site_id
#       site_name        = site_module.site_name
#       site_type        = site_module.site_type
#       connection_type  = site_module.connection_type
#       site_location    = site_module.site_location
#       native_network_range = site_module.native_network_range
#       local_ip         = site_module.local_ip
#     }
#   }
# }

# Interface Information
# output "wan_interfaces" {
#   description = "WAN interfaces for all sites"
#   value = {
#     for site_name, site_module in module.socket-site : site_name => site_module.cato_interfaces
#   }
# }

# output "lan_interfaces" {
#   description = "LAN interfaces for all sites"
#   value = {
#     for site_name, site_module in module.socket-site : site_name => site_module.lan_interfaces
#   }
# }

# Network Range Information
# output "network_ranges_by_site" {
#   description = "Network ranges grouped by site"
#   value = {
#     for site_name, site_module in module.socket-site : site_name => {
#       native_network_range = site_module.native_network_range
#       local_ip = site_module.local_ip
#       lan_network_ranges = [
#         for lan_interface in site_module.lan_interfaces : {
#           interface_name = lan_interface.name
#           interface_subnet = lan_interface.subnet
#           network_ranges = lan_interface.network_ranges
#         }
#       ]
#     }
#   }
# }

# # Location Information
# output "sites_by_location" {
#   description = "Sites grouped by location"
#   value = {
#     for country in distinct([for site in local.sites_data : site.site_location.countryCode]) : country => {
#       country_name = try([
#         for site in local.sites_data : site.site_location.countryName 
#         if site.site_location.countryCode == country
#       ][0], "")
#       sites = [
#         for site in local.sites_data : {
#           name = site.name
#           city = site.site_location.city
#           state_code = try(site.stateCode, "")
#           timezone = site.site_location.timezone
#         }
#         if site.site_location.countryCode == country
#       ]
#     }
#   }
# }

# # Configuration Summary
# output "deployment_summary" {
#   description = "Summary statistics of the deployment"
#   value = {
#     total_sites_created = length(module.socket-site)
#     sites_by_type = {
#       for site_type in distinct([for site in local.sites_data : site.type]) : site_type => length([
#         for site in local.sites_data : site if site.type == site_type
#       ])
#     }
#     sites_by_connection_type = {
#       for connection_type in distinct([for site in local.sites_data : site.connectionType]) : connection_type => length([
#         for site in local.sites_data : site if site.connectionType == connection_type
#       ])
#     }
#     total_wan_interfaces = sum([
#       for site in local.sites_data : length(site.wan_interfaces)
#     ])
#     total_lan_interfaces = sum([
#       for site in local.sites_data : length(site.lan_interfaces)
#     ])
#     total_network_ranges = sum([
#       for site in local.sites_data : sum([
#         for lan in site.lan_interfaces : length(lan.network_ranges)
#       ])
#     ])
#   }
# }

# # LAN Interface Analysis (commented out due to structure change)
# output "lan_interface_analysis" {
#   description = "Analysis of LAN interface selections by connection type"
#   value = {
#     for site_name, site_data in local.lan_interfaces_by_site : site_name => {
#       connection_type = [for site in local.sites_data : site.connection_type if site.name == site_name][0]
#       uses_lan_01 = contains(["SOCKET_X1500", "SOCKET_GCP1500", "VSOCKET_VGX_AWS", "VSOCKET_VGX_AZURE", "VSOCKET_VGX_ESX"], 
#         [for site in local.sites_data : site.connection_type if site.name == site_name][0]
#       )
#       expected_lan_interface = contains(["SOCKET_X1500", "SOCKET_GCP1500", "VSOCKET_VGX_AWS", "VSOCKET_VGX_AZURE", "VSOCKET_VGX_ESX"], 
#         [for site in local.sites_data : site.connection_type if site.name == site_name][0]
#       ) ? "LAN 01" : "LAN"
#       selected_lan_interface = site_data.lan_interface != null ? site_data.lan_interface.name : null
#       lan_interface_found = site_data.lan_interface != null
#       network_ranges_count = site_data.lan_interface != null ? length(site_data.lan_interface.network_ranges) : 0
#     }
#   }
# }

# IP Address Mapping (commented out - missing local.calculate_local_ip)
# output "ip_address_mapping" {
#   description = "Mapping of subnets to calculated local IPs"
#   value = local.calculate_local_ip
# }

# # LAN Interface Index
# output "lan_interfaces_by_id" {
#   description = "LAN interfaces indexed by their ID as string values"
#   value = local.lan_interfaces_by_id
# }

# Debug output removed - LAG member interfaces are now working correctly
# output "debug_sites_data" {
#   description = "Raw sites data for debugging LAG member interfaces"
#   value = local.sites_data
# }

# # Site Configuration for External Use
# output "site_configurations" {
#   description = "Site configurations formatted for external consumption"
#   value = {
#     for site_name, site_module in module.socket-site : site_name => {
#       basic_info = {
#         id = site_module.site_id
#         name = site_module.site_name
#         type = site_module.site_type
#         connection_type = site_module.connection_type
#         description = [for site in local.sites_data : site.description if site.name == site_name][0]
#       }
#       location = site_module.site_location
#       networking = {
#         native_network_range = site_module.native_network_range
#         local_ip = site_module.local_ip
#         wan_interfaces_count = length(site_module.cato_interfaces)
#         lan_interfaces_count = length(site_module.lan_interfaces)
#       }
#       interfaces = {
#         wan = site_module.cato_interfaces
#         lan = site_module.lan_interfaces
#       }
#     }
#   }
# }

# # Error Detection (commented out due to structure change)
# output "configuration_warnings" {
#   description = "Potential configuration issues detected"
#   value = {
#     sites_without_lan_interface = [
#       for site_name, site_data in local.lan_interfaces_by_site : site_name 
#       if site_data.lan_interface == null
#     ]
#     sites_without_network_ranges = [
#       for site_name, site_data in local.lan_interfaces_by_site : site_name 
#       if site_data.lan_interface != null && try(length(site_data.lan_interface.network_ranges), 0) == 0
#     ]
#     empty_subnets = [
#       for subnet, ip in local.calculate_local_ip : subnet if ip == ""
#     ]
#   }
# }
