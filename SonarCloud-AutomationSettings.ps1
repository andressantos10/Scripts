#V2.4
# Get Tokens in KeyVault
Write-Host ""
Write-Host "=============================================================================="
Write-Host "Setup SonarCloud Script"
Write-Host "=============================================================================="
Write-Host ""
Write-Host "Getting Tokens in KeyVault"
$KeyVault = "dev-keyvault-conectcar"
$SonarCloudToken = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name "SonarCloudToken").SecretValueText
$SonarCloudDevOpsToken = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name "SonarCloudDevOpsToken").SecretValueText
$Org = (Get-AzKeyVaultSecret -VaultName $KeyVault -Name "SonarCloudOrgKey").SecretValueText
Write-Host "		KeyVaut: "$KeyVault" done!"

# Authenticate to SonarCloud
Write-Host ""
Write-Host "Authenticate in SonarCloud"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Token = [System.Text.Encoding]::UTF8.GetBytes($SonarCloudToken + ":")
$Base64 = [System.Convert]::ToBase64String($Token)
$BasicAuth = [string]::Format("Basic {0}", $Base64)
$Headers = @{ Authorization = $BasicAuth }

$ProjectsURL = "https://sonarcloud.io/api/projects/search?organization={0}&ps=10"
$ProjectsURLGet = $ProjectsURL -f $Org
Try {	
	$GetProjects = Invoke-RestMethod -Method Get -Uri $ProjectsURLGet -Headers $Headers
	Write-Host "		Token: valid!"
	Write-Host "		Total of projects found: "$GetProjects.paging.total
} catch { Write-Error "		Token: invalid!" }

# Get Repository
$BuildRepositoryNameURL = [uri]::EscapeDataString($Env:Build_Repository_Name)
$BuildRepositoryNameDisplay = $Env:Build_Repository_Name

# Create Project
Write-Host ""
Write-Host "Create Project"
$ProjectURL = "https://sonarcloud.io/api/projects/search?organization={0}&projects={1}"
$VerifyProjectURL = $ProjectURL -f $Org, $BuildRepositoryNameURL
Try {
	$GetProject = Invoke-RestMethod -Method Get -Uri $VerifyProjectURL -Headers $Headers
	If ($GetProject.components.key) {
		Write-Host "		Project: "$BuildRepositoryNameDisplay" already exists!"
	} Else {
		$CreateProjectURL = "https://sonarcloud.io/api/projects/create?organization={0}&project={1}&name={2}&visibility=private"
		$CreateProjectURLPost = $CreateProjectURL -f $Org, $BuildRepositoryNameURL, $BuildRepositoryNameURL
		$Post = Invoke-RestMethod -Method Post -Uri $CreateProjectURLPost -Headers $Headers 
		Write-Host "		Project: "$BuildRepositoryNameDisplay" created!"		
	} 
} catch { Write-Host "		Project: "$BuildRepositoryNameDisplay" failed!" }

# Set PR Integration
Write-Host ""
Write-Host "Setup Pull Request Integration"
$SetKeyURL = "https://sonarcloud.io/api/settings/set?component={0}&key={1}&value={2}"
$PRPost1 = $SetKeyURL -f $BuildRepositoryNameURL, "sonar.pullrequest.provider", "Azure%20DevOps%20Services"
$PRPost2 = $SetKeyURL -f $BuildRepositoryNameURL, "sonar.pullrequest.vsts.token.secured", $SonarCloudDevOpsToken
Try {
	$Post = Invoke-RestMethod -Method Post -Uri $PRPost1 -Headers $Headers
	Write-Host "		sonar.pullrequest.provider: Azure DevOps Services done!"
} catch { Write-Host "		sonar.pullrequest.provider: Azure DevOps Services failed!" }

Try {
	$Post = Invoke-RestMethod -Method Post -Uri $PRPost2 -Headers $Headers
	Write-Host "		sonar.pullrequest.vsts.token.secured: *** done!"
} catch { Write-Host "		sonar.pullrequest.vsts.token.secured: *** failed!" }

# Set New Code Period
Write-Host ""
Write-Host "Set New Code Period"
$Date = "30"
$NewCodePeriodPost = $SetKeyURL -f $BuildRepositoryNameURL, "sonar.leak.period", $Date

