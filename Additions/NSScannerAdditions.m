//  Created by Kevin Ballard on 2/12/05.
//  Copyright 2005 Kevin Ballard. All rights reserved.

#import "NSScannerAdditions.h"

@implementation NSScanner (NSScannerAdditions)
- (BOOL) scanCharacterInto:(unichar *) unicharValue {
	if( ! [self isAtEnd] ) {
		unsigned location = [self scanLocation];
		*unicharValue = [[self string] characterAtIndex:location];
		[self setScanLocation:( location + 1 )];
		return YES;
	}

	return NO;
}

- (BOOL) scanStringLength:(unsigned) maxLength intoString:(NSString **) stringValue {
	if( ! [self isAtEnd] ) {
		unsigned location = [self scanLocation];
		NSString *source = [self string];
		unsigned length = MIN( maxLength, [source length] - location );
		if( length > 0 ) {
			*stringValue = [[self string] substringWithRange:NSMakeRange( location, length )];
			[self setScanLocation:( location + length )];
			return YES;
		}
	}

	return NO;
}

- (BOOL) scanCharactersFromSet:(NSCharacterSet *) scanSet maxLength:(unsigned) maxLength intoString:(NSString **) stringValue {
	if( ! [self isAtEnd] ) {
		unsigned location = [self scanLocation];
		NSString *source = [self string];
		unsigned length = MIN( maxLength, [source length] - location );
		if( length > 0 ) {
			unichar *chars = calloc( length, sizeof( unichar ) );
			[source getCharacters:chars range:NSMakeRange( location, length )];

			unsigned i = 0;
			for( i = 0; i < length && [scanSet characterIsMember:chars[i]]; i++ );

			free( chars );

			if( i > 0 ) {
				if( stringValue )
					*stringValue = [source substringWithRange:NSMakeRange( location, i )];
				[self setScanLocation:( location + i )];
				return YES;
			}
		}
	}

	return NO;
}

- (BOOL) scanXMLTagIntoString:(NSString **) stringValue {
	if( ![self scanString:@"<" intoString:NULL] )
		return NO;

	NSString *tag = nil;
	BOOL result = [self scanUpToString:@">" intoString:&tag];
	if( result ) [self scanString:@">" intoString:NULL];

	if( result && stringValue )
		*stringValue = [NSString stringWithFormat:@"<%@>", tag];

	return result;
}

- (BOOL) scanUpToXMLTagIntoString:(NSString **) stringValue {
	return [self scanUpToString:@"<" intoString:stringValue];
}
@end
