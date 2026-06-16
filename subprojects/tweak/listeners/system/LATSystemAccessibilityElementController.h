//
//  LATSystemAccessibilityElementController.h
//  libactivator
//
//  Created by Lessica on 6/17/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AXElement;

NS_ASSUME_NONNULL_BEGIN

extern NSUInteger const LATSystemAccessibilityBackButtonTrait;
extern int const LATSystemAccessibilityEscapeAction;

typedef BOOL (^LATSystemAccessibilityElementAction)(NSArray<AXElement *> *elements);

@interface LATSystemAccessibilityElementController : NSObject

- (BOOL)performWithCurrentElementsForListenerName:(NSString *)listenerName
                                   retryUnhandled:(BOOL)retryUnhandled
                                           action:(LATSystemAccessibilityElementAction)action;

- (BOOL)performEscapeActionForElements:(NSArray<AXElement *> *)elements listenerName:(NSString *)listenerName;

- (BOOL)pressFirstElementInElements:(NSArray<AXElement *> *)elements
                 matchingIdentifier:(NSString *)identifier
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason;
- (BOOL)pressFirstElementInElements:(NSArray<AXElement *> *)elements
                      matchingTitle:(NSString *)title
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason;
- (BOOL)pressFirstElementInElements:(NSArray<AXElement *> *)elements
                     matchingTitles:(NSArray<NSString *> *)titles
                identifierHasPrefix:(nullable NSString *)identifierPrefix
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason;
- (BOOL)pressFirstElementInElements:(NSArray<AXElement *> *)elements
                      matchingTrait:(NSUInteger)trait
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason;
- (BOOL)pressElement:(AXElement *)element;

@end

NS_ASSUME_NONNULL_END
