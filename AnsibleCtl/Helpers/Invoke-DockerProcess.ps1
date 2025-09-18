<#
    .SYNOPSIS
        Invoke a docker.exe process.

    .DESCRIPTION
        This function invokes a docker.exe process with the specified arguments
        and verifies, if the exit code was successful.
#>
function Invoke-DockerProcess
{
    [CmdletBinding()]
    param
    (
        # The docker command.
        [Parameter(Mandatory = $true)]
        [System.String]
        $Command,

        # The arguments to pass to the docker command.
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $ArgumentList,

        # The error message to display if the command fails.
        [Parameter(Mandatory = $false)]
        [System.String]
        $ErrorMessage = 'The Docker command failed.'
    )

    try
    {
        Write-Verbose "[ansiblectl] [$Command] docker $Command $($ArgumentList -join ' ')"

        $dockerCommandSplat = @{
            FilePath     = 'docker.exe'
            ArgumentList = @($Command) + $ArgumentList
            NoNewWindow  = $true
            PassThru     = $true
            Wait         = $true
        }

        # If -Verbose was specified, don't redirect the output and show it in
        # the console output.
        if ($VerbosePreference -eq 'SilentlyContinue')
        {
            $dockerCommandSplat['RedirectStandardOutput'] = [System.IO.Path]::GetTempFileName()
            $dockerCommandSplat['RedirectStandardError']  = [System.IO.Path]::GetTempFileName()
        }
        $dockerProcess = Start-Process @dockerCommandSplat

        if ($dockerProcess.ExitCode -ne 0)
        {
            if ($VerbosePreference -eq 'SilentlyContinue')
            {
                throw "$ErrorMessage Exit Code: $($dockerProcess.ExitCode). Error Output: $(Get-Content -Path $dockerCommandSplat.RedirectStandardError)"
            }
            else
            {
                throw $ErrorMessage
            }
        }
    }
    finally
    {
        if ($null -ne $dockerCommandSplat)
        {
            if ($dockerCommandSplat.ContainsKey('RedirectStandardOutput') -and (Test-Path -Path $dockerCommandSplat.RedirectStandardOutput))
            {
                Remove-Item -Path $dockerCommandSplat.RedirectStandardOutput -Force
            }

            if ($dockerCommandSplat.ContainsKey('RedirectStandardError') -and (Test-Path -Path $dockerCommandSplat.RedirectStandardError))
            {
                Remove-Item -Path $dockerCommandSplat.RedirectStandardError -Force
            }
        }
    }
}
