#/bin/bash

# Colour codes for text output
TXT_RED='\033[0;31m'
TXT_GRN='\033[0;32m'
TXT_BLU='\033[0;34m'
TXT_YEL='\033[1;33m'
TXT_NC='\033[0m'

# User input to request the Azure subscription to be used for creation
echo -e "${TXT_GRN}Which Azure subscription do you want to create this Web App in?${TXT_NC}"
echo -e "Type [${TXT_YEL}PPT${TXT_NC}] for Pre-Production, [${TXT_YEL}PR${TXT_NC}] for Production or anything else for Dev/Test"
read input_subscription

if [ $input_subscription = "PR" ] ; then
    SubscriptionName="Production"

    ContainerRegistrySubscription="Subscription Name - Production"
    ContainerRegistryURL="acrpr.azurecr.io"
    ContainerRegistryUsername="PRACRUsername"
    ContainerRegistryPassword=""

    AppServiceResourceGroup="PR-RG"
elif [ $input_subscription = "PPT" ] ; then
    SubscriptionName="Pre-Production"

    ContainerRegistrySubscription="Subscription Name - Pre Production"
    ContainerRegistryURL="acrppt.azurecr.io"
    ContainerRegistryUsername="PPTACRUsername"
    ContainerRegistryPassword=""

    AppServiceResourceGroup="PPT-RG"
else
    SubscriptionName="Dev/Test"
    input_subscription="DT"

    ContainerRegistrySubscription='Subscription Name - Dev/Test'
    ContainerRegistryURL="acrdt.azurecr.io"
    ContainerRegistryPassword=""
    ContainerRegistryUsername="PDTACRUsername"

    AppServiceResourceGroup="DT-RG"
fi

echo -e "You have chosen to create this Web App in the ${TXT_RED}${SubscriptionName}${TXT_NC} subscription. Logging in now..."

# Login to the specified subscription
az account set -s "$ContainerRegistrySubscription"

# Determine Resource Group to use
echo -e "${TXT_GRN}Enter the name of the Resource Group you would like to host this App Service/Web App. Type [${TXT_RED}0${TXT_GRN}] to use the same Resource Group as the DC/OS infrastructure in your given subscription.${TXT_NC}"
read input_resourcegroup

if [ "${input_resourcegroup}" -ne "0" ] ; then
    AppServiceResourceGroup=$input_resourcegroup
fi

echo -e "You have chosen to use a Resource Group named ${TXT_RED}${AppServiceResourceGroup}${TXT_NC}. The script will check to see if this Resource Group already exists at a later point."

# Find out which project this Web App is being used for
echo -e "${TXT_GRN}Enter the project that this Web App will be used for, e.g. \"MHA\", \"Persona\" or \"Platform\"${TXT_NC}"
read input_project

# Get the name of the Web App
echo -e "${TXT_GRN}Enter the name (purpose) of this Web App, e.g. \"Maintenance Page Toggle\" or \"First Use Experience\"${TXT_NC}"
read input_webappname

# Get the name of the Container Image to be used in the Web App
echo -e "${TXT_GRN}Enter the container image name and tag, e.g. \"umbraco-react-poc:stable\"${TXT_NC}"
read input_containerimage

# Little bodge to trim and capitalise the input
WebAppName=""
for i in $input_webappname; do B=`echo -n "${i:0:1}" | tr "[:lower:]" "[:upper:]"`; WebAppName="${WebAppName}${B}${i:1} "; done
WebAppName=$( echo "${WebAppName}" | tr -cd [:alnum:] );

## Web App/App Service Plan variables
AppServicePrefix="HG-${input_project}-${WebAppName}-${input_subscription}"
AppServicePlan="${AppServicePrefix}-ASP"
WebApp="${AppServicePrefix}-APP"

Tags="Resource_Owner=DevOps Environment_Name=${input_subscription} Purpose=${input_project}"

# Check for existing Resource Group / create if one doesn't exist
if az group exists -n $AppServiceResourceGroup ; then
    echo -e "Resource Group ${TXT_GRN}${AppServiceResourceGroup}${TXT_NC} already exists; using this for creation of other resources."
else
    echo -e "Creating ${TXT_GRN}Resource Group${TXT_NC}"
    az group create --name $AppServiceResourceGroup --location "UKWest" --tags $Tags --output jsonc
fi

# Create an App Service Plan
echo -e "\nCreating ${TXT_GRN}App Service Plan${TXT_NC}"
az appservice plan create --name $AppServicePlan --resource-group $AppServiceResourceGroup --location "UK West" --sku "B1" --is-linux --number-of-workers 3 --tags $Tags --output jsonc

# Create a Web App
echo -e "\nCreating ${TXT_GRN}Web App${TXT_NC}"
az webapp create --name "$WebApp" --plan "$AppServicePlan" --resource-group "$AppServiceResourceGroup" --deployment-container-image-name "${PushAcrURL}/app-html-pages" --tags $Tags --output jsonc

# Configure the Web App
echo -e "\nConfiguring Web App ${TXT_GRN}container${TXT_NC}"
az webapp config container set --enable-app-service-storage false --docker-registry-server-url "https://${ContainerRegistryURL}" --docker-registry-server-user $ContainerRegistryUsername --docker-registry-server-password $ContainerRegistryPassword --docker-custom-image-name "${ContainerRegistryURL}/${input_containerimage}" --name "$WebApp" --resource-group "$AppServiceResourceGroup" --output jsonc

# Set the CI config
echo -e "\nConfiguring Web App ${TXT_GRN}CI${TXT_NC}"
az webapp config appsettings set --settings='DOCKER_ENABLE_CI=true' --name "$WebApp" --resource-group "$AppServiceResourceGroup" --output jsonc

echo -e "\n${TXT_YEL}Processing completed${TXT_NC}. Click the link below to test:"
echo -e "${TXT_GRN}http://$WebApp.azurewebsites.net${TXT_NC}\n\n"
