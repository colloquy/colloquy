#import <Cocoa/Cocoa.h>
#import "MVAppearancePreferencePane.h"
#import "NSAttributedStringAdditions.h"

@implementation MVAppearancePreferencePane
- (id) initWithBundle:(NSBundle *) bundle {
	if( ! ( self = [super initWithBundle:bundle] ) ||
		! [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"cc.javelin.colloquy"] ) {
		self = nil;
	}
	return self;
}

- (void) mainViewDidLoad {
	id value = nil;
	BOOL boolValue = NO;

	value = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatTextColor"]];
	if( value ) [defaultTextColor setColor:value];
	value = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatActionColor"]];
	if( value ) [actionTextColor setColor:value];
	value = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatLinkColor"]];
	if( value ) [linkColor setColor:value];
	value = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatBackgroundColor"]];
	if( value ) [backgroundColor setColor:value];
	value = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatSelfColor"]];
	if( value ) [myColor setColor:value];
	value = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatOthersColor"]];
	if( value ) [otherMessageColor setColor:value];
	value = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatAlertColor"]];
	if( value ) [alertColor setColor:value];
	value = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatHighlightColor"]];
	if( value ) [highlightBackgroundColor setColor:value];
	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"];
	[allowColorMessages setState:(NSCellStateValue) ! boolValue];
	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"];
	[allowTextFormatting setState:(NSCellStateValue) ! boolValue];
	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableGraphicEmoticons"];
	[disableGraphicEmoticons setState:(NSCellStateValue) ! boolValue];
	boolValue = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"];
	[disableLinkHighlighting setState:(NSCellStateValue) ! boolValue];
	[linkColor setEnabled:! boolValue];

	[self buildExampleText:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( buildExampleText: ) name:NSColorPanelColorDidChangeNotification object:nil];
}

- (void) didUnselect {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSColorPanelColorDidChangeNotification object:nil];

	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[defaultTextColor color]] forKey:@"MVChatTextColor"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[actionTextColor color]] forKey:@"MVChatActionColor"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[linkColor color]] forKey:@"MVChatLinkColor"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[backgroundColor color]] forKey:@"MVChatBackgroundColor"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[myColor color]] forKey:@"MVChatSelfColor"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[otherMessageColor color]] forKey:@"MVChatOthersColor"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[alertColor color]] forKey:@"MVChatAlertColor"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[highlightBackgroundColor color]] forKey:@"MVChatHighlightColor"];

	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction) allowsColorChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:![sender state]] forKey:@"MVChatIgnoreColors"];
	[self buildExampleText:nil];
}

- (IBAction) allowsTextFormattingChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:![sender state]] forKey:@"MVChatIgnoreFormatting"];
	[self buildExampleText:nil];
}

- (IBAction) showEmoticonsChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:![sender state]] forKey:@"MVChatDisableGraphicEmoticons"];
	[self buildExampleText:nil];
}

- (IBAction) linkHighlightingChoice:(id) sender {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:![sender state]] forKey:@"MVChatDisableLinkHighlighting"];
	[linkColor setEnabled:(BOOL) [sender state]];
	[self buildExampleText:nil];
}

- (void) buildExampleText:(id) sender {
	[exampleChat replaceCharactersInRange:NSMakeRange( 0., [[exampleChat textStorage] length] ) withString:@""];
	[exampleChat setBackgroundColor:[backgroundColor color]];
	[self addMessageToDisplay:@"joined the chat room." fromUser:@"nonex" asAction:YES asAlert:YES];
	[self addMessageToDisplay:@"waves." fromUser:@"pf5268" asAction:YES asAlert:NO];
	[self addMessageToDisplay:@"Hello!" fromUser:@"nonex" asAction:NO asAlert:NO];
	if( (BOOL) [allowTextFormatting state] ) [self addMessageToDisplay:@"<u>Hi</u> :)" fromUser:@"pf5268" asAction:NO asAlert:NO];
	else [self addMessageToDisplay:@"Hi :)" fromUser:@"pf5268" asAction:NO asAlert:NO];
	[self addMessageToDisplay:@"What is new pf5268?" fromUser:@"nonex" asAction:NO asAlert:NO];
	if( (BOOL) [allowColorMessages state] && (BOOL) [allowTextFormatting state] ) [self addMessageToDisplay:@"<font color=\"#9c009c\"><b>Check out this site</b> http://www.javelin.cc.</font>" fromUser:@"pf5268" asAction:NO asAlert:NO];
	else if( (BOOL) [allowColorMessages state] && (BOOL) ! [allowTextFormatting state] ) [self addMessageToDisplay:@"<font color=\"#9c009c\">Check out this site http://www.javelin.cc.</font>" fromUser:@"pf5268" asAction:NO asAlert:NO];
	else if( (BOOL) ! [allowColorMessages state] && (BOOL) [allowTextFormatting state] ) [self addMessageToDisplay:@"<b>Check out this site</b> http://www.javelin.cc." fromUser:@"pf5268" asAction:NO asAlert:NO];
	else [self addMessageToDisplay:@"Check out this site http://www.javelin.cc." fromUser:@"pf5268" asAction:NO asAlert:NO];
	[self addMessageToDisplay:@"is amazed." fromUser:@"nonex" asAction:YES asAlert:NO];
}

