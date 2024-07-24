#!/bin/bash

# Step 1: Create OpenSearch cluster
echo "Creating OpenSearch cluster..."
doctl databases create opensearch-doks --engine opensearch --region lon1 --size db-s-1vcpu-2gb --num-nodes 1

# Wait for the OpenSearch cluster to be ready
echo "Waiting for OpenSearch cluster to be ready..."
sleep 600  # Adjust sleep time based on how long it typically takes for your cluster to be created

# Retrieve OpenSearch credentials
echo "Retrieving OpenSearch credentials..."
OPENSEARCH_CONNECTION=$(doctl databases connection opensearch-doks)

# Extract required info from the connection string
OPENSEARCH_HOST=$(echo $OPENSEARCH_CONNECTION | grep -oP 'host=\K[^ ]+')
OPENSEARCH_PORT=$(echo $OPENSEARCH_CONNECTION | grep -oP 'port=\K[^ ]+')

# Step 2: Generate some random logs using log-generator
echo "Adding kube-logging Helm repo..."
helm repo add kube-logging https://kube-logging.github.io/helm-charts
helm repo update

echo "Installing log-generator..."
helm install --generate-name --wait kube-logging/log-generator

# Verify log generation
echo "Verifying log generation..."
kubectl logs -l app.kubernetes.io/name=log-generator

# Step 3: Install axosyslog-collector
echo "Adding AxoSysLog Helm repo..."
helm repo add axosyslog https://axoflow.github.io/axosyslog-charts
helm repo update

echo "Installing axosyslog-collector..."
cat <<EOF > axoflow-demo.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: axoflow-demo-configmap
data:
  output.conf: |
    [output]
    host = ${OPENSEARCH_HOST}
    port = ${OPENSEARCH_PORT}
EOF

helm install axosyslog -f axoflow-demo.yaml axosyslog/axosyslog-collector --wait

# Update configmap to use the correct port if needed (assuming port is 25060 as per README)
echo "Updating configmap with correct port..."
kubectl get configmap axosyslog-axosyslog-collector -o yaml | sed 's/9200\/_bulk/25060\/_bulk/' | kubectl apply -f -

# Restart pods to apply new configuration
echo "Restarting AxoSysLog collector pods..."
kubectl delete pods -l app=axosyslog-axosyslog-collector

# Provide instructions for viewing logs in OpenSearch (manual step)
cat <<EOF

OpenSearch setup complete! To view logs:

1. Go to your OpenSearch dashboard.
2. Create an index pattern matching the logs.
3. Use the Discover tab to view and filter logs.

Refer to DigitalOcean documentation or support if you need assistance with these steps.

EOF
