[CmdletBinding()]
param(
    [parameter(mandatory=$false)] [string] $TenantId,
    [parameter(mandatory=$false)] [string] $Location = "East Us",
    [parameter(mandatory=$true)] [string] $Deployment,
    [ValidateLength(1,3)]
    [parameter(mandatory=$true)] [string] $DeploymentAlias,
    [parameter(mandatory=$true)] [string] $SubscriptionId
)

#region Check Azure login
Write-Host "Checking for an active Azure login:"
$azContext = Get-AzContext
# If no context found, execute Connect-AzAccount, and select the Tenant ID if provided.
try {
    if (-not $azContext) {
        Connect-AzAccount -Scope Process
    }
    $AzureSubscription = Select-AzSubscription -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction 'Stop'
    Write-Host "TenantId: $($AzureSubscription.Tenant.Id)"
    Write-Host "SubscriptionId: $($AzureSubscription.Subscription.Id)"
} catch {
    Write-Host "[ERROR]" -ForegroundColor 'Red'
    throw $_
}
Write-Host "[SUCCESS]" -ForegroundColor 'Green'
#end Check Azure login

# region Create Terraform Admin group
$adminGroupName = "$Deployment-terraform-admins"
$adminGroupDescription = "Terraform Admins group for the $Deployment deployment. Members of this group are able to execute terraform."
Write-Host -Message "Validating Terraform Admins Azure AD Group [$adminGroupName]:"
try {
    $terraformAdminsGroup = Get-AzADGroup -DisplayName $adminGroupName
    if(-not $terraformAdminsGroup){
        Write-Host -Message "Azure AD Group [$adminGroupName] not found. Creating Group..."
        $terraformAdminsGroup = New-AzADGroup -DisplayName $adminGroupName -MailNickname $adminGroupName -ErrorAction 'Stop' -Description $adminGroupDescription
    }
} catch {
    Write-Host "[ERROR]" -ForegroundColor 'Red'
    throw $_
}
Write-Host "[SUCCESS]" -ForegroundColor 'Green'
# endregion Create Terraform Admin group

# region Terraform Azure Resource Group.
$terraformManagementResourceGroupName = "$Deployment-terraform-management"
Write-Host -Message "Validating Terraform Management Resource Group [$terraformManagementResourceGroupName]:" 
try {
    $terraformManagementResourceGroup = Get-AzResourceGroup -Name $terraformManagementResourceGroupName -ErrorAction Ignore
    if(-not $terraformManagementResourceGroup){
        Write-Host -Message "Resource Group [$terraformManagementResourceGroupName] not found. Creating Resource Group..."
        $terraformManagementResourceGroup = New-AzResourceGroup -Name $terraformManagementResourceGroupName -Location $Location -ErrorAction 'Stop'
    }
} catch {
    Write-Host "[ERROR]" -ForegroundColor 'Red'
    throw $_
}
Write-Host "[SUCCESS]" -ForegroundColor 'Green'
# endregion Terraform Azure Resource Group.

# region Terraform Management Azure Storage Account.
$terraformManagementStorageAccountName = $DeploymentAlias + "tfsa"
Write-Host -Message "Validating Terraform Management StorageAccount [$terraformManagementStorageAccountName]:" 
try {
    $terraformManagementStorageAccount = Get-AzStorageAccount -Name $terraformManagementStorageAccountName -ResourceGroupName $terraformManagementResourceGroup.ResourceGroupName -ErrorAction Ignore
    if(-not $terraformManagementStorageAccount){
        Write-Host -Message "StorageAccount [$terraformManagementStorageAccountName] not found. Creating StorageAccount..."
        $terraformManagementStorageAccount = New-AzStorageAccount -Name $terraformManagementStorageAccountName -ResourceGroupName $terraformManagementResourceGroup.ResourceGroupName -Location $Location -SkuName 'Standard_ZRS' -EnableHttpsTrafficOnly $true -ErrorAction 'Stop'
    }
} catch {
    Write-Host "[ERROR]" -ForegroundColor 'Red'
    throw $_
}
Write-Host "[SUCCESS]" -ForegroundColor 'Green'
# endregion Terraform Management Azure Storage Account.

Set-AzCurrentStorageAccount -AccountName $terraformManagementStorageAccount.StorageAccountName -ResourceGroupName $terraformManagementResourceGroup.ResourceGroupName | Out-String | Write-Verbose

# region Terraform Management Azure Storage Container.
$terraformManagementStorageContainerName = "$Deployment-terraform"
Write-Host -Message "Validating Terraform Management Storage Container [$terraformManagementStorageContainerName]:" 
try {
    $terraformManagementStorageContainer = Get-AzStorageContainer -Name $terraformManagementStorageContainerName -ErrorAction Ignore
    if(-not $terraformManagementStorageContainer){
        Write-Host -Message "Storage Container [$terraformManagementStorageContainerName] not found. Creating Storage Container..."
        $terraformManagementStorageContainer = New-AzStorageContainer -Name $terraformManagementStorageContainerName -Permission 'Off' -ErrorAction 'Stop'
    }
} catch {
    Write-Host "[ERROR]" -ForegroundColor 'Red'
    throw $_
}
Write-Host "[SUCCESS]" -ForegroundColor 'Green'
# endregion Terraform Management Azure Storage Container.