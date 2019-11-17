# JetiLogfilePlayer
Jeti Log File Player 

Warning

The application is designed to replay log files on the Jeti emulator to test new lua application against previous 
recorded log files. The player is a development tool.
The application should never be used on a real device to to avoid any unpredictable behavior of a remote controlled device.


Description

The application is a development tool to test lua applications with previous recorded log file data.
A free selectable switch can control the player. The control switch should not be contained in the log file data.
The player has four states: 
 - not initialiesed
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
  - system.getInputsVal (Input1,...)
  - system.getTxTelemetry ()
