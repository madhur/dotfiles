#!/bin/bash

# Read the current DNS from resolv.conf
current_dns=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}')

# Print the current DNS
echo "Current DNS: $current_dns"

# Prompt the user for the new DNS value
if [ "$current_dns" = "192.168.1.1" ]; then
    remote_ip="192.168.1.36"
    remote_port="53"
    
    nc -z "$remote_ip" "$remote_port"
    
    if [ $? -eq 0 ]; then
      echo "DNS server is running on $remote_ip:$remote_port"
      # Update the DNS in resolv.conf
      sudo sed -i "s/^nameserver.*/nameserver $remote_ip/" /etc/resolv.conf
      
      # Print the updated DNS
      notify-send "Updated DNS: $remote_ip"
      
      
    else
      echo "DNS server is not running on $remote_ip:$remote_port"
    fi

fi


