# Login to Azure first - use global admin account for the AD that u r installing this in
Login-AzureRmAccount

# Select the subscription
Get-AzureRmSubscription
Get-AzureRmSubscription | select SubscriptionName
$subscr = "Your-Own-Subscription";
$SubscrId = "your-own-subs-id";
$tenantId = "your-own-tenant-id";
Select-AzureRmSubscription -SubscriptionName $subscr

# Set the location for all resource groups
$location = "West US";
$locationUrl = "westus";
$keyValutResourceGroup = "YourOwnKeyVault";
$keyValut = "YourOwnFabricKeyVault";

# Create a new resource group for the key vault in the location where Service Fabric is going to deployed
New-AzureRmResourceGroup -Name $keyValutResourceGroup -Location $location

# Create a new key vauly in the newly created key vault resource group
# Please note that the key vault must be enabled for deployment
New-AzureRmKeyVault -VaultName $keyValut -ResourceGroupName $keyValutResourceGroup -Location $location -EnabledForDeployment

# Import Helpers
Import-Module .\ServiceFabricRPHelpers.psm1

# Create self-certificate
$clusterName = "yourownfabricCluster";
$certificateName = "YourOwnFabricCertificate";
# The certificate's subject name must match the domain used to access the Service Fabric cluster.
$dnsName = $clustername + "." + $locationUrl + ".cloudapp.azure.com";
$webApplicationReplyUrl = "https://" + $dnsName + ":19080/Explorer/index.html";
# location where you want the .PFX to be stored
$localCertPath = "D:\Keeps\Certs"; 
Invoke-AddCertToKeyVault -SubscriptionId $SubscrId -ResourceGroupName $keyValutResourceGroup -Location $location -VaultName $keyValut -CertificateName $certificateName -CreateSelfSignedCertificate -DnsName $dnsName -OutputPath $localCertPath

<# 
The output looks like this:

Name  : CertificateThumbprint
Value : BEB29D861FD06078B75AC6F08D386C81808B068F

Name  : SourceVault
Value : /subscriptions/d0eefeff-9fab-46fd-a0df-6f77505c71a6/resourceGroups/HmcKeyVault/providers/Microsoft.KeyVault/vaults/HmcFabricKey
        Vault

Name  : CertificateURL
Value : https://hmcfabrickeyvault.vault.azure.net:443/secrets/HmcFabricCertificate/3906af14c3b84641894e917133e451d2
#>

$certThumbprint = "BEB29D861FD06078B75AC6F08D386C81808B068F";

<#
Now setup the Azure Active Directory applications for the Cluster Explorer and Visual Studio
#>

# Auto create web and client apps in AD to be accessed by the cluster
.\MicrosoftAzureServiceFabric-AADHelpers\SetupApplications.ps1 -TenantId $tenantId -ClusterName $clusterName -WebApplicationReplyUrl $webApplicationReplyUrl

<#
Name                           Value                                                                                                   
----                           -----                                                                                                   
TenantId                       your-own-96a06dc3627e                                                                    
WebAppId                       your-own-3f079cc199a0                                                                    
NativeClientAppId              your-own-922ceaa831e8                                                                    
ServicePrincipalId             your-own-868e12ae6115                                                                    

-----ARM template-----
"azureActiveDirectory": {
  "tenantId":"your-own-96a06dc3627e",
  "clusterApplication":"your-own-3f079cc199a0",
  "clientApplication":"your-own-922ceaa831e8"
}
#>

$serviceFabricResourceGroup = "YourOwnFabric";
# Create a new resource group for the key vault in the location where Service Fabric is going to deployed
New-AzureRmResourceGroup -Name $serviceFabricResourceGroup -Location $location

# Check for core quota
Get-AzureRmVMUsage

<#
Location: westus

Name                         Current Value Limit  Unit
----                         ------------- -----  ----
Availability Sets                        0  2000 Count
Total Regional Cores                     2    20 Count
Virtual Machines                         1 10000 Count
Virtual Machine Scale Sets               0  2000 Count
Standard A0-A7 Family Cores              2    10 Count
Standard DSv2 Family Cores               0    10 Count
Basic A Family Cores                     0    10 Count
Standard A8-A11 Family Cores             0    10 Count
Standard D Family Cores                  0    20 Count
Standard Dv2 Family Cores                0    10 Count
Standard G Family Cores                  0    10 Count
Standard DS Family Cores                 0    10 Count
Standard GS Family Cores                 0    10 Count
Standard F Family Cores                  0    10 Count
Standard FS Family Cores                 0    10 Count
Standard NV Family Cores                 0    12 Count
Standard NC Family Cores                 0    12 Count
Standard H Family Cores                  0     8 Count
Standard Av2 Family Cores                0    10 Count
Standard LS Family Cores                 0    10 Count
#>

# I had to request a quota increase for west Us for the D series
# Test the template - using VM Size of Standard_DS1_v2 instead of Standard_D2 to avoid quota exceeded errors
Test-AzureRmResourceGroupDeployment -ResourceGroupName $serviceFabricResourceGroup -TemplateFile .\azuredeploy.json -TemplateParameterFile .\azuredeploy.parameters.json

# Deploy it
New-AzureRmResourceGroupDeployment -ResourceGroupName $serviceFabricResourceGroup -TemplateFile .\azuredeploy.json -TemplateParameterFile .\azuredeploy.parameters.json

# Assign users to the new cluster AD application that was created!!

# Connect to it
Connect-ServiceFabricCluster -ConnectionEndpoint ${dnsName}:19000 -ServerCertThumbprint $certThumbprint -AzureActiveDirectory

<# 
****** Use another script to connect, deploy something and test.....
#>

######

# Delete the resource groups
Remove-AzureRmResourceGroup -Name $serviceFabricResourceGroup -Force
Remove-AzureRmResourceGroup -Name $keyValutResourceGroup -Force
   