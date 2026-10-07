import Cocoa
import AVFoundation
import SceneKit

enum GiftLanguage {
    case zh, en

    static var systemDefault: GiftLanguage {
        let first = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return first.hasPrefix("zh") ? .zh : .en
    }

    mutating func toggle() { self = self == .zh ? .en : .zh }
}

struct GiftCopy {
    let language: GiftLanguage

    var giftTitle: String { language == .zh ? "一份给你的礼物" : "A gift for you" }
    var giftBody: String { language == .zh ? "听说你最近缺一个真正实用的东西。" : "We heard you could use something truly practical." }
    var open: String { language == .zh ? "拆开看看" : "Open it" }
    var won: String { language == .zh ? "点一下，拿起苍蝇拍。" : "Click the swatter to pick it up." }
    var swatter: String { language == .zh ? "苍蝇拍" : "A fly swatter" }
    var arm: String { language == .zh ? "点击拿起 · 可能马上用得上" : "Pick it up · You may need it soon" }
    var tray: String { language == .zh ? "拿起苍蝇拍" : "Pick up the swatter" }
    var countdownPrefix: String { language == .zh ? "抓住它" : "CATCH IT" }
    var successTitle: String { language == .zh ? "你拍死的，不只是一段动画。" : "You killed more than an animation." }
    var failureTitle: String { language == .zh ? "它用真正的逃逸回路从你手里活下来了。" : "It escaped using a real escape circuit." }
    var science: String {
        language == .zh
            ? "这只果蝇运行着 FlyWire v783 的完整连接组：139,255 个神经元、54,492,922 个突触，以 1 kHz 在 Apple GPU 上模拟。鼠标逼近时会刺激 LC4/LPLC2；Giant Fiber 放电后，它才会起飞。"
            : "This fly ran the complete FlyWire v783 connectome: 139,255 neurons and 54,492,922 synapses simulated at 1 kHz on the Apple GPU. Your approaching cursor stimulated LC4/LPLC2; it took off only when the Giant Fiber fired."
    }
    var boundary: String {
        language == .zh
            ? "连接数据来自真实果蝇；神经生理参数、屏幕感觉转换和身体动作仍是计算模型。"
            : "The wiring data comes from a real fly. Neural physiology, screen sensing, and body motion are still computational models."
    }
    var close: String { language == .zh ? "关闭" : "Close" }
    func successStats(seconds: TimeInterval, swings: Int) -> String {
        language == .zh
            ? String(format: "用时 %.1f 秒 · 挥拍 %d 次", seconds, swings)
            : String(format: "%.1f seconds · %d swings", seconds, swings)
    }
    func failureStats(swings: Int) -> String {
        language == .zh
            ? "它存活了 60 秒 · 挥拍 \(swings) 次"
            : "It survived for 60 seconds · \(swings) swings"
    }
}

enum GamePhase: Equatable {
    case giftClosed, giftOpened, waitingForFly, challenge, killed, escaped, cancelled, reveal, terminated
}

enum ChallengeResult: Equatable {
    case killed(elapsed: TimeInterval, swings: Int)
    case escaped(swings: Int)
    case cancelled
}

struct DoublePressDetector {
    let maximumInterval: TimeInterval
    private(set) var previousPress: TimeInterval?

    init(maximumInterval: TimeInterval = 0.45) { self.maximumInterval = maximumInterval }

    mutating func press(now: TimeInterval) -> Bool {
        defer { previousPress = now }
        guard let previousPress else { return false }
        return now - previousPress <= maximumInterval
    }
}

func flyHitTest(cursor: CGPoint, center: CGPoint, visualRadius: CGFloat,
                forgiveness: CGFloat = 8) -> Bool {
    hypot(cursor.x - center.x, cursor.y - center.y) <= visualRadius + forgiveness
}

struct SwatterHeadSample {
    let center: CGPoint
    let size: CGSize
    let angle: CGFloat
    let swing: CGFloat

    var equivalentRadius: CGFloat {
        sqrt(size.width * size.height / .pi)
    }
}

func swatterHeadHitTest(flyCenter: CGPoint, flyRadius: CGFloat,
                        head: SwatterHeadSample, forgiveness: CGFloat = 9) -> Bool {
    let dx = flyCenter.x - head.center.x
    let dy = flyCenter.y - head.center.y
    let c = cos(-head.angle), s = sin(-head.angle)
    let localX = dx * c - dy * s
    let localY = dx * s + dy * c
    let qx = max(abs(localX) - head.size.width * 0.5, 0)
    let qy = max(abs(localY) - head.size.height * 0.5, 0)
    return hypot(qx, qy) <= flyRadius + forgiveness
}

func sweptSwatterHeadHitTest(flyCenter: CGPoint, flyRadius: CGFloat,
                             from: SwatterHeadSample, to: SwatterHeadSample) -> Bool {
    let travel = hypot(to.center.x - from.center.x, to.center.y - from.center.y)
    let angleDelta = atan2(sin(to.angle - from.angle), cos(to.angle - from.angle))
    let steps = max(1, min(18, Int(ceil(max(travel / 7, abs(angleDelta) / 0.08)))))
    for index in 0...steps {
        let t = CGFloat(index) / CGFloat(steps)
        let sample = SwatterHeadSample(
            center: CGPoint(x: from.center.x + (to.center.x - from.center.x) * t,
                            y: from.center.y + (to.center.y - from.center.y) * t),
            size: CGSize(width: from.size.width + (to.size.width - from.size.width) * t,
                         height: from.size.height + (to.size.height - from.size.height) * t),
            angle: from.angle + angleDelta * t,
            swing: from.swing + (to.swing - from.swing) * t)
        if swatterHeadHitTest(flyCenter: flyCenter, flyRadius: flyRadius, head: sample) {
            return true
        }
    }
    return false
}

final class ChallengeController {
    private(set) var phase: GamePhase = .giftClosed
    private(set) var armed = false
    private(set) var swings = 0
    private(set) var spawnAt: TimeInterval?
    private(set) var startedAt: TimeInterval?
    let duration: TimeInterval

