$URL ="https://ddcattackfunapp.azurewebsites.net/admin/vfs/site/wwwroot/studentX/function.json"
$Params = @{
"URI" = $URL
"Method" = "PUT"
"Headers" = @{
"Content-Type" = "application/octet-stream"
"x-functions-key" = "d9I2c3XAGVoND_72tJAk0Cbpah7nMlr6HTE4fDNan47sAzFuy5fANg=="
}
}
$Body = @"
{
"bindings": [
{
"authLevel": "anonymous",
"type": "httpTrigger",
"direction": "in",
"name": "Request",
"methods": [
"get",
"post"
]
},
{
"type": "http",
"direction": "out",
"name": "Response"
}
]
}
"@
Invoke-RestMethod @Params -UseBasicParsing -Body $Body