//  Created by Kevin Ballard on 2/12/05.
//  Copyright 2005 Kevin Ballard. All rights reserved.

@interface NSScanner (NSScannerAdditions)
- (BOOL) scanCharacterInto:(unichar *) unicharValue;
- (BOOL) scanStringLength:(NSUInteger) length intoString:(NSString **) stringValue;
- (BOOL) scanCharactersFromSet:(NSCharacterSet *) scanSet maxLength:(NSUInteger) length intoString:(NSString **) stringValue;

- (BOOL) scanXMLTagIntoString:(NSString **) stringValue;
- (BOOL) scanUpToXMLTagIntoString:(NSString **) stringValue;
@end
