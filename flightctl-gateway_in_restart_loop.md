FlightCtl 1.2.0 upgrade leaves flightctl-gateway in restart loop.

The service references:

registry.redhat.io/rhel10/nginx-126:10.2-1779710424

Podman fails to pull the image with:

Source image rejected:
missing dev.sigstore.cosign/bundle annotation

Workaround:
1. podman pull registry.redhat.io/rhel10/nginx-126:10.2
2. podman tag registry.redhat.io/rhel10/nginx-126:10.2 \
              registry.redhat.io/rhel10/nginx-126:10.2-1779710424
3. systemctl restart flightctl-gateway

After tagging, flightctl-gateway starts successfully.
