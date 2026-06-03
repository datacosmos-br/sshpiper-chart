# [sshpiper](https://github.com/datacosmos-br/sshpiper) (datacosmos fork)

The missing reverse proxy for ssh scp.

This is the **datacosmos** fork of the chart. It deploys
`ghcr.io/datacosmos-br/sshpiperd` and adds declarative configuration for
multiple/chained plugins, certificate-based routing (`trusted_user_ca_keys`),
and HashiCorp Vault.

## Usage

### Install chart with helm

```
helm install my-sshpiper ./charts/sshpiper
```

### Image

Defaults to `ghcr.io/datacosmos-br/sshpiperd` at the chart `appVersion`. The
chart automatically selects the **full** image (all plugins) when you enable any
plugin other than `kubernetes`/`workingdir`, or Vault, or failtoban. Override
with `image.repository` / `image.tag`, or force full with `image.full: true`.

### Declarative plugins (chaining)

Configure the plugin pipeline under `sshpiper.plugins`. Plugins run in order and
2+ enabled plugins are chained (separated by `--`):

```yaml
sshpiper:
  plugins:
    - name: yaml
      enabled: true
      config: |
        version: "1.0"
        pipes:
        - from:
            - username: "alice"
              trusted_user_ca_keys: /etc/sshpiper/ca/team-a.pub
          to:
            host: host-a.internal:22
            username: "world"
            ignore_hostkey: true
            private_key_vault: secret/data/ssh/upstream-key
    - name: kubernetes      # fallback for anything yaml does not match
      enabled: true
```

### CA-based routing (user/CA/host)

Mount CA public keys and reference them from a yaml pipe's
`trusted_user_ca_keys`. Each entry is mounted at `/etc/sshpiper/ca/<name>`:

```yaml
sshpiper:
  trustedUserCAKeys:
    team-a.pub: "ssh-ed25519 AAAA... ca-team-a"
    team-b.pub: "ssh-ed25519 AAAA... ca-team-b"
```

Two yaml pipes with the same `username` but different `trusted_user_ca_keys` (and
different `to.host`) route to different upstreams purely by which CA signed the
client certificate.

### Vault

```yaml
sshpiper:
  vault:
    enabled: true
    addr: "https://vault.internal:8200"
    cacheDuration: "5m"
    existingSecret: my-vault-token   # or set `token:` to render one (avoid in prod)
    existingSecretKey: token
```

Sets `VAULT_ADDR` / `VAULT_TOKEN` / `VAULT_CACHE_DURATION` so the yaml plugin's
`*_vault` fields (`trusted_user_ca_keys_vault`, `authorized_keys_vault`,
`private_key_vault`) resolve from Vault.


### Create Password Pipe


```
apiVersion: sshpiper.com/v1beta1
kind: Pipe
metadata:
  name: pipe-password
spec:
  from:
  - username: "password_simple"
  to:
    host: host-password:2222
    username: "user"
    ignore_hostkey: true
```

`ssh password_simple@piper_ip` will pipe to `user@host-password`


### Create Public Key Pipe

`ssh piper_ip -i <key in authorized_keys_data> ` will pipe to `user@host-publickey` and login with secret `host-publickey-key`


```
apiVersion: v1
data:
  ssh-privatekey: |
    <base64 encoded private key>
kind: Secret
metadata:
  name: host-publickey-key
type: kubernetes.io/ssh-auth
---
apiVersion: sshpiper.com/v1beta1
kind: Pipe
metadata:
  name: pipe-publickey
spec:
  from:
  - username: ".*" # catch all    
    username_regex_match: true
    authorized_keys_data: "base64_authorized_keys_data"
  to:
    host: host-publickey:2222
    username: "user"
    private_key_secret:
      name: host-publickey-key
    ignore_hostkey: true
```

more info: kubernetes plugin for sshpiper <https://github.com/tg123/sshpiper/tree/master/plugin/kubernetes>
