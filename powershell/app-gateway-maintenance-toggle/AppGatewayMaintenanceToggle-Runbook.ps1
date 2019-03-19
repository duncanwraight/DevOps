# @title:   Maintenance Page toggle
# @purpose: Detect which Backend Pool an Azure Application Gateway is currently pointing at.
#           If it's pointing at the "correct" pool, e.g. DC/OS Master nodes, change this to point at a maintenance App Service
#           If it's pointing at the maintenance App Service, point it back at the DC/OS Master nodes
#           In short, this allows us to toggle a Maintenance Page which is hosted by an App Service if needing to take the whole application offline.            
# @tech:    PowerShell
# @author:  Duncan Wraight
# @version: 1.2
# @url:     https://www.linkedin.com/in/duncanwraight

# Azure Runbook authentication
Try {
    $ServicePrincipalConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
    
    Write-Output "Logging in to Azure..."
    
    # Use $null= instead of | Out-Null which doesn't work in Azure Runbooks
	$null = Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $ServicePrincipalConnection.TenantId `
        -ApplicationId $ServicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint
}
Catch {
    Throw $_.Exception
}

function Get-CurrentLineNumber { 
    $MyInvocation.ScriptLineNumber 
}

# Names of rules/HTTP settings etc. to use for Maintenance Toggle
$MaintenanceTogglePrefix = 'OrgName-Project-MaintenanceToggle'
$MaintenanceToggleHTTPSettingSuffix = 'HS'
$MaintenanceToggleBackendPoolSuffix = 'BPO'
$MaintenanceToggleHealthProbeSuffix = 'HPR'

<#############################################################################>

$Subscriptions = @(
    @{
        acronym="DTD";
        id = "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
        resourceGroup = "OrgName-WebPlatform-DT-RG";
        appGateway = "OrgName-AppGateway-DT-AG";
        httpsRule = "DEVOPS-TEST-HTTP";
        httpListener = "HttpListenerTest";
        origBackendPool = "appGatewayBackendPool";
        origHttpSetting = "Project-Secure-Proxy";
        webAppResourceGroup = "projecthtmlpages";
        webAppService = "projecthtmlpages"
    };
    
    @{
        acronym="PPT";
        id = "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
        resourceGroup = "OrgName-DCOSWeb-PPT-RG";
        appGateway = "OrgName-AppGateway-PPT-AG";
        httpsRule = "Project-HTTPS-Rule";
        httpListener = "MyHomeAccount-HTTPS-Test";
        origBackendPool = "dcos-public-node-ip";
        origHttpSetting = "Project-Secure-Proxy";
    };
    
    @{
        acronym="PR";
        id = "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
        resourceGroup = "OrgName-DCOSWeb-PR-RG";
        appGateway = "OrgName-AppGateway-PR-AG";
        httpsRule = "Project-HTTPS-Rule";
        httpListener = "Project-HTTPS";
        origBackendPool = "DCOS-PublicNodes";
        origHttpSetting = "Project-Secure-Proxy";
    }
)

# Work out which subscription this script is running on
$CurrentSubscription = $(Get-AzureRmContext).Subscription.Id
Write-Output "[$(Get-CurrentLineNumber)]  Active Azure subscription ID is: $($CurrentSubscription)."

# Use this subscription's Hash Table for the rest of the script
$ChosenSubscription = ''
ForEach( $Subscription in $Subscriptions ) {
    If( [string]$Subscription.id -eq [string]$CurrentSubscription ) {
        Write-Output "[$(Get-CurrentLineNumber)]  This subscription is: $($Subscription.acronym)."
        $ChosenSubscription = $Subscription
    }
}

If( $ChosenSubscription.GetType().FullName -ne "System.Collections.Hashtable" ) {
    Throw "`$ChosenSubscription hasn't been selected properly. Variable type $($ChosenSubscription.GetType().FullName). Exiting..."
}

