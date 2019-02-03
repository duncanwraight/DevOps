#/bin/bash

# @title:   Azure App Service promotion
# @purpose: Promote/duplicate a container-powered App Service to a different (or, theoretically, the
#             same) subscription
# @tech:    Bash/Azure CLI
# @author:  Duncan Wraight
# @version: 1.0
# @url:     https://www.linkedin.com/in/duncanwraight

# Colour codes for text output
TXT_RED='\033[0;31m'
TXT_GRN='\033[0;32m'
TXT_BLU='\033[0;34m'
TXT_YEL='\033[1;33m'
NC='\033[0m'

# Function to check an array for specific elements
containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Config for the new App Service, including Resource Group
resourceGroup="DEVOPS_TEST_RG"
appName="DEVOPSTESTAPP$RANDOM"
appServicePlanName="DEVOPS_TEST_SP"
location="UKWest"

imageName="my-container-image"          # The container image used to populate the App Service
dockerContainerVersion="latest"         # ... and its version tag

# Details of the subscription.registry you want to promote/copy the App Service from
PullRegistry="azure-container-registry-url.azurecr.io"
SubscrToPullFrom='Azure Subscription Name'
PullAcrLogin="AzureContainerRegistryUsername"

# Details of the subscription/registry you want to host the new App Service
PushRegistry="azure-container-registry-url.azurecr.io"
SubscrToPushTo='Azure Subscription Name'
PushAcrLogin="AzureContainerRegistryUsername"

# Login...
echo -e "${TXT_GRN}Logging in${NC}..."
az login

echo -e "--- ${TXT_GRN}Starting push for service ${TXT_RED}${imageName}${NC}"
az account set -s "$SubscrToPullFrom"
az acr login -n "$PullAcrLogin"
docker pull $PullRegistry/$imageName
docker tag $PullRegistry/$imageName $PushRegistry/$imageName
az account set -s "$SubscrToPushTo"
az acr login -n "$PushAcrLogin"
docker push $PushRegistry/$imageName
echo -e "--- ${TXT_GRN}Push completed for service ${TXT_RED}${imageName}${NC}\n"

# Create a Resource Group
echo -e "${TXT_YEL}az group create --name ${resourceGroup} --location ${location}${NC}..."
az group create --name $resourceGroup --location $location

# Create an App Service Plan
echo -e "${TXT_YEL}az appservice plan create --name $appServicePlanName --resource-group $resourceGroup --location \"UK West\" --sku \"B1\" --is-linux --number-of-workers 3${NC}..."
az appservice plan create --name $appServicePlanName --resource-group $resourceGroup --location "UK West" --sku "B1" --is-linux --number-of-workers 3

# Create a Web App
echo -e "${TXT_YEL}az webapp create --name \"${appName}\"" --plan \"${appServicePlanName}\"" --resource-group \"${resourceGroup}\"${NC}..."
az webapp create --name "$appName" --plan "$appServicePlanName" --resource-group "$resourceGroup" --deployment-container-image-name "${PushRegistry}/$imageName:$dockerContainerVersion"

# Configure Web App with a Custom Docker Container from Docker Hub
echo -e "${TXT_YEL}az webapp config container set --enable-app-service-storage false --docker-registry-server-url \"https://${PushRegistry}\" --docker-registry-server-user $PushAcrLogin --docker-registry-server-password \"jamoRFUrUBd27bfSGFMPvToVJRM=q5BB\" --docker-custom-image-name \"${PushRegistry}/$imageName:$dockerContainerVersion\" --name \"$appName\" --resource-group \"$resourceGroup\"${NC}..."
az webapp config container set --enable-app-service-storage false --docker-registry-server-url "https://${PushRegistry}" --docker-registry-server-user $PushAcrLogin --docker-registry-server-password "jamoRFUrUBd27bfSGFMPvToVJRM=q5BB" --docker-custom-image-name "${PushRegistry}/$imageName:$dockerContainerVersion" --name "$appName" --resource-group "$resourceGroup"

# Set the CI config
echo -e "${TXT_YEL}az webapp config appsettings set --settings='DOCKER_ENABLE_CI=true' --name \"$appName\" --resource-group \"$resourceGroup\"${NC}..."
az webapp config appsettings set --settings='DOCKER_ENABLE_CI=true' --name "$appName" --resource-group "$resourceGroup"

# Copy the result of the following command into a browser to see the web app.
echo http://$appName.azurewebsites.net
