//
//  GameScene.swift
//  Fappy Bird
//
//  Created by Oscar Villavicencio on 9/29/16.
//  Copyright © 2016 Unicorn. All rights reserved.
//

import SpriteKit
import GameplayKit
import AVFoundation

enum Layer: CGFloat{
    case background
    case obstacle
    case foreground
    case player
    case ui
    case flash
}

struct PhysicsCategory {
    static let None: UInt32 = 0 //0
    static let Player: UInt32 = 0x1 << 0 //1
    static let Obstacle: UInt32 = 0x1 << 1 //2
    static let Ground: UInt32 = 0x1 << 2 //4
}

enum GameState {
    case mainMenu
    case play
    case falling
    case showingScore
    case gameOver
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    //movement-obstacle constants
    let kBackgroundMotion: CGFloat = 170.0
    let kNumForegrounds = 2
    let kBottomObstacleMinFraction: CGFloat = 0.2 // percent of playableHeight
    let kBottomObstacleMaxFraction: CGFloat = 0.55 // percent of playableHeight
    let kObstacleGapToPlayerHeightRatio: CGFloat = 3.5 // ratio of gap between obstacles to player height
    let kFirstSpawnDelay: TimeInterval = 0.5
    let kEverySpawnDelay: TimeInterval = 2
    let kAnimationDelay: TimeInterval = 0.3
    //game sprites and mechanics
    let worldNode = SKNode()
    var scoreLabel = SKLabelNode()
    let kFontName = "STIXVariants-Bold"
    let kFontColor = SKColor(red: 101.0/255.0, green: 71.0/255.0, blue: 73.0/255.0, alpha: 1.0)
    let kMargin: CGFloat = 20.0
    var playableHeight: CGFloat = 0
    var playableStart: CGFloat = 0
    var player = SKSpriteNode(color: SKColor.green, size: CGSize(width: 40, height: 30))
    let background = SKSpriteNode(imageNamed: "Background")
    var lastUpdateTime: TimeInterval = 0
    var dt: TimeInterval = 0
    var hitGround = false
    var hitObstacle = false
    var gameState: GameState = .mainMenu
    var score = 0
    var hitOnce = 0
    var rectHeight: CGFloat = 0.0
    
    //sounds
    /*
    let soundAction = SKAction.playSoundFileNamed("sound.wav", waitForCompletion: false)
    */
    
    override init(size: CGSize) {
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        addChild(worldNode)
        worldNode.name = "world"
        setupBackground()
        setupForeground()
        setupPlayer()
    }
    
    // MARK: Setup Functions
    func setupBackground() {
        worldNode.addChild(background)
        background.scale(to: CGSize(width: size.width * 2, height: size.height * 0.9))
        
        background.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        background.position = CGPoint(x: size.width/2, y: size.height)
        background.zPosition = Layer.background.rawValue
        
        playableHeight = background.size.height
        playableStart = playableHeight * 0.19
        
    }
    
    func setupForeground(){
        for i in 0..<kNumForegrounds{
            let foreground = SKSpriteNode(imageNamed: "foreground")
            foreground.anchorPoint = CGPoint(x:0, y:1)
            foreground.position = CGPoint(x:CGFloat(i) * foreground.size.width, y:playableStart)
            foreground.zPosition = Layer.foreground.rawValue
            foreground.name = "foreground"
            worldNode.addChild(foreground)
            
            rectHeight = foreground.size.height * 0.7
            
        }
        
        let lowerLeft = CGPoint(x: 0, y: rectHeight)
        let lowerRight = CGPoint(x: size.width, y: rectHeight)
        
        let dummyNode = SKNode()
        dummyNode.physicsBody = SKPhysicsBody(edgeFrom: lowerLeft, to: lowerRight)
        dummyNode.physicsBody!.categoryBitMask = PhysicsCategory.Ground
        dummyNode.physicsBody!.contactTestBitMask = PhysicsCategory.Player
        dummyNode.physicsBody!.collisionBitMask = PhysicsCategory.None
        dummyNode.physicsBody!.isDynamic = false
        worldNode.addChild(dummyNode)
        
    }
    
    func setupPlayer(){
        player.position = CGPoint(x: size.width * 0.2, y: playableHeight * 0.4 + playableStart)
        player.zPosition = Layer.player.rawValue
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody!.categoryBitMask = PhysicsCategory.Player
        player.physicsBody!.contactTestBitMask = PhysicsCategory.Obstacle | PhysicsCategory.Ground
        player.physicsBody!.collisionBitMask = PhysicsCategory.None
        player.physicsBody!.isDynamic = true
        player.physicsBody!.affectedByGravity = false
        
        worldNode.addChild(player)
        
        let moveUp = SKAction.moveBy(x: 0, y: 10, duration: 0.4)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        let `repeat` = SKAction.repeatForever(SKAction.sequence([moveUp, moveDown]))
        player.run(`repeat`, withKey: "Wobble")
        
    }
    
