# Bees for Rui

## RaspberryPi setup

1. Install OS in SD card

  1. Pick "Raspberry Pi OS Lite (32-bit)" in SD card

  2. Advanced settings (gear icon)

    * Set hostname
    * "Enable SSH" with "Use password authentication"
    * "Set username and password"
    * Do not configure wireless LAN
    * Set locale settings to "Europe/London"
    * Disable telemetry

2. Remote connection (SSH)

      ssh username@hostname.local

3. On first start update kernel which is at 5.15.84 and we need 6.1.19
   or later for arducam):

       sudo apt update
       sudo apt full-upgrade
       sud0 reboot

   After reboot, `uname -` should be higher

4. Install the things

       wget -O install_pivariety_pkgs.sh https://github.com/ArduCAM/Arducam-Pivariety-V4L2-Driver/releases/download/install_script/install_pivariety_pkgs.sh
       chmod a+x install_pivariety_pkgs.sh
       ./install_pivariety_pkgs.sh -p libcamera
       ./install_pivariety_pkgs.sh -p libcamera_apps

   Remove the crap:

       rm \
         libcamera0_0.git20230321+74d023d8-1_armhf.deb \
         libcamera-apps_0.git20230309+4def288-1_armhf.deb \
         libcamera_apps_links.txt \
         libcamera-dev_0.git20230321+74d023d8-1_armhf.deb \
         libcamera_links.txt \
         packages.txt

5. Configure boot

       sudo nano /etc/boot.config

   For one camera (without quadcam), add at the bottom of the file (in
   the `[all]` section):

       dtoverlay=arducam-64mp

   For one camera in the "Camera A" position of the quadcam, use:

       dtoverlay=camera-mux-4port,cam0-arducam-64mp

   For two cameras, one in the "Camera A" and "Camera C" position of
   the quadcam, use:

       dtoverlay=camera-mux-4port,cam0-arducam-64mp,cam2-arducam-64mp

6. Test:

       libcamera-hello --nopreview --list-cameras

   will print the list of cameras.

   To take images every 10 seconds for 30 seconds with camera 0
   (number is given by `libcamera-hello`, and name them image-X.jpg
   (where X is the image number with 4 digits), do:

       libcamera-still \
         --nopreview \
         --camera 0 \
         --timeout 30000 \
         --timelapse 10000 \
         --output 'image-%04d.jpg'
