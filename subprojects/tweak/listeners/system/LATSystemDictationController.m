//
//  LATSystemDictationController.m
//  libactivator
//
//  Created by Lessica on 6/17/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import "system/LATSystemDictationController.h"

#import "system/LATSystemAccessibilityElementController.h"

#import <HBLog.h>

static NSString *const LATKeyboardAccessibilityIdentifierPrefix = @"0:";

static NSArray<NSString *> *LATKeyboardDictationStartTitles(void) {
    return @[
        @"听写",
        @"聽寫",
        @"Dictation",
        @"Dictate",
        @"Diktat",
        @"Dicter",
        @"Dictée",
        @"Dictado",
        @"Dettatura",
        @"Ditado",
        @"Diktering",
        @"Diktafon",
        @"Диктовка",
        @"Диктування",
        @"Dikte",
        @"Sanelu",
        @"Dyktowanie",
        @"Dikteer",
        @"Diktování",
        @"Diktovanie",
        @"Diktálás",
        @"Dikte Etme",
        @"إملاء",
        @"הכתבה",
        @"डिक्टेशन",
        @"音声入力",
        @"받아쓰기",
        @"การป้อนตามคำบอก"
    ];
}

static NSArray<NSString *> *LATKeyboardDictationStopTitles(void) {
    return @[
        @"键盘",
        @"鍵盤",
        @"Keyboard",
        @"Tastatur",
        @"Clavier",
        @"Teclado",
        @"Tastiera",
        @"Teclat",
        @"Toetsenbord",
        @"Klawiatura",
        @"Klávesnice",
        @"Klávesnica",
        @"Billentyűzet",
        @"Klavye",
        @"Клавиатура",
        @"Клавіатура",
        @"لوحة المفاتيح",
        @"מקלדת",
        @"कीबोर्ड",
        @"キーボード",
        @"키보드",
        @"แป้นพิมพ์"
    ];
}

@interface LATSystemDictationController ()
@property(nonatomic, strong) LATSystemAccessibilityElementController *accessibilityElementController;
@end

@implementation LATSystemDictationController

- (instancetype)init {
    return [self initWithAccessibilityElementController:[[LATSystemAccessibilityElementController alloc] init]];
}

- (instancetype)initWithAccessibilityElementController:
    (LATSystemAccessibilityElementController *)accessibilityElementController {
    self = [super init];
    if (self) {
        _accessibilityElementController = accessibilityElementController;
    }
    return self;
}

- (BOOL)startDictationForListenerName:(NSString *)listenerName {
    NSString *copiedListenerName = [listenerName copy];
    return [self.accessibilityElementController
        performWithCurrentElementsForListenerName:copiedListenerName
                                   retryUnhandled:YES
                                           action:^BOOL(NSArray *elements) {
                                               BOOL handled = [self.accessibilityElementController
                                                   pressFirstElementInElements:elements
                                                                matchingTitles:LATKeyboardDictationStopTitles()
                                                          identifierHasPrefix:nil
                                                                  listenerName:copiedListenerName
                                                                        reason:@"keyboard dictation stop target"];
                                               if (handled) {
                                                   return YES;
                                               }

                                               handled = [self.accessibilityElementController
                                                   pressFirstElementInElements:elements
                                                                matchingTitles:LATKeyboardDictationStartTitles()
                                                          identifierHasPrefix:LATKeyboardAccessibilityIdentifierPrefix
                                                                  listenerName:copiedListenerName
                                                                        reason:@"keyboard dictation start target"];
                                               if (!handled) {
                                                   HBLogDebug(@"No keyboard dictation accessibility target handled system action %@",
                                                              copiedListenerName ?: @"");
                                               }
                                               return handled;
                                           }];
}

@end
