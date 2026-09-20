param(
    [Parameter(Mandatory = $true)]
    [string]$paraRG,

    [Parameter(Mandatory = $true)]
    [string]$paraSPName
)

# ============================================================
# Get Azure context
# ============================================================

$subscriptionId = az account show --query id -o tsv

if (-not $subscriptionId) {
    throw "目前沒有登入 Azure"
}

$scope = "/subscriptions/$subscriptionId/resourceGroups/$paraRG"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Delete Service Principal" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SP Name        : $paraSPName"
Write-Host "Resource Group : $paraRG"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Find SP
# ============================================================

$clientId = az ad sp list `
    --display-name $paraSPName `
    --query "[0].appId" `
    -o tsv

if (-not $clientId) {
    Write-Host "找不到 Service Principal: $paraSPName" `
        -ForegroundColor Yellow
    exit
}

$spObjectId = az ad sp show `
    --id $clientId `
    --query id `
    -o tsv

Write-Host "Client ID: $clientId"

# ============================================================
# Remove RBAC assignments
# ============================================================

Write-Host ""
Write-Host "移除 RBAC Role Assignment..." `
    -ForegroundColor Yellow

az role assignment delete `
    --assignee-object-id $spObjectId `
    --scope $scope

Write-Host "RBAC 已移除" -ForegroundColor Green

# ============================================================
# Delete Service Principal
# ============================================================

Write-Host ""
Write-Host "刪除 Service Principal..." `
    -ForegroundColor Yellow

az ad sp delete `
    --id $clientId

Write-Host "Service Principal 已刪除" `
    -ForegroundColor Green

# ============================================================
# Delete App Registration
# ============================================================

Write-Host ""
Write-Host "刪除 App Registration..." `
    -ForegroundColor Yellow

az ad app delete `
    --id $clientId

Write-Host "App Registration 已刪除" `
    -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " 清除完成" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green