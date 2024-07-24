#!/bin/bash

# Extract Database ID for opensearch-doks
DB_ID=$(doctl databases list --format Name,ID --no-header | grep opensearch-doks | awk '{print $2}')

# Get Hostname, Username, and Password
OPENSEARCHHOSTNAME=$(doctl databases connection $DB_ID --no-header --format Host)
OPENSEARCHUSERNAME=$(doctl databases connection $DB_ID --no-header --format User)
OPENSEARCHPASSWORD=$(doctl databases connection $DB_ID --no-header --format Password)

# Update axoflow-demo.yaml with extracted values using yq
yq eval ".config.destinations.opensearch[0].address = \"$OPENSEARCHHOSTNAME\"" -i axoflow-demo.yaml
yq eval ".config.destinations.opensearch[0].user = \"$OPENSEARCHUSERNAME\"" -i axoflow-demo.yaml
yq eval ".config.destinations.opensearch[0].password = \"$OPENSEARCHPASSWORD\"" -i axoflow-demo.yaml

echo "axoflow-demo.yaml has been updated."