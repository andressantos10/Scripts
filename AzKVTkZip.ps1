#!/usr/bin/env pwsh

Trace-VstsEnteringInvocation $MyInvocation

#Set vars
$targetPath = Get-VstsInput -Name targetPath -Require
$Packages = Get-VstsInput -Name Packages
$fileFilter = Get-VstsInput -Name fileFilter -Require
$tokenPrefix = Get-VstsInput -Name tokenPrefix -Require
$tokenSuffix = Get-VstsInput -Name tokenSuffix -Require
$ReplaceWithEmpty = Get-VstsInput -Name ReplaceWithEmpty -Require
$KeyVaultName = Get-VstsInput -Name KeyVaultName -Require

$tokenPrefixEscape = [Regex]::Escape($tokenPrefix)
$tokenSuffixEscape = [Regex]::Escape($tokenSuffix)
$Regex = "$tokenPrefixEscape(.*?)$tokenSuffixEscape"

Write-Verbose "targetPath = $targetPath" -Verbose
Write-Verbose "Packages = $Packages" -Verbose
Write-Verbose "fileFilter = $fileFilter" -Verbose
Write-Verbose "tokenPrefix = $tokenPrefix" -Verbose
Write-Verbose "tokenSuffix = $tokenSuffix" -Verbose
Write-Verbose "ReplaceWithEmpty = $ReplaceWithEmpty" -Verbose
Write-Verbose "KeyVaultName = $KeyVaultName" -Verbose
Write-Verbose "regex: $regex" -Verbose

#Login Azure
Try {
	Write-Host ""
	Write-Host "Login at Azure DevOps endpoint..."
	Write-Host "=============================================================================="
	Write-Host ""
	Disable-AzContextAutosave -Scope Process | Out-Null
	$serviceNameInput = Get-VstsInput -Name ConnectedServiceNameSelector -Default 'ConnectedServiceName'
	$serviceName = Get-VstsInput -Name $serviceNameInput -Default (Get-VstsInput -Name DeploymentEnvironmentName)
	$vstsEndpoint = Get-VstsEndpoint -Name $serviceName -Require

    $cred = New-Object System.Management.Automation.PSCredential(
        $vstsEndpoint.Auth.Parameters.ServicePrincipalId,
        (ConvertTo-SecureString $vstsEndpoint.Auth.Parameters.ServicePrincipalKey -AsPlainText -Force))

    Login-AzAccount -Credential $cred -ServicePrincipal -TenantId $vstsEndpoint.Auth.Parameters.TenantId -SubscriptionId $vstsEndpoint.Data.SubscriptionId | Out-Null
	Get-AzContext | Format-List
	<#
		Write-Host ".."
		$vstsEndpoint | Format-List
		Write-Host ".."
		$vstsEndpoint.Data | Format-List
		Write-Host ".."
		$vstsEndpoint.Data.appObjectId | Format-List
		Write-Host ".."
		$vstsEndpoint.Auth | Format-List
		Write-Host ".."
		$vstsEndpoint.Auth.Parameters | Format-List
	#>
} Catch [Exception] {
    Write-Host "Authentication error."
	Write-Error ($_.Exception.ToString())
    Write-Host "##vso[task.logissue type=error;]$Error[0]"
    Write-Host "##vso[task.complete result=Failed;]Unintentional failure. Error encountered. Defaulting to always fail." 
} Finally {
	Trace-VstsLeavingInvocation $MyInvocation
	Write-Host ""
	Write-Host "=============================================================================="
	Write-Host ""
}

#Verify Key Vault
Try {
	Write-Host "Key Vault"
	Write-Host "=============================================================================="
	Write-Host ""
	Write-Host "Verifying KeyVault: "$KeyVaultName
	$KeyVault = Get-AzKeyVault -Name $KeyVaultName
	If ($KeyVault) {
		Write-Host "Verifying access policy permission to get secrets..."
		$NumSecrets = (Get-AzKeyVaultSecret -VaultName $KeyVaultName).Count
		Write-Host "     Key Vault $KeyVaultName have $NumSecrets secrets"
		If ($NumSecrets -eq 0){
			Write-Host "     zero secrets listed!"
			Throw
		}
	} Else {
		Write-Host "KeyVault not found or without permission."
	}
} Catch [Exception] {
	Write-Host "Key Vault access error, check the connection and access policies."
    Write-Error ($_.Exception.ToString())
    Write-Host "##vso[task.logissue type=error;]$Error[0]"
    Write-Host "##vso[task.complete result=Failed;]Unintentional failure. Error encountered. Defaulting to always fail." 
} Finally {
	Trace-VstsLeavingInvocation $MyInvocation
	Write-Host ""
	Write-Host "=============================================================================="
	Write-Host ""
}