    init(duration: TimeInterval = 60) { self.duration = duration }

    func openGift(now: TimeInterval, delay: TimeInterval) {
        guard phase == .giftClosed else { return }
        phase = .giftOpened
        spawnAt = now + delay
        phase = .waitingForFly
    }

    func arm() { armed = true }
    func recordSwing() { if phase == .challenge && armed { swings += 1 } }

    func shouldSpawn(now: TimeInterval) -> Bool {
        phase == .waitingForFly && now >= (spawnAt ?? .greatestFiniteMagnitude)
    }

    func spawn(now: TimeInterval) {
        guard phase == .waitingForFly else { return }
        startedAt = now
        phase = .challenge
    }

    func remaining(now: TimeInterval) -> TimeInterval {
        guard let startedAt else { return duration }
        return max(0, duration - (now - startedAt))
    }

    func kill(now: TimeInterval) -> ChallengeResult? {
        guard phase == .challenge, armed, let startedAt else { return nil }
        phase = .killed
        return .killed(elapsed: max(0, now - startedAt), swings: swings)
    }

    func tick(now: TimeInterval) -> ChallengeResult? {
        guard phase == .challenge, remaining(now: now) <= 0 else { return nil }
        phase = .escaped
        return .escaped(swings: swings)
    }

    func cancel() -> ChallengeResult? {
        guard phase != .terminated, phase != .cancelled else { return nil }
        phase = .cancelled
        return .cancelled
    }

    func reveal() { if phase == .killed || phase == .escaped { phase = .reveal } }
    func terminate() { phase = .terminated }
}

private let giftCream = NSColor(calibratedRed: 0.91, green: 0.81, blue: 0.62, alpha: 1)
private let giftRed = NSColor(calibratedRed: 0.48, green: 0.07, blue: 0.045, alpha: 1)
private let giftInk = NSColor(calibratedRed: 0.14, green: 0.08, blue: 0.05, alpha: 1)

final class RetroPaperView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        giftCream.setFill(); bounds.fill()
        giftRed.withAlphaComponent(0.10).setFill()
        for y in stride(from: 5, to: Int(bounds.height), by: 9) {
            for x in stride(from: (y / 9) % 2 == 0 ? 5 : 9, to: Int(bounds.width), by: 12) {
                NSBezierPath(ovalIn: NSRect(x: CGFloat(x), y: CGFloat(y), width: 1.2, height: 1.2)).fill()
            }
        }
        giftRed.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 9, dy: 9))
        border.lineWidth = 3; border.stroke()
    }
}

final class SwatterGraphicView: NSView {
    /// Everything below draws in this fixed space. The view's *frame* is what
    /// grows during the power-up, so AppKit scales the whole swatter — head,
    /// handle and perforations — by the same factor the hit geometry uses.
    static let baseSize = NSSize(width: 105, height: 135)
    var swing: CGFloat = 0 { didSet { needsDisplay = true } }
    var boosted = false { didSet { needsDisplay = true } }
    var onClick: (() -> Void)? { didSet { window?.invalidateCursorRects(for: self) } }
    private lazy var swatterImage: NSImage? = {
        guard let url = findResource("swatter-red-v3.png")
                ?? findResource("assets/swatter-red-v3.png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bounds = NSRect(origin: .zero, size: Self.baseSize)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if bounds.size != Self.baseSize { bounds = NSRect(origin: .zero, size: Self.baseSize) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX, yBy: 10)
        transform.rotate(byDegrees: -10 - swing * 34)
        transform.translateX(by: -bounds.midX, yBy: -10)
        transform.concat()

        if let image = swatterImage {
            let inset = bounds.insetBy(dx: max(2, bounds.width * 0.06),
                                       dy: max(2, bounds.height * 0.025))
            image.draw(in: inset, from: .zero, operation: .sourceOver, fraction: 1,
                       respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            if boosted {
                // Tint only the swatter's own pixels so the buff reads without
                // any extra chrome or a halo that could drift from the head.
                NSGraphicsContext.current?.saveGraphicsState()
                NSGraphicsContext.current?.compositingOperation = .sourceAtop
                NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.28, alpha: 0.32).setFill()
                NSBezierPath(rect: inset).fill()
                NSGraphicsContext.current?.restoreGraphicsState()
            }
            NSGraphicsContext.current?.restoreGraphicsState()
            return
        }

        let plastic = NSColor(calibratedRed: 0.78, green: 0.035, blue: 0.025, alpha: 1)
        let plasticDark = NSColor(calibratedRed: 0.39, green: 0.012, blue: 0.01, alpha: 1)
        let plasticLight = NSColor(calibratedRed: 1.0, green: 0.18, blue: 0.12, alpha: 1)
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.36)
        shadow.shadowBlurRadius = 4; shadow.shadowOffset = NSSize(width: 1.5, height: -2)
        shadow.set()

        let grip = NSBezierPath(roundedRect: NSRect(x: bounds.midX - 8.5, y: 4, width: 17,
                                                     height: bounds.height * 0.43),
                                xRadius: 8, yRadius: 8)
        NSGradient(starting: plasticLight, ending: plasticDark)?.draw(in: grip, angle: 0)
        plasticDark.setStroke(); grip.lineWidth = 1.4; grip.stroke()
        let handle = NSBezierPath(roundedRect: NSRect(x: bounds.midX - 3.8, y: bounds.height * 0.34,
                                                       width: 7.6, height: bounds.height * 0.28),
                                  xRadius: 3.8, yRadius: 3.8)
        plastic.setFill(); handle.fill(); plasticLight.withAlphaComponent(0.65).setStroke()
        handle.lineWidth = 1; handle.stroke()

        let hole = NSBezierPath(roundedRect: NSRect(x: bounds.midX - 3.2, y: 8, width: 6.4, height: 13),
                                xRadius: 3, yRadius: 3)
        NSColor.black.withAlphaComponent(0.42).setFill(); hole.fill()

        let headRect = NSRect(x: bounds.midX - 34, y: bounds.height * 0.52, width: 68, height: 55)
        let head = NSBezierPath(roundedRect: headRect, xRadius: 7, yRadius: 7)
        NSGradient(starting: plasticLight, ending: plasticDark)?.draw(in: head, angle: -24)
        plasticDark.setStroke(); head.lineWidth = 2.2; head.stroke()

        // Dense square perforations and molded reinforcement ribs match the
        // ubiquitous inexpensive Chinese one-piece plastic swatter.
        let cell: CGFloat = 4.2
        for row in 0..<10 {
            for col in 0..<13 {
                let r = NSRect(x: headRect.minX + 5.3 + CGFloat(col) * cell,
                               y: headRect.minY + 5.0 + CGFloat(row) * cell,
                               width: 2.6, height: 2.6)
                NSColor.black.withAlphaComponent(0.42).setFill()
                NSBezierPath(roundedRect: r, xRadius: 0.6, yRadius: 0.6).fill()
            }
        }
        plasticLight.withAlphaComponent(0.76).setStroke()
        for xEnd in [headRect.minX + 7, headRect.midX, headRect.maxX - 7] {
            let rib = NSBezierPath(); rib.move(to: NSPoint(x: bounds.midX, y: headRect.minY + 1))
            rib.line(to: NSPoint(x: xEnd, y: headRect.maxY - 5)); rib.lineWidth = 2; rib.stroke()
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) { onClick?() }
    override func resetCursorRects() {
        super.resetCursorRects()
        if onClick != nil { addCursorRect(bounds, cursor: .pointingHand) }
    }
}

final class GiftBox3DView: SCNView {
    var onOpen: (() -> Void)?
    private let giftRoot = SCNNode()
    private let modelRoot = SCNNode()
    private var wrappingNodes: [SCNNode] = []
    private var boxNodes: [SCNNode] = []
    private var opened = false

