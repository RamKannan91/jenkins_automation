#!/bin/bash
set -o errexit
set -o nounset

ansible-playbook jenkins.yml -vvvv #--limit jenkins
