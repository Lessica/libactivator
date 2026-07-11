//
//  LATestEventDataSource.h
//  libactivator
//
//  Created by Lessica on 6/10/26.
//  Copyright © 2026 Lessica. All rights reserved.
//

#import <Activator/Activator.h>

NS_ASSUME_NONNULL_BEGIN

@interface LATestEventDataSource : NSObject <LAEventDataSource>
@property(nonatomic, copy) NSArray<NSString *> *compatibleModes;
@property(nonatomic, assign) BOOL supportsUnlockingDeviceToSend;
@property(nonatomic, assign) BOOL hidden;
@property(nonatomic, assign) BOOL requiresAssignment;
@property(nonatomic, assign) BOOL unprotectedEvent;
@property(nonatomic, assign) BOOL supportsRemoval;
@property(nonatomic, assign) NSInteger removalCount;
@property(nonatomic, copy, nullable) void (^removalHandler)(void);
@property(nonatomic, copy, nullable) NSString *configurationClassName;
@property(nonatomic, strong, nullable) NSBundle *configurationBundle;
@property(nonatomic, strong, nullable) id configuration;
@property(nonatomic, strong, nullable) id lastSavedConfiguration;
@property(nonatomic, copy, nullable) void (^configurationDescriptorRequestHandler)(void);
@property(nonatomic, assign) NSInteger configurationRequestCount;
@property(nonatomic, assign) NSInteger configurationSaveCount;
@end

NS_ASSUME_NONNULL_END
