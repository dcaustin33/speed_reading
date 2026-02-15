import Foundation

/// Detects DRM protection in EPUB files by analyzing META-INF/encryption.xml.
/// Per spec: Check for Adobe ADEPT encryption, W3C XML encryption URIs,
/// and EncryptedData elements (excluding font obfuscation).
enum DRMDetector {
    // MARK: - Public Methods

    /// Check if the encryption XML indicates DRM protection
    /// - Parameter encryptionXML: Contents of META-INF/encryption.xml, or nil if not present
    /// - Returns: true if DRM is detected, false otherwise
    static func hasDRM(encryptionXML: String?) -> Bool {
        guard let xml = encryptionXML, !xml.isEmpty else {
            // No encryption.xml means no DRM
            return false
        }

        // Must have EncryptedData elements to be encrypted at all
        guard xml.contains("EncryptedData") else {
            return false
        }

        // Check for DRM-related encryption algorithms
        // Font obfuscation is NOT DRM - it's allowed

        // Adobe ADEPT DRM
        if xml.contains("http://ns.adobe.com/adept") {
            return true
        }

        // Other known DRM schemes
        if xml.contains("http://www.marlin-drm.com") ||
           xml.contains("http://www.fairplay.com") {
            return true
        }

        // If we have EncryptedData but it's only font obfuscation, that's OK
        // Check if ALL encryption uses font obfuscation algorithms
        let fontObfuscationAlgorithms = [
            "http://www.idpf.org/2008/embedding",  // IDPF font obfuscation
            "http://ns.adobe.com/pdf/enc#RC"        // Adobe font obfuscation
        ]

        // Find all EncryptionMethod Algorithm values
        // If any don't match font obfuscation, it's DRM
        let algorithmPattern = "Algorithm=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: algorithmPattern, options: []) else {
            return false
        }

        let matches = regex.matches(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml))
        for match in matches {
            if let algorithmRange = Range(match.range(at: 1), in: xml) {
                let algorithm = String(xml[algorithmRange])
                if !fontObfuscationAlgorithms.contains(algorithm) {
                    // Unknown or DRM algorithm found
                    return true
                }
            }
        }

        return false
    }
}
