function Remove-DbaClientAlias {
    <#
        .SYNOPSIS
            Removes a sql alias for the specified server - mimics cliconfg.exe

        .DESCRIPTION
            Removes a SQL Server alias by altering HKLM:\SOFTWARE\Microsoft\MSSQLServer\Client

        .PARAMETER ComputerName
            The target computer where the alias will be created

        .PARAMETER Credential
            Allows you to login to remote computers using alternative credentials

        .PARAMETER Alias
            The alias or array of aliases to be deleted

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Alias

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Remove-DbaClientAlias

        .EXAMPLE
            Remove-DbaClientAlias -ComputerName workstationx -Alias sqlps

            Removes the sqlps SQL client alias on workstationx

        .EXAMPLE
            Get-DbaClientAlias | Remove-DbaClientAlias

            Removes all SQL Server client aliases on the local computer
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [DbaInstanceParameter[]]$ComputerName = $env:COMPUTERNAME,
        [PSCredential]$Credential,
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('AliasName')]
        [string[]]$Alias,
        [Alias('Silent')]
        [switch]$EnableException
    )

    begin {
        $scriptblock = {
            $Alias = $args

            $basekeys = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSSQLServer", "HKLM:\SOFTWARE\Microsoft\MSSQLServer"

            foreach ($basekey in $basekeys) {
                $fullKey = "$basekey\Client\ConnectTo"
                if ((Test-Path $fullKey) -eq $false) {
                    Write-Warning "Registry key ($fullKey) does not exist. Quitting."
                    continue
                }

                if ($basekey -like "*WOW64*") {
                    $architecture = "32-bit"
                }
                else {
                    $architecture = "64-bit"
                }

                $all = Get-Item -Path $fullKey
                foreach ($entry in $all) {
                    $e = $entry.ToString().Replace('HKEY_LOCAL_MACHINE', 'HKLM:\')
                    foreach ($a in $Alias) {
                        if ($entry.Property -contains $a) {
                            Remove-ItemProperty -Path $e -Name $a

                            [PSCustomObject]@{
                                ComputerName = $computer
                                Architecture = $architecture
                                Alias        = $a
                                Status       = "Removed"
                            }
                        }
                    }
                }
            }
        }
    }

    process {
        foreach ($computer in $ComputerName) {
            $null = Test-ElevationRequirement -ComputerName $computer -Continue

            if ($PSCmdlet.ShouldProcess("$($Alias -join ', ') on $computer", "Remove aliases")) {
                try {
                    Invoke-Command2 -ComputerName $computer -Credential $Credential -ScriptBlock $scriptblock -ErrorAction Stop -Verbose:$false -ArgumentList $Alias
                }
                catch {
                    Stop-Function -Message "Failure" -ErrorRecord $_ -Target $computer -Continue
                }
            }
        }
    }
}