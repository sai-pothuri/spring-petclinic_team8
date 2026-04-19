#!/bin/bash
echo "Bypassing container and invoking host-side Ansible for deployment..."

# Use SSH to connect to the host (10.0.0.50) and run the local ansible-playbook
# Note: Using the absolute path confirmed by 'ansible --version'
ssh -o StrictHostKeyChecking=no lili@10.0.0.50 "/home/lili/.local/bin/ansible-playbook /home/lili/spring-petclinic_team8/ansible/deploy.yml"
