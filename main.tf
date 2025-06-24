provider "aws" {
  region = "ap-south-1"

}

resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = "terra_vpc"
  }
}

resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = var.subnet_cidr
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "terra_subnet"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "terra_igw"
  }
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "terra_route_table"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
}

resource "aws_route_table_association" "RTass" {
  subnet_id = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_key_pair" "my_key_pair" {
  key_name = "terr-key-pair"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "terra-SG" {
  name = "web"
  description = "Allow HTTP and SSH traffic"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    description = "Allow HTTP traffic"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH traffic"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
  
}

resource "aws_instance" "server" {
  ami = "ami-021a584b49225376d" # Example AMI, replace with a valid one for your region
  instance_type = "t2.micro"
  subnet_id = aws_subnet.sub1.id
  key_name = aws_key_pair.my_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.terra-SG.id]

  tags = {
    Name = "terra_instance"
  }

  connection {
    type = "ssh"
    user = "ubuntu" # Change this to the appropriate user for your AMI
    private_key = file("~/.ssh/id_rsa")
    host = self.public_ip
  }

  provisioner "file" {
    source = "app.py" # Path to the file you want to copy
    destination = "/home/ubuntu/app.py" # Destination path on the instance
  }
  provisioner "remote-exec" {
    inline = [
      "echo 'Hello from the remote instance'",
      "sudo apt update -y",  # Update package lists (for ubuntu)
      "sudo apt-get install -y python3-pip",  # Example package installation
      "cd /home/ubuntu",
      "sudo pip3 install flask",
      "sudo python3 app.py &",
    ]
  }

  
}
  