    override init(frame: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        buildScene()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildScene() {
        let scene = SCNScene(); self.scene = scene
        backgroundColor = .clear
        antialiasingMode = .multisampling4X
        allowsCameraControl = false

        let paper = SCNMaterial(); paper.lightingModel = .physicallyBased
        paper.diffuse.contents = NSColor(calibratedRed: 0.70, green: 0.035, blue: 0.035, alpha: 1)
        paper.roughness.contents = 0.48; paper.metalness.contents = 0.01
        let ribbon = SCNMaterial(); ribbon.lightingModel = .physicallyBased
        ribbon.diffuse.contents = NSColor(calibratedRed: 0.98, green: 0.64, blue: 0.09, alpha: 1)
        ribbon.roughness.contents = 0.19; ribbon.metalness.contents = 0.22

        if let url = findResource("GiftBox.obj") ?? findResource("assets/gift-box-cc0/GiftBox.obj"),
           let imported = try? SCNScene(url: url, options: [
               .checkConsistency: true,
               .convertToYUp: true,
               .createNormalsIfAbsent: true
           ]) {
            for child in imported.rootNode.childNodes { modelRoot.addChildNode(child.clone()) }
        } else {
            // The packaged CC0 mesh is the normal path; this keeps source-tree
            // developer runs understandable if Resources have not been copied.
            let fallback = SCNBox(width: 1.5, height: 1.35, length: 1.5, chamferRadius: 0.05)
            fallback.materials = [paper]
            let node = SCNNode(geometry: fallback); node.name = "GiftBox_fallback"
            modelRoot.addChildNode(node)
        }

        func prepare(_ node: SCNNode) {
            let lower = (node.name ?? "").lowercased()
            if let geometry = node.geometry {
                // SceneKit collapses the OBJ objects into material elements.
                // Re-split them so the bow and two ribbon meshes can unwrap
                // independently from the paper box during the reveal.
                if geometry.elements.count > 1 {
                    node.geometry = nil
                    for index in 0..<geometry.elements.count {
                        let partGeometry = SCNGeometry(sources: geometry.sources,
                                                       elements: [geometry.element(at: index)])
                        let isWrap = index > 0
                        partGeometry.materials = [isWrap ? ribbon : paper]
                        if isWrap { partGeometry.subdivisionLevel = 1 }
                        let part = SCNNode(geometry: partGeometry)
                        part.name = isWrap ? "wrapping_\(index)" : "paper_box"
                        part.castsShadow = true; node.addChildNode(part)
                        if isWrap { wrappingNodes.append(part) } else { boxNodes.append(part) }
                    }
                    return
                }
                let isWrap = lower.contains("bow") || lower.contains("ribbon")
                geometry.materials = [isWrap ? ribbon : paper]; node.castsShadow = true
                if isWrap { wrappingNodes.append(node) } else { boxNodes.append(node) }
            }
            node.childNodes.forEach(prepare)
        }
        prepare(modelRoot)
        let bounds = modelRoot.boundingBox
        let center = SCNVector3((bounds.min.x + bounds.max.x) * 0.5,
                                (bounds.min.y + bounds.max.y) * 0.5,
                                (bounds.min.z + bounds.max.z) * 0.5)
        modelRoot.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)
        let extent = max(bounds.max.x - bounds.min.x,
                         max(bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z))
        let scale = 108 / max(extent, 0.001)
        modelRoot.scale = SCNVector3(scale, scale, scale)
        giftRoot.addChildNode(modelRoot)
        giftRoot.position.y = -7
        giftRoot.eulerAngles = SCNVector3(-0.10, -0.48, 0.035)
        scene.rootNode.addChildNode(giftRoot)

        let shadow = SCNPlane(width: 192, height: 116)
        let shadowMaterial = SCNMaterial()
        shadowMaterial.lightingModel = .constant
        shadowMaterial.diffuse.contents = Self.softShadowTexture()
        shadowMaterial.isDoubleSided = true
        shadowMaterial.writesToDepthBuffer = false
        shadow.materials = [shadowMaterial]
        let shadowNode = SCNNode(geometry: shadow)
        shadowNode.eulerAngles.x = -.pi / 2; shadowNode.position = SCNVector3(0, -78, 5)
        scene.rootNode.addChildNode(shadowNode)

        let camera = SCNCamera(); camera.fieldOfView = 34; camera.zNear = 1; camera.zFar = 800
        let cameraNode = SCNNode(); cameraNode.camera = camera
        cameraNode.position = SCNVector3(118, 92, 295)
        let look = SCNLookAtConstraint(target: giftRoot); look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]; scene.rootNode.addChildNode(cameraNode)

