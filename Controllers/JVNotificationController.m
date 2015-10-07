#import <Growl/GrowlApplicationBridge.h>
#import "JVNotificationController.h"
#import "KABubbleWindowController.h"
#import "KABubbleWindowView.h"

#define GrowlApplicationBridge NSClassFromString( @"GrowlApplicationBridge" )

static JVNotificationController *sharedInstance = nil;

@interface JVNotificationController (JVNotificationControllerPrivate) <GrowlApplicationBridgeDelegate, KABubbleWindowControllerDelegate>
- (void) _bounceIconOnce;
- (void) _bounceIconContinuously;
- (void) _showBubbleForIdentifier:(NSString *) identifier withContext:(NSDictionary *) context andPrefs:(NSDictionary *) eventPrefs;
- (void) _playSound:(NSString *) path;
@end

#pragma mark -

@implementation JVNotificationController
+ (JVNotificationController *) defaultController {
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_bubbles = [NSMutableDictionary dictionary];
		_sounds = [[NSMutableDictionary alloc] init];

		if( floor( NSAppKitVersionNumber ) < NSAppKitVersionNumber10_8 )
			_useGrowl = ( GrowlApplicationBridge && ! [[[NSUserDefaults standardUserDefaults] objectForKey:@"DisableGrowl"] boolValue] );
		else [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

		if( _useGrowl ) [GrowlApplicationBridge setGrowlDelegate:self];
	}

	return self;
}

