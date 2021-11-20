output "security-group-workers-e-haproxy1" {
  value = aws_security_group.acessos_haproxy.id
}

output "security-group-acessos-masters" {
  value = aws_security_group.acessos_masters.id
}

output "security-group-acessos_workers" {
  value = aws_security_group.acessos_workers.id
}