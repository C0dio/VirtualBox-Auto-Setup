#!/bin/bash

# Path Options
PATH_64="Program Files\Oracle\VirtualBox"
PATH_32="Program Files (x86)\Oracle\VirtualBox"
PATH_VBOX="${PATH_VBOX:-$PATH_64}"
PATH_DOWNLOADS="${PATH_DOWNLOADS:-/tmp}" # File Locations

# VM Settings
VM_NAME="${VM_NAME:-nimbox}" # Name
VM_CPU="${VM_CPU:-2}"        # CPUs
VM_HDD="${VM_HDD:-20000}"    # Disk Space (KB)
VM_RAM="${VM_RAM:-4096}"     # Memory (KB)
VM_VRAM="${VM_VRAM:-128}"    # Virtual memory (KB)
VM_SSH="${VM_SSH:-2222}"     # SSH port
VM_GCON="${VM_GCON:-vmsvga}" # Graphics Controller
VM_NAPT="${VM_NAPT:-virtio}" # Network Adapter
VM_USER="${VM_USER:-vmuser}" # VM's Username
VM_PASS="${VM_PASS:-vmpass}" # VM's Password (plaintext)

# Colour options for output messages
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

#--------------------------------

#----- VIRTUALBOX -----

#
# Accept flags
#
FLAG_FORCE=0
FLAG_SKIP_IMPORT=0
while getopts :fs FLAG; do
    case $FLAG in
        f) FLAG_FORCE=1 ;;
        s) FLAG_SKIP_IMPORT=1 ;;
    esac
done

#
# Check vboxmanage installed and accessable
#
command -v vboxmanage &> /dev/null || {
    echo "vboxmanage not found, might not be added to PATH..."
    echo "Checking for vboxmanage in Program Files"

    # check the program files for vboxmanage
    command -v "C:\\$PATH_64\\vboxmanage" &> /dev/null || {

        # vb not found in 64-bit files, check 32-bit
        command -v "C:\\$PATH_32\\vboxmanage" &> /dev/null || {

            # still not found, install vboxmanage and get user to go through the wizard
            echo "No vboxmanage, installing installer now..."
            if [ ! -f VirtualBox-6.0.24-139119-Win.exe ]; then
                curl -L -O https://download.virtualbox.org/virtualbox/6.0.24/VirtualBox-6.0.24-139119-Win.exe -o /dev/null --progress-bar
            fi
            echo "Complete the steps in the Setup Wizard."
            echo "restart your computer if prompted."
            echo "re-run this script once complete."
            sleep 3
            ./VirtualBox-6.0.24-139119-Win.exe
            exit 1
        }

        # found vbox in 32-bit folder
        PATH_VBOX=$PATH_32
    }
    echo "Found vboxmanage, updating script..."
    echo -e "${RED}WARNING:${NC} If you want to run vboxmanage commands you will need to update your PATH"
    PATH="$PATH:/c/$PATH_VBOX"
}
PATH="$PATH:/c/Program Files\Git\mingw64\ssl\certs\ca-bundle.crt"

# sanity check
command -v vboxmanage &> /dev/null || {
    echo -e "${RED}ERROR: Failed to find vboxmanage, is it installed and added to your PATH?${NC}"
    exit 1
}
echo -e "\n${GREEN}vboxmanage setup complete${NC}\n"

#----- VM BOX -----

#
#   Create empty log file
#
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

LOG_FILE="$DIR/log.txt"
>"$LOG_FILE"

#
# Check if the VM exists
#
if vboxmanage list vms | grep -q "^\"$VM_NAME\" "; then
    echo "Virtual Box \"$VM_NAME\" already exists."
    if [[ $FLAG_FORCE -eq 1 ]]; then
        echo -n "FLAG_FORCE enabled. Destroying $VM_NAME..."

        # power off VM
        vboxmanage controlvm "$VM_NAME" poweroff &> /dev/null &
        while ! timeout 2 tail --pid=$! -f /dev/null; do
            echo "VM still running, retry in 3 seconds.."
            sleep 3
        done
        sleep 2 # prevent race-condition

        # delete vm
        vboxmanage unregistervm --delete "$VM_NAME" &>> "$LOG_FILE" &&
            echo "Success" ||
            { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }
    else
        echo "Run with -f to force cleanup ahead of deploy,"
        exit 1
    fi
else
    echo "Virtual Box \"$VM_NAME\" not found locally"
fi

#
# Download a seed for the VM
# TODO: Add Hash Validation
#
FILE_SEED="$PATH_DOWNLOADS/ubuntu-20-04-6-seed.iso"
if [[ FLAG_SKIP_IMPORT -eq 0 ]]; then
    if [ ! -d "$PATH_DOWNLOADS" ]; then
        mkdir -p "$PATH_DOWNLOADS"
    fi

    if [ ! -f "$FILE_SEED" ]; then
        curl -L -O "https://releases.ubuntu.com/focal/ubuntu-20.04.6-desktop-amd64.iso"
        mv ubuntu-20.04.6-desktop-amd64.iso "$FILE_SEED"
    fi
fi

#
# Create VM
#
echo -n "$VM_NAME: Creating VM..."
vboxmanage createvm --name $VM_NAME --ostype Ubuntu_64 --register &>> "$LOG_FILE" &&
    echo "Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

