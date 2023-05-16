#!/bin/bash

# Get hostname
HOSTNAME=$(hostname)

# Get IP
IP=$(hostname -I | awk '{print $1}')

# Get DNS servers from /etc/resolv.conf
DNS_SERVERS=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf)

# Send information to DNS server
echo "sending ${HOSTNAME} = ${IP} to localhost"
curl -X POST -d "hostname=$HOSTNAME&ip=$IP" http://localhost:5000/update_record

# Send information to each DNS server
for DNS_SERVER in $DNS_SERVERS; do
  echo "sending ${HOSTNAME} = ${IP} to ${DNS_SERVER}"
  #curl -X POST -d "hostname=$HOSTNAME&ip=$IP" http://$DNS_SERVER:5000/update_record
done




