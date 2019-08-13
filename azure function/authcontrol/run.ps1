using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$ADAccount = $Request.Query.ADAccount
if (-not $ADAccount) { $ADAccount = $Request.Body.ADAccount }

$ADTenantId = $Request.Query.ADTenantId
if (-not $ADTenantId) { $ADTenantId = $Request.Body.ADTenantId }

$ADTenantDomain = $Request.Query.ADTenantDomain
if (-not $ADTenantDomain) { $ADTenantDomain = $Request.Body.ADTenantDomain }

$AppDisplayName = $Request.Query.AppDisplayName
if (-not $AppDisplayName) { $AppDisplayName = $Request.Body.AppDisplayName }

$AppId = $Request.Query.AppId
if (-not $AppId) { $AppId = $Request.Body.AppId }

$AppObjectId = $Request.Query.AppObjectId
if (-not $AppObjectId) { $AppObjectId = $Request.Body.AppObjectId }

if($ADAccount -and $ADTenantId -and $ADTenantDomain -and $AppDisplayName -and $AppId -and $AppObjectId)
{
    if($env:AZURE_FUNCTIONS_ENVIRONMENT -eq "Development")
    {
        $Credential = New-Object PSCredential -ArgumentList $env:ApplicationID, (ConvertTo-SecureString -String $env:ClientSecret -AsPlainText -Force)
        $TenantID = $env:TenantID
    }
    else
    {
        $apiVersion = "2017-09-01"
        $resourceURI = "https://vault.azure.net"
        $tokenAuthURI = $env:MSI_ENDPOINT + "?resource=$resourceURI&api-version=$apiVersion"

        $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Secret"="$env:MSI_SECRET"} -Uri $tokenAuthURI
        $accessToken = $tokenResponse.access_token

        $userName = Get-Secrets -accessToken $accessToken -vaultName $env:vaultname -secretName $env:AppID_SecretName
        $password= Get-Secrets -accessToken $accessToken -vaultName $env:vaultname -secretName $env:AppClientSecret_SecretName

        $Credential = New-Object -TypeName PSCredential -ArgumentList ($userName ,(ConvertTo-SecureString -String $password -AsPlainText -Force))
        $TenantID = (Get-AzContext).Tenant.Id
    }

    $Acc = Connect-AzAccount -Tenant $TenantID -Credential $Credential -ServicePrincipal

    If(!($ADUserObject = Get-AzADuser -UserPrincipalName $ADAccount -ErrorAction SilentlyContinue))
    {
        $ExternalUser = -join($ADAccount.Replace("@","_"),"#EXT#")
        If(!($ADUserObject = Get-AzADuser -UserPrincipalName $ExternalUser -ErrorAction SilentlyContinue))
        {
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::NotFound
                Body = "Cant find User $($ADAccount)"
            })
            exit
        }
    }

    $Context = (Get-AzStorageAccount -ResourceGroupName $env:ResourceGroupName -Name $env:StorageAccountname).Context
    $Table = (Get-AzStorageTable -name $env:StorageTableName -Context $Context).CloudTable

    if($UserObj = Get-AzTableRow -Table $Table -ColumnName "RowKey" -Value $ADUserObject.Id -Operator Equal -ErrorAction SilentlyContinue)
    {
        if($ADAccount -eq $UserObj.UserPrincipalName -and $ADTenantId -eq $UserObj.TenantID -and $ADTenantDomain -eq $UserObj.SubscriptionName -and $AppDisplayName -eq $UserObj.ApplicationName -and $AppId -eq $UserObj.ApplicationID -and $AppObjectId -eq $UserObj.ObjectID)
        {
            $status = [HttpStatusCode]::OK
            $body = "Login successful."
        }
        else
        {
            $status = [HttpStatusCode]::Forbidden
            $body = "Permission denied."
        }
    }
    else
    {
        $status = [HttpStatusCode]::NotFound
        $body = "Cant find User $($ADAccount)"
    }
}
else {
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass ADAccount, ADTenantId, ADTenantDomain, AppDisplayName, AppID and AppObjectId on the query string or in the request body."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})
