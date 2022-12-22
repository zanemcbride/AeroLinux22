#!/bin/bash

#  -----------------------------------------------------------------
# |This script installs the necessary packages on a Linux system    |
# | It includes a Python installation to operate a modem	    |
# | The script is meant to run once, running again will add new user|
# | Author: anthony.d.larosa@nasa.gov				    |
#  -----------------------------------------------------------------
user_var=$(logname)

if [ `id -u` -ne 0 ]; then
	echo "Please execute this installer script with sudo, exiting.."
	exit 1
fi

echo "Setting system's timezone to UTC."
timedatectl set-timezone Etc/UTC
sleep 1

echo "setting keymap to FREEDOM edition" 
localectl set-keymap us 
sleep 1

echo "installing pre-reqs" 
apt-get install -y libcurl4-openssl-dev 
apt-get install -y chrony
apt-get install -y libqmi-utils udhcpc
#apt install -y ip 
#apt install -y pppd
if [[ $> 0 ]]
then
	echo "libcurl and recs failed to install, exiting."
else
	echo "Dependencies are installed, continuing with script."
fi
sleep 1 

echo "Installing Log2RAM, reduce SD wear and corruption rate" 
curl -L https://github.com/azlux/log2ram/archive/master.tar.gz | tar zxf -
cd log2ram-master
chmod +x install.sh && sudo ./install.sh
cd ..
rm -r log2ram-master
sleep 1

getent group sudo | grep -q "$user_var"
if [ $? -eq 0 ]; then
	echo "$user_var has root privileges, continuing..."
else
	echo "Adding using to root failed...Try a new username?" 1>&2
	exit 1
fi

echo "$user_var	ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "workaround for dialout issues that occur sometimes for unknown reasons" 
usermod -a -G dialout $user_var
usermod -a -G tty $user_var
sleep 1
echo "De-yeeting Hologram SDK..."
sleep 1 
systemctl disable ModemManager.service
echo "pest control completed; removed ModemManager"
sleep 1
echo "moving UDEV rule to final resting place"
mv 99-QualcommModem.rules /etc/udev/rules.d 
mv 00-ModemWDM.rules /etc/udev/rules.d
sleep 1
echo "Setting up modem sleep service on shutdown" 
mv ModemSleep.service /etc/systemd/system/
systemctl enable ModemSleep.service
chmod +x /scripts/ModemSleep.sh

echo "Setup of network start/stop symlinks"
chmod +x /scripts/GSM-Up 
chmod +x /scripts/GSM-Down 
echo "alias GSM-Up="bash /home/$USER/AeroLinux22/scripts/GSM-Up"" >> ~/.bash_aliases
echo "alias GSM-Down="bash /home/$USER/AeroLinux22/scripts/GSM-Down"" >> ~/.bash_aliases
#jank way of shutting down modem on shutdown, not optimal but it works
echo "alias shutdown="sudo qmicli -d /dev/ModemWDM --dms-set-operating-mode=low-power; shutdown -h now"" >> ~/.bash_aliases
echo "if [ -f ~/.bash_aliases ]; then" >> ~/.bash_aliases
echo ". ~/.bash_aliases" >> ~/.bash_aliases
echo "fi" >> ~/.bash_aliases
source ~/.bash_aliases
# echoes into bash alias for testing


sleep 1
echo "Setting NTP using chrony" 
chronyc makestep 

#echo "Setting raw-ip enable perms" 
#chmod g+w /sys/class/net/wwan0/qmi/* 
#sleep 1

echo "Adding cronjobs to user's crontab"
crontab -r
cronjob1="@reboot sleep 60 && /home/$user_var/AeroLinux22/scripts/combined_pi_start_script.sh >> /home/$user_var/logs/connection.log"
cronjob2="0 0 */2 * * /home/$user_var/AeroLinux22/scripts/k7_k8_check.sh"

{ crontab -l -u $user_var 2>/dev/null; echo "$cronjob1"; } | crontab -u $user_var -
{ crontab -l -u $user_var; echo "$cronjob2"; } | crontab -u $user_var -


sleep 1
echo "Building new directories..."
sleep 1

mkdir /home/$user_var/logs #Make a log file directory
mkdir /home/$user_var/cimel_logs #Make a log directory for cimel connect output
mkdir /home/$user_var/backup #For data files saved to disk
touch /home/$user_var/logs/connection.log
touch /home/$user_var/logs/modem_diagnostics.log


sleep 1
echo "Compiling Cimel software package..."
sleep 1

cd /home/$user_var/AeroLinux22/source/
cc -o ../bin/pi_ftp_upload pi_ftp_upload.c models_port.c -lm -lcurl
cc -o ../bin/models_connect_and_reset models_connect_and_reset.c models_port.c -lm -lcurl
chown -R ${user_var}: /home/$user_var/
chmod -R 777 /home/$user_var/

sleep 1
echo "==========================="
sleep 1
echo "==========================="
echo "Build complete"
echo "Please execute a reboot to hard reload daemons and kernel changes"
#sudo reboot 
