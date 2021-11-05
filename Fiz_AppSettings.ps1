#ConectCar Build .Net Core with SonarCloud V2
#Task PowerShell Script Fix appsettings.json
$Files = Get-ChildItem -Recurse
Foreach ($File in $Files){
	If ($File.Name -eq "appsettings.json") {
		Write-Host $File.FullName" removed"
		Remove-Item $File.FullName -Force
	}
	If ($File.Name -eq "appsettings.Development.json") {
		Write-Host $File.FullName" removed"
		Remove-Item $File.FullName -Force
	}
	If ($File.Name -eq "appsettings.Release.json") {
		Write-Host $File.FullName" renamed to appsettings.json"
		Rename-Item -Path $File.FullName -NewName "appsettings.json" -Force
	}
}
