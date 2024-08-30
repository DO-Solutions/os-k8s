# Collect and Forward DigitalOcean Kubernetes (DOKS) Logs to DigitalOcean Managed OpenSearch.

## Introduction

This project demonstrates how to collect and forward logs from a DigitalOcean Kubernetes (DOKS) cluster to a DigitalOcean Managed OpenSearch instance using AxoSyslog, a scalable security data processor. By following this guide, you'll learn how to set up a robust logging system that captures and analyzes logs from your Kubernetes applications, making it easier to monitor, troubleshoot, and secure your infrastructure.

In this guide we will use [AxoSyslog](https://axoflow.com/docs/AxoSyslog-core/intro/) to forward logs from a Kubernetes cluster to OpenSearch.

## Prerequisites

Before getting started, ensure that you have the following prerequisites in place:

1. **[DigitalOcean Account](https://www.digitalocean.com/):** You'll need access to a DigitalOcean account to create and manage your Kubernetes and OpenSearch resources.
2. **[doctl CLI](https://docs.digitalocean.com/reference/doctl/how-to/install/):** The DigitalOcean Command Line Interface (CLI) tool, `doctl`, should be installed and configured on your local machine.
3. **[Kubernetes Cluster](https://docs.digitalocean.com/products/kubernetes/):** A running DigitalOcean Kubernetes (DOKS) cluster.
4. **[Helm](https://helm.sh/docs/intro/install/):** The Kubernetes package manager, Helm, should be installed to manage Kubernetes applications.
5. **[Basic Knowledge](https://kubernetes.io/docs/concepts/):** Familiarity with Kubernetes, Helm, and DigitalOcean's managed services.

## Use Case

This project is ideal for scenarios where you need a centralized logging solution to monitor and analyze logs from various applications running in a Kubernetes cluster. Whether you are managing a small set of applications or a large-scale infrastructure, collecting and forwarding logs to a dedicated OpenSearch cluster helps in:

- **Security Monitoring:** Detect and respond to security incidents by analyzing logs in real time.
- **Troubleshooting:** Quickly identify and resolve issues within your Kubernetes applications by accessing detailed logs.
- **Compliance:** Maintain a log of events for compliance with industry regulations.

By integrating AxoSyslog with DigitalOcean Managed OpenSearch, you can efficiently process and store large volumes of logs, making it easier to extract valuable insights and maintain the health and security of your systems.

## Step 1 - Create OpenSearch cluster

In this step, you’ll set up the core component of your logging system, the OpenSearch cluster. OpenSearch will serve as the destination for all the logs you collect from your Kubernetes cluster. By running the following command, you’ll create a new OpenSearch instance in your chosen region on DigitalOcean.

```sh
doctl databases create opensearch-doks --engine opensearch --region lon1 --size db-s-1vcpu-2gb --num-nodes 1
```

Replace `lon1` with your desired region. For a list of available size slugs, visit our [API reference documentation.](https://docs.digitalocean.com/reference/api/api-reference/#tag/Databases)

## Step 2 - Generate some random logs

Before you can forward logs to OpenSearch, you need some logs to work with. If you don’t have an application already generating logs within your Kubernetes cluster, this step will show you how to deploy a log generator. This log generator will produce a steady stream of sample logs that can be used to test and demonstrate your logging pipeline.

First, add the log generator Helm chart repository and install the log generator:

```sh
helm repo add kube-logging https://kube-logging.github.io/helm-charts
helm repo update
```

Then, install the log generator using Helm:

```sh
helm install --generate-name --wait kube-logging/log-generator
```

You can verify that the log generator is working by viewing the logs it produces:

```sh
kubectl logs -l app.kubernetes.io/name=log-generator
```

## Step 3 - Prepare AxoSyslog Collector for Installation

In this step, you’ll configure the AxoSyslog Collector, which is responsible for gathering logs from your Kubernetes cluster and forwarding them to OpenSearch. This involves providing the correct connection details for your OpenSearch cluster (hostname, user, and password).

We'll use helm to install AxoSyslog Collector and pass custom values.

To configure the AxoSyslog collector with the correct address, user, and password for your OpenSearch database, follow these steps:

### Automated Script

To simplify the configuration, you can use an automated script that fetches the necessary OpenSearch connection details and updates your AxoSyslog configuration file.

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

```sh
chmod +x update_axoflow_demo.sh && ./update_axoflow_demo.sh
```

This script will fetch the necessary information from your DigitalOcean account using `doctl` and update your `axoflow-demo.yaml` file accordingly.

### Manual Steps to Update `axoflow-demo.yaml`

If you prefer to manually configure your AxoSyslog Collector, follow these steps:

Run the following command to extract database ID for `opensearch-doks`:

```sh
doctl databases list --format Name,ID --no-header | grep opensearch-doks | awk '{print $2}'
```

To retrieve hostname, username, and password, execute the following commands respectively:

```sh
doctl databases connection <id> --no-header --format Host
doctl databases connection <id> --no-header --format User
doctl databases connection <id> --no-header --format Password
```

Now, you need to manually update the `axoflow-demo.yaml` file:

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

## Step 4 - Install AxoSyslog-collector

Now that the configuration is complete, the next step is to deploy the AxoSyslog Collector to your Kubernetes cluster. This will enable the collection and forwarding of logs to OpenSearch.

Add the AxoSyslog Helm repository and install the AxoSyslog Collector using the customized configuration file:

```sh
helm repo add AxoSyslog https://axoflow.github.io/AxoSyslog-charts
helm repo update
```

```sh
helm install AxoSyslog -f axoflow-demo.yaml AxoSyslog/AxoSyslog-collector --wait
```

To ensure that logs are being sent to the correct OpenSearch port, update the AxoSyslog Collector’s configuration by updating your `configmap`:

```sh
kubectl get configmap AxoSyslog-AxoSyslog-collector -o yaml | sed 's/9200\/_bulk/25060\/_bulk/' | kubectl apply -f -
```

Finally, delete the existing pods to apply the updated configuration:

```sh
kubectl delete pods -l app=AxoSyslog-AxoSyslog-collector
```

## Conclusion

Setting up a logging pipeline from DigitalOcean Kubernetes to OpenSearch using AxoSyslog not only centralizes your logs but also enhances your ability to monitor, analyze, and secure your applications. With the steps provided in this guide, you can quickly deploy this solution, gaining deeper visibility into your Kubernetes environment and ensuring that your infrastructure remains resilient and compliant.
