# Imaging Nucs

The setup involves two [Raspberry
Pis](https://www.raspberrypi.com/products/), two [Arducam 64MP Hawkeye
cameras](https://www.arducam.com/64mp-ultra-high-res-camera-raspberry-pi/),
and one [Arducam Multi-Camera Adapter
module](https://www.arducam.com/product/multi-camera-v2-1-adapter-raspberry-pi/).
At least one of the Raspberry Pi must be a Raspberry Pi 4.  The
[Raspberry Pi touch
display](https://www.raspberrypi.com/products/raspberry-pi-touch-display/)
makes it easier to use later.

Two Pis are used because we need to use separate Pis for controlling
the cameras and displaying the images.  The 64MP cameras being used
are [only reliable with the Raspberry Pi OS
Lite](https://docs.arducam.com/Raspberry-Pi-Camera/Native-camera/Troubleshooting/#7-cannot-allocate-memory-on-arducam-64mp-autofocus-camera-module)
which means no graphical display.  Since manual review of each image
is required during acquisition, a second Pi is used to display.

So: one of the Pis is the "imager" Pi.  The imager Pi has two cameras
and no display.  The other Pi is the "controller" Pi.  The controller
Pi controls the imager Pi remotely and displays the acquired images
for review.


## Network setup

The two Pis are connected by ethernet.  The controller runs a DHCP
server on the ethernet port.  The reason to not use static IP
addresses is that the imager has no display we don't want to be
messing around with its network configuration.  The controller Pi has
a display so we can change its configuration easily.

The controller also runs a [NFS
server](https://www.raspberrypi.com/documentation/computers/remote-access.html#network-file-system-nfs)
exporting `/srv/nfs/images/` which the imager mounts locally.  The
imager saves the images directly to the remote filesystem so the
controller can display upon acquisition.


## Security

No care was taken for security because there's no time and the two Pis
are planned to only be connected to each other.


## Setup of the imager Pi

The "imager" Pi must be a RaspberryPi 4.  Two Arducam 64MP Hawkeye
cameras are connected to it through the Arducam Multi-Camera adapter.
This Pi has no graphical display.  Instead, connect to it by ssh.

1. Install OS in SD card:

  1. Pick "Raspberry Pi OS Lite (32-bit)" in SD card

  2. Advanced settings (gear icon)

    * Set hostname
    * "Enable SSH" with "Use password authentication"
    * "Set username and password"
    * Do not configure wireless LAN
    * Set locale settings to "Europe/London"
    * Disable telemetry

2. Remote connection (replace `imager-username` and `imager-hostname`
   with whatever you picked during the OS install step):

      ssh imager-username@imager-hostname.local

3. On first start update kernel (which is at 5.15.84 but 6.1.19 or
   later is needed for the 64MP cameras):

       sudo apt update
       sudo apt full-upgrade
       sudo reboot

   After reboot, `uname -a` should show a kernel version number higher.

4. Install the arducam version of libcamera:

       wget -O install_pivariety_pkgs.sh https://github.com/ArduCAM/Arducam-Pivariety-V4L2-Driver/releases/download/install_script/install_pivariety_pkgs.sh
       chmod a+x install_pivariety_pkgs.sh
       ./install_pivariety_pkgs.sh -p libcamera
       ./install_pivariety_pkgs.sh -p libcamera_apps

   and remove the crap their "installer" leaves behind:

       rm \
         libcamera0_0.git20230321+74d023d8-1_armhf.deb \
         libcamera-apps_0.git20230309+4def288-1_armhf.deb \
         libcamera_apps_links.txt \
         libcamera-dev_0.git20230321+74d023d8-1_armhf.deb \
         libcamera_links.txt \
         packages.txt

5. Configure the cameras by editing the `/etc/boot.config` file:

       sudo nano /etc/boot.config

   What to add to the file, depends on the camera setup.  The line
   should be added at the bottom of the file (in the `[all]` section).

   - For one camera (without quadcam):

         dtoverlay=arducam-64mp

   - For one camera in the "Camera A" position of the quadcam:

         dtoverlay=camera-mux-4port,cam0-arducam-64mp

   - For two cameras, in the "Camera A" and "Camera C" positions of
     the quadcam:

         dtoverlay=camera-mux-4port,cam0-arducam-64mp,cam2-arducam-64mp

   Then reboot with `sudo reboot`

6. Test.

   After rebooting, this will display the list of cameras:

       libcamera-hello --nopreview --list-cameras

   To take images every 10 seconds for 30 seconds with camera 0
   (number is given by `libcamera-hello`), and name them `image-X.jpg`
   (where `X` is the image number with 4 digits), do:

       libcamera-still \
         --nopreview \
         --camera 0 \
         --timeout 30000 \
         --timelapse 10000 \
         --output 'image-%04d.jpg'


## Setup of the controller Pi

1. Install OS in SD card.

  1. Pick "Raspberry Pi OS (32-bit)" in SD card

  2. Advanced settings (gear icon)

    * Set hostname
    * "Enable SSH" with "Use password authentication"
    * "Set username and password"
    * Do not configure wireless LAN
    * Set locale settings to "Europe/London"
    * Disable telemetry

2. On first start update everything.  No special reason other than get
   any pending updates and running the same versions as the imager:

       sudo apt update
       sudo apt full-upgrade
       sudo reboot

3. Install graphicsmagick (to resize the images for faster display):

       sudo apt install graphicsmagick

4. Setup the NFS server.

   1. Install the NFS server

          sudo apt install nfs-kernel-server

   2. Set `NEED_SVCGSSD` to `"no"` in `/etc/default/nfs-kernel-server`

          sudo nano /etc/default/nfs-kernel-server

   3. Create the directories:

          sudo mkdir /srv/images
          sudo mkdir /srv/nfs
          sudo mkdir /srv/nfs/images
          sudo chmod 777 /srv/nfs /srv/nfs/images

      mount it automatically by adding this line to `/etc/fstab`:

          echo "/srv/images  /srv/nfs/images  none  bind  0  0" | sudo tee -a /etc/fstab

      and configure the server to export them by adding these lines to
      `/etc/exports`:

          /export        192.168.0.0/24(rw,fsid=0,insecure,no_subtree_check,async)
          /export/images 192.168.0.0/24(rw,nohide,insecure,no_subtree_check,async)

   4. Assuming that the controller is on a local network
       `192.168.0.0/24` and has the IP address `192.168.0.77` the
       `images` export should be available to clients with:

           sudo mount -t nfs 192.168.0.77:/images /mnt

5. Setup the DHCP server.  Beware with filenames. `dhcpcd` is for the
   DHCP Client Daemon while `dhcpd` is for the DHCP (server) Daemon.

   1. Install the DHCP server:

          sudo apt install isc-dhcp-server

   2. Setup static IP address for ourselves by adding to
      `/etc/dhcpcd.conf`:

          profile static_eth0
          static ip_address=192.168.0.1/24

          interface eth0
          fallback static_eth0

   3. Configure network in `/etc/dhcp/dhcpd.conf` by commenting out
      the domain name options:

          #option domain-name "example.local";
          #option domain-name-servers ns1.example.org, ns2.example.org;

      and configuring the subnet (remember that we're only exporting
      the NFS mounts to `192.168.0.0/24`):

          subnet 192.168.0.0 netmask 255.255.255.0 {
              range 192.168.0.1 192.168.0.254;
          }

   4. And configure DHCP to serve on the interface by adding on
      `/etc/default/isc-dhcp-server`:

          DHCPDv4_CONF=/etc/dhcp/dhcpd.conf
          DHCPDv4_PID=/var/run/dhcpd.pid
          INTERFACESv4="eth0"


## Start up steps

This part is a bit of a mess and needs to be done properly.

The DHCP server won't start unless `eth0` is up but that is being
managed by `dhcpcd` which won't bring the `eth0` up unless it's
connected to something (even if configured with static IP address).
The order that the `dhcpcd` and `isc-dhcp-server` services start may
also be an issue.  So the imager needs to be up and connected before
the DHCP server starts but then the imager it won't get an IP address.
So here's the hack:

1. Start with both Pis turned off and connected with an ethernet
   cable.

2. Turn on the imager Pi.  Wait for the start to complete.

3. Turn on the controller Pi.  Wait for the start to complete.

4. In the controller Pi, restart the DHCP daemon:

       sudo systemctl restart isc-dhcp-server.service

5. Turn the imager Pi off and on again.  Wait for the start to
   complete.

6. We should now be able to ssh from the controller into the imager:

       ssh imager-username@imager-hostname.local


## First time configuration once the two Pis are connected

1. The script that controls the imager connects over ssh each time
   that it sends a command to acquire an image.  To avoid having to
   enter password each time we use passwordless SSH keys (we should
   use a SSH key agent instead but this is a network with only this
   two Pis).  See, [Passwordless SSH Access on the Raspberry Pi
   documentation](https://www.raspberrypi.com/documentation/computers/remote-access.html#passwordless-ssh-access)

   1. First generate a SSH key on the controller (don't change the
      file and leave the password empty):

          ssh-keygen

   2. Then add the SSH key to the list of authorized keys in the
      imager (it will ask you the user password for the imager):

          ssh-copy-id imager-username@imager-hostname.local

   3. You should now be able to ssh to the imager without being asked
      for a password.

2. Mount the controller `images` mount point in the imager.

   1. In the imager, create the mount point:

          sudo mkdir /srv/images

   2. We should be able to mount it manually (in the imager):

          sudo mount -t nfs controller-hostname.local:/images /srv/images
          sudo umount /srv/images

   3. To mount it automatically, run in the imager:

          echo "controller-hostname.local:/images  /srv/images  nfs  auto  0  0" | sudo tee -a /etc/fstab
          sudo mount /srv/images


## Test

Once everything is connected, we should be able to control image
acquisition from the controller.  Test these commands in the
controller:

1. Get list of cameras:

       ssh imager-username@imager-hostname.local \
           libcamera-hello --nopreview --list-cameras

2. Acquire an image:

       ssh imager-username@imager-hostname.local \
           libcamera-still \
               --nopreview \
               --camera 0 \
               --output '/srv/images/test-image.jpg'

3. View the image:

       gpicview /srv/images/test-image.jpg


## Running the experiment

Just run this script in the controller and follow the instructions:

    ./image-experiment.sh imager-username@imager-hostname.local
