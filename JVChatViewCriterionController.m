#import <ChatCore/MVChatConnection.h>
#import "JVChatViewCriterionController.h"

@implementation JVChatViewCriterionController
+ (id) controller {
	return [[[self alloc] init] autorelease];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_query = @"";
		_changed = NO;
		[self setKind:JVChatViewTitleCriterionKind];
		[self setOperation:JVChatViewTextContainsCriterionOperation];
	}

	return self;
}

- (id) initWithCoder:(NSCoder *) coder {
	if( [coder allowsKeyedCoding] ) {
		self = [self init];
		[self setKind:[coder decodeIntForKey:@"kind"]];
		[self setQuery:[coder decodeObjectForKey:@"query"]];
		[self setOperation:[coder decodeIntForKey:@"operation"]];
		return self;
	} else [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	return nil;
}

- (void) encodeWithCoder:(NSCoder *) coder {
	if( [coder allowsKeyedCoding] ) {
		[coder encodeInt:[self kind] forKey:@"kind"];
		[coder encodeObject:[self query] forKey:@"query"];
		[coder encodeInt:[self operation] forKey:@"operation"];
	} else [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
}

- (id) copyWithZone:(NSZone *) zone {
	JVChatViewCriterionController *ret = [[JVChatViewCriterionController alloc] init];
	[ret setKind:[self kind]];
	[ret setQuery:[self query]];
	[ret setOperation:[self operation]];
	return ret;
}

- (id) mutableCopyWithZone:(NSZone *) zone {
	return [self copyWithZone:zone];
}

- (void) dealloc {
	[subview release];
	[kindMenu release];
	[_query release];

	subview = nil;
	kindMenu = nil;
	_query = nil;

	[super dealloc];
}

#pragma mark -

- (void) awakeFromNib {
	[tabView selectTabViewItemWithIdentifier:[NSString stringWithFormat:@"%d", [self format]]];

	if( [self format] == JVChatViewTextCriterionFormat ) {
		[textKindButton selectItemAtIndex:[textKindButton indexOfItemWithTag:[self kind]]];
		[textOperationButton selectItemAtIndex:[textOperationButton indexOfItemWithTag:[self operation]]];
		[textQuery setObjectValue:[self query]];
	} else if( [self format] == JVChatViewBooleanCriterionFormat ) {
		[booleanKindButton selectItemAtIndex:[booleanKindButton indexOfItemWithTag:[self kind]]];
	} else if( [self format] == JVChatViewListCriterionFormat ) {
		[listKindButton selectItemAtIndex:[listKindButton indexOfItemWithTag:[self kind]]];
		[listOperationButton selectItemAtIndex:[listOperationButton indexOfItemWithTag:[self operation]]];
		int index = [listQuery indexOfItemWithRepresentedObject:[self query]];
		if( index == -1 && [[self query] isKindOfClass:[NSNumber class]] )
			index = [(NSNumber *)[self query] intValue];
		if( [listQuery numberOfItems] < index ) index = -1;
		[listQuery selectItemAtIndex:index];
	}
}

#pragma mark -

- (NSView *) view {
	if( ! subview ) [NSBundle loadNibNamed:@"JVChatViewCriterion" owner:self];
	return subview;
}

#pragma mark -

- (JVChatViewCriterionFormat) format {
	return _format;
}

- (void) setFormat:(JVChatViewCriterionFormat) format {
	if( format != _format ) {
		_format = format;

		[tabView selectTabViewItemWithIdentifier:[NSString stringWithFormat:@"%d", format]];

		if( [self format] == JVChatViewTextCriterionFormat ) {
			[textKindButton selectItemAtIndex:[textKindButton indexOfItemWithTag:[self kind]]];
		} else if( [self format] == JVChatViewBooleanCriterionFormat ) {
			[booleanKindButton selectItemAtIndex:[booleanKindButton indexOfItemWithTag:[self kind]]];
		} else if( [self format] == JVChatViewListCriterionFormat ) {
			[listKindButton selectItemAtIndex:[listKindButton indexOfItemWithTag:[self kind]]];
		}
	}
}

#pragma mark -

- (JVChatViewCriterionKind) kind {
	return _kind;
}

- (void) setKind:(JVChatViewCriterionKind) kind {
	if( kind != _kind ) {
		_kind = kind;

		switch( kind ) {
		case JVChatViewTitleCriterionKind:
		case JVChatViewConnectionAddressCriterionKind:
			[self setFormat:JVChatViewTextCriterionFormat];
			break;
		case JVChatViewTypeCriterionKind:
		case JVChatViewConnectionTypeCriterionKind:
		case JVChatViewOpenMethodCriterionKind:
			[self setFormat:JVChatViewListCriterionFormat];
			break;
		default:
		case JVChatViewEveryPanelCriterionKind:
			[self setFormat:JVChatViewBooleanCriterionFormat];
		}
	}
}

#pragma mark -

- (JVChatViewCriterionOperation) operation {
	return _operation;
}

- (void) setOperation:(JVChatViewCriterionOperation) operation {
	_operation = operation;

	if( [self format] == JVChatViewTextCriterionFormat ) {
		[textOperationButton selectItemAtIndex:[textOperationButton indexOfItemWithTag:[self operation]]];
	} else if( [self format] == JVChatViewListCriterionFormat ) {
		[listOperationButton selectItemAtIndex:[listOperationButton indexOfItemWithTag:[self operation]]];
	}
}

#pragma mark -

- (id) query {
	return _query;
}

- (void) setQuery:(id) query {
	[_query autorelease];
	_query = [query retain];

	if( [self format] == JVChatViewTextCriterionFormat ) {
		[textQuery setObjectValue:query];
	} else if( [self format] == JVChatViewListCriterionFormat ) {
		int index = [listQuery indexOfItemWithRepresentedObject:query];
		if( index == -1 && [query isKindOfClass:[NSNumber class]] )
			index = [(NSNumber *)query intValue];
		if( [listQuery numberOfItems] < index ) index = -1;
		[listQuery selectItemAtIndex:index];
	}
}

#pragma mark -

- (IBAction) selectCriterionKind:(id) sender {
	_changed = YES;
	[self setKind:[[sender selectedItem] tag]];

	if( [self format] == JVChatViewTextCriterionFormat ) {
		[self setOperation:JVChatViewTextContainsCriterionOperation];
	} else if( [self format] == JVChatViewBooleanCriterionFormat ) {
		[self setOperation:JVChatViewNoCriterionOperation];
	} else if( [self format] == JVChatViewListCriterionFormat ) {
		[self setOperation:JVChatViewIsEqualCriterionOperation];
	}
}

- (IBAction) selectCriterionOperation:(id) sender {
	_changed = YES;
	[self setOperation:[[sender selectedItem] tag]];
}

- (IBAction) changeQuery:(id) sender {
	_changed = YES;
	if( [self format] == JVChatViewTextCriterionFormat ) {
		[self setQuery:[textQuery stringValue]];
	} else if( [self format] == JVChatViewListCriterionFormat ) {
		NSMenuItem *mitem = [listQuery selectedItem];
		if( [mitem representedObject] ) [self setQuery:[mitem representedObject]];
		else [self setQuery:[NSNumber numberWithInt:[listQuery indexOfSelectedItem]]];
	}
}

- (void) controlTextDidChange:(NSNotification *) notification {
	_changed = YES;
}

- (IBAction) noteOtherChanges:(id) sender {
	_changed = YES;
}

#pragma mark -

- (BOOL) changedSinceLastMatch {
	return _changed;
}

- (BOOL) matchChatView:(id <JVChatViewController>) chatView ignoringCase:(BOOL) ignoreCase {
	_changed = NO;

	if( [self format] == JVChatViewTextCriterionFormat ) {
		NSString *value = nil;
		if( [self kind] == JVChatViewTitleCriterionKind ) value = [chatView title];
		else if( [self kind] == JVChatViewConnectionAddressCriterionKind ) value = [[chatView connection] server];

		BOOL match = NO;
		JVChatViewCriterionOperation oper = [self operation];
		if( oper == JVChatViewTextMatchCriterionOperation || oper == JVChatViewTextDoesNotMatchCriterionOperation ) {
			AGRegex *regex = [AGRegex regexWithPattern:[self query] options:( ignoreCase ? AGRegexCaseInsensitive : 0 )];
			AGRegexMatch *result = [regex findInString:value];
			if( result ) match = YES;
			if( oper == JVChatViewTextDoesNotMatchCriterionOperation ) match = ! match;
		} else if( oper >= 3 && oper <= 6 ) {
			unsigned int options = ( ignoreCase ? NSCaseInsensitiveSearch : 0 );
			if( oper == JVChatViewTextBeginsWithCriterionOperation ) options = NSAnchoredSearch;
			else if( oper == JVChatViewTextEndsWithCriterionOperation ) options = ( NSAnchoredSearch | NSBackwardsSearch );
			NSRange range = [value rangeOfString:[self query] options:options];
			match = ( range.location != NSNotFound );
			if( oper == JVChatViewTextDoesNotContainCriterionOperation ) match = ! match;
		} else if( oper == JVChatViewIsEqualCriterionOperation ) {
			if( ! ignoreCase ) match = [value isEqualToString:[self query]];
			else match = ! [value caseInsensitiveCompare:[self query]];
		}

		return match;
	}

	return NO;
}

#pragma mark -

- (NSView *) firstKeyView {
	if( [self format] == JVChatViewTextCriterionFormat ) {
		return textKindButton;
	} else if( [self format] == JVChatViewBooleanCriterionFormat ) {
		return booleanKindButton;
	} else if( [self format] == JVChatViewListCriterionFormat ) {
		return listKindButton;
	} else return nil;
}

- (NSView *) lastKeyView {
	if( [self format] == JVChatViewTextCriterionFormat ) {
		return textQuery;
	} else if( [self format] == JVChatViewBooleanCriterionFormat ) {
		return booleanKindButton;
	} else if( [self format] == JVChatViewListCriterionFormat ) {
		return listQuery;
	} else return nil;
}
@end