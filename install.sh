#!/bin/bash
#####################################################################
# This script will install community edition of gitlab on this server
#####################################################################
# Start of user inputs
SELFSIGNEDCERT="yes"
#SELFSIGNEDCERT="no"
SERVERFQDN="garfield99991.mylabserver.com"

# Firewalld should be up and running to make changes
FIREWALL="yes"
FIREWALL="no"
# End of user inputs
#####################################################################

if [[ $EUID != 0 ]]
then
	echo
	echo "##########################################################"
	echo "ERROR. You need to have root privileges to run this script"
	exit 1
	echo "##########################################################"
else
	echo
	echo "##############################################"
	echo "This script will install gitlab on this server"
	echo "##############################################"
fi

INSTALLPACKAGES1="curl policycoreutils-python openssh-server openssh-clients lynx mutt"
INSTALLPACKAGES2="postfix"
GITLABFILE="https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh"
INSTALLPACKAGES3="gitlab-ce"

echo
echo "#####################################################################################"
echo "Installing base packages - $INSTALLPACKAGES1"
yum install -y $INSTALLPACKAGES1 
echo "Done"
sleep 2
echo "#####################################################################################"

if [[ $FIREWALL == "yes" ]]
then	
	if systemctl -q is-active firewalld
	then
		echo
		echo "##################################"
		echo "Adding http service to the firewall"
		firewall-cmd --permanent --add-service http
		firewall-cmd --reload
		echo "Done"
		echo "##################################"
	else
		echo
		echo "######################################################"
		echo "Firewalld not running. No changes made to the firewall"
		echo "######################################################"
	fi
fi

if yum list installed postfix > /dev/null 2>&1
then
	systemctl -q is-active postfix && {
	systemctl stop postfix
	systemctl -q disable postfix
	}

	echo 	
	echo "############################"
	echo "Removing old copy of postfix"	
	yum remove -y $INSTALLPACKAGES2
	rm -rf /var/spool/postfix
	echo "Done"
	echo "############################"
fi
	

# Install postfix	
echo
echo "##################"
echo "Installing $INSTALLPACKAGES2"
yum install -y $INSTALLPACKAGES2 
echo "Done"
sleep 2
echo "##################"

systemctl start postfix
systemctl -q enable postfix

if yum list installed $INSTALLPACKAGES3
then
	echo
	echo "################################"
	echo "Removing old instances of gitlab"
	yum remove -y $INSTALLPACKAGES3
	rm -rf /etc/gitlab
	rm -rf /var/log/gitlab
	rm -rf /etc/yum.repos.d/gitlab_gitlab-ce.repo
	sleep 2
	echo "Done"
	echo "################################"
fi

# Install gitlab
echo 
echo "################################################"
echo "Installing gitlab. This can take upto 20 minutes"
curl -sS $GITLABFILE | bash
yum install -y $INSTALLPACKAGES3
sleep 5
echo "Done"
echo "################################################"


if [[ $SELFSIGNEDCERT == "yes" ]]
then
	rm -rf ./gitlabserver.*
	rm -rf /etc/gitlab/ssl
	openssl req -x509 -days 365 -newkey rsa:2048 -nodes -keyout ./gitlabserver.key -out ./gitlabserver.crt -subj "/C=US/ST=TX/L=Houston/O=CMEI"
	mkdir /etc/gitlab/ssl
	chmod 700 /etc/gitlab/ssl
	mv ./gitlabserver.* /etc/gitlab/ssl/

	sed -i "s/^\(external_url\).*/external_url https://$SERVERFQDN" /etc/gitlab/gitlab.rb
	
