# tkellem

tkellem is an IRC bouncer, a proxy that keeps you permanently logged on to an
IRC server and stores all messages so that when your client next connects, you
can see the backlog of what happened while you were gone.

tkellem supports multiple users, multiple device-independent backlogs
per-user, and connecting to multiple IRC servers all from the same
process.

## IMPORTANT

This is still a pretty early alpha. Expect bugs and missing
functionality.

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
