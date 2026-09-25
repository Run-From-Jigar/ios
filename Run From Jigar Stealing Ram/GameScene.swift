import SpriteKit
import GameplayKit
import UIKit

// =====================================================================
//  RUN FROM JIGAR — polished edition
// =====================================================================
//  This file no longer depends on external art assets at all.
//  Every sprite (player, Jigar, RAM, power-ups, background) is drawn
//  in code with Core Graphics and turned into a crisp SKTexture.
//  That means the game looks finished immediately — no missing-image
//  placeholders, no trip to Assets.xcassets required — while still
//  automatically using a named asset (e.g. "playerSprite") if you
//  drop one into Assets.xcassets later.
//
//  Sections are labelled and commented so the flow is easy to follow
//  even if you're new to SpriteKit.
// =====================================================================

// MARK: - Collision Categories

struct PhysicsCategory {
    static let none: UInt32     = 0
    static let player: UInt32   = 0b1
    static let ram: UInt32      = 0b10
    static let powerUp: UInt32  = 0b100
}

// MARK: - Game States

enum GameState {
    case tutorial
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

    /// Simple SF Symbol style glyph drawn by hand, used for the icon
    /// inside the power-up's procedurally drawn badge.
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
    private var worldNode: SKNode!          // everything that shakes together
    private var uiNode: SKNode!             // HUD, never shakes

    // MARK: UI

    private var ramLabel: SKLabelNode!
    private var ramProgressBar: SKShapeNode!
    private var ramProgressFill: SKShapeNode!

    private var jigarDistanceLabel: SKLabelNode!
    private var jigarProximityBar: SKShapeNode!
    private var jigarProximityFill: SKShapeNode!

    private var comboLabel: SKLabelNode!

    private var powerUpBadge: SKNode!
    private var powerUpIconLabel: SKLabelNode!
    private var powerUpTextLabel: SKLabelNode!

    private var pauseButton: SKShapeNode!

    private var tutorialNode: SKNode!
    private var gameOverNode: SKNode!
    private var pauseNode: SKNode!

    // MARK: Game State

    private var gameState: GameState = .tutorial
    private var stateBeforePause: GameState = .tutorial

    private var ramCount = 0
    private var ramNeededForPowerUp = 10
    private var comboCount = 0
    private var lastCollectTime: TimeInterval = 0

    private var highScore = 0

    // MARK: Jigar

    private var jigarDistance: CGFloat = 260
    private let startingJigarDistance: CGFloat = 260
    private var jigarFrozen = false
    private var jigarShielded = false

    // MARK: Power Up

    private var availablePowerUp: PowerUp?
    private var powerUpActive = false

    // MARK: Movement

    private let lanes: [CGFloat] = [-100, 0, 100]
    private var currentLane = 1

    // MARK: Game Speed

    private var gameSpeed: CGFloat = 1.0

    // MARK: RAM Nodes

    private var ramNodes: [SKNode] = []

    // MARK: Sprite Names (optional — drop matching images into
    // Assets.xcassets and they will be used automatically instead
    // of the built-in procedural artwork)

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

        highScore = UserDefaults.standard.integer(forKey: "HighScoreRAM")

        worldNode = SKNode()
        addChild(worldNode)

        uiNode = SKNode()
        uiNode.zPosition = 200
        addChild(uiNode)

        setupBackground()
        setupPlayer()
        setupJigar()
        setupUI()
        setupTutorial()
        setupGameOver()
        setupPauseOverlay()
        setupSwipeControls(view: view)
        setupTapControls(view: view)

