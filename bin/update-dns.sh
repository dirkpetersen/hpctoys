
#!/bin/bash

# Get hostname
HOSTNAME=$(hostname)

# Get IP
IP=$(hostname -I | awk '{print $1}')

# Send information to DNS server
echo "sending ${HOSTNAME} = ${IP}"
curl -X POST -d "hostname=$HOSTNAME&ip=$IP" http://localhost:5000/update_record


