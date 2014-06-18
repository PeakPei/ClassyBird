//
//  ClassyBirdMyScene.m
//  ClassyBird
//
//  Created by Aaron Rama on 3/15/14.
//  Copyright (c) 2014 Aaron Rama. All rights reserved.
//

#import "ClassyBirdMyScene.h"

typedef NS_ENUM(int, Layer) {
  LayerBackground,
  LayerObstacle,
  LayerForeground,
  LayerPlayer,
  LayerUI
};

typedef NS_OPTIONS(int, EntityCategory) {
  EntityCategoryPlayer = 1 << 0,
  EntityCategoryObstacle = 1 << 1,
  EntityCategoryGround = 1 << 2
};


// Gameplay constants
static const float kGravity = -1500.0;
static const float kImpulse = 400.0;
static const float kGroundSpeed = 150.0;

//Gameplay - obstacles
static const float kGapMultiplier = 3.20;
static const float kBottomObstacleMinFraction = 0.1;
static const float kBottomObstacleMaxFraction = 0.6;
static const float kFirstSpawnDelay = 1.75;
static const float kNormalSpawnDelay = 1.5;


//Looks Constants
static const int kNumForegrounds = 2;
static const float kMargin = 20.0;
static const float kAnimationDelay = 0.3;
static NSString *const kFontName = @"AmericanTypewriter-Bold";

@interface ClassyBirdMyScene() <SKPhysicsContactDelegate>

@end

@implementation ClassyBirdMyScene
{
  SKNode *_worldNode;
  float _playableHeight;
  float _playableStart;
  
  SKSpriteNode *_player;
  CGPoint _playerVelocity;
  
  BOOL _hitGround;
  BOOL _hitObstacle;
  
  NSTimeInterval _lastUpdateTime;
  NSTimeInterval _dt;
  
  //Sounds
  SKAction *_dingAction;
  SKAction *_coinAction;
  SKAction *_fallingAction;
  SKAction *_flapAction;
  SKAction *_hitGroundAction;
  SKAction *_popAction;
  SKAction *_whackAction;
  
  GameState _gameState;
  
  SKLabelNode *_scoreLabel;
  int _score;
}

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
      _worldNode = [SKNode node];
      [self addChild:_worldNode];
      self.physicsWorld.gravity = CGVectorMake(0, 0);
      self.physicsWorld.contactDelegate = self;
      
      [self switchToTutorial];
      


    }
    return self;
}

#pragma mark - Setup Methods

- (void)setupBackground
{
  SKSpriteNode *background = [SKSpriteNode spriteNodeWithImageNamed:@"Background"];
  background.anchorPoint = CGPointMake(0.5, 1);
  background.position = CGPointMake(self.size.width/2, self.size.height);
  background.zPosition = LayerBackground;
  [_worldNode addChild:background];
  
  _playableStart = self.size.height - background.size.height;
  _playableHeight = background.size.height;
  
  // 1
  CGPoint lowerLeft = CGPointMake(0, _playableStart);
  CGPoint lowerRight = CGPointMake(self.size.width, _playableStart);
  
  self.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:lowerLeft toPoint:lowerRight];
//  [self skt_attachDebugLineFromPoint:lowerLeft toPoint:lowerRight color:[UIColor redColor]];
  
  self.physicsBody.categoryBitMask = EntityCategoryGround;
  self.physicsBody.collisionBitMask = 0;
  self.physicsBody.contactTestBitMask = EntityCategoryPlayer;
}

- (void)setupForeground
{
  for (int i = 0; i < kNumForegrounds; ++i) {
    SKSpriteNode *foreground = [SKSpriteNode spriteNodeWithImageNamed:@"ground"];
    foreground.anchorPoint = CGPointMake(0, 1);
    foreground.position = CGPointMake(i * self.size.width, _playableStart);
    foreground.zPosition = LayerForeground;
    foreground.name = @"Foreground";
    [_worldNode addChild:foreground];
  }
}

