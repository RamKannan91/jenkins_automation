#!/bin/bash
set -o errexit
set -o nounset

ansible-playbook jenkins_bootstrap.yml -vvvv #--limit jenkins_bootstrap --inventory-file=hostsbootstrap -vvvv
ansible-playbook jenkins.yml -vvvv #--limit jenkins
