Import-Module Az
#Login-AzAccount
az login

$FileName = ".\Report-EnvApps.csv"
If (Test-Path $FileName) {Remove-Item $FileName}
Add-Content -Path $FileName -Value "DEV;QA;HMG;PRD"

Write-Host "Load Enviromment Arrays"

#Load DEV Array
Select-AzSubscription f009812d-0fd6-4064-812e-ad76471d0082
[System.Collections.ArrayList]$DEVApps = (Get-AzWebApp).Name | Sort

#Load QA Array
Select-AzSubscription bd425708-5a91-4201-a542-241b342057c0
[System.Collections.ArrayList]$QAApps = (Get-AzWebApp).Name | Sort

#Load HMG Array
Select-AzSubscription a7f9f071-82d9-48ce-84df-aee91d89c5d2
[System.Collections.ArrayList]$HMGApps = (Get-AzWebApp).Name | Sort

#Load PRD Array
Select-AzSubscription 460adbb0-e76f-4b92-ab5a-b823bba3251f
[System.Collections.ArrayList]$PRDApps = (Get-AzWebApp).Name | Sort

Write-Host "Start processing report"
Write-Host "Processing dev"

Foreach ($DEVApp in $DEVApps) {
	If ($DEVApp -like "dev-*") {
		
		$Search = $DEVApp.Replace("dev-", "*")
		$QAApp = $QAApps | Where-Object { $_ -like $Search }
		$HMGApp = $HMGApps | Where-Object { $_ -like $Search }
		$PRDApp = $PRDApps | Where-Object { $_ -like $Search }
		
		$Line = $DEVApp + ";" + $QAApp + ";" + $HMGApp + ";" + $PRDApp
		Add-Content -Path $FileName -Value $Line
		
		If($QAApp) {$QAApps.Remove($QAApp)}
		If($HMGApp) {$HMGApps.Remove($HMGApp)}
		If($PRDApp) {$PRDApps.Remove($PRDApp)}
		Write-Host "." -NoNewLine
		
	} Else {
		$Line = $DEVApp + ";;;"
		Add-Content -Path $FileName -Value $Line
		Write-Host "." -NoNewLine
	}
}

Write-Host ""
Write-Host "Processing qa"

$QAApp = ""
Foreach ($QAApp in $QAApps) {
	If ($QAApp -like "qa-*") {
		
		$Search = $QAApp.Replace("qa-", "*")
		$HMGApp = $HMGApps | Where-Object { $_ -like $Search }
		$PRDApp = $PRDApps | Where-Object { $_ -like $Search }
		
		$Line = ";" + $QAApp + ";" + $HMGApp + ";" + $PRDApp
		Add-Content -Path $FileName -Value $Line
		
		If($HMGApp) {$HMGApps.Remove($HMGApp)}
		If($PRDApp) {$PRDApps.Remove($PRDApp)}
		Write-Host "." -NoNewLine
		
	} Else {
		$Line = ";" + $QAApp + ";;"
		Add-Content -Path $FileName -Value $Line
		Write-Host "." -NoNewLine
	}
}

Write-Host ""
Write-Host "Processing hmg"

$HMGApp = ""
Foreach ($HMGApp in $HMGApps) {
	If ($HMGApp -like "hmg-*") {
		
		$Search = $HMGApp.Replace("hmg-", "*")
		$PRDApp = $PRDApps | Where-Object { $_ -like $Search }
		
		$Line = ";;" + $HMGApp + ";" + $PRDApp
		Add-Content -Path $FileName -Value $Line
		
		If($PRDApp) {$PRDApps.Remove($PRDApp)}
		Write-Host "." -NoNewLine
		
	} Else {
		$Line = ";;" + $HMGApp + ";"
		Add-Content -Path $FileName -Value $Line
		Write-Host "." -NoNewLine
	}
}

Write-Host ""
Write-Host "Processing prd"

$PRDApp = ""
Foreach ($PRDApp in $PRDApps) {
	$Line = ";;;" + $PRDApp
	Add-Content -Path $FileName -Value $Line
	Write-Host "." -NoNewLine
}
