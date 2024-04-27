# Overview
This repo is intended to help developers and administrators who want to write
a script to automatically set up a raspberry pi.  The real target audience are
those who contribute to open source projects.  For example, the first use
of this project was to develop an install script for the
[HestiaPi](https://hestiapi.com/).

The idea is you write a script, or series of scripts, that will SSH into a
stock raspberry pi (according to the project(s) you are building on), install
the packages you want, and set up configuration files to match your deployment
environment.  Then, you use build_emulator.sh from this repo to test your script
before you deploy it to hardware, to make sure it doesn't (for example) cut off
your access to a potentially difficult-to-restore system.

To build a HestiaPi image using Jessie, run:

```
./build_emulator.sh arm1176 jessie wrapper.sh
```

To build a HestiaPi image using Stretch, run:
```
./build_emulator.sh arm1176 stretch wrapper.sh
```


# Getting started
First, you need to describe the state you expect the hardware to be in before
your customization script runs.  To do this, you configure some environment
variables in a script named BASE_VERSION.sh.  This repo already includes
configurations to emulate the official Raspbian lite distros for stretch and
buster.

Next, write your configuration script to SSH into localhost on port 5022
(which maps to port 22/sshd on your emulated pi) and do the actual
configuration.  Call it CONFIG.sh.

Put the contents of this repo, your BASE_VERSION.sh if you wrote a new one,
and CONFIG.sh in the same directory.  Make sure your new .sh scripts are
executable.  From that working directory, run:

```sh
./build_emulator.sh CPU BASE_VERSION CONFIG.sh
```

You can include as many CONFIG arguments as you want; they will be run in order.

If your CONFIG.sh isn't perfect on the first iteration, simply kill QEMU (e.g.
press crtl-c on the terminal where you launched build_emulator.sh) if it is
still running, and re-run build_emulator.sh.  When it asks if you want to
overwrite the .img file, say yes.  This will make sure you are starting from a
fresh image.

When your script appears to run perfectly, log into the guest system and shut
it down.  Then start it back up from the same working directory:

```sh
./resume.sh CPU BASE_VERSION
```

This will boot up the machine normally.  You can log in on the
console to explore the emulated pi and confirm that your script worked.

# Less common tasks

## Creating new base versions
Each BASE_VERSION.sh must specify

 - the locations of
    - a filesystem image
    - a matching kernel a suitable for use by qemu
    - a compiled device tree
- login credentials for an account with sudo access on the pi

You configure build_emulator.sh to find these items by exporting environment
variables in BASE_VERSION.sh.

Some good places to look for these items:

 - [official Raspberry Pi OS downloads](https://www.raspberrypi.org/downloads/raspberry-pi-os/)
 - image downloads for the specific Pi project you want to use, e.g. [HestiaPi
 downloads](https://hestiapi.com/downloads/)
 - [the QEMU Raspberry Pi project](https://github.com/dhruvvyas90/qemu-rpi-kernel)

## Re-enabling SSH
If your last CONFIG disabled SSH, but you need to log in via ssh for some reason, re-run:

```sh
./build_emulator.sh CPU BASE_VERSION
```

Do not specify a CONFIG (unless you have an additional one that must be applied
after a reboot).  When it asks if you want to overwrite the .img file, say no.

Note that if you re-enable SSH and save the VM, it will still have SSH enabled when you resume it later.

# Under the hood
The build_emulator.sh script:

 - Loads environment variables from BASE_VERSION.sh
 - Downloads the files described in BASE_VERSION.sh
 - Uses turn_on_ssh.ex to actually start running Rasbian in QEMU, automatically
log into the guest O/S, and enable SSH on guest:22/host:5022
 - Runs each CONFIG in the order given

There are numerous assumptions in the existing code. Please embrace and extend.

# Enabling new platforms
Currently, only the Raspberry Pi Zero and Raspberry Pi 2b are emulated.  In order
to add more, the things that may need changed are the arguments to qemu:

- `-kernel` - to boot a kernel that is compatible with the CPU
- `-cpu` - to use a cpu that is compatible with the kernel
- `-m` - to change the amount of memory of the emulated device
- `-M` - to tell qemu what hardware to emulate (apart from the CPU)
- `-dtb` - the Device Tree Blob to specify what harware to emulate

If you are not getting any output from QEMU, there are a number of possible causes.

- The `-machine` argument to qemu isn't right
- The kernel arguments are sending it to TTYAMA0, but that doesn't exist
- The `-serial` argument to qemu isn't sending data to the screen

Once you can see the output, you may get a kernel panic, such as the one listed
below:

```
[    2.400710] Internal error: synchronous external abort: 96000010 [#1] PREEMPT SMP
```

There's a [closed issue](https://gitlab.com/qemu-project/qemu/-/issues/317) that sounds
like it's related, and the issue has reportedly been fixed in June of 2021.  Looking at
[the diff](https://gitlab.com/qemu-project/qemu/-/commit/a6091108aa44e9017af4ca13c43f55a629e3744c),
it appears the change is not in
[5.2.0](https://gitlab.com/qemu-project/qemu/-/blob/v5.2.0/hw/pci-host/gpex.c), but was
first introduced in
[6.1.0](https://gitlab.com/qemu-project/qemu/-/blob/v6.1.0/hw/pci-host/gpex.c#L89).

If you need a newer version, you can check to see if there are
[packages](https://pkgs.org/download/qemu) available, but likely you will need
to compile it yourself and put it in your PATH before the stock version (e.g.,
/usr/local/bin which typically comes before /usr/bin in people's PATH).
