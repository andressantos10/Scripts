Import-Module VSTeam
Set-VSTeamAccount -Account https://dev.azure.com/conectcar/ -PersonalAccessToken "lv2virnbkgiwkhxcqdfjd6med3nunn5nf4zrcaazd3m2ardj52sq"
#

$FileName = ".\Report-Build-SonarCloud.csv"
If (Test-Path $FileName) {Remove-Item $FileName}

Add-Content -Path $FileName -Value "Project;Repo;Type;Build Definition;Release Definitions for this Build Def;Task Group;SonarQube Legancy;Prepare Analysis;Run Analysis;Publish Quality;Pull Request Integration;Sonar Gate;SSDT;Created/Updated;Last Run;Status;Run By"

#$Projects = (Get-VSTeamProject | Where-Object {$_.Name -ne "ALM"} | Sort-Object).Name
$Projects = (Get-VSTeamProject | Sort-Object).Name
Foreach ($Project IN $Projects){
	
	Write-Host "Reading " $Project
	$BuildDefs = Get-VSTeamBuildDefinition -ProjectName $Project -ErrorAction SilentlyContinue | Sort-Object Name
	
	Foreach ($BuildDef IN $BuildDefs) {
		
		$QB = "-"
		$TG = "-"
		$PA = "-"
		$RA = "-"
		$PQ = "-"
		$PR = "-"
		$SD = "-"
		$SG = "-"
		
		$Def = Get-VSTeamBuildDefinition -ProjectName $Project -Id $BuildDef.Id -Json -ErrorAction SilentlyContinue
		If ($Def | %{$_ -match "yamlFilename"}) {
			$Type = "Yaml"
		} Else {
			$Type = "Classic"
		}
		
		If (($Def | %{$_ -match "SSDT"}) -or ($Def | %{$_ -match "sqlproj"})) {
			$SD = "Ok"
			If ($Def | %{$_ -match "Task group: SSDT build"}) {$TG = "SSDT Build (Old)"}
			If ($Def | %{$_ -match "Task group: ConectCar SSDT build"}) {$TG = "ConectCar SSDT build (Old)"}
		} Else {
			If ($Def | %{$_ -match "SonarQube"}) {$QB = "Ok"}
			If ($Def | %{$_ -match "Prepare analysis on SonarCloud"}) {$PA = "Ok"}
			If ($Def | %{$_ -match "Run Code Analysis"}) {$RA = "Ok"}
			If ($Def | %{$_ -match "Publish Quality Gate Result"}) {$PQ = "Ok"}
			If ($Def | %{$_ -match "Set up SonarCloud pull request integration"}) {$PR = "Ok"}
			
			If ($Def | %{$_ -match "Task group:"}) {$TG = "Custom task group (Old)"}
						
			If ($Def | %{$_ -match "ConectCar Build .Net Core"}) {
				$QB = "Ok"
				$TG = "ConectCar Build .Net Core (Old)"
			}
			If ($Def | %{$_ -match "Task group: ConectCar VS Build .Net Full"}) {
				$QB = "Ok"
				$TG = "Task group: ConectCar VS Build .Net Full (Old)"
			}
			# ConectCar Build .Net Core with SonarCloud
			If ($Def | %{$_ -match "ConectCar Build .Net Core with SonarCloud"}) {
				$QB = "-"
				$TG = "ConectCar Build .Net Core with SonarCloud"
				$PA = "Ok"
				$RA = "Ok"
				$PQ = "Ok"
				$PR = "Ok"
			}
			# ConectCar Build .Net Full with SonarCloud
			If ($Def | %{$_ -match "ConectCar Build .Net Full with SonarCloud"}) {
				$QB = "-"
				$TG = "ConectCar Build .Net Full with SonarCloud"
				$PA = "Ok"
				$RA = "Ok"
				$PQ = "Ok"
				$PR = "Ok"			
			}
			# ConectCar Build NPM with SonarCloud
			If ($Def | %{$_ -match "ConectCar Build NPM with SonarCloud"}) {
				$QB = "-"
				$TG = "ConectCar Build NPM with SonarCloud"
				$PA = "Ok"
				$RA = "Ok"
				$PQ = "Ok"
				$PR = "Ok"			
			}
		}
		
		
		$RawBuildDef = Get-VSTeamBuildDefinition -ProjectName $Project -Id $BuildDef.Id -Raw -ErrorAction SilentlyContinue
		$DDate = Get-Date($RawBuildDef.createdDate)
		$DDate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($DDate, [System.TimeZoneInfo]::Local.Id)
		$DDate = $DDate.tostring("dd/MM/yyyy")
		$Build = Get-VSTeamBuild -ProjectName $Project -Definitions $RawBuildDef.Id -Top 1
		IF ($Build.startTime) {
			$BDate = Get-Date($Build.startTime)
			$BDate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($BDate, [System.TimeZoneInfo]::Local.Id)
			$BDate = $BDate.tostring("dd/MM/yyyy")
		} Else {$BDate = ""}
		$BResult = $Build.result
		$RunBy = $Build.requestedBy.displayName + " " + $Build.RequestedBy.UniqueName
		
		$ArtefactId = $RawBuildDef.project.id + ":" + $BuildDef.Id
		$RelDef = (Get-VSTeamReleaseDefinition -ProjectName $Project -Expand Artifacts | Where-Object Artifacts -Match $ArtefactId) #.Name
		$RelDefNames = $RelDef.Name -Join " / " 
		
		# Sonar Gate
		If ($RelDef.Count -eq 0) {$SG = "-"}
		If ($RelDef.Count -ge 2) {$SG = "N Releses"}
		If ($RelDef.Count -eq 1) {
			$ReleaseId = $RelDef.Id
			$ReleaseJson = ((Get-VSTeamReleaseDefinition -ProjectName $Project -Id $ReleaseId -raw).environments | Where name -eq "hmg").postDeploymentGates.gates | ConvertTo-Json
			If ($ReleaseJson | %{$_ -match "SonarCloud"}) {$SG = "Ok"} Else {$SG = "Not"}
		}  
		
		#"Project;Repo;Type;Build Definition;Release Definitions for this Build Def;Task Group;SonarQube Legancy;Prepare Analysis;Run Analysis;Publish Quality;Pull Request Integration;Sonar Gate;SSDT;Created/Updated;Last Run;Status;Run By"
		$Line = $Project + ";" + $RawBuildDef.Repository.Name + ";" + $Type + ";" + $RawBuildDef.Name + ";" + $RelDefNames + ";" + $TG + ";" + $QB + ";" + $PA + ";" + $RA + ";" + $PQ + ";" + $PR + ";" + $SG + ";" + $SD + ";" + $DDate + ";" + $BDate + ";" + $BResult + ";" + $RunBy
		Add-Content -Path $FileName -Value $Line
	}
}