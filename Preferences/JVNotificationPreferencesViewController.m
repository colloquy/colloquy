#import "JVNotificationPreferencesViewController.h"

#import "NSRegularExpressionAdditions.h"


@interface JVNotificationPreferencesViewController ()

@property(nonatomic, strong) NSMutableDictionary *eventPrefs;

@property(nonatomic, strong) IBOutlet NSTextField *highlightWords;
@property(nonatomic, strong) IBOutlet NSPopUpButton *chatActions;
@property(nonatomic, strong) IBOutlet NSButton *playSound;
@property(nonatomic, strong) IBOutlet NSButton *soundOnlyIfBackground;
@property(nonatomic, strong) IBOutlet NSPopUpButton *sounds;
@property(nonatomic, strong) IBOutlet NSButton *bounceIcon;
@property(nonatomic, strong) IBOutlet NSButton *untilAttention;
@property(nonatomic, strong) IBOutlet NSButton *showBubble;
@property(nonatomic, strong) IBOutlet NSButton *onlyIfBackground;
@property(nonatomic, strong) IBOutlet NSButton *keepOnScreen;

- (void) initializeFromDefaults;

- (IBAction) switchEvent:(id) sender;

- (void) saveEventSettings;
- (IBAction) saveHighlightWords:(id) sender;

- (void) buildEventsMenu;
- (void) buildSoundsMenu;

- (void) selectSoundWithPath:(NSString *) path;
- (IBAction) playSound:(id) sender;
- (IBAction) playSoundIfBackground:(id) sender;
- (IBAction) switchSound:(id) sender;

- (IBAction) bounceIcon:(id) sender;
- (IBAction) bounceIconUntilFront:(id) sender;

- (IBAction) showBubble:(id) sender;
- (IBAction) showBubbleIfBackground:(id) sender;
- (IBAction) keepBubbleOnScreen:(id) sender;

@end


@implementation JVNotificationPreferencesViewController

- (void)awakeFromNib {
	[self initializeFromDefaults];
}


#pragma mark - MASPreferencesViewController

- (NSString *) identifier {
	return @"JVNotificationPreferencesViewController";
}

- (NSImage *) toolbarItemImage {
	return [NSImage imageNamed:@"NotificationPreferences"];
}

- (NSString *) toolbarItemLabel {
	return NSLocalizedString( @"Alerts", "alerts preference pane name" );
}

- (BOOL)hasResizableWidth {
	return NO;
}

- (BOOL)hasResizableHeight {
	return NO;
}


#pragma mark - Private