        scene.lightingEnvironment.contents = NSColor.white
        scene.lightingEnvironment.intensity = 0.58
        let key = SCNLight(); key.type = .area; key.intensity = 1540
        key.color = NSColor(calibratedRed: 1, green: 0.79, blue: 0.58, alpha: 1)
        key.areaExtents = SIMD3<Float>(105, 105, 0); key.castsShadow = true; key.shadowRadius = 11
        let keyNode = SCNNode(); keyNode.light = key; keyNode.position = SCNVector3(-105, 150, 175)
        keyNode.constraints = [SCNLookAtConstraint(target: giftRoot)]; scene.rootNode.addChildNode(keyNode)
        let rim = SCNLight(); rim.type = .omni; rim.intensity = 680
        rim.color = NSColor(calibratedRed: 0.40, green: 0.58, blue: 0.92, alpha: 1)
        let rimNode = SCNNode(); rimNode.light = rim; rimNode.position = SCNVector3(110, 35, -80)
        scene.rootNode.addChildNode(rimNode)
        let fill = SCNLight(); fill.type = .ambient; fill.intensity = 480
        let fillNode = SCNNode(); fillNode.light = fill; scene.rootNode.addChildNode(fillNode)

        let turn = SCNAction.sequence([.rotateBy(x: 0, y: 0.075, z: 0.006, duration: 1.8),
                                       .rotateBy(x: 0, y: -0.15, z: -0.012, duration: 3.6),
                                       .rotateBy(x: 0, y: 0.075, z: 0.006, duration: 1.8)])
        turn.timingMode = .easeInEaseOut
        giftRoot.runAction(.repeatForever(turn), forKey: "idle")
    }

    private static func softShadowTexture() -> NSImage {
        let size = NSSize(width: 256, height: 128)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let oval = NSBezierPath(ovalIn: NSRect(x: 8, y: 16, width: 240, height: 96))
        oval.addClip()
        let gradient = NSGradient(starting: NSColor(calibratedWhite: 0.05, alpha: 0.20),
                                  ending: NSColor(calibratedWhite: 0.05, alpha: 0))
        gradient?.draw(in: NSRect(origin: .zero, size: size), relativeCenterPosition: .zero)
        image.unlockFocus()
        return image
    }

    override func mouseDown(with event: NSEvent) { openGift() }

    func openGift() {
        guard !opened else { return }
        opened = true
        giftRoot.removeAction(forKey: "idle")
        for (index, node) in wrappingNodes.enumerated() {
            let direction: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let unwrap = SCNAction.group([
                .moveBy(x: direction * (38 + CGFloat(index) * 8), y: 74, z: 12, duration: 0.76),
                .rotateBy(x: -0.38, y: direction * 0.7, z: direction * 0.52, duration: 0.76),
                .fadeOut(duration: 0.64)
            ])
            unwrap.timingMode = .easeInEaseOut; node.runAction(unwrap)
        }
        for node in boxNodes {
            let open = SCNAction.sequence([
                .wait(duration: 0.12),
                .group([.moveBy(x: 0, y: -22, z: 8, duration: 0.58),
                        .scale(to: 0.80, duration: 0.58),
                        .fadeOut(duration: 0.58)])
            ])
            open.timingMode = .easeInEaseOut; node.runAction(open)
        }
        let glowMaterial = SCNMaterial(); glowMaterial.lightingModel = .constant
        glowMaterial.emission.contents = NSColor(calibratedRed: 0.30, green: 0.78, blue: 1, alpha: 1)
        glowMaterial.diffuse.contents = NSColor.clear
        let glow = SCNNode(geometry: SCNSphere(radius: 7)); glow.geometry?.materials = [glowMaterial]
        glow.opacity = 0; glow.position.y = -4; giftRoot.addChildNode(glow)
        glow.runAction(.sequence([.group([.fadeOpacity(to: 0.75, duration: 0.16),
                                         .scale(to: 3.6, duration: 0.58)]),
                                  .fadeOut(duration: 0.20)]))
        giftRoot.runAction(.sequence([.scale(to: 1.035, duration: 0.09),
                                      .scale(to: 0.99, duration: 0.14)]))
        onOpen?()
    }
}

final class GiftWindowController: NSWindowController {
    var onOpen: (() -> Void)?
    var onArm: (() -> Void)?
    var onLanguageChange: ((GiftLanguage) -> Void)?
    private(set) var language = GiftLanguage.systemDefault
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let giftName = NSTextField(labelWithString: "")
    private let openButton = NSButton(title: "", target: nil, action: nil)
    private let languageButton = NSButton(title: "中 / EN", target: nil, action: nil)
    private let swatter = SwatterGraphicView(frame: .zero)
    private let giftBox = GiftBox3DView(frame: .zero)
    private var swatterCenterY: NSLayoutConstraint!
    private var opened = false

    init() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                            styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .screenSaver
        super.init(window: panel)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        guard let window else { return }
        let root = RetroPaperView(frame: window.contentView?.bounds ?? .zero)
        root.autoresizingMask = [.width, .height]
        window.contentView = root

        titleLabel.font = .boldSystemFont(ofSize: 29)
        titleLabel.textColor = giftRed
        titleLabel.alignment = .center
        bodyLabel.font = .systemFont(ofSize: 17)
        bodyLabel.textColor = giftInk
        bodyLabel.alignment = .center
        giftName.font = .boldSystemFont(ofSize: 31)
        giftName.textColor = giftRed
        giftName.alignment = .center
        giftName.isHidden = true
        swatter.isHidden = true
        swatter.onClick = { [weak self] in self?.arm() }
        swatter.toolTip = language == .zh ? "点击拿起苍蝇拍" : "Click to pick up the swatter"
        giftBox.onOpen = { [weak self] in self?.openGift() }
        openButton.bezelStyle = .rounded
        openButton.target = self; openButton.action = #selector(openGift)
        languageButton.isBordered = false
        languageButton.font = .boldSystemFont(ofSize: 12)
        languageButton.contentTintColor = giftRed
        languageButton.target = self; languageButton.action = #selector(toggleLanguage)

