<#
    .COPYRIGHT
     Copyright (c) Microsoft. All Rights Reserved.     Information Contained Herein is Proprietary and Confidential.     Microsoft makes no warranties, express or implied.     This code can only be used if authorized by Microsoft.   
    
    .SYNOPSIS
        This script allocates machine objects in a given OU to groups in a given OU with the same base name using the last letter of the computed hash

    .DESCRIPTION
        Machine objects in the specified OU will have their hash values computed and be added as members of a group based on the last letter of the hash. 
        The groups will be determined by groups with a base prefix in a specified OU
        
    ===============
    Version Control
    ===============
    Ver #: 0.0.1
    Modified By: Kieran Bhardwaj
    Date Modified: 02/06/2020		
    Details: kieran.bhardwaj@microsoft.com	 
    ===============
    End Version Control
#>

Param (
    [Parameter(Mandatory=$true)]
    [string]
    $MachineDN,

    [Parameter(Mandatory=$true)]
    [string]
    $GroupNameBase,

    [Parameter(Mandatory=$true)]
    [string]
    $GroupDN
)

######################################################################################################################
#  Functions
######################################################################################################################

Function Load-Module
{
<#
    .SYNOPSIS
    Loads a system module
    .DESCRIPTION
    Checks a module exists and then loads it into the PowerShell environment
    .PARAMETER Name
    The name of the module to be loaded
#>
    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $result = $true

    If(Get-Module -ListAvailable | Where-Object { $_.name -eq $name }) { 
        Import-Module -Name $name 
    }else{
        $result =  $false 
    }  

    return $result
}

Function Write-Log
{  
<#
    .SYNOPSIS
    Write messages to the log file
    .DESCRIPTION
    Write a message to the global log file including a timestamp
    .PARAMETER Msg
    Message to be written to log file
#>
    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $Msg
    )

    $date = Get-Date -format dd.MM.yyyy  
    $time = Get-Date -format HH:mm:ss  
    Add-Content -Path $Global:LogFile -Value ($date + " " + $time + "   " + $Msg)  
}

Function Log
{
<#
    .SYNOPSIS
    Handles errors and information messages
    .DESCRIPTION
    Write a message to the logging locations and to the user screen.
    .PARAMETER Type
    If the message is error (ERR) or information (INFO) or success (SUCC)
    .PARAMETER Text
    Message text
#>
    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string]
        $Text
    )

    # If error use red text
    if($type -eq "ERR"){
        $msg = "Error: " + $text
        Write-Log $msg
        Write-Host -ForegroundColor Red $msg
    }

    # If info use blue text
    if($type -eq "INFO"){
        $msg = "Information: " + $text
        Write-Log $msg
        Write-Host -ForegroundColor Cyan $msg
    }

    # If success use green text
    if($type -eq "SUCC"){
        $msg = "Success: " + $text
        Write-Log $msg
        Write-Host -ForegroundColor Green $msg
    }
}

Function Compute-Hash
{
<#
    .SYNOPSIS
        Computes the hash value of an input string
    .DESCRIPTION
        Computers the hash value of a given input string using a specified algorithm
    .PARAMETER ClearText
        The input string
    .PARAMETER Algorthim
        The hash algorimth to be used - defaults to 'sha256' if unsupplied
#>
    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $ClearText,

        [Parameter()]
        [string]
        $Algorthim = 'sha256'
    )

    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($Algorthim)
    $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($ClearText))

    $hashString = ([System.BitConverter]::ToString($hash)).Replace('-', '')
    
    return $hashString
}

######################################################################################################################
# Main
######################################################################################################################

# Start Logging.
$dateTime=get-date -format s
$dateTime=$dateTime -replace ":","_"
$dateTime=$dateTime.ToString()
$Global:logFile=$PSScriptRoot + "\WECGM_$dateTime.log"
Log "INFO" ("Log File Name is " + $GLOBAL:logFile)

# Import Modules
Log "INFO" "Loading ActiveDirectory Module"
if ((Load-Module -Name "ActiveDirectory") -eq $True){
    Log "SUCC" "Loaded ActiveDirectory Module"
}else{
    Log "ERR" "Failed to load ActiveDirectory Module"
}

$groups = Get-ADGroup -Filter "GroupCategory -eq 'Security' -and Name -like '$($GroupNameBase)*'" -SearchBase $GroupDN | Select -Property Name
Log "INFO" "Retrieved $($groups.count) groups from Active Directory."

$groupMembers = @{}
foreach($item in $groups){
    $members = Get-ADGroupMember -Identity $item.Name -Recursive | Select -ExpandProperty Name
    $groupMembers.Add($item.Name, $members)
    Log "INFO" "Retrieved $($members.count) members for group named $($item.Name)."
}

$machines = Get-ADComputer -Filter * -SearchBase $MachineDN | Select -Property Name, SID

Log "INFO" "Retrieved $($machines.count) machines from Active Directory."

foreach($item in $machines){
    $item | Add-Member -NotePropertyName Hash -NotePropertyValue (Compute-Hash -ClearText $item.Name)
    $item | Add-Member -NotePropertyName GroupAssigned -NotePropertyValue ($GroupNameBase+($item.Hash).Substring($item.Hash.length - 1,1))
    Log "INFO" "Machine $($item.Name) is assigned group $($item.GroupAssigned)."

    if($groupMembers[$item.GroupAssigned] -contains $item.Name) {
        Log "INFO" "Machine $($item.Name) is a member group $($item.GroupAssigned)."
    }else{
        Log "INFO" "Adding machine $($item.Name) to group $($item.GroupAssigned)...."
        Get-ADGroup -Filter "Name -eq '$($item.GroupAssigned)'" -SearchBase $GroupDN | Add-ADGroupMember -Members $item.SID

        $result = Get-ADGroupMember -Identity $item.GroupAssigned -Recursive | Where{$_.Name -eq $item.Name}
        if($result){
            Log "SUCC" "Machine $($item.Name) added to group $($item.GroupAssigned)."
        }else{
            Log "ERR" "Failed to add machine $($item.Name) to group $($item.GroupAssigned)."
        }
    }
}