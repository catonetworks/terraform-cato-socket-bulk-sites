# Changelog

## 0.0.1 (2025-09-24)

### Features
- Initial commit

## 0.0.2 (2025-09-24)

### Features
- Updated Readme

## 0.0.3 (2025-10-20)

### Features
- Updated module input validation to require a value for native_range_local_ip
- Updated csv templates to exclude ip values for new creation of site from csv format

## 0.0.4 (2025-10-23)
- Incrementing TF version to 1.13 and provider to 0.0.47 to address comples csv parsing string mapping required in newer versions

## 0.0.5 (2025-10-23)
- Added license resource to module

## 0.0.7 (2025-10-23)
- Fix for DHCP_RELAY group name from csv
- Added override for site network ranges csv per site

## 0.0.8 (2026-01-15)
- Updated json logic to reflect csv logic to properly detect and ignore changes in source data, and  align to new export format to index resources by id and handle empty values

## 0.0.9 (2026-01-16)
- Reverted indexing back to using names to accommodate new creation of records and impoorts of existing sites into terraform

## 0.0.10 (2026-01-19)
- Added logic to support network_range files with no network range entries

## 0.0.11 (2026-02-23)
- Updated module to support custom inteface_index for default lan for socket

## 0.0.12 (2026-03-26)
- Added outputs

## 0.0.13 (2026-04-14)
- Fixed processing ranges for direct and routed to ignore dhcp

## 0.0.14 (2026-05-05)
- Added `internet_only` support for network ranges.

## 0.0.15 (2026-11-04)
- Added per-site `sites[].wifi_ssids[]` passthrough to each site's `cato_wifi_ssid` resources, plus a sensitive `wifi_ssid_passkeys` map keyed `"<site name>:<ssid name>"`, split per-site and passed down to the child module keyed by SSID name.
- Added `wifi_ssids` output (map of `"<site name>:<ssid name>"` to the created `cato_wifi_ssid` resource ID).
- Added `allow_empty_sites` safety guard: planning fails if the sites data resolves to 0 sites, unless explicitly set `true`, protecting against a truncated or wrong-tenant export destroying every live site.
- Re-confirmed 0.0.14 `internet_only` support for network ranges in-tree (CSV-derived LAN interface ranges and JSON-derived ranges).
- README overhaul: JSON schema section now documents `wifi_ssids`; brownfield-import docs now present two options -- native Terraform `import` blocks (Option A, recommended) and `catocli import socket_sites_to_tf` (Option B) -- including a full `migration.tf` example with a per-resource import-ID table covering all 5 resource families (`cato_socket_site`, `cato_wan_interface`, `cato_lan_interface`, `cato_lan_interface_lag_member`, `cato_network_range`, `cato_wifi_ssid`).
- Bumped required provider version to `= 1.5.0-prerelease.1` and required Terraform core version to `>= 1.5`.
