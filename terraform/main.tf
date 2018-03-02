# Choose AWS as the cloud provider
provider "aws" {
  version = "~> 1.9"
}

# Create VPC with CIDR 192.168.0.0/20
resource "aws_vpc" "yellowdog_vpc" {
  cidr_block       = "192.168.0.0/20"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags {
    Name = "Crevise VPC"
  }
}

# Create subnet for ELB in AZ-A
resource "aws_subnet" "elb_subnet_az_a" {
  vpc_id                  = "${aws_vpc.yellowdog_vpc.id}"
  cidr_block              = "192.168.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2a"
  tags = {
        Name =  "ELB Subnet AZ-A"
  }
}

# Create subnet for ELB in AZ-B
resource "aws_subnet" "elb_subnet_az_b" {
  vpc_id                  = "${aws_vpc.yellowdog_vpc.id}"
  cidr_block              = "192.168.5.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2b"
  tags = {
        Name =  "ELB Subnet AZ-B"
  }
}

# Create subnet for Apps in AZ A
resource "aws_subnet" "app_subnet_az_a" {
  vpc_id                  = "${aws_vpc.yellowdog_vpc.id}"
  cidr_block              = "192.168.3.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2a"
  tags = {
        Name =  "APP Subnet AZ-A"
  }
}

# Create subnet for Apps in AZ B
resource "aws_subnet" "app_subnet_az_b" {
  vpc_id                  = "${aws_vpc.yellowdog_vpc.id}"
  cidr_block              = "192.168.4.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-2b"
  tags = {
        Name =  "APP Subnet AZ-B"
  }
}

# Create IGW for making a subnet public
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.yellowdog_vpc.id}"
  tags {
        Name = "Crevise VPC IGW"
    }
}

# Make route entry of IGW as a default gateway in main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.yellowdog_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

# Create EIP for NAT Gateway
resource "aws_eip" "yellowdog_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.igw"]
}

# Create NAT gateway for accessing internet from p`rivate subnet machines
resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.yellowdog_eip.id}"
    subnet_id = "${aws_subnet.elb_subnet_az_a.id}"
    depends_on = ["aws_internet_gateway.igw"]
}

# Add Nat Gateway route entry in private subnet route table
resource "aws_route" "private_route" {
        route_table_id  = "${aws_route_table.private_route_table.id}"
        destination_cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.nat.id}"
}

# Create a route table for private subnet
resource "aws_route_table" "private_route_table" {
    vpc_id = "${aws_vpc.yellowdog_vpc.id}"

    tags {
        Name = "Private Route Table"
    }
}

# Associate ELB Subnet AZ-A to public route table
resource "aws_route_table_association" "public_app_subnet_az_a_association" {
    subnet_id = "${aws_subnet.elb_subnet_az_a.id}"
    route_table_id = "${aws_vpc.yellowdog_vpc.main_route_table_id}"
}

# Associate ELB Subnet AZ-B to public route table
resource "aws_route_table_association" "public_app_subnet_az_b_association" {
    subnet_id = "${aws_subnet.elb_subnet_az_b.id}"
    route_table_id = "${aws_vpc.yellowdog_vpc.main_route_table_id}"
}


# Associate APP Subnet AZ-A to private route table
resource "aws_route_table_association" "private_app_subnet_az_a_association" {
    subnet_id = "${aws_subnet.app_subnet_az_a.id}"
    route_table_id = "${aws_route_table.private_route_table.id}"
}

# Associate APP Subnet AZ-B to private route table
resource "aws_route_table_association" "private_app_subnet_az_b_association" {
    subnet_id = "${aws_subnet.app_subnet_az_b.id}"
    route_table_id = "${aws_route_table.private_route_table.id}"
}

# Create a security group for ELB
resource "aws_security_group" "allow_http_all" {
  name        = "elb_allow_http_all"
  description = "Allow all inbound traffic on port 80"
  vpc_id      = "${aws_vpc.yellowdog_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "ELB HTTP Allow All"
  }
}

# Create a security group for APP Server EC2
resource "aws_security_group" "allow_tomcat_vpc" {
  name        = "ec2_allow_8080_vpc"
  description = "Allow inbound traffic on port 8080 from VPC"
  vpc_id      = "${aws_vpc.yellowdog_vpc.id}"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.yellowdog_vpc.cidr_block}"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.yellowdog_vpc.cidr_block}"]
  }

  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "EC2 Allow port 22 and 8080"
  }
}

# Create an EC2 SSH key pair. You need to use either ssh-keygen or puttygen command to generate the key pairs
resource "aws_key_pair" "baseline_key" {
  key_name   = "baseline_yellowdog"
  public_key = "${file("${var.aws_ssh_admin_key_file}.pub")}"
}

# Create a new load balancer in ELB subnets
resource "aws_elb" "yellowdog_lb" {
  name               = "yellowdog-terraform-elb"
  subnets = ["${aws_subnet.elb_subnet_az_a.id}","${aws_subnet.elb_subnet_az_b.id}"]
  security_groups = ["${aws_security_group.allow_http_all.id}"]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8080"
    interval            = 30
  }

  instances                   = ["${aws_instance.tomcat1.id}","${aws_instance.tomcat2.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "yellowdog-terraform-elb"
  }
}

# Get the latest Ubuntu 16.04 server AMI
data "aws_ami" "tomcat_amazon" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create one EC2 in APP Subnet A and use local-exec to apply ansible playbook
resource "aws_instance" "tomcat1" {
  ami           = "${data.aws_ami.tomcat_amazon.id}"
  instance_type = "${var.instance_type}"
  vpc_security_group_ids = ["${aws_security_group.allow_tomcat_vpc.id}"]
  subnet_id = "${aws_subnet.app_subnet_az_a.id}"
  key_name = "${var.aws_key_name}"
  tags {
    Name = "Tomcat App Server 1"
    Role = "Appserver"
  }
  lifecycle {
    create_before_destroy = true
  }
  provisioner "local-exec" {
       command = "/usr/bin/ec2.py --refresh-cache && ansible -i /usr/bin/ec2.py -e 'host_key_checking=False' -u ubuntu --become tag_Role_Appserver -m raw -a 'sudo killall -9 apt; sudo rm -fv /var/lib/dpkg/lock; sudo apt install -y python-minimal python-simplejson'; ansible-playbook -i /usr/bin/ec2.py -e 'host_key_checking=False' /etc/ansible/setup.yml"
  }
  depends_on = ["aws_nat_gateway.nat"]
}

# Create another EC2 in APP Subnet B and use local-exec to apply ansible playbook
resource "aws_instance" "tomcat2" {
  ami           = "${data.aws_ami.tomcat_amazon.id}"
  instance_type = "${var.instance_type}"
  vpc_security_group_ids = ["${aws_security_group.allow_tomcat_vpc.id}"]
  subnet_id = "${aws_subnet.app_subnet_az_b.id}"
  key_name = "${var.aws_key_name}"
  tags {
    Name = "Tomcat App Server 2"
    Role = "Appserver"
  }
  provisioner "local-exec" {
        command = "/usr/bin/ec2.py --refresh-cache && ansible -i /usr/bin/ec2.py -e 'host_key_checking=False' -u ubuntu --become tag_Role_Appserver -m raw -a 'sudo killall -9 apt; sudo rm -fv /var/lib/dpkg/lock; sudo apt install -y python-minimal python-simplejson'; ansible-playbook -i /usr/bin/ec2.py -e 'host_key_checking=False' /etc/ansible/setup.yml"
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = ["aws_nat_gateway.nat"]
}
