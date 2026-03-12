# Azure Functions profile - runs once when the function worker starts.
# Authenticate to Azure services via Managed Identity when running in Azure.

if ($env:MSI_SECRET) {
    Connect-AzAccount -Identity | Out-Null
    Write-Host 'Authenticated via Managed Identity'
}
