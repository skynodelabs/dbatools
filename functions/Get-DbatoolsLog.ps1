﻿function Get-DbatoolsLog {
    
<#
    .SYNOPSIS
        Returns log entries for dbatools
    
    .DESCRIPTION
        Returns log entries for dbatools. Handy when debugging or developing a script using it.
    
    .PARAMETER FunctionName
        Default: "*"
        Only messages written by similar functions will be returned.
    
    .PARAMETER ModuleName
        Default: "*"
        Only messages written by commands from similar modules will be returned.
    
    .PARAMETER Target
        Only messags handling the specified target will be returned.
    
    .PARAMETER Tag
        Only messages containing one of these tags will be returned.
    
    .PARAMETER Last
        Only messages written by the last X executions will be returned.
        Uses Get-History to determine execution. Ignores Get-message commands.
        By default, this will also include messages from other runspaces. If your command executes in parallel, that's useful.
        If it doesn't and you were offloading executions to other runspaces, consider also filtering by runspace using '-Runspace'
    
    .PARAMETER Skip
        How many executions to skip when specifying '-Last'.
        Has no effect without the '-Last' parameter.
    
    .PARAMETER Runspace
        The guid of the runspace to return messages from.
        By default, messages from all runspaces are returned.
        Run the following line to see the list of guids:
        
        Get-Runspace | ft Id, Name, InstanceId -Autosize
    
    .PARAMETER Level
        Limit the message selection by level.
        Message levels have a numeric value, making it easier to select a range:
        
        -Level (1..6)
        
        Will select the first 6 levels (Critical - SomewhatVerbose).
    
    .PARAMETER Errors
        Instead of log entries, the error entries will be retrieved
    
    .EXAMPLE
        Get-DbatoolsLog
        
        Returns all log entries currently in memory.
    
    .EXAMPLE
        Get-DbatoolsLog -Target "a" -Last 1 -Skip 1
        
        Returns all log entries that targeted the object "a" in the second last execution sent.
    
    .EXAMPLE
        Get-DbatoolsLog -Tag "fail" -Last 5
        
        Returns all log entries within the last 5 executions that contained the tag "fail"
#>
    [CmdletBinding()]
    param (
        [string]
        $FunctionName = "*",
        
        [string]
        $ModuleName = "*",
        
        [AllowNull()]
        $Target,
        
        [string[]]
        $Tag,
        
        [int]
        $Last,
        
        [int]
        $Skip = 0,
        
        [guid]
        $Runspace,
        
        [Sqlcollaborative.Dbatools.Message.MessageLevel[]]
        $Level,
        
        [switch]
        $Errors
    )
    
    begin {
        
    }
    
    process {
        if ($Errors) { $messages = [Sqlcollaborative.Dbatools.Message.LogHost]::GetErrors() | Where-Object { ($_.FunctionName -like $FunctionName) -and ($_.ModuleName -like $ModuleName) } }
        else { $messages = [Sqlcollaborative.Dbatools.Message.LogHost]::GetLog() | Where-Object { ($_.FunctionName -like $FunctionName) -and ($_.ModuleName -like $ModuleName) } }
        
        if (Test-Bound -ParameterName Target) {
            $messages = $messages | Where-Object TargetObject -EQ $Target
        }
        
        if (Test-Bound -ParameterName Tag) {
            $messages = $messages | Where-Object { $_.Tags | Where-Object { $_ -in $Tag } }
        }
        
        if (Test-Bound -ParameterName Runspace) {
            $messages = $messages | Where-Object Runspace -EQ $Runspace
        }
        
        if (Test-Bound -ParameterName Last) {
            $history = Get-History | Where-Object CommandLine -NotLike "Get-DbatoolsLog*" | Select-Object -Last $Last -Skip $Skip
            $start = $history[0].StartExecutionTime
            $end = $history[-1].EndExecutionTime
            
            $messages = $messages | Where-Object { ($_.Timestamp -gt $start) -and ($_.Timestamp -lt $end) -and ($_.Runspace -eq ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InstanceId)) }
        }
        
        if (Test-Bound -ParameterName Level) {
            $messages = $messages | Where-Object Level -In $Level
        }
        
        return $messages
    }
    
    end {
        
    }
}
