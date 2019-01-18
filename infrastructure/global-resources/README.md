# Global Resource Deployment

## Traffic Manger Endpoints

Project Jackson uses Traffic Manager to route a specific URL to the correct region. In order to create these endpoints, the [`endpoint_deploy.json`](./endpoint_deploy.json) needs to be run. To do this, run:

```
az group deployment create --template-file infrastructure/global-resoruces/endpoint_deploy.json --resource-group your-resource-group --parameters traffic_manager_endpoints=app1,app2 traffic_manager_endpoint_locations=eastus,westus
```

with `your-resource-group` as the name of the resource group you are creating the global resources in, app1 being the target for an endpoint that correlates to the azure region specified by the first parameter in the `traffic_manager_endpoint_locations` parameter. For example, `app1` is created in `eastus` and `app2` is created in `westus`.

## CosmosDB

Project Jackson uses a CosmosDB instance enabled with the MongoDB API and an Azure Container Registry to push and pull images.
These are global resources and should be deployed independently of application infrastructure.
Deploy your own using the button below, which uses the included ARM template.

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/?repository=https://github.com/Microsoft/containers-rest-cosmos-appservice-java/infrastructure/global-resources)

## Deploying Data

> Note: This is optional, but is a good way to injest some sample data without needing to manually create it.

In this section we'll explain how to populate the [CosmosDB](https://azure.microsoft.com/en-us/services/cosmos-db/) instance that was created above with sample data.

### Install Dependencies

* Install [the latest Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* Install MongoDB:
  * Windows: [Install MongoDB Community Edition on Windows](https://docs.mongodb.com/v3.2/tutorial/install-mongodb-on-windows/)
  * MacOS: From a command line, run `brew install mongodb`
  * Linux: From command line, run `apt-get install mongodb`
* Open a [shell](https://en.wikipedia.org/wiki/Shell_%28computing%29) in the project root directory (the next steps depend on this)

### Set up your environment variables

- Locate the provisioned CosmosDB instance in the [Azure Portal](https://portal.azure.com)
- Open the Cosmos Connection String blade
- Make sure the Cosmos DB resource is already created as described above
- From Bash command line, run `load_env.sh`. This will write/load any needed variables to the `vars.env` file
  - `RESOURCE_GROUP` - the Azure resource group name
  - `COSMOSDB_NAME` - the CosmosDB collection name (which is case sensitive)
  - `COSMOSDB_PASSWORD` - the CosmosDB's password (needed for when you load the data into Cosmos)
- Load `vars.env` into your environment or the VM where the app is being built locally
  - `source vars.env`
  - or in your chosen IDE, set your environment variables within your project
- NB: there will also be a DB_NAME and DB_CONNSTR for the Spring application (see the database section below in Application Configuration)

### Prepare the command line

- Switch into the project `data` directory: `cd data`
- Log into Azure: `az login`
- If you have multiple subscriptions, confirm that the project subscription is active:

``` Bash
az account show
az account set --subscription <subscription name/ID>
```

### Import the sample IMDb data to Cosmos DB

- Open a Bash command line
- Download and prepare the required IMDb data files:

``` Bash
data/getdata.sh
```

- Before starting to import data make sure the step `Set up your environment variables` is completed.
- Import the data into Cosmos collections

``` Bash
data/importdata.sh
```

### TIP: Explore the data from the MongoDB command-line

- Copy the Cosmos DB connection string from the "Connection String" blade
- Start the MongoDB CLI with this command: `mongo <connection string>`
- Begin executing MongoDB commands, such as:

``` Mongo
use moviesdb
show collections
db.titles.count()
db.titles.find ({primaryTitle: "Casablanca"})
```

### create a new service principal and object id which will be used for AKS and key vault setup

- Log into Azure: `az login`
- If you have multiple subscriptions, confirm that the project subscription is active:

``` Bash
az account show
az account set --subscription <subscription name/ID>

az ad sp create-for-rbac --skip-assignment
```
- save values of appId and password. These will be used for AKS setup
- Run below command to get object id of live id or microsoft id
``` Bash
az ad user show --upn-or-object-id <your Live ID> | jq -r .objectId

```
- save values of Object ID. These will be used for Key vault setup