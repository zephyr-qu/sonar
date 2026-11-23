//! Resolving the client address when a reverse proxy may sit in front.

use crate::util::ip::normalize;
use ipnet::IpNet;
use std::net::IpAddr;
use std::sync::LazyLock;

/// CIDR ranges (or single addresses) of the reverse proxies whose
/// `X-Forwarded-For` may be believed, comma separated:
/// `TRUSTED_PROXIES=127.0.0.1/32,::1/128`.
///
/// Empty by default: anyone who can reach the port directly can forge the
/// header, so it is ignored unless a deployment explicitly opts in. Without it,
/// every client behind a proxy lands in the proxy's own group and shares its
/// connection and request budget.
static TRUSTED_PROXIES: LazyLock<Vec<IpNet>> = LazyLock::new(|| {
    std::env::var("TRUSTED_PROXIES")
        .unwrap_or_default()
        .split(',')
        .map(str::trim)
        .filter(|entry| !entry.is_empty())
        .filter_map(|entry| match parse_net(entry) {
            Some(net) => Some(net),
            None => {
                tracing::warn!("Ignoring invalid TRUSTED_PROXIES entry {entry:?}");
                None
            }
        })
        .collect()
});

pub(crate) fn trusted_proxies() -> &'static [IpNet] {
    TRUSTED_PROXIES.as_slice()
}

/// The address a client is grouped on.
///
/// Without a trusted proxy in front, the socket peer is the client. Behind one,
/// `X-Forwarded-For` lists the hops starting at the client, each proxy
/// appending the address it saw, so the right-most entry that is not itself a
/// trusted proxy is the closest hop that can be vouched for. Everything left of
/// it is whatever the client sent and may be forged.
pub(crate) fn client_ip(peer: IpAddr, forwarded_for: Option<&str>, trusted: &[IpNet]) -> IpAddr {
    let peer = normalize(peer);
    if !is_trusted(peer, trusted) {
        return peer;
    }
    let Some(header) = forwarded_for else {
        return peer;
    };

    for hop in header.split(',').rev().map(str::trim) {
        let Some(ip) = parse_hop(hop) else {
            continue;
        };
        let ip = normalize(ip);
        if !is_trusted(ip, trusted) {
            return ip;
        }
    }

    // Every hop is a trusted proxy; the socket peer is one too.
    peer
}

fn is_trusted(ip: IpAddr, trusted: &[IpNet]) -> bool {
    trusted.iter().any(|net| match (net, ip) {
        (IpNet::V4(net), IpAddr::V4(ip)) => net.contains(&ip),
        (IpNet::V6(net), IpAddr::V6(ip)) => net.contains(&ip),
        _ => false,
    })
}

/// Some proxies append the port (`1.2.3.4:5678`).
fn parse_hop(value: &str) -> Option<IpAddr> {
    value.parse::<IpAddr>().ok().or_else(|| {
        value
            .parse::<std::net::SocketAddr>()
            .ok()
            .map(|addr| addr.ip())
    })
}

fn parse_net(entry: &str) -> Option<IpNet> {
    if let Ok(net) = entry.parse::<IpNet>() {
        return Some(net);
    }
    // A bare address means a single host.
    let ip = entry.parse::<IpAddr>().ok()?;
    IpNet::new(ip, if ip.is_ipv4() { 32 } else { 128 }).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn nets(entries: &[&str]) -> Vec<IpNet> {
        entries
            .iter()
            .map(|entry| parse_net(entry).unwrap())
            .collect()
    }

    fn ip(value: &str) -> IpAddr {
        value.parse().unwrap()
    }

    #[test]
    fn ignores_the_header_from_an_untrusted_peer() {
        let trusted = nets(&["10.0.0.0/8"]);
        assert_eq!(
            client_ip(ip("203.0.113.7"), Some("1.2.3.4"), &trusted),
            ip("203.0.113.7")
        );
    }

    #[test]
    fn takes_the_client_from_a_single_proxy() {
        let trusted = nets(&["10.0.0.0/8"]);
        assert_eq!(
            client_ip(ip("10.0.0.2"), Some("1.2.3.4"), &trusted),
            ip("1.2.3.4")
        );
    }

    #[test]
    fn walks_past_trusted_hops() {
        let trusted = nets(&["10.0.0.0/8"]);
        // client -> 10.0.0.2 -> 10.0.0.3
        assert_eq!(
            client_ip(ip("10.0.0.3"), Some("1.2.3.4, 10.0.0.2"), &trusted),
            ip("1.2.3.4")
        );
    }

    #[test]
    fn a_forged_left_entry_does_not_win() {
        let trusted = nets(&["10.0.0.0/8"]);
        // The client sent "6.6.6.6"; the proxy appended the address it saw.
        assert_eq!(
            client_ip(ip("10.0.0.2"), Some("6.6.6.6, 1.2.3.4"), &trusted),
            ip("1.2.3.4")
        );
    }

    #[test]
    fn falls_back_to_the_peer_without_a_usable_header() {
        let trusted = nets(&["10.0.0.0/8"]);
        assert_eq!(client_ip(ip("10.0.0.2"), None, &trusted), ip("10.0.0.2"));
        assert_eq!(
            client_ip(ip("10.0.0.2"), Some("10.0.0.9, nonsense"), &trusted),
            ip("10.0.0.2")
        );
    }

    #[test]
    fn accepts_a_forwarded_hop_with_a_port() {
        let trusted = nets(&["10.0.0.0/8"]);
        assert_eq!(
            client_ip(ip("10.0.0.2"), Some("1.2.3.4:5678"), &trusted),
            ip("1.2.3.4")
        );
    }

    #[test]
    fn normalizes_ipv4_mapped_hops() {
        let trusted = nets(&["10.0.0.0/8"]);
        // A dual-stack listener reports the proxy as ::ffff:10.0.0.2.
        assert_eq!(
            client_ip(ip("::ffff:10.0.0.2"), Some("1.2.3.4"), &trusted),
            ip("1.2.3.4")
        );
    }

    #[test]
    fn accepts_a_bare_address_as_a_single_host() {
        let trusted = nets(&["127.0.0.1", "::1"]);
        assert_eq!(
            client_ip(ip("127.0.0.1"), Some("1.2.3.4"), &trusted),
            ip("1.2.3.4")
        );
        assert_eq!(
            client_ip(ip("::1"), Some("1.2.3.4"), &trusted),
            ip("1.2.3.4")
        );
    }
}
