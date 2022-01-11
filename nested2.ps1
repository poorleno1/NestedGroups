$computerName = "client2016"
#This can be API or WinNT
$method = "WinNT"

#install Powershell module ActiveDirectory on Win10 and Win11
#Add-WindowsCapability –online –Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

#please adjust paths
$ExportPath = "$($env:SystemDrive)\temp\$($computerName).csv"

function Get-User ($ComputerName, $MemberName, $Path)
{
    $domain = Split-Path $MemberName -Parent
    $MemberName = Split-Path $MemberName -Leaf
    $e = $null
    Write-Host "Getting AD Object $MemberName."
    try
    {
        $gr = Get-ADObject -Identity $MemberName -ErrorAction Stop -ErrorVariable e
    }
    catch [System.Management.Automation.ActionPreferenceStopException]
    {
        Throw $_.exception
    }
    catch
    {
        Throw $_.exception
    }
    
    
    $type = ($gr | select -ExpandProperty objectcategory).split(",")[0].split("=")[1]

    if ($type -eq "Group")
    {
        $CustomObj = New-Object System.Collections.Generic.List[PSObject]
        $TextInfo = (Get-Culture).TextInfo
        $e = $null
        $members = $null
        Write-Host "Getting members of AD group $MemberName."
        try
        {
            $members = Get-ADGroupMember $MemberName -ErrorAction Stop -ErrorVariable e
        }
        catch [System.Management.Automation.ActionPreferenceStopException]
        {
            Throw $_.exception
        }
        catch
        {
            Throw $_.exception
        }

        if ($members)
        {
            $count = $members | Measure-Object | select -ExpandProperty count
            Write-Host "Found $count members in $domain\$MemberName"
            
            $members | ForEach-Object {
                 $CustomObj.Add([PSCustomObject]@{
                    ComputerName = $ComputerName
                    MemberName = "$domain\$($_.name)"
                    type = $TextInfo.ToTitleCase($_.objectClass)
                    IsDomain = $true
                    FromGroup = "$domain\$MemberName"
                 })

                 if ($_.objectClass -eq "group")
                 {
                     Get-User $ComputerName "$domain\$($_.name)" $Path
                 }
            }
        }
        else
        {
            Write-Host "No members found in $domain\$MemberName."
        }
    }

    #$CustomObj | ft -AutoSize
    try
    {
        $CustomObj | Export-Csv -Path $($Path) -Append -NoTypeInformation
    }
    catch [System.Management.Automation.ActionPreferenceStopException]
    {
        Throw $_.exception
    }
    catch
    {
        Throw $_.exception
    }
    finally
    {
        Write-Host "cleaning up ..."
        if (!($CustomObj))
        {
            Write-Host "Object to be exported to CSV is empty."
        }
    }
}



if ($method -eq "API")
{
    $all = Get-NetLocalGroupMember -ComputerName $computerName -Method API    
}
elseif ($method -eq "WinNT")
{
    $all_winnt = Get-NetLocalGroupMember -ComputerName $computerName -Method WinNT
    $all = $all_winnt | select Computername,@{name="MemberName";e={$_.AccountName}},@{"name"="type";e={if($_.IsGroup){"Group"}else{"User"}}},@{"name"="IsDomain";e={if($_.IsDomain){$true}else{$false}}},@{"name"="FromGroup";e={$_.GroupName}}
}
else
{
    write-host "Unsupported qurying method."
}

#output to screen all info from client computer
$all | select Computername,Membername,@{"name"="type";e={if($_.IsGroup){"Group"}else{"User"}}},@{"name"="IsDomain";e={if($_.IsDomain){$true}else{$false}}},@{"name"="FromGroup";e={$_.GroupName}} | ft -AutoSize

#initial export to csv 
$all | select Computername,Membername,@{"name"="type";e={if($_.IsGroup){"Group"}else{"User"}}},@{"name"="IsDomain";e={if($_.IsDomain){$true}else{$false}}},@{"name"="FromGroup";e={$_.GroupName}} | Export-Csv $ExportPath -NoTypeInformation

#further analysis of domain groups and users as Get-NetLocalGroupMember is wrongly analyzing some groups
$all | select Computername,Membername,@{"name"="type";e={if($_.IsGroup){"Group"}else{"User"}}},@{"name"="IsDomain";e={if($_.IsDomain){$true}else{$false}}},@{"name"="FromGroup";e={$_.GroupName}} | Where-Object IsDomain | ForEach-Object {Get-User $_.Computername $_.Membername $ExportPath}


