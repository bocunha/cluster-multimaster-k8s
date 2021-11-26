output "k8s-masters1" {
  value = [
    for key, item in aws_instance.k8s_masters :
      "IP k8s-master ${key} - ${item.private_ip} - ssh ubuntu@${item.public_dns}"
  ]
}

output "output-k8s_workers1" {
  value = [
    for key, item in aws_instance.k8s_workers :
      "IP k8s-workers ${key} - ${item.private_ip} - ssh ubuntu@${item.public_dns}"
  ]
}

output "output-k8s_proxy1" {
  value = [
    "k8s_proxy - ${aws_instance.k8s_proxy.private_ip} - ssh ubuntu@${aws_instance.k8s_proxy.public_dns}"
  ]
}

output "k8s-id-masters1" {
  value = [
    for key, item in aws_instance.k8s_masters :
      "k8s-master ${key} - ID: ${item.id}"
  ]
}

output "output-id-k8s_workers1" {
  value = [
    for key, item in aws_instance.k8s_workers :
      "k8s-workers ${key} - ID: ${item.id}"
  ]
}