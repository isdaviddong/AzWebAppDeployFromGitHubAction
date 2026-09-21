# 使用 GitHub Actions 部署 Azure Web App

本專案是文章[用 GitHub Actions 部署 Azure Web App](https://isdaviddong.github.io/Reporter/Articles/Deploy_Az_Web_App_form_GH_Action.html)使用的 ASP.NET Core Razor Pages 範例，完整示範可參考 [YouTube 影片](https://www.youtube.com/watch?v=GMR52AqDOns)。

網站本身是最小化的 .NET Web App，重點不在頁面功能，而在展示如何透過 GitHub Actions 將程式建置、發布並部署到 Azure Web App。

## 部署流程

```text
Push 到 GitHub
		|
GitHub Actions restore / build / publish
		|
使用 AZURE_CREDENTIALS 登入 Azure
		|
部署到 Azure Web App
```

GitHub Actions workflow 位於 `.github/workflows/deploy.yml`，主要步驟如下：

1. 取出 GitHub repository 的原始碼。
2. 設定 .NET SDK。
3. 執行 `dotnet restore`、`dotnet build` 與 `dotnet publish`。
4. 使用 `azure/login@v2` 登入 Azure。
5. 使用 `azure/webapps-deploy@v3` 將 `./publish` 部署到 Azure Web App。

Workflow 可以在 push 到 `main` 時執行，也可以使用 `workflow_dispatch` 手動執行。

## Azure 部署身分

GitHub Actions 是無人值守的自動化流程，不能依賴開發者個人的 Azure 登入狀態。因此本專案使用 Service Principal 作為 GitHub Actions 登入 Azure 的身分。

Service Principal 的權限被限制在指定的 Resource Group，並使用 `Website Contributor` 角色。這表示部署流程可以操作該 Resource Group 內的網站資源，但不會自動取得其他 Resource Group 的權限。

建立完成後，GitHub Repository 必須建立名為 `AZURE_CREDENTIALS` 的 Secret，內容是 JSON：

```json
{
	"clientId": "...",
	"clientSecret": "...",
	"subscriptionId": "...",
	"tenantId": "..."
}
```

Workflow 會透過下列設定讀取它：

```yaml
with:
	creds: ${{ secrets.AZURE_CREDENTIALS }}
```

不要將這份 JSON 寫入程式碼、提交到 Git，或放進影片、截圖及 Actions log。正式環境建議評估 GitHub Actions OIDC，以免保存長期有效的 Client Secret。

## 重要 Script

### `script/create-sp.ps1`

此 Script 建立 GitHub Actions 部署所需的 Service Principal、App Registration、Client Secret 與 Azure RBAC 權限。

執行前須先使用 Azure CLI 登入，並準備好已存在的 Resource Group：

```powershell
az login

.\script\create-sp.ps1 `
	-paraRG "ResourceGroupName" `
	-paraSPName "GitHubActionsDeploy"
```

它會：

- 取得目前的 Subscription ID 與 Tenant ID。
- 確認指定的 Resource Group 存在。
- 防止建立同名的 Service Principal。
- 以 `Website Contributor` 角色建立指定 Resource Group Scope 的權限。
- 輸出 `AZURE_CREDENTIALS` 所需的 JSON。

Client Secret 只會在建立時顯示，請在 Script 執行完成後立即保存。

### `script/delete-sp.ps1`

此 Script 用來清理不再使用的部署身分與權限：

```powershell
.\script\delete-sp.ps1 `
	-paraRG "ResourceGroupName" `
	-paraSPName "GitHubActionsDeploy"
```

它會依名稱找到 Service Principal，接著：

1. 移除指定 Resource Group Scope 的 RBAC Role Assignment。
2. 刪除 Service Principal。
3. 刪除對應的 App Registration。

這個 Script 不會刪除 Resource Group 或其中的 Azure Web App，只會清除部署用的身分與權限。

## 執行與部署前置條件

- 已安裝 .NET SDK。
- 已安裝 Azure CLI，並可執行 `az login`。
- Azure Subscription 中已建立 Resource Group。
- Resource Group 中已建立 Azure Web App。
- GitHub Repository 已設定 `AZURE_CREDENTIALS` Secret。
- Workflow 中的 Web App 名稱與 Azure 上的實際名稱一致。

本機執行網站：

```bash
dotnet run
```

## 目前設定的注意事項

- `testazwebappdeploy.csproj` 的 Target Framework 是 `net10.0`。
- Workflow 目前設定的 SDK 是 `8.0.x`，workflow 名稱也寫成 `.NET 8`。正式使用前應讓 SDK 版本與專案 Target Framework 一致。
- Workflow 宣告了 `slot_name` 手動輸入參數，但目前 `azure/webapps-deploy` 沒有傳入 `slot-name`，所以實際上會部署到 production slot。若要部署到 staging，必須確認 Azure Web App 已建立該 slot，並在 deploy step 加入對應設定。
- 若只需要部署一個網站，可以進一步把 Service Principal 的 Scope 評估為單一 Web App，以符合最小權限原則。