#Tokenize Files
Try {
	Write-Host "Files"
	Write-Host "=============================================================================="
	Write-Host ""
	$Filters = $fileFilter -Split ","
	ForEach ($Filter in $Filters){
		$Files = (Get-ChildItem -Path $targetPath -Filter $Filter -Recurse).FullName | Sort
		$TotalFiles = $Files.Count
		Write-Host ""
		Write-Host "      Filter: "$Filter" Total files found: "$TotalFiles
		If ($Files){
			ForEach ($File in $Files){
				$FileContent = Get-Content -Path $File
				$Tokens = ($FileContent | Select-String -Pattern $Regex).Matches.Value
				Write-Host ""
				$TotalTokens = $Tokens.Count
				Write-Host "            Tokening file: "$File" Total tokens found: "$TotalTokens
				If ($Tokens) {
					ForEach ($Token in $Tokens){
						$Key = ($Token.Replace($tokenPrefix, "")).Replace($tokenSuffix, "")
						IF ($Key -match "^[a-zA-Z0-9\-]+$") {
							Write-Verbose "                  Quering Secret: $Key" -Verbose
							#$Value = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $Key).SecretValueText
							$Value = ""
							$Secret = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $Key).SecretValue
							If ($Secret) {
								$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
								Try {
									$Value = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
								} Finally {
									[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
								}
							#}
							#If ($Value){
								Write-Host "                  "$Token" found in key vault and replaced!"
								(Get-Content -Path $File -Raw) -IReplace $Token,$Value | Set-Content -Path $File
							} Else {
								If ($ReplaceWithEmpty.ToLowerInvariant() -eq "true") {
									Write-Host "                  "$Token" not was found in key vault, replacing with empty value!"
									(Get-Content -Path $File -Raw) -IReplace $Token,"" | Set-Content -Path $File
								} Else {
									Write-Host "                  "$Token" was not found in key vault!"
								}
							}							
						} Else {
							Write-Host "                  "$Token" has a wrong pattern name to search on key vault, do nothing"
						}
					}
				}
			}
		}
	}
} Catch [Exception] {
    Write-Host "Error reading files"
	Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
    Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
	#Write-Error ($_.Exception.ToString())
    Write-Host "##vso[task.logissue type=error;]$Error[0]"
    Write-Host "##vso[task.complete result=Failed;]Unintentional failure. Error encountered. Defaulting to always fail." 
} Finally {
	Trace-VstsLeavingInvocation $MyInvocation
	Write-Host ""
	Write-Host "=============================================================================="
	Write-Host ""
}

#Tokenize Files inside zip archive
Try {
	Write-Host "Packages"
	Write-Host "=============================================================================="
	Write-Host ""
	If ($Packages){
		Add-Type -assembly "System.IO.Compression.FileSystem"
		$ZipFileNames = (Get-ChildItem -Path $targetPath -Include $Packages -Recurse).FullName | Sort
		Write-Host ""
		$TotalZipFileNames = $ZipFileNames.Count
		Write-Host "Package filter: "$Packages" Total package files: "$TotalZipFileNames
		ForEach ($ZipFileName in $ZipFileNames){
			Write-Host ""
			Write-Host "      Tokening package file: "$ZipFileName
			$ZipFile = [System.IO.Compression.ZipFile]::Open($ZipFileName,'Update') 
			$ZFilters = $fileFilter -Split ","
			ForEach ($ZFilter in $ZFilters){
				$ZipEntries = $ZipFile.Entries | Where-Object {$_.FullName -Like $ZFilter}
				Write-Host ""
				$TotalZipEntries = $ZipEntries.Count
				Write-Host "            Filter: "$ZFilter" Total files found in zip: "$TotalZipEntries
				ForEach ($ZipEntrie in $ZipEntries){
					$ZFile = [System.IO.StreamReader]($ZipEntrie).Open()
					$ZFileContent = $ZFile.ReadToEnd()
					$ZFile.Close()
					$ZFile.Dispose()
					$ZTokens = (Select-String -InputObject $ZFileContent -Pattern $Regex -AllMatches).Matches.Value
					Write-Host ""
					$ZipEntrieFullName = ($ZipEntrie.FullName).Replace("/","\")
					$TotalZTokens = $ZTokens.Count
					Write-Host "                  File: "$ZipEntrieFullName" Total tokens found: "$TotalZTokens
					ForEach ($ZToken in $ZTokens){
						$ZKey = ($ZToken.Replace($tokenPrefix, "")).Replace($tokenSuffix, "")
						IF ($ZKey -match "^[a-zA-Z0-9\-]+$") {
							Write-Verbose "                  Quering Secret: $ZKey" -Verbose
							#$ZValue = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ZKey).SecretValueText
							$ZValue = ""
							$ZSecret = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $ZKey).SecretValue
							If ($ZSecret) {
								$ZssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ZSecret)
								Try {
									$ZValue = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ZssPtr)
								} Finally {
									[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ZssPtr)
								}
							#}
							#If ($ZValue){
								Write-Host "                        "$ZToken" found in key vault and replaced!"
								$WZFile = [System.IO.StreamWriter]($ZipEntrie).Open()
								$ZFileContent = $ZFileContent -IReplace $ZToken,$ZValue
								$WZFile.BaseStream.SetLength(0)
								$WZFile.Write($ZFileContent)
								$WZFile.Flush()
								$WZFile.Close()
							} Else {
								If ($ReplaceWithEmpty.ToLowerInvariant() -eq "true") {
									Write-Host "                        "$ZToken" was not found in key vault, replacing with empty value!"
									$WZFile = [System.IO.StreamWriter]($ZipEntrie).Open()
									$ZFileContent = $ZFileContent -IReplace $ZToken,""
									$WZFile.BaseStream.SetLength(0)
									$WZFile.Write($ZFileContent)
									$WZFile.Flush()
									$WZFile.Close()
								} Else {
									Write-Host "                        "$ZToken" was not found in key vault!"
								}
							}
						} Else {
							Write-Host "                  "$ZToken" has a wrong pattern name to search on key vault, do nothing"
						}
					}
				} 
			}
			$ZipFile.Dispose()
		}
	}
} Catch [Exception] {
    Write-Host "Error reading zip package."
	Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
    Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
	#Write-Error ($_.Exception.ToString())
    Write-Host "##vso[task.logissue type=error;]$Error[0]"
    Write-Host "##vso[task.complete result=Failed;]Unintentional failure. Error encountered. Defaulting to always fail." 
} Finally {
	Trace-VstsLeavingInvocation $MyInvocation
	Write-Host ""
	Write-Host "=============================================================================="
	Write-Host ""
}
