//
//  LATestListener.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestListener : NSObject <LAListener>
@property(nonatomic, assign) NSInteger receiveCount;
@property(nonatomic, assign) NSInteger abortCount;
@property(nonatomic, assign) NSInteger previewCount;
@property(nonatomic, assign) NSInteger deactivateCount;
@property(nonatomic, assign) NSInteger otherHandledCount;
@property(nonatomic, assign) NSInteger modeChangeCount;
@property(nonatomic, assign) NSInteger removalCount;
@property(nonatomic, assign) NSUInteger removalRequestCount;
@property(nonatomic, assign) NSUInteger smallIconRequestCount;
@property(nonatomic, assign) NSUInteger localizedTitleRequestCount;
@property(nonatomic, assign) NSUInteger localizedGroupRequestCount;
@property(nonatomic, assign) NSUInteger localizedDescriptionRequestCount;
@property(nonatomic, assign) NSInteger unlockingCount;
@property(nonatomic, assign) NSInteger didNotHandleCount;
@property(nonatomic, assign) BOOL handlesReceivedEvents;
@property(nonatomic, assign) BOOL handlesAbortEvents;
@property(nonatomic, assign) BOOL requiresNoTouchEvents;
@property(nonatomic, assign) BOOL supportsRemoval;
@property(nonatomic, assign) BOOL requiresAssignment;
@property(nonatomic, assign) BOOL needsPoweredDisplay;
@property(nonatomic, copy) NSArray<NSString *> *compatibleModes;
@property(nonatomic, copy) NSArray<NSString *> *exclusiveGroups;
@property(nonatomic, copy, nullable) NSArray<NSString *> *compatibleEventNames;
@property(nonatomic, copy, nullable) NSArray<NSString *> *incompatibleListenerNames;
@property(nonatomic, copy, nullable) NSString *localizedTitle;
@property(nonatomic, copy, nullable) NSString *localizedGroup;
@property(nonatomic, copy, nullable) NSString *localizedDescription;
@property(nonatomic, strong, nullable) UIImage *smallIconImage;
@property(nonatomic, copy, nullable) NSString *lastReceivedEventName;
@property(nonatomic, copy, nullable) NSString *lastReceivedEventMode;
@property(nonatomic, copy, nullable) NSDictionary *lastReceivedUserInfo;
@property(nonatomic, copy, nullable) NSString *lastAbortedEventName;
@end

NS_ASSUME_NONNULL_END

