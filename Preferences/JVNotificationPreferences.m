#import "JVNotificationPreferences.h"
#import "NSRegularExpressionAdditions.h"

@implementation JVNotificationPreferences

- (NSString *) preferencesNibName {
	return @"JVNotificationPreferences";
}

- (BOOL) hasChangesPending {
	return YES;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [NSImage imageNamed:@"NotificationPreferences"];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	_eventPrefs = nil;
	[self buildEventsMenu];
	[self buildSoundsMenu];
	[self switchEvent:chatActions];
	[highlightWords setStringValue:[[[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatHighlightNames"] componentsJoinedByString:@" "]];
}

- (void) switchEvent:(id) sender {
	_eventPrefs = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:[NSString stringWithFormat:@"JVNotificationSettings %@", [[chatActions selectedItem] representedObject]]]];

	BOOL boolValue = [_eventPrefs[@"playSound"] boolValue];
	[playSound setState:boolValue];
	[soundOnlyIfBackground setEnabled:boolValue];
	[sounds setEnabled:boolValue];
	if( ! boolValue ) [soundOnlyIfBackground setState:NSOffState];
	else [soundOnlyIfBackground setState:[_eventPrefs[@"playSoundOnlyIfBackground"] boolValue]];
	[self selectSoundWithPath:_eventPrefs[@"soundPath"]];

	boolValue = [_eventPrefs[@"bounceIcon"] boolValue];
	[bounceIcon setState:boolValue];
	[untilAttention setEnabled:boolValue];
	if( ! boolValue ) [untilAttention setState:NSOffState];
	else [untilAttention setState:[_eventPrefs[@"bounceIconUntilFront"] boolValue]];

	boolValue = [_eventPrefs[@"showBubble"] boolValue];
	[showBubble setState:boolValue];
	[onlyIfBackground setEnabled:boolValue];
	[keepOnScreen setEnabled:boolValue];
	if( ! boolValue ) {
		[onlyIfBackground setState:NSOffState];
		[keepOnScreen setState:NSOffState];
	} else {
		[onlyIfBackground setState:[_eventPrefs[@"showBubbleOnlyIfBackground"] boolValue]];
		[keepOnScreen setState:[_eventPrefs[@"keepBubbleOnScreen"] boolValue]];
	}
}

- (void) saveEventSettings {
	[[NSUserDefaults standardUserDefaults] setObject:_eventPrefs forKey:[NSString stringWithFormat:@"JVNotificationSettings %@", [[chatActions selectedItem] representedObject]]];
}

- (void) saveHighlightWords:(id) sender {
	// We want to be able to let highlights contain spaces, so lets split intelligently
	NSMutableArray *components = [NSMutableArray array];
	NSString *words = [highlightWords stringValue];

	NSRegularExpression *regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(?<=\\s|^)([/\"'].*?[/\"'])(?=\\s|$)" options:0 error:nil];

	for( NSTextCheckingResult *match in [regex matchesInString:words options:NSMatchingCompleted range:NSMakeRange( 0, words.length )] )
		[components addObject:[words substringWithRange:[match rangeAtIndex:1]]];

	words = [words stringByReplacingOccurrencesOfRegex:@"(?<=\\s|^)([/\"'].*?[/\"'])(?=\\s|$)" withString:@""];

	[components addObjectsFromArray:[words componentsSeparatedByString:@" "]];
	[components removeObject:@""];

	[[NSUserDefaults standardUserDefaults] setObject:components forKey:@"MVChatHighlightNames"];
}

- (void) buildEventsMenu {
	NSMenu *availableEvents = [[NSMenu alloc] initWithTitle:@""];

	for( NSDictionary *info in [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"notifications" ofType:@"plist"]] ) {
		if( ! info[@"seperator"] ) {
			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( info[@"title"], "notification event menu items, notification preferences" ) action:NULL keyEquivalent:@""];
			[menuItem setRepresentedObject:info[@"identifier"]];
			[availableEvents addItem:menuItem];
		} else [availableEvents addItem:[NSMenuItem separatorItem]];
	}

	[chatActions setMenu:availableEvents];
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
	NSArray *paths = @[[NSString stringWithFormat:@"/Network/Library/Application Support/%@/Sounds", bundleName],
		[NSString stringWithFormat:@"/Library/Application Support/%@/Sounds", bundleName],
		[[NSString stringWithFormat:@"~/Library/Application Support/%@/Sounds", bundleName] stringByExpandingTildeInPath],
		@"-",
		@"/System/Library/Sounds",
		[@"~/Library/Sounds" stringByExpandingTildeInPath]];

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
				menuItem = [[NSMenuItem alloc] initWithTitle:sound action:@selector( aRandomSelector:of:no:consequence: ) keyEquivalent:@""];
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

	[sounds setMenu:availableSounds];
}

- (void) selectSoundWithPath:(NSString *) path {
	NSInteger index = [sounds indexOfItemWithRepresentedObject:path];
	if( index != -1 ) [sounds selectItemAtIndex:index];
	else [sounds selectItemAtIndex:0];
}

- (void) playSound:(id) sender {
	[sounds setEnabled:(BOOL)[sender state]];
	[soundOnlyIfBackground setEnabled:(BOOL)[sender state]];
	if( [sender state] == NSOffState ) [soundOnlyIfBackground setState:NSOffState];
	else [soundOnlyIfBackground setState:[_eventPrefs[@"playSoundOnlyIfBackground"] boolValue]];
	_eventPrefs[@"playSound"] = @((BOOL)[sender state]);
	[self switchSound:sounds];
	[self saveEventSettings];
}

- (void) playSoundIfBackground:(id) sender {
	_eventPrefs[@"playSoundOnlyIfBackground"] = @((BOOL)[sender state]);
	[self saveEventSettings];
}

- (void) switchSound:(id) sender {
	NSString *path = [[sounds selectedItem] representedObject];

	_eventPrefs[@"soundPath"] = [[sounds selectedItem] representedObject];
	[self saveEventSettings];

	if( [playSound state] == NSOnState ) {
		if( ! [path isAbsolutePath] ) path = [[NSString stringWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];
		NSSound *sound = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
		[sound play];
	}
}

- (void) bounceIcon:(id) sender {
	[untilAttention setEnabled:(BOOL)[sender state]];
	if( [sender state] == NSOffState ) [untilAttention setState:NSOffState];
	else [untilAttention setState:[_eventPrefs[@"bounceIconUntilAttention"] boolValue]];
	_eventPrefs[@"bounceIcon"] = @((BOOL)[sender state]);
	[self saveEventSettings];
}

- (void) bounceIconUntilFront:(id) sender {
	_eventPrefs[@"bounceIconUntilFront"] = @((BOOL)[sender state]);
	[self saveEventSettings];
}

- (void) showBubble:(id) sender {
	[onlyIfBackground setEnabled:(BOOL)[sender state]];
	[keepOnScreen setEnabled:(BOOL)[sender state]];
	if( [sender state] == NSOffState ) {
		[onlyIfBackground setState:NSOffState];
		[keepOnScreen setState:NSOffState];
	} else {
		[onlyIfBackground setState:[_eventPrefs[@"showBubbleOnlyIfBackground"] boolValue]];
		[keepOnScreen setState:[_eventPrefs[@"keepBubbleOnScreen"] boolValue]];
	}
	_eventPrefs[@"showBubble"] = @((BOOL)[sender state]);
	[self saveEventSettings];
}

- (void) showBubbleIfBackground:(id) sender {
	_eventPrefs[@"showBubbleOnlyIfBackground"] = @((BOOL)[sender state]);
	[self saveEventSettings];
}

- (void) keepBubbleOnScreen:(id) sender {
	_eventPrefs[@"keepBubbleOnScreen"] = @((BOOL)[sender state]);
	[self saveEventSettings];
}
@end
