## Config Data Directory and File Names
variable "sites_json_file_path" {
  type        = string
  default     = null
  description = "Path to the JSON file containing the site configuration data. Either this or sites_csv_file_path must be provided."

  validation {
    condition     = var.sites_json_file_path != null || var.sites_csv_file_path != null
    error_message = "Either sites_json_file_path or sites_csv_file_path must be provided."
  }
}

## Config Data Directory and File Names  
variable "sites_csv_file_path" {
  type        = string
  default     = null
  description = "Path to the main CSV file containing the site configuration data. Either this or sites_json_file_path must be provided."
}

## Config Data Directory and File Names
variable "sites_csv_network_ranges_folder_path" {
  type        = string
  default     = null
  description = "Path to the folder containing individual CSV files with network ranges data for each site. Optional when using CSV input. Files should be named {site_name}_network_ranges.csv by default, or you can specify a custom filename in the network_ranges_csv_filename column of socket_sites.csv"
}

variable "wifi_ssid_passkeys" {
  description = "PSK passkeys for Wi-Fi SSIDs defined in sites[].wifi_ssids[] whose security.mode is \"PSK\", keyed by \"<site name>:<ssid name>\" (e.g. \"Branch 1:Guest Wi-Fi\"). The Cato API never returns the passkey, so it cannot be recovered on brownfield import or refresh. Each site's entries are split out and passed to its child module keyed by ssid name only."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "allow_empty_sites" {
  type        = bool
  default     = false
  description = "Safety guard: fail planning when the sites data contains 0 sites unless explicitly allowed. Protects against a truncated or wrong-tenant export destroying every live site. Set true only for intentional greenfield/teardown."
}
