#import <Cocoa/Cocoa.h>
#import "JVNotificationPreferences.h"
#import <AGRegex/AGRegex.h>

@implementation JVNotificationPreferences
- (NSString *) preferencesNibName {
	return @"JVNotificationPreferences";
}

- (BOOL) hasChangesPending {
	return YES;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"NotificationPreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	_eventPrefs = nil;
	[self buildEventsMenu];
	[self buildSoundsMenu];
	[self switchEvent:chatActions];
	[muteAllSounds setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatNotificationsMuted"]];
	[highlightWords setStringValue:[[[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatHighlightNames"] componentsJoinedByString:@" "]];
}

- (void) switchEvent:(id) sender {
	[_eventPrefs autorelease];
	_eventPrefs = [[NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:[NSString stringWithFormat:@"JVNotificationSettings %@", [[chatActions selectedItem] representedObject]]]] retain];

	BOOL boolValue = [[_eventPrefs objectForKey:@"playSound"] boolValue];
	[playSound setState:boolValue];
	[sounds setEnabled:boolValue];
	[self selectSoundWithPath:[_eventPrefs objectForKey:@"soundPath"]];

	boolValue = [[_eventPrefs objectForKey:@"bounceIcon"] boolValue];
	[bounceIcon setState:boolValue];
	[untilAttention setEnabled:boolValue];
	if( ! boolValue ) [untilAttention setState:NSOffState];
	else [untilAttention setState:[[_eventPrefs objectForKey:@"bounceIconUntilFront"] boolValue]];	

	boolValue = [[_eventPrefs objectForKey:@"showBubble"] boolValue];
	[showBubble setState:boolValue];
	[onlyIfBackground setEnabled:boolValue];
	[keepOnScreen setEnabled:boolValue];
	if( ! boolValue ) {
		[onlyIfBackground setState:NSOffState];
		[keepOnScreen setState:NSOffState];
	} else {
		[onlyIfBackground setState:[[_eventPrefs objectForKey:@"showBubbleOnlyIfBackground"] boolValue]];
		[keepOnScreen setState:[[_eventPrefs objectForKey:@"keepBubbleOnScreen"] boolValue]];
	}
}

- (void) saveEventSettings {
	[[NSUserDefaults standardUserDefaults] setObject:_eventPrefs forKey:[NSString stringWithFormat:@"JVNotificationSettings %@", [[chatActions selectedItem] representedObject]]];
}

- (void) saveHighlightWords:(id) sender {
	// We want to be able to let Regex's contain spaces, so lets split intelligently
	NSMutableArray *components = [NSMutableArray array];
	NSString *words = [highlightWords stringValue];
	AGRegex *regex = [AGRegex regexWithPattern:@"(?:\\s|^)(/.*?/)(?:\\s|$)"];
	NSArray *matches = [regex findAllInString:words];
	NSEnumerator *e = [matches objectEnumerator];
	AGRegexMatch *match;
	while( match = [e nextObject] ) {
		[components addObject:[match groupAtIndex:1]];
	}
	words = [regex replaceWithString:@"" inString:words];
	[components addObjectsFromArray:[words componentsSeparatedByString:@" "]];
	[components removeObject:@""];
	[[NSUserDefaults standardUserDefaults] setObject:components forKey:@"MVChatHighlightNames"];
}

- (void) buildEventsMenu {
	NSMenuItem *menuItem = nil;
	NSEnumerator *enumerator = nil;
	NSMenu *availableEvents = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSDictionary *info = nil;

	enumerator = [[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"notifications" ofType:@"plist"]] objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( ! [info objectForKey:@"seperator"] ) {
			menuItem = [[[NSMenuItem alloc] initWithTitle:[info objectForKey:@"title"] action:NULL keyEquivalent:@""] autorelease];
			[menuItem setRepresentedObject:[info objectForKey:@"identifier"]];
			[availableEvents addItem:menuItem];
		} else [availableEvents addItem:[NSMenuItem separatorItem]];
	}

	[chatActions setMenu:availableEvents];
}

- (void) buildSoundsMenu {
	NSMenuItem *menuItem = nil;
	NSEnumerator *enumerator = nil;
	id sound = nil;
	BOOL first = YES;

	NSMenu *availableSounds = [[[NSMenu alloc] initWithTitle:@""] autorelease];

	enumerator = [[[NSBundle mainBundle] pathsForResourcesOfType:@"aiff" inDirectory:@"Sounds"] objectEnumerator];
	while( ( sound = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[[sound lastPathComponent] stringByDeletingPathExtension] action:NULL keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:[sound lastPathComponent]];
		[menuItem setImage:[NSImage imageNamed:@"sound"]];
		[availableSounds addItem:menuItem];
	}

	enumerator = [[NSFileManager defaultManager] enumeratorAtPath:@"/System/Library/Sounds"];
	while( ( sound = [enumerator nextObject] ) ) {
		if( [[sound pathExtension] isEqualToString:@"aif"] || [[sound pathExtension] isEqualToString:@"aiff"] || [[sound pathExtension] isEqualToString:@"wav"] ) {
			if( first ) [availableSounds addItem:[NSMenuItem separatorItem]];
			first = NO;
			menuItem = [[[NSMenuItem alloc] initWithTitle:[[sound lastPathComponent] stringByDeletingPathExtension] action:NULL keyEquivalent:@""] autorelease];
			[menuItem setRepresentedObject:[NSString stringWithFormat:@"%@/%@", @"/System/Library/Sounds", sound]];
			[menuItem setImage:[NSImage imageNamed:@"sound"]];
			[availableSounds addItem:menuItem];
		}
	}

	enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[@"~/Library/Sounds" stringByExpandingTildeInPath]];
	while( ( sound = [enumerator nextObject] ) ) {
		if( [[sound pathExtension] isEqualToString:@"aif"] || [[sound pathExtension] isEqualToString:@"aiff"] || [[sound pathExtension] isEqualToString:@"wav"] ) {
			if( first ) [availableSounds addItem:[NSMenuItem separatorItem]];
			first = NO;
			menuItem = [[[NSMenuItem alloc] initWithTitle:[[sound lastPathComponent] stringByDeletingPathExtension] action:NULL keyEquivalent:@""] autorelease];
			[menuItem setRepresentedObject:[NSString stringWithFormat:@"%@/%@", [@"~/Library/Sounds" stringByExpandingTildeInPath], sound]];
			[menuItem setImage:[NSImage imageNamed:@"sound"]];
			[availableSounds addItem:menuItem];
		}
	}

	[sounds setMenu:availableSounds];
}

- (void) selectSoundWithPath:(NSString *) path {
	int index = [sounds indexOfItemWithRepresentedObject:path];
	if( index != -1 ) [sounds selectItemAtIndex:index];
	else [sounds selectItemAtIndex:0];
}

- (void) playSound:(id) sender {
	[sounds setEnabled:(BOOL)[sender state]];
	[_eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"playSound"];
	[self switchSound:sounds];
	[self saveEventSettings];
}

- (void) switchSound:(id) sender {
	NSString *path = [[sounds selectedItem] representedObject];

	[_eventPrefs setObject:[[sounds selectedItem] representedObject] forKey:@"soundPath"];
	[self saveEventSettings];

	if( [playSound state] == NSOnState ) {
		if( ! [path isAbsolutePath] ) path = [[NSString stringWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];
		NSSound *sound = [[[NSSound alloc] initWithContentsOfFile:path byReference:YES] autorelease];
		[sound play];
	}
}

- (void) bounceIcon:(id) sender {
	[untilAttention setEnabled:(BOOL)[sender state]];
	if( [sender state] == NSOffState ) [untilAttention setState:NSOffState];
	else [untilAttention setState:[[_eventPrefs objectForKey:@"bounceIconUntilAttention"] boolValue]];	
	[_eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"bounceIcon"];
	[self saveEventSettings];
}

- (void) bounceIconUntilFront:(id) sender {
	[_eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"bounceIconUntilFront"];
	[self saveEventSettings];
}

- (void) showBubble:(id) sender {
	[onlyIfBackground setEnabled:(BOOL)[sender state]];
	[keepOnScreen setEnabled:(BOOL)[sender state]];
	if( [sender state] == NSOffState ) {
		[onlyIfBackground setState:NSOffState];
		[keepOnScreen setState:NSOffState];
	} else {
		[onlyIfBackground setState:[[_eventPrefs objectForKey:@"showBubbleOnlyIfBackground"] boolValue]];
		[keepOnScreen setState:[[_eventPrefs objectForKey:@"keepBubbleOnScreen"] boolValue]];
	}
	[_eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"showBubble"];
	[self saveEventSettings];
}

- (void) showBubbleIfBackground:(id) sender {
	[_eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"showBubbleOnlyIfBackground"];
	[self saveEventSettings];
}

- (void) keepBubbleOnScreen:(id) sender {
	[_eventPrefs setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"keepBubbleOnScreen"];
	[self saveEventSettings];
}

- (void) muteAllSounds:(id) sender {
	[[NSUserDefaults standardUserDefaults] setBool:(BOOL)[sender state] forKey:@"JVChatNotificationsMuted"];
}
@end