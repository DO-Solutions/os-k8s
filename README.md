# Collect and Forward DigitalOcean Kubernetes (DOKS) Logs to DigitalOcean Managed OpenSearch.

In this guide we will use [AxoSysLog](https://axoflow.com/docs/axosyslog-core/intro/) to forward logs from a Kubernetes cluster to OpenSearch. AxoSyslog is a scalable security data processor.

## Create OpenSearch cluster

`doctl databases create opensearch-doks --engine opensearch --region lon1 --size db-s-1vcpu-2gb --num-nodes 1`

Replace `lon1` with your desired region. For a list of available size slugs, visit our [API reference documentation.](https://docs.digitalocean.com/reference/api/api-reference/#tag/Databases)

## Generate some random logs

If you don’t already have an application that generates logs deployed to the Kubernetes cluster, install `kube-logging/log-generator` to generate sample logs.

```text
helm repo add kube-logging https://kube-logging.github.io/helm-charts
helm repo update
```

```text
helm install --generate-name --wait kube-logging/log-generator
```

Check it's output, you'll see lots of random logs being generated:

`kubectl logs -l app.kubernetes.io/name=log-generator`

## Prepare AxoSysLog Collector for Installation

We'll use helm to install AxoSysLog Collector and pass custom values.

To configure the AxoSysLog collector with the correct address, user, and password for your OpenSearch database, follow these steps:

### Automated Script

To automate this process, you can use the following script:

Save the following script as `update_axoflow_demo.sh`:

```sh
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
```

Ensure you have execute permission on your script before running it:
`chmod +x update_axoflow_demo.sh && ./update_axoflow_demo.sh`

This script will fetch the necessary information from your DigitalOcean account using `doctl` and update your axoflow-demo.yaml file accordingly.

### Manual Steps to Update `axoflow-demo.yaml`

**Extract Database ID for `opensearch-doks`:**

`doctl databases list --format Name,ID --no-header | grep opensearch-doks | awk '{print $2}'`

**Retrieve Hostname, Username, and Password:**

Hostname: `doctl databases connection <id> --no-header --format Host`

Username: `doctl databases connection <id> --no-header --format User`

Password: `doctl databases connection <id> --no-header --format Password`

**Manually update `axoflow-demo.yaml`:**

   Open your `axoflow-demo.yaml` file in a text editor and replace the relevant fields with the extracted values:

   ```yaml
   config:
     sources:
       kubernetes:
         # Collect kubernetes logs
         enabled: true
     destinations:
       # Send logs to OpenSearch
       opensearch:
         - address: "x.k.db.ondigitalocean.com"
           index: "doks-demo"
           user: "doadmin"
           password: "AVNS_x"
           tls:
             # Do not validate the server's TLS certificate.
             peerVerify: false
           # Send the syslog fields + the metadata from .k8s.* in JSON format
           template: "$(format-json --scope rfc5424 --exclude DATE --key ISODATE @timestamp=${ISODATE} k8s=$(format-json .k8s.* --shift-levels 2 --exclude .k8s.log))"
   ```

## Install axosyslog-collector

```text
helm repo add axosyslog https://axoflow.github.io/axosyslog-charts
helm repo update
```

`helm install axosyslog -f axoflow-demo.yaml axosyslog/axosyslog-collector --wait`

Update our configmap to use the correct port

`kubectl get configmap axosyslog-axosyslog-collector -o yaml | sed 's/9200\/_bulk/25060\/_bulk/' | kubectl apply -f -`

Delete the pods so they are recreated and use the updated config

`kubectl delete pods -l app=axosyslog-axosyslog-collector`

## View logs in OpenSearch

add section here about creating an index pattern, viewing and filtering the logs.
