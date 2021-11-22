# LINHA  191 E 266 SG FIXO -> DO MASTER
data "http" "myip" {
  url = "http://ipv4.icanhazip.com" # outra opção "https://ifconfig.me"
}

variable "subnet" {
  default     = {
    azc1 = "subnet-0958c1cc0f3c9b493",
    aza2 = "subnet-0b06fb1f9978ec6fb",
    azc3 = "subnet-0958c1cc0f3c9b493"
  }
}

resource "aws_instance" "k8s_proxy" {
  subnet_id     = "subnet-0958c1cc0f3c9b493"
  ami                         = "ami-0e66f5495b4efdd0f" #ubuntu
  instance_type = "t2.micro"
  key_name = "ortaleb-chave-nova"
  tags = {
    Name = "k8s-haproxy"
    KubernetesCluster = "UCPKubenertesCluster"
    Owner = "ortaleb"
  }
    associate_public_ip_address = true
    root_block_device {
    encrypted = true
    volume_size = 8
  }
  vpc_security_group_ids = [aws_security_group.acessos_haproxy.id]
}
resource "aws_instance" "k8s_masters" {
  for_each = var.subnet
  subnet_id     = "${each.value}"
  ami                         = "ami-0e66f5495b4efdd0f" #ubuntu
  instance_type = "t2.large"
  key_name = "ortaleb-chave-nova"
  #count         = 3
  tags = {
    Name = "k8s-master-${each.key}"
    KubernetesCluster = "UCPKubenertesCluster"
    Owner = "ortaleb"
  }
    associate_public_ip_address = true
    root_block_device {
    encrypted = true
    volume_size = 8
  }
  vpc_security_group_ids = [aws_security_group.acessos_masters.id]
  depends_on = [
    aws_instance.k8s_workers,
  ]
}

resource "aws_instance" "k8s_workers" {
  for_each = var.subnet
  subnet_id     = "${each.value}"
  ami                         = "ami-0e66f5495b4efdd0f" #ubuntu
  instance_type = "t2.medium"
  key_name = "ortaleb-chave-nova"
  tags = {
    Name = "k8s_workers-${each.key}"
    KubernetesCluster = "UCPKubenertesCluster"
    Owner = "ortaleb"
  }
    associate_public_ip_address = true
    root_block_device {
    encrypted = true
    volume_size = 8
  }
  vpc_security_group_ids = [aws_security_group.acessos_workers.id]
}

# terraform refresh para mostrar o ssh
