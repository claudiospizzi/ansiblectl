<#
    .SYNOPSIS
        Start the Ansible control container instance.

    .DESCRIPTION
        This function will start the container image claudiospizzi/ansiblectl
        with the required parameters for binding the Ansible files and the SSH
        keys.

    .EXAMPLE
        PS C:\> Start-AnsibleCtl
        Start the Ansible control container instance in the current directory
        and search $HOME/.ssh for SSH keys.

    .LINK
        https://github.com/claudiospizzi/ansiblectl
#>
function Start-AnsibleCtl
{
    [Alias('ansiblectl')]
    [CmdletBinding(DefaultParameterSetName = 'ContainerImage_KeyFiles')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This function provides an interactive experience for the user.')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'The 1Password key item is not a password but the item id or name.')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'This function does not change the system state. It only starts a container instance.')]
    param
    (
        # Path to the Ansible repository. Defaults to the current directory.
        [Parameter(Mandatory = $false)]
        [System.String]
        $RepositoryPath = $PWD.Path,

        # The container image to use.
        [Parameter(Mandatory = $false, ParameterSetName = 'ContainerImage_KeyFiles')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ContainerImage_1Password')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ContainerImage_NoKeys')]
        [System.String]
        $ContainerImage = 'claudiospizzi/ansiblectl:latest',

        # The Ansible version to use. This will be the container image tag, so
        # semantic versioning is supported of the Ansible community package
        # release version. It has to be a prebuilt image in the container
        # registry claudiospizzi/ansiblectl.
        [Parameter(Mandatory = $true, ParameterSetName = 'AnsibleVersion_KeyFiles')]
        [Parameter(Mandatory = $true, ParameterSetName = 'AnsibleVersion_1Password')]
        [Parameter(Mandatory = $true, ParameterSetName = 'AnsibleVersion_NoKeys')]
        [System.String]
        $AnsibleVersion,

        # If set, a custom Dockerfile will be used to build the container image
        # before starting the Ansible Control. The base image is controlled in
        # the specified Dockerfile and should be based on any of the official
        # images in claudiospizzi/ansiblectl.
        [Parameter(Mandatory = $true, ParameterSetName = 'Dockerfile_KeyFiles')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Dockerfile_1Password')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Dockerfile_NoKeys')]
        [System.String]
        $Dockerfile,

        # If set, the local SSH keys in the ~/.ssh directory of the user profile
        # will be mounted into the container.
        [Parameter(Mandatory = $false, ParameterSetName = 'ContainerImage_KeyFiles')]
        [Parameter(Mandatory = $false, ParameterSetName = 'AnsibleVersion_KeyFiles')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Dockerfile_KeyFiles')]
        [System.String]
        $SshKeyFilePath = "$HOME/.ssh",

        # If set, the 1Password key items will be used. The item can be
        # specified by id or by name. All specified keys are mounted into the
        # container.
        [Parameter(Mandatory = $true, ParameterSetName = 'ContainerImage_1Password')]
        [Parameter(Mandatory = $true, ParameterSetName = 'AnsibleVersion_1Password')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Dockerfile_1Password')]
        [System.String[]]
        $OnePasswordSshKeys,

        # If set, no SSH keys will be mounted into the container. This is useful
        # if Ansible is used only for the local system or cloud services which
        # don't required any SSH keys
        [Parameter(Mandatory = $true, ParameterSetName = 'ContainerImage_NoKeys')]
        [Parameter(Mandatory = $true, ParameterSetName = 'AnsibleVersion_NoKeys')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Dockerfile_NoKeys')]
        [Switch]
        $NoSshKeys,

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

        Write-Verbose "[ansiblectl] Version $Script:PSModuleVersion"

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
        # inventory. At the end, resolve it to the full path.
        if (-not (Test-Path -Path $RepositoryPath))
        {
            throw 'The specified Ansible repository does not exist (folder not found).'
        }
        if (-not (Test-Path -Path (Join-Path -Path $RepositoryPath -ChildPath 'ansible.cfg')))
        {
            throw 'The specified Ansible repository does not exist (ansible.cfg not found).'
        }


        ##
        ## Repository Path & Cache (.ansiblectl)
        ##

        Write-Verbose "[ansiblectl] [Repository] Input Path: $RepositoryPath"

        # Resolve the repository path to the full path, so we can use it without
        # relative path issues.
        $repositoryFullPath = Resolve-Path -Path $RepositoryPath | Select-Object -First 1 -ExpandProperty 'Path'
        Write-Verbose "[ansiblectl] [Repository] Resolved Path: $repositoryFullPath"

        # We use a path in the repository to cache ansiblectl related files.
        $repositoryCachePath = Join-Path -Path $repositoryFullPath -ChildPath '.ansiblectl'
        Write-Verbose "[ansiblectl] [Repository] Verify Cache Path: $repositoryCachePath"
        if (-not (Test-Path -Path $repositoryCachePath))
        {
            New-Item -Path $repositoryCachePath -ItemType 'Directory' | Out-Null
        }

        # This folder will contain the SSH keys to be mounted into the
        # container. They will be deleted as soon as the container starts. We
        # have a background task and the finally block to ensure this folder is
        # always cleaned up. But to be sure we don't use old keys, we clean it
        # up at the beginning as well.
        $repositorySshPath = Join-Path -Path $repositoryFullPath -ChildPath '.ansiblectl/.ssh'
        Write-Verbose "[ansiblectl] [Repository] Verify SSH Folder: $repositorySshPath"
        if (-not (Test-Path -Path $repositorySshPath))
        {
            New-Item -Path $repositorySshPath -ItemType 'Directory' | Out-Null
        }
        else
        {
            Get-ChildItem -Path $repositorySshPath -Filter 'id_*' -File | Remove-Item -Force
        }

        # Ensure there is a note file in the .ssh path to inform the user that
        # this folder is managed by ansiblectl and cleaned up automatically.
        $repositorySshUserInfoPath = Join-Path -Path $repositoryFullPath -ChildPath '.ansiblectl/.ssh/DO-NOT-SAVE-SSH-KEYS-IN-THIS-FOLDER.txt'
        Write-Verbose "[ansiblectl] [Repository] Verify SSH Key User Info File: $repositorySshUserInfoPath"
        if (-not (Test-Path -Path $repositorySshUserInfoPath))
        {
            Set-Content -Path $repositorySshUserInfoPath -Value "IMPORTANT NOTE`n**************`n`nThis folder is managed by ansiblectl. All SSH key files are cleaned up`nautomatically. Do not use this folder as your personal SSH key files storage." -Encoding 'UTF8'
        }

        # Ensure there is a .gitignore file in the .ssh path to ensure, that no
        # ssh key is checked into a git repository.
        $repositorySshGitIgnorePath = Join-Path -Path $repositoryFullPath -ChildPath '.ansiblectl/.ssh/.gitignore'
        Write-Verbose "[ansiblectl] [Repository] Verify SSH .gitignore File: $repositorySshGitIgnorePath"
        if (-not (Test-Path -Path $repositorySshGitIgnorePath))
        {
            Set-Content -Path $repositorySshGitIgnorePath -Value '# Ignore all files in the folder', '*' -Encoding 'UTF8'
        }

        # Store the bash history to have the latest command of the target
        # ansible repository.
        $repositoryBashHistoryPath = Join-Path -Path $repositoryFullPath -ChildPath '.ansiblectl/.bash_history'
        Write-Verbose "[ansiblectl] [Repository] Verify Bash History File: $repositoryBashHistoryPath"
        if (-not (Test-Path -Path $repositoryBashHistoryPath))
        {
            New-Item -Path $repositoryBashHistoryPath -ItemType 'File' | Out-Null
        }


        ##
        ## Container Image
        ##

        if ($PSCmdlet.ParameterSetName -like 'ContainerImage_*')
        {
            # Nothing to do, the container image is already specified.
            Write-Verbose "[ansiblectl] [Container Image] Image: $ContainerImage"
        }

        if ($PSCmdlet.ParameterSetName -like 'AnsibleVersion_*')
        {
            Write-Verbose "[ansiblectl] [Container Image] Ansible Version: $AnsibleVersion"

            $ContainerImage = "ghcr.io/claudiospizzi/ansiblectl:$AnsibleVersion"

            Write-Verbose "[ansiblectl] [Container Image] Image: $ContainerImage"
        }

        if ($PSCmdlet.ParameterSetName -like 'Dockerfile_*')
        {
            Write-Verbose "[ansiblectl] [Container Image] Custom Dockerfile: $Dockerfile"

            # Check if the specified Dockerfile actually exists.
            if (-not (Test-Path -Path $Dockerfile))
            {
                throw "The specified Dockerfile '$Dockerfile' does not exist."
            }

            # Prepare a container image name based on the Dockerfile hash.
            $dockerfileHash = Get-FileHash -Path $Dockerfile -Algorithm 'SHA256' | ForEach-Object { $_.Hash.ToLower().Substring(0, 12) }
            $ContainerImage = 'custom/ansiblectl:{0}' -f $dockerfileHash
            $dockerfilePath = Split-Path -Path $Dockerfile -Parent

            # Build the container image from the specified Dockerfile.
            Write-Verbose "[ansiblectl] [Container Image] docker build -t $ContainerImage -f $Dockerfile $dockerfilePath"
            $dockerImageBuildSplat = @{
                FilePath               = 'docker.exe'
                ArgumentList           = @('build', '-t', $ContainerImage, '-f', $Dockerfile, $dockerfilePath)
                NoNewWindow            = $true
                PassThru               = $true
                Wait                   = $true
                RedirectStandardOutput = [System.IO.Path]::GetTempFileName()
                RedirectStandardError  = [System.IO.Path]::GetTempFileName()
            }
            $dockerImageBuild = Start-Process @dockerImageBuildSplat

            # Check if the Docker build was successful.
            if ($dockerImageBuild.ExitCode -ne 0)
            {
                throw "The Docker build of the specified Dockerfile '$Dockerfile' failed.`n$(Get-Content -Path $dockerImageBuildSplat.RedirectStandardError -Raw)"
            }
            Remove-Item -Path $dockerImageBuildSplat.RedirectStandardOutput -Force -ErrorAction 'SilentlyContinue'
            Remove-Item -Path $dockerImageBuildSplat.RedirectStandardError -Force -ErrorAction 'SilentlyContinue'

            Write-Verbose "[ansiblectl] [Container Image] Image: $ContainerImage"
        }


        ##
        ## SSH Keys
        ##

        if ($PSCmdlet.ParameterSetName -like '*_KeyFiles')
        {
            # Use the local SSH keys in the ~/.ssh directory.
            if (-not (Test-Path -Path $SshKeyFilePath))
            {
                throw "The specified SSH key directory '$SshKeyFilePath' does not exist."
            }

            Write-Verbose "[ansiblectl] [SSH Keys] Using local SSH keys: $SshKeyFilePath"

            # Ensure we have some SSH keys
            $sshKeyFiles = Get-ChildItem -Path $SshKeyFilePath -Filter 'id_*' -File
            if ($null -eq $sshKeyFiles)
            {
                throw "No specified SSH key files found in the specified directory '$SshKeyFilePath'."
            }

            # Copy all files from the local SSH directory to the repository
            # cache SSH directory.
            foreach ($sshKeyFile in $sshKeyFiles)
            {
                Write-Verbose "[ansiblectl] [SSH Keys] Copying local SSH key: $($sshKeyFile.FullName) -> $repositorySshPath\$($sshKeyFile.Name)"

                Copy-Item -Path $sshKeyFile.FullName -Destination $repositorySshPath -Verbose -Force
            }
        }

        if ($PSCmdlet.ParameterSetName -like '*_1Password')
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

            Write-Verbose "[ansiblectl] [SSH Keys] Using 1Password SSH keys: $($OnePasswordSshKeys -join ', ')"

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
                Write-Verbose "[ansiblectl] [SSH Keys] Exporting 1Password SSH key: $($sshKeyItem.title)"
                $sshKeyItemDetail = op.exe item get $sshKeyItem.id --fields "label=public key,label=private key,label=key type" --format json | ConvertFrom-Json

                Write-Verbose "[ansiblectl] [SSH Keys] Store 1Password SSH key file: $repositorySshPath\id_$($sshKeyItem.id).pub"
                Set-Content -Path "$repositorySshPath\id_$($sshKeyItem.id).pub" -Value $sshKeyItemDetail.Where({ $_.label -eq 'public key' }).value -Encoding 'UTF8'

                Write-Verbose "[ansiblectl] [SSH Keys] Store 1Password SSH key file: $repositorySshPath\id_$($sshKeyItem.id)"
                Set-Content -Path "$repositorySshPath\id_$($sshKeyItem.id)" -Value $sshKeyItemDetail.Where({ $_.label -eq 'private key' }).value -Encoding 'UTF8'
            }
        }

        if ($PSCmdlet.ParameterSetName -like '*_NoKeys')
        {
            Write-Verbose '[ansiblectl] [SSH Keys] No SSH keys will be used.'

            if (-not $NoSshKeys.IsPresent)
            {
                throw 'Setting the -NoSshKeys switch to false is not supported. Please set it to true (or just use the switch). As an alternative use the -SshKeyFilePath or -OnePasswordSshKeys parameters to specify SSH keys.'
            }
        }


        ##
        ## Run Ansible Control Node
        ##

        # Show a nice SSH Key Mode information
        if ($PSCmdlet.ParameterSetName -like '*_KeyFiles')
        {
            $headerSshKeyMode = 'Key Files ({0})' -f $SshKeyFilePath
        }
        if ($PSCmdlet.ParameterSetName -like '*_1Password')
        {
            $headerSshKeyMode = '1Password Items ({0})' -f ($OnePasswordSshKeys -join ', ')
        }
        if ($PSCmdlet.ParameterSetName -like '*_NoKeys')
        {
            $headerSshKeyMode = 'Disabled'
        }

        # User information
        if (-not $Silent.IsPresent)
        {
            Write-Host ''
            Write-Host 'ANSIBLE CONTROL NODE' -ForegroundColor 'Magenta'
            Write-Host '********************' -ForegroundColor 'Magenta'
            Write-Host ''
            Write-Host "Ansible Repo    : $repositoryFullPath"
            Write-Host "Container Image : $ContainerImage"
            Write-Host "SSH Key Mode    : $headerSshKeyMode"
            Write-Host ''
        }

        $normalizedRepositoryPath = '/{0}' -f $repositoryFullPath.Replace(':', '').Replace('\', '/').Trim('/')

        $dockerSshKeysVolumeMount        = '{0}/.ansiblectl/.ssh:/tmp/.ssh' -f $normalizedRepositoryPath
        $dockerBashHistoryVolumeMount    = '{0}/.ansiblectl/.bash_history:/root/.bash_history' -f $normalizedRepositoryPath
        $dockerRepositoryPathVolumeMount = '{0}:/ansible' -f $normalizedRepositoryPath

        # Pull the container image to ensure we have the latest version.
        Write-Verbose "[ansiblectl] docker pull $ContainerImage"
        $dockerPullSplat = @{
            FilePath               = 'docker.exe'
            ArgumentList           = @('pull', $ContainerImage)
            NoNewWindow            = $true
            PassThru               = $true
            Wait                   = $true
            RedirectStandardOutput = [System.IO.Path]::GetTempFileName()
            RedirectStandardError  = [System.IO.Path]::GetTempFileName()
        }
        $dockerPull = Start-Process @dockerPullSplat

        # Check if the Docker pull was successful.
        if ($dockerPull.ExitCode -ne 0)
        {
            throw "The Docker pull of the container image '$ContainerImage' failed.`n$(Get-Content -Path $dockerPullSplat.RedirectStandardError -Raw)"
        }
        Remove-Item -Path $dockerPullSplat.RedirectStandardOutput -Force -ErrorAction 'SilentlyContinue'
        Remove-Item -Path $dockerPullSplat.RedirectStandardError -Force -ErrorAction 'SilentlyContinue'

        # Clean-up the key files after 15 seconds
        Start-Job -ScriptBlock { Start-Sleep -Seconds 15; Get-ChildItem -Path $using:repositorySshPath -Filter 'id_*' -File | Remove-Item -Force } | Out-Null

        # Run the Docker container with docker run. If successful, the script
        # will halt at this point until the container is exited by the user.
        Write-Verbose "[ansiblectl] docker run -it --rm -h ansiblectl -v $dockerSshKeysVolumeMount -v $dockerRepositoryPathVolumeMount -v $dockerBashHistoryVolumeMount $ContainerImage"
        $dockerRunSplat = @{
            FilePath               = 'docker.exe'
            ArgumentList           = @('run', '-it', '--rm', '-h', 'ansiblectl', '-v', $dockerSshKeysVolumeMount, '-v', $dockerRepositoryPathVolumeMount, '-v', $dockerBashHistoryVolumeMount, $ContainerImage)
            NoNewWindow            = $true
            PassThru               = $true
            Wait                   = $true
            RedirectStandardOutput = [System.IO.Path]::GetTempFileName()
            RedirectStandardError  = [System.IO.Path]::GetTempFileName()
            ErrorAction           = 'Continue'
        }
        $dockerRun = Start-Process @dockerRunSplat

        # Check if the Docker run was successful.
        if ($dockerRun.ExitCode -ne 0)
        {
            throw "The Docker run of the container image '$ContainerImage' failed.`n$(Get-Content -Path $dockerRunSplat.RedirectStandardError -Raw)"
        }
        Remove-Item -Path $dockerRunSplat.RedirectStandardOutput -Force -ErrorAction 'SilentlyContinue'
        Remove-Item -Path $dockerRunSplat.RedirectStandardError -Force -ErrorAction 'SilentlyContinue'

        # $dockerResult = docker.exe run -it --rm -h 'ansiblectl' -v $dockerSshKeysVolumeMount -v $dockerRepositoryPathVolumeMount -v $dockerBashHistoryVolumeMount $ContainerImage
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

# List all available ansible versions (image tags) from the GitHub Container Registry
Register-ArgumentCompleter -CommandName 'Start-AnsibleCtl' -ParameterName 'AnsibleVersion' -ScriptBlock {
    param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

    # Query the config.json from the GitHub repository to get the available
    # Ansible versions which will be builded and published to the container.
    # This is not perfect, but the image registry has non anonymous API to get
    # all containers tags.
    $config = Invoke-RestMethod -uri 'https://raw.githubusercontent.com/claudiospizzi/ansiblectl/refs/heads/main/docker/config.json'
    foreach ($ansibleVersion in $config.ansible.versions) {
        if ($ansibleVersion -like "$WordToComplete*") {
            [System.Management.Automation.CompletionResult]::new($ansibleVersion, $ansibleVersion, 'ParameterValue', $ansibleVersion)
        }
    }
}
