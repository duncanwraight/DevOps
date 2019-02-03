#!/usr/bin/env bash

# @title:   Azure container promotion
# @purpose: Promote/duplicate container images from one Azure Container Registry to another, either
#             in the same subscription or another.
#           Also gives user the option of which environment to be promoted to, and could obviously
#             be expanded.
#           Primarily designed as a manual deployment method for non-CI/CD environments like
#             Pre-Production or Production.
# @deps:    Requires a version of Bash which supports associative arrays.
# @tech:    Bash/Azure CLI
# @author:  Duncan Wraight
# @version: 1.1
# @url:     https://www.linkedin.com/in/duncanwraight

# Services to push
# Any service prefixed with a hash symbol will NOT be pushed
services=(
   "my-image-name:v1.0.1"
   #"my-other-image:latest"
)

# Colour codes for text output
TXT_RED='\033[0;31m'
TXT_GRN='\033[0;32m'
TXT_BLU='\033[0;34m'
TXT_YEL='\033[1;33m'
TXT_NC='\033[0m'

# Subscriptions
declare -A DEV
DEV["Subscription"]='Dev'
DEV["AcrURL"]="azurecontainerregistrydev.azurecr.io"
DEV["AcrName"]="AzureContainerRegistryDEV"

declare -A PPT
PPT["Subscription"]="Pre-Production"
PPT["AcrURL"]="azurecontainerregistryppt.azurecr.io"
PPT["AcrName"]="AzureContainerRegistryPPT"

declare -A PR
PR["Subscription"]="Production"
PR["AcrURL"]="azurecontainerregistrypr.azurecr.io"
PR["AcrName"]="AzureContainerRegistryPR"

echo -e "--- Running script ${TXT_YEL}PromoteContainers.sh${TXT_NC}\n"

# User input to request the "pull" environment
echo -e "${TXT_GRN}Which environment are you promoting to?${TXT_NC}"
echo -e "Type [${TXT_YEL}PPT${TXT_NC}] for Pre-Production or [${TXT_YEL}PR${TXT_NC}] for Production"
read input_environment

if [ $input_environment = "PR" ] ; then
    EnvironmentName="Production"

    PullSubscription=${DEV[Subscription]}
    PullAcrName=${DEV[AcrName]}
    PullAcrURL=${DEV[AcrURL]}

    PushSubscription=${PR[Subscription]}
    PushAcrName=${PR[AcrName]}
    PushAcrURL=${PR[AcrURL]}

    AppResourceGroup="MyResouceGroup"     # Only relevant if also promoting an App Service
    AcrPassword="<<changeme>>"
else
    EnvironmentName="Pre-Production"

    PullSubscription=${DEV[Subscription]}
    PullAcrName=${DEV[AcrName]}
    PullAcrURL=${DEV[AcrURL]}

    PushSubscription=${PPT[Subscription]}
    PushAcrName=${PPT[AcrName]}
    PushAcrURL=${PPT[AcrURL]}

    AppResourceGroup="MyResourceGroup"      # Only relevant if also promoting an App Service
    AcrPassword="<<changeme>>"
fi

echo -e "\nYou have chosen to promote containers to the ${TXT_RED}${EnvironmentName}${TXT_NC} environment, which uses the following variables:"
echo -e "   ${TXT_RED}Pull from...${TXT_NC}"
echo -e "Subscription: ${TXT_BLU}${PullSubscription}${TXT_NC}"
echo -e "Container Registry Name: ${TXT_BLU}${PullAcrName}${TXT_NC}"
echo -e "Container Registry URL: ${TXT_BLU}${PullAcrURL}${TXT_NC}"
echo -e "   ${TXT_RED}Promote to...${TXT_NC}"
echo -e "Subscription: ${TXT_BLU}${PushSubscription}${TXT_NC}"
echo -e "Container Registry Name: ${TXT_BLU}${PushAcrName}${TXT_NC}"
echo -e "Container Registry URL: ${TXT_BLU}${PushAcrURL}${TXT_NC}\n"

echo -e "The following services will be promoted:"
for i in "${services[@]}"
do
    echo -e " - ${TXT_RED}${i}${TXT_NC}"
done

echo -e "\n"

read -p "Please double-check the stated variables and press Enter to continue"

