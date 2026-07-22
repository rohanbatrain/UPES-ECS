UPES-ECS Emergency PBX  -  Please read before installing


WHAT THIS INSTALLS
   A complete, self-contained emergency phone system that runs on this PC inside a
   pre-provisioned virtual machine. No internet connection, Python, or QEMU install
   is required - everything is included.

REQUIREMENTS
   -  64-bit Windows 10 (build 1809 or newer) or Windows 11
   -  About 14 GB of free disk space
   -  Administrator rights (to open the phone ports in the Windows firewall)

WHAT SETUP WILL DO
   -  Install the phone-server virtual machine and boot it (first boot is instant,
      offline - no downloads)
   -  Open the SIP / RTP firewall ports
   -  Start the Operations Console at http://localhost:8080
   -  Place a "UPES-ECS Repair" shortcut on your Desktop for recovery

AFTER INSTALL
   -  Phones register to  upes-ecs.local:5060  and dial  111  for emergencies.
   -  The system starts automatically at each logon.

Deploying the ~10 GB phone server takes a few minutes. Please be patient and do not
close Setup until it finishes.
