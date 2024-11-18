# Run Standalone Gateway

## Prerequisites

> **Note:** This gateway can only be run on Linux-based operating systems.

### Install Spheron CLI

Run the following command to install the Spheron CLI:

```bash
wget -O install.sh https://sphnctl.sh
chmod +x install.sh
./install.sh
```

### Create Wallet

Run the following command to create a wallet:

```bash
sphnctl wallet create --name wallet --key-secret testPassword
```

### Create Gateway Config

```json
{
  "name": "spheron-gateway-1",
  "region": "us-east",
  "hostname": "gateway.example.com"
}
```

### Register Gateway

```bash
sphnctl provider add --config gateway-config.json
```

### Start Gateway

```bash
chmod +x gateway.sh
./gateway.sh
```
