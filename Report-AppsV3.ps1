$ProgressPreference = "SilentlyContinue"

#Modules
Import-Module VSTeam
Import-Module AZ

#Login
Set-VSTeamAccount -Account https://dev.azure.com/conectcar/ -PersonalAccessToken "p736cytxz7jnxl6gkzj35zhkeqwn3x2m2tx6yuo4ttrthaijd2na"
#az login
Login-AzAccount

#Sonar Token
$SonarCloudToken = "0150c98e6157d606a435da7f98d0145999b70573"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$SonarToken = [System.Text.Encoding]::UTF8.GetBytes($SonarCloudToken + ":")
$SonarBase64 = [System.Convert]::ToBase64String($SonarToken)
$SonarBasicAuth = [string]::Format("Basic {0}", $SonarBase64)
$SonarHeaders = @{ Authorization = $SonarBasicAuth }
$SonarOrg = "87e2ff301ed9e261a13204d8d402dd7286462f13"
$SonarProjectAnalisesURL = "https://sonarcloud.io/api/measures/component?component={0}&branch={1}&metricKeys=alert_status"

#Log File
$FileName = ".\Report-Apps.csv"
If (Test-Path $FileName) {Remove-Item $FileName}
Add-Content -Path $FileName -Value "AppPrefiz;AppSufiz;Subscription;Resorce Group;ServicePlan;Name;URL;State;Deployed at;Project;Repo;Branch;Build Definition;Release Definition;Release;Sonar Build Definition;Sonar Release Definition;Sonar Release;Sonar Status"

($Subscriptions = Get-AzSubscription | Sort Name) | Out-Null

Write-Host ""
Write-Host ""

