# JetiLogfilePlayer
Jeti Log File Player 

Warning

The application is designed to replay log files on the Jeti emulator to test new lua application against previous 
recorded log files. The player is a development tool.
The application should never be used on a real device to to avoid any unpredictable behavior of a remote controlled device.


Description

The application is a development tool to test lua applications with previous recorded log file data.
Instead of using a real logfile you can build your own test case file to simulate your test-app.
A free selectable switch can control the player. The control switch is always taken from the emulator.
The player has four states: 
 - initialiesed
 - reset/stopped
 - playing
 - finished
User feedback is given in the emulator debug window.


Usage

1. Install the player application parallel to the to-test-application
2. Select a log file from the "Log" folder
3. Select a switch to "start" or "reset" the log file player
4. The test application can retrieve values form the log file through the system calls:
  - system.getSensors ()
  - system.getSensorByID (sensor ID, sensor param)
  - system.getSensorValueByID (sensor ID, sensor param)
  - system.getInputsVal (Input1,...) - limited functionality!
  - system.getInputs (...)
  - system.getTxTelemetry ()

Demo
Install the default.log file in the emulator ../Log dir.
Istall the LPTest.lua in the ../App folder
Start the Player with the control switch.
When everything went well you should see:
LP: Test Sensor
LP: initillised
LP: playing
signal A = 1.016  (min: 0.015, max: 1.016)
...

Please select the player's Telemetry window to see some basic information: status, playtime, file ...

The SwPoMoni Program is a simple montior to show some input values frome the player in a Telemetry window.

The print monitor (separate directory) is an additional debug tool, to visualize some internal values of your program.
