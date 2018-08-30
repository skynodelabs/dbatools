function Copy-DbaAgentProxyAccount {
    <#
        .SYNOPSIS
            Copy-DbaAgentProxyAccount migrates proxy accounts from one SQL Server to another.

        .DESCRIPTION
            By default, all proxy accounts are copied. The -ProxyAccounts parameter is auto-populated for command-line completion and can be used to copy only specific proxy accounts.

            If the associated credential for the account does not exist on the destination, it will be skipped. If the proxy account already exists on the destination, it will be skipped unless -Force is used.

        .PARAMETER Source
            Source SQL Server. You must have sysadmin access and server version must be SQL Server version 2000 or higher.

        .PARAMETER SourceSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Destination
            Destination SQL Server. You must have sysadmin access and the server must be SQL Server 2000 or higher.

        .PARAMETER DestinationSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER ProxyAccount
            Only migrate specific proxy accounts
    
        .PARAMETER ExcludeProxyAccount
            Migrate all proxy accounts except the ones explicitly excluded
    
        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .PARAMETER Force
            If this switch is enabled, the Operator will be dropped and recreated on Destination.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Migration, Agent
            Author: Chrissy LeMaire (@cl), netnerds.net
            Requires: sysadmin access on SQL Servers

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Copy-DbaAgentProxyAccount

        .EXAMPLE
            Copy-DbaAgentProxyAccount -Source sqlserver2014a -Destination sqlcluster

            Copies all proxy accounts from sqlserver2014a to sqlcluster using Windows credentials. If proxy accounts with the same name exist on sqlcluster, they will be skipped.

        .EXAMPLE
            Copy-DbaAgentProxyAccount -Source sqlserver2014a -Destination sqlcluster -ProxyAccount PSProxy -SourceSqlCredential $cred -Force

            Copies only the PSProxy proxy account from sqlserver2014a to sqlcluster using SQL credentials for sqlserver2014a and Windows credentials for sqlcluster. If a proxy account with the same name exists on sqlcluster, it will be dropped and recreated because -Force was used.

        .EXAMPLE
            Copy-DbaAgentProxyAccount -Source sqlserver2014a -Destination sqlcluster -WhatIf -Force

            Shows what would happen if the command were executed using force.
    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true)]
        [DbaInstanceParameter]$Source,
        [PSCredential]$SourceSqlCredential,
        [parameter(Mandatory = $true)]
        [DbaInstanceParameter[]]$Destination,
        [PSCredential]$DestinationSqlCredential,
        [string[]]$ProxyAccount,
        [string[]]$ExcludeProxyAccount,
        [switch]$Force,
        [Alias('Silent')]
        [switch]$EnableException
    )
    begin {
        try {
            Write-Message -Level Verbose -Message "Connecting to $Source"
            $sourceServer = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential -MinimumVersion 9
        }
        catch {
            Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $Source
            return
        }
        $serverProxyAccounts = $sourceServer.JobServer.ProxyAccounts
        if ($ProxyAccount) {
            $serverProxyAccounts | Where-Object Name -in $ProxyAccount
        }
        if ($ExcludeProxyAccount) {
            $serverProxyAccounts | Where-Object Name -notin $ProxyAccount
        }
    }
    process {
        if (Test-FunctionInterrupt) { return }
        foreach ($destinstance in $Destination) {
            try {
                Write-Message -Level Verbose -Message "Connecting to $destinstance"
                $destServer = Connect-SqlInstance -SqlInstance $destinstance -SqlCredential $DestinationSqlCredential -MinimumVersion 9
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $destinstance -Continue
            }
            
            $destProxyAccounts = $destServer.JobServer.ProxyAccounts
            
            foreach ($account in $serverProxyAccounts) {
                $proxyName = $account.Name
                
                $copyAgentProxyAccountStatus = [pscustomobject]@{
                    SourceServer = $sourceServer.Name
                    DestinationServer = $destServer.Name
                    Name         = $null
                    Type         = "Agent Proxy"
                    Status       = $null
                    Notes        = $null
                    DateTime     = [Sqlcollaborative.Dbatools.Utility.DbaDateTime](Get-Date)
                }
                
                # Proxy accounts rely on Credential accounts
                $credentialName = $account.CredentialName
                $copyAgentProxyAccountStatus.Name = $credentialName
                $copyAgentProxyAccountStatus.Type = "Credential"
                
                try {
                    $credentialtest = $destServer.Credentials[$CredentialName]
                }
                catch {
                    # don't care
                }
                
                if ($null -eq $credentialtest) {
                    $copyAgentProxyAccountStatus.Status = "Skipped"
                    $copyAgentProxyAccountStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                    Write-Message -Level Verbose -Message "Associated credential account, $CredentialName, does not exist on $destinstance. Skipping migration of $proxyName."
                    continue
                }
                
                if ($destProxyAccounts.Name -contains $proxyName) {
                    $copyAgentProxyAccountStatus.Name = $proxyName
                    $copyAgentProxyAccountStatus.Type = "ProxyAccount"
                    
                    if ($force -eq $false) {
                        $copyAgentProxyAccountStatus.Status = "Skipped"
                        $copyAgentProxyAccountStatus
                        Write-Message -Level Verbose -Message "Server proxy account $proxyName exists at destination. Use -Force to drop and migrate."
                        continue
                    }
                    else {
                        if ($Pscmdlet.ShouldProcess($destinstance, "Dropping server proxy account $proxyName and recreating")) {
                            try {
                                Write-Message -Level Verbose -Message "Dropping server proxy account $proxyName"
                                $destServer.JobServer.ProxyAccounts[$proxyName].Drop()
                            }
                            catch {
                                $copyAgentProxyAccountStatus.Status = "Failed"
                                $copyAgentProxyAccountStatus.Notes = "Could not drop"
                                $copyAgentProxyAccountStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                                Stop-Function -Message "Issue dropping proxy account" -Target $proxyName -ErrorRecord $_ -Continue
                            }
                        }
                    }
                }
                
                if ($Pscmdlet.ShouldProcess($destinstance, "Creating server proxy account $proxyName")) {
                    $copyAgentProxyAccountStatus.Name = $proxyName
                    $copyAgentProxyAccountStatus.Type = "ProxyAccount"
                    
                    try {
                        Write-Message -Level Verbose -Message "Copying server proxy account $proxyName"
                        $sql = $account.Script() | Out-String
                        Write-Message -Level Debug -Message $sql
                        $destServer.Query($sql)
                        
                        # Will fixing this misspelled status cause problems downstream?
                        $copyAgentProxyAccountStatus.Status = "Successful"
                        $copyAgentProxyAccountStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                    }
                    catch {
                        $exceptionstring = $_.Exception.InnerException.ToString()
                        if ($exceptionstring -match 'subsystem') {
                            $copyAgentProxyAccountStatus.Status = "Skipping"
                            $copyAgentProxyAccountStatus.Notes = "Failure"
                            $copyAgentProxyAccountStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                            
                            Write-Message -Level Verbose -Message "One or more subsystems do not exist on the destination server. Skipping that part."
                        }
                        else {
                            $copyAgentProxyAccountStatus.Status = "Failed"
                            $copyAgentProxyAccountStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                            
                            Stop-Function -Message "Issue creating proxy account" -Target $proxyName -ErrorRecord $_
                        }
                    }
                }
            }
        }
    }
    end {
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Copy-SqlProxyAccount
    }
}
