output "application_url" {
  description = "Open this URL in your browser"
  value       = "http://${aws_instance.proxy.public_dns}"
}

output "proxy_public_ip" {
  value = aws_instance.proxy.public_ip
}

output "private_app_ip" {
  description = "Private IP of the application server"
  value       = aws_instance.app.private_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}