# Get the names of our rules etc. based on the prefixes/suffixes defined above and the environment we're connected to
$MaintenanceToggleHTTPSetting = "$($MaintenanceTogglePrefix)-$($ChosenSubscription.acronym)-$($MaintenanceToggleHTTPSettingSuffix)"
$MaintenanceToggleHealthProbe = "$($MaintenanceTogglePrefix)-$($ChosenSubscription.acronym)-$($MaintenanceToggleHealthProbeSuffix)"
$MaintenanceToggleBackendPool = "$($MaintenanceTogglePrefix)-$($ChosenSubscription.acronym)-$($MaintenanceToggleBackendPoolSuffix)"

# Bit of a hack for Dev/Test because the Web App doesn't follow naming conventions
If ( $ChosenSubscription.webAppResourceGroup ) {
    $WebAppResourceGroup = $ChosenSubscription.webAppResourceGroup
}
Else { $WebAppResourceGroup = "Project-StaticHTMLPagesContainers-$($ChosenSubscription.acronym)-RG" }

If ( $ChosenSubscription.webAppService ) {
    $WebAppService = $ChosenSubscription.webAppService
}
Else { $WebAppService = "Project-MaintenancePage-$($ChosenSubscription.acronym)-APP" }

# Retrieve the Application Gateway
Try {
    $AppGW = Get-AzureRmApplicationGateway -Name $ChosenSubscription.appGateway -ResourceGroupName $ChosenSubscription.resourceGroup  
}
Catch {
    Throw "Unable to retrieve Application Gateway. Ran into error: $($_.Exception)."
}

<# INVESTIGATE CURRENT HTTPS RULE TO SEE WHICH BACKEND POOL IT'S POINTING AT #>

Try {
    $Rule = Get-AzureRmApplicationGatewayRequestRoutingRule -Name $ChosenSubscription.httpsRule -ApplicationGateway $AppGW  
}
Catch {
    Throw "Unable to retrieve Request Routing Rule. Variables [Name=$($ChosenSubscription.httpsRule), ApplicationGateway=$($AppGW.Name)]. Ran into error: $($_.Exception)."
}

$MaintenancePageEnabled = $False

# Name of associated backendPool is in a long string format including multiple forward slashes. Find the last forward slash and any text after it using this RegEx pattern
$null = $Rule.BackendAddressPool.Id -match '/[^/]*$'

$CurrentBackendAddressPool = $matches[0] -replace '/', ''

# Does the name of the associated backendPool contain the name of our Maintenance Page backendPool?
If( $CurrentBackendAddressPool -contains "$($MaintenanceToggleBackendPool)" ) {
    Write-Output "[$(Get-CurrentLineNumber)]  Current Backend Pool associated with primary rule '$($ChosenSubscription.httpsRule)' is our Maintenance Page Backend Pool '$($MaintenanceToggleBackendPool)'"
    $MaintenancePageEnabled = $True
} Else {
    Write-Output "[$(Get-CurrentLineNumber)]  Current Backend Pool associated with primary rule '$($ChosenSubscription.httpsRule)' is '$($CurrentBackendAddressPool)'"
}