        for v in [titleLabel, bodyLabel, giftName, giftBox, swatter, openButton, languageButton] {
            v.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(v)
        }
        swatterCenterY = swatter.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: 34)
        NSLayoutConstraint.activate([
            languageButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            languageButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 46),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 19),
            bodyLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 52),
            bodyLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -52),
            giftName.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 11),
            giftName.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 30),
            giftName.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -30),
            giftBox.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            giftBox.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 5),
            giftBox.widthAnchor.constraint(equalToConstant: 330),
            giftBox.heightAnchor.constraint(equalToConstant: 245),
            swatter.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            swatterCenterY,
            swatter.widthAnchor.constraint(equalToConstant: 150),
            swatter.heightAnchor.constraint(equalToConstant: 205),
            openButton.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            openButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -35),
            openButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 155),
        ])
        updateCopy()
    }

    func showCentered() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center(); showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.orderFrontRegardless()
    }

    @objc private func openGift() {
        guard !opened else { return }
        opened = true
        bodyLabel.isHidden = true; openButton.isHidden = true
        titleLabel.stringValue = language == .zh ? "正在拆开…" : "Opening…"
        giftBox.openGift(); onOpen?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.74) { [weak self] in
            guard let self else { return }
            self.giftBox.isHidden = true
            self.giftName.isHidden = false; self.swatter.isHidden = false
            self.updateCopy()
        }
    }

    @objc private func arm() { onArm?() }
    @objc private func toggleLanguage() {
        language.toggle(); updateCopy(); onLanguageChange?(language)
    }

    private func updateCopy() {
        let c = GiftCopy(language: language)
        titleLabel.stringValue = opened ? c.won : c.giftTitle
        bodyLabel.stringValue = c.giftBody
        openButton.title = c.open
        giftName.stringValue = c.swatter
        swatter.toolTip = c.arm
    }

    func collapseToTray(on screen: NSScreen) {
        guard let window else { return }
        titleLabel.isHidden = true; bodyLabel.isHidden = true; giftName.isHidden = true
        swatter.isHidden = false; openButton.isHidden = true; languageButton.isHidden = true
        swatterCenterY.constant = 0
        let size = NSSize(width: 180, height: 220)
        let f = screen.visibleFrame
        window.setFrame(NSRect(x: f.maxX - size.width - 22, y: f.minY + 22, width: size.width, height: size.height), display: true, animate: true)
    }
}

final class SwatterOverlayController {
    /// Base geometry, all in the swatter's own coordinate space. The power-up
    /// multiplies every one of these by `scale`, so the rendered graphic, the
    /// pointer offset and the hit shape stay locked together.
    static let basePanel = NSSize(width: 105, height: 135)
    static let pointerInset = CGPoint(x: 52, y: 115)
    static let pivotDrop: CGFloat = 105
    static let headOffset: CGFloat = 92
    static let headSize = CGSize(width: 72, height: 54)

    /// Shake-to-grow buff: a few sharp cursor reversals arm it, the head then
    /// stays enlarged for `boostDuration`. A bigger head also subtends a bigger
    /// looming stimulus, so the fly spooks sooner — the buff trades precision
    /// for reach rather than being a free win.
    private static let boostedScale: CGFloat = 1.7
    private static let boostDuration: TimeInterval = 4
    private static let boostLockout: TimeInterval = 0.8
    private static let shakeMinSpeed: CGFloat = 800
    private static let shakeThreshold: CGFloat = 2.5

    private let panel: NSPanel
    private let graphic: SwatterGraphicView
    private(set) var armed = false
    private(set) var isSwinging = false
    private(set) var scale: CGFloat = 1
    private var animationTimer: Timer?
    private var swingPhase: CGFloat = 0

