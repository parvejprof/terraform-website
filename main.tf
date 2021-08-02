provider "aws" {
  region = "ap-south-1"
}


# 1. Create VPC

resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dev-vpc"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev-vpc.id
}

# 3. Create Custom Route Table

resource "aws_route_table" "dev-route-table" {
  vpc_id = aws_vpc.dev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Dev"
  }
}

###### Using variables

# variable "subnet_prefix" {
#   description = "cidr block for the subnet" 
#   # default = 
#   # type = 

# }

# 4. Create a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.dev-vpc.id
  cidr_block = "10.0.1.0/24"
  #cidr_block = var.subnet_prefix
  availability_zone = "ap-south-1b"

  tags = {
    Name = "dev-subnet"
  }
}


# 5. Associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.dev-route-table.id
}



# 6. Create a security group to allow port 22, 80, 443


resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    description      = "Allow HTTPs"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Allow HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Allow SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


# 7. Create a network interface with an IP in the subnet that was created in step 4

resource "aws_network_interface" "web-interface" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8. Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
  
}
# 9. Create Ubuntu server and install/enable apache 2



resource "aws_instance" "web" {
  ami           = "ami-04db49c0fb2215364"
  instance_type = "t3.micro"
  availability_zone = "ap-south-1b"
  key_name = "web-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-interface.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install httpd -y
    sudo service httpd start
    sudo bash -c 'echo your very first web server > /var/www/html/index.html'
    EOF

 tags = {
    Name = "wev-Server"
    Env = "Test"
  }

}

#### Using output for get dynamics values

output "webserver-public-ip" {
  value = aws_eip.one.public_ip
}

output "webserver-private-ip" {
  value = aws_instance.web.private_ip
}

output "webserver-instance-id" {
  value = aws_instance.web.id
}


