from telnetlib import Telnet
import sys

username = b"root\n"
password = b"s\n"

server = 'localhost'
#port = 3456
port = int(sys.argv[1])

#gups command
commands = [b"/m5 exit\r\n", b"/seq-list -s 2 -e 1\r\n", b"/m5 exit\r\n" ]
#commands = [b"./m5 exit\r\n", b"./Graph500/seq-list/seq-list -s 15 -e 15\r\n", b"./m5 exit\r\n" ]

with Telnet(server, port) as tn:
    tn.read_until(b"login: ")
    tn.write(username)
    tn.read_until(b"Password: ")
    tn.write(password)
    for c in commands:
        tn.write(c)
