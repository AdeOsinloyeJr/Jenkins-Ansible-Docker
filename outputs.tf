output "instance_public_ips" {
  description = "Public IPs of all EC2 instances"
  value       = [for instance in aws_instance.demo : instance.public_ip]
}

output "instance_private_ips" {
  description = "Private IPs of all EC2 instances"
  value       = [for instance in aws_instance.demo : instance.private_ip]
}

output "instance_ip_mapping" {
  description = "Mapping of instance names to public and private IPs"
  value = {
    for name, instance in aws_instance.demo : name => {
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
      instance_id = instance.id
    }
  }
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to each instance"
  value = [
    for name, instance in aws_instance.demo : 
    "ssh -i /mnt/c/Users/adedi/Downloads/LaptopKey ubuntu@${instance.public_ip}  # ${name}"
  ]
}

output "jenkins_urls" {
  description = "Jenkins web UI URLs (public and private)"
  value = {
    public_url  = "http://${aws_instance.demo["controller"].public_ip}:8080"
    private_url = "http://${aws_instance.demo["controller"].private_ip}:8080"
  }
}

output "agent_connection_info" {
  description = "Jenkins agent connection information"
  value = {
    controller_public_ip  = aws_instance.demo["controller"].public_ip
    controller_private_ip = aws_instance.demo["controller"].private_ip
    agents = {
      for name, instance in aws_instance.demo : 
      name => {
        public_ip  = instance.public_ip
        private_ip = instance.private_ip
        ssh_command = "ssh -i /mnt/c/Users/adedi/Downloads/LaptopKey ubuntu@${instance.public_ip}"
      } if name != "controller"
    }
  }
}