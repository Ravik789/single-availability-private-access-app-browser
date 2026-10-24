# single-availability-private-access-app-browser

Summary: VPC + Private Subnet + Browser Access
- VPC: 10.0.0.0/16
- Availability Zone: us-east-1a (single AZ)
- Public subnet: 10.0.1.0/24
- Private subnet: 10.0.2.0/24
- Internet Gateway: Provides internet connectivity to the public subnet.
- EC2 #1 — Public: Runs Nginx reverse proxy on port 80.
- EC2 #2 — Private: Runs the application on port 8080, without a public IP.
- Security groups: Allow browser traffic to the proxy and proxy traffic to the private app.
- Browser access: Open http://<public-EC2-DNS>.
Why 2 EC2 instances? One receives browser requests; the other runs the application privately.

Important: This demo has no ALB or NAT Gateway. It is suitable for learning, not high availability.