- (void)setupPlayer
{
  _player = [SKSpriteNode spriteNodeWithImageNamed:@"birdFlap1"];
  _player.position = CGPointMake(self.size.width * 0.2, _playableHeight * 0.4 + _playableStart);
  _player.zPosition = LayerPlayer;
  
  [_worldNode addChild:_player];
  
  NSArray *textures = @[
                        [SKTexture textureWithImageNamed:@"birdFlap1"],
                        [SKTexture textureWithImageNamed:@"birdFlap2"],
                        [SKTexture textureWithImageNamed:@"birdFlap3"],
                        [SKTexture textureWithImageNamed:@"birdFlap4"],
                        [SKTexture textureWithImageNamed:@"birdFlap5"],
                        [SKTexture textureWithImageNamed:@"birdFlap6"],
                        [SKTexture textureWithImageNamed:@"birdFlap7"],
                        [SKTexture textureWithImageNamed:@"birdFlap8"]
                        ];
  SKAction *flapAnimation = [SKAction animateWithTextures:textures timePerFrame:0.1];
  SKAction *foreverFlap = [SKAction repeatActionForever:flapAnimation];
  [_player runAction:foreverFlap withKey:@"FlapAnimation"];
  
  CGFloat offsetX = _player.frame.size.width * _player.anchorPoint.x;
  CGFloat offsetY = _player.frame.size.height * _player.anchorPoint.y;
  
  CGMutablePathRef path = CGPathCreateMutable();
  
  CGPathMoveToPoint(path, NULL, 6 - offsetX, 21 - offsetY);
  CGPathAddLineToPoint(path, NULL, 20 - offsetX, 35 - offsetY);
  CGPathAddLineToPoint(path, NULL, 32 - offsetX, 31 - offsetY);
  CGPathAddLineToPoint(path, NULL, 32 - offsetX, 19 - offsetY);
  CGPathAddLineToPoint(path, NULL, 39 - offsetX, 15 - offsetY);
  CGPathAddLineToPoint(path, NULL, 31 - offsetX, 11 - offsetY);
  CGPathAddLineToPoint(path, NULL, 23 - offsetX, 6 - offsetY);
  CGPathAddLineToPoint(path, NULL, 11 - offsetX, 8 - offsetY);
  CGPathAddLineToPoint(path, NULL, 5 - offsetX, 13 - offsetY);
  
  CGPathCloseSubpath(path);
  
  _player.physicsBody = [SKPhysicsBody bodyWithPolygonFromPath:path];
//  [_player skt_attachDebugFrameFromPath:path color:[UIColor redColor]];
  _player.physicsBody.categoryBitMask = EntityCategoryPlayer;
  _player.physicsBody.collisionBitMask = 0;
  _player.physicsBody.contactTestBitMask = EntityCategoryObstacle | EntityCategoryGround;
  
  
}

- (void)setupSounds {
  _dingAction = [SKAction playSoundFileNamed:@"ding.wav" waitForCompletion:NO];
  _flapAction = [SKAction playSoundFileNamed:@"flapping.wav" waitForCompletion:NO];
  _whackAction = [SKAction playSoundFileNamed:@"whack.wav" waitForCompletion:NO];
  _fallingAction = [SKAction playSoundFileNamed:@"falling.wav" waitForCompletion:NO];
  _hitGroundAction = [SKAction playSoundFileNamed:@"hitGround.wav" waitForCompletion:NO];
  _popAction = [SKAction playSoundFileNamed:@"pop.wav" waitForCompletion:NO];
  _coinAction = [SKAction playSoundFileNamed:@"coin.wav" waitForCompletion:NO];
}

- (void)setupLabel
{
  _scoreLabel = [[SKLabelNode alloc]initWithFontNamed:kFontName];
  _scoreLabel.fontColor = [SKColor blackColor];
  _scoreLabel.text = @"0";
  _scoreLabel.position = CGPointMake(self.size.width/2, self.size.height - kMargin);
  _scoreLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeTop;
  _scoreLabel.zPosition = LayerUI;
  [_worldNode addChild:_scoreLabel];
  
  
}

- (void)setupTutorial {
  SKSpriteNode *tutorial = [SKSpriteNode spriteNodeWithImageNamed:@"Tutorial"];
  tutorial.position = CGPointMake((int)self.size.width * 0.5, (int)_playableHeight * 0.4 + _playableStart);
  tutorial.name = @"Tutorial";
  tutorial.zPosition = LayerUI;
  [_worldNode addChild:tutorial];
  
}

