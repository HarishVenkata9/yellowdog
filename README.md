# Created by Manish Rangari <linuxtricksfordevops@gmail.com>

# YellowDog Repo to create AWS resources using Terraform and configuration management using Ansible to deploy a sample application in Tomcat. The tarrform scripts can be heavily variablized but in this guide I am keeping it simple.


This will create the following AWS resources

a) VPC with CIDR of 192.168.0.0/20
b) 1 Internet Gateway
c) 2 Private Subnet for application servers both in different AZ
d) 2 Private Subnets for ELB both in different AZ
e) Make the route entry to make respective subnets public and private
f) NAT Gateway for accessing internet from private subnet machines
g) Assign an EIP to NAT Gateway.
h) Security Groups for ELB and app server with proper rules
i) ELB in two AZs with app server attached
j) 2 EC2 instances which will use local-exec to run ansible playbook to install and configure the application.
k) Ansible uses dynamic inventory to identify the targets
l) There are three roles in ansible, one for configuring java, another for configuring tomcat and finally one for delpoyment.

Pre-requisite for running this

1. Make sure you setup these environment variable
export AWS_ACCESS_KEY_ID="xxxxxxxxxxxxxxxxxxxxxxx"
export AWS_SECRET_ACCESS_KEY="yyyyyyyyyyyyyyyyyyyyyyyyy"
export AWS_DEFAULT_REGION="us-east-2"

2. Install ansible and terraform on the machine where you are going to run this.
3. Setup a SSH key pairs using ssh-keygen command and replace the keys present in keys directory with these newly created ones.
4. Add the private key in SSH key store using following commands. This will allow you to talk to other machines without mentioning any key

        $ eval $(ssh-agent)
        $ ssh-add keys/baseline_yellowdog.pem

5. Copy ansible aws dynamic inventory script and ini file in /usr/bin directory and make sure to make the scripts as executable.
6. You can run this scripts from two machines. You can use either of this two methods
a) From a machine where you will be having network connectivity between the current machine and the EC2 instances which will be launched. In this case, you will install ansible/terraform in this control machine and we will use "local-exec" to run the ansible playbook which will target newly launched EC2 instances by using dynamic inventory. I used this method in this guide.
b) From any machine which has internet access. In this method as well you install ansible/terraform in this control machine and you will use "remote-exec" and the ssh private key to get the ansible playbooks from a git repo. It will then install ansible ans run the playbook locally by using this command "ansible-playbook -i "localhost," -c local setup.yml" in each app server machine.
7. Copy the files inside ansible folder inside /etc/ansible
8. Finally go to terraform folder and run

        $ terrform validate
        $ terraform init
        $ terrform plan
        $ terraform apply

9. It will create AWS resources and at the end if everything goes well, it will output the ELB endpoint where you can access the application in this location

        http://elb-end-point/sample/
