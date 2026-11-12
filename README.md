# Cato Networks Socket Bulk Sites Terraform Module

[![Terraform Registry](https://img.shields.io/badge/terraform-registry-623CE4.svg)](https://registry.terraform.io/modules/catonetworks/socket-bulk-sites/cato/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Terraform Version](https://img.shields.io/badge/terraform-%3E%3D1.5-623CE4.svg)](https://terraform.io)

This module allows you to bulk provision Cato Networks socket sites (and their WAN interfaces, LAN interfaces, network ranges, and Wi-Fi SSIDs) from a CSV or JSON configuration data set, as code. It is designed to work seamlessly with the Cato CLI tool for exporting existing site configurations and importing them as Terraform resources.

### Features

- **Bulk Deployment**: Provision multiple sites simultaneously using a single configuration
- **Brownfield Support**: Export and import existing Cato socket site configurations for Terraform management

## Prerequisites

Before using this module, ensure you have:

- **Terraform**: Version >= 1.5 installed
- **CatoCLI**: Version >= 3.0.2 installed
- **Cato Account**: Commercial Cato Networks account with API access
- **Required Permissions**:
  - Cato: API token with Edit permissions

## Usage

The module reads either a JSON configuration file or a CSV configuration file (plus a per-site network-ranges CSV folder) that defines:
- **Sites**: Individual socket sites with their location, connection type, and description
- **WAN interfaces**: Per-site WAN interface configurations
- **LAN interfaces**: Per-site LAN interfaces, including LAG member interfaces
- **Network ranges**: Per-LAN-interface network ranges (including the site's native/default range)
- **Wi-Fi SSIDs**: Optional per-site Wi-Fi SSID configurations

Unlike the rules-oriented bulk modules, there is no section/ordering concept here - every site, interface, and range in the data set is created unconditionally (subject to the `allow_empty_sites` guard below).

### Basic Example

**Create bulk sites from JSON:**

```hcl
terraform {
  required_providers {
    cato = {
      source  = "catonetworks/cato"
      version = "= 1.5.0-prerelease.2"
    }
  }
  required_version = ">= 1.5"
}

provider "cato" {
  baseurl    = "https://api.catonetworks.com/api/v1/graphql2"
  token      = var.cato_token
  account_id = var.account_id
}

module "sites_from_json" {
  source                = "catonetworks/socket-bulk-sites/cato"
  sites_json_file_path   = "config_data/socket_sites.json"
}
```

**Create bulk sites from CSV:**

```hcl
module "sites_from_csv" {
  source                                = "catonetworks/socket-bulk-sites/cato"
  sites_csv_file_path                   = "config_data_csv/socket_sites.csv"
  sites_csv_network_ranges_folder_path  = "config_data_csv/sites_config/"
}
```

**Deploy your socket sites:**

```bash
terraform init
terraform plan
terraform apply
```

The module includes template files to help you get started:
- [Sample socket_sites.json](https://github.com/catonetworks/terraform-cato-socket-bulk-sites/blob/main/templates/socket_sites.json)
- [Sample bulk socket_sites.csv](https://github.com/catonetworks/terraform-cato-socket-bulk-sites/blob/main/templates/socket_sites.csv)
- [Sample test site network_ranges.csv](https://github.com/catonetworks/terraform-cato-socket-bulk-sites/blob/main/templates/Test_network_ranges.csv)

### JSON Configuration Structure

Unlike the policy/rules bulk modules, this module's JSON root is **flat** - there is no `data.policy.*` wrapper. The JSON file's top-level `sites[]` array is the entire input:

- `sites[].name`, `.description`, `.type`, `.connection_type` - basic site identity
- `sites[].site_location` - `address`, `city`, `country_code`, `state_code`, `timezone`
- `sites[].wan_interfaces[]` - WAN interface definitions, keyed by `index`
- `sites[].lan_interfaces[]` - LAN interface definitions (including LAG members), keyed by `index`, each with its own `network_ranges[]`
- `sites[].wifi_ssids[]` - optional Wi-Fi SSID definitions, keyed by `name`

#### Key Fields: Wi-Fi SSIDs (`sites[].wifi_ssids[]`)

Each site entry may include an optional `wifi_ssids` array. Each entry becomes one `cato_wifi_ssid` resource on that site, keyed by SSID `name`, and is passed through to the child module unchanged.

- `id` - present in `catocli` export output; ignored on input (Terraform manages the resource ID via state)
- `name` - SSID name; also the key used for `module.socket-site["<site name>"].cato_wifi_ssid.this["<ssid name>"]` and for `wifi_ssid_passkeys`
- `network_interface_id` - an unused Wi-Fi interface on the site (e.g. `WBR1`); replace-on-change
- `band`, `category` - the API currently supports `category: "GUEST"` only
- `enabled`, `visible`, `internet_only` - optional
- `subnet`, `local_ip`, `mdns_enabled`, `microsegmentation_enabled` - required
- `dhcp.dhcp_subnet` - optional, omit the whole `dhcp` object to leave DHCP unset
- `security.mode`, `security.auth_protocol`, `security.track_authentication` - `track_authentication` is optional

**PSK passkeys are not stored in this JSON.** The Cato API never returns a configured passkey, so `catocli export` cannot capture it and brownfield import cannot recover it. Supply passkeys for any `security.mode == "PSK"` SSID via the separate, sensitive `wifi_ssid_passkeys` variable, keyed `"<site name>:<ssid name>"` - see [Parameters](#parameters). Creating or updating a PSK SSID requires an entry here; omitting one leaves `security.psk` unset.

<details>
<summary>Click to expand a wifi_ssids example</summary>

```json
{
  "sites": [
    {
      "name": "Test",
      "wifi_ssids": [
        {
          "name": "Guest Wi-Fi",
          "network_interface_id": "WBR1",
          "band": "BOTH",
          "category": "GUEST",
          "enabled": true,
          "visible": true,
          "internet_only": false,
          "subnet": "10.30.50.0/24",
          "local_ip": "10.30.50.1",
          "mdns_enabled": false,
          "microsegmentation_enabled": false,
          "dhcp": {
            "dhcp_subnet": "10.30.50.128/25"
          },
          "security": {
            "mode": "PSK",
            "auth_protocol": "WPA3",
            "track_authentication": false
          }
        }
      ]
    }
  ]
}
```

```hcl
# terraform.tfvars
wifi_ssid_passkeys = {
  "Test:Guest Wi-Fi" = "a-wpa3-passkey"
}
```
</details>

### Parameters

- `sites_json_file_path`: Path to the JSON file containing the site configuration data. Either this or `sites_csv_file_path` must be provided.
- `sites_csv_file_path`: Path to the main CSV file containing the site configuration data. Either this or `sites_json_file_path` must be provided.
- `sites_csv_network_ranges_folder_path`: (Optional) Path to the folder containing individual CSV files with network ranges data for each site. Files should be named `{site_name}_network_ranges.csv` by default, or a custom filename can be set via the `network_ranges_csv_filename` column of `socket_sites.csv`.
- `wifi_ssid_passkeys`: (Optional, sensitive) PSK passkeys for Wi-Fi SSIDs defined in `sites[].wifi_ssids[]` whose `security.mode` is `"PSK"`, keyed `"<site name>:<ssid name>"`.
- `allow_empty_sites`: (Optional) Safety guard - fails planning if the sites data resolves to 0 sites, since that almost always means a truncated export, a renamed upstream JSON/CSV key, or an accidentally wrong-tenant data file. Set `true` only for an intentional greenfield/teardown config.

## Working with Existing Sites (Brownfield Deployments)

This module is particularly valuable for brownfield deployments where you need to bring existing Cato Networks infrastructure under Terraform management. There are two supported ways to adopt existing sites into this module's state - pick one per migration:

- **Option A (recommended)** - native Terraform `import` blocks. Fully declarative, previewable with `terraform plan` before anything touches state, no extra tooling beyond Terraform itself. Requires Terraform >= 1.7.
- **Option B** - `catocli import socket_sites_to_tf`. A single imperative command that also generates the `.tf` configuration files for you; writes to state immediately with no plan preview. Still the most battle-tested path for a site's deep internals (LAG members, nested network ranges) if you'd rather not hand-build `migration.tf`.

Every resource this module creates per site (`cato_socket_site`, `cato_wan_interface`, `cato_lan_interface`, `cato_lan_interface_lag_member`, `cato_network_range`, `cato_wifi_ssid`) has a working provider `ImportState` implementation and a `for_each` key that's fully derivable from the exported JSON - there is no resource in this stack where Option A is structurally blocked.

### Installing and Configuring Cato CLI

```bash
pip3 install catocli
```

**Note**: Ensure you have Python 3.6 or later installed on your system.

Before using the CLI, configure your Cato API credentials:

1. **Create API Key**: Log into your Cato Management Application and [generate an API key with appropriate permissions](https://support.catonetworks.com/hc/en-us/articles/29899905115421-Generating-API-Keys-for-the-Cato-API-EA)

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

### Exporting Existing Sites

```bash
# Export to JSON
catocli export socket_sites -f json --output-directory=config_data

# Or export to CSV
catocli export socket_sites -f csv --output-directory=config_data_csv
```

This command will generate a data file containing all your existing sites, WAN/LAN interfaces, network ranges, and Wi-Fi SSIDs in the format required by this Terraform module.

### Importing Existing Sites into Terraform State

<details>
<summary>Option A (recommended) — native Terraform import blocks (migration.tf)</summary>

A brownfield site's full adoption spans several nested resources and modules, each with its own import ID format (verified against the `catonetworks/terraform-provider-cato` source, quoted below) and its own `for_each` key:

| # | Resource | Address (relative to `module.sites.module.socket-site[<site name>]`) | for_each key source | Import ID format | Verified in provider source |
|---|---|---|---|---|---|
| 1 | `cato_socket_site.site` | `cato_socket_site.site` | n/a (one per site) | plain site ID | `resource_socket_site.go`: `resource.ImportStatePassthroughID(ctx, path.Root("id"), req, resp)` |
| 2 | `cato_wan_interface.wan[...]` / `.wan_lte[...]` | `cato_wan_interface.wan["<index>"]` (or `.wan_lte[...]` if `index == "LTE"`) | `wan_interfaces[].index` | `"<site_id>:<interface_index>"` | `resource_wan_interface.go` Read: `"Expected format 'site_id:interface_id', got: "+state.ID.ValueString()` |
| 3a | `cato_lan_interface.interface[...]` (regular) | `module.lan_interfaces["<index>"].cato_lan_interface.interface["<index>"]` | `lan_interfaces[].index` | plain entity ID | `resource_lan_interface.go`: `resource.ImportStatePassthroughID(...)`; Read matches `curIint.Entity.ID == state.ID.ValueString()` |
| 3b | `cato_lan_interface_lag_member.lag_lan_members[...]` | `cato_lan_interface_lag_member.lag_lan_members["<index>"]` | `lan_interfaces[].index` (where `dest_type == "LAN_LAG_MEMBER"`) | `"<site_id>:<interface_index>"` -- **must be computed**, see below | `resource_lan_interface_lag_member.go`: `"invalid LAN LAG Member interface ID format: expected format 'site_id:interface_index', got: %s"` |
| 4a | `cato_network_range.default_interface_ranges[...]` | `cato_network_range.default_interface_ranges["<name>_<idx>"]` | `"<range.name>_<idx>"`, idx = position in the flattened, native-range-excluded list for that site | plain range ID | `resource_network_range.go`: `resource.ImportStatePassthroughID(...)`; `state.ID = types.StringValue(req.ID)` |
| 4b | `cato_network_range.with_dhcp[0]` / `.no_dhcp[0]` | `module.lan_interfaces["<lan index>"].module.network_ranges.module.network_range["<name>_<idx>"].cato_network_range.with_dhcp[0]` (or `.no_dhcp[0]`) | `"<range.name>_<idx>"`, idx = position within that LAN interface's own network_ranges array | plain range ID (same as 4a) | same provider resource as 4a; the **resource name** (`with_dhcp` vs `no_dhcp`) is a `count`, not a `for_each`, selected by whether the range's `dhcp_settings` is non-null (see `modules/network_range/main.tf` in `terraform-cato-network-ranges-bulk`) |
| 5 | `cato_wifi_ssid.this[...]` | `cato_wifi_ssid.this["<ssid name>"]` | `wifi_ssids[].name` | plain SSID ID | `resource_wifi_ssid.go`: `resource.ImportStatePassthroughID(ctx, path.Root("id"), req, resp)` |

Notes on the two cases that aren't a plain 1:1 copy of an `id` field from the JSON:

- **LAG members (3b) export with `id: null`.** The export has nowhere to put a LAG member's composite import ID, so it must be computed in `migration.tf` as `"${site.id}:${lan.index}"` -- shown in the locals below.
- **Regular LAN interface ranges (4b) are `count`-based, not `for_each`-based.** `modules/network_range` creates `cato_network_range.with_dhcp` (count = 1) when the range carries a non-null `dhcp_settings` object, or `cato_network_range.no_dhcp` (count = 1) otherwise -- never both. In this export format `dhcp_settings` is populated even for `DHCP_DISABLED`/`ACCOUNT_DEFAULT` ranges, so `with_dhcp[0]` is the common case; `no_dhcp[0]` only applies if a hand-authored JSON omits `dhcp_settings` entirely. `migration.tf` below splits the import blocks into two, one per resource name, since a single `import` block can't switch resource names based on a computed value.
- **The site's own native/primary range is not a separate resource.** The single range embedded in `cato_socket_site.site.native_range` (the site's default interface's primary subnet) is part of the site resource itself and comes in automatically when you import `cato_socket_site.site` -- don't try to import it again as a `cato_network_range`.

Every resource above is addressed by a human-readable key pulled straight from the exported JSON -- sites by `name`, WAN/LAN interfaces by their `index`, network ranges by `<name>_<idx>`, and Wi-Fi SSIDs by `name` -- never by the opaque Cato-assigned ID, matching the same convention the bulk module's own `for_each` already uses.

<details>

<summary>Click to expand a full migration.tf example (all 5 resource families, one site)</summary>

This example was validated with `terraform init -backend=false && terraform validate` against this module, `terraform-cato-socket`, and `terraform-cato-network-ranges-bulk`, using the `templates/socket_sites.json` sample shipped in this repo. It assumes your root module declares `module "sites" { source = "catonetworks/socket-bulk-sites/cato" ... }` -- adjust the `module.sites.` prefix to match whatever you named your own module call.

```hcl
# migration.tf -- one-time brownfield adoption. Delete after `terraform apply`
# reports "N imported, 0 added, 0 changed, 0 destroyed".

locals {
  migration_sites = jsondecode(file("${path.module}/config_data/socket_sites.json")).sites

  # ---- 2. WAN interfaces ---------------------------------------------
  # wan_interfaces[].id already ships as "<site_id>:<interface_index>" --
  # exactly the cato_wan_interface import ID format. The module for_each
  # key is the WAN's own `index` field (e.g. "INT_2", or "LTE").
  migration_wan = merge([
    for s in local.migration_sites : {
      for w in try(s.wan_interfaces, []) :
      "${s.name}|${w.index}" => {
        site_name = s.name
        key       = w.index
        import_id = w.id
        is_lte    = w.index == "LTE"
      }
    }
  ]...)

  # ---- 3. LAN interfaces (regular) + LAG members ----------------------
  # Regular (non-LAG, non-default) LAN interfaces: lan.id is a plain
  # entity ID, usable directly as the import ID. LAG members export with
  # lan.id == null -- their import ID is computed as "<site_id>:<index>".
  migration_lan_regular = merge([
    for s in local.migration_sites : {
      for l in try(s.lan_interfaces, []) :
      "${s.name}|${l.index}" => {
        site_name = s.name
        key       = l.index
        import_id = l.id
      } if !try(l.default_lan, false) && try(l.dest_type, "") != "LAN_LAG_MEMBER" && l.id != null
    }
  ]...)

  migration_lag_members = merge([
    for s in local.migration_sites : {
      for l in try(s.lan_interfaces, []) :
      "${s.name}|${l.index}" => {
        site_name = s.name
        key       = l.index
        import_id = "${s.id}:${l.index}" # lan.id is null for LAG members -- compute it
      } if try(l.dest_type, "") == "LAN_LAG_MEMBER"
    }
  ]...)

  # ---- 4a. Network ranges under the default/native LAN interface ------
  migration_default_ranges = merge([
    for s in local.migration_sites : {
      for idx, nr in flatten([
        for l in try(s.lan_interfaces, []) : [
          for nr in try(l.network_ranges, []) : nr
          if try(l.default_lan, false) && !try(nr.native_range, false)
        ]
      ]) :
      "${s.name}|${nr.name}_${idx}" => {
        site_name = s.name
        key       = "${nr.name}_${idx}"
        import_id = nr.id
      }
    }
  ]...)

  # ---- 4b. Network ranges under regular (non-default) LAN interfaces --
  # Split into with_dhcp / no_dhcp since a single import block can't pick
  # a resource name dynamically -- see the note above.
  migration_regular_ranges = merge([
    for s in local.migration_sites : merge([
      for l in try(s.lan_interfaces, []) : {
        for idx, nr in [
          for nr in try(l.network_ranges, []) : nr if !try(nr.native_range, false)
          ] :
        "${s.name}|${l.index}|${nr.name}_${idx}" => {
          site_name = s.name
          lan_key   = l.index
          range_key = "${nr.name}_${idx}"
          import_id = nr.id
          has_dhcp  = try(nr.dhcp_settings, null) != null
        }
      } if !try(l.default_lan, false) && try(l.dest_type, "") != "LAN_LAG_MEMBER"
    ]...)
  ]...)

  migration_regular_ranges_with_dhcp = { for k, v in local.migration_regular_ranges : k => v if v.has_dhcp }
  migration_regular_ranges_no_dhcp   = { for k, v in local.migration_regular_ranges : k => v if !v.has_dhcp }

  # ---- 5. Wi-Fi SSIDs --------------------------------------------------
  migration_ssids = merge([
    for s in local.migration_sites : {
      for ssid in try(s.wifi_ssids, []) :
      "${s.name}|${ssid.name}" => {
        site_name = s.name
        key       = ssid.name
        import_id = ssid.id
      }
    }
  ]...)
}

# ---- 1. cato_socket_site.site -----------------------------------------
import {
  for_each = { for s in local.migration_sites : s.name => s }
  to       = module.sites.module.socket-site[each.key].cato_socket_site.site
  id       = each.value.id
}

# ---- 2. WAN interfaces: non-LTE ----------------------------------------
import {
  for_each = { for k, v in local.migration_wan : k => v if !v.is_lte }
  to       = module.sites.module.socket-site[each.value.site_name].cato_wan_interface.wan[each.value.key]
  id       = each.value.import_id
}

# ---- 2. WAN interfaces: LTE ---------------------------------------------
import {
  for_each = { for k, v in local.migration_wan : k => v if v.is_lte }
  to       = module.sites.module.socket-site[each.value.site_name].cato_wan_interface.wan_lte[each.value.key]
  id       = each.value.import_id
}

# ---- 3a. LAN interfaces: regular -----------------------------------------
import {
  for_each = local.migration_lan_regular
  to       = module.sites.module.socket-site[each.value.site_name].module.lan_interfaces[each.value.key].cato_lan_interface.interface[each.value.key]
  id       = each.value.import_id
}

# ---- 3b. LAN interfaces: LAG members -------------------------------------
import {
  for_each = local.migration_lag_members
  to       = module.sites.module.socket-site[each.value.site_name].cato_lan_interface_lag_member.lag_lan_members[each.value.key]
  id       = each.value.import_id
}

# ---- 4a. Network ranges: default/native LAN interface --------------------
import {
  for_each = local.migration_default_ranges
  to       = module.sites.module.socket-site[each.value.site_name].cato_network_range.default_interface_ranges[each.value.key]
  id       = each.value.import_id
}

# ---- 4b. Network ranges: regular LAN interfaces (with dhcp_settings) -----
import {
  for_each = local.migration_regular_ranges_with_dhcp
  to       = module.sites.module.socket-site[each.value.site_name].module.lan_interfaces[each.value.lan_key].module.network_ranges.module.network_range[each.value.range_key].cato_network_range.with_dhcp[0]
  id       = each.value.import_id
}

# ---- 4b. Network ranges: regular LAN interfaces (no dhcp_settings) -------
import {
  for_each = local.migration_regular_ranges_no_dhcp
  to       = module.sites.module.socket-site[each.value.site_name].module.lan_interfaces[each.value.lan_key].module.network_ranges.module.network_range[each.value.range_key].cato_network_range.no_dhcp[0]
  id       = each.value.import_id
}

# ---- 5. Wi-Fi SSIDs -------------------------------------------------------
import {
  for_each = local.migration_ssids
  to       = module.sites.module.socket-site[each.value.site_name].cato_wifi_ssid.this[each.value.key]
  id       = each.value.import_id
}
```

</details>
</details>

<details>
<summary>Option B — catocli import socket_sites_to_tf (imperative alternative)</summary>

### IMPORTANT NOTE
Upgrade to the latest version of the catocli using `pip3 install --upgrade catocli`

1. **Export your current configuration** from the Cato Management Application to CSV or JSON using the `catocli export` command.
2. **Import the configuration into Terraform** using the `catocli import socket_sites_to_tf` command, which creates the necessary Terraform configuration files.
3. **Make incremental changes** to your infrastructure by modifying the imported configuration files and applying the changes with Terraform.

**Caveat vs. Option A**: this command writes to Terraform state immediately -- there is no `terraform plan`-style preview step before it mutates anything. It remains the most battle-tested path today for a site's deep internals (LAG members, nested per-interface network ranges) since it also generates the `.tf` configuration files for you, rather than relying on this module's existing `for_each` structure already matching what's being imported.

##### CSV Export and Import

```bash
# Export existing sites to CSV
catocli export socket_sites -f csv --output-directory=config_data_csv

# Import into Terraform
catocli import socket_sites_to_tf --data-type csv --csv-file config_data_csv/socket_sites.csv --csv-folder config_data_csv/sites_config/ --module-name module.sites_from_csv --auto-approve
```

##### JSON Export and Import

```bash
# Export existing sites to JSON
catocli export socket_sites -f json --output-directory=config_data

# Import into Terraform
catocli import socket_sites_to_tf --data-type json --json-file config_data/socket_sites.json --module-name module.sites_from_json
```

</details>

### Typical Brownfield Workflow

1. **Export** your current configuration: `catocli export socket_sites -f json --output-directory=config_data`.
2. **Write `migration.tf`** using the Option A example above, pointed at your exported JSON.
3. **`terraform plan`** -- this previews every import with no state changes yet. A healthy plan reads `N to import, 0 to add, 0 to change, 0 to destroy`; if anything shows as a *change* instead of a clean import, your JSON is stale relative to the live tenant -- re-export and retry before applying.
4. **`terraform apply`** -- performs the imports.
5. **Delete `migration.tf`.** Its job is done; leaving it in place has no effect on future plans (imports of already-imported resources are no-ops), but removing it keeps the repo clean.

### Backup and Restore Workflow

If unintended changes are made directly to sites, interfaces, ranges, or SSIDs in the Cato Management Application, you can restore to the last known good state:

1. **Apply your last known good configuration:**
   ```bash
   terraform apply
   ```
   This will restore sites and their interfaces/ranges/SSIDs to match your Terraform configuration.

2. **Alternatively, re-export and compare:**
   ```bash
   catocli export socket_sites -f json --output-directory=config_data
   # Compare with your existing JSON file to identify changes
   ```

## Using Module Outputs

The module provides outputs that can be used for monitoring, auditing, integration with other systems, and operational insights. Below are practical examples of how to use these outputs in your Terraform configuration.

<details>
<summary>Click to expand example client-side outputs</summary>

```hcl
# Quick reference for WAN interfaces and network ranges by site
output "quick_reference" {
  description = "Quick reference maps for WAN interfaces and network ranges"
  value = {
    wan_interfaces = module.sites_from_json.wan_interfaces
    network_ranges = module.sites_from_json.network_ranges
  }
}

# Socket site details for downstream modules
output "socket_site_details" {
  description = "All created socket site resources, keyed by site name"
  value       = module.sites_from_json.socket_sites
}

# Wi-Fi SSID resource IDs, for referencing from other modules/configs
output "wifi_ssid_ids" {
  description = "Map of \"<site name>:<ssid name>\" to the created cato_wifi_ssid resource ID"
  value       = module.sites_from_json.wifi_ssids
}

# Example: For integration with monitoring systems
output "monitoring_metrics" {
  description = "Example metrics that could be sent to monitoring systems"
  value = {
    deployment_timestamp = timestamp()
    total_sites          = length(module.sites_from_json.socket_sites)
  }
}
```
</details>

### Output Use Cases

These example outputs demonstrate various practical applications:

- **`quick_reference`**: WAN interface and network range lookups for referencing resources in other modules
- **`socket_site_details`**: Full per-site resource detail for downstream modules or audits
- **`wifi_ssid_ids`**: ID mappings for referencing Wi-Fi SSIDs elsewhere (e.g. in policy rules)
- **`monitoring_metrics`**: Metrics formatted for monitoring systems

## Important Notes & Limitations

### Missing Fields from API in Export
The following fields are missing in the read operations from the API and are not currently included in the export. After exporting, you will need to populate these fields with the desired values before applying changes.
1. lag_min_links
1. dhcp_type
1. ip_range
1. relay_group_id/relay_group_name
1. gateway
1. translated_subnet
1. internet_only
1. local_ip
1. range_type

### CSV File Structure
- The main CSV file must include columns for all site attributes
- Network range CSV files must be named `{site_name}_network_ranges.csv` by default
  - **Optional**: You can override the network ranges CSV filename by adding a `network_ranges_csv_filename` column to the socket_sites.csv file
  - When specified, this column allows you to use custom filenames for the network ranges CSV (e.g., `custom_ranges.csv`, `site1_lan.csv`)
  - If this column is empty or not present, the module will fall back to the default naming pattern
- Ensure all required fields are populated according to the templates

### JSON Structure
- The JSON file must follow the structure shown in the template and in [JSON Configuration Structure](#json-configuration-structure) above
- All site attributes should be properly nested as per the template

### DHCP Configuration
- DHCP settings should be specified within the network range configuration
- When using DHCP relay, ensure `relay_group_id` or `relay_group_name` is specified

### LAG (Link Aggregation) Configuration
- For LAG member interfaces, use `LAN_LAG_MEMBER` for the `lan_interface_dest_type`
- LAG member interfaces do not require subnet configuration
- Ensure the LAG master interface is properly configured

## Troubleshooting

### Common Issues

**Missing Network Range Files:**
- Ensure each site has a corresponding network range file named `{site_name}_network_ranges.csv` when using CSV format (or the custom filename specified in the `network_ranges_csv_filename` column)
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
| 0.0.15+        | >= 1.5    | = 1.5.0-prerelease.2 | >= 3.0.2 |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_cato"></a> [cato](#requirement\_cato) | = 1.5.0-prerelease.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_socket-site"></a> [socket-site](#module\_socket-site) | ../terraform-cato-socket | n/a |

## Resources

| Name | Type |
|------|------|
| [terraform_data.guard_empty_sites](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_empty_sites"></a> [allow\_empty\_sites](#input\_allow\_empty\_sites) | Safety guard: fail planning when the sites data contains 0 sites unless explicitly allowed. Protects against a truncated or wrong-tenant export destroying every live site. Set true only for intentional greenfield/teardown. | `bool` | `false` | no |
| <a name="input_sites_csv_file_path"></a> [sites\_csv\_file\_path](#input\_sites\_csv\_file\_path) | Path to the main CSV file containing the site configuration data. Either this or sites\_json\_file\_path must be provided. | `string` | `null` | no |
| <a name="input_sites_csv_network_ranges_folder_path"></a> [sites\_csv\_network\_ranges\_folder\_path](#input\_sites\_csv\_network\_ranges\_folder\_path) | Path to the folder containing individual CSV files with network ranges data for each site. Optional when using CSV input. Files should be named {site\_name}\_network\_ranges.csv by default, or you can specify a custom filename in the network\_ranges\_csv\_filename column of socket\_sites.csv | `string` | `null` | no |
| <a name="input_sites_json_file_path"></a> [sites\_json\_file\_path](#input\_sites\_json\_file\_path) | Path to the JSON file containing the site configuration data. Either this or sites\_csv\_file\_path must be provided. | `string` | `null` | no |
| <a name="input_wifi_ssid_passkeys"></a> [wifi\_ssid\_passkeys](#input\_wifi\_ssid\_passkeys) | PSK passkeys for Wi-Fi SSIDs defined in sites[].wifi\_ssids[] whose security.mode is "PSK", keyed by "<site name>:<ssid name>" (e.g. "Branch 1:Guest Wi-Fi"). The Cato API never returns the passkey, so it cannot be recovered on brownfield import or refresh. Each site's entries are split out and passed to its child module keyed by ssid name only. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_network_ranges"></a> [network\_ranges](#output\_network\_ranges) | Map of network ranges by site name |
| <a name="output_socket_sites"></a> [socket\_sites](#output\_socket\_sites) | Map of all socket site resources by site name |
| <a name="output_wan_interfaces"></a> [wan\_interfaces](#output\_wan\_interfaces) | Map of WAN interfaces by site name |
| <a name="output_wifi_ssids"></a> [wifi\_ssids](#output\_wifi\_ssids) | Map of "<site name>:<ssid name>" to the created cato\_wifi\_ssid resource ID |
<!-- END_TF_DOCS -->
