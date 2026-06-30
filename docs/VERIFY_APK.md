# How to verify Medito APK before installing to your devices

## Using keytool

```
keytool -printcert -jarfile medito.apk
```
The output certificate fingerprints should match:
```
Signer #1:

Signature:

Owner: OU=Medito Foundation
Issuer: OU=Medito Foundation
Serial number: 3d33b57b
Valid from: Mon May 24 20:00:02 CEST 2021 until: Fri May 18 20:00:02 CEST 2046
Certificate fingerprints:
	 SHA1: 4F:55:86:C3:E5:97:6B:8C:4B:FB:C4:3C:5D:64:EF:F3:62:C5:13:91
	 SHA256: 49:CD:5F:E2:57:DA:4B:DC:AB:20:0E:17:23:F0:4F:18:BB:CD:E2:D3:49:DE:14:50:44:76:0E:CC:79:0A:63:D3
Signature algorithm name: SHA256withRSA
Subject Public Key Algorithm: 2048-bit RSA key
Version: 3

Extensions: 

#1: ObjectId: 2.5.29.14 Criticality=false
SubjectKeyIdentifier [
KeyIdentifier [
0000: A9 A3 8F 23 30 75 E3 14   6F FC 9B B3 35 6D 4E F2  ...#0u..o...5mN.
0010: 7F F2 DB 9F                                        ....
]
]

```

## Using apksigner

```
apksigner verify --print-certs medito.apk
```

The output certificate fingerprints should match:
```
// TODO: add Medito certificate fingerprints
```
