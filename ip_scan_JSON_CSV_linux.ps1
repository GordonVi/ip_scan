<#
.SYNOPSIS
  Scan an IP range and report how many IPs are alive.
  
.DESCRIPTION
  Uses Multi Threading and only 1 ping to accomplish the task faster. (Inspired by Angry IP SCanner)

.PARAMETER <Parameter_Name>
   In the top of the script, set your IP ranges. You can scan multiple ranges. Handy for corporate nets.
	
.INPUTS
  None
  
.OUTPUTS
  Text to CLI console out
  Text to a TimeStamp.JSON file
  
.NOTES
  Version:        1.02
  Author:         Gordon Virasawmi
  GitHub:         https://github.com/GordonVi/ip_scan/
  Creation Date:  9/23/2022 @ 10:08am
  Purpose/Change: Added JSON Logging
  License:        Free for all. Too simple to charge for. Too important to not publish.
  Works Cited:    Runspaces Simplified - https://blog.netnerds.net/2016/12/runspaces-simplified/
  
.EXAMPLE
  .\ip_scan_JSON.ps1
     (Type this in the Powershell CLI or Right Click and Run from Windows GUI)
  
#>

# --------------------------------------------------

$TimeStart = $(Get-Date -UFormat "%H:%M:%S")

$threads = 1000 # how many simultanious threads. I've tested up to 1000 ok against ~3600 local IPs, ~900 active.

$list = for ($a=0; $a -le 255; $a++) # set the last octlet range
			{
					 "10.134.225.$a" # Manually add subnets, or create a $b to scan more.
					 "10.134.226.$a" # Manually add subnets, or create a $b to scan more.
					 "10.134.227.$a" # Manually add subnets, or create a $b to scan more.
			}

# --------------------------------------------------
	
clear

""
write-host "       Threads: " -nonewline -foregroundcolor yellow
$threads
"    Build Pool: "
"    Drain Pool: "
" ---------------------"
write-host "   Total Hosts: $($list.count)"
write-host "   Alive Hosts: "
write-host "    Dead Hosts: "


# BLOCK 1: Create and open runspace pool, setup runspaces array with min and max threads
$pool = [RunspaceFactory]::CreateRunspacePool(1, $threads)
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = $results = @()

# --------------------------------------------------
    
# BLOCK 2: Create reusable scriptblock. This is the workhorse of the runspace. Think of it as a function.
$scriptblock = {
    Param (
    [string]$ip
    )

	$ping=Test-Connection -ComputerName $ip -Count 1
	if ($ping.status -eq "Success") {
	
							$DNS=([System.Net.Dns]::GetHostByAddress($ip)).Hostname
							$mac=$($(arp -a $ip).split(" "))[3]
							#$mac=$(get-netneighbor -ipaddress $ip).LinkLayerAddress
							
							} else {

							$DNS=""
							$mac=""
							}
       
    # return whatever you want, or don't.
    return [pscustomobject][ordered]@{
								ip 		= $ip
								ping	= $ping.status
								DNS		= $DNS
								MAC		= $mac
							}
}

# --------------------------------------------------
 
# BLOCK 3: Create runspace and add to runspace pool
$counter=0
foreach ($ip in $list) {
 
    $runspace = [PowerShell]::Create()
    $null = $runspace.AddScript($scriptblock)
    $null = $runspace.AddArgument($ip)

    $runspace.RunspacePool = $pool
 
# BLOCK 4: Add runspace to runspaces collection and "start" it
    # Asynchronously runs the commands of the PowerShell object pipeline
    $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }

	$Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 16 , 2
	$counter++
	write-host "$counter " -nonewline
}

# --------------------------------------------------
 
# BLOCK 5: Wait for runspaces to finish

<#

do {

	$Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 5 , 9
	$cnt = ($runspaces | Where {$_.Result.IsCompleted -ne $true}).Count
	write-host "$cnt   "
	
	} while ($cnt -gt 0)

#>

# --------------------------------------------------

$total=$counter
$counter=0

# BLOCK 6: Clean up
foreach ($runspace in $runspaces ) {
    # EndInvoke method retrieves the results of the asynchronous call
    $results += $runspace.Pipe.EndInvoke($runspace.Status)
    $runspace.Pipe.Dispose()
	
	$Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 16 , 3
	$counter++
	write-host "$($total-$counter) " -nonewline

}
    
$pool.Close() 
$pool.Dispose()

# --------------------------------------------------
 
# Bonus block 7
# Look at $results to see any errors or whatever was returned from the runspaces

# Use this to output to JSON. CSV works too since it's simple data.
# $results | convertto-json -depth 10 > ip_scan.json

$total=$results.count
$alive = $($results | ? {$_.ping -eq "Success"}).count
$dead = $($results | ? {$_.ping -ne "Success"}).count

$Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0 , 5

write-host "   Total Hosts: " -nonewline -foregroundcolor cyan
$total

write-host "   Alive Hosts: " -nonewline -foregroundcolor green
$alive

write-host "    Dead Hosts: " -nonewline -foregroundcolor magenta
$dead

"  ---------------------"

# Block 8
# Write the dated JSON

  #$results | ? {$_.ping -eq "true"} | select ip,DNS,MAC | sort ip | out-host

$filename = $(Get-Date -UFormat "%Y-%m-%d_%H-%M-%S")
$filename = "$filename"
$nodes=@()

foreach ($node in $($results | ? {$_.ping -eq "Success"} | select ip,DNS,MAC | sort-object -Property ip, DNS, MAC -Descending)) {
	
	$nodes +=  [PsCustomObject]@{
		IP = $node.IP
		MAC = $node.mac
		DNS = $node.dns
		}
}


$jsonobject = [pscustomobject]@{

		Name = "IP Scan"
		Date = $(Get-Date -UFormat "%Y-%m-%d")
		TimeStart = $TimeStart
		TimeEnd = $(Get-Date -UFormat "%H:%M:%S")
		Threads = $threads
		Total = $total
		Alive = $alive
		Dead = $dead
		Nodes = $nodes
}

$jsonobject | ConvertTo-Json | Out-File -FilePath ".\$filename.JSON"
$results | ? {$_.ping -eq "Success"} | select IP,DNS,MAC | ConvertTo-CSV | Out-File -FilePath ".\$filename.CSV"


