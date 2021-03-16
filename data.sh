#!/bin/bash

echo ------------------------START BOOT STRAPING-----------------------
sudo yum -y update
sudo yum install -y httpd

public_ip=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
hostname=`curl http://169.254.169.254/latest/meta-data/hostname`
echo "<html><body bgcolor=white><center><h2><p><font color=red>Server-$hostname powered by Terraform whis public ip-$public_ip greets you<h2><center><body><html>" > /var/www/html/index.html
echo "ver-2.0" >> /var/www/html/index.html
sudo service httpd start
chkconfig httpd on

echo -----------------------FINISH BOOT STRAPING-----------------------
