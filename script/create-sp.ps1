param(
    [Parameter(Mandatory = $true)]
    [string]$paraRG,

    [Parameter(Mandatory = $true)]
    [string]$paraSPName
)

# ============================================================
# Get current Azure context
# ============================================================

$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv

if (-not $subscriptionId) {
    throw "目前沒有登入 Azure，請先執行 Connect-AzAccount 或 az login"
}

# ============================================================
# Check Resource Group
# ============================================================

$rgExists = az group exists --name $paraRG

if ($rgExists -ne "true") {
    throw "找不到 Resource Group: $paraRG"
}

$scope = "/subscriptions/$subscriptionId/resourceGroups/$paraRG"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Create Service Principal" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SP Name        : $paraSPName"
Write-Host "Resource Group : $paraRG"
Write-Host "Role           : Website Contributor"
Write-Host "Scope          : $scope"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Check existing SP
# ============================================================

$existingAppId = az ad sp list `
    --display-name $paraSPName `
    --query "[0].appId" `
    -o tsv

if ($existingAppId) {
    throw "Service Principal 已存在: $paraSPName (AppId: $existingAppId)"
}

# ============================================================
# Create SP + App Registration + Secret + RBAC
# ============================================================

Write-Host "建立 Service Principal..." -ForegroundColor Yellow

$resultJson = az ad sp create-for-rbac `
    --name $paraSPName `
    --role "Website Contributor" `
    --scopes $scope `
    --output json

if (-not $resultJson) {
    throw "Service Principal 建立失敗"
}

$result = $resultJson | ConvertFrom-Json

$clientId = $result.appId
$clientSecret = $result.password
$tenantId = $result.tenant

# ============================================================
# Prepare GitHub AZURE_CREDENTIALS
# ============================================================

$azureCredentials = @{
    clientId       = $clientId
    clientSecret   = $clientSecret
    subscriptionId = $subscriptionId
    tenantId       = $tenantId
} | ConvertTo-Json

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " 建立完成" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Service Principal Name:"
Write-Host $paraSPName -ForegroundColor Yellow

Write-Host ""
Write-Host "Client ID:"
Write-Host $clientId -ForegroundColor Yellow

Write-Host ""
Write-Host "GitHub Repository Secret 請建立：" -ForegroundColor Cyan
Write-Host "AZURE_CREDENTIALS"
Write-Host ""
Write-Host $azureCredentials -ForegroundColor Yellow
Write-Host ""
Write-Host "請立即保存，Client Secret 建立後無法再次讀取。" `
    -ForegroundColor Red