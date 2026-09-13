from http.server import BaseHTTPRequestHandler, HTTPServer
import socket


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        hostname = socket.gethostname()

        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()

        response = f"Tera bhai seedhe-k8s!\nPod hostname: {hostname}\n"
        self.wfile.write(response.encode())


server = HTTPServer(("0.0.0.0", 8080), Handler)
server.serve_forever()
