#import <Cocoa/Cocoa.h>
#import "MVNotificationPreferencePane.h"

@interface NSCell (NSCellPrivate)
- (void) _setVerticallyCentered:(BOOL) flag;
@end

@implementation MVNotificationPreferencePane
- (id) initWithBundle:(NSBundle *) bundle {
	if( ! ( self = [super initWithBundle:bundle] ) ||
		! [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"cc.javelin.colloquy"] ) {
		[self autorelease];
		self = nil;
	} else {
		NSMenuItem *menuItem = nil;
		NSImage *soundIcon = [[[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"none" ofType:@"tif"]] autorelease];
		NSEnumerator *enumerator = nil;
		id sound = nil;

		chatSoundActions = [[NSMutableArray arrayWithContentsOfFile:[bundle pathForResource:@"actions" ofType:@"plist"]] retain];
		availableSounds = [[NSMenu alloc] initWithTitle:NSLocalizedStringFromTable( @"Sounds", @"Chat", sounds menu name )];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTable( @"No Sound", @"Chat", no sound menu option - mute ) action:NULL keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@""];
		[menuItem setImage:soundIcon];
		[availableSounds addItem:menuItem];

		soundIcon = [[[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"sound" ofType:@"tif"]] autorelease];

		[availableSounds addItem:[NSMenuItem separatorItem]];

		enumerator = [[[NSBundle mainBundle] pathsForResourcesOfType:@"aiff" inDirectory:@"Sounds"] objectEnumerator];
		while( ( sound = [enumerator nextObject] ) ) {
			menuItem = [[[NSMenuItem alloc] initWithTitle:[[sound lastPathComponent] stringByDeletingPathExtension] action:NULL keyEquivalent:@""] autorelease];
			[menuItem setRepresentedObject:[sound lastPathComponent]];
			[menuItem setImage:soundIcon];
			[availableSounds addItem:menuItem];
		}

		[availableSounds addItem:[NSMenuItem separatorItem]];

		enumerator = [[NSFileManager defaultManager] enumeratorAtPath:@"/System/Library/Sounds"];
		while( ( sound = [enumerator nextObject] ) ) {
			if( [[sound pathExtension] isEqualToString:@"aif"] || [[sound pathExtension] isEqualToString:@"aiff"] ) {
				menuItem = [[[NSMenuItem alloc] initWithTitle:[[sound lastPathComponent] stringByDeletingPathExtension] action:NULL keyEquivalent:@""] autorelease];
				[menuItem setRepresentedObject:[NSString stringWithFormat:@"%@/%@", @"/System/Library/Sounds", sound]];
				[menuItem setImage:soundIcon];
				[availableSounds addItem:menuItem];
			}
		}

		[availableSounds addItem:[NSMenuItem separatorItem]];

		enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[@"~/Library/Sounds" stringByExpandingTildeInPath]];
		while( ( sound = [enumerator nextObject] ) ) {
			if( [[sound pathExtension] isEqualToString:@"aif"] || [[sound pathExtension] isEqualToString:@"aiff"] ) {
				menuItem = [[[NSMenuItem alloc] initWithTitle:[[sound lastPathComponent] stringByDeletingPathExtension] action:NULL keyEquivalent:@""] autorelease];
				[menuItem setRepresentedObject:[NSString stringWithFormat:@"%@/%@", [@"~/Library/Sounds" stringByExpandingTildeInPath], sound]];
				[menuItem setImage:soundIcon];
				[availableSounds addItem:menuItem];
			}
		}
	}
	return self;
}

- (void) dealloc {
	[chatSoundActions autorelease];
	[availableSounds autorelease];
	chatSoundActions = nil;
	availableSounds = nil;
}

