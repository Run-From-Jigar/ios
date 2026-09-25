import UIKit
import SpriteKit

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // This executes once constraints map exactly to modern iPhone screen layouts
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let view = self.view as? SKView, view.scene == nil {
            let scene = GameScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill
            scene.anchorPoint = CGPoint(x: 0.5, y: 0.5) // Sets coordinates nicely around the center point
            
            view.presentScene(scene)
            view.ignoresSiblingOrder = true
            view.showsFPS = true
            view.showsNodeCount = true
        }
    }
    
    override var prefersStatusBarHidden: Bool { return true }
}