- (void)setupScoreCard
{
  if (_score > [self bestScore]) {
    [self setBestScore:_score];
  }
  
  SKSpriteNode *scoreCard = [SKSpriteNode spriteNodeWithImageNamed:@"Scorecard"];
  scoreCard.position = CGPointMake(self.size.width * 0.5, self.size.height * 0.5);
  scoreCard.name = @"Tutorial";
  scoreCard.zPosition = LayerUI;
  [_worldNode addChild:scoreCard];
  
  SKLabelNode *scoreLabel = [[SKLabelNode alloc]initWithFontNamed:kFontName];
  scoreLabel.fontColor = [SKColor whiteColor];
  scoreLabel.position = CGPointMake(-scoreCard.size.width * 0.25, -scoreCard.size.height * 0.2);
  scoreLabel.text = [NSString stringWithFormat:@"%d", _score];
  [scoreCard addChild:scoreLabel];
  
  SKLabelNode *bestScore = [[SKLabelNode alloc]initWithFontNamed:kFontName];
  bestScore.fontColor = [SKColor whiteColor];
  bestScore.position = CGPointMake(scoreCard.size.width * 0.25, -scoreCard.size.height * 0.2);
  bestScore.text = [NSString stringWithFormat:@"%d", [self bestScore]];
  [scoreCard addChild:bestScore];
  
  SKSpriteNode *gameOver = [SKSpriteNode spriteNodeWithImageNamed:@"GameOver"];
  gameOver.zPosition = LayerUI;
  gameOver.name = @"Tutorial";
  gameOver.position = CGPointMake(self.size.width / 2, self.size.height / 2 + scoreCard.size.height / 2 + kMargin + gameOver.size.height / 2);
  [_worldNode addChild:gameOver];
  
  SKSpriteNode *okButton = [SKSpriteNode spriteNodeWithImageNamed:@"okButton"];
  okButton.name = @"Tutorial";
  okButton.zPosition = LayerUI;
  okButton.position = CGPointMake(self.size.width * 0.25, self.size.height / 2 - scoreCard.size.height/2 - kMargin - okButton.size.height/2);
  [_worldNode addChild:okButton];
  
  SKSpriteNode *shareButton = [SKSpriteNode spriteNodeWithImageNamed:@"shareButton"];
  shareButton.name = @"Tutorial";
  shareButton.zPosition = LayerUI;
  shareButton.position = CGPointMake(self.size.width * 0.75, self.size.height / 2 - scoreCard.size.height/2 - kMargin - okButton.size.height/2);
  [_worldNode addChild:shareButton];
  
  gameOver.scale = 0;
  gameOver.alpha = 0;
  
  SKAction *group = [SKAction group:
  @[
    [SKAction fadeInWithDuration:kAnimationDelay],
    [SKAction scaleTo:1.0 duration:kAnimationDelay]
  ]];
  group.timingMode = SKActionTimingEaseInEaseOut;
  [gameOver runAction:[SKAction sequence:
  @[
    [SKAction waitForDuration:kAnimationDelay],
    group
    ]]];
  
  scoreCard.position = CGPointMake(self.size.width * 0.5, -self.size.height / 2);
  SKAction *moveTo = [SKAction moveTo:CGPointMake(self.size.width/2, self.size.height/2) duration:kAnimationDelay];
  moveTo.timingMode = SKActionTimingEaseInEaseOut;
  [scoreCard runAction:[SKAction sequence:
  @[
    [SKAction waitForDuration:kAnimationDelay*2],
    moveTo
    ]]];
  
  okButton.alpha = 0;
  shareButton.alpha = 0;
  
  SKAction *fadeIn = [SKAction sequence:
  @[
    [SKAction waitForDuration:kAnimationDelay *3],
    [SKAction fadeInWithDuration:kAnimationDelay]
    ]];
  
  [okButton runAction:fadeIn];
  [shareButton runAction:fadeIn];
  
  [self runAction:[SKAction waitForDuration:kAnimationDelay*4] completion:^{
    [self switchToGameOver];
  }];

}

#pragma mark Gameplay Methods

- (SKSpriteNode *)createObstacle
{
  SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithImageNamed:@"obstacle"];
  sprite.zPosition = LayerObstacle;
  
  CGFloat offsetX = sprite.frame.size.width * sprite.anchorPoint.x;
  CGFloat offsetY = sprite.frame.size.height * sprite.anchorPoint.y;
  
  CGMutablePathRef path = CGPathCreateMutable();
  
  CGPathMoveToPoint(path, NULL, 53 - offsetX, 315 - offsetY);
  CGPathAddLineToPoint(path, NULL, 53 - offsetX, 1 - offsetY);
  CGPathAddLineToPoint(path, NULL, 0 - offsetX, 0 - offsetY);
  CGPathAddLineToPoint(path, NULL, -1 - offsetX, 315 - offsetY);
  
  CGPathCloseSubpath(path);
  
  sprite.physicsBody = [SKPhysicsBody bodyWithPolygonFromPath:path];