    private var lastPointer: CGPoint?
    private var lastPointerTime: TimeInterval?
    private var previousVelocity: CGPoint?
    private var shakeEnergy: CGFloat = 0
    private var boostUntil: TimeInterval = 0
    private var lastBoostAt: TimeInterval = -.greatestFiniteMagnitude

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.basePanel.width, height: Self.basePanel.height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        graphic = SwatterGraphicView(frame: panel.contentView?.bounds ?? .zero)
        graphic.autoresizingMask = [.width, .height]; panel.contentView = graphic
    }

    func arm() {
        guard !armed else { return }
        armed = true
        resetShake()
        CGDisplayHideCursor(CGMainDisplayID())
        panel.orderFrontRegardless()
    }

    /// Runs once per frame while the swatter is held: watches the cursor for a
    /// back-and-forth shake and keeps the head size in sync with the buff.
    func update(now: TimeInterval, pointer: CGPoint) {
        guard armed else { resetShake(); return }
        if let last = lastPointer, let lastTime = lastPointerTime, now > lastTime {
            let dt = now - lastTime
            let velocity = CGPoint(x: (pointer.x - last.x) / dt, y: (pointer.y - last.y) / dt)
            let speed = hypot(velocity.x, velocity.y)
            shakeEnergy *= CGFloat(exp(-dt / 0.28))
            if speed > Self.shakeMinSpeed, let previous = previousVelocity {
                let previousSpeed = hypot(previous.x, previous.y)
                let alignment = (velocity.x * previous.x + velocity.y * previous.y)
                    / (speed * previousSpeed)
                if alignment < -0.4 { shakeEnergy += 1 }   // sharp direction reversal
            }
            previousVelocity = speed > Self.shakeMinSpeed ? velocity : nil
            if shakeEnergy >= Self.shakeThreshold, now - lastBoostAt > Self.boostLockout {
                lastBoostAt = now
                boostUntil = now + Self.boostDuration
                shakeEnergy = 0
            }
        }
        lastPointer = pointer
        lastPointerTime = now
        apply(scale: now < boostUntil ? Self.boostedScale : 1, pointer: pointer)
    }

    private func apply(scale wanted: CGFloat, pointer: CGPoint) {
        if wanted != scale {
            scale = wanted
            graphic.boosted = wanted > 1
            panel.setContentSize(NSSize(width: Self.basePanel.width * wanted,
                                        height: Self.basePanel.height * wanted))
        }
        move(to: pointer)
    }

    private func resetShake() {
        lastPointer = nil; lastPointerTime = nil
        previousVelocity = nil; shakeEnergy = 0; boostUntil = 0
    }

    func move(to point: CGPoint) {
        guard armed else { return }
        panel.setFrameOrigin(NSPoint(x: point.x - Self.pointerInset.x * scale,
                                     y: point.y - Self.pointerInset.y * scale))
    }

    func swing() {
        guard armed else { return }
        animationTimer?.invalidate()
        isSwinging = true
        let start = ProcessInfo.processInfo.systemUptime
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let t = (ProcessInfo.processInfo.systemUptime - start) / 0.22
            if t >= 1 {
                self.isSwinging = false
                self.swingPhase = 0; self.graphic.swing = 0; timer.invalidate(); return
            }
            self.swingPhase = CGFloat(sin(t * .pi))
            self.graphic.swing = self.swingPhase
        }
    }

    /// Geometric counterpart of the rendered plastic head. The pointer sits
    /// near the upper handle/head junction; rotating this offset around the
    /// same pivot as `SwatterGraphicView` keeps perception and hit testing
    /// aligned with the pixels during a swing.
    func headSample(at pointer: CGPoint) -> SwatterHeadSample? {
        guard armed else { return nil }
        let angle = (-10 - swingPhase * 34) * .pi / 180
        let pivot = CGPoint(x: pointer.x, y: pointer.y - Self.pivotDrop * scale)
        let headVector = CGPoint(x: 0, y: Self.headOffset * scale)
        let c = cos(angle), s = sin(angle)
        let center = CGPoint(x: pivot.x + headVector.x * c - headVector.y * s,
                             y: pivot.y + headVector.x * s + headVector.y * c)
        return SwatterHeadSample(center: center,
                                 size: CGSize(width: Self.headSize.width * scale,
                                              height: Self.headSize.height * scale),
                                 angle: angle, swing: swingPhase)
    }

    func disarm() {
        animationTimer?.invalidate(); animationTimer = nil
        isSwinging = false
        swingPhase = 0; graphic.swing = 0
        if scale != 1 {
            scale = 1
            graphic.boosted = false
            panel.setContentSize(Self.basePanel)
        }
        resetShake()
        panel.orderOut(nil)
        guard armed else { return }
        armed = false
        CGDisplayShowCursor(CGMainDisplayID())
    }
}

private final class ClickCatcherView: NSView {
    var onClick: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onClick?() }
}

final class FlyHitWindowController {
    private let panel: NSPanel
    private let catcher: ClickCatcherView

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 18, height: 18), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .screenSaver; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        catcher = ClickCatcherView(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        panel.contentView = catcher
    }

    var onClick: (() -> Void)? { didSet { catcher.onClick = onClick } }

    func update(at cursor: CGPoint, active: Bool) {
        if active {
            panel.setFrameOrigin(NSPoint(x: cursor.x - 9, y: cursor.y - 9))
            panel.orderFrontRegardless()
        } else { panel.orderOut(nil) }
    }

    func hide() { panel.orderOut(nil) }
}

final class CountdownWindowController {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 58), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = giftRed.withAlphaComponent(0.94)
        panel.hasShadow = true; panel.ignoresMouseEvents = true; panel.level = .floating
        label.frame = panel.contentView?.bounds.insetBy(dx: 10, dy: 10) ?? .zero
        label.autoresizingMask = [.width, .height]
        label.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        label.textColor = giftCream; label.alignment = .center
        panel.contentView?.addSubview(label)
    }

    func show(seconds: Int, language: GiftLanguage, on screen: NSScreen) {
        label.stringValue = "\(GiftCopy(language: language).countdownPrefix)  00:\(String(format: "%02d", seconds))"
        let f = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: f.midX - 110, y: f.maxY - 86))
        panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
}

