#!/bin/bash -vx
## VARIAVEIS
TFPATH="/home/ec2-user/cluster-multi-master/0-k8s"
CHKSGNOK=`grep "sg" $TFPATH/0-terraform/sg-ok.tf | wc -l`
CHAVESSH="~/.ssh/ortaleb-chave-nova.pem"
###########################
#LIMPA TEMPORARIOS
rm $TFPATH/tmp/tf*.tmp

#PEGA O ESTADO DO TERRAFORM
cd $TFPATH/0-terraform/
terraform refresh > $TFPATH/tmp/tfrefresh.tmp
CHKREFRESH=`grep "empty" $TFPATH/tmp/tfrefresh.tmp | wc -l`

read

### RODA PRA CRIAR OS SECURITY GROUPS E SALVAR OS IDs
if [ ${CHKSGNOK} == 0 ] || [ ${CHKREFRESH} == 1 ]; 
  then 
    # PREPARA OS ARQUIVOS PARA RODAR SOMENTE SG
    cp sg-nok.tf sg-nok.tf.bkp
    if [ ! -f mainv2.tf.disable ] ;then mv mainv2.tf mainv2.tf.disable; fi
    if [ ! -f outputmain.tf.disable ] ;then mv outputmain.tf outputmain.tf.disable; fi

    # RODA O TERRAFORM PARA CRIAR OS SG
    terraform init
    terraform apply -auto-approve
    
    # PEGA O OUTPUT PARA TRATAR
    terraform output | sed 's/\"//g' | sed 's/ //g' > $TFPATH/tmp/tfsgids.tmp
    SGWORKER=`grep security-group-acessos_workers $TFPATH/tmp/tfsgids.tmp | cut -d"=" -f2`
    SGMASTERS=`grep security-group-acessos-masters $TFPATH/tmp/tfsgids.tmp | cut -d"=" -f2`
    SGHAPROXY=`grep security-group-workers-e-haproxy1 $TFPATH/tmp/tfsgids.tmp | cut -d"=" -f2`

    # RENOMEIA ARQUIVO DO SG SUBSTITUINDO OS IDS CIRCULARES
    mv sg-nok.tf sg-ok.tf
    sed -i 's/#security-group-acessos_workers/"'${SGWORKER}'",/g' sg-ok.tf
    sed -i 's/#security-group-acessos-masters/"'${SGMASTERS}'",/g' sg-ok.tf
    sed -i 's/#security-group-workers-e-haproxy1/"'${SGHAPROXY}'",/g' sg-ok.tf
fi

read 
# LIBERA OS ARQUIVOS DO TERRAFORM PARA RODAR
if [ -f mainv2.tf.disable ]; then mv mainv2.tf.disable mainv2.tf; fi
if [ -f outputmain.tf.disable ]; then mv outputmain.tf.disable outputmain.tf; fi

read
cd $TFPATH/0-terraform/
if [ ${CHKSGNOK} -eq 5 ] && [ ${CHKREFRESH} -lt 15 ]; 
  then
    terraform init
    terraform apply -auto-approve
fi
read
### RETIRA OS IPS E DNS DAS MAQUINAS
echo  "Aguardando a criação das maquinas ..."
sleep 10
terraform output | sed 's/\",//g' > $TFPATH/tmp/tfoutput.tmp

ID_M1=`awk '/k8s-master azc1 -/ {print $4}' $TFPATH/tmp/tfoutput.tmp`
ID_M1_DNS=`awk '/k8s-master azc1 -/ {print $7}' $TFPATH/tmp/tfoutput.tmp | cut -d"@" -f2`

ID_M2=`awk '/k8s-master aza2 -/ {print $4}' $TFPATH/tmp/tfoutput.tmp`
ID_M2_DNS=`awk '/k8s-master aza2 -/ {print $7}' $TFPATH/tmp/tfoutput.tmp | cut -d"@" -f2`

ID_M3=`awk '/k8s-master azc3 -/ {print $4}' $TFPATH/tmp/tfoutput.tmp`
ID_M3_DNS=`awk '/k8s-master azc3 -/ {print $7}' $TFPATH/tmp/tfoutput.tmp | cut -d"@" -f2`

ID_HAPROXY=`awk '/k8s_proxy -/ {print $3}' $TFPATH/tmp/tfoutput.tmp`
ID_HAPROXY_DNS=`awk '/k8s_proxy -/ {print $6}' $TFPATH/tmp/tfoutput.tmp | cut -d"@" -f2`

ID_W1=`awk '/k8s-workers azc1 -/ {print $4}' $TFPATH/tmp/tfoutput.tmp`
ID_W1_DNS=`awk '/k8s-workers azc1 -/ {print $7}' $TFPATH/tmp/tfoutput.tmp | cut -d"@" -f2`

ID_W2=`awk '/k8s-workers aza2 -/ {print $4}' $TFPATH/tmp/tfoutput.tmp`
ID_W2_DNS=`awk '/k8s-workers aza2 -/ {print $7}' $TFPATH/tmp/tfoutput.tmp | cut -d"@" -f2`

ID_W3=`awk '/k8s-workers azc3 -/ {print $4}' $TFPATH/tmp/tfoutput.tmp`
ID_W3_DNS=`awk '/k8s-workers azc3 -/ {print $7}' $TFPATH/tmp/tfoutput.tmp | cut -d"@" -f2`
read
# COLOCA A INFRMACAO DOS IPS NO HOSTS DO ANSIBLE
echo "
[ec2-k8s-proxy]
$ID_HAPROXY_DNS