Try {
	$Post = Invoke-RestMethod -Method Post -Uri $NewCodePeriodPost -Headers $Headers
	Write-Host "		sonar.leak.period: "$Date" done!"
} catch { Write-Host "		sonar.leak.period: "$Date" failed!"}

# Set Long living branches pattern
Write-Host ""
Write-Host "Set Long living branches pattern"
$BranchPattern = "(master|develop|release).*"
$LongLivingBranchesPatternPost = $SetKeyURL -f $BuildRepositoryNameURL, "sonar.branch.longLivedBranches.regex", $BranchPattern

Try {
	$Post = Invoke-RestMethod -Method Post -Uri $LongLivingBranchesPatternPost -Headers $Headers
	Write-Host "		sonar.branch.longLivedBranches.regex: "$BranchPattern" done!"
} catch { Write-Host "		sonar.branch.longLivedBranches.regex: "$BranchPattern" failed!" }	

# Set Coverage Exclusion
Write-Host ""
Write-Host "Set Code Coverage Exclusion"
$SCEPaterns = @("**\*.Test.csproj","**\*.Test.*.csproj","**\*.Teste.csproj","**\*.Teste.*.csproj","**\*.Tests.csproj","**\*.Testes.csproj","**\*.Tests.*.csproj","**\*.Testes.*.csproj")
$SCEURLPaterns = $SCEPaterns -Join "&values="
$SCEURLSet = "https://sonarcloud.io/api/settings/set?component={0}&key={1}&values={2}"
$SCEURLSetPost = $SCEURLSet -f $BuildRepositoryNameURL, "sonar.coverage.exclusions", $SCEURLPaterns

Try {
	$Post = Invoke-RestMethod -Method Post -Uri $SCEURLSetPost -Headers $Headers
	$DisplaySCEURLPaterns = $SCEPaterns -Join ", "
	Write-Host "		sonar.coverage.exclusions: "$DisplaySCEURLPaterns" done!"
} catch { Write-Host "		sonar.coverage.exclusions: "$DisplaySCEURLPaterns" failed!" }	

# Rename Main Branch
Write-Host ""
Write-Host "Rename Main Branch"
$MainBrachName = "develop"
$RNURL = "https://sonarcloud.io/api/project_branches/rename?name={0}&project={1}"
$RNPost = $RNURL -f $MainBrachName, $BuildRepositoryNameURL

Try {
	$Post = Invoke-RestMethod -Method Post -Uri $RNPost -Headers $Headers
	Write-Host "		Main Branch: "$MainBrachName" done!"
} catch { Write-Host "		Main Branch: "$MainBrachName" failed!" }

# Create and Set Groups permissions
Write-Host ""
Write-Host "Setup Groups and Permissions"
$GRURLVerify = "https://sonarcloud.io/api/user_groups/search?organization={0}&q={1}"
$GRURLCreate = "https://sonarcloud.io/api/user_groups/create?organization={0}&name={1}&description={2}"
$GRPermSetURL = "https://sonarcloud.io/api/permissions/add_group?organization={0}&projectKey={1}&groupName={2}&permission={3}"

## Project Group
$GR1Name = [uri]::EscapeDataString($Env:System_TeamProject)
$GR1NameDesc = "Este grupo tem acesso a todos os projetos da area"
$GR1Post = $GRURLCreate -f $Org, $GR1Name, $GR1NameDesc

Try {
	$GRURLVerifyGet = $GRURLVerify -f $Org, $GR1Name
	$GetGroups = Invoke-RestMethod -Method Get -Uri $GRURLVerifyGet -Headers $Headers
	If ($Env:System_TeamProject -in $GetGroups.groups.name) {
		Write-Host "		group: "$Env:System_TeamProject" already exists!"
	} Else {
		$Post = Invoke-RestMethod -Method Post -Uri $GR1Post -Headers $Headers
		Write-Host "		create group: "$Env:System_TeamProject" done!"
	}
} Catch { Write-Host "		group: "$Env:System_TeamProject" failed!" }

