output "public_ec2_eip" {
  value = aws_eip.public_ec2_eip.public_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "nat_gateway_ip" {
  value = aws_eip.nat_eip.public_ip
}
