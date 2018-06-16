CI with Jenkins.
=============================================

## Background
Nowadays continious integration is the important part of the agile software development life cycle.
There is a number of tools on the market: Atlassian Bamboo, Jenkins, Jetbrains TeamCity.
In my opinion Jenkins has the most optimal product community and set of really useful plugins
that suits most of your software projects:  you can  build software, deploy software,  
websites, portals to various places, including AWS, DigitalOcean, bare metal servers
or to run unit tests. It can be integrated with communication tools of your choice, like Slack, HipChat or
email.

If you haven't had a chance to try Jenkins earlier, feel free to use tutorial below to start.

### Get base Jenkins setup
You will need to execut series of the commands, namely: add jenkins signing key,
register jenkins apt sources, update package lists, and install Jenkins package.
<pre>
wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
sudo echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list
sudo apt-get update
sudo apt-get install jenkins
</pre>

By default, it will install base Jenkins setup, which is insecure. You will
need to go to the host were your Jenkins is installed, for example: http://jenkins-host:8080/.
Navigate to Manage Jenkins (on the left) and choose "Configure Global Security" item
on the page loaded.
![enable security](https://raw.githubusercontent.com/Voronenko/devops-jenkins-box-template/master/docs/enable_security.png)

### Put behind web server
Usually I hide Jenkins behind nginx. Typical configuration looks like the one below
<pre>
server {
  listen 443 ssl;
  server_name jenkins.vagrant.dev;

  ssl_certificate /etc/nginx/jenkins_selfsigned.crt;
  ssl_certificate_key /etc/nginx/jenkins_selfsigned.key;

  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_redirect off;

    proxy_connect_timeout 150;
    proxy_send_timeout 100;
    proxy_read_timeout 100;
  }
  ...
}
</pre>

## Automated installation
Do I install Jenkins manually each time? Of course not, I do it often for my customers.
With ansible, and sa-box-jenkins role new Jenkins installation can be deployed while you drink the coffee.

Let's prepare basic bootstrap project, that can be used by you in the future.
It includes following files:

- *bootstrap.sh* - installs ansible alongside with dependences.
- *init.sh* - initializes 3rd party dependencies
- *.projmodules* - fully compatible with .gitmodules git syntax,  specifies list of the dependencies that will be used by the playbook.
In particular, it includes ansible- by default developer_recipes (repository with set of handy deployment recipes)
and ansible role called  *sa-box-bootstrap* responsible for box securing steps (assuming you plan to put Jenkins on a remote hosts).

<pre>
[submodule "public/ansible_developer_recipes"]
	path = public/ansible_developer_recipes
	url = git@github.com:Voronenko/ansible-developer_recipes.git
[submodule "roles/sa-box-bootstrap"]
        path = roles/sa-box-bootstrap
        url = git@github.com:softasap/sa-box-bootstrap.git
[submodule "roles/sa-box-jenkins"]
        path = roles/sa-box-jenkins
        url = git@github.com:softasap/sa-box-jenkins.git</pre>
- *hosts* - list here the initial box credentials, that were provided to you for the server. Note: jenkins-bootstrap assumes, you have the fresh box with the root access only. If your box already secured, adjust credentials appropriately
<pre>
[jenkins-bootstrap]
jenkins_bootstrap ansible_ssh_host=192.168.0.17 ansible_ssh_user=yourrootuser ansible_ssh_pass=yourpassword
[jenkins]
jenkins ansible_ssh_host=192.168.0.17 ansible_ssh_user=jenkins
</pre>
- *jenkins_vars.yml* - set here specific environment overrides, like your preferred deploy user name and keys.
- *jenkins_bootstrap.yml* - First step - box securing. Creates jenkins user, and secures the box using sa-box-bootstrap role.
[See more details](https://github.com/softasap/sa-box-bootstrap) about the sa-box-bootstrap role
In order, to override params for *sa-box-bootstrap* - pass the parameters like in example below.

<pre>
- hosts: all

  vars_files:
    - ./jenkins_vars.yml
  roles:
     - {
         role: "sa-box-bootstrap",
         root_dir: "{{playbook_dir}}/public/ansible_developer_recipes",
         deploy_user: "{{jenkins_user}}",
         deploy_user_keys: "{{jenkins_authorized_keys}}"
       }</pre>
- *jenkins.yml* provisioning script that configures jenkins with set of plugins and users.
- *jenkins_vars.yml* configuration options for jenkins deployment.
- *setup_jenkins.sh* shell script that invokes deployment in two steps: initial box bootstraping & jenkins setup
<pre>
#!/bin/sh

ansible-playbook jenkins_bootstrap.yml --limit jenkins_bootstrap
ansible-playbook jenkins.yml --limit jenkins
</pre>


## Configuration options for automated installation
You need to override:  
- jenkins_authorized_keys (this is list of the keys, that allow you to login to Jenkins box under jenkins)
- jenkins_domain - your agency domain
- jenkins_host - name of the jenkins host (Site will be binded to jenkins_host.jenkins_domain)
- java_version - your Java choice (6,7,8 supported)

<pre>
jenkins_user: jenkins
jenkins_authorized_keys:
  - "{{playbook_dir}}/components/files/ssh/ramkannan.pub"

jenkins_domain: "vagrant.dev"
jenkins_host: "jenkins"

java_version: 8
</pre>

-jenkins_users list of users with passwords to create. Admin and deploy are required users.
Admin is used to manage instance, deploy is used to access the artifacts via deployment scripts.
If you won't override passwords, default one will be used (per role), which is not the best, for public deployments.
<pre>
jenkins_users:
  - {
    name: "Admin",
    password: "AAAdmin",
    email: "no-reply@localhost"
    }
  - {
    name: "deploy",
    password: "DeDeDeDeploy",
    email: "no-reply@localhost"
    }
</pre>

- jenkins_plugins Your choice of plugins to install. By default:

<pre>
jenkins_plugins:
  - bitbucket # https://wiki.jenkins-ci.org/display/JENKINS/BitBucket+Plugin
  - bitbucket-pullrequest-builder
  - build-pipeline-plugin
  - copyartifact # https://wiki.jenkins-ci.org/display/JENKINS/Copy+Artifact+Plugin
  - credentials # https://wiki.jenkins-ci.org/display/JENKINS/Credentials+Plugin
  - delivery-pipeline-plugin # https://wiki.jenkins-ci.org/display/JENKINS/Delivery+Pipeline+Plugin
  - environment-script # https://wiki.jenkins-ci.org/display/JENKINS/Environment+Script+Plugin
  - git
  - parameterized-trigger #https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Trigger+Plugin
  - rebuild # https://wiki.jenkins-ci.org/display/JENKINS/Rebuild+Plugin
  - ssh
  - s3 # https://wiki.jenkins-ci.org/display/JENKINS/S3+Plugin
  - throttle-concurrents #https://wiki.jenkins-ci.org/display/JENKINS/Throttle+Concurrent+Builds+Plugin
</pre>

## Code in action

Code can be downloaded from repository [https://github.com/RamKannan91/jenkins_automation](https://github.com/RamKannan91/jenkins_automation)
In order to use it - fork it, adjust parameters to your needs, and use.

Running is as simple as
<pre>
./setup_jenkins.sh
</pre>

Welcome to the world of CI/CD.