- (void) mainViewDidLoad {
	id value = nil;
	BOOL boolValue = NO;
	NSTableColumn *theColumn;
	id prototypeCell = nil;

	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatPlayActionSounds"];
	[playSoundsForActions setState:(NSCellStateValue) boolValue];

	theColumn = [soundSelections tableColumnWithIdentifier:@"sound"];
	prototypeCell = [[[NSPopUpButtonCell alloc] initTextCell:@""] autorelease];
	[prototypeCell setFont:[NSFont systemFontOfSize:10.]];
	[prototypeCell setControlSize:NSSmallControlSize];
	[prototypeCell setAltersStateOfSelectedItem:YES];
	[prototypeCell setMenu:[[availableSounds copy] autorelease]];
	[theColumn setDataCell:prototypeCell];

	theColumn = [soundSelections tableColumnWithIdentifier:@"action"];
	prototypeCell = [theColumn dataCell];
	[prototypeCell setFont:[NSFont labelFontOfSize:11.]];
	[prototypeCell _setVerticallyCentered:YES];
	[soundSelections reloadData];

	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatShowHiddenOnRoomMessage"];
	[showHiddenOnRoomMessage setState:(NSCellStateValue) boolValue];
	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatShowHiddenOnPrivateMessage"];
	[showHiddenOnPrivateMessage setState:(NSCellStateValue) boolValue];
	
	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatBounceIconOnMessage"];
	[bounceAppIcon setState:(NSCellStateValue)boolValue];
	[bounceUntilFront setEnabled:boolValue];
	if( ! boolValue ) [bounceUntilFront setState:NSOffState];
	else [bounceUntilFront setState:(NSCellStateValue)[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatBounceIconUntilFront"]];

	value = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatHighlightNames"] componentsJoinedByString:@" "];
	if( value ) [hightlightNames setStringValue:value];
}

- (void) didUnselect {
	[[NSUserDefaults standardUserDefaults] setObject:[[hightlightNames stringValue] componentsSeparatedByString:@" "] forKey:@"MVChatHighlightNames"];

	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction) showHiddenRoomsChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"MVChatShowHiddenOnRoomMessage"];
}

- (IBAction) showHiddenPrivateMessagesChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"MVChatShowHiddenOnPrivateMessage"];
}

- (IBAction) bounceAppIconChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"MVChatBounceIconOnMessage"];
	[bounceUntilFront setEnabled:(BOOL)[sender state]];
	if( ! [sender state] ) {
		[bounceUntilFront setState:NSOffState];
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"MVChatBounceIconUntilFront"];
	}
}

- (IBAction) playActionSoundsChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"MVChatPlayActionSounds"];
}

- (IBAction) bounceUntilFrontChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:(BOOL)[sender state]] forKey:@"MVChatBounceIconUntilFront"];
}

- (void) playSound:(NSString *) path {
	if( [path length] ) {
		NSSound *sound = nil;
		NSString *fullPath = path;
		if( ! [path isAbsolutePath] ) fullPath = [[NSString stringWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];
		sound = [[[NSSound alloc] initWithContentsOfFile:fullPath byReference:YES] autorelease];
		[sound play];
	}
}

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [chatSoundActions count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqualToString:@"action"] ) {
		return [[chatSoundActions objectAtIndex:row] objectForKey:@"MVChatActionTitle"];
	} else if( [[column identifier] isEqualToString:@"sound"] ) {
		return [[chatSoundActions objectAtIndex:row] objectForKey:@"MVCurrentSoundSelection"];
	}
	return nil;
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	NSMutableDictionary *sounds = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatActionSounds"]];
	NSMenuItem *item = [availableSounds itemAtIndex:[object unsignedIntValue]];
	[sounds setObject:[item representedObject] forKey:[[chatSoundActions objectAtIndex:row] objectForKey:@"MVChatActionIdentifier"]];
	[[NSUserDefaults standardUserDefaults] setObject:sounds forKey:@"MVChatActionSounds"];

	[[chatSoundActions objectAtIndex:row] setObject:object forKey:@"MVCurrentSoundSelection"];

	[[NSSound soundNamed:[[chatSoundActions objectAtIndex:row] objectForKey:@"MVChatActionIdentifier"]] autorelease];

	[self playSound:[item representedObject]];
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqualToString:@"sound"] ) {
		if( [[chatSoundActions objectAtIndex:row] objectForKey:@"MVCurrentSoundSelection"] ) {
			[cell selectItemAtIndex:[[[chatSoundActions objectAtIndex:row] objectForKey:@"MVCurrentSoundSelection"] unsignedIntValue]];
		} else {
			NSString *path = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatActionSounds"] objectForKey:[[chatSoundActions objectAtIndex:row] objectForKey:@"MVChatActionIdentifier"]];
			int i = -1;
			if( [path length] && ( i = [cell indexOfItemWithRepresentedObject:path] ) != -1 ) [cell selectItemAtIndex:i];
			else [cell selectItemAtIndex:0];
		}
	}
}
@end