echo -e "\n${TXT_GRN}Logging into Azure...${TXT_NC}"
az login --query "[?n]|[0]"  #--query is a hack to stop the subscription output

CreateStaticHTMLContainer=false
StaticHTMLContainer=false

echo -e "\n--- Beginning container promotion sequence\n"

for i in "${services[@]}"
do
    :
        echo -e "${TXT_GRN}Starting push for service ${TXT_RED}${i}${TXT_NC}"
        az account set -s "$PullSubscription"
        az acr login -n "$PullAcrName"
        docker pull $PullAcrURL/$i
        docker tag $PullAcrURL/$i $PushAcrURL/$i
        az account set -s "$PushSubscription"
        az acr login -n "$PushAcrName"
        docker push $PushAcrURL/$i
        echo -e "${TXT_GRN}Push completed for service ${TXT_RED}${i}${TXT_NC}\n"

        # Is one of these services our standalone static HTML pages container?
        if [[ $i == "html-pages"* ]]; then
            CreateStaticHTMLContainer=true
            StaticHTMLContainer=$i
        fi
done

echo -e "--- Container promotion completed\n"

# If one of the services that we're trying to update is our static HTML pages container, we need to do something slightly different
# Create an "App Service" (AKA "Web App") standalone container in the "Push" subscription and configure it to use our pushed image
if [ "$CreateStaticHTMLContainer" = true ] ; then
    echo -e "${TXT_GRN}Static HTML container${TXT_NC} requires an update. ${TXT_YEL}Processing...${TXT_NC}\n"
    
    # Get the name of the App Service
    echo -e "${TXT_GRN}Enter the name (purpose) of this App Service, e.g. \"Maintenance Page Toggle\" or \"First Use Experience\"${TXT_NC}"
    read input_appservicename

    # Little bodge to trim and capitalise the input
    AppServiceName=""
    for i in $input_appservicename; do B=`echo -n "${i:0:1}" | tr "[:lower:]" "[:upper:]"`; AppServiceName="${AppServiceName}${B}${i:1} "; done
    AppServiceName=$( echo "${AppServiceName}" | tr -cd [:alnum:] );

    AppServicePrefix="${AppServiceName}-${input_environment}"
    AppServicePlan="${AppServicePrefix}-ASP"
    AppService="${AppServicePrefix}-APP"

    # Create a Resource Group
    echo -e "Creating ${TXT_GRN}Resource Group${TXT_NC}"
    az group create --name $AppResourceGroup --location "UKWest" --tags 'Resource_Owner=DevOps' 'Environment_Name=PPT' 'Purpose=MyProject' --output jsonc

    # Create an App Service Plan
    echo -e "\nCreating ${TXT_GRN}App Service Plan${TXT_NC}"
    az appservice plan create --name $AppServicePlan --resource-group $AppResourceGroup --location "UK West" --sku "B1" --is-linux --number-of-workers 3 --tags 'Resource_Owner=DevOps' 'Environment_Name=PPT' 'Purpose=MyProject' --output jsonc

    # Create an App Service
    echo -e "\nCreating ${TXT_GRN}App Service${TXT_NC}"
    az webapp create --name "$AppService" --plan "$AppServicePlan" --resource-group "$AppResourceGroup" --deployment-container-image-name "${PushAcrURL}/html-pages" --tags 'Resource_Owner=DevOps' 'Environment_Name=PPT' 'Purpose=MyProject' --output jsonc

    # Configure the App Service
    echo -e "\nConfiguring App Service ${TXT_GRN}container${TXT_NC}"
    az webapp config container set --enable-app-service-storage false --docker-registry-server-url "https://${PushAcrURL}" --docker-registry-server-user $PushAcrName --docker-registry-server-password $AcrPassword --docker-custom-image-name "${PushAcrURL}/${StaticHTMLContainer}" --name "$AppService" --resource-group "$AppResourceGroup" --output jsonc

    # Set the CI config
    echo -e "\nConfiguring App Service ${TXT_GRN}CI${TXT_NC}"
    az webapp config appsettings set --settings='DOCKER_ENABLE_CI=true' --name "$AppService" --resource-group "$AppResourceGroup" --output jsonc

    echo -e "\n${TXT_YEL}Processing completed${TXT_NC}. Click the link below to test:"
    echo -e "${TXT_GRN}http://$AppService.azurewebsites.net${TXT_NC}\n\n"
fi
