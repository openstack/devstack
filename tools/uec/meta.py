#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import BaseHTTPServer
import SimpleHTTPServer
import sys


def main(host, port, HandlerClass=SimpleHTTPServer.SimpleHTTPRequestHandler,
         ServerClass=BaseHTTPServer.HTTPServer, protocol="HTTP/1.0"):
    """simple http server that listens on a give address:port."""

    server_address = (host, port)

    HandlerClass.protocol_version = protocol
    httpd = ServerClass(server_address, HandlerClass)

    sa = httpd.socket.getsockname()
    print("Serving HTTP on", sa[0], "port", sa[1], "...")
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