- (void) addMessageToDisplay:(NSString *) message fromUser:(NSString *) user asAction:(BOOL) action asAlert:(BOOL) alert {
	NSString *MVChatDummyHTMLDocumentFormat = @"<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=%s\"></head><body><font face=\"Arial\">%@</font></body></html>";
	NSString *str = [NSString stringWithFormat:MVChatDummyHTMLDocumentFormat, "utf-8", message];
	NSData *msgData = [str dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	NSMutableAttributedString *msgString = [[[NSMutableAttributedString alloc] initWithHTML:msgData documentAttributes:nil] autorelease];
	unsigned length = 0, begin = 0;

	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );

	begin = [[exampleChat textStorage] length];
	if( user ) {
		if( action ) [exampleChat replaceCharactersInRange:NSMakeRange([[exampleChat textStorage] length], 0) withString:@"\xA5"];
		[exampleChat replaceCharactersInRange:NSMakeRange([[exampleChat textStorage] length], 0) withString:user];
		if( ! action ) [exampleChat replaceCharactersInRange:NSMakeRange([[exampleChat textStorage] length], 0) withString:@":"];
		length = [[exampleChat textStorage] length] - begin;
		if( ( [[msgString string] rangeOfString:@"'"].location && action ) || ! action ) {
			[exampleChat replaceCharactersInRange:NSMakeRange( [[exampleChat textStorage] length], 0 ) withString:@" "];
			[[exampleChat textStorage] setAttributes:nil range:NSMakeRange( begin + length, 1. )];
		}
		[[exampleChat textStorage] setAttributes:nil range:NSMakeRange( begin, length )];
		[exampleChat setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]] range:NSMakeRange( begin, length )];
		if( alert ) {
			[exampleChat setTextColor:[alertColor color] range:NSMakeRange( begin, length )];
		} else if( ! [user caseInsensitiveCompare:@"pf5268"] ) {
			[exampleChat setTextColor:[myColor color] range:NSMakeRange( begin, length )];
		} else {
			[exampleChat setTextColor:[otherMessageColor color] range:NSMakeRange( begin, length )];
		}
	}

	if( (BOOL) [disableLinkHighlighting state] )
		[msgString preformLinkHighlightingUsingColor:[linkColor color] withUnderline:YES];

	if( (BOOL) [disableGraphicEmoticons state] ) {
		id dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObject:@":)"], @"smile.tif", nil];
		[msgString preformImageSubstitutionWithDictionary:dict];
	}

	[[exampleChat textStorage] appendAttributedString:msgString];
	[exampleChat replaceCharactersInRange:NSMakeRange([[exampleChat textStorage] length], 0.) withString:@"\n"];

	if( action ) [exampleChat setTextColor:[actionTextColor color] range:NSMakeRange( begin + 1, [[exampleChat textStorage] length] - begin - 1 )];

	if( ! [user isEqualToString:@"pf5268"] ) {
		if( [[[msgString string] lowercaseString] rangeOfString:@"pf5268"].length ) {
			[[exampleChat textStorage] addAttribute:NSBackgroundColorAttributeName value:[highlightBackgroundColor color] range:NSMakeRange( begin, [[exampleChat textStorage] length] - begin )];
		}
	}
}
@end