final class SplatWindowController {
    private let panel: NSPanel
    init(at point: CGPoint) {
        let size = NSSize(width: 240, height: 190)
        panel = NSPanel(contentRect: NSRect(x: point.x - size.width / 2,
                                            y: point.y - size.height / 2,
                                            width: size.width, height: size.height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let v = SplatView(frame: NSRect(origin: .zero, size: size)); panel.contentView = v
        panel.orderFrontRegardless()
        v.beginDissolve()
    }
    func hide() { panel.orderOut(nil) }
}

private final class SplatView: NSView {
    private let residueLayer = CALayer()
    private let emitter = CAEmitterLayer()
    private let scanRing = CAShapeLayer()
    private var started = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false
        configureLayers()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configureLayers() {
        guard let root = layer else { return }
        residueLayer.frame = bounds.insetBy(dx: 22, dy: 28)
        residueLayer.contentsGravity = .resizeAspect
        residueLayer.opacity = 0
        if let url = findResource("splat-realistic-v1.png")
                ?? findResource("assets/splat-realistic-v1.png"),
           let image = NSImage(contentsOf: url) {
            var rect = NSRect(origin: .zero, size: image.size)
            residueLayer.contents = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        root.addSublayer(residueLayer)

        scanRing.frame = bounds
        scanRing.path = CGPath(ellipseIn: bounds.insetBy(dx: 67, dy: 45), transform: nil)
        scanRing.fillColor = NSColor.clear.cgColor
        scanRing.strokeColor = NSColor(calibratedRed: 0.20, green: 0.84, blue: 1, alpha: 0.88).cgColor
        scanRing.lineWidth = 1.35; scanRing.lineDashPattern = [3, 5]
        scanRing.shadowColor = NSColor(calibratedRed: 0.12, green: 0.76, blue: 1, alpha: 1).cgColor
        scanRing.shadowRadius = 7; scanRing.shadowOpacity = 0.9; scanRing.opacity = 0
        root.addSublayer(scanRing)

        emitter.frame = bounds; emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterShape = .point; emitter.renderMode = .additive
        emitter.birthRate = 0
        let blue = particleCell(color: NSColor(calibratedRed: 0.20, green: 0.86, blue: 1, alpha: 1),
                                velocity: 76, scale: 0.65)
        let gold = particleCell(color: NSColor(calibratedRed: 1, green: 0.69, blue: 0.20, alpha: 1),
                                velocity: 58, scale: 0.46)
        emitter.emitterCells = [blue, gold]
        root.addSublayer(emitter)
    }

    private func particleCell(color: NSColor, velocity: CGFloat, scale: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = particleImage(color: color)
        cell.birthRate = 92; cell.lifetime = 0.82; cell.lifetimeRange = 0.28
        cell.velocity = velocity; cell.velocityRange = 46
        cell.emissionRange = .pi * 2
        cell.scale = scale; cell.scaleRange = 0.34; cell.scaleSpeed = -0.28
        cell.alphaSpeed = -1.08; cell.spinRange = .pi * 2
        cell.color = color.cgColor
        return cell
    }

    private func particleImage(color: NSColor) -> CGImage? {
        let image = NSImage(size: NSSize(width: 13, height: 13))
        image.lockFocus()
        let shadow = NSShadow(); shadow.shadowColor = color; shadow.shadowBlurRadius = 4
        shadow.shadowOffset = .zero; shadow.set()
        color.setFill(); NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 5, height: 5),
                                      xRadius: 1.2, yRadius: 1.2).fill()
        image.unlockFocus()
        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    func beginDissolve() {
        guard !started else { return }
        started = true
        let appear = CAKeyframeAnimation(keyPath: "transform.scale")
        appear.values = [0.72, 1.08, 1.0]; appear.keyTimes = [0, 0.62, 1]
        appear.duration = 0.18; appear.timingFunction = CAMediaTimingFunction(name: .easeOut)
        residueLayer.add(appear, forKey: "impact")
        residueLayer.opacity = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { [weak self] in
            guard let self else { return }
            self.emitter.birthRate = 1
            self.scanRing.opacity = 1
            let ring = CAAnimationGroup()
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.38; scale.toValue = 1.65
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9; fade.toValue = 0
            ring.animations = [scale, fade]; ring.duration = 0.72
            ring.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.scanRing.add(ring, forKey: "scan")
            self.scanRing.opacity = 0

            CATransaction.begin(); CATransaction.setAnimationDuration(0.82)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            self.residueLayer.opacity = 0
            self.residueLayer.transform = CATransform3DMakeScale(0.64, 0.64, 1)
            CATransaction.commit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
                self?.emitter.birthRate = 0
            }
        }
    }
}

final class ResultWindowController: NSWindowController {
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private var onClose: (() -> Void)?

    init(result: ChallengeResult, language: GiftLanguage, onClose: @escaping () -> Void) {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 610, height: 500), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true; panel.level = .screenSaver
        panel.isFloatingPanel = true; panel.hidesOnDeactivate = false
        self.onClose = onClose
        super.init(window: panel)
        build(result: result, language: language)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build(result: ChallengeResult, language: GiftLanguage) {
        guard let window else { return }
        let root = RetroPaperView(frame: window.contentView?.bounds ?? .zero); root.autoresizingMask = [.width, .height]; window.contentView = root
        let c = GiftCopy(language: language)
        let success: Bool
        let stats: String
        switch result {
        case let .killed(elapsed, swings): success = true; stats = c.successStats(seconds: elapsed, swings: swings)
        case let .escaped(swings): success = false; stats = c.failureStats(swings: swings)
        case .cancelled: success = false; stats = ""
        }
        let title = NSTextField(wrappingLabelWithString: success ? c.successTitle : c.failureTitle)
        title.font = .boldSystemFont(ofSize: 27); title.textColor = giftRed; title.alignment = .center
        let stat = NSTextField(labelWithString: stats); stat.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold); stat.textColor = giftInk; stat.alignment = .center
        let science = NSTextField(wrappingLabelWithString: c.science); science.font = .systemFont(ofSize: 16); science.textColor = giftInk
        let boundary = NSTextField(wrappingLabelWithString: c.boundary); boundary.font = .systemFont(ofSize: 13); boundary.textColor = giftInk.withAlphaComponent(0.72)
        let repo = NSTextField(labelWithString: "github.com/ThomasLin070217/FlyGift"); repo.font = .monospacedSystemFont(ofSize: 12, weight: .regular); repo.textColor = giftRed; repo.alignment = .center
        closeButton.title = c.close; closeButton.target = self; closeButton.action = #selector(closeNow)
        for v in [title, stat, science, boundary, repo, closeButton] { v.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(v) }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 68), title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 42), title.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -42),
            stat.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 15), stat.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 30), stat.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -30),
            science.topAnchor.constraint(equalTo: stat.bottomAnchor, constant: 29), science.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 55), science.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -55),
            boundary.topAnchor.constraint(equalTo: science.bottomAnchor, constant: 18), boundary.leadingAnchor.constraint(equalTo: science.leadingAnchor), boundary.trailingAnchor.constraint(equalTo: science.trailingAnchor),
            repo.topAnchor.constraint(equalTo: boundary.bottomAnchor, constant: 24), repo.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 30), repo.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -30),
            closeButton.centerXAnchor.constraint(equalTo: root.centerXAnchor), closeButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -37), closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 130)
        ])
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center(); showWindow(nil); window?.makeKeyAndOrderFront(nil); window?.orderFrontRegardless()
    }
    @objc private func closeNow() { onClose?() }
}

