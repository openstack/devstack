import sys
from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
from SimpleHTTPServer import SimpleHTTPRequestHandler

def main(host, port, HandlerClass = SimpleHTTPRequestHandler,
         ServerClass = HTTPServer, protocol="HTTP/1.0"):
    """simple http server that listens on a give address:port"""

    server_address = (host, port)

    HandlerClass.protocol_version = protocol
    httpd = ServerClass(server_address, HandlerClass)

    sa = httpd.socket.getsockname()
    print "Serving HTTP on", sa[0], "port", sa[1], "..."
    httpd.serve_forever()

if __name__ == '__main__':
    if sys.argv[1:]:
        address = sys.argv[1]
    else:
        address = '0.0.0.0'
    if ':' in address:
        host, port = address.split(':')
    else:
        host = address
        port = 8080

    main(host, int(port))
