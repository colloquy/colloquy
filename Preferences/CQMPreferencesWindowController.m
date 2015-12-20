//
//  CQMPreferencesWindowController.m
//  Colloquy (Old)
//
//  Created by Alexander Kempgen on 19.12.15.
//
//

#import "CQMPreferencesWindowController.h"

#import "JVGeneralPreferencesViewController.h"
#import "JVInterfacePreferencesViewController.h"
#import "JVAppearancePreferencesViewController.h"
#import "JVNotificationPreferencesViewController.h"
#import "JVFileTransferPreferencesViewController.h"
#import "JVTranscriptPreferencesViewController.h"
#import "JVBehaviorPreferencesViewController.h"


@implementation CQMPreferencesWindowController

- (instancetype)init
{
	// Set up built in preferences view controllers.
	JVGeneralPreferencesViewController *generalPreferences = [[JVGeneralPreferencesViewController alloc] init];
	JVInterfacePreferencesViewController *interfacePreferences = [[JVInterfacePreferencesViewController alloc] init];
	JVAppearancePreferencesViewController *appearancePreferences = [[JVAppearancePreferencesViewController alloc] init];
	JVNotificationPreferencesViewController *notificationPreferences = [[JVNotificationPreferencesViewController alloc] init];
	JVFileTransferPreferencesViewController *fileTransferPreferences = [[JVFileTransferPreferencesViewController alloc] init];
	JVTranscriptPreferencesViewController *transcriptPreferences = [[JVTranscriptPreferencesViewController alloc] init];
	JVBehaviorPreferencesViewController *behaviorPreferences = [[JVBehaviorPreferencesViewController alloc] init];
	
	NSArray<NSViewController<MASPreferencesViewController> *> *viewControllers = @[
																				   generalPreferences,
																				   interfacePreferences,
																				   appearancePreferences,
																				   notificationPreferences,
																				   fileTransferPreferences,
																				   transcriptPreferences,
																				   behaviorPreferences
																				   ];
	
	self = [super initWithViewControllers:viewControllers];
	if (self)
	{
		_generalPreferences = generalPreferences;
		_interfacePreferences = interfacePreferences;
		_appearancePreferences = appearancePreferences;
		_notificationPreferences = notificationPreferences;
		_fileTransferPreferences = fileTransferPreferences;
		_transcriptPreferences = transcriptPreferences;
		_behaviorPreferences = behaviorPreferences;
	}
	return self;
}

@end
