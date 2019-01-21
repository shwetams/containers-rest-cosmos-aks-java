#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -c <servicePrincipalClientId> -s <servicePrincipalClientSecret> -o <objectId> -d <DBCONNSTR> -m <DBNAME> " 1>&2; exit 1; }

declare subscriptionId=""
declare resourceGroupName=""
declare deploymentName=""
declare resourceGroupLocation=""
declare servicePrincipalClientId=""
declare servicePrincipalClientSecret=""
declare objectId=""
declare DBCONNSTR=""
declare DBNAME=""


# Initialize parameters specified from command line
while getopts ":i:g:n:l:" arg; do
	case "${arg}" in
		i)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		n)
			deploymentName=${OPTARG}
			;;
		l)
			resourceGroupLocation=${OPTARG}
			;;

		c)
			servicePrincipalClientId=${OPTARG}
			;;
		s)
			servicePrincipalClientSecret=${OPTARG}
			;;
		o)
			objectId=${OPTARG}
			;;
		d)
			DBCONNSTR=${OPTARG}
			;;
		m)
			DBNAME=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
	echo "Your subscription ID can be looked up with the CLI using: az account show --out json "
	echo "Enter your subscription ID:"
	read subscriptionId
	[[ "${subscriptionId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$resourceGroupLocation" ]]; then
	echo "If creating a *new* resource group, you need to set a location "
	echo "You can lookup locations with the CLI using: az account list-locations "

	echo "Enter resource group location:"
	read resourceGroupLocation
fi

if [[ -z "$servicePrincipalClientId" ]]; then
	echo "Please enter service principal client ID creates using Global readme "
	echo "Enter your service principal client ID:"
	read servicePrincipalClientId
	[[ "${servicePrincipalClientId:?}" ]]
fi

if [[ -z "$servicePrincipalClientSecret" ]]; then
	echo "Please enter service principal client secret creates using Global readme "
	echo "Enter your service principal client secret:"
	read servicePrincipalClientSecret
	[[ "${servicePrincipalClientSecret:?}" ]]
fi

if [[ -z "$objectId" ]]; then
	echo "Please enter object ID of you azure login. This can be looked up with the CLI using: az ad user show --upn-or-object-id <your Live ID> | jq -r .objectId "
	echo "Enter your object ID:"
	read objectId
	[[ "${objectId:?}" ]]
fi

if [[ -z "$DBCONNSTR" ]]; then
	echo "Please enter DB-CONNSTR  from vars.env file "
	echo "Enter your DB CONNSTR:"
	read DBCONNSTR
	[[ "${DBCONNSTR:?}" ]]
fi

if [[ -z "$DBNAME" ]]; then
	echo "Please enter DB-Name  from vars.env file "
	echo "Enter your DB Name:"
	read DBNAME
	[[ "${DBNAME:?}" ]]
fi

if [[ -z "$deploymentName" ]]; then
	echo "Please enter a Deployment Name for your Application"
	read deploymentName
	[[ "${deploymentName:?}" ]]
fi

#templateFile Path - template file to be used
templateFilePath= "azuredeploy.json"

if [ ! -f "$templateFilePath" ]; then
	echo "$templateFilePath not found"
	exit 1
fi

#parameter file path
#parametersFilePath="parameters.json"

#if [ ! -f "$parametersFilePath" ]; then
#	echo "$parametersFilePath not found"
#	exit 1
#fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ]; then
	echo "Either one of subscriptionId, resourceGroupName, deploymentName is empty"
	usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

set +e

#Check for existing RG
az group show --name $resourceGroupName 1> /dev/null

if [ $? != 0 ]; then
	echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
	set -e
	(
		set -x
		az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
	)
	else
	echo "Using existing resource group..."
fi

#Start deployment
echo "Starting deployment..."
(
	set -x
	az group deployment create --name "$deploymentName" --resource-group "$resourceGroupName" --template-file "$templateFilePath " --parameters servicePrincipalClientId="$servicePrincipalClientId" servicePrincipalClientSecret="$servicePrincipalClientSecret" DB-CONNSTR="$DBCONNSTR" DB-NAME="$DBNAME" objectId="$objectId"  #--parameters "@${parametersFilePath}"
)

if [ $?  == 0 ];
 then
	echo "Template has been successfully deployed"
fi
