# Terraform Cato Socket Bulk Sites

This Terraform module allows you to provision multiple Cato socket sites from either CSV or JSON data files. It's designed to work seamlessly with the Cato CLI tool for exporting existing configurations and importing them as Terraform resources.

## Prerequisites

### Installing Cato CLI

The Cato CLI (`catocli`) is required to export existing socket site configurations and generate the data files needed by this module.

#### Installation

Install the Cato CLI using pip:

```bash
pip install catocli
```

**Note**: Ensure you have Python 3.6 or later installed on your system.

### Configuring Cato CLI Credentials

Before using the CLI, you need to configure your Cato API credentials:

1. **Create API Key**: Log into your Cato Management Application and generate an API key with appropriate permissions
2. **Configure credentials** using one of these methods:

   ```bash
   catocli configure
   ```
   Follow the prompts to enter your API token and account ID.

## Usage Workflow

This module supports two main workflows for bulk site provisioning:

### Workflow 1: CSV-based Configuration

1. **Export existing socket sites to CSV format:**
   ```bash
   catocli export socket_sites -f csv --output-directory=config_data_csv
   ```
   This creates CSV files containing your existing socket site configurations.

2. **Import and generate Terraform configuration:**
   ```bash
   catocli import socket_sites_to_tf --data-type csv --csv-file config_data_csv/socket_sites_11362.csv --csv-folder config_data_csv/sites_config_11362/ --module-name module.sites_from_csv --auto-approve
   ```
   
   This command:
   - Reads the CSV file containing site data
   - Processes individual site network range CSV files from the specified folder
   - Generates Terraform configuration using the specified module name
   - Automatically approves the import process

### Workflow 2: JSON-based Configuration

1. **Export existing socket sites to JSON format:**
   ```bash
   catocli export socket_sites -f json --output-directory=config_data
   ```
   This creates a JSON file containing your existing socket site configurations.

2. **Import and generate Terraform configuration:**
   ```bash
   catocli import socket_sites_to_tf --data-type json --json-file config_data/socket_sites_11362.json --module-name module.sites_from_json
   ```
   
   This command:
   - Reads the JSON file containing site data
   - Generates Terraform configuration using the specified module name

## Module Usage

After running the import commands above, you can use this module in your Terraform configuration:

### Using CSV Data
```hcl
module "sites_from_csv" {
  source = "catonetworks/socket-bulk-sites/cato"
  
  sites_csv_file_path = "config_data_csv/socket_sites_11362.csv"
  sites_csv_network_ranges_folder_path = "config_data_csv/sites_config_11362/"
}
```

### Using JSON Data
```hcl
module "sites_from_json" {
  source = "catonetworks/socket-bulk-sites/cato"
  
  sites_json_file_path = "config_data/socket_sites_11362.json"
}
```

## File Structure

### CSV Format
When using CSV format, the export creates:
- Main CSV file: `socket_sites_{account_id}.csv` - Contains site configuration data
- Individual CSV files: `{site_name}_network_ranges.csv` - Contains network ranges for each site

### JSON Format
When using JSON format, the export creates:
- Single JSON file: `socket_sites_{account_id}.json` - Contains all site configuration data including network ranges

## Next Steps

After configuring the module:

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Plan the deployment:**
   ```bash
   terraform plan
   ```

3. **Apply the configuration:**
   ```bash
   terraform apply
   ```

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