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

static NSString *const LATSystemDictationKeyboardAccessibilityIdentifierPrefix = @"0:";

@interface LATSystemDictationController ()
@property(nonatomic, strong) LATSystemAccessibilityElementController *accessibilityElementController;
@end

@implementation LATSystemDictationController

#pragma mark - Localized Titles

+ (NSArray<NSString *> *)startAccessibilityTitles {
    return @[
        @"听写",       @"聽寫",      @"Dictation",  @"Dictate",   @"Diktat",    @"Dicter",     @"Dictée",
        @"Dictado",    @"Dettatura", @"Ditado",     @"Diktering", @"Diktafon",  @"Диктовка",   @"Диктування",
        @"Dikte",      @"Sanelu",    @"Dyktowanie", @"Dikteer",   @"Diktování", @"Diktovanie", @"Diktálás",
        @"Dikte Etme", @"إملاء",     @"הכתבה",      @"डिक्टेशन",    @"音声入力",  @"받아쓰기",   @"การป้อนตามคำบอก"
    ];
}

+ (NSArray<NSString *> *)stopAccessibilityTitles {
    return @[
        @"键盘",         @"鍵盤",       @"Keyboard",    @"Tastatur",   @"Clavier",       @"Teclado",
        @"Tastiera",     @"Teclat",     @"Toetsenbord", @"Klawiatura", @"Klávesnice",    @"Klávesnica",
        @"Billentyűzet", @"Klavye",     @"Клавиатура",  @"Клавіатура", @"لوحة المفاتيح", @"מקלדת",
        @"कीबोर्ड",       @"キーボード", @"키보드",      @"แป้นพิมพ์"
    ];
}

#pragma mark - Lifecycle

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

#pragma mark - Public API

- (BOOL)startDictationForListenerName:(NSString *)listenerName {
    NSString *copiedListenerName = [listenerName copy];
    BOOL requestSubmitted = [self.accessibilityElementController
        performWithCurrentElementsForListenerName:copiedListenerName
                                   retryUnhandled:YES
                                           action:^BOOL(NSArray<AXElement *> *elements) {
                                               BOOL handled = [self.accessibilityElementController
                                                   pressFirstElementInElements:elements
                                                                matchingTitles:self.class.stopAccessibilityTitles
                                                           identifierHasPrefix:nil
                                                                  listenerName:copiedListenerName
                                                                        reason:@"keyboard dictation stop target"];
                                               if (handled) {
                                                   return YES;
                                               }

                                               handled = [self.accessibilityElementController
                                                   pressFirstElementInElements:elements
                                                                matchingTitles:self.class.startAccessibilityTitles
                                                           identifierHasPrefix:
                                                               LATSystemDictationKeyboardAccessibilityIdentifierPrefix
                                                                  listenerName:copiedListenerName
                                                                        reason:@"keyboard dictation start target"];
                                               if (!handled) {
                                                   HBLogDebug(@"No keyboard dictation accessibility target handled "
                                                              @"system action %@",
                                                              copiedListenerName ?: @"");
                                               }
                                               return handled;
                                           }];
    if (!requestSubmitted) {
        HBLogError(@"Unable to submit keyboard dictation accessibility request for system action %@",
                   copiedListenerName ?: @"");
    }
    return YES;
}

@end