# If the Maintenance Page isn't already enabled, the user running this script must want to enable it
If( !$MaintenancePageEnabled ) {
    Write-Output "[$(Get-CurrentLineNumber)]  Maintenance page isn't enabled." 
    
    <# IF DOES NOT EXIST, CREATE BACKEND POOL FOR APP SERVICE #>
    
    # Get the FQDN of our maintenance page App Service to set -BackendFqdns
    Try {
        $WebApp = Get-AzureRmWebApp -ResourceGroupName $WebAppResourceGroup -Name $WebAppService 
    }
    Catch {
        Throw "Unable to retrieve Web App Service. Variables [Name=$($WebAppService), ResourceGroup=$($WebAppResourceGroup)]. Ran into error: $($_.Exception)."
    }

    Write-Output "[$(Get-CurrentLineNumber)]  Retrieved App Service '$($WebApp.Name)' with EnabledHostNames '$($WebApp.EnabledHostNames)'." 

    # Create a new BackendPool which points at our App Service/Web App
    $backendPool = Get-AzureRmApplicationGatewayBackendAddressPool -Name $MaintenanceToggleBackendPool `
        -ApplicationGateway $AppGW `
        -ErrorAction SilentlyContinue

    If( !$backendPool ) {
        Write-Output "[$(Get-CurrentLineNumber)]  No AG Backend Address Pool currently exists with name '$($MaintenanceToggleBackendPool)'. Attempting to create..." 
        
        # Add our new backend address pool
        Try {
            $backendPool = Add-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $AppGW `
                -Name $MaintenanceToggleBackendPool `
                -BackendFqdns $WebApp.EnabledHostNames[0]
        }
        Catch {
            Throw "Unable to add Backend Address Pool. Variables [Name=$($MaintenanceToggleBackendPool), ApplicationGateway=$($AppGW.Name), BackendFqdns=$($WebApp.EnabledHostNames[0])]. Ran into error: $($_.Exception)."
        }

        # Save Gateway configuration
        Write-Output "[$(Get-CurrentLineNumber)]  Attempting to save changes to the Application Gateway..."
        Try {
            # Use $null= instead of | Out-Null which doesn't work in Azure Runbooks
			$null = Set-AzureRmApplicationGateway -ApplicationGateway $backendPool
        }
        Catch {
            Throw "Unable to save Application Gateway configuration. Variables [ApplicationGateway=$($backendPool.Name)]. Ran into error: $($_.Exception)."
        }
    }
    Else {
        Write-Output "[$(Get-CurrentLineNumber)]  Retrieved AG Backend Address Pool '$($backendPool.Name)'." 
    }

    <# IF DOES NOT EXIST, CREATE A CUSTOM PROBE #>
    #http, pick hostname from backend http settings, use probe matching conditions, path /index.html and rest default

    $probe = Get-AzureRmApplicationGatewayProbeConfig -Name $MaintenanceToggleHealthProbe `
        -ApplicationGateway $AppGW `
        -ErrorAction SilentlyContinue
    
    If( !$probe ) {
        Write-Output "[$(Get-CurrentLineNumber)]  No AG Health Probe currently exists with name '$($MaintenanceToggleHealthProbe)'. Attempting to create..." 
        Try {
            $match = New-AzureRmApplicationGatewayProbeHealthResponseMatch -StatusCode 200-399
        }
        Catch {
            Throw "Unable to create Health Probe Response Match. Variables [StatusCode=200-399]. Ran into error: $($_.Exception)."
        }
        
        Try {
            $probe = Add-AzureRmApplicationGatewayProbeConfig -ApplicationGateway $AppGW `
                -Name $MaintenanceToggleHealthProbe `
                -Protocol Http -PickHostNameFromBackendHttpSettings `
                -Path "/index.html" `
                -Interval 30 `
                -Timeout 30 `
                -UnhealthyThreshold 3 `
                -Match $match
        }
        Catch {
            Throw "Unable to create Health Probe. Variables [ApplicationGateway=$($AppGW.Name), Name=$($MaintenanceToggleHealthProbe), Protocol=Http, Path=/Index.html, Interval=30, Timeout=30, UnhealthyThreshold=3,Match=`$Match]. Ran into error: $($_.Exception)."
        }

        # Save Gateway configuration
        Write-Output "[$(Get-CurrentLineNumber)]  Attempting to save changes to the Application Gateway..."
        Try {
            # Use $null= instead of | Out-Null which doesn't work in Azure Runbooks
			$null = Set-AzureRmApplicationGateway -ApplicationGateway $probe
        }
        Catch {
            Throw "Unable to save Application Gateway configuration. Variables [ApplicationGateway=$($probe.Name)]. Ran into error: $($_.Exception)."
        }
    }
    Else {
        Write-Output "[$(Get-CurrentLineNumber)]  Retrieved AG Health Probe '$($probe.Name)'." 
    }

    <# IF DOES NOT EXIST, CREATE HTTP SETTING TO POINT AT ABOVE BACKEND POOL #>
    #http, port 80, tick "use for app service", link ^ custom probe

    $httpSettings = Get-AzureRmApplicationGatewayBackendHttpSettings -Name $MaintenanceToggleHTTPSetting `
        -ApplicationGateway $AppGW `
        -ErrorAction SilentlyContinue
    
    If( !$httpSettings ) {
        Try {
            $probe = Get-AzureRmApplicationGatewayProbeConfig -ApplicationGateway $AppGW -Name $MaintenanceToggleHealthProbe
        }
        Catch {
            Throw "Unable to retrieve Health Probe. Variables [Name=$($MaintenanceToggleHealthProbe), ApplicationGateway=$($AppGW.Name)]. Ran into error: $($_.Exception)."
        }
        
        Write-Output "[$(Get-CurrentLineNumber)]  No AG HTTP Settings currently exist with name '$($MaintenanceToggleHTTPSetting)'. Attempting to create..."
        Try {
            $httpSettings = Add-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $AppGW `
                -Name $MaintenanceToggleHTTPSetting `
                -Protocol Http `
                -Port 80 `
                -CookieBasedAffinity Disabled `
                -RequestTimeout 120 `
                -Probe $probe `
                -PickHostNameFromBackendAddress
        }
        Catch {
            Throw "Unable to create HTTP Setting. Variables [ApplicationGateway=$($AppGW.Name), Name=$($MaintenanceToggleHTTPSetting), Protocol=Http, Port=80, CookieBasedAffinity=Disabled, RequestTimeout=30, PickHostNameFromBackendAddress, Probe=`$probe]. Ran into error: $($_.Exception)."
        }

        # Save Gateway configuration
        Write-Output "[$(Get-CurrentLineNumber)]  Attempting to save changes to the Application Gateway..."
        Try {
            # Use $null= instead of | Out-Null which doesn't work in Azure Runbooks
			$null = Set-AzureRmApplicationGateway -ApplicationGateway $httpSettings
        }
        Catch {
            Throw "Unable to save Application Gateway configuration. Variables [ApplicationGateway=$($httpSettings.Name)]. Ran into error: $($_.Exception)."
        }
    }
    Else {
        Write-Output "[$(Get-CurrentLineNumber)]  Retrieved AG HTTP Settings '$($httpSettings.Name)'." 
    }
    
    <# AMEND EXISTING HTTPS RULE TO POINT AT NEW BACKEND POOL AND HTTP SETTING #>

    # Get the relevant rule...
    Try {
        $rule = Get-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $AppGW -Name $ChosenSubscription.httpsRule
    }
    Catch {
        Throw "Unable to retrieve Request Routing Rule. Variables [Name=$($ChosenSubscription.httpsRule), ApplicationGateway=$($httpSettings.Name)]. Ran into error: $($_.Exception)."
    }
    
    If( $rule ) {
        Write-Output "[$(Get-CurrentLineNumber)]  Retrieved AG Rule '$($rule.Name)'." 
        Write-Output "[$(Get-CurrentLineNumber)]  Attempting to change this rule to point at Backend Address Pool '$($backendPool.Name)' and HTTP Settings '$($httpSettings.Name)'..." 

        # Re-retrieve the Application Gateway after saving it earlier
        Try {
            $AppGW = Get-AzureRmApplicationGateway -Name $ChosenSubscription.appGateway -ResourceGroupName $ChosenSubscription.resourceGroup  
        }
        Catch {
            Throw "Unable to retrieve Application Gateway. Ran into error: $($_.Exception)."
        }
        
        # Re-retrieve the Backend Address Pool and HTTP Settings that we've created, for the sake of updating the rule
        Try {
            $backendPool = Get-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $AppGW -Name $MaintenanceToggleBackendPool
            $httpSettings = Get-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $AppGW -Name $MaintenanceToggleHTTPSetting
            $httpListener = Get-AzureRmApplicationGatewayHttpListener -ApplicationGateway $AppGW -Name $ChosenSubscription.httpListener
        }
        Catch {
             Throw "Unable to retrieve either the Backend Address Pool, HTTP Setting or HTTP Listener. Ran into error: $($_.Exception)."           
        }

        Try {
            $amendedRule = Set-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $AppGW `
                -Name $ChosenSubscription.httpsRule `
                -RuleType Basic `
                -BackendAddressPool $backendPool `
                -BackendHttpSettings $httpSettings `
                -HttpListener $httpListener
        }
        Catch {
            Throw "Unable to amend Request Routing Rule. Variables [ApplicationGateway=$($AppGW.Name), Name=$($ChosenSubscription.httpsRule), BackendAddressPool=`$backendPool, BackendHttpSettings=`$httpSettings] HttpListener=`$httpListener. Ran into error: $($_.Exception)."
        }
        
        # Save Gateway configuration
        Write-Output "[$(Get-CurrentLineNumber)]  Attempting to save changes to the Application Gateway..."
        Try {
            # Use $null= instead of | Out-Null which doesn't work in Azure Runbooks
			$null = Set-AzureRmApplicationGateway -ApplicationGateway $amendedRule
        }
        Catch {
            Throw "Unable to save Application Gateway configuration. Variables [ApplicationGateway=$($amendedRule.Name)]. Ran into error: $($_.Exception)."
        }
    }
}
Else {
    <# RESTORE ALL OF THE ORIGINAL SETTINGS BACK TO THE APPLICATION GATEWAY RULE #>

    # Get the relevant rule...
    Try {
        $rule = Get-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $AppGW -Name $ChosenSubscription.httpsRule
    }
    Catch {
        Throw "Unable to retrieve Request Routing Rule. Variables [Name=$($ChosenSubscription.httpsRule), ApplicationGateway=$($httpSettings.Name)]. Ran into error: $($_.Exception)."
    }

    If( $rule ) {
        Write-Output "[$(Get-CurrentLineNumber)]  Retrieved AG Rule '$($rule.Name)'." 
        Write-Output "[$(Get-CurrentLineNumber)]  Attempting to change this rule to point at Backend Address Pool '$($ChosenSubscription.origBackendPool)' and HTTP Settings '$($ChosenSubscription.origHttpSetting)'..." 

        # Retrieve the Application Gateway
        Try {
            $AppGW = Get-AzureRmApplicationGateway -Name $ChosenSubscription.appGateway -ResourceGroupName $ChosenSubscription.resourceGroup  
        }
        Catch {
            Throw "Unable to retrieve Application Gateway. Ran into error: $($_.Exception)."
        }
        
        # Retrieve the Backend Address Pool, HTTP Settings and Listener from our chosen subscription
        Try {
            $backendPool = Get-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $AppGW -Name $ChosenSubscription.origBackendPool
            $httpSettings = Get-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $AppGW -Name $ChosenSubscription.origHttpSetting
            $httpListener = Get-AzureRmApplicationGatewayHttpListener -ApplicationGateway $AppGW -Name $ChosenSubscription.httpListener
        }
        Catch {
             Throw "Unable to retrieve either the (original) Backend Address Pool, HTTP Setting or HTTP Listener. Ran into error: $($_.Exception)."           
        }

        Try {
            $amendedRule = Set-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $AppGW `
            -Name $ChosenSubscription.httpsRule `
            -RuleType Basic `
            -BackendAddressPool $backendPool `
            -BackendHttpSettings $httpSettings `
            -HttpListener $httpListener
        }
        Catch {
            Throw "Unable to amend Request Routing Rule. Variables [ApplicationGateway=$($AppGW.Name), Name=$($ChosenSubscription.httpsRule), BackendAddressPool=`$backendPool, BackendHttpSettings=`$httpSettings] HttpListener=`$httpListener. Ran into error: $($_.Exception)."
        }

        # Save Gateway configuration
        Write-Output "[$(Get-CurrentLineNumber)]  Attempting to save changes to the Application Gateway..."
        Try {
            # Use $null= instead of | Out-Null which doesn't work in Azure Runbooks
			$null = Set-AzureRmApplicationGateway -ApplicationGateway $amendedRule
        }
        Catch {
            Throw "Unable to save Application Gateway configuration. Variables [ApplicationGateway=$($amendedRule.Name)]. Ran into error: $($_.Exception)."
        }
    }
}

Write-Output "[$(Get-CurrentLineNumber)]  Process completed, please check Portal for confirmation." 