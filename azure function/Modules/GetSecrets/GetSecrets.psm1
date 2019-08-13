function Get-Secrets([string]$accessToken,[string]$vaultName,[string]$secretName)
{
    $headers= @{'Authorization'="Bearer $accessToken"}
    $queryUrl="https://$vaultName.vault.azure.net/secrets/$secretName"+'?api-version=2016-10-01'
    $keyResponse= Invoke-RestMethod -Method GET -Uri $queryUrl -Headers $headers

    return $keyResponse.value
}

Export-ModuleMember -Function Get-Secrets