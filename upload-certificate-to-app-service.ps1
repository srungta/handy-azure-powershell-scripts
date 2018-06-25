# Introduction

Write-Host '...Hi...'
Write-Host 'You are using a script to install multiple PFX certificates with the passwords in keyvault quickly'
Write-Host 'By using this script, you are not agreeing to any liability or licences :)'
Write-Host 'This script may install a few powershell modules to work, mostly around Azure CLI.'

# Take the output path
$PathToJson = Read-Host -Prompt 'Provide path to the config json file :' 

if ([string]::IsNullOrWhiteSpace($PathToJson)) {
    Write-Host "Using default value 'templates/upload-certificate-to-app-service.json'."
    $PathToJson = './templates/upload-certificate-to-app-service.json'
} 
# Check if the path is valid else ask for a file name

# Check if Azure Rm is available
$IsAzureInstalled = Get-Module AzureRm -list | Select-Object Name, Version, Path

if ($IsAzureInstalled) {
    Write-Host 'You already have Azure powershell installed. Skipping installation.'
}
else {
    # Check if PowerShellGet is installed
    $IsPowerShellGetInstalled = Get-Module PowerShellGet  -list | Select-Object Name, Version, Path
    if ($IsPowerShellGetInstalled) {
        Write-Host 'You do not have Powershell get installed. Skipping installation.'
        # Give instructions to install powershellget
        Write-Host 'Visit https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps?view=azurermps-4.3.1#how-to-get-powershellget for more information'
        Exit-PSSession
    }    
    Write-Host 'You do not have Azure get installed. Initiating installation.'
    # Install Azure Rm if unavailable
    Install-Module AzureRM
    Import-Module AzureRM
}

        
# Login to Azure RM account if required
if ([string]::IsNullOrEmpty($(Get-AzureRmContext).Account)) {
    Login-AzureRmAccount
}

# Get Azure subscriptions on this account
$AllSubscriptionsForThisAccount = Get-AzureRmSubscription

# Provide option to select a subscription
$i = 0
Write-Host 'You have the following subscriptions available.'
foreach ($subscription in $AllSubscriptionsForThisAccount) {
    Write-Host $i '.' $subscription.Name
    $i++
}
$SubscriptionIndex = Read-Host -Prompt 'Select subscription by index above'

if ([convert]::ToInt32($SubscriptionIndex, 10) -ge $i -or [convert]::ToInt32($SubscriptionIndex, 10) -lt 0) {
    Write-Host 'Trying to act coy, are we? rerun the script now. :P'
    Exit-PSSession
}

Select-AzureRmSubscription -SubscriptionName $AllSubscriptionsForThisAccount[$SubscriptionIndex].Name

$content = Get-Content -Raw -Path $PathToJson | ConvertFrom-Json
2

$keyvaultName = $content.keyvaultName
$resourceGroupName = $content.resourceGroupName
$folderForCertificate = $content.certificateFolder
$certificates = $content.certificates
foreach ($application in $certificates) {
    Write-Host 'Installing certificate ' $application.certificateName
    $certificatePath = "$folderForCertificate\$($application.certificateName).pfx"
    $password = Get-AzureKeyVaultSecret -VaultName $keyvaultName -Name $application.certificatePasswordSecretName
    New-AzureRmWebAppSSLBinding -ResourceGroupName $resourceGroupName -WebAppName $application.webAppName -CertificateFilePath $certificatePath -CertificatePassword  $password.SecretValueText -Name $application.certificateName -WarningAction SilentlyContinue -ErrorAction Stop
    Remove-AzureRmWebAppSSLBinding -ResourceGroupName $resourceGroupName -WebAppName $application.webAppName -Name $application.certificateName -DeleteCertificate $false
}
