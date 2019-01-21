# Kubernetes releases the GitOps way


**About GitOps**

We are using Weaveworks [Flux](https://github.com/weaveworks/flux) opensource project to manage the deployments. You can read more about GitOps at  https://www.weave.works/blog/gitops-operations-by-pull-request


### Install Helm and Tiller

If you don't have Helm CLI installed, please refer to this [link](https://github.com/helm/helm/blob/master/docs/install.md)

Once Helm is installed, Create a service account and a cluster role binding for Tiller: 

```bash
kubectl -n kube-system create sa tiller

kubectl create clusterrolebinding tiller-cluster-rule \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller 
```

Deploy Tiller in kube-system namespace:

```bash
helm init --skip-refresh --upgrade --service-account tiller
```
RBAC permissions need to be applied and this can be done by applying this yaml file- 

```
kubectl apply -f https://raw.githubusercontent.com/shwetams/containers-rest-cosmos-appservice-java/master/gitops/permissions.yaml

```

Here are the permissions you applied above: 

```bash
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin
rules:
  - apiGroups:
    - '*'
    resources:
    - '*'
    verbs:
    - '*'
  - nonResourceURLs:
    - '*'
    verbs:
    - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:discovery
rules:
  - nonResourceURLs:
    - /api
    - /api/*
    - /apis
    - /apis/*
    - /healthz
    - /openapi
    - /openapi/*
    - /swagger-2.0.0.pb-v1
    - /swagger.json
    - /swaggerapi
    - /swaggerapi/*
    - /version
    - /version/
    verbs:
      - get
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
  - kind: ServiceAccount
    name: tiller
    namespace: flux

```


### Install Weave Flux

Add the Weave Flux chart repo:

```bash
helm repo add weaveworks https://weaveworks.github.io/flux
```

```bash
helm install --name flux \
--set rbac.create=true \
--set helmOperator.create=true \
--set helmOperator.updateChartDeps=false \
--set git.url=git@github.com:munishmalhotra/gitops-chakraView \
--namespace flux \
weaveworks/flux
```

Chart release is described by a Kubernetes customer resource named as HelmRelease.
Flux then syncronizes resources from your git.

> Flux Helm Operator works with Kubernetes 1.9 or newer. 

Flux generates a SSH key and logs out the public key. 
Find the SSH public key with:

```bash
kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2
```
Or you can use the fluctl command utility to get the key by using following command:

```
fluxctl identity --k8s-fwd-ns=flux
```

To sync your cluster with Git you need to copy this public key and deploy it to Github with **write access**.

Open GitHub, go to your fork, go to _Setting > Deploy keys_ click on _Add deploy key_, check 
_Allow write access_, paste the Flux public key and click _Add key_.


### GitOps pipeline example

The config repo has the following structure:

```
├── charts
│   └── chakraView
│       ├── Chart.yaml
│       ├── README.md
│       ├── templates
│       └── values.yaml
├── namespaces
│   ├── dev.yaml
│   └── prod.yaml
└── releases
    ├── dev
    │   └── chakraView.yaml
    └── prod
        └── chakraView.yaml
```

Once the namespaces are up, you need to add the secrets to the namespace manually as of now, before you see the containers running inside your cluster.

```bash
kubectl create secret docker-registry <name> --docker-server=<ACR Name> --docker-username=<Registry name> --docker-password=<Registry password> --docker-email=<email Id>
```

You can setup or use [this](/api/azure-pipelines.yml) Azure DevOps build pipeline to generate a new container. 

Though, you need to add following variables:

<li> ACR_CONTAINER_TAG : chakraview:prod-$(Build.BuildNumber)

<li> ACR Credentials - Variable group must be addded with following keys
<ol>
<li> ACR_PASSWORD
<li>  ACR_SERVER
<li> ACR_USERNAME
</ol>

> Replace chakraview & prod variable in the ACR_Container_TAG with your project considerations. 

*charts* directory contains the Helm chart. This chart is used to create a release in the `prod` namespace with the image I've just published to Azure container registry(ACR).
Instead of editing the `values.yaml` from the chart source, I create a `HelmRelease` definition (located in /releases/dev/chakraView.yaml): 

```yaml
apiVersion: flux.weave.works/v1beta1
kind: HelmRelease
metadata:
  name: chakraview-prod
  namespace: prod
  annotations:
    flux.weave.works/automated: "true"
    flux.weave.works/tag.chart-image: glob:prod-*
spec:
  releaseName: chakraview-prod
  chart:
    git: git@github.com:munishmalhotra/gitops-chakraview
    path: charts/chakraview
    ref: master
  values:
    image: <ACRNAME>/<ImageName:TagName>
    replicaCount: 1
    hpa:
      enabled: true
      maxReplicas: 10
      cpu: 50
      memory: 128Mi
  
```

The options specified in the HelmRelease `spec.values` will override the ones in `values.yaml` from the chart source.


The `flux.weave.works` annotations instruct Flux to automate this release.
When a new tag with the prefix `prod` is pushed to ACR, Flux will update the image field in the yaml file, 
will commit and push the change to Git and finally will apply the change on the cluster. 

To understand more, please read [this](https://github.com/weaveworks/flux/blob/master/site/fluxctl.md)

When the `chakraview-prod` HelmRelease object changes inside the cluster, 
Kubernetes API will notify the Flux Helm Operator and the operator will perform a Helm release upgrade. 

```
$ helm history chakraview-dev

```

The Flux Helm Operator reacts to changes in the HelmRelease collection but will also detect changes in the charts source files.
If I make a change to the chakraview chart, the operator will pick that up and run an upgrade. 


```
$ helm history chakraview-dev
```

More details can be found on Weaveworks flux [repository](https://github.com/weaveworks/flux/blob/master/site/fluxctl.md).

GitOps Implementation reference [repository](https://github.com/stefanprodan/gitops-helm)

