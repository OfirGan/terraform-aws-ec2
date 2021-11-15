locals {
  nginx-webserver = <<EOF
#!/bin/bash
sudo apt update -y
sudo apt install nginx awscli -y

########## Edit Site Name ###########
sed -i "s/nginx/Grandpa's Whiskey - $HOSTNAME.srv/g" /var/www/html/index.nginx-debian.html
sed -i '15,23d' /var/www/html/index.nginx-debian.html

########## Restart nginx ##########
service nginx restart

########## Upload Access Log To S3 Now & Every Hour ##########
echo "0 * * * * root aws s3 cp /var/log/nginx/access.log  s3://${var.s3_logs_bucket_name}/${var.s3_logs_folder}/webserverlogs/$HOSTNAME-access.log" | tr [:upper:] [:lower:] | sudo tee -a /etc/crontab

EOF
}


# log the original IP address in the webserver access logs
# https://aws.amazon.com/premiumsupport/knowledge-center/elb-capture-client-ip-addresses/
# access_log /var/log/nginx/access.log;  
#  -> replace with ->
# log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
#                   '$status $body_bytes_sent "$http_referer" '
#                   '"$http_user_agent" "$http_x_forwarded_for"';
# access_log  /var/log/nginx/access.log  main;
