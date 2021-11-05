$BuildRepositoryName = "$(Build.Repository.Name)"
$SonarCloudToken = (Get-AzKeyVaultSecret -VaultName "dev-keyvault-conectcar" -Name "SonarCloudToken").SecretValueText
$SonarCloudDevOpsToken = (Get-AzKeyVaultSecret -VaultName "dev-keyvault-conectcar" -Name "SonarCloudDevOpsToken").SecretValueText
$Org = (Get-AzKeyVaultSecret -VaultName "dev-keyvault-conectcar" -Name "SonarCloudOrgKey").SecretValueText

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Token = [System.Text.Encoding]::UTF8.GetBytes($SonarCloudToken + ":")
$Base64 = [System.Convert]::ToBase64String($Token)
$BasicAuth = [string]::Format("Basic {0}", $Base64)
$Headers = @{ Authorization = $BasicAuth }

#Set PR Integration

$PRURL = "https://sonarcloud.io/api/settings/set?"
$PRParam = "key=sonar.pullrequest.provider&value=Azure%20DevOps%20Services&component="
$PRParam2 = "key=sonar.pullrequest.vsts.token.secured&value=" + $SonarCloudDevOpsToken + "&component="

$PRURI = $PRURL + $PRParam + $BuildRepositoryName
$PRURI2 = $PRURL + $PRParam2 + $BuildRepositoryName

Invoke-RestMethod -Method Post -Uri $PRURI -Headers $Headers
Invoke-RestMethod -Method Post -Uri $PRURI2 -Headers $Headers

#Set Group

$Group = ("$(System.TeamProject)").Replace(" ","%20")
$GRURL2 = "https://sonarcloud.io/api/permissions/add_group?"
$GRParam = "groupName=" + $Group + "&organization=" + $Org + "&permission=user" + "&projectKey=" + $BuildRepositoryName
$GRParam2 = "groupName=" + $Group + "&organization=" + $Org + "&permission=codeviewer" + "&projectKey=" + $BuildRepositoryName
$GRParam3 = "groupName=" + $Group + "&organization=" + $Org + "&permission=issueadmin" + "&projectKey=" + $BuildRepositoryName
$GRParam4 = "groupName=" + $Group + "&organization=" + $Org + "&permission=securityhotspotadmin" + "&projectKey=" + $BuildRepositoryName

$GRURI = $GRURL2 + $GRParam
$GRURI2 = $GRURL2 + $GRParam2
$GRURI3 = $GRURL2 + $GRParam3
$GRURI4 = $GRURL2 + $GRParam4

Invoke-RestMethod -Method Post -Uri $GRURI -Headers $Headers
Invoke-RestMethod -Method Post -Uri $GRURI2 -Headers $Headers
Invoke-RestMethod -Method Post -Uri $GRURI3 -Headers $Headers
Invoke-RestMethod -Method Post -Uri $GRURI4 -Headers $Headers