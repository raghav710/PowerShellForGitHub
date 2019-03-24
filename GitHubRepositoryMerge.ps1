# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

function Merge-GitHubRepositoryBranch
{
<#
    .SYNOPSIS
        Merge the specified branch into another branch

    .DESCRIPTION
        Merge the specified branch into another branch

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OwnerName
        Owner of the repository.
        If not supplied here, the DefaultOwnerName configuration property value will be used.

    .PARAMETER RepositoryName
        Name of the repository.
        If not supplied here, the DefaultRepositoryName configuration property value will be used.

    .PARAMETER Uri
        Uri for the repository.
        The OwnerName and RepositoryName will be extracted from here instead of needing to provide
        them individually.

    .PARAMETER State
        The state of the pull requests that should be returned back.

    .PARAMETER Base
        The name of the base branch that the head will be merged into.

    .PARAMETER Head
        The head to merge. This can be a branch name or a commit SHA1.

    .PARAMETER CommitMessage
        Commit message to use for the merge commit. If omitted, a default message will be used.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .PARAMETER NoStatus
        If this switch is specified, long-running commands will run on the main thread
        with no commandline status update.  When not specified, those commands run in
        the background, enabling the command prompt to provide status information.
        If not supplied here, the DefaultNoStatus configuration property value will be used.

    .OUTPUTS
        PSCustomObject

    .EXAMPLE
        Merge-GitHubRepositoryBranch -OwnerName PowerShell -RepositoryName PowerShellForGitHub -Base 'master' -Head 'new_feature' -CommitMessage 'Merging branch new_feature into master'
#>

[CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName='Elements')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ParameterSetName='Uri')]
        [string] $Uri,

        [Parameter(Mandatory)]
        [string] $Base,

        [Parameter(Mandatory)]
        [string] $Head,

        [string] $CommitMessage,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements -DisableValidation
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
    }

    $hashBody = @{
        'base'= $Base
        'head' = $Head
    }

    if(-not $CommitMessage -eq $null)
    {
        $hashBody['commit_message'] = $CommitMessage
    }

    $params = @{
        'UriFragment' = "repos/$OwnerName/$RepositoryName/merges"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Post'
        'Description' =  "Merging branch $Head to $Base in $RepositoryName"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
        'NoStatus' = (Resolve-ParameterWithDefaultConfigurationValue -Name NoStatus -ConfigValueName DefaultNoStatus)
    }

    try {
        $result = Invoke-GHRestMethod @params -ExtendedResult
        if ($result.statusCode -eq 204)
        {
            Write-Log -Message "Nothing to merge. The branch $Base already contains changes from $Head" -Level Warning
        }
        return $result.result
    }
    catch {
        #TODO: Read the error message and find out the kind of issue
        Write-Error $_.Exception
        Write-Log -Message "Unable to merge. Either the branch $Base or branch $Head does not exist or there is a conflict" -Level Warning
    }
}
