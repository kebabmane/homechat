# HomeChat LAN Discovery Protocol

HomeChat servers can be automatically discovered on the local network using mDNS (Multicast DNS) with DNS Service Discovery.

## Service Advertisement

HomeChat servers advertise themselves using:
- **Service Type**: `_homechat._tcp.local.`
- **Port**: The HTTP port the server is running on (3000 for development, 80 for production)
- **TXT Records**: Additional service information

### TXT Record Format

The service includes these TXT record fields:

| Field | Description | Example Values |
|-------|-------------|----------------|
| `version` | API version | `1.0` |
| `platform` | Server platform | `rails` |
| `features` | Supported features | `chat,api,webhooks` |
| `secure` | HTTPS support | `true`, `false` |

## Client Discovery Implementation

### macOS/iOS (Swift)
```swift
import Network

let browser = NWBrowser(for: .bonjour(type: "_homechat._tcp", domain: "local."), using: .tcp)
browser.browseResultsChangedHandler = { results, changes in
    for result in results {
        if case let .service(name: name, type: _, domain: _, interface: _) = result.endpoint {
            // Found HomeChat server: name
        }
    }
}
browser.start(queue: .main)
```

### Android (Java/Kotlin)
```kotlin
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo

val nsdManager = getSystemService(Context.NSD_SERVICE) as NsdManager

val discoveryListener = object : NsdManager.DiscoveryListener {
    override fun onServiceFound(service: NsdServiceInfo) {
        if (service.serviceType == "_homechat._tcp") {
            nsdManager.resolveService(service, resolveListener)
        }
    }
}

nsdManager.discoverServices("_homechat._tcp", NsdManager.PROTOCOL_DNS_SD, discoveryListener)
```

### Windows (.NET)
```csharp
using Makaretu.Dns;

var mdns = new MulticastService();
mdns.NetworkInterfaceDiscovered += (s, e) => mdns.SendQuery("_homechat._tcp.local", type: DnsType.PTR);
mdns.AnswerReceived += (s, e) => {
    var ptr = e.Message.Answers.OfType<PTRRecord>().FirstOrDefault();
    if (ptr?.DomainName.ToString().Contains("_homechat._tcp") == true) {
        // Found HomeChat server
    }
};
mdns.Start();
```

### Linux (Avahi/Python)
```python
import avahi
import dbus

def service_resolved(interface, protocol, name, stype, domain, host, aprotocol, address, port, txt, flags):
    if stype == '_homechat._tcp':
        print(f"Found HomeChat server: {name} at {address}:{port}")

bus = dbus.SystemBus()
server = dbus.Interface(bus.get_object(avahi.DBUS_NAME, avahi.DBUS_PATH_SERVER), avahi.DBUS_INTERFACE_SERVER)
sbrowser = dbus.Interface(bus.get_object(avahi.DBUS_NAME, server.ServiceBrowserNew(avahi.IF_UNSPEC, avahi.PROTO_UNSPEC, '_homechat._tcp', 'local', dbus.UInt32(0))), avahi.DBUS_INTERFACE_SERVICE_BROWSER)
```

## Server Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DISCOVERY_ENABLED` | `true` | Enable/disable LAN discovery |
| `DISCOVERY_SERVER_NAME` | `HomeChat on [hostname]` | Custom server name |
| `DISCOVERY_PORT` | `3000` (dev), `80` (prod) | Port to advertise |

### Example Configuration
```bash
# Disable discovery
DISCOVERY_ENABLED=false

# Custom server name
DISCOVERY_SERVER_NAME="My HomeChat Server"

# Custom port (if running on non-standard port)
DISCOVERY_PORT=8080
```

## Connection Flow

1. **Discovery**: Client scans for `_homechat._tcp.local.` services
2. **Resolution**: Client resolves service to get IP address and port
3. **Validation**: Client can check TXT records for compatibility
4. **Connection**: Client connects to `http://[ip]:[port]` (or `https://` if `secure=true`)

## Troubleshooting

### Common Issues

- **No services found**: Check firewall settings, ensure mDNS/Bonjour is enabled
- **Service not advertising**: Check server logs for discovery service errors
- **Network isolation**: Some networks block multicast traffic

### Testing Discovery

Use command-line tools to verify service advertisement:

```bash
# macOS/Linux
dns-sd -B _homechat._tcp local.

# Linux (avahi)
avahi-browse -t _homechat._tcp

# Windows
# Use third-party tools like Bonjour Browser
```