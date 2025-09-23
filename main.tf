locals {
  # Determine if we're using JSON or CSV input
  using_json = var.sites_json_file_path != null && var.sites_json_file_path != ""
  using_csv = var.sites_csv_file_path != null && var.sites_csv_file_path != ""
  
  # Validation - ensure exactly one input method is used
  input_validation = local.using_json && local.using_csv ? (
    regex("Error: Cannot use both JSON and CSV inputs simultaneously. Please specify either sites_json_file_path OR sites_csv_file_path, not both.", "")
  ) : (!local.using_json && !local.using_csv ? (
    regex("Error: Must specify either sites_json_file_path or sites_csv_file_path.", "")
  ) : "valid")
  
  # JSON data processing - use try() to handle type consistency
  json_sites_data = try(jsondecode(file(var.sites_json_file_path != null ? var.sites_json_file_path : "/dev/null")).sites, [])
  
  # CSV data processing
  sites_csv_raw = local.using_csv ? csvdecode(file(var.sites_csv_file_path)) : []
  
  # Transform CSV data to match JSON structure
  csv_sites_grouped = local.using_csv ? {
    for row in local.sites_csv_raw : row.site_name => row...
  } : {}
  
  # Read network ranges CSV files for each site when using CSV input
  site_network_ranges_data = local.using_csv && var.sites_csv_network_ranges_folder_path != null ? {
    for site_name, site_rows in local.csv_sites_grouped :
    site_name => try(
      csvdecode(file("${var.sites_csv_network_ranges_folder_path}/${replace(site_name, " ", "")}_network_ranges.csv")), 
      try(
        csvdecode(file("${var.sites_csv_network_ranges_folder_path}/${site_name}_network_ranges.csv")), 
        []
      )
    )
  } : {}
  
  # Validation for Routed network ranges - they should not have DHCP configuration fields with values
  routed_dhcp_validation_errors = flatten([
    for site_name, network_ranges in local.site_network_ranges_data : [
      for idx, nr in network_ranges : 
      "Site '${site_name}': Routed network range '${try(nr.network_range_name, "Unnamed")}' (${try(nr.subnet, "No subnet")}) cannot have DHCP configuration fields (dhcp_ip_range, dhcp_relay_group_id, dhcp_relay_group_name, dhcp_microsegmentation) set to non-empty/non-false values. For Routed ranges, only dhcp_type can be empty, DHCP_DISABLED, or ACCOUNT_DEFAULT."
      if try(nr.range_type, "") == "Routed" && (
        (try(nr.dhcp_ip_range, null) != null && try(nr.dhcp_ip_range, "") != "") ||
        (try(nr.dhcp_relay_group_id, null) != null && try(nr.dhcp_relay_group_id, "") != "") ||
        (try(nr.dhcp_relay_group_name, null) != null && try(nr.dhcp_relay_group_name, "") != "") ||
        (try(nr.dhcp_microsegmentation, null) != null && try(nr.dhcp_microsegmentation, null) != false && try(lower(tostring(nr.dhcp_microsegmentation)), "false") == "true")
      )
    ]
  ])

  # Use regex to force an error if there are validation issues
  routed_validation_check = length(local.routed_dhcp_validation_errors) > 0 ? regex(
    "ValidationError", 
    join("\n", concat(["VALIDATION ERROR:"], local.routed_dhcp_validation_errors, ["Please fix these configuration errors before proceeding."]))
  ) : "validation_passed"
  
  csv_sites_data = try(local.using_csv ? [
    for site_name, site_rows in local.csv_sites_grouped : {
      name = site_name
      description = try(site_rows[0].site_description, "")
      type = try(site_rows[0].site_type, "")
      connection_type = try(site_rows[0].connection_type, "")
      
      site_location = {
        address = try(site_rows[0].site_location_address, null) != "" ? try(site_rows[0].site_location_address, null) : "No address provided"
        city = try(site_rows[0].site_location_city, null)
        countryCode = try(site_rows[0].site_location_country_code, null)
        stateCode = try(site_rows[0].site_location_state_code, null)
        timezone = try(site_rows[0].site_location_timezone, null)
      }
      
      # Extract WAN interfaces from CSV rows
      wan_interfaces = [
        for row in site_rows : {
          index = row.wan_interface_index
          name = row.wan_interface_name
          upstream_bandwidth = try(tonumber(row.wan_upstream_bw), 0)
          downstream_bandwidth = try(tonumber(row.wan_downstream_bw), 0)
          role = row.wan_role
          precedence = row.wan_precedence
        } if row.wan_interface_index != "" && row.wan_interface_index != null && row.wan_interface_name != "" && row.wan_interface_name != null
      ]
      
      # Native range from CSV
      native_range = {
        subnet = try(trimspace(site_rows[0].native_range_subnet), "")
        local_ip = try(trimspace(site_rows[0].native_range_local_ip), null)
        interface_name = try(trimspace(site_rows[0].native_range_interface_name), "")
        interface_id = try(trimspace(site_rows[0].native_range_interface_id), "") # Now populated from CSV
        index = try(trimspace(site_rows[0].native_range_interface_index), "1")
        range_name = try(trimspace(site_rows[0].native_range_name), "Native Range")
        range_id = try(trimspace(site_rows[0].native_range_id), "")
        vlan = try(tonumber(trimspace(site_rows[0].native_range_vlan)), null) != 0 ? try(tonumber(trimspace(site_rows[0].native_range_vlan)), null) : null
        gateway = try(trimspace(site_rows[0].native_range_gateway), null)
        range_type = try(trimspace(site_rows[0].native_range_type), "Direct")
        translated_subnet = try(trimspace(site_rows[0].native_range_translated_subnet), null)
        mdns_reflector = try(lower(trimspace(site_rows[0].native_range_mdns_reflector)), "false") == "true"
        interface_dest_type = try(trimspace(site_rows[0].native_range_interface_dest_type), null)
        lag_min_links = try(tonumber(trimspace(site_rows[0].native_range_interface_lag_min_links)), null)
        dhcp_settings = {
          dhcp_type = try(trimspace(site_rows[0].native_range_dhcp_type), "DHCP_DISABLED")
          ip_range = try(trimspace(site_rows[0].native_range_dhcp_ip_range), null) != "" ? try(trimspace(site_rows[0].native_range_dhcp_ip_range), null) : null
          relay_group_id = try(trimspace(site_rows[0].native_range_dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(site_rows[0].native_range_dhcp_relay_group_id), "") != "" ? try(trimspace(site_rows[0].native_range_dhcp_relay_group_id), null) : null
          relay_group_name = try(trimspace(site_rows[0].native_range_dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(site_rows[0].native_range_dhcp_relay_group_name), "") != "" ? try(trimspace(site_rows[0].native_range_dhcp_relay_group_name), null) : null
          dhcp_microsegmentation = try(lower(trimspace(site_rows[0].native_range_dhcp_microsegmentation)), "false") == "true"
        }
      }
      
      # Process LAN interfaces from network ranges CSV data
      # This includes both regular LAN interfaces AND default interfaces with network ranges
      lan_interfaces = try(length(local.site_network_ranges_data[site_name]), 0) > 0 ? concat(
        # Regular LAN interfaces (those with explicit lan_interface_id)
        # Group by lan_interface_id for interfaces that have explicit IDs
        [
          for lan_id, lan_ranges in {
            for nr in local.site_network_ranges_data[site_name] : 
            try(nr.lan_interface_id, "unknown") => nr... if try(nr.lan_interface_id, "") != ""
          } : {
            id = lan_id
            name = try(lan_ranges[0].lan_interface_name, "LAN Interface")
            index = try(lan_ranges[0].lan_interface_index, "")
            dest_type = try(lan_ranges[0].lan_interface_dest_type, "LAN")
            default_lan = false
            # Include only non-native network ranges for this interface
            # Native ranges are managed at the LAN interface level, not as separate resources
            network_ranges = concat(
              # Non-native ranges for this interface
              [
                for nr in lan_ranges : {
                  id = try(nr.network_range_id, "")
                  name = try(nr.network_range_name, "Network Range")
                  subnet = try(nr.subnet, "")
                  vlan = try(tonumber(nr.vlan), null) != 0 ? try(tonumber(nr.vlan), null) : null
                  mdns_reflector = try(lower(nr.mdns_reflector), "false") == "true"
                  gateway = try(nr.gateway, null)
                  range_type = try(nr.range_type, "Direct")
                  translated_subnet = try(nr.translated_subnet, null)
                  local_ip = try(nr.local_ip, null)
                  native_range = try(lower(nr.is_native_range), "false") == "true"
                  dhcp_settings = {
                    dhcp_type = try(trimspace(nr.dhcp_type), "DHCP_DISABLED")
                    ip_range = try(trimspace(nr.dhcp_ip_range), null) != "" ? try(trimspace(nr.dhcp_ip_range), null) : null
                    relay_group_id = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_id), "") != "" ? try(trimspace(nr.dhcp_relay_group_id), null) : null
                    relay_group_name = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_name), "") != "" ? try(trimspace(nr.dhcp_relay_group_name), null) : null
                    dhcp_microsegmentation = try(lower(trimspace(nr.dhcp_microsegmentation)), "false") == "true"
                  }
                } if (
                  try(nr.subnet, "") != "" &&  # Only include rows with actual network range data (subnet is required)
                  try(lower(nr.is_native_range), "false") != "true"  # Exclude native ranges
                )
              ],
              # Additional non-native ranges for this interface (those without lan_interface_id but matching lan_interface_index)
              [
                for nr in local.site_network_ranges_data[site_name] : {
                  id = try(nr.network_range_id, "")
                  name = try(nr.network_range_name, "Network Range")
                  subnet = try(nr.subnet, "")
                  vlan = try(tonumber(nr.vlan), null) != 0 ? try(tonumber(nr.vlan), null) : null
                  mdns_reflector = try(lower(nr.mdns_reflector), "false") == "true"
                  gateway = try(nr.gateway, null)
                  range_type = try(nr.range_type, "Direct")
                  translated_subnet = try(nr.translated_subnet, null)
                  local_ip = try(nr.local_ip, null)
                  native_range = try(lower(nr.is_native_range), "false") == "true"
                  dhcp_settings = {
                    dhcp_type = try(trimspace(nr.dhcp_type), "DHCP_DISABLED")
                    ip_range = try(trimspace(nr.dhcp_ip_range), null) != "" ? try(trimspace(nr.dhcp_ip_range), null) : null
                    relay_group_id = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_id), "") != "" ? try(trimspace(nr.dhcp_relay_group_id), null) : null
                    relay_group_name = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_name), "") != "" ? try(trimspace(nr.dhcp_relay_group_name), null) : null
                    dhcp_microsegmentation = try(lower(trimspace(nr.dhcp_microsegmentation)), "false") == "true"
                  }
                } if (
                  try(nr.lan_interface_id, "") == "" &&  # No explicit lan_interface_id
                  try(nr.subnet, "") != "" &&  # Valid network range data (subnet is required)
                  try(nr.lan_interface_index, "") == try(lan_ranges[0].lan_interface_index, "") &&  # Matching interface index
                  try(nr.lan_interface_index, try(site_rows[0].native_range_interface_index, "")) != try(site_rows[0].native_range_interface_index, "") &&  # Not the default/native interface
                  try(lower(nr.is_native_range), "false") != "true"  # Exclude native ranges
                )
              ]
            )
          } if lan_id != "unknown" && lan_id != "" && (
            length([
              for nr in lan_ranges : nr if try(nr.subnet, "") != ""  # Only require subnet for valid network range
            ]) > 0 || # Create LAN interface if it has at least one valid network range (including native ranges)
            try(lan_ranges[0].lan_interface_dest_type, "") == "LAN_LAG_MEMBER" # OR if it's a LAG member (no subnet required)
          )
        ],
        # Virtual LAN interfaces for network ranges with explicit interface index but no interface ID
        # These are ranges that specify a lan_interface_index but have empty lan_interface_id
        # Exclude interface indices that already have explicit LAN interfaces to avoid duplicates
        [
          for interface_index, ranges in {
            for nr in local.site_network_ranges_data[site_name] : 
            try(nr.lan_interface_index, "") => nr... if (
              try(nr.lan_interface_id, "") == "" &&  # No explicit interface ID
              try(nr.lan_interface_index, "") != "" &&  # But has interface index
              (
                try(nr.subnet, "") != "" ||  # Valid network range (subnet is required) OR
                try(nr.lan_interface_dest_type, "") == "LAN_LAG_MEMBER"  # LAG member (no subnet required)
              ) &&
              try(nr.lan_interface_index, try(site_rows[0].native_range_interface_index, "")) != try(site_rows[0].native_range_interface_index, "") &&  # Not native interface
              try(lower(nr.is_native_range), "false") != "true" &&  # Exclude native ranges
              # Ensure this interface index doesn't already have an explicit LAN interface
              !contains([
                for nr_check in local.site_network_ranges_data[site_name] : try(nr_check.lan_interface_index, "")
                if try(nr_check.lan_interface_id, "") != ""
              ], try(nr.lan_interface_index, ""))
            )
          } : {
            id = null  # Virtual interface - no actual interface ID
            name = try([
              for nr in local.site_network_ranges_data[site_name] : trimspace(nr.lan_interface_name)
              if try(trimspace(nr.lan_interface_index), "") == interface_index && 
                 try(trimspace(nr.lan_interface_name), "") != "" &&
                 (try(lower(trimspace(nr.is_native_range)), "false") == "true" || try(trimspace(nr.lan_interface_dest_type), "") == "LAN_LAG_MEMBER")
            ][0], "LAN Interface ${interface_index}")
            index = interface_index
            dest_type = try([
              for nr in local.site_network_ranges_data[site_name] : nr.lan_interface_dest_type
              if try(trimspace(nr.lan_interface_index), "") == interface_index &&
                 try(trimspace(nr.lan_interface_dest_type), "") != ""
            ][0], "LAN")
            default_lan = false
            network_ranges = [
              for nr in ranges : {
                id = try(nr.network_range_id, "")
                name = try(nr.network_range_name, "Network Range")
                subnet = try(nr.subnet, "")
                vlan = try(tonumber(nr.vlan), null) != 0 ? try(tonumber(nr.vlan), null) : null
                mdns_reflector = try(lower(nr.mdns_reflector), "false") == "true"
                gateway = try(nr.gateway, null)
                range_type = try(nr.range_type, "Direct")
                translated_subnet = try(nr.translated_subnet, null)
                local_ip = try(nr.local_ip, null)
                native_range = try(lower(nr.is_native_range), "false") == "true"
                dhcp_settings = {
                  dhcp_type = try(trimspace(nr.dhcp_type), "DHCP_DISABLED")
                  ip_range = try(trimspace(nr.dhcp_ip_range), null) != "" ? try(trimspace(nr.dhcp_ip_range), null) : null
                  relay_group_id = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_id), "") != "" ? try(trimspace(nr.dhcp_relay_group_id), null) : null
                  relay_group_name = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_name), "") != "" ? try(trimspace(nr.dhcp_relay_group_name), null) : null
                  dhcp_microsegmentation = try(lower(trimspace(nr.dhcp_microsegmentation)), "false") == "true"
                }
              } if (
                try(nr.subnet, "") != "" &&  # Only include rows with actual network range data (subnet is required)
                try(lower(nr.is_native_range), "false") != "true"  # Exclude native ranges
              )
            ]
          } if length(ranges) > 0 || (
            # Create interface for LAG members even without network ranges
            length([
              for nr in local.site_network_ranges_data[site_name] : nr
              if try(trimspace(nr.lan_interface_index), "") == interface_index &&
                 try(trimspace(nr.lan_interface_dest_type), "") == "LAN_LAG_MEMBER"
            ]) > 0
          )
        ],
        # Default interfaces with network ranges (those without explicit lan_interface_id but with network ranges)
        # Check if there are any network ranges for default interfaces
        length([
          for nr in local.site_network_ranges_data[site_name] : nr 
          if (
            try(nr.lan_interface_id, "") == "" &&
            try(nr.subnet, "") != "" &&  # Only require subnet for default interface ranges
            (try(nr.is_native_range, "") == "" || try(lower(nr.is_native_range), "false") != "true") &&
            try(nr.lan_interface_index, try(site_rows[0].native_range_interface_index, "")) == try(site_rows[0].native_range_interface_index, "")
          )
        ]) > 0 ? [{
          id = null  # No ID for default interface - this signals it shouldn't be created as a separate resource
          name = try(site_rows[0].native_range_interface_name, "")
          index = try(site_rows[0].native_range_interface_index, "1")
          dest_type = "LAN"
          default_lan = true
          network_ranges = [
            for nr in local.site_network_ranges_data[site_name] : {
              id = try(nr.network_range_id, "")
              name = try(nr.network_range_name, "Network Range")
              subnet = try(nr.subnet, "")
              vlan = try(tonumber(nr.vlan), null) != 0 ? try(tonumber(nr.vlan), null) : null
              mdns_reflector = try(lower(nr.mdns_reflector), "false") == "true"
              gateway = try(nr.gateway, null)
              range_type = try(nr.range_type, "Direct")
              translated_subnet = try(nr.translated_subnet, null)
              local_ip = try(nr.local_ip, null)
              native_range = try(lower(nr.is_native_range), "false") == "true"
              dhcp_settings = {
                dhcp_type = try(trimspace(nr.dhcp_type), "DHCP_DISABLED")
                ip_range = try(trimspace(nr.dhcp_ip_range), null) != "" ? try(trimspace(nr.dhcp_ip_range), null) : null
                relay_group_id = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_id), "") != "" ? try(trimspace(nr.dhcp_relay_group_id), null) : null
                relay_group_name = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_name), "") != "" ? try(trimspace(nr.dhcp_relay_group_name), null) : null
                dhcp_microsegmentation = try(lower(trimspace(nr.dhcp_microsegmentation)), "false") == "true"
              }
            } if (
              try(nr.lan_interface_id, "") == "" &&
              try(nr.subnet, "") != "" &&  # Only require subnet for default interface ranges
              (try(nr.is_native_range, "") == "" || try(lower(nr.is_native_range), "false") != "true") &&
              try(nr.lan_interface_index, try(site_rows[0].native_range_interface_index, "")) == try(site_rows[0].native_range_interface_index, "")  # Only native interface index for default interfaces
            )
          ]
        }] : []
      ) : []
    }
  ] : [], [])
  
  # Combine JSON and CSV data (only one will have data)
  sites_data = concat(local.json_sites_data, local.csv_sites_data)
  
  # Helper to index all LAN interfaces by their interface index and name
  lan_interfaces_by_id = {
    for lan in flatten([
      for site in local.sites_data : 
        try(site.lan_interfaces, [])
    ]) : "${lan.index}-${lan.name}" => lan if can(lan.index) || can(lan.name)
  }
  
  # Collect all network ranges from all sites and LAN interfaces
  all_network_ranges = flatten([
    for site in local.sites_data : [
      for lan in try(site.lan_interfaces, []) : [
        for nr in lan.network_ranges : merge(nr, {
          site_name = site.name
          site_id = site.name  # Use site name as key for module reference
          lan_interface_index = try(can(tonumber(lan.index)) ? "INT_${lan.index}" : lan.index, "DEFAULT")
          lan_interface_name = try(lan.name, "Default LAN")
        }) if try(nr.native_range, false) == false && nr.subnet != ""  # Only require subnet for network ranges
      ] if length(lan.network_ranges) > 0
    ]
  ])
}

