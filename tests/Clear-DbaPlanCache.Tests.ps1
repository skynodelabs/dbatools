﻿$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tag "IntegrationTests" {
    Context "doesn't clear plan cache" {
        It "returns correct datatypes" {
            # Make plan cache way higher than likely for a test rig
            $results = Clear-DbaPlanCache -SqlInstance $script:instance1 -Threshold 10240
            $results.Size -is [dbasize] | Should -Be $true
            $results.Status -match 'below' | Should -Be $true
        }
        It "supports piping" {
            # Make plan cache way higher than likely for a test rig
            $results = Get-DbaPlanCache -SqlInstance $script:instance1 | Clear-DbaPlanCache -Threshold 10240
            $results.Size -is [dbasize] | Should -Be $true
            $results.Status -match 'below' | Should -Be $true
        }
    }
}