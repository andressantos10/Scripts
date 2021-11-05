Param
(
#    [Parameter(Mandatory = $True)]
#    [string]$PAT,
    [Parameter(Mandatory = $True)]
    [string]$Project,
    [Parameter(Mandatory = $True)]
    [string]$RepoName,
    [Parameter(Mandatory = $True)]
    [ValidateSet('Function', 'WebJob', 'WebApp', 'SQL', 'K8S')]
    [string]$TipoAplicacao,
    [string]$OperationTypeRepo = "create",
    [string]$ProjectType
)

$PAT = "p736cytxz7jnxl6gkzj35zhkeqwn3x2m2tx6yuo4ttrthaijd2na"
# $Project = 'DevOps Core'
# $RepoName = 'BDU'
# $OperationTypeRepo = 'create'

Function Import-GitRepo {
    Param
    (
        [string] $repoName,
        [string] $gitSource,
        [string] $requiresAuthorization
    )
    Write-Host '===Criando repositorio no Azure Repos'
    $importRepo = az repos import create --git-source-url $gitSource -r $repoName --requires-authorization | ConvertFrom-Json

    Write-Host '======Remote URL: ' $importRepo.remoteUrl
    Write-Host '======Repo ID: ' $importRepo.id
    return $importRepo
}
Function Add-GitRepo {
    Param
    (
        [string] $repoName
    )
    Write-Host '===Criando repositorio no Azure Repos'
    $createRepo = az repos create --name $repoName --project $Project --organization $Organization | ConvertFrom-Json

    Write-Host '======Remote URL: ' $createRepo.remoteUrl
    Write-Host '======Repo ID: ' $createRepo.id
    return $createRepo
}

Function Set-GitPush {
    Param
    (
        [string] $remoteUrl
    )
    Write-Host '===Push inicial de aplicacao exemplo'
    git add .
    git commit -m 'Primeiro commit no novo repositorio'
    git remote add origin $remoteUrl
    git push origin master --quiet
}

Function Add-ProjectTypeSolution {
    Param
    (
        [string] $ProjectType,
        [string] $RepoName
    )

    Write-Host '===Criacao do tipo de aplicacao' $ProjectType

    switch ( $ProjectType ) {
        'DotNetCoreMVC' {
            dotnet new sln --name $RepoName
            dotnet new mvc --name $RepoName
            dotnet sln add .\$RepoName\$RepoName.csproj
        }
    }
        
}

Function Add-Pipelines {
    Param
    (
        [string] $pipelineGated,
        [string] $pipelinePrincipal,
        [string] $remoteUrl
    )
    Write-Host '===Criacao de Pipeline Definitions'
    Write-Host '======Criacao da Pipeline Definition Principal' $pipelinePrincipal
    $createPipelinePrincipal = az pipelines create --name $pipelinePrincipal --branch master --description 'Pipeline Principal' --repository $remoteUrl --repository-type 'tfsgit' --skip-first-run true --yaml-path '\esteiras\build-principal.yml'  --project $Project --organization $Organization | ConvertFrom-Json
    Write-Host '======' $createPipelinePrincipal.createdDate

    Write-Host '======Enfileiramento da Pipeline Principal' $pipelinePrincipal
    $queuePipelinePrincipal = az pipelines build queue --definition-id $createPipelinePrincipal.id | ConvertFrom-Json
    Write-Host '======' $queuePipelinePrincipal.buildNumber

    Write-Host '======Criacao da Pipeline Definition Gated' $pipelineGated
    $createPipelineGated = az pipelines create --name $pipelineGated --branch master --description 'Pipeline Gated' --repository $remoteUrl --repository-type 'tfsgit' --skip-first-run true --yaml-path '\esteiras\build-gated.yml'  --project $Project --organization $Organization| ConvertFrom-Json
    Write-Host '======' $createPipelineGated.createdDate

    Write-Host '======Enfileiramento da Pipeline Gated' $pipelineGated
    $queuePipelineGated = az pipelines build queue --definition-id $createPipelineGated.id | ConvertFrom-Json
    Write-Host '======' $queuePipelineGated.buildNumber

    return $createPipelineGated.id
}

Function Set-BranchPolicy {
    Param
    (
        [string] $repoId,
        [string] $pipelineGatedId,
        [string] $pipelineGated,
        [string] $BuildValidation,
        [string] $Reviewers,
        [string] $branchName
    )
    Write-Host "===Estabelecendo as policies da branch $($branchName)"

    Write-Host '======Policy: Require a minimum number of reviewers'
    $policyApproverCount = az repos policy approver-count create --allow-downvotes false --blocking true --branch $branchName --creator-vote-counts false --enabled true --minimum-approver-count 1 --repository-id $repoId --reset-on-source-push false  --project $Project --organization $Organization | ConvertFrom-Json
    Write-Host '======' $policyApproverCount.createdDate
    
    Write-Host '======Policy: Checked for linked work items'
    $policyWorkItemLinking = az repos policy work-item-linking create --blocking true --branch $branchName --enabled true --repository-id $repoId --project $Project --organization $Organization | ConvertFrom-Json
    Write-Host '======' $policyWorkItemLinking.createdDate 

    Write-Host '======Policy: Checked for comment resolution'
    $policyCommentRequired = az repos policy comment-required create --blocking true --branch $branchName --enabled true --repository-id $repoId --project $Project --organization $Organization | ConvertFrom-Json
    Write-Host '======' $policyCommentRequired.createdDate

    ############################# verificar se vamos usar isso agora 
    if ($BuildValidation -eq $true) {
        Write-Host '======Policy: Build Validation'
        $policyBuildValidation = az repos policy build create --blocking true --branch $branchName --build-definition-id $pipelineGatedId --display-name $pipelineGated --enabled true --manual-queue-only false --queue-on-source-update-only false --repository-id $repoId --valid-duration 0  --project $Project --organization $Organization| ConvertFrom-Json
        Write-Host '======' $policyBuildValidation.createdDate
        
    }

    Write-Host '======Policy: Automatically include code reviewers'

    switch ($branchName) {
        'master' {
            $policyRequiredReviewer = az repos policy required-reviewer create --blocking true --branch $branchName --enabled true --repository-id $repoId --message "master" --required-reviewer-ids $Reviewers  --project $Project --organization $Organization| ConvertFrom-Json
            Write-Host '======' $policyRequiredReviewer.createdDate
        }
        'develop' {
            $policyRequiredReviewer = az repos policy required-reviewer create --blocking true --branch $branchName --enabled true --repository-id $repoId --message "develop" --required-reviewer-ids $Reviewers  --project $Project --organization $Organization| ConvertFrom-Json
            Write-Host '======' $policyRequiredReviewer.createdDate
        }
        Default {
            Write-Host "====== Check the BranchName $($branchName)"
        }
    }
}

