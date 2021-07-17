# How to verify Medito APK before installing to your devices

## Using keytool

```
keytool -printcert -jarfile medito.apk
```
The output certificate fingerprints should match:
```
// TODO: add Medito certificate fingerprints
```

## Using apksigner

```
apksigner verify --print-certs medito.apk
```

The output certificate fingerprints should match:
```
// TODO: add Medito certificate fingerprints
```