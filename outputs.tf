# ##################################################################################
# # OUTPUT
# ##################################################################################
output "db_servers_private_ips" {
  value = aws_instance.db_servers.*.private_ip
}

output "web_servers_public_ips" {
  value = aws_instance.nginx_web_servers.*.public_ip
}

output "alb_public_dns" {
  value = aws_lb.web_alb.dns_name
}
