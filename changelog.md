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
