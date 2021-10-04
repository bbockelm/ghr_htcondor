
A Mac OS X GitHub runner for public repos
=========================================

This repository contains the scripts and instructions for taking a MacOS-based server
and turning it into a reasonably secure GitHub runner.  We will do this by creating
a VM that will take in a token for authenticating with GitHub, launch an ephemeral
GitHub self-hosted runner, and shut itself down after a single job is finished.

Creating a MacOS VM guest
-------------------------

These instructions are adopted from <https://oleksandrkirichenko.com/blog/macos-ci-on-a-budget/>.

Make sure you have about 60GB of free disk space for this procedure.

1. Download the latest MacOS installer from the Mac App Store.  Yes, simply download it as if
   it was a normal application - it'll drop it in a directory mentioned below.
2. Create a temporary disk image which we will use to create a macOS installation ISO:
   ```
   hdiutil create -o /tmp/BigSur -size 16G -layout SPUD -fs HFS+J -type SPARSE
   ```
3. Mount it:
   ```
   hdiutil attach /tmp/BigSur.sparseimage -noverify -mountpoint /Volumes/mac_install
   ```
4. Using the `createinstallmedia` utility from the MacOS distribution, make the mounted image a macOS installation image
   ```
   sudo /Applications/Install\ macOS\ Big\ Sur.app/Contents/Resources/createinstallmedia --volume /Volumes/mac_install
   ```
5. Unmount it:
   ```
   hdiutil detach /Volumes/Install\ macOS\ Big\ Sur.
   ```
   You may need the -force flag if it is constantly busy.

6. Convert the Sparse image into an ISO one
   ```
   hdiutil convert /tmp/BigSur.sparseimage -format UDTO -o /tmp/BigSur.iso
   ```
7. Move your ISO file to the desktop, changing the extension from cdr to iso
   ```
   mv /tmp/BigSur.iso.cdr ~/Desktop/BigSur.iso
   ```
8. Delete the temporary image
   ```
   rm /tmp/BigSur.sparseimage
   ```

At this point, we have a valid ISO for installing Mac OS X!

Create a VM using VirtualBox
----------------------------

1. Install VirtualBox and its optional extensions.
2. Ensure there is at least 4GB of RAM, 128MB of video memory, and 4 cores for the CI runner.
3. Create a 160GB disk image.  In our testing, you can probably get away with 100GB -- but assuming you select
   dynamic allocation, the difference should be fine.
4. Add the ISO file created in the previous section into the optical drive.


Install MacOS
-------------

1. Boot your new VM in VirtualBox.
2. Open Disk Utility and format your new virtual disk.
3. Install MacOS
4. Configure a new user with admin rights and memorable password.
5. Disable the screensaver and any energy savings.
6. Set the user to Automatic Login.

Configure and Install Dependencies
----------------------------------

1. Open the Apple Store.  Sign in with your credentials.
2. Install XCode.  This will take awhile.
3. Install the command line tools for XCode:
   ```
   sudo xcode-select --install
   ```
4. Install homebrew:
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
5. Install any additional dependencies:
   ```
   brew install cmake
   brew install ninja
   brew install boost-python3
   ```
6. Install `scitokens-cpp` from <https://github.com/scitokens/scitokens-cpp>
7. Install a GitHub runner following the instructions at <https://github.com/organizations/htcondor/settings/actions/runners/new>

You may need to adjust the image a few times to get things right.  To do this, startup the image,
tinker with it, shut it down, and then make sure you delete any prior snapshots (the CI startup
script will automatically restore old snapshots on restart).

Create an Automator Application
-------------------------------

1. Open the Automator application and create a new "Application".
2. Add a step of type "Run Shell Script".
3. Copy the contents of `startup_script.sh` as the shell script for the application.
4. Save the application.  In System Preference's tab on Users, set this application to
   run on login.

Shutdown the VM for now.

Test-run the GitHub runner startup
----------------------------------

Create a personal access token with the `public_repo` scope.  Put it in the `gh_token` file in this repo.

Run the `oneshot_runner.sh` script.  This should create a snapshot, a runner registration token, and a
corresponding ISO containing this information.  Once this is done, it'll startup the VM.

Ensure VM starts along with the Automator application.  You may need to approve a few permissions
in order for it to start smoothly.

Each time you want to preserve the changes made, after shutting down the VM, run:

```
VBoxManage snapshot BigSurCI delete BigSurCI-pre
```

Otherwise, on the next startup, the `oneshot_runner.sh` will restore from that snapshot.

Finish Automations
------------------

Create a launchd plist that autmatically restarts the `oneshot_runner.sh` whenever it shuts down.
(Yes, this part needs to be fleshed out).  Probably need a few clones of the VM so multiple runners
can coexist on the same server.