- (void) initializeFromDefaults {
	self.eventPrefs = nil;
	[self buildEventsMenu];
	[self buildSoundsMenu];
	[self switchEvent:self.chatActions];
	[self.highlightWords setStringValue:[[[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatHighlightNames"] componentsJoinedByString:@" "]];
}

- (IBAction) switchEvent:(id) sender {
	self.eventPrefs = [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:[[NSString alloc] initWithFormat:@"JVNotificationSettings %@", [[self.chatActions selectedItem] representedObject]]]];

	BOOL boolValue = [[self.eventPrefs objectForKey:@"playSound"] boolValue];
	[self.playSound setState:boolValue];
	[self.soundOnlyIfBackground setEnabled:boolValue];
	[self.sounds setEnabled:boolValue];
	if( ! boolValue ) [self.soundOnlyIfBackground setState:NSOffState];
	else [self.soundOnlyIfBackground setState:[[self.eventPrefs objectForKey:@"playSoundOnlyIfBackground"] boolValue]];
	[self selectSoundWithPath:[self.eventPrefs objectForKey:@"soundPath"]];

	boolValue = [[self.eventPrefs objectForKey:@"bounceIcon"] boolValue];
	[self.bounceIcon setState:boolValue];
	[self.untilAttention setEnabled:boolValue];
	if( ! boolValue ) [self.untilAttention setState:NSOffState];
	else [self.untilAttention setState:[[self.eventPrefs objectForKey:@"bounceIconUntilFront"] boolValue]];

	boolValue = [[self.eventPrefs objectForKey:@"showBubble"] boolValue];
	[self.showBubble setState:boolValue];
	[self.onlyIfBackground setEnabled:boolValue];
	[self.keepOnScreen setEnabled:boolValue];
	if( ! boolValue ) {
		[self.onlyIfBackground setState:NSOffState];
		[self.keepOnScreen setState:NSOffState];
	} else {
		[self.onlyIfBackground setState:[[self.eventPrefs objectForKey:@"showBubbleOnlyIfBackground"] boolValue]];
		[self.keepOnScreen setState:[[self.eventPrefs objectForKey:@"keepBubbleOnScreen"] boolValue]];
	}
}

- (void) saveEventSettings {
	[[NSUserDefaults standardUserDefaults] setObject:self.eventPrefs forKey:[[NSString alloc] initWithFormat:@"JVNotificationSettings %@", [[self.chatActions selectedItem] representedObject]]];
}

- (IBAction) saveHighlightWords:(id) sender {
	// We want to be able to let highlights contain spaces, so lets split intelligently
	NSMutableArray *components = [[NSMutableArray alloc] init];
	NSString *words = [self.highlightWords stringValue];

	NSRegularExpression *regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(?<=\\s|^)([/\"'].*?[/\"'])(?=\\s|$)" options:0 error:nil];

	for( NSTextCheckingResult *match in [regex matchesInString:words options:0 range:NSMakeRange( 0, words.length )] )
		[components addObject:[words substringWithRange:[match rangeAtIndex:1]]];

	words = [words stringByReplacingOccurrencesOfRegex:@"(?<=\\s|^)([/\"'].*?[/\"'])(?=\\s|$)" withString:@""];

	[components addObjectsFromArray:[words componentsSeparatedByString:@" "]];
	[components removeObject:@""];

	[[NSUserDefaults standardUserDefaults] setObject:components forKey:@"MVChatHighlightNames"];
}

- (void) buildEventsMenu {
	NSMenu *availableEvents = [[NSMenu alloc] initWithTitle:@""];

	for( NSDictionary *info in [[NSArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"notifications" ofType:@"plist"]] ) {
		if( ! [info objectForKey:@"seperator"] ) {
			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( [info objectForKey:@"title"], "notification event menu items, notification preferences" ) action:NULL keyEquivalent:@""];
			[menuItem setRepresentedObject:[info objectForKey:@"identifier"]];
			[availableEvents addItem:menuItem];
		} else [availableEvents addItem:[NSMenuItem separatorItem]];
	}

	[self.chatActions setMenu:availableEvents];
}

- (void) buildSoundsMenu {
	NSMenuItem *menuItem = nil;
	BOOL first = YES;

	NSMenu *availableSounds = [[NSMenu alloc] initWithTitle:@""];

	for( id sound in [[NSBundle mainBundle] pathsForResourcesOfType:@"aiff" inDirectory:@"Sounds"] ) {
		menuItem = [[NSMenuItem alloc] initWithTitle:[[sound lastPathComponent] stringByDeletingPathExtension] action:NULL keyEquivalent:@""];
		[menuItem setRepresentedObject:[sound lastPathComponent]];
		[menuItem setImage:[NSImage imageNamed:@"sound"]];
		[availableSounds addItem:menuItem];
	}

	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSArray *paths = [[NSArray alloc] initWithObjects:
		[[NSString alloc] initWithFormat:@"/Network/Library/Application Support/%@/Sounds", bundleName],
		[[NSString alloc] initWithFormat:@"/Library/Application Support/%@/Sounds", bundleName],
		[[[NSString alloc] initWithFormat:@"~/Library/Application Support/%@/Sounds", bundleName] stringByExpandingTildeInPath],
		@"-",
		@"/System/Library/Sounds",
		[@"~/Library/Sounds" stringByExpandingTildeInPath],
		nil];

	for( __strong NSString *aPath in paths ) {
		if( [aPath isEqualToString:@"-"] ) {
			first = YES;
			continue;
		}
		NSEnumerator *enumerator = [[fm contentsOfDirectoryAtPath:aPath error:nil] objectEnumerator];
		NSEnumerator *oldEnum = nil;
		NSString *oldPath = nil;
		NSInteger indentationLevel = 0;
		id sound = nil;
		while( ( sound = [enumerator nextObject] ) || oldEnum ) {
			if( ! sound && oldEnum ) {
				enumerator = oldEnum;
				aPath = oldPath;
				oldEnum = nil;
				indentationLevel = 0;
				continue;
			}
			NSString *newPath = [aPath stringByAppendingPathComponent:sound];
			BOOL isDir;
			if( ! oldEnum && [fm fileExistsAtPath:newPath isDirectory:&isDir] && isDir ) {
				oldEnum = enumerator;
				enumerator = [[fm contentsOfDirectoryAtPath:newPath error:nil] objectEnumerator];
				oldPath = aPath;
				aPath = newPath;
				if( first ) [availableSounds addItem:[NSMenuItem separatorItem]];
				first = NO;
				menuItem = [[NSMenuItem alloc] initWithTitle:sound action:@selector( play /* SEL should exist, but, doesn't matter (?) */ ) keyEquivalent:@""];
				[menuItem setEnabled:NO];
				[menuItem setImage:[NSImage imageNamed:@"folder"]];
				[availableSounds addItem:menuItem];
				indentationLevel = 1;
				continue;
			}
			if( [[sound pathExtension] isEqualToString:@"aif"] || [[sound pathExtension] isEqualToString:@"aiff"] || [[sound pathExtension] isEqualToString:@"wav"] ) {
				if( first ) [availableSounds addItem:[NSMenuItem separatorItem]];
				first = NO;
				menuItem = [[NSMenuItem alloc] initWithTitle:[sound stringByDeletingPathExtension] action:NULL keyEquivalent:@""];
				[menuItem setRepresentedObject:newPath];
				[menuItem setImage:[NSImage imageNamed:@"sound"]];
				[menuItem setIndentationLevel:indentationLevel];
				[availableSounds addItem:menuItem];
			}
		}
	}

	[self.sounds setMenu:availableSounds];
}

- (void) selectSoundWithPath:(NSString *) path {
	NSInteger index = [self.sounds indexOfItemWithRepresentedObject:path];
	if( index != -1 ) [self.sounds selectItemAtIndex:index];
	else [self.sounds selectItemAtIndex:0];
}

- (IBAction) playSound:(id) sender {
	[self.sounds setEnabled:(BOOL)[sender state]];
	[self.soundOnlyIfBackground setEnabled:(BOOL)[sender state]];
	if( [sender state] == NSOffState ) [self.soundOnlyIfBackground setState:NSOffState];
	else [self.soundOnlyIfBackground setState:[[self.eventPrefs objectForKey:@"playSoundOnlyIfBackground"] boolValue]];
	[self.eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"playSound"];
	[self switchSound:self.sounds];
	[self saveEventSettings];
}

- (IBAction) playSoundIfBackground:(id) sender {
	[self.eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"playSoundOnlyIfBackground"];
	[self saveEventSettings];
}

- (IBAction) switchSound:(id) sender {
	NSString *path = [[self.sounds selectedItem] representedObject];

	[self.eventPrefs setObject:[[self.sounds selectedItem] representedObject] forKey:@"soundPath"];
	[self saveEventSettings];

	if( [self.playSound state] == NSOnState ) {
		if( ! [path isAbsolutePath] ) path = [[[NSString alloc] initWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];
		NSSound *sound = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
		[sound play];
	}
}

- (IBAction) bounceIcon:(id) sender {
	[self.untilAttention setEnabled:(BOOL)[sender state]];
	if( [sender state] == NSOffState ) [self.untilAttention setState:NSOffState];
	else [self.untilAttention setState:[[self.eventPrefs objectForKey:@"bounceIconUntilAttention"] boolValue]];
	[self.eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"bounceIcon"];
	[self saveEventSettings];
}

- (IBAction) bounceIconUntilFront:(id) sender {
	[self.eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"bounceIconUntilFront"];
	[self saveEventSettings];
}

- (IBAction) showBubble:(id) sender {
	[self.onlyIfBackground setEnabled:(BOOL)[sender state]];
	[self.keepOnScreen setEnabled:(BOOL)[sender state]];
	if( [sender state] == NSOffState ) {
		[self.onlyIfBackground setState:NSOffState];
		[self.keepOnScreen setState:NSOffState];
	} else {
		[self.onlyIfBackground setState:[[self.eventPrefs objectForKey:@"showBubbleOnlyIfBackground"] boolValue]];
		[self.keepOnScreen setState:[[self.eventPrefs objectForKey:@"keepBubbleOnScreen"] boolValue]];
	}
	[self.eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"showBubble"];
	[self saveEventSettings];
}

- (IBAction) showBubbleIfBackground:(id) sender {
	[self.eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"showBubbleOnlyIfBackground"];
	[self saveEventSettings];
}

- (IBAction) keepBubbleOnScreen:(id) sender {
	[self.eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"keepBubbleOnScreen"];
	[self saveEventSettings];
}

@end
