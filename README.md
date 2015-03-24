# tkellem

[![Build
Status](https://travis-ci.org/codekitchen/tkellem.png)](https://travis-ci.org/codekitchen/tkellem)
[![Code Climate](https://codeclimate.com/github/codekitchen/tkellem.png)](https://codeclimate.com/github/codekitchen/tkellem)
[![Coverage Status](https://coveralls.io/repos/codekitchen/tkellem/badge.png)](https://coveralls.io/r/codekitchen/tkellem)


tkellem is an IRC bouncer, a proxy that keeps you permanently logged on to an
IRC server and stores all messages so that when your client next connects, you
can see the backlog of what happened while you were gone.

tkellem supports multiple users, multiple device-independent backlogs
per-user, and connecting to multiple IRC servers all from the same
process.

## Project Status

I am no longer actively developing Tkellem, since I'm no longer on IRC day-to-day. My company switched to another chat protocol. Maintainers are welcome.

## Getting Started

This will have to do as a quickstart guide, for now:

    $ gem install tkellem
    $ tkellem start
    $ tkellem admin
    > help
    > listen ircs://0.0.0.0:8765
    > user <my-name> --role=admin
    > password --user=<my-name> <my-new-password>
    > network --public --name=freenode ircs://irc.freenode.org:7000

Then connect to tkellem with an irc client:

    server: localhost
    port: 8765
    ssl: yes

    nickname: <my-name>
    login: <my-name>@freenode
    server password: <my-new-password>

Note that all config and log files are stored in ~/.tkellem of the user
you run `tkellem start` as. You also need to run `tkellem admin` as this
same user, in order to have access to the admin console.

## Devices

Each user can connect with multiple devices. Devices are specified in your
login by appending `:<device-name>` to your login. Example:

    login: <my-name>@freenode:work-machine

If there is no `:<device-name>` appended to your login, tkellem just uses a
default device.

Using multiple devices simply marks separate points in the backlog so you
get only the relevant backlog on a per-device basis.

## Upgrading

Upgrading is as simple as:

    $ gem install tkellem
    $ tkellem restart

All active clients will be forced to re-connect. Their positions in the backlog will not
be lost, so restarting is relatively painless.