//  [sprite skt_attachDebugFrameFromPath:path color:[UIColor redColor]];
  sprite.physicsBody.categoryBitMask = EntityCategoryObstacle;
  sprite.physicsBody.collisionBitMask = 0;
  sprite.physicsBody.contactTestBitMask = EntityCategoryPlayer;
  
  return sprite;
}

- (void)spawnObstacle
{
  SKSpriteNode *bottomObstacle = [self createObstacle];
  float startX = self.size.width + bottomObstacle.size.width / 2;
  
  float bottomObstacleMin = (_playableStart - bottomObstacle.size.height/2) + (_playableHeight * kBottomObstacleMinFraction);
  float bottomObstacleMax = (_playableStart - bottomObstacle.size.height/2) + (_playableHeight * kBottomObstacleMaxFraction);
  bottomObstacle.userData = [NSMutableDictionary dictionary];
  
  bottomObstacle.position = CGPointMake(startX, RandomFloatRange(bottomObstacleMin, bottomObstacleMax));
  bottomObstacle.name = @"BottomObstacle";
  [_worldNode addChild:bottomObstacle];
  
  SKSpriteNode *topObstacle = [self createObstacle];
  topObstacle.zRotation = DegreesToRadians(180);
  topObstacle.position = CGPointMake(
    startX,
    bottomObstacle.position.y + bottomObstacle.size.height/2 + topObstacle.size.height/2 + _player.size.height * kGapMultiplier
  );
  
  topObstacle.name = @"TopObstacle";
  
  [_worldNode addChild:topObstacle];
  
  float moveX = self.size.width + topObstacle.size.width;
  float moveDuration = moveX / kGroundSpeed;
  
  SKAction *sequence = [SKAction sequence:@[
    [SKAction moveByX:-moveX y:0 duration:moveDuration],
    [SKAction removeFromParent]
  ]];
  
  [topObstacle runAction:sequence];
  [bottomObstacle runAction:sequence];
}

- (void)startSpawning
{
  SKAction *firstDelay = [SKAction waitForDuration:kFirstSpawnDelay];
  SKAction *spawn = [SKAction performSelector:@selector(spawnObstacle) onTarget:self];
  SKAction *normalDelay = [SKAction waitForDuration:kNormalSpawnDelay];
  SKAction *spawnSequence = [SKAction sequence:@[spawn, normalDelay]];
  SKAction *foreverSpawn = [SKAction repeatActionForever:spawnSequence];
  SKAction *overallSequence = [SKAction sequence:@[firstDelay, foreverSpawn]];
  
  [self runAction:overallSequence withKey:@"Spawn"];
}

- (void)stopSpawning
{
  [self removeActionForKey:@"Spawn"];
  
  [_worldNode enumerateChildNodesWithName:@"BottomObstacle" usingBlock:^(SKNode *node, BOOL *stop) {
    [node removeAllActions];
  }];
  [_worldNode enumerateChildNodesWithName:@"TopObstacle" usingBlock:^(SKNode *node, BOOL *stop) {
    [node removeAllActions];
  }];
}

- (void)flapPlayer
{
  [self runAction:_flapAction];
  
  _playerVelocity = CGPointMake(0, kImpulse);
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  switch (_gameState) {
    case GameStateMainMenu:
      break;
    case GameStateTutorial:
      [self switchToPlay];
      break;
    case GameStatePlay:
      [self flapPlayer];
      break;
    case GameStateFalling:
      break;
    case GameStateShowingScore:
      break;
    case GameStateGameOver:
      [self startNewGame];
      break;
  }
}

#pragma mark - PhysicsContactDelegate

- (void)didBeginContact:(SKPhysicsContact *)contact
{
  SKPhysicsBody *other = (contact.bodyA.categoryBitMask == EntityCategoryPlayer ? contact.bodyB : contact.bodyA);
  if (other.categoryBitMask == EntityCategoryGround) {
    _hitGround = YES;
    return;
  }
  if (other.categoryBitMask == EntityCategoryObstacle) {
    _hitObstacle = YES;
    return;
  }
}

#pragma mark - Switch State methods

- (void)switchToShowScore
{
  _gameState = GameStateShowingScore;
  [_player removeAllActions];
  [self stopSpawning];
  
  [self setupScoreCard];
}

- (void)switchToFalling {
  _gameState = GameStateFalling;
  
  _player.texture = [SKTexture textureWithImageNamed:@"hitbird2"];
  [self runAction:[SKAction sequence:@[
   _whackAction,
   [SKAction waitForDuration:0.1],
   _fallingAction]
  ]];

  [_player removeAllActions];
  [self stopSpawning];
}

