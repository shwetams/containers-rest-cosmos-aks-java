# Azure Active Directory

> Note: This document roughly follows [these tutorials](https://github.com/Azure/aad-pod-identity and https://github.com/Azure/kubernetes-keyvault-flexvol ).

To enable Azure key vault integration, we have used Flex-volume[https://github.com/kubernetes/community/blob/master/contributors/devel/flexvolume.md].

This document will describe how to configure and leverage Azure key vault with Azure kubernetes Services.

## Prerequisites

Setup k8s cluster on Azure using ARM template given in infrastructure folder.

## Steps

1. Do basic setup for RBAC enabled cluster
   ``` Bash
   kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
   ```

2. Now create User Azure Identity in  MC_ resoource group
   ``` Bash
   az identity create -g <AKS resource group name starting with MC_ > -n <Identity name>
   ```
3. Get client ID of identity created in step 2
    ``` Bash
    az identity show -n <Identity name> -g <AKS resource group name starting with MC_ > | jq -r .clientId
    ```

4. Get Resource ID of identity created in step 2
   ``` Bash
   az identity show -n <Identity name>  -g  <AKS resource group name starting with MC_ > | jq -r .id
   ```
5. Get subscription ID of current account
   ``` Bash
   az account show | jq -r .id
   ```
6. Get Prinicpal ID of current account
   ``` Bash
   az identity show -n  <Identity name> -g <AKS resource group name starting with MC_ > | jq -r .principalId
   ```
7. Now we will deploy Identity created in setp 2 to Kubernetes. first create a new yaml file and paste below content  and run with kubectl apply command
```
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: sample-aad #unique name
spec:
  type: 0
  ResourceID: /subscriptions/<Subscription ID got from step 5>/resourcegroups/<AKS resource group name starting with MC_ >/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<Identity name created in step 2>
  ClientID: <Value of client ID got from step 3>

```
8. Create a AzureIdentityBinding. Create a new yaml file and paste below content  and run with kubectl apply command
```
   apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
 name: sample-aad-azure-identity-binding
spec:
 AzureIdentity: sample-aad #unique name created in setp 6
 Selector: sampleselectername # unique selector name, will be used for pod deployment
```
9. Now install the KeyVault Flexvolume in your cluster
  ``` 
kubectl create -f https://raw.githubusercontent.com/Azure/kubernetes-keyvault-flexvol/master/deployment/kv-flexvol-installer.yaml 
   ```
10.  Assign permissions to new identity to key vault
    
    az role assignment create --role Reader --assignee <Value of Prinicpal ID got from step 6> --scope /subscriptions/<Subscription ID got from step 5>/resourcegroups/<resource group of keyvault>/providers/Microsoft.KeyVault/vaults/<Key vault name>
    
11. Set key vault policy 
```   
az keyvault set-policy -n <Key vault name> --secret-permissions get --spn  <Value of client ID got from step 3>
```

## Validation

1.  Check for Indentity. It should return azureidentity name created in step 7
   ``` 
   kubectl describe azureidentity
   ```
2. Check for azureidentitybinding. It should return Azure Identity binding name created in step 8
   ``` 
   kubectl describe azureidentitybinding
   ```
3. Check for Flex volumes. You should be able to see 3 flex volume pods under namespace kv
   ``` Bash
   kubectl get pods -n kv
   ```
4. Check for MCI and NMI pods created in step 1. You should be able to see 1 mci pod and 3 nmi pods under namespace default
   ``` Bash
   kubectl get pods -n default
   ```
