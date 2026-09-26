import SpriteKit
import GameplayKit
import UIKit

// =====================================================================
//  RUN FROM JIGAR — polished edition, v4
// =====================================================================
//  New in this version (design notes / assumptions called out since
//  the request was a little ambiguous — see the chat reply for these):
//
//   • TOUCHING Jigar directly is now instant death, separate from the
//     old "distance" mechanic. Jigar has a real physics body now.
//   • Jigar is redesigned to look like a virus: a round cell body
//     covered in spike proteins, in sickly toxic tones.
//   • The old horizontal "JIGAR 260m" bar is replaced by a VERTICAL
//     "Jigar Health" bar, top-right, scaled 0–100. Reading it as your
//     remaining safety margin: 100 = fully safe, 0 = caught.
//   • Jigar's ranged shots no longer instant-kill on hit. Instead each
//     hit chips a random 4–15 off that Health bar (dodging is still
//     the correct play — direct contact is still instant death).
//     A Shield power-up blocks both ranged chip damage and a direct
//     touch.
//
//  Everything else (procedural art for player/RAM, menu, Garage,
//  particles, screen shake, pause, combo counter, power-ups) is
//  unchanged from v3.
// =====================================================================

// MARK: - Collision Categories

struct PhysicsCategory {
    static let none: UInt32       = 0
    static let player: UInt32     = 0b1
    static let ram: UInt32        = 0b10
    static let powerUp: UInt32    = 0b100
    static let projectile: UInt32 = 0b1000
    static let jigarBody: UInt32  = 0b10000
}

// MARK: - Game States

enum GameState {
    case menu
    case tutorial
    case garage
    case playing
    case paused
    case gameOver
}

// MARK: - Power Ups

enum PowerUp: CaseIterable {
    case speedBoost
    case ramMagnet
    case shield
    case jigarAttack
    case freezeJigar

    var displayName: String {
        switch self {
        case .speedBoost:  return "SPEED BOOST"
        case .ramMagnet:   return "RAM MAGNET"
        case .shield:      return "SHIELD"
        case .jigarAttack: return "JIGAR ATTACK"
        case .freezeJigar: return "FREEZE JIGAR"
        }
    }

    var description: String {
        switch self {
        case .speedBoost:  return "Run faster and create distance."
        case .ramMagnet:   return "Pull nearby RAM toward you."
        case .shield:      return "Protect yourself from Jigar."
        case .jigarAttack: return "Knock Jigar farther away."
        case .freezeJigar: return "Stop Jigar from chasing you."
        }
    }

    var color: UIColor {
        switch self {
        case .speedBoost:  return UIColor(red: 0.20, green: 0.95, blue: 1.00, alpha: 1)
        case .ramMagnet:   return UIColor(red: 0.30, green: 1.00, blue: 0.45, alpha: 1)
        case .shield:      return UIColor(red: 0.35, green: 0.55, blue: 1.00, alpha: 1)
        case .jigarAttack: return UIColor(red: 1.00, green: 0.30, blue: 0.35, alpha: 1)
        case .freezeJigar: return UIColor(red: 0.75, green: 0.40, blue: 1.00, alpha: 1)
        }
    }

    var glyph: String {
        switch self {
        case .speedBoost:  return "⚡"
        case .ramMagnet:   return "🧲"
        case .shield:      return "🛡"
        case .jigarAttack: return "💥"
        case .freezeJigar: return "❄"
        }
    }

    var assetName: String {
        switch self {
        case .speedBoost:  return "speedBoostSprite"
        case .ramMagnet:   return "ramMagnetSprite"
        case .shield:      return "shieldSprite"
        case .jigarAttack: return "jigarAttackSprite"
        case .freezeJigar: return "freezeJigarSprite"
        }
    }
}

// MARK: - Cosmetic Skins (unlocked/bought with banked RAM)

struct SkinOption {
    let id: String
    let name: String
    let color: UIColor
    let cost: Int
}

let playerSkins: [SkinOption] = [
    SkinOption(id: "default", name: "CYAN RUNNER", color: UIColor(red: 0.35, green: 0.95, blue: 1.0, alpha: 1), cost: 0),
    SkinOption(id: "gold",    name: "GOLD RUNNER",  color: UIColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 1), cost: 150),
    SkinOption(id: "magenta", name: "NEON PINK",    color: UIColor(red: 1.0, green: 0.25, blue: 0.75, alpha: 1), cost: 150),
    SkinOption(id: "emerald", name: "EMERALD",      color: UIColor(red: 0.25, green: 1.0, blue: 0.55, alpha: 1), cost: 250),
    SkinOption(id: "ghost",   name: "GHOST WHITE",  color: UIColor(white: 0.95, alpha: 1), cost: 350)
]

let jigarSkins: [SkinOption] = [
    SkinOption(id: "default", name: "CRIMSON VIRUS", color: UIColor(red: 0.85, green: 0.15, blue: 0.2, alpha: 1), cost: 0),
    SkinOption(id: "toxic",   name: "TOXIC VIRUS",    color: UIColor(red: 0.35, green: 0.95, blue: 0.25, alpha: 1), cost: 200),
    SkinOption(id: "shadow",  name: "SHADOW VIRUS",   color: UIColor(white: 0.25, alpha: 1), cost: 200),
    SkinOption(id: "royal",   name: "ROYAL VIRUS",    color: UIColor(red: 0.55, green: 0.25, blue: 1.0, alpha: 1), cost: 350)
]

// MARK: - Persistent Meta Progress

final class MetaProgress {

    static let shared = MetaProgress()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let totalRAM = "TotalRAMBanked"
        static let unlockedPlayerSkins = "UnlockedPlayerSkins"
        static let unlockedJigarSkins = "UnlockedJigarSkins"
        static let equippedPlayerSkin = "EquippedPlayerSkin"
        static let equippedJigarSkin = "EquippedJigarSkin"
        static let highScore = "HighScoreRAM"
    }

    var totalRAM: Int {
        get { defaults.integer(forKey: Keys.totalRAM) }
        set { defaults.set(max(0, newValue), forKey: Keys.totalRAM) }
    }

    var level: Int { totalRAM / 100 + 1 }
    var levelProgress: CGFloat { CGFloat(totalRAM % 100) / 100.0 }

    var bestRun: Int {
        get { defaults.integer(forKey: Keys.highScore) }
        set { defaults.set(newValue, forKey: Keys.highScore) }
    }

    var unlockedPlayerSkins: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.unlockedPlayerSkins) ?? ["default"]) }
        set { defaults.set(Array(newValue), forKey: Keys.unlockedPlayerSkins) }
    }

    var unlockedJigarSkins: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.unlockedJigarSkins) ?? ["default"]) }
        set { defaults.set(Array(newValue), forKey: Keys.unlockedJigarSkins) }
    }

    var equippedPlayerSkin: String {
        get { defaults.string(forKey: Keys.equippedPlayerSkin) ?? "default" }
        set { defaults.set(newValue, forKey: Keys.equippedPlayerSkin) }
    }

    var equippedJigarSkin: String {
        get { defaults.string(forKey: Keys.equippedJigarSkin) ?? "default" }
        set { defaults.set(newValue, forKey: Keys.equippedJigarSkin) }
    }

    func unlockPlayerSkin(_ id: String) {
        var set = unlockedPlayerSkins
        set.insert(id)
        unlockedPlayerSkins = set
    }

    func unlockJigarSkin(_ id: String) {
        var set = unlockedJigarSkins
        set.insert(id)
        unlockedJigarSkins = set
    }
}

