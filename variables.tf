## Config Data Directory and File Names
variable "sites_json_file_path" {
  type        = string
  default     = null
  description = "Path to the JSON file containing the site configuration data. Either this or sites_csv_file_path must be provided."
  
  validation {
    condition = var.sites_json_file_path != null || var.sites_csv_file_path != null
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
  description = "Path to the folder containing individual CSV files with network ranges data for each site. Optional when using CSV input. Files should be named {site_name}_network_ranges.csv"
}
