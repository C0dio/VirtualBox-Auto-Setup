## VirtualBox Auto Setup
A series of scripts that automatically sets up a virtual machine via VirtualBox and triggers an environment setup script on the VM.

The `./setup-vm.sh` script triggers an Unattended Installation for VirtualBox so once you run it, leave it - updates are printed to the screen.

If you have a slow internet connection you can go get a cup of tea - assuming you don't need to install VirtualBox - the Virtual Machine's seed can be quite large. 

## Default Virtual Machine
To use, simply copy the scripts in the repository and put them into the same directory - then run the following on a command line;
```console
$ bash setup-vm.sh
```

Running the script without parameters will result in a Virtual Machine being created with the following attributes;

|Parameter Name|Default Value|Summary|
|---|---|---|
|VM_NAME|nimbox|Name of the VM|
|VM_CPU|2|CPUs|
|VM_HDD|20000|Disk Space (KB)|
|VM_RAM|4096|Memory (KB)|
|VM_VRAM|128|Virtual memory (KB)|
|VM_SSH|2222|SSH Port|
|VM_GCON|vmsvga|Graphics Controller|
|VM_NAPT|virtio|Network Adapter|
|VM_USER|vmuser|VM's Username|
|VM_PASS|vmpass|VM's Password (plaintext)|

## Customised Virtual Machine
Several attributes of the Virtual Machine can be edited from the command line, the list of parameters can be found below and to change them simply prefix them to the script.

```console
$ VM_NAME=JohnSmithVM bash test.sh                                # Override a single parameter
```
```console
$ VM_NAME=JohnSmithVM VM_PASS=SuperSecretPassword bash test.sh    # Override multiple parameters
```

```python
* VM_NAME="${VM_NAME:-nimbox}" # Name
* VM_CPU="${VM_CPU:-2}"        # CPUs
* VM_HDD="${VM_HDD:-20000}"    # Disk Space (KB)
* VM_RAM="${VM_RAM:-4096}"     # Memory (KB)
* VM_VRAM="${VM_VRAM:-128}"    # Virtual memory (KB)
* VM_SSH="${VM_SSH:-2222}"     # SSH port
* VM_GCON="${VM_GCON:-vmsvga}" # Graphics Controller
* VM_NAPT="${VM_NAPT:-virtio}" # Network Adapter
* VM_USER="${VM_USER:-vmuser}" # VM's Username
* VM_PASS="${VM_PASS:-vmpass}" # VM's Password (plaintext)
```
     
## Environment Script
The `./environment.sh` script will install the following;
* Configure SUDO access,
* Configure Certificates,
* Create SSH Keys,
* Install OpenSSH for SSH,
* Install Curl,
* Install unzip, zip and jq,
* Install AWS,
* Install Terraform,
* Install Node.

## Requirements
* [x] The ability to run a Shell Script;
  * [x] Ubuntu Terminal
  * [x] Git Bash 
  * [x] [WSL](https://aka.ms/wslstore) for Windows
  
## Something Went Wrong!
Don't panic, the script was designed for several systems but not every use case has been handled, for example [HyperVisor Errors](#hypervisor-error).

### Logging
The script will log to two files, one inside the Virtual Machine (assuming it got that far) and another in the same directory you ran the script.

The reason for the two is to indicate which part of the script failed, if the log file in the VM is incomplete then you can assume the `./environment` script encountered an error and cancelled the `./setup-vm.sh` script.

### HyperVisor Error
Follow the steps outlined here:
[https://www.partitionwizard.com/partitionmanager/not-in-a-hypervisor-partition.html](https://www.partitionwizard.com/partitionmanager/not-in-a-hypervisor-partition.html)
