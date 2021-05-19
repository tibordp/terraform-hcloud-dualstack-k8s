{
  "cniVersion": "0.3.1",
  "name": "tibornet",
  "plugins": [
    {
      "type": "ptp",
      "ipMasq": false,
      "ipam": {
        "type": "host-local",
        "dataDir": "/run/cni-ipam-state",
        "routes": [
          {
            "dst": "::/0"
          },
          {
            "dst": "0.0.0.0/0"
          }          
        ],
        "ranges": [
          [
            {
              "subnet": "${pod_subnet_v6}"
            }
          ],
          [          
            {
              "subnet": "${pod_subnet_v4}",
              "rangeStart": "${cidrhost(pod_subnet_v4, 2)}"
            }
          ]
        ]
      },
      "mtu": 1500
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}