module "socket-site" {
  for_each = { for site in local.sites_data : site.name => site }
  source   = "../terraform-cato-socket"
  
  # Basic site information
  site_name        = each.value.name
  site_description = each.value.description
  site_type        = each.value.type
  connection_type  = each.value.connection_type
  
  # Site location
  site_location = merge({
    address      = each.value.site_location.address
    city         = each.value.site_location.city
    country_code = each.value.site_location.countryCode
    timezone     = each.value.site_location.timezone
  }, each.value.site_location.stateCode != null && each.value.site_location.stateCode != "" ? {
    state_code = each.value.site_location.stateCode
  } : {})
  
  # WAN interfaces (cato_interfaces) - transformed from wan_interfaces
  cato_interfaces = [
    for wan in each.value.wan_interfaces : {
      # Use the index field from source data, format as INT_X if it's just a number
      interface_index      = can(tonumber(wan.index)) ? "INT_${wan.index}" : wan.index
      name                 = wan.name
      upstream_bandwidth   = wan.upstream_bandwidth
      downstream_bandwidth = wan.downstream_bandwidth
      role                 = wan.role  # Use the actual role field
      precedence           = wan.precedence
    }
  ]
  
  # LAN interfaces - transformed from lan_interfaces with network_ranges
  # Include both regular interfaces (with lan.id) AND default interfaces (lan.id == null) that have network ranges
  # For default native range interfaces, omit dest_type so they won't be created as LAN interface resources
  lan_interfaces = [
    for lan in try(each.value.lan_interfaces, []) : merge({
      # For default_lan interfaces, use native_range info; otherwise use lan interface info
      name              = try(lan.default_lan, false) ? each.value.native_range.interface_name : lan.name
      interface_index   = try(lan.default_lan, false) ? (can(tonumber(each.value.native_range.index)) ? "INT_${each.value.native_range.index}" : each.value.native_range.index) : (can(tonumber(lan.index)) ? "INT_${lan.index}" : lan.index)
      # For default_lan interfaces (native range), omit dest_type so socket module won't create the LAN interface
      # For regular interfaces, include dest_type so socket module will create the LAN interface
      # For LAG members, pass the dest_type so socket module can create LAG member resources
      dest_type         = try(lan.default_lan, false) ? null : lan.dest_type
      subnet            = try(lan.default_lan, false) ? each.value.native_range.subnet : (
        # For regular LAN interfaces, find the subnet from the native range
        # First check if using CSV data
        local.using_csv && contains(keys(local.site_network_ranges_data), each.key) ? (
          # For virtual interfaces (lan.id == null), match by interface_index; for regular interfaces, match by interface_id
          lan.id == null ? (
            # Virtual interface - match by interface_index
            length([
              for nr in local.site_network_ranges_data[each.key] : nr
              if try(trimspace(nr.lan_interface_index), "") == lan.index && try(lower(trimspace(nr.is_native_range)), "false") == "true"
            ]) > 0 ? [
              for nr in local.site_network_ranges_data[each.key] : try(trimspace(nr.subnet), "")
              if try(trimspace(nr.lan_interface_index), "") == lan.index && try(lower(trimspace(nr.is_native_range)), "false") == "true"
            ][0] : (
              # Fallback to first non-native range if no native range found
              length(lan.network_ranges) > 0 ? lan.network_ranges[0].subnet : ""
            )
          ) : (
            # Regular interface - match by interface_id
            length([
              for nr in local.site_network_ranges_data[each.key] : nr
              if try(trimspace(nr.lan_interface_id), "") == lan.id && try(lower(trimspace(nr.is_native_range)), "false") == "true"
            ]) > 0 ? [
              for nr in local.site_network_ranges_data[each.key] : try(trimspace(nr.subnet), "")
              if try(trimspace(nr.lan_interface_id), "") == lan.id && try(lower(trimspace(nr.is_native_range)), "false") == "true"
            ][0] : (
              # Fallback to first non-native range if no native range found
              length(lan.network_ranges) > 0 ? lan.network_ranges[0].subnet : ""
            )
          )
        ) : (
          # For JSON data, look for native range in the LAN interface's network_ranges
          length([
            for nr in lan.network_ranges : nr
            if try(nr.native_range, false) == true
          ]) > 0 ? [
            for nr in lan.network_ranges : nr.subnet
            if try(nr.native_range, false) == true
          ][0] : (
            # Fallback to first range if no native range found
            length(lan.network_ranges) > 0 ? lan.network_ranges[0].subnet : ""
          )
        )
      )
      local_ip          = try(lan.default_lan, false) ? each.value.native_range.local_ip : (
        # For regular LAN interfaces, find the local_ip from the native range
        # First check if using CSV data
        local.using_csv && contains(keys(local.site_network_ranges_data), each.key) ? (
          # For virtual interfaces (lan.id == null), match by interface_index; for regular interfaces, match by interface_id
          lan.id == null ? (
            # Virtual interface - match by interface_index
            length([
              for nr in local.site_network_ranges_data[each.key] : nr
              if try(trimspace(nr.lan_interface_index), "") == lan.index && try(lower(trimspace(nr.is_native_range)), "false") == "true"
            ]) > 0 ? [
              for nr in local.site_network_ranges_data[each.key] : try(trimspace(nr.local_ip), null)
              if try(trimspace(nr.lan_interface_index), "") == lan.index && try(lower(trimspace(nr.is_native_range)), "false") == "true"
            ][0] : (
              # Fallback to first non-native range if no native range found
              length(lan.network_ranges) > 0 ? lan.network_ranges[0].local_ip : null
            )
          ) : (
            # Regular interface - match by interface_id
            length([
              for nr in local.site_network_ranges_data[each.key] : nr
              if try(trimspace(nr.lan_interface_id), "") == lan.id && try(lower(trimspace(nr.is_native_range)), "false") == "true"
            ]) > 0 ? [
              for nr in local.site_network_ranges_data[each.key] : try(trimspace(nr.local_ip), null)
              if try(trimspace(nr.lan_interface_id), "") == lan.id && try(lower(trimspace(nr.is_native_range)), "false") == "true"
            ][0] : (
              # Fallback to first non-native range if no native range found
              length(lan.network_ranges) > 0 ? lan.network_ranges[0].local_ip : null
            )
          )
        ) : (
          # For JSON data, look for native range in the LAN interface's network_ranges
          length([
            for nr in lan.network_ranges : nr
            if try(nr.native_range, false) == true
          ]) > 0 ? [
            for nr in lan.network_ranges : nr.local_ip
            if try(nr.native_range, false) == true
          ][0] : (
            # Fallback to first range if no native range found
            length(lan.network_ranges) > 0 ? lan.network_ranges[0].local_ip : null
          )
        )
      )
      translated_subnet = null
      network_ranges = [
        for nr in lan.network_ranges : merge({
          name              = nr.name
          range_type        = nr.range_type
          subnet            = nr.subnet
          local_ip          = nr.local_ip
          gateway           = nr.gateway
          vlan              = nr.vlan != "" && nr.vlan != null ? tonumber(nr.vlan) : null
          translated_subnet = nr.translated_subnet
          dhcp_settings     = nr.dhcp_settings
          native_range      = try(nr.native_range, false)  # Pass through the native_range flag with safe access
        }, 
        can(nr.id) ? {
          id        = nr.id
          import_id = nr.id
        } : {}) if try(nr.native_range, false) == false  # Exclude native ranges - they are managed at LAN interface level
      ]
    })
    # Include interfaces that exist in the configuration (they may have only native ranges)
    if true  # Always include since interfaces are only created if they have valid data
  ]
  
