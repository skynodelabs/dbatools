﻿$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $null = New-DbaClientAlias -ServerName sql2016 -Alias dbatoolscialias1 -Verbose:$false
        $null = New-DbaClientAlias -ServerName sql2016 -Alias dbatoolscialias2 -Verbose:$false
        $null = New-DbaClientAlias -ServerName sql2016 -Alias dbatoolscialias3 -Verbose:$false
        $null = New-DbaClientAlias -ServerName sql2016 -Alias dbatoolscialias4 -Verbose:$false
        $null = New-DbaClientAlias -ServerName sql2016 -Alias dbatoolscialias5 -Verbose:$false
    }

    InModuleScope 'dbatools' {
        Context "removes the alias" {
            $aliases = Get-DbaClientAlias
            It "alias exists" {
                $aliases.AliasName -contains 'dbatoolscialias1' | Should Be $true
            }

            $null = Remove-DbaClientAlias -Alias dbatoolscialias1 -Verbose:$false

            $aliases = Get-DbaClientAlias
            It "alias is not included in results" {
                $aliases.AliasName -notcontains 'dbatoolscialias1' | Should Be $true
            }
        }

        Context "removes an array of aliases" {
            $testCases = @(
                @{'Alias' = 'dbatoolscialias2'},
                @{'Alias' = 'dbatoolscialias3'}
            )

            $aliases = Get-DbaClientAlias
            It "alias <Alias> exists" -TestCases $testCases {
                param ($Alias)

                $aliases.AliasName -contains $Alias | Should Be $true
            }

            $null = Remove-DbaClientAlias -Alias @('dbatoolscialias2', 'dbatoolscialias3')

            $aliases = Get-DbaClientAlias
            It "alias <Alias> was removed" -TestCases $testCases {
                param ($Alias)

                $aliases.AliasName -notcontains $Alias | Should Be $true
            }
        }

        Context "removes an alias through the pipeline" {
            $aliases = Get-DbaClientAlias
            It "alias exists" {
                $aliases.AliasName -contains 'dbatoolscialias4' | Should Be $true
            }

            $null = Get-DbaClientAlias | Where-Object { $_.AliasName -eq 'dbatoolscialias4' } | Remove-DbaClientAlias
            $aliases = Get-DbaClientAlias
            It "alias was removed" {
                $aliases.AliasName -notcontains 'dbatoolscialias4' | Should Be $true
            }
        }

        Context "SQL client is not installed" {
            Mock -CommandName 'Test-Path' -MockWith {
                return $false
            }

            $defaultParamValues = $PSDefaultParameterValues
            $PSDefaultParameterValues=@{"*:WarningVariable"="+buffer"}

            $null = Remove-DbaClientAlias -Alias 'dbatoolscialias5' -WarningAction 'SilentlyContinue'

            $PSDefaultParameterValues = $defaultParamValues

            It "warns that the key doesn't exist" {
                $buffer.Count -ge 4 | Should -Be $true
            }
        }
    }
}