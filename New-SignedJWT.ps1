function New-SignedJWT(){
$DataAnalyticsAppID = 'f23a808b-6a01-4fb2-bfd9-bdb3e8390421'
$audience = 'https://login.microsoftonline.com/d6bd5a42-7c65-421c-ad23-a25a5d5fa57f/oauth2/token'

# JWT request should be valid for max 2 minutes.
$StartDate             = (Get-Date "1970-01-01T00:00:00Z" ).ToUniversalTime()
$JWTExpirationTimeSpan = (New-TimeSpan -Start $StartDate -End (Get-Date).ToUniversalTime().AddMinutes(2)).TotalSeconds
$JWTExpiration         = [math]::Round($JWTExpirationTimeSpan,0)

# Create a NotBefore timestamp. 
$NotBeforeExpirationTimeSpan = (New-TimeSpan -Start $StartDate -End ((Get-Date).ToUniversalTime())).TotalSeconds
$NotBefore                   = [math]::Round($NotBeforeExpirationTimeSpan,0)

# Create JWT header
$jwtHeader = @{
    'alg' = "RS256"              # Use RSA encryption and SHA256 as hashing algorithm
    'typ' = "JWT"                # We want a JWT
    'x5t' = $AKVCertificate.x5t[0]  # The pubkey hash we received from Azure Key Vault
}

# Create the payload
$jwtPayLoad = @{
    'aud' = $audience           # Points to oauth token request endpoint for your tenant
    'exp' = $JWTExpiration      # Expiration of JWT request
    'iss' = $DataAnalyticsAppID    # The AppID for which we request a token for
    'jti' = [guid]::NewGuid()   # Random GUID
    'nbf' = $NotBefore          # This should not be used before this timestamp
    'sub' = $DataAnalyticsAppID    # Subject
}

# Convert header and payload to json and to base64
$jwtHeaderBytes  = [System.Text.Encoding]::UTF8.GetBytes(($jwtHeader | ConvertTo-Json))
$jwtPayloadBytes = [System.Text.Encoding]::UTF8.GetBytes(($jwtPayLoad | ConvertTo-Json))
$b64JwtHeader    = [System.Convert]::ToBase64String($jwtHeaderBytes)
$b64JwtPayload   = [System.Convert]::ToBase64String($jwtPayloadBytes)

# Concat header and payload to create an unsigned JWT and compute a Sha256 hash
$unsignedJwt      = $b64JwtHeader + "." + $b64JwtPayload
$unsignedJwtBytes = [System.Text.Encoding]::UTF8.GetBytes($unsignedJwt)
$hasher           = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
$jwtSha256Hash    = $hasher.ComputeHash($unsignedJwtBytes)
$jwtSha256HashB64 = [Convert]::ToBase64String($jwtSha256Hash) -replace '\+','-' -replace '/','_' -replace '='

# Sign the sha256 of the unsigned JWT using the certificate in Azure Key Vault
$uri      = "$($AKVCertificate.kid)/sign?api-version=7.3"
$headers  = @{
    'Authorization' = "Bearer $GISAppKeyVaultToken"
    'Content-Type' = 'application/json'
}
$response = Invoke-RestMethod -Uri $uri -UseBasicParsing -Method POST -Headers $headers -Body (([ordered] @{
    'alg'   = 'RS256'
    'value' = $jwtSha256HashB64
}) | ConvertTo-Json)
$signature = $response.value

# Concat the signature to the unsigned JWT
$signedJWT = $unsignedJwt + "." + $signature

return $signedJWT

}