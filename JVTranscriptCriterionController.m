// Concept by Joar Wingfors.
// Created by Timothy Hatcher for Colloquy.
// Copyright Joar Wingfors and Timothy Hatcher. All rights reserved.

#import "JVTranscriptCriterionController.h"
#import "JVChatMessage.h"

@implementation JVTranscriptCriterionController
+ (id) controller {
	return [[[self alloc] init] autorelease];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		if( ! [NSBundle loadNibNamed:@"JVTranscriptCriterion" owner:self] ) {
			[self release];
			self = nil;
			_changed = NO;
		}

		[self setKind:JVTranscriptMessageBodyCriterionKind];	
	}

	return self;
}

- (void) dealloc {
	[subview release];
	[kindMenu release];

	subview = nil;
	kindMenu = nil;

	[super dealloc];
}

#pragma mark -

- (NSView *) view {
	return subview;
}

#pragma mark -

- (JVTranscriptCriterionFormat) format {
	return _format;
}

- (void) setFormat:(JVTranscriptCriterionFormat) format {
	if( format != _format ) {
		_format = format;
		[tabView selectTabViewItemWithIdentifier:[NSString stringWithFormat:@"%d", format]];
	}
}

#pragma mark -

- (JVTranscriptCriterionKind) kind {
	return _kind;
}

- (void) setKind:(JVTranscriptCriterionKind) kind {
	if( kind != _kind ) {
		_kind = kind;

		switch( kind ) {
		case JVTranscriptSenderNameCriterionKind:
		case JVTranscriptMessageBodyCriterionKind:
			[self setFormat:JVTranscriptTextCriterionFormat];
			break;
		case JVTranscriptDateReceivedCriterionKind:
			[self setFormat:JVTranscriptDateCriterionFormat];
			break;
		default:
		case JVTranscriptSenderInBuddyListCriterionKind:
		case JVTranscriptSenderNotInBuddyListCriterionKind:
		case JVTranscriptSenderIgnoredCriterionKind:
		case JVTranscriptSenderNotIgnoredCriterionKind:
		case JVTranscriptMessageIgnoredCriterionKind:
		case JVTranscriptMessageNotIgnoredCriterionKind:
		case JVTranscriptMessageAddressedToMeCriterionKind:
		case JVTranscriptMessageNotAddressedToMeCriterionKind:
		case JVTranscriptMessageFromMeCriterionKind:
		case JVTranscriptMessageNotFromMeCriterionKind:
		case JVTranscriptMessageHighlightedCriterionKind:
		case JVTranscriptMessageNotHighlightedCriterionKind:
		case JVTranscriptMessageIsActionCriterionKind:
		case JVTranscriptMessageIsNotActionCriterionKind:
			[self setFormat:JVTranscriptBooleanCriterionFormat];
		}
	}
}

#pragma mark -

