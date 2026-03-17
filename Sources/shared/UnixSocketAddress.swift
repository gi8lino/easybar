import Darwin

/// Builds a Unix domain socket address for the given path.
public func makeSockAddrUn(path: String) -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)

    let bytes = Array(path.utf8)
    let maxLen = MemoryLayout.size(ofValue: addr.sun_path)

    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: maxLen) { cptr in
            memset(cptr, 0, maxLen)

            for (index, byte) in bytes.prefix(maxLen - 1).enumerated() {
                cptr[index] = CChar(bitPattern: byte)
            }
        }
    }

    return addr
}