$Organization = 'https://conectcar.visualstudio.com'
$urlBuildTemplates = 'https://conectcar.visualstudio.com/Infraestrutura/_git/InicializacaoRepositorio'
$ReviewersMaster = '[conectcar]\G_AzDevOps_MASTER_Aprove'
$ReviewersDevelop = '[conectcar]\G_AzDevOps_QA_Aprove'

if (!$TeamProject) { $TeamProject = $Project.Replace(" ", "") }
if (!$Name) { $Name = $RepoName }
if (!$DevopsNickName) { $DevopsNickName = $RepoName.Replace(".", "") }
if (!$ARMResourceType) { $ARMResourceType = $TipoAplicacao }

echo $PAT | az devops login --org $Organization

Write-Host '===Configurando conexao com a organization e o Team Project'
az devops configure --defaults organization=$Organization project=$Project

switch ($OperationTypeRepo) {
    'import' {

        $importRepo = Import-GitRepo -repoName $RepoName -gitSource $urlBuildTemplates -requiresAuthorization $true

        #aplica politicas de branch
        # Set-BranchPolicy -repoId $createRepo.id -pipelineGatedId $pipelineGatedId -pipelineGated $pipelineGated -ReviewersTeam $ReviewersTeam -ReviewersDevOps $ReviewersDevOps
        
    }
    'create' {
        git clone $urlBuildTemplates --quiet
        $repoBuildTemplates = $urlBuildTemplates.Substring($urlBuildTemplates.lastIndexOf('/') + 1)
        
        $currentDir = $PSScriptRoot
        
        $nugetFolder = "$($currentDir)\$($repoBuildTemplates)\"
        
        $createRepo = Add-GitRepo -repoName $RepoName
        
        New-Item -Path $RepoName -ItemType Directory
        Set-Location $currentDir\$RepoName
        
        #inicializa git repo
        git init

        $excludes = ".git"
        Get-ChildItem $nugetFolder | 
            Where-Object { $_.Name -notin $excludes } | 
            Copy-Item -Destination $currentDir\$RepoName -Recurse -Force

        If ($TipoAplicacao -eq 'Function' -or $TipoAplicacao -eq 'WebJob' -or $TipoAplicacao -eq 'WebApp'){ 
			(Get-Content $currentDir\$RepoName'\ALM\Configuration.json') | Foreach-Object {
				$_ -replace '__TeamProject__', $TeamProject `
					-replace '__GitRepository__', $Name `
					-replace '__Name__', $Name `
					-replace '__DevopsNickName__', $DevopsNickName `
					-replace '__RootDir__', $Name `
					-replace '__ARMResourceType__', $ARMResourceType 
			} | Set-Content $currentDir\$RepoName'\ALM\Configuration.json'

            Remove-Item $currentDir\$RepoName'\K8S\' -Recurse -Force

        } ElseIf ($TipoAplicacao -eq 'K8S'){
            (Get-Content $currentDir\$RepoName'\K8S\deployment.yaml') | Foreach-Object {
				$_ -replace '__AppName__', $Name.ToLower() `
                -replace '__TeamProject__', $TeamProject
			} | Set-Content $currentDir\$RepoName'\K8S\deployment.yaml'

            Remove-Item $currentDir\$RepoName'\ALM\' -Recurse -Force

        } ElseIf ($TipoAplicacao -eq 'SQL'){
			Remove-Item $currentDir\$RepoName'\ALM\' -Recurse -Force
            Remove-Item $currentDir\$RepoName'\K8S\' -Recurse -Force

		}
        
        #cria solucao por tipo de tecnologia
        # Add-ProjectTypeSolution -ProjectType $ProjectType -RepoName $RepoName
            
        #push no repositorio
        Set-GitPush -remoteUrl $createRepo.remoteUrl
        
        #create develop
        git checkout -b develop master
        git push origin develop --quiet
        
        #develop default
        az repos update --repository $RepoName --default-branch develop --org $Organization --project $Project
        
        Set-BranchPolicy -repoId $createRepo.id -BuildValidation $false -Reviewers $ReviewersMaster -branchName "master"
        Set-BranchPolicy -repoId $createRepo.id -BuildValidation $false -Reviewers $ReviewersDevelop -branchName "develop"
    }
    Default {
        Write-Host "Set TypeRepo to Import or Create"
    }
}

az devops logout

Set-Location $currentDir
If(Test-Path $RepoName){Remove-Item -Path $RepoName -Recurse -Force}
If(Test-Path $repoBuildTemplates){Remove-Item -Path $repoBuildTemplates -Recurse -Force}
