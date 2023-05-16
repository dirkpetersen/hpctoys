#!/usr/bin/env python3

from flask import Flask, request
from dnslib import RR, A, DNSRecord, DNSHeader, QTYPE, dns
from dnslib.server import DNSServer, DNSHandler, BaseResolver
import threading, os, socket

class DynamicResolver(BaseResolver):
    def __init__(self):
        self.records = {}
        self.public_dns = self.load_resolvers()

    def load_resolvers(self):
        resolvers = []
        with open('/etc/resolv.conf', 'r') as f:
            for line in f:
                if line.startswith('nameserver'):
                    ip = line.split()[1]
                    resolvers.append(ip)
        return resolvers

    def external_resolve(self, request):
        for resolver in self.public_dns:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(1)
            try:
                sock.sendto(bytes(request.pack()), (resolver, 53))
                data, _ = sock.recvfrom(1024)
                return DNSRecord.parse(data)
            except socket.timeout:
                continue
            finally:
                sock.close()
        return None

    def resolve(self, request, handler):
        q = request.q
        if str(q.qname) in self.records:
            a = RR(q.qname, QTYPE.A, rdata=A(self.records[str(q.qname)]))
            return DNSRecord(DNSHeader(id=request.header.id, qr=1, aa=1, ra=1), q=q, a=a)
        else:
            return self.external_resolve(request) or request.reply()


resolver = DynamicResolver()
dns_server = DNSServer(resolver)

app = Flask(__name__)

@app.route('/update_record', methods=['POST'])
def update_record():
    hostname = request.form.get('hostname')
    ip = request.form.get('ip')

    # Add or Update DNS record
    resolver.records[hostname] = ip

    # Update DNS record in file
    with open('dns_records.txt', 'r') as f:
        lines = f.readlines()
    with open('dns_records.txt', 'w') as f:
        for line in lines:
            if line.split(',')[0] != hostname:
                f.write(line)
        f.write(f'{hostname},{ip}\n')

    return 'OK', 200

def load_records():
    # Load DNS records from file
    if os.path.exists('dns_records.txt'):
        with open('dns_records.txt', 'r') as f:
            for line in f:
                hostname, ip = line.strip().split(',')
                resolver.records[hostname] = ip

if __name__ == '__main__':
    # Load DNS records
    load_records()

    # Start the DNS server
    threading.Thread(target=dns_server.start).start()

    # Start the Flask app
    app.run(host='0.0.0.0', port=5000)