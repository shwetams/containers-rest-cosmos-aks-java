
# Project Jackson Infrastructure

This repository includes the ARM templates for Project Jackson.

## Global ARM Template

__Regional resources depend on Global ARM resources. Complete this deployment first, so those variables can be used below.__

To deploy all the global resources, see the [Global Readme](./global-resources/README.md) which includes details on populating a [CosmosDB](https://azure.microsoft.com/en-us/services/cosmos-db/) instance with test data. 

## Regional ARM Template

To deploy all the resources, the script deploy.sh can be used.
The below values are required as inputs to the script:

1. Azure Subscription ID
2. Azure Resource Group (Add existing if one exists; else create a new one)
3. Azure Deployment Location (i.e., EastUS, WestUS)
4. App-name: Application Name
5. ServicePrincipal ClientId  : see details in [Global Readme](./global-resources/README.md). section named as "create a new service principal and object id which will be used for AKS and key vault setup"
6. ServicePrincipal ClientSecret (password):  see details in [Global Readme](./global-resources/README.md). section named as "create a new service principal and object id which will be used for AKS and key vault setup"
7. objectId : object ID of your live or microsoft account :  see details in [Global Readme](./global-resources/README.md). section named as "create a new service principal and object id which will be used for AKS and key vault setup"
8. DB-CONNSTR: get from  `vars.env` file
9. DB-NAME: get from  `vars.env` file
10. EXCLUDE-FILTER: default PersonRepository


Another way to deploy is to run one-click deploy for all resources using Deploy to Azure:

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

Once the ACR is deployed, follow steps given in [AKS configuration](./AKSconfiguration.md) to configure Key vault with AKS.

Once the AKS configuration with key vault  is done, follow these manual steps to set up CD pipeline:

1. Create a new variable group in Azure Pipeline Library
2. Create variable ACR_SERVER and set value to the server name, which will be the output of your deployment (<application name>container.azurecr.io)
3. Get values of username and password from container using Azure Portal
4. Create variables ACR_USERNAME and ACR_PASSWORD and set them to the values you got from the Azure Portal.

Your deployment resources can now be used as part of your CD pipeline.

## Environments

- Different environments like Dev, QA, Staging and Production environments are created under the resource group for all the resources to be deployed using ARM Template.
- Policies can be created between each of the environments to promote builds from one environment to another based on the requirements of the customer.
- These policies can differ for each customer and product.
- Once the tests under Dev environment passes, they can be approved to run on the QA environment based on policies set for approvals on each. These policies can be set under Azure DevOps Release Pipeline.

## Redis Cache

- To be updated

## Auto Scaling

- To be updated