  # Set native_network_range and local_ip directly from the native_range object in the JSON
  native_network_range = each.value.native_range.subnet
  local_ip = each.value.native_range.local_ip
  
  # Additional native_range fields from JSON
  native_range_gateway = each.value.native_range.gateway != "" ? each.value.native_range.gateway : null
  native_range_vlan = each.value.native_range.vlan != "" && each.value.native_range.vlan != null ? each.value.native_range.vlan : null
  native_range_mdns_reflector = each.value.native_range.mdns_reflector
  native_range_translated_subnet = each.value.native_range.translated_subnet != "" ? each.value.native_range.translated_subnet : null
  
  # DHCP settings from JSON (only set when there are meaningful values)
  native_range_dhcp_settings = {
    dhcp_type = each.value.native_range.dhcp_settings.dhcp_type != "" ? each.value.native_range.dhcp_settings.dhcp_type : "DHCP_DISABLED"
    ip_range = each.value.native_range.dhcp_settings.ip_range != "" ? each.value.native_range.dhcp_settings.ip_range : null
    relay_group_id = each.value.native_range.dhcp_settings.relay_group_id != "" ? each.value.native_range.dhcp_settings.relay_group_id : null
    dhcp_microsegmentation = each.value.native_range.dhcp_settings.dhcp_microsegmentation
  }
  
  # Native range interface configuration
  interface_dest_type = each.value.native_range.interface_dest_type
  lag_min_links = each.value.native_range.lag_min_links
  interface_name = each.value.native_range.interface_name
  
  # Network ranges for the default/native LAN interface
  # Extract from default_lan interfaces that have network ranges
  default_interface_network_ranges = flatten([
    for lan in try(each.value.lan_interfaces, []) : [
      for nr in lan.network_ranges : {
        id                = nr.id
        name              = nr.name
        range_type        = nr.range_type
        subnet            = nr.subnet
        local_ip          = nr.local_ip
        gateway           = nr.gateway
        vlan              = nr.vlan
        translated_subnet = nr.translated_subnet
        internet_only     = false
        mdns_reflector    = nr.mdns_reflector
        dhcp_settings     = nr.dhcp_settings
        # Include interface_index from the CSV row for default interfaces
        interface_index   = try(nr.lan_interface_index, try(each.value.native_range.index, ""))
      } if try(nr.native_range, false) == false # Exclude native ranges
    ] if try(lan.default_lan, false) == true # Only from default LAN interfaces
  ])
}
