# Cato Networks Socket Bulk Sites Terraform Module

[![Terraform Registry](https://img.shields.io/badge/terraform-registry-623CE4.svg)](https://registry.terraform.io/modules/catonetworks/socket-bulk-sites/cato/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Terraform Version](https://img.shields.io/badge/terraform-%3E%3D1.5-623CE4.svg)](https://terraform.io)

Terraform module for bulk deployment of Cato Networks socket sites from CSV or JSON data files. This module simplifies the process of managing multiple socket sites and their configurations as code.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Creating Sites from CSV](#creating-sites-from-csv)
  - [Creating Sites from JSON](#creating-sites-from-json)
- [Brownfield Deployments](#brownfield-deployments)
- [Important Notes & Limitations](#important-notes--limitations)
- [Troubleshooting](#troubleshooting)
- [Version Compatibility](#version-compatibility)
- [Requirements](#requirements)
- [Inputs](#inputs)
- [Outputs](#outputs)

## Overview

This Terraform module provides a streamlined way to provision and manage multiple Cato socket sites at scale. It supports two input formats:

1. **CSV-based Configuration**: Using a main CSV file for sites and individual CSV files for network ranges
2. **JSON-based Configuration**: Using a single JSON file containing all site and network range information

The module is designed to work seamlessly with the Cato CLI tool for exporting existing configurations and importing them as Terraform resources, enabling infrastructure-as-code management for your entire Cato Networks deployment.

### Features

- **Bulk Deployment**: Provision multiple sites simultaneously using a single configuration
- **Brownfield Support**: Import existing Cato socket site configurations for Terraform management
- **Format Flexibility**: Support for both CSV and JSON input formats
- **Network Range Management**: Comprehensive configuration of all network range settings
- **Integration with Cato CLI**: Simplified export and import workflows

## Prerequisites

Before using this module, ensure you have:

- **Terraform**: Version >= 1.5.0 installed
- **CatoCLI**: Version >= 3.0.2 installed
- **Cato Account**: Commercial Cato Networks account with API access
- **Required Permissions**:
  - Cato: API token with Edit permissions

### Installing Cato CLI

```bash
pip install catocli
```

**Note**: Ensure you have Python 3.6 or later installed on your system.

### Configuring the CatoCLI

Before using the CLI, you need to configure your Cato API credentials:

1. **Create API Key**: Log into your Cato Management Application and generate an API key with appropriate permissions
2. **Configure credentials** using one of the following methods:

   ```bash
   # Interactive configuration
   catocli configure
   
   # Direct configuration (default profile)
   catocli configure set --cato-token YOUR_API_TOKEN --account-id YOUR_ACCOUNT_ID
   
   # Direct configuration using a specific profile
   catocli configure set --profile my-profile --cato-token YOUR_API_TOKEN --account-id YOUR_ACCOUNT_ID
   
   # Setting the API endpoint (for region specific CMA urls)
   catocli configure set --endpoint https://api.catonetworks.com/api/v1/graphql2 --cato-token YOUR_API_TOKEN --account-id YOUR_ACCOUNT_ID
   ```

## Quick Start

1. **Export your existing Cato socket sites**:
   ```bash
   # Export to CSV
   catocli export socket_sites -f csv --output-directory=config_data_csv
   
   # Or export to JSON
   catocli export socket_sites -f json --output-directory=config_data
   ```

2. **Create a Terraform configuration file**:
   ```hcl
   # For CSV data
   module "sites_from_csv" {
     source = "catonetworks/socket-bulk-sites/cato"
     
     sites_csv_file_path = "config_data_csv/socket_sites.csv"
     sites_csv_network_ranges_folder_path = "config_data_csv/sites_config/"
   }
   
   # For JSON data
   module "sites_from_json" {
     source = "catonetworks/socket-bulk-sites/cato"
     
     sites_json_file_path = "config_data/socket_sites.json"
   }
   ```

3. **Deploy your socket sites**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Usage

### Creating Sites from CSV

The CSV-based approach uses:
- A main CSV file containing socket site configurations
- Individual CSV files for each site's network ranges

#### Template Files
The module includes template CSV files to help you get started:
- [Sample socket_sites.csv](https://github.com/catonetworks/terraform-cato-socket-bulk-sites/blob/main/templates/socket_sites.csv)
- [Sample network_ranges.csv](https://github.com/catonetworks/terraform-cato-socket-bulk-sites/blob/main/templates/Test_network_ranges.csv)

#### Example Workflow

1. **Export existing sites to CSV format**:
   ```bash
   catocli export socket_sites -f csv --output-directory=config_data_csv
   ```

2. **Import the configuration into Terraform**:
   ```bash
   catocli import socket_sites_to_tf --data-type csv --csv-file config_data_csv/socket_sites.csv --csv-folder config_data_csv/sites_config/ --module-name module.sites_from_csv --auto-approve
   ```

3. **Configure the module in your Terraform file**:
   ```hcl
   module "sites_from_csv" {
     source = "catonetworks/socket-bulk-sites/cato"
     
     sites_csv_file_path = "config_data_csv/socket_sites.csv"
     sites_csv_network_ranges_folder_path = "config_data_csv/sites_config/"
   }
   ```

### Creating Sites from JSON

The JSON-based approach uses a single file containing all site and network range information.

#### Template Files
The module includes a sample JSON file to help you get started:
- [Sample socket_sites.json](https://github.com/catonetworks/terraform-cato-socket-bulk-sites/blob/main/templates/socket_sites.json)

#### Example Workflow

1. **Export existing sites to JSON format**:
   ```bash
   catocli export socket_sites -f json --output-directory=config_data
   ```

2. **Import the configuration into Terraform**:
   ```bash
   catocli import socket_sites_to_tf --data-type json --json-file config_data/socket_sites.json --module-name module.sites_from_json
   ```

3. **Configure the module in your Terraform file**:
   ```hcl
   module "sites_from_json" {
     source = "catonetworks/socket-bulk-sites/cato"
     
     sites_json_file_path = "config_data/socket_sites.json"
   }
   ```

## Brownfield Deployments

This module is particularly valuable for brownfield deployments where you need to bring existing Cato Networks infrastructure under Terraform management. The workflow for managing existing sites:

1. **Export your current configuration** from the Cato Management Application to CSV or JSON using the `catocli export` command.

2. **Import the configuration into Terraform** using the `catocli import socket_sites_to_tf` command, which creates the necessary Terraform configuration files.

3. **Make incremental changes** to your infrastructure by modifying the imported configuration files and applying the changes with Terraform.

This approach enables you to:
- Manage existing sites as code
- Bulk update configurations across multiple sites
- Add new network ranges to existing sites
- Track configuration changes in version control
- Enforce consistency across your infrastructure

### Examples

#### CSV Export and Import
```bash
# Export existing sites to CSV
catocli export socket_sites -f csv --output-directory=config_data_csv

# Import into Terraform
catocli import socket_sites_to_tf --data-type csv --csv-file config_data_csv/socket_sites.csv --csv-folder config_data_csv/sites_config/ --module-name module.sites_from_csv --auto-approve
```

#### JSON Export and Import
```bash
# Export existing sites to JSON
catocli export socket_sites -f json --output-directory=config_data

# Import into Terraform
catocli import socket_sites_to_tf --data-type json --json-file config_data/socket_sites.json --module-name module.sites_from_json
```

## Important Notes & Limitations

### CSV File Structure
- The main CSV file must include columns for all site attributes
- Network range CSV files must be named `{site_name}_network_ranges.csv`
- Ensure all required fields are populated according to the templates

### JSON Structure
- The JSON file must follow the structure shown in the template
- All site attributes should be properly nested as per the template

### DHCP Configuration
- DHCP settings should be specified within the network range configuration
- Supported DHCP types include: `DHCP_DISABLED`, `DHCP_SERVER`, and `DHCP_RELAY`
- When using DHCP relay, ensure `relay_group_id` or `relay_group_name` is specified

### LAG (Link Aggregation) Configuration
- For LAG member interfaces, use `LAN_LAG_MEMBER` for the `lan_interface_dest_type`
- LAG member interfaces do not require subnet configuration
- Ensure the LAG master interface is properly configured

## Troubleshooting

### Common Issues

**Missing Network Range Files:**
- Ensure each site has a corresponding network range file named `{site_name}_network_ranges.csv` when using CSV format
- Verify the path to the network ranges folder is correct

**Import Failures:**
- Check that the CSV or JSON files follow the expected format and structure
- Ensure all required fields are properly populated
- Verify that your Cato API token has the necessary permissions

**DHCP Configuration Issues:**
- Ensure DHCP settings are correctly specified in the network range configuration
- Verify that relay group names or IDs exist in your Cato account

### Debug Commands

```bash
# Test API connectivity
catocli ping

# Validate configuration
catocli configure show

# Show available commands
catocli -h
```

## Version Compatibility

| Module Version | Terraform | Cato Provider | CatoCLI |
|----------------|-----------|---------------|----------|
| 0.1.0+         | >= 1.5.0  | >= 0.0.43     | >= 3.0.2 |

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_cato"></a> [cato](#requirement\_cato) | >=0.0.43 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_socket-site"></a> [socket-site](#module\_socket-site) | ../terraform-cato-socket | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_sites_csv_file_path"></a> [sites\_csv\_file\_path](#input\_sites\_csv\_file\_path) | Path to the main CSV file containing the site configuration data. Either this or sites\_json\_file\_path must be provided. | `string` | `null` | no |
| <a name="input_sites_csv_network_ranges_folder_path"></a> [sites\_csv\_network\_ranges\_folder\_path](#input\_sites\_csv\_network\_ranges\_folder\_path) | Path to the folder containing individual CSV files with network ranges data for each site. Optional when using CSV input. Files should be named {site\_name}\_network\_ranges.csv | `string` | `null` | no |
| <a name="input_sites_json_file_path"></a> [sites\_json\_file\_path](#input\_sites\_json\_file\_path) | Path to the JSON file containing the site configuration data. Either this or sites\_csv\_file\_path must be provided. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lan_interfaces_by_id"></a> [lan\_interfaces\_by\_id](#output\_lan\_interfaces\_by\_id) | LAN interfaces indexed by their ID as string values |
| <a name="output_sites_by_connection_type"></a> [sites\_by\_connection\_type](#output\_sites\_by\_connection\_type) | Sites grouped by their connection type |
| <a name="output_sites_by_location"></a> [sites\_by\_location](#output\_sites\_by\_location) | Sites grouped by location |
| <a name="output_sites_by_type"></a> [sites\_by\_type](#output\_sites\_by\_type) | Sites grouped by their type |
<!-- END_TF_DOCS -->