Try {
	$GR1Post2 = $GRPermSetURL -f $Org, $BuildRepositoryNameURL, $GR1Name, "user"
	$GR1Post3 = $GRPermSetURL -f $Org, $BuildRepositoryNameURL, $GR1Name, "codeviewer"
	$GR1Post4 = $GRPermSetURL -f $Org, $BuildRepositoryNameURL, $GR1Name, "issueadmin"
	$GR1Post5 = $GRPermSetURL -f $Org, $BuildRepositoryNameURL, $GR1Name, "securityhotspotadmin"

	$Post = Invoke-RestMethod -Method Post -Uri $GR1Post2 -Headers $Headers
	$Post = Invoke-RestMethod -Method Post -Uri $GR1Post3 -Headers $Headers
	$Post = Invoke-RestMethod -Method Post -Uri $GR1Post4 -Headers $Headers
	$Post = Invoke-RestMethod -Method Post -Uri $GR1Post5 -Headers $Headers
	Write-Host "		setting permissions for group: "$Env:System_TeamProject" done!"
} Catch {Write-Host "		setting permissions for group: "$Env:System_TeamProject" failed!"}

## Repository Group
$GR2Name = $BuildRepositoryNameURL
$GR2NameDesc = "Este grupo tem acesso somente a esse repositorio"

$GR2Post = $GRURLCreate -f $Org, $GR2Name, $GR2NameDesc

Try {
	$GRURLVerifyGet = $GRURLVerify -f $Org, $GR2Name
	$GetGroups = Invoke-RestMethod -Method Get -Uri $GRURLVerifyGet -Headers $Headers
	If ($BuildRepositoryNameDisplay -in $GetGroups.groups.name) {
		Write-Host "		group: "$BuildRepositoryNameDisplay" already exists!"
	} Else {
		$Post = Invoke-RestMethod -Method Post -Uri $GR2Post -Headers $Headers
		Write-Host "		create group: "$BuildRepositoryNameDisplay" done!"
	}
} Catch { Write-Host "		group: "$BuildRepositoryNameDisplay" failed!" }

Try {
	$GR2Post2 = $GRPermSetURL -f $Org, $BuildRepositoryNameURL, $GR2Name, "user"
	$GR2Post3 = $GRPermSetURL -f $Org, $BuildRepositoryNameURL, $GR2Name, "codeviewer"
	$GR2Post4 = $GRPermSetURL -f $Org, $BuildRepositoryNameURL, $GR2Name, "issueadmin"
	$GR2Post5 = $GRPermSetURL -f $Org, $BuildRepositoryNameURL, $GR2Name, "securityhotspotadmin"

	$Post = Invoke-RestMethod -Method Post -Uri $GR2Post2 -Headers $Headers
	$Post = Invoke-RestMethod -Method Post -Uri $GR2Post3 -Headers $Headers
	$Post = Invoke-RestMethod -Method Post -Uri $GR2Post4 -Headers $Headers
	$Post = Invoke-RestMethod -Method Post -Uri $GR2Post5 -Headers $Headers
	Write-Host "		setting permissions for group: "$BuildRepositoryNameDisplay" done!"
} Catch { Write-Host "		setting permissions for group: "$BuildRepositoryNameDisplay" failed!" }

# Query Sonar User
Write-Host ""
Write-Host "Add user to group "$BuildRepositoryNameDisplay", if exists"
Try {
    $UserMail = [uri]::EscapeDataString($Env:BUILD_REQUESTEDFOREMAIL)
    $UserURL = "https://sonarcloud.io/api/users/search?q={0}"
    $UserGet = $UserURL -f $UserMail
    $User = Invoke-RestMethod -Method Get -Uri $UserGet -Headers $Headers

    ##Add User to Repository Group
    If ($User.users.login){
        $AddUserURL =  "https://sonarcloud.io/api/user_groups/add_user?organization={0}&name={1}&login={2}"
        $AddUserPost = $AddUserURL -f $Org, $BuildRepositoryNameURL, $User.users.login
        $Post = Invoke-RestMethod -Method Post -Uri $AddUserPost -Headers $Headers
		Write-Host "		user: "$Env:BUILD_REQUESTEDFOREMAIL" added!"
    } Else {
		Write-Host "		user: "$Env:BUILD_REQUESTEDFOREMAIL" not found on SonarCloud!"
	}
} Catch { Write-Host "		user: "$Env:BUILD_REQUESTEDFOREMAIL" failed!" }
Write-Host ""
Write-Host "=============================================================================="