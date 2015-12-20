//
//  CQMPreferencesWindowController.h
//  Colloquy (Old)
//
//  Created by Alexander Kempgen on 19.12.15.
//
//

#import <Cocoa/Cocoa.h>

#import <MASPreferences.h>

@class JVGeneralPreferencesViewController;
@class JVInterfacePreferencesViewController;
@class JVAppearancePreferencesViewController;
@class JVNotificationPreferencesViewController;
@class JVFileTransferPreferencesViewController;
@class JVTranscriptPreferencesViewController;
@class JVBehaviorPreferencesViewController;


@interface CQMPreferencesWindowController : MASPreferencesWindowController

@property(nonatomic, strong, readonly) JVGeneralPreferencesViewController *generalPreferences;
@property(nonatomic, strong, readonly) JVInterfacePreferencesViewController *interfacePreferences;
@property(nonatomic, strong, readonly) JVAppearancePreferencesViewController *appearancePreferences;
@property(nonatomic, strong, readonly) JVNotificationPreferencesViewController *notificationPreferences;
@property(nonatomic, strong, readonly) JVFileTransferPreferencesViewController *fileTransferPreferences;
@property(nonatomic, strong, readonly) JVTranscriptPreferencesViewController *transcriptPreferences;
@property(nonatomic, strong, readonly) JVBehaviorPreferencesViewController *behaviorPreferences;

- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end
