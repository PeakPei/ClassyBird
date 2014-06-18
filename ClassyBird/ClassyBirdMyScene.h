//
//  ClassyBirdMyScene.h
//  ClassyBird
//

//  Copyright (c) 2014 Aaron Rama. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

typedef NS_ENUM(int, GameState) {
  GameStateMainMenu,
  GameStateTutorial,
  GameStatePlay,
  GameStateFalling,
  GameStateShowingScore,
  GameStateGameOver
};

@interface ClassyBirdMyScene : SKScene


@end
