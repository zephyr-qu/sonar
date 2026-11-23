use std::net::IpAddr;

pub(crate) fn get_ip_group(ip: IpAddr) -> String {
    match normalize(ip) {
        IpAddr::V4(ip) => {
            // IPv4: Each IP address is already a group.
            ip.to_string()
        }
        IpAddr::V6(ip) => {
            // IPv6: We treat /64 as a group.
            let segments = ip.segments();
            format!(
                "{:x}:{:x}:{:x}:{:x}",
                segments[0], segments[1], segments[2], segments[3]
            )
        }
    }
}

/// An IPv4 client on a dual-stack socket arrives as `::ffff:a.b.c.d`; treat it
/// as the IPv4 address it stands for, so every IPv4 client does not collapse
/// into the `0:0:0:0` group.
pub(crate) fn normalize(ip: IpAddr) -> IpAddr {
    match ip {
        IpAddr::V6(ip) => ip.to_ipv4_mapped().map_or(IpAddr::V6(ip), IpAddr::V4),
        IpAddr::V4(_) => ip,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::str::FromStr;

    #[test]
    fn test_get_ip_group() {
        assert_eq!(
            get_ip_group(IpAddr::from_str("1.2.3.4").unwrap()),
            "1.2.3.4"
        );
        assert_eq!(
            get_ip_group(IpAddr::from_str("1:2:3:4:5:6:7:8").unwrap()),
            "1:2:3:4"
        );
        assert_eq!(
            get_ip_group(IpAddr::from_str("a:b:c:d:e:f:0:1").unwrap()),
            "a:b:c:d"
        );
    }

    #[test]
    fn test_ipv4_mapped_addresses_group_as_ipv4() {
        assert_eq!(
            get_ip_group(IpAddr::from_str("::ffff:1.2.3.4").unwrap()),
            "1.2.3.4"
        );
    }
}
