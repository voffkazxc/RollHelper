import sys
import socket

if len(sys.argv) > 1:
    msg = sys.argv[1].encode('utf-8')
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(msg, ("127.0.0.1", 5055))
    sock.close()
