#import "MVChatUserAdditions.h"
#import <ChatCore/NSDataAdditions.h>
#import <ChatCore/NSStringAdditions.h>

@implementation MVChatUser (MVChatUserAdditions)
- (NSString *) xmlDescription {
	return [self xmlDescriptionWithTagName:@"user"];
}

- (NSString *) xmlDescriptionWithTagName:(NSString *) tag {
	NSParameterAssert( [tag length] != 0 );

	// Full format will look like:
	// <user self="yes" nickname="..." hostmask="..." identifier="...">...</user>

	NSMutableString *ret = [NSMutableString string];
	[ret appendFormat:@"<%@", tag];

	if( [self isLocalUser] ) [ret appendString:@" self=\"yes\""];

	if( ! [[self displayName] isEqualToString:[self nickname]] )
		[ret appendFormat:@" nickname=\"%@\"", [[self nickname] stringByEncodingXMLSpecialCharactersAsEntities]];

	if( [[self username] length] && [[self address] length] )
		[ret appendFormat:@" hostmask=\"%@@%@\"", [[self username] stringByEncodingXMLSpecialCharactersAsEntities], [[self address] stringByEncodingXMLSpecialCharactersAsEntities]];

	id uniqueId = [self uniqueIdentifier];
	if( ! [uniqueId isEqual:[self nickname]] ) {
		if( [uniqueId isKindOfClass:[NSData class]] ) uniqueId = [uniqueId base64Encoding];
		else if( [uniqueId isKindOfClass:[NSString class]] ) uniqueId = [uniqueId stringByEncodingXMLSpecialCharactersAsEntities];
		[ret appendFormat:@" identifier=\"%@\"", uniqueId];
	}

	if( [self isServerOperator] ) [ret appendFormat:@" class=\"%@\"", @"server operator"];

	[ret appendFormat:@">%@</%@>", [[self displayName] stringByEncodingXMLSpecialCharactersAsEntities], tag];

	[ret stripIllegalXMLCharacters];
	return [NSString stringWithString:ret];
}
@end
