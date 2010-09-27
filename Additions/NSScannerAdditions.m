//  Created by Kevin Ballard on 2/12/05.
//  Copyright 2005 Kevin Ballard. All rights reserved.

#import "NSScannerAdditions.h"

@implementation NSScanner (NSScannerAdditions)
- (BOOL) scanCharactersFromSet:(NSCharacterSet *) scanSet maxLength:(NSUInteger) maxLength intoString:(NSString **) stringValue {
	if( ! [self isAtEnd] ) {
		NSUInteger location = [self scanLocation];
		NSString *source = [self string];
		NSUInteger length = MIN( maxLength, source.length - location );
		if( length > 0 ) {
			unichar *chars = calloc( length, sizeof( unichar ) );
			[source getCharacters:chars range:NSMakeRange( location, length )];

			NSUInteger i = 0;
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
@end
