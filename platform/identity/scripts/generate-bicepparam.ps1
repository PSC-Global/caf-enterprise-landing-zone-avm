$mappingPath = Join-Path $PSScriptRoot "../config/aad-group-mapping.json"
$mapping = Get-Content $mappingPath | ConvertFrom-Json

$bicepParamPath = Join-Path $PSScriptRoot "../bicep/aad-group-ids.bicepparam"
$jsonParamPath = Join-Path $PSScriptRoot "../bicep/aad-group-ids.json"

# Generate .bicepparam file
"using './role-assignments-subscription.bicep'" | Out-File $bicepParamPath -Encoding utf8
"" | Out-File $bicepParamPath -Append -Encoding utf8
"param aadGroupIds = {" | Out-File $bicepParamPath -Append -Encoding utf8

foreach ($prop in $mapping.PSObject.Properties) {
    $key = $prop.Name
    $value = $prop.Value
    "  '${key}': '$value'" | Out-File $bicepParamPath -Append -Encoding utf8
}

"}" | Out-File $bicepParamPath -Append -Encoding utf8

# Generate .json file for Azure CLI (just the value object)
$mapping | ConvertTo-Json -Depth 10 | Out-File $jsonParamPath -Encoding utf8

Write-Host "Generated: $bicepParamPath"
Write-Host "Generated: $jsonParamPath"