// MARK: - Game Scene

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: Main Nodes

    private var player: SKNode!
    private var playerCore: SKSpriteNode!
    private var playerGlow: SKSpriteNode!
    private var playerShadow: SKShapeNode!

    private var jigar: SKNode!
    private var jigarCore: SKSpriteNode!
    private var jigarGlow: SKSpriteNode!

    private var backgroundNode: SKNode!
    private var worldNode: SKNode!
    private var uiNode: SKNode!

    // MARK: HUD (in-run)

    private var ramLabel: SKLabelNode!
    private var ramProgressBar: SKShapeNode!
    private var ramProgressFill: SKShapeNode!

    // Vertical "Jigar Health" bar, top-right, 0-100.
    private var jigarHealthTitle: SKLabelNode!
    private var jigarHealthBarBack: SKShapeNode!
    private var jigarHealthBarFill: SKShapeNode!
    private var jigarHealthValueLabel: SKLabelNode!
    private let jigarHealthBarHeight: CGFloat = 120

    private var comboLabel: SKLabelNode!

    private var powerUpBadge: SKNode!
    private var powerUpIconLabel: SKLabelNode!
    private var powerUpTextLabel: SKLabelNode!

    private var pauseButton: SKShapeNode!

    // MARK: Screens

    private var menuNode: SKNode!
    private var garageNode: SKNode!
    private var tutorialNode: SKNode!
    private var gameOverNode: SKNode!
    private var pauseNode: SKNode!

    // MARK: Game State

    private var gameState: GameState = .menu

    private var ramCount = 0
    private var ramNeededForPowerUp = 10
    private var comboCount = 0
    private var lastCollectTime: TimeInterval = 0

    // MARK: Jigar Health (0...100 — your remaining safety margin)

    private var jigarHealth: CGFloat = 100
    private let startingJigarHealth: CGFloat = 100
    /// How far (in points) Jigar visually sits behind the player at
    /// full health. Purely cosmetic — derived from jigarHealth. Scaled
    /// up for larger screens in didMove — see contentScale below.
    private var maxVisualGap: CGFloat = 260

    private var jigarFrozen = false
    private var jigarShielded = false

    // MARK: Power Up

    private var availablePowerUp: PowerUp?
    private var powerUpActive = false

    // MARK: Movement

    /// Lane x-positions and the player/Jigar's base y-position. These
    /// start with iPhone-sized defaults but are recomputed in didMove
    /// once the actual scene size is known, so the 3 lanes stretch
    /// across the whole width on a bigger screen (iPad/macOS) instead
    /// of sitting in a fixed narrow strip in the middle.
    private var lanes: [CGFloat] = [-100, 0, 100]
    private var currentLane = 1
    private var playerBaseY: CGFloat = -170

    /// Scale applied to every gameplay sprite (player, Jigar, RAM,
    /// projectiles, glows) so they enlarge to match bigger screens
    /// instead of staying iPhone-sized and looking tiny. 1.0 on a
    /// ~375pt-wide iPhone; grows from there.
    private var contentScale: CGFloat = 1.0

    // MARK: Game Speed

    private var gameSpeed: CGFloat = 1.0

    // MARK: RAM Nodes

    private var ramNodes: [SKNode] = []

    // MARK: Sprite Names (optional external assets)

    private enum SpriteName {
        static let player = "playerSprite"
        static let jigar = "jigarSprite"
        static let ram = "ramSprite"
        static let background = "backgroundSprite"
    }

    // =================================================================
    // MARK: - Scene Setup
    // =================================================================

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self

        // --- Scale gameplay for the actual screen size ---
        // On an iPhone-width scene this reproduces the original
        // layout (lanes ~100pt apart, scale 1.0). On a wider iPad or
        // macOS window, the 3 lanes spread out to cover most of the
        // width instead of a fixed narrow strip, and every gameplay
        // sprite scales up to match, instead of looking small and
        // stranded in the middle of a big screen.
        let laneSpan = size.width * 0.32
        lanes = [-laneSpan, 0, laneSpan]
        contentScale = min(max(size.width / 375.0, 1.0), 2.4)
        maxVisualGap = 260 * contentScale
        playerBaseY = -170 * contentScale

        worldNode = SKNode()
        addChild(worldNode)

        uiNode = SKNode()
        uiNode.zPosition = 200
        addChild(uiNode)

        setupBackground()
        setupPlayer()
        setupJigar()
        setupUI()

        menuNode = SKNode()
        menuNode.zPosition = 210
        uiNode.addChild(menuNode)

        garageNode = SKNode()
        garageNode.zPosition = 210
        uiNode.addChild(garageNode)

        setupTutorial()
        setupGameOver()
        setupPauseOverlay()
        setupSwipeControls(view: view)
        setupTapControls(view: view)

        applyEquippedSkins()
        changeState(to: .menu)
    }

    // =================================================================
    // MARK: - State Management
    // =================================================================

    private func changeState(to newState: GameState) {
        gameState = newState

        menuNode.isHidden = true
        garageNode.isHidden = true
        tutorialNode.isHidden = true
        gameOverNode.isHidden = true
        pauseNode.isHidden = true

        switch newState {

        case .menu:
            buildMenuContent()
            menuNode.isHidden = false

            player.isHidden = true
            jigar.isHidden = true
            ramLabel.isHidden = true
            ramProgressBar.isHidden = true
            jigarHealthTitle.isHidden = true
            jigarHealthBarBack.isHidden = true
            jigarHealthBarFill.isHidden = true
            jigarHealthValueLabel.isHidden = true
            powerUpBadge.isHidden = true
            pauseButton.isHidden = true
            comboLabel.isHidden = true

        case .garage:
            buildGarageContent()
            garageNode.isHidden = false

            player.isHidden = true
            jigar.isHidden = true

        case .tutorial:
            tutorialNode.isHidden = false

            player.isHidden = true
            jigar.isHidden = true

        case .playing:
            player.isHidden = false
            jigar.isHidden = false

            ramLabel.isHidden = false
            ramProgressBar.isHidden = false
            jigarHealthTitle.isHidden = false
            jigarHealthBarBack.isHidden = false
            jigarHealthBarFill.isHidden = false
            jigarHealthValueLabel.isHidden = false
            pauseButton.isHidden = false

            resetGame()

        case .paused:
            pauseNode.isHidden = false
            physicsWorld.speed = 0
            worldNode.isPaused = true

        case .gameOver:
            gameOverNode.isHidden = false

            player.isHidden = false
            jigar.isHidden = false

            ramLabel.isHidden = true
            ramProgressBar.isHidden = true
            jigarHealthTitle.isHidden = true
            jigarHealthBarBack.isHidden = true
            jigarHealthBarFill.isHidden = true
            jigarHealthValueLabel.isHidden = true
            powerUpBadge.isHidden = true
            pauseButton.isHidden = true
            comboLabel.isHidden = true

            stopGame()
        }
    }

    // =================================================================
    // MARK: - Procedural Art Helpers
    // =================================================================

    private func glowTexture(color: UIColor, diameter: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let colors = [color.withAlphaComponent(0.55).cgColor,
                          color.withAlphaComponent(0.0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: colors,
                                             locations: [0, 1]) else { return }
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            cgCtx.drawRadialGradient(gradient,
                                      startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: diameter / 2,
                                      options: [])
        }
        return SKTexture(image: image)
    }

    private func playerTexture() -> SKTexture {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let bodyRect = CGRect(x: 14, y: 6, width: 36, height: 52)
            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: 18)

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [UIColor(red: 0.35, green: 0.95, blue: 1.0, alpha: 1).cgColor,
                                                UIColor(red: 0.05, green: 0.55, blue: 0.75, alpha: 1).cgColor] as CFArray,
                                       locations: [0, 1])!
            cgCtx.saveGState()
            bodyPath.addClip()
            cgCtx.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height),
                                      options: [])
            cgCtx.restoreGState()

            let visor = UIBezierPath(roundedRect: CGRect(x: 20, y: 38, width: 24, height: 8), cornerRadius: 4)
            UIColor.white.withAlphaComponent(0.9).setFill()
            visor.fill()

            UIColor.white.withAlphaComponent(0.5).setStroke()
            bodyPath.lineWidth = 2
            bodyPath.stroke()
        }
        return SKTexture(image: image)
    }

    /// Jigar redrawn as a virus: a round "cell body" ringed with
    /// club-headed spike proteins (the classic virus-icon silhouette),
    /// with the same glowing red eyes so the character stays readable
    /// as "the thing chasing me" rather than a generic germ.
    private func jigarTexture() -> SKTexture {
        let canvasSize = CGSize(width: 96, height: 96)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let bodyRadius: CGFloat = 26
            let spikeCount = 12
            let spikeLength: CGFloat = 10
            let spikeHeadRadius: CGFloat = 5

            // Spike proteins first (drawn behind the body so the body
            // edge covers the base of each stalk cleanly).
            for i in 0..<spikeCount {
                let angle = (CGFloat(i) / CGFloat(spikeCount)) * .pi * 2
                let baseX = center.x + cos(angle) * bodyRadius
                let baseY = center.y + sin(angle) * bodyRadius
                let tipX = center.x + cos(angle) * (bodyRadius + spikeLength)
                let tipY = center.y + sin(angle) * (bodyRadius + spikeLength)

                let stalk = UIBezierPath()
                stalk.move(to: CGPoint(x: baseX, y: baseY))
                stalk.addLine(to: CGPoint(x: tipX, y: tipY))
                stalk.lineWidth = 3.5
                UIColor(red: 0.55, green: 0.1, blue: 0.14, alpha: 1).setStroke()
                stalk.stroke()

                let head = UIBezierPath(ovalIn: CGRect(x: tipX - spikeHeadRadius, y: tipY - spikeHeadRadius,
                                                        width: spikeHeadRadius * 2, height: spikeHeadRadius * 2))
                UIColor(red: 0.75, green: 0.15, blue: 0.2, alpha: 1).setFill()
                head.fill()
            }

            // Cell body — mottled sphere with a radial gradient for depth.
            let bodyRect = CGRect(x: center.x - bodyRadius, y: center.y - bodyRadius,
                                   width: bodyRadius * 2, height: bodyRadius * 2)
            let bodyPath = UIBezierPath(ovalIn: bodyRect)

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [UIColor(red: 0.55, green: 0.08, blue: 0.12, alpha: 1).cgColor,
                                                UIColor(red: 0.15, green: 0.02, blue: 0.04, alpha: 1).cgColor] as CFArray,
                                       locations: [0, 1])!
            cgCtx.saveGState()
            bodyPath.addClip()
            cgCtx.drawRadialGradient(gradient,
                                      startCenter: CGPoint(x: center.x - 6, y: center.y + 6), startRadius: 2,
                                      endCenter: center, endRadius: bodyRadius,
                                      options: [])
            cgCtx.restoreGState()

            UIColor(red: 0.85, green: 0.2, blue: 0.25, alpha: 0.6).setStroke()
            bodyPath.lineWidth = 2
            bodyPath.stroke()

            // A few small membrane blemishes for texture.
            for _ in 0..<5 {
                let dotRadius = CGFloat.random(in: 1.5...3)
                let dotAngle = CGFloat.random(in: 0...(.pi * 2))
                let dotDistance = CGFloat.random(in: 4...(bodyRadius - 6))
                let dotX = center.x + cos(dotAngle) * dotDistance
                let dotY = center.y + sin(dotAngle) * dotDistance
                let dot = UIBezierPath(ovalIn: CGRect(x: dotX - dotRadius, y: dotY - dotRadius,
                                                       width: dotRadius * 2, height: dotRadius * 2))
                UIColor.black.withAlphaComponent(0.2).setFill()
                dot.fill()
            }

            // Glowing eyes so it still reads as a character, not just a germ.
            for dx: CGFloat in [-8, 8] {
                let eyeRect = CGRect(x: center.x + dx - 4, y: center.y + 2, width: 8, height: 8)
                UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1).setFill()
                UIBezierPath(ovalIn: eyeRect).fill()
                UIColor.white.withAlphaComponent(0.9).setFill()
                UIBezierPath(ovalIn: eyeRect.insetBy(dx: 2.5, dy: 2.5)).fill()
            }
        }
        return SKTexture(image: image)
    }

    private func ramTexture() -> SKTexture {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let chipRect = CGRect(x: 5, y: 5, width: 22, height: 22)
            let chipPath = UIBezierPath(roundedRect: chipRect, cornerRadius: 4)

            UIColor(red: 0.10, green: 0.55, blue: 0.20, alpha: 1).setFill()
            chipPath.fill()
            UIColor(red: 0.45, green: 1.0, blue: 0.55, alpha: 1).setStroke()
            chipPath.lineWidth = 2
            chipPath.stroke()

            UIColor(red: 0.85, green: 1.0, blue: 0.85, alpha: 1).setFill()
            for i in 0..<4 {
                let x = chipRect.minX + 3 + CGFloat(i) * 5
                cgCtx.fill(CGRect(x: x, y: chipRect.minY - 3, width: 2, height: 3))
                cgCtx.fill(CGRect(x: x, y: chipRect.maxY, width: 2, height: 3))
            }

            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: chipRect.minX + 4, y: chipRect.midY))
            linePath.addLine(to: CGPoint(x: chipRect.maxX - 4, y: chipRect.midY))
            UIColor(red: 0.75, green: 1.0, blue: 0.8, alpha: 0.9).setStroke()
            linePath.lineWidth = 1.5
            linePath.stroke()
        }
        return SKTexture(image: image)
    }

    // =================================================================
    // MARK: - Background
    // =================================================================

    private func setupBackground() {
        backgroundNode = SKNode()
        backgroundNode.zPosition = -100
        worldNode.addChild(backgroundNode)

        if let background = loadSprite(named: SpriteName.background) {
            background.size = CGSize(width: size.width, height: size.height)
            background.position = .zero
            backgroundNode.addChild(background)
        } else {
            backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1.0)
            createModernBackground()
        }
    }

    private func createModernBackground() {
        let gradientTexture = verticalGradientTexture(
            top: UIColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 1),
            bottom: UIColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1),
            size: CGSize(width: max(size.width, 400), height: max(size.height, 800))
        )
        let backdrop = SKSpriteNode(texture: gradientTexture)
        backdrop.zPosition = -101
        backgroundNode.addChild(backdrop)

        for lane in lanes {
            let line = SKShapeNode()
            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: lane, y: -size.height))
            linePath.addLine(to: CGPoint(x: lane, y: size.height))
            line.path = linePath
            line.strokeColor = UIColor(red: 0.15, green: 1.0, blue: 1.0, alpha: 0.10)
            line.lineWidth = 3
            line.glowWidth = 4
            backgroundNode.addChild(line)
        }

        let grid = SKNode()
        backgroundNode.addChild(grid)
        for y in stride(from: -size.height, through: size.height, by: 60) {
            let line = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -size.width, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            line.path = p
            line.strokeColor = UIColor(red: 0.1, green: 0.8, blue: 0.8, alpha: 0.06)
            line.lineWidth = 1
            grid.addChild(line)
        }

        for _ in 0..<18 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.4))
            dot.fillColor = UIColor.cyan.withAlphaComponent(CGFloat.random(in: 0.05...0.18))
            dot.strokeColor = .clear
            dot.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                    y: CGFloat.random(in: -size.height/2...size.height/2))
            backgroundNode.addChild(dot)
            let drift = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.moveBy(x: 0, y: -size.height - 40, duration: Double.random(in: 6...11)),
                    SKAction.moveBy(x: 0, y: size.height + 40, duration: 0)
                ])
            )
            dot.run(drift)
        }
    }

    private func verticalGradientTexture(top: UIColor, bottom: UIColor, size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: colors, locations: [0, 1]) else { return }
            ctx.cgContext.drawLinearGradient(gradient,
                                              start: CGPoint(x: size.width / 2, y: 0),
                                              end: CGPoint(x: size.width / 2, y: size.height),
                                              options: [])
        }
        return SKTexture(image: image)
    }

    // =================================================================
    // MARK: - Player
    // =================================================================

    private func setupPlayer() {
        player = SKNode()
        player.name = "player"
        player.position = CGPoint(x: lanes[currentLane], y: playerBaseY)
        player.zPosition = 20
        worldNode.addChild(player)

        playerShadow = SKShapeNode(ellipseOf: CGSize(width: 40 * contentScale, height: 12 * contentScale))
        playerShadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        playerShadow.strokeColor = .clear
        playerShadow.position = CGPoint(x: 0, y: -30 * contentScale)
        playerShadow.zPosition = -1
        player.addChild(playerShadow)

        playerGlow = SKSpriteNode(texture: glowTexture(color: .cyan, diameter: 140))
        playerGlow.size = CGSize(width: 110 * contentScale, height: 110 * contentScale)
        playerGlow.zPosition = -0.5
        player.addChild(playerGlow)
        playerGlow.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.7),
                SKAction.scale(to: 1.0, duration: 0.7)
            ])
        ))

        if let sprite = loadSprite(named: SpriteName.player) {
            playerCore = sprite
        } else {
            playerCore = SKSpriteNode(texture: playerTexture())
        }
        playerCore.size = CGSize(width: 48 * contentScale, height: 48 * contentScale)
        player.addChild(playerCore)

        playerCore.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.moveBy(x: 0, y: 4, duration: 0.22),
                SKAction.moveBy(x: 0, y: -4, duration: 0.22)
            ])
        ), withKey: "bob")

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 48 * contentScale, height: 48 * contentScale))
        body.isDynamic = true
        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.ram | PhysicsCategory.powerUp
            | PhysicsCategory.projectile | PhysicsCategory.jigarBody
        body.collisionBitMask = PhysicsCategory.none
        player.physicsBody = body
    }

    // =================================================================
    // MARK: - Jigar
    // =================================================================

    private func setupJigar() {
        jigar = SKNode()
        jigar.name = "jigar"
        jigar.position = CGPoint(x: lanes[currentLane], y: playerBaseY - maxVisualGap)
        jigar.zPosition = 15
        worldNode.addChild(jigar)

        jigarGlow = SKSpriteNode(texture: glowTexture(color: .red, diameter: 160))
        jigarGlow.size = CGSize(width: 130 * contentScale, height: 130 * contentScale)
        jigarGlow.zPosition = -0.5
        jigar.addChild(jigarGlow)
        jigarGlow.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
        ))

        if let sprite = loadSprite(named: SpriteName.jigar) {
            jigarCore = sprite
        } else {
            jigarCore = SKSpriteNode(texture: jigarTexture())
        }
        jigarCore.size = CGSize(width: 68 * contentScale, height: 68 * contentScale)
        jigar.addChild(jigarCore)

        jigarCore.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.rotate(byAngle: 0.06, duration: 0.15),
                SKAction.rotate(byAngle: -0.12, duration: 0.3),
                SKAction.rotate(byAngle: 0.06, duration: 0.15)
            ])
        ), withKey: "menace")

        // Real physics body on Jigar itself: touching it is now a
        // distinct, instant-death event, separate from the Health bar.
        let body = SKPhysicsBody(circleOfRadius: 26 * contentScale)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.jigarBody
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        jigar.physicsBody = body
    }

    private func applyEquippedSkins() {
        let meta = MetaProgress.shared
        let pSkin = playerSkins.first(where: { $0.id == meta.equippedPlayerSkin }) ?? playerSkins[0]
        let jSkin = jigarSkins.first(where: { $0.id == meta.equippedJigarSkin }) ?? jigarSkins[0]

        playerCore.color = pSkin.color
        playerCore.colorBlendFactor = pSkin.id == "default" ? 0 : 0.6
        playerGlow.texture = glowTexture(color: pSkin.color, diameter: 140)

        jigarCore.color = jSkin.color
        jigarCore.colorBlendFactor = jSkin.id == "default" ? 0 : 0.6
        jigarGlow.texture = glowTexture(color: jSkin.color, diameter: 160)
    }

    // =================================================================
    // MARK: - Sprite Loader (optional external assets)
    // =================================================================

    private func loadSprite(named name: String) -> SKSpriteNode? {
        guard let image = UIImage(named: name) else { return nil }
        return SKSpriteNode(texture: SKTexture(image: image))
    }

    // =================================================================
    // MARK: - In-Run UI
    // =================================================================

    private func setupUI() {
        ramLabel = makeLabel(text: "RAM 0 / 10", size: 20, color: .white)
        ramLabel.horizontalAlignmentMode = .left
        ramLabel.position = CGPoint(x: -size.width / 2 + 24, y: size.height / 2 - 50)
        uiNode.addChild(ramLabel)

        ramProgressBar = roundedBar(width: 130, height: 10, color: UIColor.white.withAlphaComponent(0.12))
        ramProgressBar.position = CGPoint(x: -size.width / 2 + 24 + 65, y: size.height / 2 - 68)
        uiNode.addChild(ramProgressBar)

        ramProgressFill = roundedBar(width: 130, height: 10, color: UIColor(red: 0.3, green: 1.0, blue: 0.45, alpha: 1))
        ramProgressFill.position = ramProgressBar.position
        ramProgressFill.xScale = 0
        uiNode.addChild(ramProgressFill)

        // --- Vertical Jigar Health bar, top-right ---
        let barX = size.width / 2 - 30
        let barTopY = size.height / 2 - 60

        jigarHealthTitle = makeLabel(text: "JIGAR", size: 12, color: .red)
        jigarHealthTitle.position = CGPoint(x: barX, y: barTopY + 14)
        uiNode.addChild(jigarHealthTitle)

        jigarHealthBarBack = SKShapeNode(rectOf: CGSize(width: 18, height: jigarHealthBarHeight), cornerRadius: 9)
        jigarHealthBarBack.fillColor = UIColor.white.withAlphaComponent(0.12)
        jigarHealthBarBack.strokeColor = UIColor.white.withAlphaComponent(0.25)
        jigarHealthBarBack.position = CGPoint(x: barX, y: barTopY - jigarHealthBarHeight / 2)
        uiNode.addChild(jigarHealthBarBack)

        jigarHealthBarFill = SKShapeNode(rectOf: CGSize(width: 18, height: jigarHealthBarHeight), cornerRadius: 9)
        jigarHealthBarFill.fillColor = .green
        jigarHealthBarFill.strokeColor = .clear
        jigarHealthBarFill.position = jigarHealthBarBack.position
        uiNode.addChild(jigarHealthBarFill)

        jigarHealthValueLabel = makeLabel(text: "100", size: 12, color: .white)
        jigarHealthValueLabel.position = CGPoint(x: barX, y: barTopY - jigarHealthBarHeight - 16)
        uiNode.addChild(jigarHealthValueLabel)

        comboLabel = makeLabel(text: "", size: 16, color: .yellow)
        comboLabel.position = CGPoint(x: 0, y: 60)
        comboLabel.isHidden = true
        uiNode.addChild(comboLabel)

        powerUpBadge = SKNode()
        powerUpBadge.position = CGPoint(x: 0, y: -size.height / 2 + 55)
        powerUpBadge.isHidden = true
        uiNode.addChild(powerUpBadge)

        let pill = SKShapeNode(rectOf: CGSize(width: 230, height: 40), cornerRadius: 20)
        pill.fillColor = UIColor.black.withAlphaComponent(0.45)
        pill.strokeColor = UIColor.white.withAlphaComponent(0.25)
        pill.lineWidth = 1
        powerUpBadge.addChild(pill)

        powerUpIconLabel = SKLabelNode(text: "⚡")
        powerUpIconLabel.fontSize = 20
        powerUpIconLabel.verticalAlignmentMode = .center
        powerUpIconLabel.position = CGPoint(x: -95, y: 0)
        powerUpBadge.addChild(powerUpIconLabel)

        powerUpTextLabel = makeLabel(text: "", size: 14, color: .cyan)
        powerUpTextLabel.horizontalAlignmentMode = .left
        powerUpTextLabel.verticalAlignmentMode = .center
        powerUpTextLabel.position = CGPoint(x: -75, y: 0)
        powerUpBadge.addChild(powerUpTextLabel)

        let swipeHint = makeLabel(text: "SWIPE ↑", size: 11, color: .white)
        swipeHint.alpha = 0.7
        swipeHint.horizontalAlignmentMode = .right
        swipeHint.verticalAlignmentMode = .center
        swipeHint.position = CGPoint(x: 100, y: 0)
        powerUpBadge.addChild(swipeHint)

        powerUpBadge.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.scale(to: 1.04, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
        ))

        // Pause button moved to top-left (top-right is now the Health bar).
        pauseButton = SKShapeNode(circleOfRadius: 18)
        pauseButton.fillColor = UIColor.black.withAlphaComponent(0.35)
        pauseButton.strokeColor = UIColor.white.withAlphaComponent(0.4)
        pauseButton.position = CGPoint(x: -size.width / 2 + 34, y: size.height / 2 - 100)
        pauseButton.name = "pauseButton"
        pauseButton.isHidden = true
        uiNode.addChild(pauseButton)

        let bar1 = SKShapeNode(rectOf: CGSize(width: 4, height: 14), cornerRadius: 1)
        bar1.fillColor = .white
        bar1.strokeColor = .clear
        bar1.position = CGPoint(x: -4, y: 0)
        pauseButton.addChild(bar1)
        let bar2 = bar1.copy() as! SKShapeNode
        bar2.position = CGPoint(x: 4, y: 0)
        pauseButton.addChild(bar2)

        updateUI()
    }

    private func roundedBar(width: CGFloat, height: CGFloat, color: UIColor) -> SKShapeNode {
        let bar = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        bar.fillColor = color
        bar.strokeColor = .clear
        return bar
    }

    private func updateUI() {
        guard ramLabel != nil else { return }

        ramLabel.text = "RAM  \(ramCount) / \(ramNeededForPowerUp)"

        let previousThreshold = ramNeededForPowerUp - 10
        let progress = CGFloat(ramCount - previousThreshold) / 10.0
        let clamped = max(0, min(progress, 1))
        ramProgressFill.run(SKAction.scaleX(to: clamped, duration: 0.2))

        updateJigarHealthBar()

        if let powerUp = availablePowerUp {
            powerUpIconLabel.text = powerUp.glyph
            powerUpTextLabel.text = powerUp.displayName
            powerUpTextLabel.fontColor = powerUp.color
            powerUpBadge.isHidden = false
        } else {
            powerUpBadge.isHidden = true
        }
    }

    /// Updates the vertical Health bar. Full (100) = green/safe,
    /// empty (0) = red/caught. The fill shrinks from the bar's
    /// center, matching the style of the other progress bars.
    private func updateJigarHealthBar() {
        guard jigarHealthBarFill != nil else { return }

        let healthFraction = max(0, min(jigarHealth / 100, 1))
        jigarHealthBarFill.run(SKAction.scaleY(to: max(0.02, healthFraction), duration: 0.1))

        let danger = 1 - healthFraction
        jigarHealthBarFill.fillColor = dangerColor(for: danger)

        jigarHealthValueLabel.text = "\(Int(jigarHealth))"
        jigarHealthValueLabel.fontColor = danger > 0.75
            ? UIColor(red: 1, green: 0.25, blue: 0.25, alpha: 1)
            : .white
    }

    private func dangerColor(for t: CGFloat) -> UIColor {
        if t < 0.5 {
            return blend(UIColor(red: 0.3, green: 1.0, blue: 0.4, alpha: 1),
                          UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1), t / 0.5)
        } else {
            return blend(UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1),
                          UIColor(red: 1.0, green: 0.2, blue: 0.25, alpha: 1), (t - 0.5) / 0.5)
        }
    }

    private func blend(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
    }

    private func makeLabel(text: String, size: CGFloat, color: UIColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        return label
    }

    private func makeButton(text: String, name: String, width: CGFloat, height: CGFloat = 52,
                             fill: UIColor, textColor: UIColor = .white, fontSize: CGFloat = 18) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        button.fillColor = fill
        button.strokeColor = UIColor.white.withAlphaComponent(0.35)
        button.lineWidth = 1.5
        button.name = name

        let label = makeLabel(text: text, size: fontSize, color: textColor)
        label.verticalAlignmentMode = .center
        label.name = name
        button.addChild(label)

        return button
    }

    // =================================================================
    // MARK: - Main Menu
    // =================================================================

    private func buildMenuContent() {
        menuNode.removeAllChildren()
        let meta = MetaProgress.shared

        let panel = SKShapeNode(rectOf: CGSize(width: size.width - 36, height: 460), cornerRadius: 26)
        panel.fillColor = UIColor.black.withAlphaComponent(0.42)
        panel.strokeColor = UIColor.cyan.withAlphaComponent(0.25)
        panel.lineWidth = 1.5
        menuNode.addChild(panel)

        let title = makeLabel(text: "RUN FROM JIGAR", size: 30, color: .white)
        title.position = CGPoint(x: 0, y: 195)
        menuNode.addChild(title)
        title.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.colorize(with: .cyan, colorBlendFactor: 0.5, duration: 1.2),
                SKAction.colorize(with: .white, colorBlendFactor: 0, duration: 1.2)
            ])
        ))

        let subtitle = makeLabel(text: "STEAL BACK THE RAM", size: 14, color: .green)
        subtitle.position = CGPoint(x: 0, y: 168)
        menuNode.addChild(subtitle)

        let pSkin = playerSkins.first(where: { $0.id == meta.equippedPlayerSkin }) ?? playerSkins[0]
        let jSkin = jigarSkins.first(where: { $0.id == meta.equippedJigarSkin }) ?? jigarSkins[0]

        let previewPlayer = SKSpriteNode(texture: playerTexture())
        previewPlayer.size = CGSize(width: 54, height: 54)
        previewPlayer.color = pSkin.color
        previewPlayer.colorBlendFactor = pSkin.id == "default" ? 0 : 0.6
        previewPlayer.position = CGPoint(x: -45, y: 110)
        menuNode.addChild(previewPlayer)

        let previewJigar = SKSpriteNode(texture: jigarTexture())
        previewJigar.size = CGSize(width: 62, height: 62)
        previewJigar.color = jSkin.color
        previewJigar.colorBlendFactor = jSkin.id == "default" ? 0 : 0.6
        previewJigar.position = CGPoint(x: 45, y: 110)
        menuNode.addChild(previewJigar)

        let statsY: CGFloat = 55
        addStat(to: menuNode, title: "LEVEL", value: "\(meta.level)", x: -100, y: statsY, color: .cyan)
        addStat(to: menuNode, title: "TOTAL RAM", value: "\(meta.totalRAM)", x: 0, y: statsY, color: .green)
        addStat(to: menuNode, title: "BEST RUN", value: "\(meta.bestRun)", x: 100, y: statsY, color: .yellow)

        let levelBarBack = roundedBar(width: 220, height: 8, color: UIColor.white.withAlphaComponent(0.12))
        levelBarBack.position = CGPoint(x: 0, y: statsY - 30)
        menuNode.addChild(levelBarBack)
        let levelBarFill = roundedBar(width: 220, height: 8, color: .cyan)
        levelBarFill.position = levelBarBack.position
        levelBarFill.xScale = max(0.02, meta.levelProgress)
        menuNode.addChild(levelBarFill)

        let playButton = makeButton(text: "▶  PLAY", name: "menuPlay", width: 240,
                                     fill: UIColor(red: 0.15, green: 0.75, blue: 0.35, alpha: 0.9))
        playButton.position = CGPoint(x: 0, y: -30)
        menuNode.addChild(playButton)

        let garageButton = makeButton(text: "🎨  GARAGE (SKINS & SHOP)", name: "menuGarage", width: 240,
                                       fill: UIColor(red: 0.55, green: 0.2, blue: 0.85, alpha: 0.9), fontSize: 14)
        garageButton.position = CGPoint(x: 0, y: -95)
        menuNode.addChild(garageButton)

        let howToButton = makeButton(text: "❓  HOW TO PLAY", name: "menuHowTo", width: 240,
                                      fill: UIColor.white.withAlphaComponent(0.12), fontSize: 15)
        howToButton.position = CGPoint(x: 0, y: -160)
        menuNode.addChild(howToButton)
    }

    private func addStat(to parent: SKNode, title: String, value: String, x: CGFloat, y: CGFloat, color: UIColor) {
        let valueLabel = makeLabel(text: value, size: 22, color: color)
        valueLabel.position = CGPoint(x: x, y: y)
        parent.addChild(valueLabel)

        let titleLabel = makeLabel(text: title, size: 10, color: .white)
        titleLabel.alpha = 0.6
        titleLabel.position = CGPoint(x: x, y: y - 20)
        parent.addChild(titleLabel)
    }

    // =================================================================
    // MARK: - Garage (Customize + Shop)
    // =================================================================

    private func buildGarageContent() {
        garageNode.removeAllChildren()
        let meta = MetaProgress.shared

        let panel = SKShapeNode(rectOf: CGSize(width: size.width - 24, height: 520), cornerRadius: 26)
        panel.fillColor = UIColor.black.withAlphaComponent(0.5)
        panel.strokeColor = UIColor.purple.withAlphaComponent(0.3)
        panel.lineWidth = 1.5
        garageNode.addChild(panel)

        let title = makeLabel(text: "GARAGE", size: 26, color: .white)
        title.position = CGPoint(x: 0, y: 235)
        garageNode.addChild(title)

        let ramBalance = makeLabel(text: "💰 \(meta.totalRAM) RAM", size: 16, color: .green)
        ramBalance.position = CGPoint(x: 0, y: 205)
        garageNode.addChild(ramBalance)

        let hint = makeLabel(text: "TAP TO EQUIP · LOCKED = TAP TO BUY", size: 10, color: .white)
        hint.alpha = 0.55
        hint.position = CGPoint(x: 0, y: 185)
        garageNode.addChild(hint)

        let runnerLabel = makeLabel(text: "RUNNER SKINS", size: 14, color: .cyan)
        runnerLabel.position = CGPoint(x: 0, y: 140)
        garageNode.addChild(runnerLabel)
        buildSkinRow(skins: playerSkins,
                     unlocked: meta.unlockedPlayerSkins,
                     equipped: meta.equippedPlayerSkin,
                     namePrefix: "playerSkin_",
                     y: 90)

        let jigarLabel = makeLabel(text: "VIRUS SKINS", size: 14, color: .red)
        jigarLabel.position = CGPoint(x: 0, y: 15)
        garageNode.addChild(jigarLabel)
        buildSkinRow(skins: jigarSkins,
                     unlocked: meta.unlockedJigarSkins,
                     equipped: meta.equippedJigarSkin,
                     namePrefix: "jigarSkin_",
                     y: -35)

        let warning = makeLabel(text: "NOT ENOUGH RAM", size: 14, color: .red)
        warning.name = "garageWarning"
        warning.alpha = 0
        warning.position = CGPoint(x: 0, y: -110)
        garageNode.addChild(warning)

        let backButton = makeButton(text: "◀  BACK TO MENU", name: "garageBack", width: 220,
                                     fill: UIColor.white.withAlphaComponent(0.12), fontSize: 15)
        backButton.position = CGPoint(x: 0, y: -220)
        garageNode.addChild(backButton)
    }

    private func buildSkinRow(skins: [SkinOption], unlocked: Set<String>, equipped: String, namePrefix: String, y: CGFloat) {
        let spacing: CGFloat = 62
        let startX = -CGFloat(skins.count - 1) * spacing / 2

        for (index, skin) in skins.enumerated() {
            let x = startX + CGFloat(index) * spacing
            let isUnlocked = unlocked.contains(skin.id)
            let isEquipped = skin.id == equipped

            let swatch = SKShapeNode(circleOfRadius: 24)
            swatch.name = namePrefix + skin.id
            swatch.fillColor = isUnlocked ? skin.color : skin.color.withAlphaComponent(0.25)
            swatch.strokeColor = isEquipped ? .white : UIColor.white.withAlphaComponent(0.2)
            swatch.lineWidth = isEquipped ? 3 : 1
            swatch.position = CGPoint(x: x, y: y)
            garageNode.addChild(swatch)

            if isEquipped {
                let check = makeLabel(text: "✓", size: 18, color: .white)
                check.name = namePrefix + skin.id
                check.verticalAlignmentMode = .center
                check.position = CGPoint(x: x, y: y)
                garageNode.addChild(check)
            } else if !isUnlocked {
                let lock = makeLabel(text: "🔒", size: 14, color: .white)
                lock.name = namePrefix + skin.id
                lock.verticalAlignmentMode = .center
                lock.position = CGPoint(x: x, y: y)
                garageNode.addChild(lock)
            }

            if !isUnlocked {
                let costLabel = makeLabel(text: "\(skin.cost)", size: 10, color: .yellow)
                costLabel.name = namePrefix + skin.id
                costLabel.position = CGPoint(x: x, y: y - 36)
                garageNode.addChild(costLabel)
            }
        }
    }

    private func selectPlayerSkin(_ id: String) {
        guard let skin = playerSkins.first(where: { $0.id == id }) else { return }
        let meta = MetaProgress.shared

        if meta.unlockedPlayerSkins.contains(id) {
            meta.equippedPlayerSkin = id
            applyEquippedSkins()
            buildGarageContent()
        } else if meta.totalRAM >= skin.cost {
            meta.totalRAM -= skin.cost
            meta.unlockPlayerSkin(id)
            meta.equippedPlayerSkin = id
            applyEquippedSkins()
            buildGarageContent()
        } else {
            flashInsufficientFunds()
        }
    }

    private func selectJigarSkin(_ id: String) {
        guard let skin = jigarSkins.first(where: { $0.id == id }) else { return }
        let meta = MetaProgress.shared

        if meta.unlockedJigarSkins.contains(id) {
            meta.equippedJigarSkin = id
            applyEquippedSkins()
            buildGarageContent()
        } else if meta.totalRAM >= skin.cost {
            meta.totalRAM -= skin.cost
            meta.unlockJigarSkin(id)
            meta.equippedJigarSkin = id
            applyEquippedSkins()
            buildGarageContent()
        } else {
            flashInsufficientFunds()
        }
    }

    private func flashInsufficientFunds() {
        guard let warning = garageNode.childNode(withName: "garageWarning") else { return }
        warning.removeAllActions()
        warning.alpha = 1
        warning.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.9),
            SKAction.fadeOut(withDuration: 0.3)
        ]))
    }

    // =================================================================
    // MARK: - Tutorial
    // =================================================================

    private func setupTutorial() {
        tutorialNode = SKNode()
        tutorialNode.zPosition = 210
        uiNode.addChild(tutorialNode)

        let panel = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 400), cornerRadius: 24)
        panel.fillColor = UIColor.black.withAlphaComponent(0.4)
        panel.strokeColor = UIColor.cyan.withAlphaComponent(0.25)
        panel.lineWidth = 1.5
        tutorialNode.addChild(panel)

        let title = makeLabel(text: "HOW TO PLAY", size: 28, color: .white)
        title.position = CGPoint(x: 0, y: 160)
        tutorialNode.addChild(title)

        let lines: [(String, UIColor, CGFloat)] = [
            ("🧠 COLLECT RAM CHIPS", .green, 105),
            ("⚡ EVERY 10 RAM = A RANDOM POWER-UP", .white, 70),
            ("↔️ SWIPE LEFT / RIGHT TO CHANGE LANES", .cyan, 35),
            ("⬆️ SWIPE UP TO USE YOUR POWER-UP", .yellow, 0),
            ("🦠 TOUCHING THE VIRUS = INSTANT DEFEAT", .red, -35),
            ("⚠️ IT ALSO FIRES SHOTS (4-15 DMG) — DODGE THEM", .orange, -70),
            ("💚 YOUR HEALTH BAR IS TOP-RIGHT, OUT OF 100", .green, -105)
        ]
        for (text, color, y) in lines {
            let label = makeLabel(text: text, size: 12.5, color: color)
            label.position = CGPoint(x: 0, y: y)
            tutorialNode.addChild(label)
        }

        let start = makeLabel(text: "[ SWIPE UP TO START ]", size: 18, color: .green)
        start.position = CGPoint(x: 0, y: -170)
        tutorialNode.addChild(start)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        ])
        start.run(SKAction.repeatForever(pulse))
    }

    // =================================================================
    // MARK: - Game Over UI
    // =================================================================

    private func setupGameOver() {
        gameOverNode = SKNode()
        gameOverNode.zPosition = 210
        uiNode.addChild(gameOverNode)

        let panel = SKShapeNode(rectOf: CGSize(width: size.width - 60, height: 300), cornerRadius: 24)
        panel.fillColor = UIColor.black.withAlphaComponent(0.55)
        panel.strokeColor = UIColor.red.withAlphaComponent(0.35)
        panel.lineWidth = 1.5
        gameOverNode.addChild(panel)

        let title = makeLabel(text: "JIGAR CAUGHT YOU", size: 26, color: .red)
        title.name = "gameOverTitle"
        title.position = CGPoint(x: 0, y: 105)
        gameOverNode.addChild(title)

        let score = makeLabel(text: "", size: 20, color: .green)
        score.name = "finalScore"
        score.position = CGPoint(x: 0, y: 60)
        gameOverNode.addChild(score)

        let banked = makeLabel(text: "", size: 14, color: .cyan)
        banked.name = "bankedRAM"
        banked.position = CGPoint(x: 0, y: 32)
        gameOverNode.addChild(banked)

        let best = makeLabel(text: "", size: 16, color: .white)
        best.name = "finalBest"
        best.position = CGPoint(x: 0, y: 2)
        gameOverNode.addChild(best)

        let newBest = makeLabel(text: "🏆 NEW BEST!", size: 15, color: .yellow)
        newBest.name = "newBest"
        newBest.position = CGPoint(x: 0, y: -26)
        newBest.isHidden = true
        gameOverNode.addChild(newBest)

        let restart = makeLabel(text: "[ SWIPE UP TO RUN AGAIN ]", size: 15, color: .white)
        restart.position = CGPoint(x: 0, y: -85)
        gameOverNode.addChild(restart)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
        restart.run(SKAction.repeatForever(pulse))

        let menuButton = makeButton(text: "MENU", name: "gameOverMenu", width: 140, height: 40,
                                     fill: UIColor.white.withAlphaComponent(0.12), fontSize: 14)
        menuButton.position = CGPoint(x: 0, y: -130)
        gameOverNode.addChild(menuButton)
    }

    // =================================================================
    // MARK: - Pause Overlay
    // =================================================================

    private func setupPauseOverlay() {
        pauseNode = SKNode()
        pauseNode.isHidden = true
        pauseNode.zPosition = 300
        uiNode.addChild(pauseNode)

        let dim = SKShapeNode(rectOf: CGSize(width: size.width + 40, height: size.height + 40))
        dim.fillColor = UIColor.black.withAlphaComponent(0.6)
        dim.strokeColor = .clear
        pauseNode.addChild(dim)

        let title = makeLabel(text: "PAUSED", size: 30, color: .white)
        title.position = CGPoint(x: 0, y: 40)
        pauseNode.addChild(title)

        let resume = makeLabel(text: "[ TAP TO RESUME ]", size: 16, color: .cyan)
        resume.position = CGPoint(x: 0, y: -10)
        pauseNode.addChild(resume)
    }

    // =================================================================
    // MARK: - Reset Game
    // =================================================================

    private func resetGame() {
        removeAllGameObjects()

        ramCount = 0
        ramNeededForPowerUp = 10
        comboCount = 0
        availablePowerUp = nil
        powerUpActive = false

        jigarHealth = startingJigarHealth
        jigarFrozen = false
        jigarShielded = false

        currentLane = 1
        gameSpeed = 1.0

        player.alpha = 1
        jigar.alpha = 1

        player.position = CGPoint(x: lanes[currentLane], y: playerBaseY)
        jigar.position = CGPoint(x: lanes[currentLane], y: playerBaseY - maxVisualGap)

        physicsWorld.speed = 1
        worldNode.isPaused = false

        applyEquippedSkins()
        updateUI()
        startGameLoops()
    }

    // =================================================================
    // MARK: - Game Loops
    // =================================================================

    private func startGameLoops() {
        stopGame()

        let spawn = SKAction.run { [weak self] in self?.spawnRAM() }
        let wait = SKAction.wait(forDuration: 0.85)
        run(SKAction.repeatForever(SKAction.sequence([spawn, wait])), withKey: "gameLoop")

        let jigarUpdate = SKAction.run { [weak self] in self?.updateJigar() }
        let jigarWait = SKAction.wait(forDuration: 0.1)
        run(SKAction.repeatForever(SKAction.sequence([jigarUpdate, jigarWait])), withKey: "jigarLoop")

        scheduleNextJigarShot()
    }

    // =================================================================
    // MARK: - Spawn RAM
    // =================================================================

    private func spawnRAM() {
        guard gameState == .playing else { return }
        guard let lane = lanes.randomElement() else { return }

        let ram: SKSpriteNode
        if let sprite = loadSprite(named: SpriteName.ram) {
            ram = sprite
        } else {
            ram = SKSpriteNode(texture: ramTexture())
        }
        ram.size = CGSize(width: 32 * contentScale, height: 32 * contentScale)

        ram.name = "ram"
        ram.position = CGPoint(x: lane, y: size.height / 2 + 40)
        ram.zPosition = 10
        worldNode.addChild(ram)

        ram.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 2.2)))

        let body = SKPhysicsBody(circleOfRadius: 14 * contentScale)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ram
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        ram.physicsBody = body

        ramNodes.append(ram)

        let duration = TimeInterval(3.2 / gameSpeed)
        let moveDown = SKAction.moveTo(y: -size.height / 2 - 50, duration: duration)
        let remove = SKAction.run { [weak self, weak ram] in
            guard let self = self, let ram = ram else { return }
            self.ramNodes.removeAll { $0 === ram }
            ram.removeFromParent()
        }
        ram.run(SKAction.sequence([moveDown, remove]))
    }

    // =================================================================
    // MARK: - Jigar Chase (Health drain)
    // =================================================================

    private func updateJigar() {
        guard gameState == .playing else { return }

        if !jigarFrozen {
            let pressure = CGFloat.random(in: 0.1...0.32)
            jigarHealth -= pressure
            jigarHealth += 0.03 // tiny breathing room, same feel as before
        }

        jigarHealth = max(0, min(jigarHealth, 100))

        let visualGap = (jigarHealth / 100) * maxVisualGap
        let targetPosition = CGPoint(x: player.position.x, y: playerBaseY - visualGap)
        jigar.run(SKAction.move(to: targetPosition, duration: 0.1), withKey: "jigarMovement")

        updateUI()

        if jigarHealth <= 0 {
            if jigarShielded {
                jigarHealth = 20
                flashShieldBlock()
            } else {
                triggerGameOver(reason: "JIGAR CAUGHT YOU")
            }
        }
    }

    private func flashShieldBlock() {
        let flash = SKShapeNode(circleOfRadius: 50)
        flash.fillColor = .clear
        flash.strokeColor = .cyan
        flash.lineWidth = 4
        flash.position = player.position
        flash.zPosition = 80
        worldNode.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3)
            ]),
            SKAction.removeFromParent()
        ]))
        shakeScreen(intensity: 6, duration: 0.15)
    }

    // =================================================================
    // MARK: - Jigar Ranged Attack (chip damage, 4-15 per hit)
    // =================================================================

    private func scheduleNextJigarShot() {
        guard gameState == .playing else { return }
        let delay = Double.random(in: 2.5...5.0)
        run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run { [weak self] in self?.telegraphAndShoot() }
        ]), withKey: "jigarShotScheduler")
    }

    private func telegraphAndShoot() {
        guard gameState == .playing else { return }

        guard !jigarFrozen else {
            scheduleNextJigarShot()
            return
        }

        let laneX = jigar.position.x

        let warning = makeLabel(text: "⚠️", size: 26, color: .orange)
        warning.position = CGPoint(x: laneX, y: size.height / 2 - 110)
        warning.zPosition = 90
        worldNode.addChild(warning)
        warning.run(SKAction.sequence([
            SKAction.repeat(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.2, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ]), count: 2),
            SKAction.removeFromParent()
        ]))

        jigarCore.run(SKAction.sequence([
            SKAction.run { [weak self] in
                self?.jigarCore.color = .white
                self?.jigarCore.colorBlendFactor = 0.85
            },
            SKAction.wait(forDuration: 0.2),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                let jSkin = jigarSkins.first(where: { $0.id == MetaProgress.shared.equippedJigarSkin }) ?? jigarSkins[0]
                self.jigarCore.color = jSkin.color
                self.jigarCore.colorBlendFactor = jSkin.id == "default" ? 0 : 0.6
            }
        ]))

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.45),
            SKAction.run { [weak self] in self?.fireJigarProjectile(laneX: laneX) }
        ]))

        scheduleNextJigarShot()
    }

    private func fireJigarProjectile(laneX: CGFloat) {
        guard gameState == .playing else { return }

        let projectile = SKShapeNode(circleOfRadius: 9 * contentScale)
        projectile.name = "jigarProjectile"
        projectile.fillColor = UIColor(red: 1, green: 0.25, blue: 0.25, alpha: 1)
        projectile.strokeColor = .white
        projectile.lineWidth = 1.5
        projectile.glowWidth = 5
        projectile.zPosition = 16
        projectile.position = CGPoint(x: laneX, y: jigar.position.y + 25 * contentScale)
        worldNode.addChild(projectile)

        let body = SKPhysicsBody(circleOfRadius: 9 * contentScale)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.projectile
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody = body

        let travel = SKAction.moveTo(y: size.height / 2 + 60, duration: 0.85)
        let cleanup = SKAction.run { [weak projectile] in projectile?.removeFromParent() }
        projectile.run(SKAction.sequence([travel, cleanup]))
    }

    /// A ranged hit chips a random 4–15 off the Health bar. It does
    /// NOT instantly end the run — only a direct touch (see
    /// didBegin/"jigar") or the bar hitting 0 does that.
    private func handleProjectileHit(_ projectile: SKNode) {
        projectile.removeFromParent()

        if jigarShielded {
            flashShieldBlock()
            return
        }

        let damage = CGFloat(Int.random(in: 4...15))
        jigarHealth = max(0, jigarHealth - damage)
        showDamageNumber(damage)
        updateUI()

        if jigarHealth <= 0 {
            triggerGameOver(reason: "JIGAR CAUGHT YOU")
        }
    }

    private func showDamageNumber(_ amount: CGFloat) {
        let label = makeLabel(text: "-\(Int(amount))", size: 16, color: .red)
        label.position = CGPoint(x: size.width / 2 - 30, y: size.height / 2 - 60)
        label.zPosition = 220
        uiNode.addChild(label)
        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 20, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // =================================================================
    // MARK: - Power-Up Checking
    // =================================================================

    private func checkForPowerUp() {
        guard availablePowerUp == nil else { return }
        if ramCount >= ramNeededForPowerUp {
            giveRandomPowerUp()
            ramNeededForPowerUp += 10
        }
    }

    private func giveRandomPowerUp() {
        guard let powerUp = PowerUp.allCases.randomElement() else { return }
        availablePowerUp = powerUp
        showPowerUpNotification(powerUp)
        updateUI()
    }

    private func showPowerUpNotification(_ powerUp: PowerUp) {
        let container = SKNode()
        container.position = CGPoint(x: 0, y: 30)
        container.zPosition = 100
        container.setScale(0.6)
        uiNode.addChild(container)

        let badge = SKShapeNode(rectOf: CGSize(width: 260, height: 50), cornerRadius: 24)
        badge.fillColor = UIColor.black.withAlphaComponent(0.55)
        badge.strokeColor = powerUp.color
        badge.lineWidth = 2
        container.addChild(badge)

        let icon = SKLabelNode(text: powerUp.glyph)
        icon.fontSize = 24
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: -95, y: 0)
        container.addChild(icon)

        let notification = makeLabel(text: powerUp.displayName, size: 18, color: powerUp.color)
        notification.horizontalAlignmentMode = .left
        notification.verticalAlignmentMode = .center
        notification.position = CGPoint(x: -70, y: 0)
        container.addChild(notification)

        container.run(SKAction.sequence([
            SKAction.scale(to: 1.0, duration: 0.25),
            SKAction.wait(forDuration: 1.1),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.35),
                SKAction.moveBy(x: 0, y: 20, duration: 0.35)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // =================================================================
    // MARK: - Use Power-Up
    // =================================================================

    private func usePowerUp() {
        guard gameState == .playing else { return }
        guard !powerUpActive else { return }
        guard let powerUp = availablePowerUp else { return }

        availablePowerUp = nil
        powerUpActive = true
        updateUI()

        switch powerUp {
        case .speedBoost:  activateSpeedBoost()
        case .ramMagnet:   activateRAMMagnet()
        case .shield:      activateShield()
        case .jigarAttack: activateJigarAttack()
        case .freezeJigar: activateFreezeJigar()
        }
    }

    private func activateSpeedBoost() {
        gameSpeed = 2.0

        let trail = SKAction.repeat(SKAction.sequence([
            SKAction.run { [weak self] in self?.spawnSpeedTrail() },
            SKAction.wait(forDuration: 0.05)
        ]), count: 100)
        player.run(trail, withKey: "speedTrail")

        player.run(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.15),
            SKAction.wait(forDuration: 5),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])) { [weak self] in
            guard let self = self else { return }
            self.gameSpeed = 1.0
            self.powerUpActive = false
            self.player.removeAction(forKey: "speedTrail")
        }
    }

    private func spawnSpeedTrail() {
        guard gameState == .playing else { return }
        let ghost = SKSpriteNode(texture: playerCore.texture)
        ghost.size = playerCore.size
        ghost.position = player.position
        ghost.alpha = 0.35
        ghost.color = .cyan
        ghost.colorBlendFactor = 0.6
        ghost.zPosition = 18
        worldNode.addChild(ghost)
        ghost.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.3), SKAction.removeFromParent()]))
    }

    private func activateRAMMagnet() {
        for ram in ramNodes where ram.parent != nil {
            ram.run(SKAction.move(to: player.position, duration: 0.5))
            let sparkle = SKShapeNode(circleOfRadius: 3)
            sparkle.fillColor = .green
            sparkle.strokeColor = .clear
            sparkle.position = ram.position
            worldNode.addChild(sparkle)
            sparkle.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.5), SKAction.removeFromParent()]))
        }
        run(SKAction.wait(forDuration: 2)) { [weak self] in
            self?.powerUpActive = false
        }
    }

    private func activateShield() {
        jigarShielded = true

        let shield = SKShapeNode(circleOfRadius: 38)
        shield.name = "playerShield"
        shield.strokeColor = .cyan
        shield.lineWidth = 4
        shield.fillColor = UIColor.cyan.withAlphaComponent(0.15)
        shield.zPosition = -1
        shield.glowWidth = 6
        player.addChild(shield)

        shield.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        ])))

        run(SKAction.sequence([
            SKAction.wait(forDuration: 6),
            SKAction.run { [weak self, weak shield] in
                self?.jigarShielded = false
                shield?.removeFromParent()
                self?.powerUpActive = false
            }
        ]))
    }

    private func activateJigarAttack() {
        jigarHealth = min(jigarHealth + 25, 100)

        jigar.run(SKAction.sequence([
            SKAction.run { [weak self] in
                self?.jigarCore.color = .white
                self?.jigarCore.colorBlendFactor = 1.0
            },
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                let jSkin = jigarSkins.first(where: { $0.id == MetaProgress.shared.equippedJigarSkin }) ?? jigarSkins[0]
                self.jigarCore.color = jSkin.color
                self.jigarCore.colorBlendFactor = jSkin.id == "default" ? 0 : 0.6
            }
        ]))

        shakeScreen(intensity: 14, duration: 0.25)

        run(SKAction.wait(forDuration: 0.5)) { [weak self] in
            self?.powerUpActive = false
        }

        updateUI()
    }

    private func activateFreezeJigar() {
        jigarFrozen = true
        jigar.alpha = 0.45
        jigarCore.color = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1)
        jigarCore.colorBlendFactor = 0.6

        run(SKAction.sequence([
            SKAction.wait(forDuration: 5),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.jigarFrozen = false
                self.jigar.alpha = 1.0
                let jSkin = jigarSkins.first(where: { $0.id == MetaProgress.shared.equippedJigarSkin }) ?? jigarSkins[0]
                self.jigarCore.color = jSkin.color
                self.jigarCore.colorBlendFactor = jSkin.id == "default" ? 0 : 0.6
                self.powerUpActive = false
            }
        ]))
    }

    // =================================================================
    // MARK: - Controls
    // =================================================================

    private func setupSwipeControls(view: SKView) {
        let directions: [UISwipeGestureRecognizer.Direction] = [.left, .right, .up]
        for direction in directions {
            let gesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
            gesture.direction = direction
            view.addGestureRecognizer(gesture)
        }
    }

    private func setupTapControls(view: SKView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = self.view else { return }
        let location = gesture.location(in: view)
        let scenePoint = convertPoint(fromView: location)

        switch gameState {

        case .playing:
            if pauseButton.contains(scenePoint) {
                changeState(to: .paused)
            }

        case .paused:
            physicsWorld.speed = 1
            worldNode.isPaused = false
            pauseNode.isHidden = true
            gameState = .playing

        case .menu:
            for node in nodes(at: scenePoint) {
                guard let name = node.name else { continue }
                switch name {
                case "menuPlay":  changeState(to: .playing)
                case "menuHowTo": changeState(to: .tutorial)
                case "menuGarage": changeState(to: .garage)
                default: break
                }
            }

        case .garage:
            for node in nodes(at: scenePoint) {
                guard let name = node.name else { continue }
                if name == "garageBack" {
                    changeState(to: .menu)
                    return
                } else if name.hasPrefix("playerSkin_") {
                    selectPlayerSkin(String(name.dropFirst("playerSkin_".count)))
                    return
                } else if name.hasPrefix("jigarSkin_") {
                    selectJigarSkin(String(name.dropFirst("jigarSkin_".count)))
                    return
                }
            }

        case .gameOver:
            for node in nodes(at: scenePoint) {
                if node.name == "gameOverMenu" {
                    changeState(to: .menu)
                    return
                }
            }

        default:
            break
        }
    }

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gameState == .tutorial || gameState == .gameOver {
            if gesture.direction == .up {
                changeState(to: .playing)
            }
            return
        }

        guard gameState == .playing else { return }

        switch gesture.direction {
        case .left:  movePlayerLeft()
        case .right: movePlayerRight()
        case .up:
            if availablePowerUp != nil { usePowerUp() }
        default: break
        }
    }

    // =================================================================
    // MARK: - Player Movement
    // =================================================================

    private func movePlayerLeft() {
        guard currentLane > 0 else { return }
        currentLane -= 1
        movePlayerToCurrentLane(leaning: -1)
    }

    private func movePlayerRight() {
        guard currentLane < lanes.count - 1 else { return }
        currentLane += 1
        movePlayerToCurrentLane(leaning: 1)
    }

    private func movePlayerToCurrentLane(leaning: CGFloat) {
        player.run(SKAction.moveTo(x: lanes[currentLane], duration: 0.15), withKey: "playerLaneMovement")

        let lean = SKAction.sequence([
            SKAction.rotate(toAngle: -leaning * 0.25, duration: 0.08),
            SKAction.rotate(toAngle: 0, duration: 0.12)
        ])
        playerCore.run(lean)
    }

    // =================================================================
    // MARK: - Collision Detection
    // =================================================================

    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else { return }

        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        let otherBody: SKPhysicsBody?

        if bodyA.categoryBitMask == PhysicsCategory.player {
            otherBody = bodyB
        } else if bodyB.categoryBitMask == PhysicsCategory.player {
            otherBody = bodyA
        } else {
            otherBody = nil
        }

        guard let node = otherBody?.node else { return }

        switch node.name {
        case "ram":
            collectRAM(node)
        case "jigarProjectile":
            handleProjectileHit(node)
        case "jigar":
            handleDirectTouch()
        default:
            break
        }
    }

    /// A direct touch against Jigar's own body — instant death,
    /// independent of the Health bar (unless Shield is active).
    private func handleDirectTouch() {
        if jigarShielded {
            flashShieldBlock()
        } else {
            shakeScreen(intensity: 22, duration: 0.3)
            triggerGameOver(reason: "THE VIRUS GOT YOU")
        }
    }

    // =================================================================
    // MARK: - Collect RAM
    // =================================================================

    private func collectRAM(_ ram: SKNode) {
        ram.removeFromParent()
        ramNodes.removeAll { $0 === ram }

        ramCount += 1
        jigarHealth = min(jigarHealth + 0.5, 100)

        updateCombo()
        checkForPowerUp()
        updateUI()
        createRAMCollectionEffect()
    }

    private func updateCombo() {
        let now = CACurrentMediaTime()
        if now - lastCollectTime < 0.9 {
            comboCount += 1
        } else {
            comboCount = 1
        }
        lastCollectTime = now

        guard comboCount >= 3 else {
            comboLabel.isHidden = true
            return
        }

        comboLabel.text = "COMBO x\(comboCount)!"
        comboLabel.isHidden = false
        comboLabel.setScale(1.3)
        comboLabel.run(SKAction.scale(to: 1.0, duration: 0.15))
    }

    private func createRAMCollectionEffect() {
        let flash = SKShapeNode(circleOfRadius: 10)
        flash.fillColor = .clear
        flash.strokeColor = .green
        flash.lineWidth = 3
        flash.position = player.position
        flash.zPosition = 50
        worldNode.addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3, duration: 0.25),
                SKAction.fadeOut(withDuration: 0.25)
            ]),
            SKAction.removeFromParent()
        ]))

        for _ in 0..<6 {
            let spark = SKShapeNode(circleOfRadius: 2)
            spark.fillColor = UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
            spark.strokeColor = .clear
            spark.position = player.position
            spark.zPosition = 51
            worldNode.addChild(spark)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let distance = CGFloat.random(in: 20...40)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: dx, y: dy, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        let plusOne = makeLabel(text: "+1 RAM", size: 15, color: .green)
        plusOne.position = CGPoint(x: player.position.x, y: player.position.y + 30)
        plusOne.zPosition = 60
        worldNode.addChild(plusOne)
        plusOne.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 30, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // =================================================================
    // MARK: - Screen Shake
    // =================================================================

    private func shakeScreen(intensity: CGFloat, duration: TimeInterval) {
        let originalPosition = worldNode.position
        var actions: [SKAction] = []
        let steps = 6
        for _ in 0..<steps {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: duration / Double(steps)))
        }
        actions.append(SKAction.move(to: originalPosition, duration: duration / Double(steps)))
        worldNode.run(SKAction.sequence(actions))
    }

    // =================================================================
    // MARK: - Game Over
    // =================================================================

    private func triggerGameOver(reason: String) {
        guard gameState == .playing else { return }

        shakeScreen(intensity: 20, duration: 0.3)

        let meta = MetaProgress.shared
        meta.totalRAM += ramCount

        var isNewBest = false
        if ramCount > meta.bestRun {
            meta.bestRun = ramCount
            isNewBest = true
        }

        if let title = gameOverNode.childNode(withName: "gameOverTitle") as? SKLabelNode {
            title.text = reason
        }
        if let finalScore = gameOverNode.childNode(withName: "finalScore") as? SKLabelNode {
            finalScore.text = "RAM COLLECTED: \(ramCount) MB"
        }
        if let banked = gameOverNode.childNode(withName: "bankedRAM") as? SKLabelNode {
            banked.text = "+\(ramCount) BANKED · TOTAL \(meta.totalRAM)"
        }
        if let finalBest = gameOverNode.childNode(withName: "finalBest") as? SKLabelNode {
            finalBest.text = "BEST: \(meta.bestRun) MB"
        }
        if let newBest = gameOverNode.childNode(withName: "newBest") as? SKLabelNode {
            newBest.isHidden = !isNewBest
        }

        jigarCore.run(SKAction.sequence([
            SKAction.run { [weak self] in
                self?.jigarCore.color = .white
                self?.jigarCore.colorBlendFactor = 1.0
            },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                let jSkin = jigarSkins.first(where: { $0.id == MetaProgress.shared.equippedJigarSkin }) ?? jigarSkins[0]
                self.jigarCore.colorBlendFactor = jSkin.id == "default" ? 0 : 0.6
            }
        ]))

        changeState(to: .gameOver)
    }

    // =================================================================
    // MARK: - Stop Game
    // =================================================================

    private func stopGame() {
        removeAction(forKey: "gameLoop")
        removeAction(forKey: "jigarLoop")
        removeAction(forKey: "jigarShotScheduler")
    }

    // =================================================================
    // MARK: - Remove Game Objects
    // =================================================================

    private func removeAllGameObjects() {
        for node in worldNode.children where node.name == "ram" || node.name == "jigarProjectile" {
            node.removeAllActions()
            node.removeFromParent()
        }
        ramNodes.removeAll()

        player.childNode(withName: "playerShield")?.removeFromParent()

        for node in worldNode.children where node !== player && node !== jigar && node !== backgroundNode {
            if node.name == nil {
                node.removeFromParent()
            }
        }
    }
}
