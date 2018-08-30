function Get-DbaRepPublication {
    <#
    .SYNOPSIS
    Displays all publications for a server or database.

    .DESCRIPTION
    Quickly find all transactional, merge, and snapshot publications on a specific server or database.

    .PARAMETER SqlInstance
    Allows you to specify a comma separated list of servers to query.

    .PARAMETER Database
    The database(s) to process. If unspecified, all databases will be processed.

    .PARAMETER SqlCredential
    Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER PublicationType
    Limit by specific type of publication. Valid choices include: Transactional, Merge, Snapshot

    .PARAMETER EnableException
    By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
    This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
    Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
    Author: Colin Douglas
    Tags: Replication

    Website: https://dbatools.io
    Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
    License: MIT https://opensource.org/licenses/MIT

    .LINK
    https://dbatools.io/Get-DbaRepPublication

    .EXAMPLE
    Get-DbaRepPublication -SqlInstance sql2008, sqlserver2012
    Return all publications for servers sql2008 and sqlserver2012.

    .EXAMPLE
    Get-DbaRepPublication -SqlInstance sql2008 -Database TestDB
    Return all publications on server sql2008 for only the TestDB database

    .EXAMPLE
    Get-DbaRepPublication -SqlInstance sql2008 -PublicationType Transactional
    Return all publications on server sql2008 for all databases that have Transactional publications
#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [DbaInstanceParameter[]]$SqlInstance,
        [object[]]$Database,
        [PSCredential]$SqlCredential,
        [ValidateSet("Transactional", "Merge", "Snapshot")]
        [object[]]$PublicationType,
        [switch]$EnableException
    )

    process {

        foreach ($instance in $SqlInstance) {

            # Connect to Publisher
            try {
                Write-Message -Level Verbose -Message "Connecting to $instance"
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential -MinimumVersion 9
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            $dbList = $server.Databases

            if ($Database) {
                $dbList = $dbList | Where-Object name -in $Database
            }

            $dbList = $dbList | Where-Object { ($_.ID -gt 4) -and ($_.status -ne "Offline") }


            foreach ($db in $dbList) {

                if (($db.ReplicationOptions -ne "Published") -and ($db.ReplicationOptions -ne "MergePublished")) {
                    Write-Message -Level Verbose -Message "Skipping $($db.name). Database is not published."
                }

                $repDB = Connect-ReplicationDB -Server $server -Database $db

                $pubTypes = $repDB.TransPublications + $repDB.MergePublications

                if ($PublicationType) {
                    $pubTypes = $pubTypes | Where-Object Type -in $PublicationType
                }

                foreach ($pub in $pubTypes) {

                    [PSCustomObject]@{
                        ComputerName = $server.ComputerName
                        InstanceName = $server.InstanceName
                        SqlInstance  = $server.SqlInstance
                        Server = $server.name
                        Database = $db.name
                        PublicationName = $pub.Name
                        PublicationType = $pub.Type
                    }
                }
            }
        }
    }
}
