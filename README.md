# hpctoys

dTUI Tools and wrappers that simplify working with IT environments for data intensive science (HPC, containers, virtual machines)

## commands in PATH (bin/)

* [osc-server](#using-osc-server) is a tool to quickly spin up servers in Openstack

## detailed descriptions 

### using osc-server 

`osc-server` is a simple wrapper for the openstack cli. After you get your openstack project assigned you have to execute about 10 steps for configuring network, router, IPs, images, keys, VM before you can actually login to your first virtual server. `osc-server` reduces this to a single step after you have configured your ~/.openstackrc file. 

```
> osc-server

*****  WARNING: ~/.openstackrc file missing ! *****

Log in to the Openstack Horizon Dashboard. Navigate to Project -> API Access
to download the OpenStack RC file. (In older Openstack versions this is in
Project -> Compute -> Access & Security -> API Access)
Save the file in your home as ~/.openstackrc and run "chmod 600 ~/.openstackrc"

To avoid a password prompt each time you use openstack you can comment the 2
lines containing OS_PASSWORD_INPUT and add a line "export OS_PASSWORD=<password>"
```

`osc-server help` shows all possible sub commands, for example you can always download a new QCOW2 Linux image directly into the system with `osc-server newimage <URL> <Image-Name>`

```
>osc-server help

*** osc-server - a tool to quickly create openstack servers ***

execute one of these sub commands:
 osc-server create <server-name>
 osc-server delete <server-name>
 osc-server list
 osc-server checknet
 osc-server nameservers
 osc-server newimage <URL> <Image-Name>
 osc-server projectpurge (delete all resources)
 osc-server showres  (show machine flavors and images)
 osc-server sshkey (refresh key from .ssh/id_rsa.pub)

for example:
 osc-server create -f m1.small -i "Ubuntu-22.04-LTS" myserver
```

```
> osc-server create myserver1
checking openstack configuration ... configured=false
creating network configuration ...
creating subnet configuration with DNS ...
creating L3 router configuration ...
adding router to subnet ...
creating security group os_standard (ports 22,80,443,3389,8000-8999) ...
allowing ICMP ...
allowing port 22 ...
allowing port 80 ...
allowing port 443 ...
allowing port 3389 ...
allowing port 8000-8999 ...
installing new Image, executing this command:
osc-server newimage https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img Ubuntu-22.04-LTS
remove key os_key_xxxxx if exists...
refreshing public key os_key_xxxxx ...
create floating ip address...
create server myserver1 with size m1.small and OS Ubuntu-22.04-LTS ...
assign floating ip 10.96.11.205 to server myserver1 ... Done.
Run one of these commands:
 ssh centos@10.96.11.205
 ssh ubuntu@10.96.11.205
Execute this command to see console output of server myserver1:
 osc console log show myserver1
```

 `osc-server projectpurge` simply deletes all resources in your Openstack project 

```
 > osc-server projectpurge
This will clean out your entire openstack account, including servers, images and networks
 Do you REALLY want to continue ? [y/N] y
retrieve servers ...
 deleting server myserver1 ...
retrieve floating IPs ...
 delete floating IP 10.96.11.200 ...
clear router gateway ...
delete security group os_standard ...
retrieve ports ...
 delete port 6a3fc127-46f7-4565-9a94-8353a256a726 ...
 delete port 8b7cf850-9343-46f8-8c4f-28f839d4e929 ...
delete router os_l3_router ...
delete network os_tenant_network ...
retrieve private images ...
 deleting private image "Ubuntu-22.04-LTS" ...
remove key os_key_xxxxx ...

All resources purged from current project !
```

## Background information 

### per-user-tmp

hpctoys lpython distribution shares /tmp among multiple users. 
This can be a security concern in larger environments. 
You can use [this method](http://tech.ryancox.net/2013/07/per-user-tmp-and-devshm-directories.html) 
to isolate /tmp on login nodes.