echo -n "$VM_NAME: Updating Settings..."
vboxmanage modifyvm $VM_NAME --vram $VM_VRAM --graphicscontroller $VM_GCON --nictype1 $VM_NAPT --cpus $VM_CPU --memory $VM_RAM --acpi on --boot1 dvd &>> "$LOG_FILE" &&
    echo "Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

echo -n "$VM_NAME: Enable bidirectional clipboard..."
vboxmanage modifyvm $VM_NAME --clipboard bidirectional --draganddrop bidirectional &>> "$LOG_FILE" &&
    echo "Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

#
# Create storage controllers - ignore errors - likely already in place
#
echo -n "$VM_NAME: Adding IDE Storage Controller..."
vboxmanage storagectl $VM_NAME --name IDE --add ide &> /dev/null || true &>> "$LOG_FILE" &&
    echo "Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

echo -n "$VM_NAME: Adding SATA Storage Controller..."
vboxmanage storagectl $VM_NAME --add sata --controller IntelAHCI --name "SATA Controller" &>> "$LOG_FILE" &&
    echo "Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

#
# Attach VDI HDD to SATA storage
#
echo -n "$VM_NAME: Creating HDD..."
vboxmanage createhd --filename ./$VM_NAME.vdi --size $VM_HDD --format VDI &>> "$LOG_FILE" &&
    echo "Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }
echo -n "$VM_NAME: Attaching HDD to SATA Controller..."
vboxmanage storageattach $VM_NAME --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ./$VM_NAME.vdi &>> "$LOG_FILE" &&
    echo "Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

#
# Setup SSH port forward on VM
#
INTERFACE="$(vboxmanage list hostonlyifs | grep "^Name:" | tr -s " " | cut -f2- -d" ")"
echo -n "$VM_NAME: Setting up SSH port forward from 127.0.0.1:$VM_SSH to Virtual Machine..."
vboxmanage modifyvm $VM_NAME --nic1 nat --natnet1 default --natpf1 ssh,tcp,127.0.0.1,$VM_SSH,,22 \
    --nic2 hostonly --hostonlyadapter2 "$INTERFACE" &>> "$LOG_FILE" &&
    echo "Success" ||
    { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

#
# Unattended Install
#
echo -n "$VM_NAME: Configuring Unattended Installation..."
vboxmanage unattended install $VM_NAME --iso "$FILE_SEED" \
                                       --user=$VM_USER \
                                       --password=$VM_PASS \
                                       --full-user-name="$VM_USER" \
                                       --install-additions \
                                       --language="en-gb" \
                                       --time-zone=UTC \
                                       --hostname=virtualmachine.local &>> "$LOG_FILE" &&
                                            echo "Success" ||
                                            { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

echo -e "${GREEN}VirtualBox VM's Setup Completed!\n${NC}"

echo -n "$VM_NAME: Starting VM..."
vboxmanage startvm "$VM_NAME" &>> "$LOG_FILE" &&
    echo "Success" ||
    { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

#
# Wait for VM to Start
#
while ! timeout 10 vboxmanage guestcontrol $VM_NAME run "//bin//ls" --username root --password $VM_PASS -- -c "//bin//ls" &> /dev/null; do
    echo "VM Not Ready... Waiting up to 60 seconds"
    sleep 60
done

#
# Environment Setup - timeout after 3 minutes
# TODO: pass $VM_NAME as parameter to environment script
#
echo -n "$VM_NAME: Copying Environment Script..."
vboxmanage guestcontrol $VM_NAME copyto --target-directory "." "environment.sh" --username root --password $VM_PASS &>> "$LOG_FILE" &&
    echo "Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

echo "$VM_NAME: Running Environment Script..."
vboxmanage guestcontrol $VM_NAME --username root --password $VM_PASS run "//bin//bash" --timeout 30000 --verbose --wait-stdout --wait-stderr -- -c "//bin//bash environment.sh" | sed -n '/^[^wv].*$/ s/\(.*\)/\1/p' &>> "$LOG_FILE" &&
    echo "Ignoring VERR_INVALID_HANDLE... Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

#
# Verify Script Success
# NB: the command to run the script may have succeeded but the script itself might have failed,
#     this checks that the script didn't return an exit code in the $LOG_FILE.
#
echo -n "$VM_NAME: Validating Script Execution..."
SUBCOMMAND=$(tail $LOG_FILE -n 2)
! grep -qi "Exit code=" <<< "$SUBCOMMAND" && echo "Success" ||
    { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

#
# Change Input Source to UK
#
# vboxmanage guestcontrol $VM_NAME --username $VM_USER --password $VM_PASS start "//bin//gsettings" --verbose -- -c "//bin//gsettings set org.gnome.desktop.input-sources sources '[(\'xkb\', \'gb\')]'" &>> "$LOG_FILE" &&
#     echo "Ignoring VERR_INVALID_HANDLE... Success" || { echo "Failure. Please check log at $LOG_FILE for more information."; exit 1; }

#
# SSH Setup
#
echo -e "$VM_NAME: ${GREEN}Setup complete!${NC}"
echo "$VM_NAME: Use "ssh $VM_USER@127.0.0.1" to connect to the VM via SSH"
