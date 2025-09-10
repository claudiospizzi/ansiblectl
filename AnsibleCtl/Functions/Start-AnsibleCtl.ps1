<#
    .SYNOPSIS
        Start the Ansible control container instance.

    .DESCRIPTION
        This function will start the container image claudiospizzi/ansiblectl
        with the required parameters for binding the Ansible files and the SSH
        keys.

    .EXAMPLE
        PS C:\> Start-AnsibleCtl
        .

    .LINK
        https://github.com/claudiospizzi/ansiblectl
#>
function Start-AnsibleCtl
{
    [Alias('ansiblectl')]
    [CmdletBinding(DefaultParameterSetName = '1Password')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'The 1Password key item is not a password but the item id or name.')]
    param
    (
        # Path to the Ansible repository. Defaults to the current directory.
        [Parameter(Mandatory = $false)]
        [System.String]
        $RepositoryPath = $PWD.Path,

        # The container image to use.
        [Parameter(Mandatory = $false)]
        [System.String]
        $ContainerImage = 'claudiospizzi/ansiblectl:latest',

        # If set, the local SSH keys in the ~/.ssh directory of the user profile
        # will be mounted into the container.
        [Parameter(Mandatory = $true, ParameterSetName = 'Profile')]
        [Switch]
        $ProfileSshKeys,

        # If set, the 1Password key items will be used. The item can be
        # specified by id or by name. All specified keys are mounted into the
        # container.
        [Parameter(Mandatory = $true, ParameterSetName = '1Password')]
        [System.String[]]
        $OnePasswordSshKeys,

        # Flag to hide the output header before starting the container.
        [Parameter(Mandatory = $false)]
        [Switch]
        $Silent
    )

    try
    {
        ##
        ## Environment Validation
        ##

        # Ensure we are on a Windows system by using the legacy Windows
        # PowerShell or the modern cross-platform PowerShell on the Windows OS.
        if ($PSVersionTable.PSVersion.Major -gt 5 -and -not $IsWindows)
        {
            throw 'The ansiblectl module was designed to run on Windows. Linux and MacOS are not supported.'
        }

        # Check if the Docker Desktop is installed.
        if ($null -eq (Get-Command -Name 'docker.exe' -CommandType 'Application' -ErrorAction 'SilentlyContinue'))
        {
            throw 'The Docker executable docker.exe was not found in the path. Ensure Docker Desktop is installed.'
        }

        # Check if Docker Desktop is actually running.
        if ($null -eq (Get-Process -Name 'Docker Desktop' -ErrorAction 'SilentlyContinue'))
        {
            throw 'The Docker Desktop process was not found. Ensure Docker Desktop is installed and started.'
        }

        # Check if the specified repository contains an actual Ansible
        # inventory.
        if (-not (Test-Path -Path $RepositoryPath))
        {
            throw 'The specified Ansible repository does not exist (folder not found).'
        }
        if (-not (Test-Path -Path (Join-Path -Path $RepositoryPath -ChildPath 'ansible.cfg')))
        {
            throw 'The specified Ansible repository does not exist (ansible.cfg not found).'
        }


        ##
        ## Repository Cache (.ansiblectl)
        ##

        # We use a path in the repository to cache ansiblectl related files.
        $repositoryCachePath = Join-Path -Path $RepositoryPath -ChildPath '.ansiblectl'
        if (-not (Test-Path -Path $repositoryCachePath))
        {
            New-Item -Path $repositoryCachePath -ItemType 'Directory' | Out-Null
        }

        # This folder will contain the SSH keys to be mounted into the
        # container. They will be deleted as soon as the container starts. We
        # have a background task and the finally block to ensure this folder is
        # always cleaned up.
        $repositorySshPath = Join-Path -Path $RepositoryPath -ChildPath '.ansiblectl/.ssh'
        if (-not (Test-Path -Path $repositorySshPath))
        {
            New-Item -Path $repositorySshPath -ItemType 'Directory' | Out-Null
        }

        # Ensure there is a .gitignore file in the .ssh path to ensure, that no
        # ssh key is checked into a git repository.
        $repositorySshGitIgnorePath = Join-Path -Path $RepositoryPath -ChildPath '.ansiblectl/.ssh/.gitignore'
        if (-not (Test-Path -Path $repositorySshGitIgnorePath))
        {
            Set-Content -Path $repositorySshGitIgnorePath -Value '# Ignore all files in the folder', '*' -Encoding 'UTF8'
        }

        # Store the bash history to have the latest command of the target
        # ansible repository.
        $repositoryBashHistoryPath = Join-Path -Path $RepositoryPath -ChildPath '.ansiblectl/.bash_history'
        if (-not (Test-Path -Path $repositoryBashHistoryPath))
        {
            New-Item -Path $repositoryBashHistoryPath -ItemType 'File' | Out-Null
        }


        ##
        ## SSH Keys
        ##

        if ($PSCmdlet.ParameterSetName -eq 'Profile')
        {
            # Use the local SSH keys in the ~/.ssh directory.
            $localSshPath = Join-Path -Path $HOME -ChildPath '.ssh'
            if (-not (Test-Path -Path $localSshPath))
            {
                throw 'The local SSH key directory ~/.ssh does not exist.'
            }

            # Ensure we have some SSH keys
            $sshKeyFiles = Get-ChildItem -Path $localSshPath -Filter 'id_*' -File
            if ($null -eq $sshKeyFiles)
            {
                throw 'No local SSH key files found in directory ~/.ssh.'
            }

            # Copy all files from the local SSH directory to the repository
            # cache SSH directory.
            foreach ($sshKeyFile in $sshKeyFiles)
            {
                Copy-Item -Path $sshKeyFile.FullName -Destination $repositorySshPath -Verbose -Force
            }
        }

        if ($PSCmdlet.ParameterSetName -eq '1Password')
        {
            # Check if 1Password is actually running.
            if ($null -eq (Get-Process -Name '1password' -ErrorAction 'SilentlyContinue'))
            {
                throw 'The 1Password process was not found. Ensure 1Password is installed and started.'
            }

            # Check if the 1Password CLI is installed.
            if ($null -eq (Get-Command -Name 'op.exe' -CommandType 'Application' -ErrorAction 'SilentlyContinue'))
            {
                throw 'The 1Password executable op.exe was not found in the path. Ensure 1Password CLI is installed.'
            }

            # Ensure we have some SSH keys
            $sshKeyItems = op.exe item list --categories "SSH Key" --format 'json' | ConvertFrom-Json |
                Where-Object { $_.id -in $OnePasswordSshKeys -or $_.title -in $OnePasswordSshKeys }
            if ($null -eq $sshKeyItems)
            {
                throw 'No SSH key items found in 1Password which match the specified key id or name. Unable to mount the SSH keys into the Ansible control node.'
            }

            # Export all items to the to the repository cache SSH directory.
            foreach ($sshKeyItem in $sshKeyItems)
            {
                $sshKeyItemDetail = op.exe item get $sshKeyItem.id --fields "label=public key,label=private key,label=key type" --format json | ConvertFrom-Json

                Set-Content -Path "$repositorySshPath\id_$($sshKeyItem.id).pub" -Value $sshKeyItemDetail.Where({ $_.label -eq 'public key' }).value -Encoding 'UTF8'
                Set-Content -Path "$repositorySshPath\id_$($sshKeyItem.id)" -Value $sshKeyItemDetail.Where({ $_.label -eq 'private key' }).value -Encoding 'UTF8'
            }
        }


        ##
        ## Run Ansible Control Node
        ##

        # User information
        if (-not $Silent.IsPresent)
        {
            Write-Host ''
            Write-Host 'ANSIBLE CONTROL NODE'
            Write-Host '********************'
            Write-Host ''
            Write-Host "Ansible Repo: $RepositoryPath"
            Write-Host "Docker Image: $ContainerImage"
            Write-Host "SSH Key Mode: $($PSCmdlet.ParameterSetName)"
            Write-Host ''
        }

        $normalizedRepositoryPath = '/{0}' -f $RepositoryPath.Replace(':', '').Replace('\', '/').Trim('/')

        $dockerSshKeysVolumeMount        = '{0}/.ansiblectl/.ssh:/tmp/.ssh' -f $normalizedRepositoryPath
        $dockerBashHistoryVolumeMount    = '{0}/.ansiblectl/.bash_history:/root/.bash_history' -f $normalizedRepositoryPath
        $dockerRepositoryPathVolumeMount = '{0}:/ansible' -f $normalizedRepositoryPath

        # Clean-up the key files after 3 seconds
        Start-Job -ScriptBlock { Start-Sleep -Seconds 3; Get-ChildItem -Path $using:repositorySshPath -Filter 'id_*' -File | Remove-Item -Force } | Out-Null

        # -v $volumeKeys -v $volumeBashHistory
        docker.exe run -it --rm -h 'ansiblectl' -v $dockerSshKeysVolumeMount -v $dockerRepositoryPathVolumeMount -v $dockerBashHistoryVolumeMount $ContainerImage
    }
    catch
    {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally
    {
        # Ensure no key files are stored in the repository after running this command
        $repositorySshPath = Join-Path -Path $RepositoryPath -ChildPath '.ansiblectl/.ssh'
        if (Test-Path -Path $repositorySshPath)
        {
            Get-ChildItem -Path $repositorySshPath -Filter 'id_*' -File | Remove-Item -Force
        }
    }
}
