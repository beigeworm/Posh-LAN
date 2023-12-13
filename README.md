# Posh-LAN

**SYNOPSIS**

LAN Toolset in Powershell Including File-Server, Screenshare and Reverse PS Shell, all over HTTP. 

Starts a HTTP server on the machine, open on port 8080.   

**USAGE**
1. Run the Script or stager on the target computer
2. Click 'yes' on the UAC prompt to allow script to run as Admin
3. Allow 10 seconds for setup then select an option
4. On another device on the same network, open a browser window and type the given IP address (Shown in setup window)

<h3>Why?</h3>
Transfer files, control the computer, view the screen on another device..

<h3>How?</h3>

1. Checks for Admin and restarts script
2. Opens firewall to incoming requests on port 8080
3. Sets folder as the folder the script/stager starts in
4. Defines Functions for options
5. Prompts the user to enter an option
6. Starts the webpage on the machine ip address

<h3>FAQ</h3>

1. Why admin? - Needed for opening ports in Windows firewall
2. Can the script be killed from the browser? - Yes.
3. Future Updates? - Coming soon.

# Screenshots

**Setup**
![setup](https://github.com/beigeworm/Posh-LAN/assets/93350544/0f3eb03d-dd32-40b4-b21e-8ed02614769f)

**File Server (In Browser)**
![files](https://github.com/beigeworm/Posh-LAN/assets/93350544/ce05e881-601d-47aa-b53d-2136e4ace725)

**Screenshare (In Browser)**
![scrn](https://github.com/beigeworm/Posh-LAN/assets/93350544/3b7fbb63-f6ee-4796-9e39-5fc4274f95ca)

**Commands (In Browser)**
![command](https://github.com/beigeworm/Posh-LAN/assets/93350544/5a85e798-a695-41bb-a562-66d982e38538)

# If you like my work please leave a star. ⭐