- (void)switchToTutorial
{
  _gameState = GameStateTutorial;
  [self setupBackground];
  [self setupForeground];
  [self setupPlayer];
  [self setupSounds];
  [self setupLabel];
  [self setupTutorial];
}


- (void)switchToPlay {
  
  _gameState = GameStatePlay;
  
  [_worldNode enumerateChildNodesWithName:@"Tutorial" usingBlock:^(SKNode *node, BOOL *stop) {
    [node runAction:[SKAction sequence:@[
                                         [SKAction fadeOutWithDuration:0.5],
                                         [SKAction removeFromParent]
                                         ]]];
  }];
  
  [self startSpawning];
  
  [self flapPlayer];
  
}

- (void)switchToGameOver
{
  _gameState = GameStateGameOver;
}


- (void)startNewGame
{
  [self runAction:_popAction];
  
  SKScene *newScene = [[ClassyBirdMyScene alloc] initWithSize:self.size];
  SKTransition *transition = [SKTransition fadeWithColor:[SKColor blackColor] duration:0.5];
  [self.view presentScene:newScene transition:transition];
}

#pragma mark - Check Hit Methods

- (void)checkHitGround
{
  if (_hitGround ) {
    _hitGround = NO;
    _playerVelocity = CGPointZero;
    _player.zRotation = DegreesToRadians(-90);
    _player.position = CGPointMake(_player.position.x, _playableStart + _player.size.height /2);
    _player.texture = [SKTexture textureWithImageNamed:@"deadBird"];
    [self runAction:_hitGroundAction];
    [self switchToShowScore];
  }
}

- (void)checkHitObstacle {
  if (_hitObstacle) {
    _hitObstacle = NO;
    [self switchToFalling];
  }
}


#pragma mark Update Methods

- (void)updateScore
{
  [_worldNode enumerateChildNodesWithName:@"BottomObstacle" usingBlock:^(SKNode *node, BOOL *stop) {
    SKSpriteNode *obstacle = (SKSpriteNode *)node;
    
    NSNumber *passed = obstacle.userData[@"Passed"];
    
    if (passed && passed.boolValue) return;
    
    if (_player.position.x > obstacle.position.x + obstacle.size.width/2) {
      _score += 1;
      _scoreLabel.text = [NSString stringWithFormat:@"%d", _score];
      
      [self runAction:_coinAction];
      obstacle.userData[@"Passed"] = @YES;
    }
    
  }];
}


- (void)updatePlayer
{

  // Apply gravity
  CGPoint gravity = CGPointMake(0, kGravity);
  CGPoint gravityStep = CGPointMultiplyScalar(gravity, _dt);
  _playerVelocity = CGPointAdd(_playerVelocity, gravityStep);
  
  CGPoint velocityStep = CGPointMultiplyScalar(_playerVelocity, _dt);
  _player.position = CGPointAdd(_player.position, velocityStep);

}

- (void)updateForeground
{
  [_worldNode enumerateChildNodesWithName:@"Foreground" usingBlock:^(SKNode *node, BOOL *stop) {
    SKSpriteNode *foreground = (SKSpriteNode *)node;
    CGPoint movementAmount = CGPointMake(-kGroundSpeed *_dt, 0);
    foreground.position = CGPointAdd(foreground.position, movementAmount);
    
    if (foreground.position.x < -foreground.size.width) {
      foreground.position = CGPointAdd(foreground.position, CGPointMake(foreground.size.width * kNumForegrounds, 0));
    }
    
  }];
}

-(void)update:(CFTimeInterval)currentTime {
  
  if (_lastUpdateTime) {
    _dt = currentTime - _lastUpdateTime;
  } else {
    _dt = 0;
  }
  
  
  _lastUpdateTime = currentTime;
  
  switch (_gameState) {
    case GameStateMainMenu:
      break;
    case GameStateTutorial:
      break;
    case GameStatePlay:
      [self checkHitGround];
      [self checkHitObstacle];
      [self updateForeground];
      [self updatePlayer];
      [self updateScore];
      break;
    case GameStateFalling:
      [self checkHitGround];
      [self updatePlayer];
      break;
    case GameStateShowingScore:
      break;
    case GameStateGameOver:
      break;
  }
  
}

#pragma mark - Score Methods

- (int)bestScore {
  return [[NSUserDefaults standardUserDefaults] integerForKey:@"BestScore"];
}

- (void)setBestScore:(int)bestScore {
  [[NSUserDefaults standardUserDefaults] setInteger:bestScore forKey:@"BestScore"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
