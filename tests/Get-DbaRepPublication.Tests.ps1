$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"
. "$PSScriptRoot\..\internal\functions\Connect-SqlInstance.ps1"

Describe "$commandname Unit Tests" -Tag 'UnitTests' {

    InModuleScope dbatools {

        Context "Parameter Validation" {

            [object[]]$params = (Get-ChildItem function:\Get-DbaRepPublication).Parameters.Keys
            $knownParameters = 'SqlInstance', 'Database', 'SqlCredential', 'PublicationType', 'EnableException'
            $paramCount = $knownParameters.Count
            $defaultParamCount = $params.Count - $paramCount

            It "Should contain our specific parameters" {
                ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
            }

            It "Should only contain $paramCount parameters" {
                $params.Count - $defaultParamCount | Should Be $paramCount
            }

        }

        Context "Code Validation" {

            Mock Connect-ReplicationDB -MockWith {
                [object]@{
                    Name = 'TestDB'
                    TransPublications = @{
                        Name = 'TestDB_pub'
                        Type = 'Transactional'
                    }
                    MergePublications = @{}
                }
            }

            Mock Connect-SqlInstance -MockWith {
                [object]@{
                    Name      = "MockServerName"
                    ComputerName   = 'MockComputerName'
                    Databases = @{
                                    Name = 'TestDB'
                                    #state
                                    #status
                                    ID = 5
                                    ReplicationOptions = 'Published'
                                }
                    ConnectionContext = @{
                                           SqlConnectionObject = 'FakeConnectionContext'
                                        }
                }
            }

            It "Honors the SQLInstance parameter" {
                $Results = Get-DbaRepPublication -SqlInstance MockServerName
                $Results.Server | Should Be "MockServerName"
            }

            It "Honors the Database parameter" {
                $Results = Get-DbaRepPublication -SqlInstance MockServerName -Database TestDB
                $Results.Database | Should Be "TestDB"
            }

            It "Honors the PublicationType parameter" {

                Mock Connect-ReplicationDB -MockWith {
                    [object]@{
                        Name = 'TestDB'
                        TransPublications = @{
                            Name = 'TestDB_pub'
                            Type = 'Snapshot'
                        }
                        MergePublications = @{}
                    }
                }

                $Results = Get-DbaRepPublication -SqlInstance MockServerName -Database TestDB -PublicationType Snapshot
                $Results.PublicationType | Should Be "Snapshot"
            }

            It "Stops if the SqlInstance does not exist" {
            
                Mock Connect-SqlInstance -MockWith { Throw }
        
                { Get-DbaRepPublication -sqlinstance MockServerName -EnableException} | should Throw
                
            }

            It "Stops if validate set for PublicationType is not met" {

                { Get-DbaRepPublication -SqlInstance MockServerName -PublicationType NotAPubType } | should Throw

            }
        }
    }
}
