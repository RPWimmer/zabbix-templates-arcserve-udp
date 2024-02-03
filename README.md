# zabbix-templates-arcserve-udp
Zabbix-Templates Arcserve UDP

This template checks out-of-the-box only VM Backups from Arcserve UDP.
This script only counts the number of successful or unsuccessful backup jobs and  throws a trigger if necessary.

Installation steps für Arcserve UDP VM Backup checks:

1. Copy the script file "Arcserve_UDP_VMCount.ps1" to your Zabbix Agent Script folder on the Arcserve UDP Host.
2. Modify script parameter if necessary (protocol, port, JobID)
3. Test the script manually on the Arcserve UDP Host:
   .\Arcserve_UDP_VMCount.ps1 <domain> <username> '<password>' JobSuccessCount <hostname or ip>
5. For debugging of errors you can enable "$Debug=$True" in the script.
6. Check the script for correct results of the VM backup jobs.
7. Add the UserParameter to the zabbix_agentd.conf:
   UserParameter=custom.arcserveudpvm[*],powershell.exe -NoProfile -ExecutionPolicy Bypass -file "C:\Program Files\Zabbix Agent\Scripts\Arcserve_UDP_VMCount.ps1" $1 $2 '$3' $4 $5
6. Import des Zabbix Template "Template_Arcserve UDP VM Backup Check.xml" to the Zabbix Server.
7. Assign the template to the Zabbix host for ARcserve UDP.
7. Modify the macro "{$ARCSERVE_DOMAIN}", "{$ARCSERVE_USER}" and "{$ARCSERVE_PASS}" with the read only user login for Arcserve UDP.
8. Check the latest value of application "ArcserveUDP Jobs".