- (IBAction) selectCriterionKind:(id) sender {
	_changed = YES;
	[self setKind:[[sender selectedItem] tag]];
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

- (BOOL) matchMessage:(JVChatMessage *) message ignoreCase:(BOOL) ignoreCase {
	_changed = NO;
	if( [self format] == JVTranscriptTextCriterionFormat ) {
		NSString *value = nil;
		if( [self kind] == JVTranscriptSenderNameCriterionKind ) value = [[message sender] description];
		else if( [self kind] == JVTranscriptMessageBodyCriterionKind ) value = [message bodyAsPlainText];

		BOOL match = NO;
		unsigned int tag = [textOperationButton selectedTag];
		if( tag == 1 || tag == 2 ) {
			AGRegex *regex = [AGRegex regexWithPattern:[textQuery stringValue] options:( ignoreCase ? AGRegexCaseInsensitive : 0 )];
			AGRegexMatch *result = [regex findInString:value];
			if( result ) match = YES;
			if( tag == 2 ) match = ! match;
		} else if( tag >= 3 && tag <= 6 ) {
			unsigned int options = ( ignoreCase ? NSCaseInsensitiveSearch : 0 );
			if( tag == 5 ) options = NSAnchoredSearch;
			else if( tag == 6 ) options = ( NSAnchoredSearch | NSBackwardsSearch );
			NSRange range = [value rangeOfString:[textQuery stringValue] options:options];
			match = ( range.location != NSNotFound );
			if( tag == 4 ) match = ! match;
		} else if( tag == 7 ) {
			if( ! ignoreCase ) match = [value isEqualToString:[textQuery stringValue]];
			else match = ! [value caseInsensitiveCompare:[textQuery stringValue]];
		}

		return match;
	} else if( [self kind] == JVTranscriptDateReceivedCriterionKind ) {
		double diff = ABS( [[message date] timeIntervalSinceNow] );
		unsigned int operation = [dateOperationButton selectedTag];
		unsigned int unit = [dateUnitsButton selectedTag];
		unsigned int comp = [dateQuery intValue];

		switch( unit ) {
			case 6: comp *= 4;
			case 5: comp *= 7;
			case 4: comp *= 24;
			case 3: comp *= 60;
			case 2: comp *= 60;
		}

		if( operation == 1 ) return ( diff < comp );
		else return ( diff > comp );
	} else {
		switch( [self kind] ) {
		default:
			return YES;
		case JVTranscriptSenderInBuddyListCriterionKind:
		case JVTranscriptSenderNotInBuddyListCriterionKind:
			return YES;
		case JVTranscriptSenderIgnoredCriterionKind:
			return ( [message ignoreStatus] == JVUserIgnored );
		case JVTranscriptSenderNotIgnoredCriterionKind:
			return ( [message ignoreStatus] != JVUserIgnored );
		case JVTranscriptMessageIgnoredCriterionKind:
			return ( [message ignoreStatus] == JVMessageIgnored );
		case JVTranscriptMessageNotIgnoredCriterionKind:
			return ( [message ignoreStatus] != JVMessageIgnored );
		case JVTranscriptMessageFromMeCriterionKind:
			return [message senderIsLocalUser];
		case JVTranscriptMessageNotFromMeCriterionKind:
			return ( ! [message senderIsLocalUser] );
		case JVTranscriptMessageAddressedToMeCriterionKind:
		case JVTranscriptMessageNotAddressedToMeCriterionKind:
			return YES;
		case JVTranscriptMessageHighlightedCriterionKind:
			return [message isHighlighted];
		case JVTranscriptMessageNotHighlightedCriterionKind:
			return ( ! [message isHighlighted] );
		case JVTranscriptMessageIsActionCriterionKind:
			return [message isAction];
		case JVTranscriptMessageIsNotActionCriterionKind:
			return ( ! [message isAction] );
		}
	}

	return NO;
}

- (id) query {
	if( [self format] == JVTranscriptTextCriterionFormat ) {
		return [textQuery stringValue];
	} else if( [self format] == JVTranscriptDateCriterionFormat ) {
		return [dateQuery stringValue];
	} else if( [self format] == JVTranscriptListCriterionFormat ) {
		NSMenuItem *mitem = [listQuery selectedItem];
		if( [mitem representedObject] ) return [mitem representedObject];
		else return [NSNumber numberWithInt:[listQuery indexOfSelectedItem]];
	} else return nil;
}

- (void) setQuery:(id) query {
	if( [self format] == JVTranscriptTextCriterionFormat ) {
		[textQuery setObjectValue:query];
	} else if( [self format] == JVTranscriptDateCriterionFormat ) {
		[dateQuery setObjectValue:query];
	} else if( [self format] == JVTranscriptListCriterionFormat ) {
		int index = [listQuery indexOfItemWithRepresentedObject:query];
		if( index == -1 && [query isKindOfClass:[NSNumber class]] )
			index = [(NSNumber *)query intValue];
		if( [listQuery numberOfItems] < index ) index = -1;
		[listQuery selectItemAtIndex:index];
	}
}
@end