    func createObstacle() -> SKSpriteNode {
        let sprite = SKSpriteNode(color: SKColor.red, size: CGSize(width: 55, height: 400))
        sprite.userData = NSMutableDictionary()
        
        sprite.physicsBody = SKPhysicsBody(rectangleOf: sprite.size)
        sprite.physicsBody!.categoryBitMask = PhysicsCategory.Obstacle
        sprite.physicsBody!.contactTestBitMask = PhysicsCategory.Player
        sprite.physicsBody!.collisionBitMask = PhysicsCategory.None
        sprite.physicsBody!.isDynamic = false
        sprite.zPosition = Layer.obstacle.rawValue
        
        return sprite
    }

    // MARK: Touches began
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let touchLocation = touch?.location(in: self)
        switch gameState {
        case .mainMenu:
            if (touchLocation?.y)! > size.height * 0.5{
                switchToPlay()
                setupLabel()
                // Start spawning
                startSpawn()
            }else{
                switchToSettings()
            }
            break
            
        case .play:
            flapPlayer()
            break
            
        case .falling:
            break
            
        case .showingScore:
            gameState = .showingScore
            break
            
        case .gameOver:
            if (touchLocation?.x)! > size.width * 0.6 {
                //share
            } else {
                switchToNewGame()
            }
            break
        }
    }
    
    // MARK: Updates
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        if lastUpdateTime > 0 {
            dt = currentTime - lastUpdateTime
        } else{
            dt = 0
        }
        
        lastUpdateTime = currentTime
        
        switch gameState{
        case .mainMenu:
            break
        case .play:
            updateForeground()
            updateScore()
            break
        case .falling:
            break
        case .showingScore:
            break
        case .gameOver:
            break
        }
        
        
    }
    
    // MARK: Switches
    func switchToNewGame() {
        if let skView = view {
            gameState = .mainMenu
            let newScene = GameScene(size: size)
            let transition = SKTransition.fade(with: SKColor.black, duration: 0.5)
            skView.presentScene(newScene, transition: transition)
        }
    }
    
    func switchToMainMenu(){
        gameState = .mainMenu
        
        setupBackground()
        setupForeground()
        setupPlayer()
    }
    
    func switchToPlay() {
        gameState = .play
        player.physicsBody!.affectedByGravity = true
        player.physicsBody?.allowsRotation = true
        physicsWorld.gravity = CGVector(dx: 0, dy: -1.7)
        // Stop wobbling
        player.removeAction(forKey: "Wobble")
        
        // Start spawning
        startSpawn()
        
        flapPlayer()
    }
    
    func switchToFalling() {
        gameState = .falling
        
        // Screen flash
        let whiteNode = SKSpriteNode(color: SKColor.white, size: size)
        whiteNode.position = CGPoint(x: size.width/2, y: size.height/2)
        whiteNode.zPosition = Layer.flash.rawValue
        worldNode.addChild(whiteNode)
        
        let remove = SKAction.removeFromParent()
        let delay = SKAction.wait(forDuration: 0.01)
        let delayThenRemove = SKAction.sequence([delay, remove])
        whiteNode.run(delayThenRemove)
        
        player.zRotation = CGFloat(-M_PI_2)
        player.removeAllActions()
        stopSpawning()
    }
    
    func switchToGameOver(){
        gameState = .gameOver
    }
    
    func switchToShowScore(){
        gameState = .showingScore
        setupScorecard()
        switchToGameOver()
    }
    
    func switchToSettings(){
        print("settings area touched")
    }
    
    // MARK: Player Related
    func flapPlayer(){
        //play a flap sound too, maybe?
        player.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 6))
    }
    
    // MARK: Obstacle Related
    func spawnObstacle() {
        let bottomObstacle = createObstacle()
        let startX = size.width + bottomObstacle.size.width/2 // fully off screen to the right
        
        let bottomObstacleMidpointY = (rectHeight - bottomObstacle.size.height/2)
        let bottomObstacleMin = bottomObstacleMidpointY + playableHeight * kBottomObstacleMinFraction
        let bottomObstacleMax = bottomObstacleMidpointY + playableHeight * kBottomObstacleMaxFraction
        bottomObstacle.position = CGPoint(x: startX, y: randomBetweenNumbers(bottomObstacleMin, secondNum: bottomObstacleMax))
        
        bottomObstacle.name = "BottomObstacle"
        worldNode.addChild(bottomObstacle)
        
        let topObstacle = createObstacle()
        topObstacle.zRotation = CGFloat(M_PI) // flip it 180deg around
        let bottomObstacleTopY = (bottomObstacle.position.y + bottomObstacle.size.height/2)
        let playerGap = kObstacleGapToPlayerHeightRatio * player.size.height
        topObstacle.position = CGPoint(x: startX, y: bottomObstacleTopY + playerGap + topObstacle.size.height/2)
        topObstacle.name = "TopObstacle"
        worldNode.addChild(topObstacle)
        
        // set up the obstacle's move
        let moveX = size.width + topObstacle.size.width // from offscreen right to offscreen left (includes one obj.width)
        let moveDuration = moveX / kBackgroundMotion // points divided by points/s = seconds
        // create a sequence of actions to do the move
        let sequence = SKAction.sequence([
            SKAction.moveBy(x: -moveX, y: 0, duration: TimeInterval(moveDuration)),
            SKAction.removeFromParent()
            ])
        // both obstacles run the same sequence and move together across the screen, right to left
        topObstacle.run(sequence)
        bottomObstacle.run(sequence)
    }
    
    func startSpawn(){
        let firstDelay = SKAction.wait(forDuration: kFirstSpawnDelay)
        let spawn = SKAction.run(spawnObstacle)
        let everyDelay = SKAction.wait(forDuration: kEverySpawnDelay)
        let spawnSequence = SKAction.sequence([
            spawn, everyDelay
            ])
        let foreverSpawn = SKAction.repeatForever(spawnSequence)
        let overallSequence = SKAction.sequence([
            firstDelay, foreverSpawn
            ])
        // scene itself should run this, since the code isn't specific to any nodes
        run(overallSequence, withKey: "spawn")
    }
    
    func stopSpawning() {
        removeAction(forKey: "spawn")
        // since Top and Bottom obstacles have different names (due to scoring), we need to do this removal for both
        ["TopObstacle", "BottomObstacle"].forEach() {
            self.worldNode.enumerateChildNodes(withName: $0, using: {node, stop in
                node.removeAllActions()
            })
        }
    }
    
    func checkHitGround() {
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.velocity = CGVector.zero
        //run(hitGroundAction)
        stopSpawning()
        switchToShowScore()
    }
    
    func checkHitObstacle() {
        if (hitObstacle){ switchToFalling() }
    }
    
    func randomBetweenNumbers(_ firstNum: CGFloat, secondNum: CGFloat) -> CGFloat{
        return CGFloat(arc4random()) / CGFloat(UINT32_MAX) * abs(firstNum - secondNum) + min(firstNum, secondNum)
    }
    
    // MARK: Environement Related
    func updateForeground() {
        worldNode.enumerateChildNodes(withName: "foreground", using: { node, stop in
            if let foreground = node as? SKSpriteNode {
                let moveAmount = -self.kBackgroundMotion * CGFloat(self.dt)
                foreground.position.x += moveAmount
                
                if foreground.position.x < -foreground.size.width {
                    foreground.position.x += foreground.size.width * CGFloat(self.kNumForegrounds)
                }
            }
        })
        
    }
    
    // MARK: Score Related
    func addToScore(){
        score += 1
    }
    
    func bestScore() -> Int {
        return UserDefaults.standard.integer(forKey: "BestScore")
    }
    
    func setBestScore(bestScore: Int) {
        UserDefaults.standard.set(bestScore, forKey: "BestScore")
        UserDefaults.standard.synchronize()
    }
    
    func updateScore() {
        let typicalObstacle = "TopObstacle" // pick one (top or bottom) arbitrarily, else we would double-score
        worldNode.enumerateChildNodes(withName: typicalObstacle, using: { node, stop in
            if let obstacle = node as? SKSpriteNode {
                // if current obstacle has a dictionary with the key "Passed", then we're done looking at that obstacle
                if let passed = obstacle.userData?["Passed"] as? NSNumber, passed.boolValue {
                    return
                }
                // else if player's position is beyond the obstacle's right edge...
                if self.player.position.x > obstacle.position.x + obstacle.size.width/2 {
                    // bump the score
                    self.addToScore()
                    self.scoreLabel.text = "\(self.score)"
                    // play a sound?
                    // and set the Passed key in its dictionary
                    obstacle.userData?["Passed"] = true
                }
            }
        })
    }
    
    func setupLabel() {
        scoreLabel = SKLabelNode(fontNamed: kFontName)
        scoreLabel.fontColor = SKColor.white
        scoreLabel.position = CGPoint(x: size.width/2, y: size.height - kMargin)
        scoreLabel.text = "\(score)"
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.zPosition = Layer.ui.rawValue
        worldNode.addChild(scoreLabel)
    }
    
    func setupScorecard() {
        if score > bestScore() {
            setBestScore(bestScore: score)
        }
        
        let scorecard = SKSpriteNode(imageNamed: "Scorecard")
        scorecard.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        scorecard.name = "Tutorial"
        scorecard.zPosition = Layer.ui.rawValue
        worldNode.addChild(scorecard)
        
        let lastScore = SKLabelNode(fontNamed: kFontName)
        lastScore.fontColor = kFontColor
        lastScore.position = CGPoint(x: -scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
        lastScore.text = "\(score)"
        lastScore.zPosition = Layer.ui.rawValue
        scorecard.addChild(lastScore)
        
        let bestScoreLabel = SKLabelNode(fontNamed: kFontName)
        bestScoreLabel.fontColor = kFontColor
        bestScoreLabel.position = CGPoint(x: scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
        bestScoreLabel.text = "\(self.bestScore())"
        bestScoreLabel.zPosition = Layer.ui.rawValue
        scorecard.addChild(bestScoreLabel)
        
        let yDistance = scorecard.size.height/2 + kMargin
        let gameOver = SKSpriteNode(imageNamed: "GameOver")
        gameOver.position = CGPoint(x: size.width/2, y: size.height/2 + yDistance + gameOver.size.height/2)
        gameOver.zPosition = Layer.ui.rawValue
        worldNode.addChild(gameOver)
        
        let okButton = SKSpriteNode(imageNamed: "Button")
        okButton.position = CGPoint(x: size.width * 0.25, y: size.height/2 - yDistance - okButton.size.height/2)
        okButton.zPosition = Layer.ui.rawValue
        worldNode.addChild(okButton)
        
        let ok = SKSpriteNode(imageNamed: "kay-o")
        ok.position = CGPoint.zero
        ok.zPosition = Layer.ui.rawValue
        okButton.addChild(ok)
        
        let shareButton = SKSpriteNode(imageNamed: "Button")
        shareButton.position = CGPoint(x: size.width * 0.75, y: size.height/2 - yDistance - shareButton.size.height/2)
        shareButton.zPosition = Layer.ui.rawValue
        worldNode.addChild(shareButton)
        
        let share = SKSpriteNode(imageNamed: "Share")
        share.position = CGPoint.zero
        share.zPosition = Layer.ui.rawValue
        shareButton.addChild(share)
        
        // animation: gameOver scales and fades in at its final position (no motion)
        gameOver.setScale(0)
        gameOver.alpha = 0
        let group = SKAction.group([
            SKAction.fadeIn(withDuration: kAnimationDelay),
            SKAction.scale(to: 1.0, duration: kAnimationDelay)
            ])
        group.timingMode = .easeInEaseOut
        gameOver.run(SKAction.sequence([
            SKAction.wait(forDuration: kAnimationDelay),
            group
            ]))
        
        // scorecard slides in from the bottom
        scorecard.position = CGPoint(x: size.width/2, y: -scorecard.size.height/2)
        let moveTo = SKAction.move(to: CGPoint(x: size.width/2, y: size.height/2), duration: kAnimationDelay)
        moveTo.timingMode = .easeInEaseOut
        scorecard.run(SKAction.sequence([
            SKAction.wait(forDuration: kAnimationDelay * 2),
            moveTo
            ]))
        
        // OK and Share buttons fade in, also in place
        okButton.alpha = 0
        shareButton.alpha = 0
        let fadeIn = SKAction.sequence([
            SKAction.wait(forDuration: kAnimationDelay * 3),
            SKAction.fadeIn(withDuration: kAnimationDelay)
            ])
        fadeIn.timingMode = .easeInEaseOut
        okButton.run(fadeIn)
        shareButton.run(fadeIn)
    }
    
    // MARK: Contact Delegate
    func didBegin(_ contact: SKPhysicsContact) {
        //GAMEOVER = TRUE
        let other = contact.bodyA.categoryBitMask == PhysicsCategory.Player ? contact.bodyB : contact.bodyA
        
        
        if other.categoryBitMask == PhysicsCategory.Ground {
            checkHitGround()
            print("hit ground?")
        }
        if other.categoryBitMask == PhysicsCategory.Obstacle {
            hitObstacle = true
            if(hitOnce < 1){
                checkHitObstacle()
                hitOnce += 1
            }
            print("hit pipe?")
            
        }
    }
}