- (void) dealloc {
	[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	//This will never get called:
	//if( self == sharedInstance ) sharedInstance = nil;
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context {
	NSDictionary *eventPrefs = [[NSUserDefaults standardUserDefaults] dictionaryForKey:[NSString stringWithFormat:@"JVNotificationSettings %@", identifier]];

	if( [eventPrefs[@"playSound"] boolValue] && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatNotificationsMuted"] ) {
		if( [eventPrefs[@"playSoundOnlyIfBackground"] boolValue] && ! [[NSApplication sharedApplication] isActive] )
			[self _playSound:eventPrefs[@"soundPath"]];
		else if( ! [eventPrefs[@"playSoundOnlyIfBackground"] boolValue] )
			[self _playSound:eventPrefs[@"soundPath"]];
	}

	if( [eventPrefs[@"bounceIcon"] boolValue] ) {
		if( [eventPrefs[@"bounceIconUntilFront"] boolValue] )
			[self _bounceIconContinuously];
		else [self _bounceIconOnce];
	}

	if( [eventPrefs[@"showBubble"] boolValue] ) {
		if( [eventPrefs[@"showBubbleOnlyIfBackground"] boolValue] && ! [[NSApplication sharedApplication] isActive] )
			[self _showBubbleForIdentifier:identifier withContext:context andPrefs:eventPrefs];
		else if( ! [eventPrefs[@"showBubbleOnlyIfBackground"] boolValue] )
			[self _showBubbleForIdentifier:identifier withContext:context andPrefs:eventPrefs];
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSString * ), @encode( NSDictionary * ), @encode( NSDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( performNotification:withContextInfo:andPreferences: )];
	MVAddUnsafeUnretainedAddress(identifier, 2)
	MVAddUnsafeUnretainedAddress(context, 3)
	MVAddUnsafeUnretainedAddress(eventPrefs, 4)

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) userNotificationCenter:(NSUserNotificationCenter *) center didActivateNotification:(NSUserNotification *) notification {
	id target = (notification.userInfo)[@"target"];
	SEL action = NSSelectorFromString((notification.userInfo)[@"action"]);

	if ( target && action && [target respondsToSelector:action] )
		[target performSelector:action withObject:nil];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
	// Always show when asked, because we have our own preference for "only notify when not active".
	return YES;
}

@end

#pragma mark -

@implementation JVNotificationController (JVNotificationControllerPrivate)
- (void) _bounceIconOnce {
	[[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];
}

- (void) _bounceIconContinuously {
	[[NSApplication sharedApplication] requestUserAttention:NSCriticalRequest];
}

- (void) _showBubbleForIdentifier:(NSString *) identifier withContext:(NSDictionary *) context andPrefs:(NSDictionary *) eventPrefs {
	KABubbleWindowController *bubble = nil;
	NSImage *icon = context[@"image"];
	id title = context[@"title"];
	id description = context[@"description"];

	if( ! icon ) icon = [[NSApplication sharedApplication] applicationIconImage];

	if( _useGrowl ) {
		NSString *desc = description;
		if( [desc isKindOfClass:[NSAttributedString class]] ) desc = [description string];
		NSString *programName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
		NSDictionary *notification = @{GROWL_APP_NAME: programName,
			GROWL_NOTIFICATION_NAME: identifier,
			GROWL_NOTIFICATION_TITLE: title,
			GROWL_NOTIFICATION_DESCRIPTION: desc,
			GROWL_NOTIFICATION_ICON_DATA: [icon TIFFRepresentation],
			GROWL_NOTIFICATION_IDENTIFIER: context[@"coalesceKey"],
			// this next key is not guaranteed to be non-nil
			// make sure it stays last, unless you want to ensure it's non-nil
			GROWL_NOTIFICATION_STICKY: eventPrefs[@"keepBubbleOnScreen"]};
		[GrowlApplicationBridge notifyWithDictionary:notification];
	} else if( NSAppKitVersionNumber10_8 > floor( NSAppKitVersionNumber ) ) {
		if( ( bubble = _bubbles[context[@"coalesceKey"]] ) ) {
			[(id)bubble setTitle:title];
			[(id)bubble setText:description];
			[(id)bubble setIcon:icon];
		} else {
			bubble = [KABubbleWindowController bubbleWithTitle:title text:description icon:icon];
		}

		[bubble setAutomaticallyFadesOut:(! [eventPrefs[@"keepBubbleOnScreen"] boolValue] )];
		[bubble setTarget:context[@"target"]];
		[bubble setAction:NSSelectorFromString( context[@"action"] )];
		[bubble setRepresentedObject:context[@"representedObject"]];
		[bubble startFadeIn];

		if( [(NSString *)context[@"coalesceKey"] length] ) {
			[bubble setDelegate:self];
			_bubbles[context[@"coalesceKey"]] = bubble;
		}
	} else {
		NSUserNotification *notification = [[NSUserNotification alloc] init];
		notification.title = title;

		NSString *notificationSubtitle = context[@"subtitle"];
		if (!notificationSubtitle.length) {
			if ([description isKindOfClass:[NSString class]]) {
				notificationSubtitle = description;
			}
			else if ([description isKindOfClass:[NSAttributedString class]]) {
				notificationSubtitle = [description string];
			}
		}
		notification.subtitle = notificationSubtitle;

		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
	}
}

- (void) bubbleDidFadeOut:(KABubbleWindowController *) bubble {
	NSMutableDictionary *bubbles = [_bubbles copy];
	for( NSString *key in bubbles ) {
		KABubbleWindowController *cBubble = bubbles[key];
		if( cBubble == bubble )
			[_bubbles removeObjectForKey:key];
	}
}

- (void) _playSound:(NSString *) path {
	if( ! path ) return;

	if( ! [path isAbsolutePath] )
		path = [[NSString stringWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];

	NSSound *sound;
	if( ! (sound = _sounds[path]) ) {
		sound = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
		_sounds[path] = sound;
	}

	// When run on a laptop using battery power, the play method may block while the audio
	// hardware warms up.  If it blocks, the sound WILL NOT PLAY after the block ends.
	// To get around this, we check to make sure the sound is playing, and if it isn't
	// we call the play method again.

	[sound play];
	if( ! [sound isPlaying] ) [sound play];
}

- (NSDictionary *) registrationDictionaryForGrowl {
	NSMutableArray *notifications = [NSMutableArray array];
	for( NSDictionary *info in [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"notifications" ofType:@"plist"]] ) {
		if( ! info[@"seperator"] )
			[notifications addObject:info[@"identifier"]];
		
	}

	return @{GROWL_NOTIFICATIONS_ALL: notifications, GROWL_NOTIFICATIONS_DEFAULT: notifications};
}
@end
