import os, socket, subprocess, tempfile, threading, time, http.server, hashlib, sys
class H(http.server.BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def log_message(self,*a): pass
    def do_GET(self):
        if self.headers.get('Upgrade','').lower()=='websocket':
            self.send_response(101);self.send_header('Upgrade','websocket');self.send_header('Connection','Upgrade');self.send_header('Sec-WebSocket-Accept','s3pPLMBiTxaQ9kYGzzhZRbK+xOo=');self.end_headers();self.wfile.flush()
            self.rfile.read(8);self.wfile.write(b'\x81\x02ok');self.wfile.flush();self.close_connection=True;return
        data=(self.path+'|'+self.headers.get('Host','')+'|'+self.headers.get('Origin','')+'|'+str(self.headers.get('X-Trim-Isadmin'))).encode()
        self.send_response(200);self.send_header('Content-Length',str(len(data)));self.send_header('X-Frame-Options','SAMEORIGIN');self.end_headers();self.wfile.write(data)
    def do_POST(self):
        n=int(self.headers['Content-Length']); h=hashlib.sha256()
        while n:
            b=self.rfile.read(min(n,65536)); n-=len(b);h.update(b)
        d=h.hexdigest().encode();self.send_response(200);self.send_header('Content-Length',str(len(d)));self.end_headers();self.wfile.write(d)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),H);threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory() as d:
    s=d+'/app.sock';p=subprocess.Popen([sys.argv[1],s,f'127.0.0.1:{server.server_port}'])
    try:
        for i in range(100):
            if os.path.exists(s):break
            time.sleep(.02)
        def curl(path,*args):return subprocess.check_output(['curl','-sS','--max-time','15','--unix-socket',s,'http://nas:5666'+path,*args])
        assert curl('/app/ps5upload/','-o','/dev/null','-w','%{http_code}')==b'403'
        assert curl('/app/ps5upload/','-H','X-Trim-Isadmin: true','-H','Origin: http://nas:5666')==b'/app/ps5upload/|nas:5666|http://nas:5666|None'
        assert curl('/other','-H','X-Trim-Isadmin: true','-o','/dev/null','-w','%{http_code}')==b'404'
        assert b'x-frame-options: sameorigin' in curl('/app/ps5upload/','-H','X-Trim-Isadmin: true','-i').lower()
        data=b'x'*(32*1024*1024);f=d+'/payload';open(f,'wb').write(data)
        assert curl('/app/ps5upload/upload','-H','X-Trim-Isadmin: true','--data-binary','@'+f)==hashlib.sha256(data).hexdigest().encode()
        w=socket.socket(socket.AF_UNIX);w.settimeout(3);w.connect(s);w.sendall(b'GET /app/ps5upload/ws HTTP/1.1\r\nHost: nas:5666\r\nX-Trim-Isadmin: true\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n');b=b''
        while b'\r\n\r\n' not in b:
            chunk=w.recv(4096)
            if not chunk: raise RuntimeError('upgrade disconnected')
            b+=chunk
        assert b'101 Switching Protocols' in b,b
        w.sendall(b'\x81\x82abcd\x09\x0b');r=b''
        while len(r)<4:
            chunk=w.recv(4-len(r))
            if not chunk: raise RuntimeError('WebSocket disconnected')
            r+=chunk
        assert r==b'\x81\x02ok',r;w.close()
        print('PASS: Unix socket, admin check, path restriction, Host/Origin, security headers, 32 MiB SHA256, WebSocket')
        print(next(l.strip() for l in open(f'/proc/{p.pid}/status') if l.startswith('VmRSS:')))
    finally:
        p.terminate();p.wait(timeout=5)
