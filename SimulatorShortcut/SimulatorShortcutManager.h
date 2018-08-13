//
//  AppDelegate.m
//  SimulatorShortcut
//
//  Created by Chasel on 2018/8/13.
//  Copyright © 2018 Chasel. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SimulatorShortcutManager : NSObject

+ (void)registerSimulatorShortcutWithKey:(NSString *)key modifierFlags:(UIKeyModifierFlags)flags action:(dispatch_block_t)action;

@end