Foreach ($Subscription in $Subscriptions){
	#Select Sub
	Write-Host ""
	Get-Date | Write-Host
	Write-Host "Reading Subscription " $Subscription.Name
	Select-AzSubscription $Subscription.Id | Out-Null

	Write-Host ""
		
	$Apps = Get-AzWebapp | Sort Name
	Foreach ($App in $Apps){
		Write-Host "." -NoNewline
		
		# Build Token with current Azure Context
		$azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
		$azureRmContext = Get-AzContext
		$profileClient  = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azureRmProfile)
		$accessToken    = $profileClient.AcquireAccessToken($azureRmContext.Subscription.TenantId).AccessToken
		$Headers = @{
			"Content-Type" = "application/json"
			"Authorization" = "Bearer $accessToken"
		}
		
		#Endpoint
		$RestAPIendpoint = "https://management.azure.com/subscriptions/" + $Subscription.Id + "/resourceGroups/" + $App.ResourceGroup + "/providers/Microsoft.Web/sites/" + $App.Name + "/deployments?api-version=2019-08-01"
		
		#Deploy Info from Azure
		Try {
			$DeployInfo = ((Invoke-RestMethod -Method "GET" -Uri $RestAPIendpoint -Headers $Headers).Value | Select -First 1).Properties
		} Catch {
			$DeployInfo = $Null
		}
		
		$DeployDate = ""
		$ProjectName = ""
		$BuildDefName = ""
		$RepoName = ""
		$BranchDeployed = ""
		$ReleaseDefName = ""
		$SonarBuildDef = ""
		$SonarRelease = ""
		$ReleaseName = ""
		$SonarReleaseDef = ""
		
		If ($DeployInfo) {
			#Date from Azure
			$DeployDate = Get-Date($DeployInfo.end_time)
			$DeployDate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($DeployDate, [System.TimeZoneInfo]::Local.Id)
			$DeployDate = $DeployDate.tostring("dd/MM/yyyy")

			#Project
			Try {
				$DeployInfo = $DeployInfo.Message | ConvertFrom-Json
				$ProjectName = (Get-VSTeamProject -Id $DeployInfo.teamProject).Name
			} Catch {
				$ProjectName = ""
			}
			
			#Release
			Try {
				$Release = Get-VSTeamRelease -ProjectName $ProjectName -id $DeployInfo.releaseId -Raw -WarningAction:SilentlyContinue
				$Artefact = $Release.artifacts | Where type -eq "Build"
				$ReleaseDefName = $Release.releaseDefinition.name
				$BuildDefName = $Artefact.definitionReference.definition.name
				$BranchDeployed = $Artefact.definitionReference.branch.name
				$RepoName = $Artefact.definitionReference.repository.name
				$ReleaseName = $Release.name
				
			} Catch {
				$ReleaseDefName = ""
				$BuildDefName = ""
				$RepoName = ""
				$BranchDeployed = ""
				$ReleaseName = ""
			}
			
			#Sonar Build Definition
			Try {
				#Sonar Build
				$BuildDefId = $Artefact.definitionReference.definition.id
				$BuildDefJson = Get-VSTeamBuildDefinition -ProjectName $ProjectName -id $BuildDefId -JSON -WarningAction:SilentlyContinue
				If ($BuildDefJson | %{$_ -match "SonarCloud"}) {$SonarBuildDef = "Yes"} Else {$SonarBuildDef = "No"}
			} Catch {
				$SonarBuildDef = ""
			}
			
			#Sonar Gate Release Definition
			Try {
				$ReleaseDefId = $Release.releaseDefinition.id
				$SonarGateReleaseDef = ((Get-VSTeamReleaseDefinition -ProjectName $ProjectName -Id $ReleaseDefId -raw -WarningAction:SilentlyContinue).environments | Where name -eq "hmg").postDeploymentGates.gates.tasks | where name -like "*Sonar*" | select -First 1
				If ($SonarGateReleaseDef) {$SonarReleaseDef = "Yes"} Else {$SonarReleaseDef = "No"}
			}  Catch {
				$SonarReleaseDef = ""
			}
			
			#Sonar Gate Release
			Try {
				$ReleaseSonar = ($Release.environments | Where name -eq "hmg").deploysteps.postDeploymentGates.deploymentJobs.tasks | where name -like "*Sonar*" | select -First 1
				If ($ReleaseSonar) {$SonarRelease = "Yes"} Else {$SonarRelease = "Not"}
			} Catch {
				$SonarRelease = ""
			}
		}
		
		# Env
		$LowerName = ($App.Name).ToLower()
		Switch -Wildcard ($LowerName) {
			"dev-*" {
				$AppPrefiz = "dev-"
				$AppSufiz = $LowerName.Replace("dev-","")}
			"qa-*" {
				$AppPrefiz = "qa-"
				$AppSufiz = $LowerName.Replace("qa-","")}
			"hmg-*" {
				$AppPrefiz = "hmg-"
				$AppSufiz = $LowerName.Replace("hmg-","")}
			"prd-*" {
				$AppPrefiz = "prd-"
				$AppSufiz = $LowerName.Replace("prd-","")}
			"dr-*" {
				$AppPrefiz = "dr-"
				$AppSufiz = $LowerName.Replace("dr-","")}
			Default {
				$AppPrefiz=""
				$AppSufiz = ""}
		}
		
		$AppServicePlan = $App.ServerFarmId -split '/' | Select-Object -Last 1
		
		#Sonar Gate
		Try {
			$SonarRepo = [uri]::EscapeDataString($RepoName)
			$SonarBranch = [uri]::EscapeDataString(($BranchDeployed).Replace("refs/heads/",""))
			$SonarVerifyProjectAnalisesURL = $SonarProjectAnalisesURL -f $SonarRepo, $SonarBranch
			$SonarGetProjectAnalises = Invoke-RestMethod -Method Get -Uri $SonarVerifyProjectAnalisesURL -Headers $SonarHeaders
			If ($SonarGetProjectAnalises.component.measures.value -eq "OK") {$SonarStatus = "PASS"} Else {$SonarStatus = "FAIL"}
		} Catch {$SonarStatus = ""}
		
		#			"AppPrefix;        AppSufiz;         Subscription;              Resorce Group;              ServicePlan;            Name;             URL;                                                                   State;             Deployed at;        Project;             Repo;             Branch;                 Build Definition;     Release Definition;     Release;             Sonar Build Definition; Sonar Release Definition; Sonar Release;      Sonar Status"
		$CSVLine =  $AppPrefiz + ";" + $AppSufiz + ";" + $Subscription.Name + ";" + $App.ResourceGroup + ";" +  $AppServicePlan + ";" + $App.Name + ";" + (($App.HostNames).Replace("{",[char]34)).Replace("}",[char]34) + ";" + $App.State + ";" + $DeployDate + ";" + $ProjectName + ";" + $RepoName + ";" + $BranchDeployed + ";" + $BuildDefName + ";" + $ReleaseDefName + ";" + $ReleaseName + ";" + $SonarBuildDef + ";" + $SonarReleaseDef + ";" + $SonarRelease + ";" + $SonarStatus
		Add-Content -Path $FileName -Value $CSVLine
	}
Write-Host ""
}

#Sort CSV
$TempFileName = ".\Temp-Report-Apps.csv"
Rename-Item $FileName $TempFileName
Import-Csv $TempFileName -Delimiter ";" | Sort AppSufiz,AppPrefiz | Export-Csv -Delimiter ";" -NoTypeInformation -Path $FileName
Remove-Item $TempFileName

Write-Host "Finished"
Get-Date | Write-Host