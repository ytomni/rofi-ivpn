#!/usr/bin/env bash

# get VPN status
get_vpn_status() {
    local status_output
    status_output=$(ivpn status)
    
    if echo "$status_output" | grep -q "^VPN[[:space:]]*:[[:space:]]*CONNECTED"; then
        local country
        country=$(echo "$status_output" | grep -A1 "^VPN[[:space:]]*:[[:space:]]*CONNECTED" | tail -n1 | sed -E 's/.*, ([^,]+)$/\1/')
        echo "CONNECTED $country"
    else
        echo "DISCONNECTED"
    fi
}

# get server list
get_server_list() {
    ivpn servers | awk -F'|' '
        NR>1 {
            gsub(/^[ \t]+|[ \t]+$/, "", $1)  # Trim whitespace
            gsub(/^[ \t]+|[ \t]+$/, "", $2)  # Trim whitespace
            gsub(/^[ \t]+|[ \t]+$/, "", $3)  # Trim whitespace
            gsub(/^[ \t]+|[ \t]+$/, "", $4)  # Trim whitespace
            printf "%s | %s | %s\n", $1, $3, $4
        }
    '
}

# server selection
handle_server_selection() {
    local selected
    selected=$(get_server_list | rofi -dmenu -p "Servers" -i)
    
    if [ -n "$selected" ]; then
        local protocol
        local location
        protocol=$(echo "$selected" | awk -F'|' '{print $1}' | xargs)
        location=$(echo "$selected" | awk -F'|' '{print $2}' | xargs)
        
        local hostname
        hostname=$(ivpn servers | awk -F'|' -v proto="$protocol" -v loc="$location" '
            NR>1 {
                gsub(/^[ \t]+|[ \t]+$/, "", $1)
                gsub(/^[ \t]+|[ \t]+$/, "", $2)
                gsub(/^[ \t]+|[ \t]+$/, "", $3)
                if ($1 == proto && $3 == loc) {
                    print $2
                }
            }
        ' | xargs)
        
        if [ -n "$hostname" ]; then
            ivpn connect -l "$hostname"
        fi
    fi
}
handle_firewall_menu() {
    local firewall_status
    firewall_status=$(ivpn firewall -status)
    
    local options=(
        "Enable Firewall"
        "Disable Firewall"
        "Allow LAN"
        "Block LAN"
        "Allow IVPN Servers"
        "Block IVPN Servers"
    )
    
    local selected
    selected=$(printf '%s\n' "${options[@]}" | rofi -dmenu -p "Firewall" -i)
    
    case "$selected" in
        "Enable Firewall")
            ivpn firewall -on
            ;;
        "Disable Firewall")
            ivpn firewall -off
            ;;
        "Allow LAN")
            ivpn firewall -lan_allow
            ;;
        "Block LAN")
            ivpn firewall -lan_block
            ;;
        "Allow IVPN Servers")
            ivpn firewall -ivpn_access_allow
            ;;
        "Block IVPN Servers")
            ivpn firewall -ivpn_access_block
            ;;
    esac
}

main_menu() {
    local status
    status=$(get_vpn_status)
    
    local options=(
        "Quick Connect"
        "Servers"
        "Firewall"
        "Disconnect"
    )
    
    local selected
    selected=$(printf '%s\n' "${options[@]}" | rofi -dmenu -p "$status" -i)
    
    case "$selected" in
        "Quick Connect")
            ivpn connect -f
            ;;
        "Servers")
            handle_server_selection
            ;;
        "Firewall")
            handle_firewall_menu
            ;;
        "Disconnect")
            ivpn disconnect
            ;;
    esac
}

main_menu
