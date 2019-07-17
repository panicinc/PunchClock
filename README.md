PunchClock
==========

PunchClock is an in/out tracking app for iOS 7+ that uses iBeacon and Geofencing.

![PunchClock Screenshot](http://www.panic.com/blog/wp-content/uploads/2014/07/PunchClock.png)

**PunchClock cannot operate on its own - It requires the [PunchClockServer](https://github.com/panicinc/PunchClockServer).**

Building
--------

In order to build PunchClock you'll need run the install script:

- `$ ./setup`

This script sets up a `constants.h` file, two **.xcconfig** files and runs `pod install`

The `constants.h` file will need to be customized for your environment. It's meant to allow you to run PunchClock against a local copy of the server during development and a production server after release. If you don't plan to use the Hockey or push notifications you can set those things to nil.

Code-signing is managed in the two **xcconfig** files. You'll need to paste in your provisioning profile UUIDs or you can manage code-signing in the workspace directly but you'll need to be careful about pushing these changes back in any subsequent pull-requests.

Usage
-----

When PunchClock is first launched you'll be prompted for your name which will get stashed in the keychain and used as the key in the server-side database. This is a pretty naive way to go about things but it Works For Us™. The app will then ask the server for a list of all of the people and will get back some JSON showing everyone's status as well as who is watching who. Tapping the bell icon will mark you as tracking that person and you'll receive a push notification when their status changes. If you're being watched by anyone then there will be an eye icon next to their name. Tapping the chat icon in the top-left will allow you to send a message to anyone marked as "In".

The Information tab simply shows you the data that Core Location is returning. It can be useful for fine-tuning the placement of iBeacons and geo-fence settings. Tapping your name here allows you to change it. **Note: the server doesn't currently manage name changes automatically - you'll end up with a new record.**

Contributing
------------

**PunchClock is no longer being updated**

Bug Reporting
-------------

**PunchClock is an unsupported, unofficial Panic product.** 

## EDIT

