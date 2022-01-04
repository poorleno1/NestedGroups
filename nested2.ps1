$computerName = "client2016"

#please adjust paths
$ExportPath = "$($env:SystemDrive)\temp\$($computerName).csv"

$all = Get-NetLocalGroupMember -ComputerName $computerName -Method API

#output to screen all info from client computer
$all | select Computername,Membername,@{"name"="type";e={if($_.IsGroup){"Group"}else{"User"}}},@{"name"="IsDomain";e={if($_.IsDomain){$true}else{$false}}},@{"name"="FromGroup";e={$_.GroupName}} | ft -AutoSize

#initial export to csv 
$all | select Computername,Membername,@{"name"="type";e={if($_.IsGroup){"Group"}else{"User"}}},@{"name"="IsDomain";e={if($_.IsDomain){$true}else{$false}}},@{"name"="FromGroup";e={$_.GroupName}} | Export-Csv $ExportPath -NoTypeInformation

#further analysis of domain groups and users as Get-NetLocalGroupMember is wrongly analyzing some groups
$all | select Computername,Membername,@{"name"="type";e={if($_.IsGroup){"Group"}else{"User"}}},@{"name"="IsDomain";e={if($_.IsDomain){$true}else{$false}}},@{"name"="FromGroup";e={$_.GroupName}} | Where-Object IsDomain | ForEach-Object {Get-User $_.Computername $_.Membername $ExportPath}


function Get-User ($ComputerName, $MemberName, $Path)
{
    $domain = Split-Path $MemberName -Parent
    $MemberName = Split-Path $MemberName -Leaf
    $gr = Get-ADObject -Identity $MemberName 
    $type = ($gr | select -ExpandProperty objectcategory).split(",")[0].split("=")[1]

    if ($type -eq "Group")
    {
        $CustomObj = New-Object System.Collections.Generic.List[PSObject]
        $TextInfo = (Get-Culture).TextInfo
        Get-ADGroupMember $MemberName  | ForEach-Object {
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

    #$CustomObj | ft -AutoSize
    $CustomObj | Export-Csv -Path $($Path) -Append -NoTypeInformation
}