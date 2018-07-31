# gitlab
Installing gitlab with lets encrypt  or a self-signed certificate
---------------------------------------------------------------
Installing on an AWS RHEL instance -

Make sure there is enough swap space
dd if=/dev/zero of=/root/swap bs=1M count=2000
chmod 0600 /root/swap
mkswap /root/swap
sawpon /root/swap
free -m -h

The hostname needs to match the FQDN
hostnamectl set-hostname <FQDN>

W/o these 2 steps, the installation doesnt work correctly

Also have to use the self-signed option on AWS




---------------------------------------------------------------
