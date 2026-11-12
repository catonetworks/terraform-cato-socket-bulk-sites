                  internet_only = contains(["true", "false"], try(lower(trimspace(tostring(nr.internet_only))), "")) ? lower(trimspace(tostring(nr.internet_only))) == "true" : null
                  local_ip = try(nr.local_ip, null)
                  native_range = try(lower(trimspace(nr.is_native_range)), "false") == "true"
                  # Only populate dhcp_settings for non-Routed/Direct ranges
                  # Routed/Direct ranges cannot have DHCP settings submitted to API
                  dhcp_settings = !contains(["Routed", "Direct"], try(nr.range_type, "Direct")) ? {
                    dhcp_type              = try(trimspace(nr.dhcp_type), "DHCP_DISABLED")
                    ip_range               = try(trimspace(nr.dhcp_ip_range), null) != "" ? try(trimspace(nr.dhcp_ip_range), null) : null
                    relay_group_id         = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_id), "") != "" ? try(trimspace(nr.dhcp_relay_group_id), null) : null
                    relay_group_name       = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_name), "") != "" ? try(trimspace(nr.dhcp_relay_group_name), null) : null
                    dhcp_microsegmentation = try(lower(trimspace(nr.dhcp_microsegmentation)), "false") == "true"
                  } : null
                  } if(
                  try(nr.subnet, "") != "" &&                                  # Only include rows with actual network range data (subnet is required)
                  try(lower(trimspace(nr.is_native_range)), "false") != "true" # Exclude native ranges
                )
              ],
              # Additional non-native ranges for this interface (those without lan_interface_id but matching lan_interface_index)
              [
                for nr in local.site_network_ranges_data[site_name] : {
                  id                = try(nr.network_range_id, "")
                  name              = try(nr.network_range_name, "Network Range")
                  subnet            = try(nr.subnet, "")
                  vlan              = try(tonumber(nr.vlan), null) != 0 ? try(tonumber(nr.vlan), null) : null
                  mdns_reflector    = try(lower(nr.mdns_reflector), "false") == "true"
                  gateway           = try(nr.gateway, null)
                  range_type        = try(nr.range_type, "Direct")
                  translated_subnet = try(trimspace(nr.translated_subnet), "") != "" ? try(trimspace(nr.translated_subnet), null) : null
                  internet_only = contains(["true", "false"], try(lower(trimspace(tostring(nr.internet_only))), "")) ? lower(trimspace(tostring(nr.internet_only))) == "true" : null
                  local_ip = try(nr.local_ip, null)
                  native_range = try(lower(trimspace(nr.is_native_range)), "false") == "true"
                  # Only populate dhcp_settings for non-Routed/Direct ranges
                  # Routed/Direct ranges cannot have DHCP settings submitted to API
                  dhcp_settings = !contains(["Routed", "Direct"], try(nr.range_type, "Direct")) ? {
                    dhcp_type              = try(trimspace(nr.dhcp_type), "DHCP_DISABLED")
                    ip_range               = try(trimspace(nr.dhcp_ip_range), null) != "" ? try(trimspace(nr.dhcp_ip_range), null) : null
                    relay_group_id         = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_id), "") != "" ? try(trimspace(nr.dhcp_relay_group_id), null) : null
                    relay_group_name       = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_name), "") != "" ? try(trimspace(nr.dhcp_relay_group_name), null) : null
                    dhcp_microsegmentation = try(lower(trimspace(nr.dhcp_microsegmentation)), "false") == "true"
                  } : null
                  } if(
                  try(trimspace(nr.lan_interface_id), "") == "" &&                                                                                         # No explicit lan_interface_id
                  try(nr.subnet, "") != "" &&                                                                                                              # Valid network range data (subnet is required)
                  try(nr.lan_interface_index, "") == try(lan_ranges[0].lan_interface_index, "") &&                                                         # Matching interface index
                  try(nr.lan_interface_index, try(site_rows[0].native_range_interface_index, "")) != try(site_rows[0].native_range_interface_index, "") && # Not the default/native interface
                  try(lower(trimspace(nr.is_native_range)), "false") != "true"                                                                             # Exclude native ranges
                )
              ]
            )
            } if lan_id != "unknown" && lan_id != "" && (
            length([
              for nr in lan_ranges : nr if try(nr.subnet, "") != ""            # Only require subnet for valid network range
            ]) > 0 ||                                                          # Create LAN interface if it has at least one valid network range (including native ranges)
            try(lan_ranges[0].lan_interface_dest_type, "") == "LAN_LAG_MEMBER" # OR if it's a LAG member (no subnet required)
          )
        ],
        # Virtual LAN interfaces for network ranges with explicit interface index but no interface ID
        # These are ranges that specify a lan_interface_index but have empty lan_interface_id
        # Exclude interface indices that already have explicit LAN interfaces to avoid duplicates
        [
          for interface_index, ranges in {
            for nr in local.site_network_ranges_data[site_name] :
            try(nr.lan_interface_index, "") => nr... if(
              try(trimspace(nr.lan_interface_id), "") == "" && # No explicit interface ID
              try(nr.lan_interface_index, "") != "" &&         # But has interface index
              (
                try(nr.subnet, "") != "" ||                             # Valid network range (subnet is required) OR
                try(nr.lan_interface_dest_type, "") == "LAN_LAG_MEMBER" # LAG member (no subnet required)
              ) &&
              try(nr.lan_interface_index, try(site_rows[0].native_range_interface_index, "")) != try(site_rows[0].native_range_interface_index, "") && # Not native interface
              try(lower(trimspace(nr.is_native_range)), "false") != "true" &&                                                                          # Exclude native ranges
              # Ensure this interface index doesn't already have an explicit LAN interface
              !contains([
                for nr_check in local.site_network_ranges_data[site_name] : try(nr_check.lan_interface_index, "")
                if try(trimspace(nr_check.lan_interface_id), "") != ""
              ], try(nr.lan_interface_index, ""))
            )
            } : {
            id = null # Virtual interface - no actual interface ID
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
                id                = try(nr.network_range_id, "")
                name              = try(nr.network_range_name, "Network Range")
                subnet            = try(nr.subnet, "")
                vlan              = try(tonumber(nr.vlan), null) != 0 ? try(tonumber(nr.vlan), null) : null
                mdns_reflector    = try(lower(nr.mdns_reflector), "false") == "true"
                gateway           = try(nr.gateway, null)
                range_type        = try(nr.range_type, "Direct")
                translated_subnet = try(trimspace(nr.translated_subnet), "") != "" ? try(trimspace(nr.translated_subnet), null) : null
                internet_only = contains(["true", "false"], try(lower(trimspace(tostring(nr.internet_only))), "")) ? lower(trimspace(tostring(nr.internet_only))) == "true" : null
                local_ip = try(nr.local_ip, null)
                native_range = try(lower(trimspace(nr.is_native_range)), "false") == "true"
                # Only populate dhcp_settings for non-Routed/Direct ranges
                # Routed/Direct ranges cannot have DHCP settings submitted to API
                dhcp_settings = !contains(["Routed", "Direct"], try(nr.range_type, "Direct")) ? {
                  dhcp_type              = try(trimspace(nr.dhcp_type), "DHCP_DISABLED")
                  ip_range               = try(trimspace(nr.dhcp_ip_range), null) != "" ? try(trimspace(nr.dhcp_ip_range), null) : null
                  relay_group_id         = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_id), "") != "" ? try(trimspace(nr.dhcp_relay_group_id), null) : null
                  relay_group_name       = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_name), "") != "" ? try(trimspace(nr.dhcp_relay_group_name), null) : null
                  dhcp_microsegmentation = try(lower(trimspace(nr.dhcp_microsegmentation)), "false") == "true"
                } : null
                } if(
                try(nr.subnet, "") != "" &&                                  # Only include rows with actual network range data (subnet is required)
                try(lower(trimspace(nr.is_native_range)), "false") != "true" # Exclude native ranges
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
        # For CSV input, always create a default LAN interface even if network_ranges CSV is empty
        # This matches the JSON behavior where sites can have default LAN interfaces with empty network_ranges
        # Check if: 1) we have site data from CSV, OR 2) there are actual network ranges for default interface
        (local.using_csv && contains(keys(local.site_network_ranges_data), site_name)) || length([
          for nr in try(local.site_network_ranges_data[site_name], []) : nr
          if(
            try(trimspace(nr.lan_interface_id), "") == "" &&
            try(nr.subnet, "") != "" && # Only require subnet for default interface ranges
            (try(trimspace(nr.is_native_range), "") == "" || try(lower(trimspace(nr.is_native_range)), "false") != "true") &&
            try(nr.lan_interface_index, try(site_rows[0].native_range_interface_index, "")) == try(site_rows[0].native_range_interface_index, "")
          )
          ]) > 0 ? [{
          id          = null # No ID for default interface - this signals it shouldn't be created as a separate resource
          name        = try(site_rows[0].native_range_interface_name, "")
          index       = try(site_rows[0].native_range_interface_index, "1")
          dest_type   = "LAN"
          default_lan = true
          network_ranges = [
            for nr in local.site_network_ranges_data[site_name] : {
              id                = try(nr.network_range_id, "")
              name              = try(nr.network_range_name, "Network Range")
              subnet            = try(nr.subnet, "")
              vlan              = try(tonumber(nr.vlan), null) != 0 ? try(tonumber(nr.vlan), null) : null
              mdns_reflector    = try(lower(nr.mdns_reflector), "false") == "true"
              gateway           = try(nr.gateway, null)
              range_type        = try(nr.range_type, "Direct")
              translated_subnet = try(trimspace(nr.translated_subnet), "") != "" ? try(trimspace(nr.translated_subnet), null) : null
              internet_only = contains(["true", "false"], try(lower(trimspace(tostring(nr.internet_only))), "")) ? lower(trimspace(tostring(nr.internet_only))) == "true" : null
              local_ip = try(nr.local_ip, null)
              native_range = try(lower(trimspace(nr.is_native_range)), "false") == "true"
              # Only populate dhcp_settings for non-Routed/Direct ranges
              # Routed/Direct ranges cannot have DHCP settings submitted to API
              dhcp_settings = !contains(["Routed", "Direct"], try(nr.range_type, "Direct")) ? {
                dhcp_type              = try(trimspace(nr.dhcp_type), "DHCP_DISABLED")
                ip_range               = try(trimspace(nr.dhcp_ip_range), null) != "" ? try(trimspace(nr.dhcp_ip_range), null) : null
                relay_group_id         = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_id), "") != "" ? try(trimspace(nr.dhcp_relay_group_id), null) : null
                relay_group_name       = try(trimspace(nr.dhcp_type), "DHCP_DISABLED") == "DHCP_RELAY" && try(trimspace(nr.dhcp_relay_group_name), "") != "" ? try(trimspace(nr.dhcp_relay_group_name), null) : null
                dhcp_microsegmentation = try(lower(trimspace(nr.dhcp_microsegmentation)), "false") == "true"
              } : null
              } if(
              try(trimspace(nr.lan_interface_id), "") == "" &&
              try(nr.subnet, "") != "" && # Only require subnet for default interface ranges
              (try(nr.is_native_range, "") == "" || try(lower(nr.is_native_range), "false") != "true") &&
              try(nr.lan_interface_index, try(site_rows[0].native_range_interface_index, "")) == try(site_rows[0].native_range_interface_index, "") # Only native interface index for default interfaces
            )
          ]
        }] : []
      ) : []
    }
  ] : [], [])

  # Combine JSON and CSV data (only one will have data)
  sites_data = concat(local.json_sites_data, local.csv_sites_data)

  # Helper to index all LAN interfaces by their site name, interface index, and name
  lan_interfaces_by_id = {
    for item in flatten([
      for site in local.sites_data : [
        for lan in try(site.lan_interfaces, []) : {
          key = "${site.name}-${try(lan.index, "")}-${try(lan.name, "")}"
          lan = lan
        } if can(lan.index) && can(lan.name)
      ]
    ]) : item.key => item.lan
  }

  # Collect all network ranges from all sites and LAN interfaces
  all_network_ranges = flatten([
    for site in local.sites_data : [
      for lan in try(site.lan_interfaces, []) : [
        for nr in lan.network_ranges : merge(nr, {
          site_name           = site.name
          site_id             = site.name # Use site name as key for module reference
          lan_interface_index = try(can(tonumber(lan.index)) ? "INT_${lan.index}" : lan.index, "DEFAULT")
          lan_interface_name  = try(lan.name, "Default LAN")
        }) if try(nr.native_range, false) == false && nr.subnet != "" # Only require subnet for network ranges
      ] if length(lan.network_ranges) > 0
    ]
  ])
}

