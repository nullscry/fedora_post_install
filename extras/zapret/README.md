# zapret (optional)

Config for [zapret](https://github.com/bol-van/zapret) `nfqws`, used to get
around SNI-based DPI blocking of Discord (tested on a Turkish ISP). Only
installed when you run `sudo WITH_ZAPRET=1 ./install.sh`.

- `config` — nftables backend, nfqws on TCP 443 / UDP 443 + Discord voice
  (UDP 50000-65535 with the `discord` L7 filter), hostlist mode.
- `zapret-hosts-user.txt` — the hostlist: Discord domains only, so other
  traffic is untouched.

The desync strategy depends on your ISP. If it stops working (or on a new ISP),
run `sudo /opt/zapret/blockcheck.sh`, put the strategy it finds into
`NFQWS_OPT` in `/opt/zapret/config`, then `sudo systemctl restart zapret`.