        changeState(to: .tutorial)
    }

    // =================================================================
    // MARK: - State Management
    // =================================================================

    private func changeState(to newState: GameState) {
        gameState = newState

        switch newState {

        case .tutorial:
            tutorialNode.isHidden = false
            gameOverNode.isHidden = true
            pauseNode.isHidden = true

            player.isHidden = true
            jigar.isHidden = true

            ramLabel.isHidden = true
            ramProgressBar.isHidden = true
            jigarDistanceLabel.isHidden = true
            jigarProximityBar.isHidden = true
            powerUpBadge.isHidden = true
            pauseButton.isHidden = true
            comboLabel.isHidden = true

        case .playing:
            tutorialNode.isHidden = true
            gameOverNode.isHidden = true
            pauseNode.isHidden = true

            player.isHidden = false
            jigar.isHidden = false

            ramLabel.isHidden = false
            ramProgressBar.isHidden = false
            jigarDistanceLabel.isHidden = false
            jigarProximityBar.isHidden = false
            pauseButton.isHidden = false

            resetGame()

        case .paused:
            pauseNode.isHidden = false
            physicsWorld.speed = 0
            worldNode.isPaused = true

        case .gameOver:
            tutorialNode.isHidden = true
            gameOverNode.isHidden = false
            pauseNode.isHidden = true

            player.isHidden = false
            jigar.isHidden = false

            powerUpBadge.isHidden = true
            pauseButton.isHidden = true
            comboLabel.isHidden = true

            stopGame()
        }
    }

    // =================================================================
    // MARK: - Procedural Art Helpers
    // =================================================================

    /// Renders a soft radial-glow circle texture — used behind the
    /// player and Jigar to give them a neon "alive" feel with zero
    /// external art.
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

    /// Draws the runner: a rounded, forward-leaning capsule body with
    /// a bright visor stripe — instantly reads as "a person running".
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

            // Visor stripe — reads as "face/front".
            let visor = UIBezierPath(roundedRect: CGRect(x: 20, y: 38, width: 24, height: 8), cornerRadius: 4)
            UIColor.white.withAlphaComponent(0.9).setFill()
            visor.fill()

            // Outline for readability against any background.
            UIColor.white.withAlphaComponent(0.5).setStroke()
            bodyPath.lineWidth = 2
            bodyPath.stroke()
        }
        return SKTexture(image: image)
    }

    /// Draws Jigar: a spiky, menacing dark blob with glowing red eyes
    /// — reads clearly as "the threat chasing you".
    private func jigarTexture() -> SKTexture {
        let size = CGSize(width: 80, height: 80)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2 - 6)

            // Spiky silhouette.
            let spikes = 10
            let outerRadius: CGFloat = 34
            let innerRadius: CGFloat = 22
            let path = UIBezierPath()
            for i in 0..<(spikes * 2) {
                let angle = (CGFloat(i) / CGFloat(spikes * 2)) * .pi * 2
                let radius = i % 2 == 0 ? outerRadius : innerRadius
                let point = CGPoint(x: center.x + cos(angle) * radius,
                                     y: center.y + sin(angle) * radius)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [UIColor(red: 0.35, green: 0.05, blue: 0.08, alpha: 1).cgColor,
                                                UIColor(red: 0.10, green: 0.01, blue: 0.02, alpha: 1).cgColor] as CFArray,
                                       locations: [0, 1])!
            cgCtx.saveGState()
            path.addClip()
            cgCtx.drawRadialGradient(gradient,
                                      startCenter: center, startRadius: 4,
                                      endCenter: center, endRadius: outerRadius,
                                      options: [])
            cgCtx.restoreGState()

            UIColor.red.withAlphaComponent(0.7).setStroke()
            path.lineWidth = 2
            path.stroke()

            // Glowing eyes.
            for dx: CGFloat in [-10, 10] {
                let eyeRect = CGRect(x: center.x + dx - 5, y: center.y + 4, width: 10, height: 10)
                UIColor(red: 1, green: 0.15, blue: 0.15, alpha: 1).setFill()
                UIBezierPath(ovalIn: eyeRect).fill()
                UIColor.white.withAlphaComponent(0.9).setFill()
                UIBezierPath(ovalIn: eyeRect.insetBy(dx: 3, dy: 3)).fill()
            }
        }
        return SKTexture(image: image)
    }

    /// Draws a RAM chip — a little green circuit-board square,
    /// unmistakably "a piece of computer memory".
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

            // Little contact pins on each side.
            UIColor(red: 0.85, green: 1.0, blue: 0.85, alpha: 1).setFill()
            for i in 0..<4 {
                let x = chipRect.minX + 3 + CGFloat(i) * 5
                cgCtx.fill(CGRect(x: x, y: chipRect.minY - 3, width: 2, height: 3))
                cgCtx.fill(CGRect(x: x, y: chipRect.maxY, width: 2, height: 3))
            }

            // Circuit line detail.
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
        // Soft vertical gradient panel behind everything for depth.
        let gradientTexture = verticalGradientTexture(
            top: UIColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 1),
            bottom: UIColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1),
            size: CGSize(width: max(size.width, 400), height: max(size.height, 800))
        )
        let backdrop = SKSpriteNode(texture: gradientTexture)
        backdrop.zPosition = -101
        backgroundNode.addChild(backdrop)

        // Perspective road lanes glowing gently.
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

        // Scrolling grid to sell the sense of speed.
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
        let scroll = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.moveBy(x: 0, y: -60, duration: 0.6),
                SKAction.run { [weak self] in
                    // handled by gameSpeed via updateBackgroundScroll()
                    _ = self
                }
            ])
        )
        grid.run(scroll, withKey: "gridScroll")

        // Drifting ambient particles (dust/snow-like) for atmosphere.
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
        player.position = CGPoint(x: lanes[currentLane], y: -170)
        player.zPosition = 20
        worldNode.addChild(player)

        // Soft contact shadow sells "grounded" without needing a floor sprite.
        playerShadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 12))
        playerShadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        playerShadow.strokeColor = .clear
        playerShadow.position = CGPoint(x: 0, y: -30)
        playerShadow.zPosition = -1
        player.addChild(playerShadow)

        playerGlow = SKSpriteNode(texture: glowTexture(color: .cyan, diameter: 140))
        playerGlow.size = CGSize(width: 110, height: 110)
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
            playerCore.size = CGSize(width: 48, height: 48)
        }
        player.addChild(playerCore)

        // Subtle running bob so the character feels alive even standing still.
        playerCore.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.moveBy(x: 0, y: 4, duration: 0.22),
                SKAction.moveBy(x: 0, y: -4, duration: 0.22)
            ])
        ), withKey: "bob")

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 48, height: 48))
        body.isDynamic = true
        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.ram | PhysicsCategory.powerUp
        body.collisionBitMask = PhysicsCategory.none
        player.physicsBody = body
    }

    // =================================================================
    // MARK: - Jigar
    // =================================================================

    private func setupJigar() {
        jigar = SKNode()
        jigar.name = "jigar"
        jigar.position = CGPoint(x: lanes[currentLane], y: -430)
        jigar.zPosition = 15
        worldNode.addChild(jigar)

        jigarGlow = SKSpriteNode(texture: glowTexture(color: .red, diameter: 160))
        jigarGlow.size = CGSize(width: 130, height: 130)
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
            jigarCore.size = CGSize(width: 64, height: 64)
        }
        jigar.addChild(jigarCore)

        jigarCore.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.rotate(byAngle: 0.06, duration: 0.15),
                SKAction.rotate(byAngle: -0.12, duration: 0.3),
                SKAction.rotate(byAngle: 0.06, duration: 0.15)
            ])
        ), withKey: "menace")
    }

    // =================================================================
    // MARK: - Sprite Loader (optional external assets)
    // =================================================================

    private func loadSprite(named name: String) -> SKSpriteNode? {
        guard let image = UIImage(named: name) else { return nil }
        return SKSpriteNode(texture: SKTexture(image: image))
    }

    // =================================================================
    // MARK: - UI
    // =================================================================

    private func setupUI() {
        // --- RAM counter + progress bar toward next power-up ---
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

        // --- Jigar proximity meter (color shifts green -> red) ---
        jigarDistanceLabel = makeLabel(text: "JIGAR 260m", size: 14, color: .white)
        jigarDistanceLabel.position = CGPoint(x: 0, y: size.height / 2 - 50)
        uiNode.addChild(jigarDistanceLabel)

        jigarProximityBar = roundedBar(width: 130, height: 10, color: UIColor.white.withAlphaComponent(0.12))
        jigarProximityBar.position = CGPoint(x: 0, y: size.height / 2 - 68)
        uiNode.addChild(jigarProximityBar)

        jigarProximityFill = roundedBar(width: 130, height: 10, color: .red)
        jigarProximityFill.position = jigarProximityBar.position
        uiNode.addChild(jigarProximityFill)

        // --- Combo label (fun feedback for quick chained pickups) ---
        comboLabel = makeLabel(text: "", size: 16, color: .yellow)
        comboLabel.position = CGPoint(x: 0, y: 60)
        comboLabel.isHidden = true
        uiNode.addChild(comboLabel)

        // --- Power-up badge (icon + name inside a rounded pill) ---
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

        // --- Pause button, top-right corner ---
        pauseButton = SKShapeNode(circleOfRadius: 18)
        pauseButton.fillColor = UIColor.black.withAlphaComponent(0.35)
        pauseButton.strokeColor = UIColor.white.withAlphaComponent(0.4)
        pauseButton.position = CGPoint(x: size.width / 2 - 34, y: size.height / 2 - 50)
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

        jigarDistanceLabel.text = "JIGAR  \(Int(jigarDistance))m"

        let proximity = 1 - (jigarDistance / startingJigarDistance) // 0 = safe, 1 = caught
        let danger = max(0, min(proximity, 1))
        jigarProximityFill.run(SKAction.scaleX(to: max(0.02, 1 - danger), duration: 0.1))
        jigarProximityFill.fillColor = dangerColor(for: danger)

        if danger > 0.75 {
            jigarDistanceLabel.fontColor = UIColor(red: 1, green: 0.25, blue: 0.25, alpha: 1)
        } else {
            jigarDistanceLabel.fontColor = .white
        }

        if let powerUp = availablePowerUp {
            powerUpIconLabel.text = powerUp.glyph
            powerUpTextLabel.text = powerUp.displayName
            powerUpTextLabel.fontColor = powerUp.color
            powerUpBadge.isHidden = false
        } else {
            powerUpBadge.isHidden = true
        }
    }

    /// Smoothly blends green -> yellow -> red as Jigar gets closer.
    private func dangerColor(for t: CGFloat) -> UIColor {
        if t < 0.5 {
            let local = t / 0.5
            return blend(UIColor(red: 0.3, green: 1.0, blue: 0.4, alpha: 1),
                          UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1), local)
        } else {
            let local = (t - 0.5) / 0.5
            return blend(UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1),
                          UIColor(red: 1.0, green: 0.2, blue: 0.25, alpha: 1), local)
        }
    }

    private func blend(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t,
                        green: g1 + (g2 - g1) * t,
                        blue: b1 + (b2 - b1) * t,
                        alpha: 1)
    }

    // =================================================================
    // MARK: - Tutorial
    // =================================================================

    private func setupTutorial() {
        tutorialNode = SKNode()
        uiNode.addChild(tutorialNode)

        let panel = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 340), cornerRadius: 24)
        panel.fillColor = UIColor.black.withAlphaComponent(0.4)
        panel.strokeColor = UIColor.cyan.withAlphaComponent(0.25)
        panel.lineWidth = 1.5
        panel.position = CGPoint(x: 0, y: 0)
        tutorialNode.addChild(panel)

        let title = makeLabel(text: "RUN FROM JIGAR", size: 32, color: .white)
        title.position = CGPoint(x: 0, y: 125)
        tutorialNode.addChild(title)
        title.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.colorize(with: .cyan, colorBlendFactor: 0.5, duration: 1.2),
                SKAction.colorize(with: .white, colorBlendFactor: 0, duration: 1.2)
            ])
        ))

        let subtitle = makeLabel(text: "STEAL BACK THE RAM", size: 16, color: .green)
        subtitle.position = CGPoint(x: 0, y: 90)
        tutorialNode.addChild(subtitle)

        let lines: [(String, UIColor, CGFloat)] = [
            ("🧠 COLLECT RAM CHIPS", .green, 35),
            ("⚡ EVERY 10 RAM = A RANDOM POWER-UP", .white, 5),
            ("↔️ SWIPE LEFT / RIGHT TO CHANGE LANES", .cyan, -35),
            ("⬆️ SWIPE UP TO USE YOUR POWER-UP", .yellow, -65),
            ("👹 DON'T LET JIGAR CATCH YOU", .red, -95)
        ]
        for (text, color, y) in lines {
            let label = makeLabel(text: text, size: 14, color: color)
            label.position = CGPoint(x: 0, y: y)
            tutorialNode.addChild(label)
        }

        let start = makeLabel(text: "[ SWIPE UP TO START ]", size: 18, color: .green)
        start.position = CGPoint(x: 0, y: -145)
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
        uiNode.addChild(gameOverNode)

        let panel = SKShapeNode(rectOf: CGSize(width: size.width - 60, height: 260), cornerRadius: 24)
        panel.fillColor = UIColor.black.withAlphaComponent(0.55)
        panel.strokeColor = UIColor.red.withAlphaComponent(0.35)
        panel.lineWidth = 1.5
        gameOverNode.addChild(panel)

        let title = makeLabel(text: "JIGAR CAUGHT YOU", size: 28, color: .red)
        title.position = CGPoint(x: 0, y: 85)
        gameOverNode.addChild(title)

        let score = makeLabel(text: "", size: 20, color: .green)
        score.name = "finalScore"
        score.position = CGPoint(x: 0, y: 40)
        gameOverNode.addChild(score)

        let best = makeLabel(text: "", size: 16, color: .white)
        best.name = "finalBest"
        best.position = CGPoint(x: 0, y: 10)
        gameOverNode.addChild(best)

        let newBest = makeLabel(text: "🏆 NEW BEST!", size: 15, color: .yellow)
        newBest.name = "newBest"
        newBest.position = CGPoint(x: 0, y: -20)
        newBest.isHidden = true
        gameOverNode.addChild(newBest)

        let restart = makeLabel(text: "[ SWIPE UP TO RUN AGAIN ]", size: 16, color: .white)
        restart.position = CGPoint(x: 0, y: -80)
        gameOverNode.addChild(restart)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
        restart.run(SKAction.repeatForever(pulse))
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
        resume.name = "resumeLabel"
        resume.position = CGPoint(x: 0, y: -10)
        pauseNode.addChild(resume)
    }

    private func makeLabel(text: String, size: CGFloat, color: UIColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        return label
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

        jigarDistance = startingJigarDistance

        jigarFrozen = false
        jigarShielded = false

        currentLane = 1
        gameSpeed = 1.0

        player.removeAction(forKey: "flash")
        jigarCore.colorBlendFactor = 0
        playerCore.colorBlendFactor = 0

        player.alpha = 1
        jigar.alpha = 1

        player.position = CGPoint(x: lanes[currentLane], y: -170)
        jigar.position = CGPoint(x: lanes[currentLane], y: -430)

        physicsWorld.speed = 1
        worldNode.isPaused = false

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
            ram.size = CGSize(width: 32, height: 32)
        }

        ram.name = "ram"
        ram.position = CGPoint(x: lane, y: size.height / 2 + 40)
        ram.zPosition = 10
        worldNode.addChild(ram)

        // Gentle idle spin makes the chip read as a collectible.
        ram.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 2.2)))

        let body = SKPhysicsBody(circleOfRadius: 14)
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
    // MARK: - Jigar
    // =================================================================

    private func updateJigar() {
        guard gameState == .playing else { return }

        if !jigarFrozen {
            let pressure = CGFloat.random(in: 0.25...0.8)
            jigarDistance -= pressure
            jigarDistance += 0.08 // small breathing room
        }

        jigarDistance = max(0, min(jigarDistance, 400))

        let visualY = -170 - jigarDistance
        let targetPosition = CGPoint(x: player.position.x, y: visualY)
        jigar.run(SKAction.move(to: targetPosition, duration: 0.1), withKey: "jigarMovement")

        updateUI()

        if jigarDistance <= 0 {
            if jigarShielded {
                jigarDistance = 80
                flashShieldBlock()
            } else {
                triggerGameOver()
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

        let sequence = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 0.25),
            ]),
            SKAction.wait(forDuration: 1.1),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.35),
                SKAction.moveBy(x: 0, y: 20, duration: 0.35)
            ]),
            SKAction.removeFromParent()
        ])
        container.run(sequence)
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

    // MARK: Speed Boost

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
        ghost.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: RAM Magnet

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

    // MARK: Shield

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

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        ])
        shield.run(SKAction.repeatForever(pulse))

        run(SKAction.sequence([
            SKAction.wait(forDuration: 6),
            SKAction.run { [weak self, weak shield] in
                self?.jigarShielded = false
                shield?.removeFromParent()
                self?.powerUpActive = false
            }
        ]))
    }

    // MARK: Jigar Attack

    private func activateJigarAttack() {
        jigarDistance += 100
        jigarDistance = min(jigarDistance, 400)

        let flashRed = SKAction.run { [weak self] in
            self?.jigarCore.color = .white
            self?.jigarCore.colorBlendFactor = 1.0
        }
        let wait = SKAction.wait(forDuration: 0.15)
        let returnToNormal = SKAction.run { [weak self] in self?.jigarCore.colorBlendFactor = 0.0 }
        jigar.run(SKAction.sequence([flashRed, wait, returnToNormal]))

        shakeScreen(intensity: 14, duration: 0.25)

        run(SKAction.wait(forDuration: 0.5)) { [weak self] in
            self?.powerUpActive = false
        }

        updateUI()
    }

    // MARK: Freeze Jigar

    private func activateFreezeJigar() {
        jigarFrozen = true
        jigar.alpha = 0.45
        jigarCore.color = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1)
        jigarCore.colorBlendFactor = 0.6

        run(SKAction.sequence([
            SKAction.wait(forDuration: 5),
            SKAction.run { [weak self] in
                self?.jigarFrozen = false
                self?.jigar.alpha = 1.0
                self?.jigarCore.colorBlendFactor = 0.0
                self?.powerUpActive = false
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

        if gameState == .playing, pauseButton.contains(scenePoint) {
            stateBeforePause = .playing
            changeState(to: .paused)
            return
        }
        if gameState == .paused {
            physicsWorld.speed = 1
            worldNode.isPaused = false
            changeState(to: .playing == stateBeforePause ? .playing : .playing)
            pauseNode.isHidden = true
            gameState = .playing
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
        case .left:
            movePlayerLeft()
        case .right:
            movePlayerRight()
        case .up:
            if availablePowerUp != nil {
                usePowerUp()
            }
        default:
            break
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
        let movement = SKAction.moveTo(x: lanes[currentLane], duration: 0.15)
        player.run(movement, withKey: "playerLaneMovement")

        // Quick lean/tilt in the movement direction — small detail that
        // makes the lane-change read as a physical dodge.
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

        if node.name == "ram" {
            collectRAM(node)
        }
    }

    // =================================================================
    // MARK: - Collect RAM
    // =================================================================

    private func collectRAM(_ ram: SKNode) {
        ram.removeFromParent()
        ramNodes.removeAll { $0 === ram }

        ramCount += 1
        jigarDistance = min(jigarDistance + 2, 400)

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

    // =================================================================
    // MARK: - RAM Collection Effect
    // =================================================================

    private func createRAMCollectionEffect() {
        // Ring burst.
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

        // Tiny particle sparks flying outward.
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

    private func triggerGameOver() {
        guard gameState == .playing else { return }

        shakeScreen(intensity: 20, duration: 0.3)

        var isNewBest = false
        if ramCount > highScore {
            highScore = ramCount
            isNewBest = true
            UserDefaults.standard.set(highScore, forKey: "HighScoreRAM")
        }

        if let finalScore = gameOverNode.childNode(withName: "finalScore") as? SKLabelNode {
            finalScore.text = "RAM COLLECTED: \(ramCount) MB"
        }
        if let finalBest = gameOverNode.childNode(withName: "finalBest") as? SKLabelNode {
            finalBest.text = "BEST: \(highScore) MB"
        }
        if let newBest = gameOverNode.childNode(withName: "newBest") as? SKLabelNode {
            newBest.isHidden = !isNewBest
        }

        // Jigar "catches" the player with a quick color flash for clarity.
        jigarCore.run(SKAction.sequence([
            SKAction.run { [weak self] in
                self?.jigarCore.color = .white
                self?.jigarCore.colorBlendFactor = 1.0
            },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in self?.jigarCore.colorBlendFactor = 0 }
        ]))

        changeState(to: .gameOver)
    }

    // =================================================================
    // MARK: - Stop Game
    // =================================================================

    private func stopGame() {
        removeAction(forKey: "gameLoop")
        removeAction(forKey: "jigarLoop")
    }

    // =================================================================
    // MARK: - Remove Game Objects
    // =================================================================

    private func removeAllGameObjects() {
        for node in worldNode.children where node.name == "ram" {
            node.removeAllActions()
            node.removeFromParent()
        }
        ramNodes.removeAll()

        player.childNode(withName: "playerShield")?.removeFromParent()

        // Clean up any leftover effect nodes from a previous run.
        for node in worldNode.children where node !== player && node !== jigar && node !== backgroundNode {
            if node.name == nil {
                node.removeFromParent()
            }
        }
    }
}
