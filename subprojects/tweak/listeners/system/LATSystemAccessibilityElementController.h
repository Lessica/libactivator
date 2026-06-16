//
//  LATSystemAccessibilityElementController.h
//  libactivator
//
//  Created by Lessica on 6/17/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern unsigned long long const LATSystemAccessibilityBackButtonTrait;
extern int const LATSystemAccessibilityEscapeAction;

typedef BOOL (^LATSystemAccessibilityElementAction)(NSArray *elements);

@interface LATSystemAccessibilityElementController : NSObject

- (BOOL)performWithCurrentElementsForListenerName:(NSString *)listenerName
                                   retryUnhandled:(BOOL)retryUnhandled
                                           action:(LATSystemAccessibilityElementAction)action;
- (BOOL)pressFirstElementInElements:(NSArray *)elements
                      matchingTrait:(unsigned long long)trait
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason;
- (BOOL)pressFirstElementInElements:(NSArray *)elements
                       matchingTitle:(NSString *)title
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason;
- (BOOL)pressFirstElementInElements:(NSArray *)elements
                     matchingTitles:(NSArray<NSString *> *)titles
                 identifierHasPrefix:(nullable NSString *)identifierPrefix
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason;
- (BOOL)pressFirstElementInElements:(NSArray *)elements
                 matchingIdentifier:(NSString *)identifier
                       listenerName:(NSString *)listenerName
                             reason:(NSString *)reason;
- (BOOL)performEscapeActionForElements:(NSArray *)elements listenerName:(NSString *)listenerName;
- (BOOL)pressElement:(id)element;

@end

NS_ASSUME_NONNULL_END
