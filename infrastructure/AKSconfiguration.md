# Azure kubernetes cluster integration with Azure key vault
We have implemented integration with Azure Key Vault service using the [FlexVolume](https://github.com/kubernetes/community/blob/master/contributors/devel/flexvolume.md) approach. A flexvolume implementation is available at Azure github repo that provides custom implementation of flexvolume for calling the Azure Keyvault services. You can find the concept defined [here](https://github.com/Azure/kubernetes-keyvault-flexvol/blob/master/docs/concept.md) and a few more links that can be referred to.
* https://github.com/Azure/aad-pod-identity
* https://github.com/Azure/kubernetes-keyvault-flexvol 


## Prerequisites

Setup k8s cluster on Azure using ARM template given in infrastructure folder. 

## Steps 

1. Apply the following yaml to enable RBAC in the cluster cluster
   ``` Bash
   kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
   ```

2. Create a new User Azure Identity in  MC_resourcegroupname 
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
7. Now we will deploy the Identity created in setp 2 to the Kubernest cluster. First create a new yaml file and paste below content, replacing the values in <> with your own values  and run with kubectl apply command
```
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: sample-aad #unique name
spec:
  type: 0
  ResourceID: /subscriptions/<Subscription ID from step 5>/resourcegroups/<AKS resource group name starting with MC_ >/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<Identity name created in step 2>
  ClientID: <Value of client ID from step 3>

```
8. Create a AzureIdentityBinding. Create a new yaml file and paste below content and run with kubectl apply command
```
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
 name: sample-aad-azure-identity-binding
spec:
 AzureIdentity: sample-aad #unique name created in step 7
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

1.  Check for Identity. It should return azureidentity name that was created in step 7
   ``` 
   kubectl describe azureidentity
   ```
2. Check for azureidentitybinding. It should return Azure Identity binding name that was created in step 8
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

Once you have confirmed these validation steps, please continue with the BUild pipelines 