[ec2-k8s-m1]
$ID_M1_DNS
[ec2-k8s-m2]
$ID_M2_DNS
[ec2-k8s-m3]
$ID_M3_DNS

[ec2-k8s-w1]
$ID_W1_DNS
[ec2-k8s-w2]
$ID_W2_DNS
[ec2-k8s-w3]
$ID_W3_DNS
" > $TFPATH/2-ansible/01-k8s-install-masters_e_workers/hosts

#CRIA SCRIPT DO ANSBILE PARA SUBIR O HAPROXY
read
echo "
global
        log /dev/log    local0
        log /dev/log    local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

        # Default SSL material locations
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private

        # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
        log     global
        mode    http
        option  httplog
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
        errorfile 400 /etc/haproxy/errors/400.http
        errorfile 403 /etc/haproxy/errors/403.http
        errorfile 408 /etc/haproxy/errors/408.http
        errorfile 500 /etc/haproxy/errors/500.http
        errorfile 502 /etc/haproxy/errors/502.http
        errorfile 503 /etc/haproxy/errors/503.http
        errorfile 504 /etc/haproxy/errors/504.http

frontend kubernetes
        mode tcp
        bind $ID_HAPROXY:6443 # IP ec2 Haproxy 
        option tcplog
        default_backend k8s-masters

backend k8s-masters
        mode tcp
        balance roundrobin # maq1, maq2, maq3  # (check) verifica 3 vezes negativo (rise) verifica 2 vezes positivo
        server k8s-master-0 $ID_M1:6443 check fall 3 rise 2 # IP ec2 Cluster Master k8s - 1 
        server k8s-master-1 $ID_M2:6443 check fall 3 rise 2 # IP ec2 Cluster Master k8s - 2 
        server k8s-master-2 $ID_M3:6443 check fall 3 rise 2 # IP ec2 Cluster Master k8s - 3 
        
" > $TFPATH/2-ansible/01-k8s-install-masters_e_workers/haproxy/haproxy.cfg

echo "
127.0.0.1 localhost
$ID_HAPROXY k8s-haproxy # IP privado proxy

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
" > $TFPATH/2-ansible/01-k8s-install-masters_e_workers/host/hosts

##########################################################
##########################################################
##########################################################
## RODA O ANSBILE PLAYBOOK PARA PROVISIONAR AS MAQUINAS
cd $TFPATH/2-ansible/01-k8s-install-masters_e_workers

ANSIBLE_OUT=$(ansible-playbook -i hosts provisionar.yml -u ubuntu --private-key ${CHAVESSH})

# RETIRA A CHAVE DO K8S PARA FAZER OS JOINS
K8S_JOIN_MASTER=$(echo $ANSIBLE_OUT | grep -oP "(kubeadm join.*?certificate-key.*?)'" | sed 's/\\//g' | sed "s/', u't//g" | sed "s/'$//g" )
K8S_JOIN_WORKER=$(echo $ANSIBLE_OUT | grep -oP "(kubeadm join.*?discovery-token-ca-cert-hash.*?)'" | head -n 1 | sed 's/\\//g' | sed "s/', u't//g" | sed "s/ '$//g")

echo "CHAVA PARA JOIN DOS MASTERS"
echo $K8S_JOIN_MASTER
echo "CHAVE PARA JOIN DOS WORKERS"
echo $K8S_JOIN_WORKER

# PREPARA OS SCRIPTS DE AUTO JOIN
cat <<EOF > 2-provisionar-k8s-master-auto-shell.yml
- hosts:
  - ec2-k8s-m2
  - ec2-k8s-m3
  become: yes
  tasks:
    - name: "Reset cluster"
      shell: "kubeadm reset -f"

    - name: "Fazendo join kubernetes master"
      shell: '$K8S_JOIN_MASTER'

    - name: "Colocando no path da maquina o conf do kubernetes"
      shell: mkdir -p $HOME/.kube && sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config && export KUBECONFIG=/etc/kubernetes/admin.conf
#---
- hosts:
  - ec2-k8s-w1
  - ec2-k8s-w2
  - ec2-k8s-w3
  become: yes
  tasks:
    - name: "Reset cluster"
      shell: "kubeadm reset -f"

    - name: "Fazendo join kubernetes worker"
      shell: $K8S_JOIN_WORKER

#---
- hosts:
  - ec2-k8s-m1
  become: yes
  tasks:
    - name: "Configura weavenet para reconhecer os nós master e workers"
      shell: kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=\$(kubectl version | base64 | tr -d '\n')"

    - name: Espera 30 segundos
      wait_for: timeout=30

    - shell: kubectl get nodes -o wide
      register: ps
    - debug:
        msg: " '{{ ps.stdout_lines }}' "
EOF

# RODA O SCRIPT PARA FAZER O JOIN
ansible-playbook -i hosts 2-provisionar-k8s-master-auto-shell.yml -u ubuntu --private-key ${CHAVESSH}

sleep 10

# ENTREGA O OUTPUT NA TELA
cd $TFPATH/0-terraform/
terraform output

echo "STATUS DOS NODES"
ssh -i ${CHAVESSH} ubuntu@${ID_M1_DNS} 'kubectl get nodes'

echo "Voce deseja conectar no master? yes/no"
read yes
if [[ $yes == "yes" ]];
  then
   ssh -i ${CHAVESSH} ubuntu@${ID_M1_DNS}
  else
  echo "Script finalizado, bye"
fi