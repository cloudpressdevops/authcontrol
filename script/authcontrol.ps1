function Connect-Account
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [uri]$AuthURI = "https://YourAzureFunction.azurewebsites.net/api/authcontrol?code=YourCodeIFNotAnonymous",
        [Parameter(Mandatory)]
        [string]$ApplicationName = "",
        [Parameter(Mandatory)]
        [string]$SubscriptionID = "",
        [Parameter()]
        [pscredential]$Credential = $null
    )

    if($PSVersionTable.PSVersion.Major -gt "5")
    {
        Write-Host "Username + Password authentication is not supported in PowerShell Core" -ForegroundColor Yellow
        Write-Host "Using device code authentication.." -ForegroundColor DarkCyan
        $Credential = $null
    }

    if($Credential -eq $null)
    {
        try
        {
            $AzureADObject = Connect-AzAccount -Subscription $SubscriptionID
            Start-Process "https://microsoft.com/devicelogin"
        }
        catch
        {
            $_
            Break
        }
    }
    else
    {
        try
        {
            $AzureADObject = Connect-AzAccount -Subscription $SubscriptionID -Credential $Credential
        }
        catch
        {
            $_
            Break
        }
    }

    try
    {
        $AzureADAppObject = Get-AzADApplication -DisplayName $ApplicationName -ErrorAction Stop
    }
    catch
    {
        Write-Error "ADApplication $ApplicationName not found!"
        break
    }


    $AuthObject = New-Object PSObject
    Add-Member -InputObject $AuthObject -MemberType NoteProperty -Name ADAccount -Value $AzureADObject.Context.Account.ID -Force
    Add-Member -InputObject $AuthObject -MemberType NoteProperty -Name ADTenantId -Value $AzureADObject.Context.Subscription.TenantId -Force
    Add-Member -InputObject $AuthObject -MemberType NoteProperty -Name ADTenantDomain -Value $AzureADObject.Context.Subscription.Name -Force
    Add-Member -InputObject $AuthObject -MemberType NoteProperty -Name AppDisplayName -Value $ApplicationName -Force
    Add-Member -InputObject $AuthObject -MemberType NoteProperty -Name AppId -Value $AzureADAppObject.ApplicationId -Force
    Add-Member -InputObject $AuthObject -MemberType NoteProperty -Name AppObjectId -Value $AzureADAppObject.ObjectId -Force

    $JSONObject = ConvertTo-Json $AuthObject

    [psobject]$ReturnObject = Invoke-RestMethod -Method POST -UseBasicParsing -Uri $AuthURI -Body $JSONObject -ContentType "application/json"

    return $ReturnObject
}

Connect-Account -SubscriptionID "" -AuthURI ""