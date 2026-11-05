import AVKit
import SwiftUI

/// Images: pinch and double-tap to zoom, pan when zoomed.
struct ImageViewer: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                ZoomableImage(image: image)
                    .ignoresSafeArea(edges: .bottom)
                    .background(Color(.systemBackground))
            } else if failed {
                QuickLookView(url: url)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            let url = url
            let loaded = await Task.detached { UIImage(contentsOfFile: url.path)?.preparingForDisplay() }.value
            if let loaded { image = loaded } else { failed = true }
        }
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 8
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        iv.accessibilityIgnoresInvertColors = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            iv.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            iv.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            iv.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            iv.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
        ])
        context.coordinator.imageView = iv
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        @objc func doubleTapped(_ g: UITapGestureRecognizer) {
            guard let scroll = g.view as? UIScrollView else { return }
            if scroll.zoomScale > 1 {
                scroll.setZoomScale(1, animated: true)
            } else {
                let p = g.location(in: imageView)
                let size = CGSize(width: scroll.bounds.width / 3, height: scroll.bounds.height / 3)
                scroll.zoom(to: CGRect(origin: CGPoint(x: p.x - size.width / 2, y: p.y - size.height / 2), size: size), animated: true)
            }
        }
    }
}

/// Video and audio in the system player.
struct MediaPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea(edges: .bottom)
            .background(Color.black)
            .onAppear {
                try? AVAudioSession.sharedInstance().setCategory(.playback)
                let p = AVPlayer(url: url)
                player = p
                p.play()
            }
            .onDisappear { player?.pause() }
    }
}
