# Powershell - Scan IP Range Quickly with Multithreading
![ip_scan.ps1 demo recording](http://virasawmi.com/gordon/powershell/ip_scan/ip_scan-demo.gif)

This script scans an IP range very quickly. I use this to scan big networks. The graphic is in realtime. It takes maybe 3 minutes to find 900 computers on bigger networks.

The script returns IP, DNS, and MAC entries.

Although slower, I've found this script to be more dependable than AD's computer list and Powershell's Get-NetNeighbor scan.

Please remember to edit/input your subnet range at line 38. This script doesn't autodetect your subnet mask and what IP you are using. .

