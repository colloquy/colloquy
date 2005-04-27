#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/NSMethodSignatureAdditions.h>
#import <Growl/GrowlApplicationBridge.h>
#import "JVNotificationController.h"
#import "KABubbleWindowController.h"
#import "KABubbleWindowView.h"

static JVNotificationController *sharedInstance = nil;

@interface JVNotificationController (JVNotificationControllerPrivate) <GrowlApplicationBridgeDelegate>
- (void) _bounceIconOnce;
- (void) _bounceIconContinuously;
- (void) _showBubbleForIdentifier:(NSString *) identifier withContext:(NSDictionary *) context andPrefs:(NSDictionary *) eventPrefs;
- (void) _playSound:(NSString *) path;
@end

#pragma mark -

@implementation JVNotificationController
+ (JVNotificationController *) defaultManager {
	extern JVNotificationController *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_bubbles = [[NSMutableDictionary dictionary] retain];
		if( [GrowlApplicationBridge isGrowlInstalled] && ! [[[NSUserDefaults standardUserDefaults] objectForKey:@"DisableGrowl"] boolValue] ) {
			[GrowlApplicationBridge setGrowlDelegate:self];
		}
	}

	return self;
}

- (void) dealloc {
	extern JVNotificationController *sharedInstance;

	[_bubbles release];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	_bubbles = nil;

	[super dealloc];
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context {
	NSDictionary *eventPrefs = [[NSUserDefaults standardUserDefaults] dictionaryForKey:[NSString stringWithFormat:@"JVNotificationSettings %@", identifier]];

	if( [[eventPrefs objectForKey:@"playSound"] boolValue] && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatNotificationsMuted"] )
		[self _playSound:[eventPrefs objectForKey:@"soundPath"]];

	if( [[eventPrefs objectForKey:@"bounceIcon"] boolValue] ) {
		if( [[eventPrefs objectForKey:@"bounceIconUntilFront"] boolValue] )
			[self _bounceIconContinuously];
		else [self _bounceIconOnce];
	}

	if( [[eventPrefs objectForKey:@"showBubble"] boolValue] ) {
		if( [[eventPrefs objectForKey:@"showBubbleOnlyIfBackground"] boolValue] && ! [[NSApplication sharedApplication] isActive] )
			[self _showBubbleForIdentifier:identifier withContext:context andPrefs:eventPrefs];
		else if( ! [[eventPrefs objectForKey:@"showBubbleOnlyIfBackground"] boolValue] )
			[self _showBubbleForIdentifier:identifier withContext:context andPrefs:eventPrefs];
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSString * ), @encode( NSDictionary * ), @encode( NSDictionary * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( performNotification:withContextInfo:andPreferences: )];
	[invocation setArgument:&identifier atIndex:2];
	[invocation setArgument:&context atIndex:3];
	[invocation setArgument:&eventPrefs atIndex:4];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
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

#ifndef GROWL_NOTIFICATION_IDENTIFIER
#define GROWL_NOTIFICATION_IDENTIFIER @"GrowlNotificationIdentifier"
#endif

- (void) _showBubbleForIdentifier:(NSString *) identifier withContext:(NSDictionary *) context andPrefs:(NSDictionary *) eventPrefs {
	KABubbleWindowController *bubble = nil;
	NSImage *icon = [context objectForKey:@"image"];
	id title = [context objectForKey:@"title"];
	id description = [context objectForKey:@"description"];

	if( ! icon ) icon = [[NSApplication sharedApplication] applicationIconImage];

	if( [GrowlApplicationBridge isGrowlInstalled] && ! [[[NSUserDefaults standardUserDefaults] objectForKey:@"DisableGrowl"] boolValue] ) {
		NSString *desc = description;
		if( [desc isKindOfClass:[NSAttributedString class]] ) desc = [description string];
		NSString *programName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
		NSDictionary *notification = [NSDictionary dictionaryWithObjectsAndKeys:
			programName, GROWL_APP_NAME,
			identifier, GROWL_NOTIFICATION_NAME,
			title, GROWL_NOTIFICATION_TITLE,
			desc, GROWL_NOTIFICATION_DESCRIPTION,
			[icon TIFFRepresentation], GROWL_NOTIFICATION_ICON,
			[context objectForKey:@"coalesceKey"], GROWL_NOTIFICATION_IDENTIFIER,
			// this next key is not guaranteed to be non-nil
			// make sure it stays last, unless you want to ensure it's non-nil
			[eventPrefs objectForKey:@"keepBubbleOnScreen"], GROWL_NOTIFICATION_STICKY,
			nil];
		[GrowlApplicationBridge notifyWithDictionary:notification];
	} else {
		if( ( bubble = [_bubbles objectForKey:[context objectForKey:@"coalesceKey"]] ) ) {
			[(id)bubble setTitle:title];
			[(id)bubble setText:description];
			[(id)bubble setIcon:icon];
		} else {
			bubble = [KABubbleWindowController bubbleWithTitle:title text:description icon:icon];
		}

		[bubble setAutomaticallyFadesOut:(! [[eventPrefs objectForKey:@"keepBubbleOnScreen"] boolValue] )];
		[bubble setTarget:[context objectForKey:@"target"]];
		[bubble setAction:NSSelectorFromString( [context objectForKey:@"action"] )];
		[bubble setRepresentedObject:[context objectForKey:@"representedObject"]];
		[bubble startFadeIn];

		if( [(NSString *)[context objectForKey:@"coalesceKey"] length] ) {
			[bubble setDelegate:self];
			[_bubbles setObject:bubble forKey:[context objectForKey:@"coalesceKey"]];
		}
	}
}

- (void) bubbleDidFadeOut:(KABubbleWindowController *) bubble {
	NSEnumerator *e = [[[_bubbles copy] autorelease] objectEnumerator];
	NSEnumerator *ke = [[[_bubbles copy] autorelease] keyEnumerator];
	KABubbleWindowController *cBubble = nil;
	NSString *key = nil;

	while( ( key = [ke nextObject] ) && ( cBubble = [e nextObject] ) )
		if( cBubble == bubble ) [_bubbles removeObjectForKey:key];
}

- (void) _playSound:(NSString *) path {
	if( ! path ) return;

	if( ! [path isAbsolutePath] )
		path = [[NSString stringWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];

	NSSound *sound = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
	[sound setDelegate:self];

	// When run on a laptop using battery power, the play method may block while the audio
	// hardware warms up.  If it blocks, the sound WILL NOT PLAY after the block ends.
	// To get around this, we check to make sure the sound is playing, and if it isn't
	// we call the play method again.

	[sound play];
	if( ! [sound isPlaying] ) [sound play];
}

- (void) sound:(NSSound *) sound didFinishPlaying:(BOOL) finish {
	[sound autorelease];
}

- (NSDictionary *) registrationDictionaryForGrowl {
	NSEnumerator *enumerator = [[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"notifications" ofType:@"plist"]] objectEnumerator];
	NSMutableArray *notifications = [NSMutableArray array];
	NSDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) )
		if( ! [info objectForKey:@"seperator"] )
			[notifications addObject:[info objectForKey:@"identifier"]];

	return [NSDictionary dictionaryWithObjectsAndKeys:notifications, GROWL_NOTIFICATIONS_ALL, notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
}
@end