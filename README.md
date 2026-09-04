# d3siboi-rtorrent

rtorrent + ruTorrent, running on [hotio](https://github.com/hotio)'s `alpinevpn` base image (WireGuard, Proton/PIA NAT-PMP port forwarding), with rtorrent and libtorrent compiled from source rather than pulled from a package repo, plus nginx, PHP-FPM, and the ruTorrent web UI with the filemanager and geoip2 plugins built in.

## What this actually is

This is a from-scratch Dockerfile — it does not extend or copy any single existing image. It builds on `ghcr.io/hotio/base:alpinevpn` for the VPN/WireGuard/firewall layer, and follows the general integration approach pioneered by [crazymax/docker-rtorrent-rutorrent](https://github.com/crazy-max/docker-rtorrent-rutorrent) (compile rtorrent/libtorrent/mktorrent from source, layer ruTorrent's web UI on top) — but every script, service definition, and config file in this repo was written independently for this project, adapted to hotio's own service model (s6-rc, its user/permission conventions, its VPN/firewall automation) rather than copied from either source.

## Credits

**[hotio](https://github.com/hotio)** — the `alpinevpn` base image this is built on. WireGuard setup, nftables firewall, Proton/PIA port-forwarding automation, and the overall s6-rc service model this project's own services follow the pattern of, all theirs. Licensed GPLv3.

**[CrazyMax](https://github.com/crazy-max)**, via [docker-rtorrent-rutorrent](https://github.com/crazy-max/docker-rtorrent-rutorrent) — the reference project this build's overall approach is modeled on (which pieces to compile from source, which build flags to use, how to wire ruTorrent to rtorrent). The `geoip2-rutorrent/` plugin is his actual code, fetched directly from his repo at build time (not reimplemented) — deliberately unpinned since it isn't independently versioned, same as the GeoLite2 data below. Licensed MIT.

**[rakshasa](https://github.com/rakshasa)** — [rtorrent](https://github.com/rakshasa/rtorrent) and [libtorrent](https://github.com/rakshasa/libtorrent), compiled from source in this image. Licensed GPLv2.

**[Novik](https://github.com/Novik)** — [ruTorrent](https://github.com/Novik/ruTorrent), the web UI, included in full. Licensed GPLv3.

**[nelu](https://github.com/nelu)** — [rutorrent-filemanager](https://github.com/nelu/rutorrent-filemanager), the file management plugin. Its `LICENSE` file doesn't contain standard license terms (one line, not a recognized license text) — included here as-is; check the upstream repo directly if you need clarity on terms beyond what's there.

**[Emil Renner Berthing](https://github.com/pobrn)** — [mktorrent](https://github.com/pobrn/mktorrent), compiled from source, used by ruTorrent's torrent-creation feature. Licensed GPLv2 (with an explicit OpenSSL linking exception).

**[tomcdj71](https://github.com/tomcdj71)** — [dumptorrent](https://github.com/tomcdj71/dumptorrent), compiled from source, used by ruTorrent's dump plugin. No license file found upstream at the pinned version — no explicit terms available to cite.

**[c-ares](https://github.com/c-ares/c-ares)** and **[curl](https://curl.se/)** — compiled from source as dependencies. MIT and the curl license respectively (both permissive).

**[MaxMind](https://www.maxmind.com/)** — this product includes GeoLite2 data created by MaxMind, available from https://www.maxmind.com, fetched at build time from [crazy-max/geoip-updater](https://github.com/crazy-max/geoip-updater)'s mirror. Required attribution per MaxMind's GeoLite2 EULA.

**[RARLAB](https://www.rarlab.com/)** — `rar` (archive creation) is fetched directly from RARLAB's own servers *at build time*, on whichever machine runs `docker build` — it is never vendored, redistributed, or included in this repo or in any image layer this repo's own CI publishes to a persistent registry beyond the ephemeral build. It's proprietary shareware, not open source; see rarlab.com/license.htm. `unrar` (extraction) comes from hotio's base image, built from RARLAB's separately-licensed free unrar source.

Alpine Linux packages (nginx, php84, and others pulled via `apk add`) are each under their own respective licenses, standard for any Alpine-based image.

## Licensing

This repository's own original content — the Dockerfile, the `root/` service overlay, and the app configs under `root/app/` and `root/var/www/rutorrent/` that aren't vendored from elsewhere — is licensed under **GPLv3** (see `LICENSE`). 

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

THIS PROJECT IS PROVIDED WITH NO WARRANTY OR GUARANTEE OF ANY KIND. USE IT ENTIRELY AT YOUR OWN RISK — I TAKE NO RESPONSIBILITY FOR ANY DAMAGE, DATA LOSS, LEGAL ISSUES, OR OTHER CONSEQUENCES RESULTING FROM ITS USE.