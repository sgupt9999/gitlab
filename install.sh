#!/bin/bash
#####################################################################
# This script will install community edition of gitlab on this server
#####################################################################
# Start of user inputs
#SELFSIGNEDCERT="yes"
SELFSIGNEDCERT="no"
LETSENCRYPT="yes"
#LETSENCRYPT="no"
# When testing LetsEncrypt has a limit on number of times one can get a new certficate
# Using the staging flag lets you get a certificate from non trusted CA
STAGELETSENCRYPT="yes"
#STAGELETSENCRYPT="no"
DOMAIN="garfield99992.mylabserver.com"
ADMIN_EMAIL="sgupt9999@gmail.com"

# Firewalld should be up and running to make changes
FIREWALL="yes"
#FIREWALL="no"
# End of user inputs
#####################################################################

if [[ $EUID != 0 ]]
then
	echo
	echo "##########################################################"
	echo "ERROR. You need to have root privileges to run this script"
	echo "##########################################################"
	exit 1
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
INSTALLPACKAGES4="certbot"

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
		echo "##############################################"
		echo "Adding http and https services to the firewall"
		firewall-cmd -q --permanent --add-service http
		firewall-cmd -q --reload
		firewall-cmd -q --permanent --add-service https
		firewall-cmd -q --reload
		echo "Done"
		echo "##############################################"
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
	yum remove -y $INSTALLPACKAGES3 -q > /dev/null 2>&1
	rm -rf /etc/gitlab
	rm -rf /var/log/gitlab
	rm -rf /etc/yum.repos.d/gitlab_gitlab-ce.repo
	sleep 2
	echo "Done"
	echo "################################"
fi

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

	sed -i "s/^\(external_url\).*/external_url \'https:\/\/$DOMAIN\'/" /etc/gitlab/gitlab.rb
	sed -i "/ssl_certificate/s/#{node\['fqdn'\]}/gitlabserver/" /etc/gitlab/gitlab.rb 
	sed -i "/ssl_certificate/s/#[ \t]*//" /etc/gitlab/gitlab.rb
fi


if [[ $LETSENCRYPT == "yes" ]]
then
	# Use LetsEncrypt to get a certificate

	systemctl stop gitlab-runsvdir

	if yum list installed certbot > /dev/null 2>&1
	then
		echo 
		echo "############################"
		echo "Removing old copy of certbot"
		yum remove -y certbot
		rm -rf /etc/letsencrypt
		echo "Done"
		echo "############################"
	fi

	echo
	echo "#######################################################################"
	echo "Installing epel repo and $INSTALLPACKAGES4 for Lets Encrypt certificate"
	yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	sleep 3
	# This package is only available in Centos Base
	yum install -y https://rpmfind.net/linux/centos/7.5.1804/os/x86_64/Packages/python-zope-interface-4.0.5-4.el7.x86_64.rpm
	yum install $INSTALLPACKAGES4 -y 
	sleep 3
	if [[ $STAGELETSENCRYPT == "yes" ]]
	then
		echo "certbot certonly --staging -n --standalone -d $DOMAIN --agree-tos --email $ADMIN_EMAIL"
		certbot certonly --staging -n --standalone -d $DOMAIN --agree-tos --email $ADMIN_EMAIL
	else
		
		echo "certbot certonly -n --standalone -d $DOMAIN --agree-tos --email $ADMIN_EMAIL"
		certbot certonly -n --standalone -d $DOMAIN --agree-tos --email $ADMIN_EMAIL
	fi
	echo "Done"
	echo "#######################################################################"

	sed -i "s/^\(external_url\).*/external_url \'https:\/\/$DOMAIN\'/" /etc/gitlab/gitlab.rb
	sed -i "/ssl_certificate/s/etc.*crt/etc\/letsencrypt\/live\/$DOMAIN\/fullchain.pem/" /etc/gitlab/gitlab.rb
	sed -i "/ssl_certificate/s/etc.*key/etc\/letsencrypt\/live\/$DOMAIN\/privkey.pem/" /etc/gitlab/gitlab.rb
	sed -i "/ssl_certificate/s/#[ \t]*//" /etc/gitlab/gitlab.rb

	systemctl restart gitlab-runsvdir
fi

echo
echo "####################"
echo "Reconfiguring gitlab"
gitlab-ctl reconfigure
echo "Done"
echo "####################"
	