locals {
  # Split the "<site name>:<ssid name>" keyed wifi_ssid_passkeys map into a
  # per-site map keyed by ssid name only, for pass-through to the child module
  # (which accepts PSK passkeys keyed by ssid name).
  wifi_ssid_passkeys_by_site = {
    for site in local.sites_data : site.name => {
      for key, passkey in var.wifi_ssid_passkeys : substr(key, length(site.name) + 1, -1) => passkey
      if startswith(key, "${site.name}:")
    }
  }
}

module "socket-site" {
  # Index by site name for readability in state
  for_each = { for site in local.sites_data :
    site.name => site
  }
  # source  = "catonetworks/socket/cato"   # restore (with bumped version) before publishing
  source = "../terraform-cato-socket"

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
      role                 = wan.role # Use the actual role field
      precedence           = wan.precedence
    }
  ]

  # LAN interfaces - transformed from lan_interfaces with network_ranges
  # Include both regular interfaces (with lan.id) AND default interfaces (lan.id == null) that have network ranges
  # For default native range interfaces, omit dest_type so they won't be created as LAN interface resources
  lan_interfaces = [
    for lan in try(each.value.lan_interfaces, []) : merge({
      # For default_lan interfaces, use native_range info; otherwise use lan interface info
      id              = try(lan.default_lan, false) ? null : lan.id # Pass interface ID for keying
      name            = try(lan.default_lan, false) ? try(each.value.native_range.interface_name, null) : lan.name
      interface_index = try(lan.default_lan, false) ? (can(tonumber(try(each.value.native_range.index, ""))) ? "INT_${each.value.native_range.index}" : try(each.value.native_range.index, "")) : (can(tonumber(lan.index)) ? "INT_${lan.index}" : lan.index)
      # For default_lan interfaces (native range), omit dest_type so socket module won't create the LAN interface
      # For regular interfaces, include dest_type so socket module will create the LAN interface
      # For LAG members, pass the dest_type so socket module can create LAG member resources
      dest_type = try(lan.default_lan, false) ? null : lan.dest_type
      subnet = try(lan.default_lan, false) ? try(each.value.native_range.subnet, null) : (
        # For regular LAN interfaces, find the subnet from the native range
        # First check if using CSV data (lookup by site name, not site ID)
        local.using_csv && contains(keys(local.site_network_ranges_data), each.value.name) ? (
          # For virtual interfaces (lan.id == null), match by interface_index; for regular interfaces, match by interface_id
          lan.id == null ? (
            # Virtual interface - match by interface_index
            length([
              for nr in local.site_network_ranges_data[each.value.name] : nr
              if try(trimspace(nr.lan_interface_index), "") == lan.index && try(lower(trimspace(nr.is_native_range)), "false") == "true"
              ]) > 0 ? [
              for nr in local.site_network_ranges_data[each.value.name] : try(trimspace(nr.subnet), "")
              if try(trimspace(nr.lan_interface_index), "") == lan.index && try(lower(trimspace(nr.is_native_range)), "false") == "true"
              ][0] : (
              # Fallback to first non-native range if no native range found
              length(lan.network_ranges) > 0 ? lan.network_ranges[0].subnet : ""
            )
            ) : (
            # Regular interface - match by interface_id
            length([
              for nr in local.site_network_ranges_data[each.value.name] : nr
              if try(trimspace(nr.lan_interface_id), "") == lan.id && try(lower(trimspace(nr.is_native_range)), "false") == "true"
              ]) > 0 ? [
              for nr in local.site_network_ranges_data[each.value.name] : try(trimspace(nr.subnet), "")
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
      local_ip = try(lan.default_lan, false) ? try(each.value.native_range.local_ip, null) : (
        # For regular LAN interfaces, find the local_ip from the native range
        # First check if using CSV data (lookup by site name, not site ID)
        local.using_csv && contains(keys(local.site_network_ranges_data), each.value.name) ? (
          # For virtual interfaces (lan.id == null), match by interface_index; for regular interfaces, match by interface_id
          lan.id == null ? (
            # Virtual interface - match by interface_index
            length([
              for nr in local.site_network_ranges_data[each.value.name] : nr
              if try(trimspace(nr.lan_interface_index), "") == lan.index && try(lower(trimspace(nr.is_native_range)), "false") == "true"
              ]) > 0 ? [
              for nr in local.site_network_ranges_data[each.value.name] : try(trimspace(nr.local_ip), "") != "" ? try(trimspace(nr.local_ip), null) : null
              if try(trimspace(nr.lan_interface_index), "") == lan.index && try(lower(trimspace(nr.is_native_range)), "false") == "true"
              ][0] : (
              # Fallback to first non-native range if no native range found
              length(lan.network_ranges) > 0 ? lan.network_ranges[0].local_ip : null
            )
            ) : (
            # Regular interface - match by interface_id
            length([
              for nr in local.site_network_ranges_data[each.value.name] : nr
              if try(trimspace(nr.lan_interface_id), "") == lan.id && try(lower(trimspace(nr.is_native_range)), "false") == "true"
              ]) > 0 ? [
              for nr in local.site_network_ranges_data[each.value.name] : try(trimspace(nr.local_ip), "") != "" ? try(trimspace(nr.local_ip), null) : null
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
          name                   = nr.name
          range_type             = nr.range_type
          subnet                 = nr.subnet
          local_ip               = nr.local_ip
          gateway                = nr.gateway
          vlan                   = nr.vlan != "" && nr.vlan != null ? tonumber(nr.vlan) : null
          translated_subnet      = try(trimspace(nr.translated_subnet), "") != "" ? nr.translated_subnet : null
          internet_only          = try(nr.internet_only, null)
          # Extract flat dhcp fields from nested dhcp_settings object (CSV loading creates nested object)
          dhcp_type     = try(nr.dhcp_settings.dhcp_type, null)
          dhcp_ip_range = try(nr.dhcp_settings.ip_range, null)
          # Only include relay fields when dhcp_type is DHCP_RELAY
          dhcp_relay_group_id    = try(nr.dhcp_settings.dhcp_type, "") == "DHCP_RELAY" ? try(nr.dhcp_settings.relay_group_id, null) : null
          dhcp_relay_group_name  = try(nr.dhcp_settings.dhcp_type, "") == "DHCP_RELAY" ? try(nr.dhcp_settings.relay_group_name, null) : null
          dhcp_microsegmentation = try(nr.dhcp_settings.dhcp_microsegmentation, null)
          native_range           = try(nr.native_range, false) # Pass through the native_range flag with safe access
          },
          can(nr.id) ? {
            id        = nr.id
            import_id = nr.id
        } : {}) if try(nr.native_range, false) == false # Exclude native ranges - they are managed at LAN interface level
      ]
    })
    # Include interfaces that exist in the configuration (they may have only native ranges)
    if true # Always include since interfaces are only created if they have valid data
  ]

  # Set native_network_range and local_ip directly from the native_range object in the JSON
  native_network_range = try(each.value.native_range.subnet, null)
  local_ip             = try(each.value.native_range.local_ip, null)

  # Additional native_range fields from JSON
  native_range_vlan              = try(each.value.native_range.vlan, null) != "" && try(each.value.native_range.vlan, null) != null ? try(each.value.native_range.vlan, null) : null
  native_range_mdns_reflector    = try(each.value.native_range.mdns_reflector, false)
  native_range_translated_subnet = try(each.value.native_range.translated_subnet, null) != "" && try(each.value.native_range.translated_subnet, null) != null ? try(each.value.native_range.translated_subnet, null) : null

  # DHCP settings from JSON (only set when there are meaningful values)
  native_range_dhcp_settings = try(each.value.native_range.dhcp_settings, null) != null ? {
    dhcp_type = try(each.value.native_range.dhcp_settings.dhcp_type, null) != "" && try(each.value.native_range.dhcp_settings.dhcp_type, null) != null ? try(each.value.native_range.dhcp_settings.dhcp_type, null) : "DHCP_DISABLED"
    ip_range  = try(each.value.native_range.dhcp_settings.ip_range, null) != "" && try(each.value.native_range.dhcp_settings.ip_range, null) != null ? try(each.value.native_range.dhcp_settings.ip_range, null) : null
    # Only include relay fields when dhcp_type is DHCP_RELAY
    relay_group_id         = try(each.value.native_range.dhcp_settings.dhcp_type, "") == "DHCP_RELAY" && try(each.value.native_range.dhcp_settings.relay_group_id, null) != "" && try(each.value.native_range.dhcp_settings.relay_group_id, null) != null ? try(each.value.native_range.dhcp_settings.relay_group_id, null) : null
    relay_group_name       = try(each.value.native_range.dhcp_settings.dhcp_type, "") == "DHCP_RELAY" && try(each.value.native_range.dhcp_settings.relay_group_name, null) != "" && try(each.value.native_range.dhcp_settings.relay_group_name, null) != null ? try(each.value.native_range.dhcp_settings.relay_group_name, null) : null
    dhcp_microsegmentation = try(each.value.native_range.dhcp_settings.dhcp_microsegmentation, false)
  } : null

  # Native range interface configuration
  interface_dest_type = try(each.value.native_range.interface_dest_type, try(each.value.native_range.dest_type, null))
  lag_min_links       = try(each.value.native_range.lag_min_links, null) != null && try(trimspace(each.value.native_range.lag_min_links), "") != "" ? try(tonumber(each.value.native_range.lag_min_links), null) : null
  interface_name      = try(each.value.native_range.interface_name, null)
  interface_index     = try(each.value.native_range.index, null) != null && try(trimspace(each.value.native_range.index), "") != "" ? (can(tonumber(each.value.native_range.index)) ? "INT_${each.value.native_range.index}" : each.value.native_range.index) : null

  # Network ranges for the default/native LAN interface
  # Extract from default_lan interfaces that have network ranges
  default_interface_network_ranges = flatten([
    for lan in try(each.value.lan_interfaces, []) : [
      for nr in lan.network_ranges : {
        id                     = nr.id
        name                   = nr.name
        range_type             = nr.range_type
        subnet                 = nr.subnet
        local_ip               = nr.local_ip
        gateway                = nr.gateway
        vlan                   = nr.vlan != "" && nr.vlan != null ? tonumber(nr.vlan) : null
        translated_subnet      = try(trimspace(nr.translated_subnet), "") != "" ? nr.translated_subnet : null
        internet_only          = try(nr.internet_only, null)
        mdns_reflector         = nr.mdns_reflector
        # Transform dhcp_settings to only include relay fields when dhcp_type is DHCP_RELAY
        dhcp_settings = try(nr.dhcp_settings, null) != null ? {
          dhcp_type              = try(nr.dhcp_settings.dhcp_type, null)
          ip_range               = try(nr.dhcp_settings.ip_range, null)
          relay_group_id         = try(nr.dhcp_settings.dhcp_type, "") == "DHCP_RELAY" ? try(nr.dhcp_settings.relay_group_id, null) : null
          relay_group_name       = try(nr.dhcp_settings.dhcp_type, "") == "DHCP_RELAY" ? try(nr.dhcp_settings.relay_group_name, null) : null
          dhcp_microsegmentation = try(nr.dhcp_settings.dhcp_microsegmentation, false)
        } : null
        # Include interface_index from the CSV row for default interfaces
        interface_index = try(nr.lan_interface_index, try(each.value.native_range.index, ""))
      } if try(nr.native_range, false) == false # Exclude native ranges
    ] if try(lan.default_lan, false) == true    # Only from default LAN interfaces
  ])

  # License configuration
  license_id = try(each.value.license_id, null)
  license_bw = try(each.value.license_bw, null)

  # Wi-Fi SSIDs - passed through as-is; PSK passkeys are split per-site from
  # wifi_ssid_passkeys (keyed "<site name>:<ssid name>") into a map keyed by
  # ssid name only, which is what the child module expects.
  wifi_ssids         = try(each.value.wifi_ssids, [])
  wifi_ssid_passkeys = try(local.wifi_ssid_passkeys_by_site[each.value.name], {})
}

# Safety guard: fail `terraform plan` early if the merged sites data (JSON + CSV)
# resolves to zero sites, unless the caller explicitly opts in via allow_empty_sites.
# A truncated export, a renamed upstream key, or an accidentally wrong-tenant
# near-empty file would otherwise silently destroy every live site.
resource "terraform_data" "guard_empty_sites" {
  lifecycle {
    precondition {
      condition     = var.allow_empty_sites || length(local.sites_data) > 0
      error_message = "Sites data contains 0 sites. If intentional (greenfield/teardown), set allow_empty_sites = true. A truncated or wrong-tenant export would otherwise destroy every live site."
    }
  }
}
