# Collect and Forward DigitalOcean Kubernetes (DOKS) Logs to DigitalOcean Managed OpenSearch.

In this guide we will use [AxoSysLog](https://axoflow.com/docs/axosyslog-core/intro/) to forward logs from a Kubernetes cluster to OpenSearch. AxoSyslog is a scalable security data processor.

## Create OpenSearch cluster

`doctl databases create opensearch-doks --engine opensearch --region lon1 --size db-s-1vcpu-2gb --num-nodes 1`

### Retrieve OpenSearch Credentials

`doctl databases connection <id>`

## Generate some random logs

If you don’t already have an application that generates logs deployed to the Kubernetes cluster, install `kube-logging/log-generator` to generate sample logs.

```text
helm repo add kube-logging https://kube-logging.github.io/helm-charts
helm repo update
```

```text
helm install --generate-name --wait kube-logging/log-generator
```

Check it's output, you'll see logs of random logs being generated:

`kubectl logs -l app.kubernetes.io/name=log-generator`

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
