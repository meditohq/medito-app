import SwiftUI
import UIKit

/// A pack cover, downloaded once and kept in Caches so the card shows it
/// instantly (and offline) afterwards. Covers rarely change, and the phone
/// already sends a small resized JPEG URL.
struct CoverImage: View {
    let url: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.white.opacity(0.1)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .task(id: url) { image = await CoverCache.image(for: url) }
    }
}

private enum CoverCache {
    static func image(for urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return nil }
        let file = directory.appendingPathComponent(
            String(urlString.hashValueStable, radix: 16) + ".jpg"
        )
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            return image
        }
        guard
            let (data, response) = try? await URLSession.shared.data(from: url),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let image = UIImage(data: data)
        else { return nil }
        try? data.write(to: file, options: .atomic)
        return image
    }

    private static let directory: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
}

private extension String {
    /// `hashValue` is randomised per launch; this is stable across launches
    /// (FNV-1a), which a file-name cache key needs.
    var hashValueStable: UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
