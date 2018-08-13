//
//  AppDelegate.m
//  SimulatorShortcut
//
//  Created by Chasel on 2018/8/13.
//  Copyright © 2018 Chasel. All rights reserved.
//


#import "SimulatorShortcutManager.h"
#import <objc/message.h>

#if TARGET_OS_SIMULATOR

@interface UIEvent (SimulatorShortcutManager)

@property (nonatomic, strong) NSString *_modifiedInput;
@property (nonatomic, strong) NSString *_unmodifiedInput;
@property (nonatomic, assign) UIKeyModifierFlags _modifierFlags;
@property (nonatomic, assign) BOOL _isKeyDown;
@property (nonatomic, assign) long _keyCode;

@end

@interface KeyInput : NSObject

@property (nonatomic, strong) NSString *key;
@property (nonatomic, assign) UIKeyModifierFlags flags;

@end

void SwizzleInstanceMethodWithBlock(Class class, SEL original, id block, SEL replaced)
{
    Method originalMethod = class_getInstanceMethod(class, original);
    IMP implementation = imp_implementationWithBlock(block);
    
    class_addMethod(class, replaced, implementation, method_getTypeEncoding(originalMethod));
    Method newMethod = class_getInstanceMethod(class, replaced);
    method_exchangeImplementations(originalMethod, newMethod);
}

SEL SwizzledSelectorForSelector(SEL selector)
{
    return NSSelectorFromString([NSString stringWithFormat:@"_swizzle_%x_%@", arc4random(), NSStringFromSelector(selector)]);
}

@implementation KeyInput

+ (instancetype)keyInputForKey:(NSString *)key flags:(UIKeyModifierFlags)flags
{
    KeyInput *keyInput = [[self alloc] init];
    if (keyInput) {
        keyInput.key = key;
        keyInput.flags = flags;
    }
    return keyInput;
}

- (BOOL)isEqual:(id)object
{
    BOOL isEqual = NO;
    if ([object isKindOfClass:[KeyInput class]]) {
        KeyInput *keyInput = (KeyInput *)object;
        isEqual = [self.key isEqualToString:keyInput.key] && self.flags == keyInput.flags;
    }
    return isEqual;
}

@end


@implementation SimulatorShortcutManager
{
    NSCache *_actions;
}

+ (instancetype)sharedManager
{
    static SimulatorShortcutManager *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[self alloc] init];
        _sharedInstance->_actions = [[NSCache alloc] init];
        SEL handleKeyEventSelector = NSSelectorFromString(@"handleKeyUIEvent:");
        SEL replacedSelector = SwizzledSelectorForSelector(handleKeyEventSelector);
        SwizzleInstanceMethodWithBlock([UIApplication class], handleKeyEventSelector, ^(UIApplication *application, UIEvent *event) {
            [[[self class] sharedManager] handleKeyUIEvent:event];
            ((void(*)(id, SEL, id))objc_msgSend)(application, replacedSelector, event);
        }, replacedSelector);
    });
    return _sharedInstance;
}

+ (void)registerSimulatorShortcutWithKey:(NSString *)key modifierFlags:(UIKeyModifierFlags)flags action:(dispatch_block_t)action
{
    KeyInput *keyInput = [KeyInput keyInputForKey:key flags:flags];
    [[SimulatorShortcutManager sharedManager]->_actions setObject:action forKey:keyInput];
}

- (void)handleKeyUIEvent:(UIEvent *)event
{
    BOOL isKeyDown = NO;
    NSString *modifiedInput = nil;
    NSString *unmodifiedInput = nil;
    UIKeyModifierFlags flags = 0;
    if ([event respondsToSelector:NSSelectorFromString(@"_isKeyDown")]) {
        isKeyDown = [event _isKeyDown];
    }
    
    if ([event respondsToSelector:NSSelectorFromString(@"_modifiedInput")]) {
        modifiedInput = [event _modifiedInput];
    }
    
    if ([event respondsToSelector:NSSelectorFromString(@"_unmodifiedInput")]) {
        unmodifiedInput = [event _unmodifiedInput];
    }
    
    if ([event respondsToSelector:NSSelectorFromString(@"_modifierFlags")]) {
        flags = [event _modifierFlags];
    }
    
    if (isKeyDown && [modifiedInput length] > 0) {
        KeyInput *keyInput = [KeyInput keyInputForKey:unmodifiedInput flags:flags];
        dispatch_block_t block = [_actions objectForKey:keyInput];
        if (block) {
            block();
        }
    }
}

@end

#endif
