Ansible playbooks are run from a machine (the deployer) and they SSH into
the target machine (a raspberry pi in this case) which will configure the
target in a particular way (in this case, to be a HestiaPi).

# Preperation
In order to use the ansible playbook, you'll need to have the following:

- Ansible installed on the machine on which you are running the playbook
- SSH keys set up to log into the target machine without user interaction
- Install python on the target machine (already done in most cases)

Typically, this is just a matter of something like this:

- `sudo apt install ansible`
- `scp $HOME/.ssh/id_ed25519.pub pi@192.168.0.42:.ssh/authorized_keys
  - If you don't have SSH keys yet, run `ssh-keygen -t ed25519` first

# Usage
After preperation is done, you can run a playbook from this directory like so:

```sh
# First we patch the machine (and avoid shutting down when done)
ansible-playbook -i 192.168.0.42, \
    --extra-vars "device=mmcblk0 partition_1=mmcblk0p1 partition_2=mmcblk0p2 shutdown=false" upgrade.yml
# Then we can run the hestiapi playbook (and allow the shutdown at the end to happen)
ansible-playbook -i 192.168.0.42, \
    --extra-vars "device=mmcblk0 partition_1=mmcblk0p1 partition_2=mmcblk0p2" hestiapi.yml

# Both scrips will attempt to ensure the second partition takes up the maximum
# size of the disk, and the filesystem takes the maximum size of the partition
# This is why we need to pass in the device info twice.
```

You will need to change the IP address accordingly, and if your SD card shows up
as a different device (e.g. sda) then you'll need to change the mmcblk0 to be
something like "sda1". The scripts that make sure the partition and filesystem
each take up the entire disk require there to be exactly two partitions. The
second one will be expanded to fill all available space.

Ansible will tell you what it is doing as it goes along as well as if it was
successful for each task. All tasks should have a status of "ok" or "changed"
if everything is working proerly.

# Contribution
Properly written playbooks, such as this one, should be able to be run multiple
times without causing any issues. This is known as being idempotent.

A common problem when automating a task is that configuration settings will be
appended to a file without checking to see if they are already there. This
results in the configuration file having duplicate lines at the end.

If you contribute any changes to this project, please take care to ensure that
the playbook is still idempotent.
