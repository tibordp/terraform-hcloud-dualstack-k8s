network:
    version: 2
    tunnels:
      wg0:
        mode: wireguard
        addresses:
%{ for prefix in addresses ~}            
          - "${prefix}"
%{ endfor ~}        
        routes:
%{ for peer in peers ~}
%{ for route in peer.routes ~}
          - to: "${route}"
            scope: link                 
%{ endfor ~}
%{ endfor ~}
        peers:
%{ for peer in peers ~}
          - keys:
              public: "${peer.public_key}"
            allowed-ips:
%{ for prefix in peer.allowed_ips ~}            
              - "${prefix}"
%{ endfor ~}
            endpoint: "${peer.endpoint}:51820"
%{ endfor ~}
        port: 51820
        keys:
          private: "__PRIVATE_KEY__"