final class FlyAudioController {
    private let engine = AVAudioEngine()
    private let buzz = AVAudioPlayerNode()
    private let swing = AVAudioPlayerNode()
    private let hit = AVAudioPlayerNode()
    private var ready = false
    private(set) var muted = false

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        engine.attach(buzz); engine.attach(swing); engine.attach(hit)
        engine.connect(buzz, to: engine.mainMixerNode, format: format)
        engine.connect(swing, to: engine.mainMixerNode, format: format)
        engine.connect(hit, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            if let buffer = makeBuzz(format: format) {
                buzz.scheduleBuffer(buffer, at: nil, options: .loops)
                buzz.volume = 0; buzz.play()
            }
            ready = true
        } catch { fputs("audio: \(error)\n", stderr) }
    }

    func setMuted(_ value: Bool) { muted = value; if value { buzz.volume = 0 } }
    func setFlying(_ flying: Bool, pan: Float, close: Bool = false) {
        guard ready else { return }
        buzz.pan = max(-1, min(1, pan))
        buzz.volume = muted ? 0 : (flying ? (close ? 0.42 : 0.13) : 0)
    }
    func playSwing() { playOneShot(on: swing, frequency: 92, duration: 0.12, noisy: true, volume: 0.20) }
    func playHit() { playOneShot(on: hit, frequency: 48, duration: 0.19, noisy: true, volume: 0.32) }
    func stop() { buzz.volume = 0; engine.stop() }

    private func makeBuzz(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate)
        guard let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        b.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            guard let out = b.floatChannelData?[channel] else { continue }
            for i in 0..<Int(frames) {
                let t = Double(i) / format.sampleRate
                let wobble = 205 + 8 * sin(t * 2 * .pi * 7.3)
                let body = sin(t * 2 * .pi * wobble) * 0.55 + sin(t * 2 * .pi * wobble * 2.03) * 0.20
                let grit = Double.random(in: -1...1) * 0.10
                out[i] = Float((body + grit) * 0.55)
            }
        }
        return b
    }

    private func playOneShot(on node: AVAudioPlayerNode, frequency: Double, duration: Double, noisy: Bool, volume: Float) {
        guard ready, !muted else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        b.frameLength = frames
        for c in 0..<2 {
            guard let out = b.floatChannelData?[c] else { continue }
            for i in 0..<Int(frames) {
                let t = Double(i) / format.sampleRate
                let env = exp(-t * 24)
                let n = noisy ? Double.random(in: -1...1) * 0.65 : 0
                out[i] = Float((sin(t * 2 * .pi * frequency) * 0.45 + n) * env)
            }
        }
        node.stop(); node.volume = volume; node.scheduleBuffer(b); node.play()
    }
}

func runGameTest() {
    var failures = 0
    func check(_ name: String, _ ok: @autoclosure () -> Bool) {
        let pass = ok(); print("\(pass ? "PASS" : "FAIL")  \(name)"); if !pass { failures += 1 }
    }
    let c = ChallengeController()
    c.openGift(now: 10, delay: 4)
    check("gift opens into waiting", c.phase == .waitingForFly)
    check("does not spawn early", !c.shouldSpawn(now: 13.9))
    check("spawns at deadline", c.shouldSpawn(now: 14))
    c.spawn(now: 14)
    check("challenge starts at spawn", c.phase == .challenge && c.remaining(now: 64) == 10)
    check("unarmed cannot kill", c.kill(now: 20) == nil)
    c.arm(); c.recordSwing()
    check("armed grounded result records stats", c.kill(now: 20) == .killed(elapsed: 6, swings: 1))

    let timeout = ChallengeController(); timeout.openGift(now: 0, delay: 3); timeout.spawn(now: 3)
    check("last ten begins at 50 elapsed", timeout.remaining(now: 53) == 10)
    check("timeout waits until sixty", timeout.tick(now: 62.9) == nil)
    check("timeout escapes at sixty", timeout.tick(now: 63) == .escaped(swings: 0))

    let cancel = ChallengeController(); cancel.openGift(now: 0, delay: 3)
    check("cancel is idempotent", cancel.cancel() == .cancelled && cancel.cancel() == nil)

    var escape = DoublePressDetector()
    check("single Escape does not cancel", !escape.press(now: 1.0))
    check("double Escape inside 450 ms cancels", escape.press(now: 1.4))
    check("late second Escape does not cancel", !escape.press(now: 2.0))
    check("hit test includes eight-point forgiveness",
          flyHitTest(cursor: CGPoint(x: 29.5, y: 0), center: .zero, visualRadius: 22))
    check("hit test still rejects clear misses",
          !flyHitTest(cursor: CGPoint(x: 31, y: 0), center: .zero, visualRadius: 22))
    let head = SwatterHeadSample(center: .zero, size: CGSize(width: 72, height: 54),
                                 angle: -.pi / 4, swing: 0.8)
    check("swatter uses the rendered head area, not only the pointer",
          swatterHeadHitTest(flyCenter: CGPoint(x: 29, y: -29), flyRadius: 10, head: head))
    check("swatter head rejects a clear geometric miss",
          !swatterHeadHitTest(flyCenter: CGPoint(x: 95, y: 95), flyRadius: 10, head: head))
    let sweepStart = SwatterHeadSample(center: CGPoint(x: -90, y: 0),
                                       size: CGSize(width: 72, height: 54),
                                       angle: 0, swing: 0)
    let sweepEnd = SwatterHeadSample(center: CGPoint(x: 90, y: 0),
                                     size: CGSize(width: 72, height: 54),
                                     angle: -.pi / 3, swing: 1)
    check("swept hit catches a fly between animation frames",
          !swatterHeadHitTest(flyCenter: .zero, flyRadius: 10, head: sweepStart)
          && !swatterHeadHitTest(flyCenter: .zero, flyRadius: 10, head: sweepEnd)
          && sweptSwatterHeadHitTest(flyCenter: .zero, flyRadius: 10,
                                     from: sweepStart, to: sweepEnd))
    if failures > 0 { fputs("\(failures) GAME TEST FAILURES\n", stderr); exit(1) }
    print("GAME TEST PASS")
}
