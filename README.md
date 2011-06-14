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

    $ git clone git://github.com/codekitchen/tkellem.git
    $ cd tkellem
    $ bundle install
    $ bundle exec bin/tkellem start
    $ bundle exec bin/tkellem admin
    > help
    > listen ircs://0.0.0.0:8765
    > user --add <my-name> --admin
    > password --user <my-name> <my-new-password>
    > network --add --public freenode ircs://irc.freenode.org:7000

Then connect to tkellem with an irc client:

    server: localhost
    port: 8765
    ssl: yes

    nickname: <my-name>
    login: <my-name>@freenode
    server password: <my-new-password>
