//  Created by Kevin Ballard on 2/12/05.
//  Copyright 2005 Kevin Ballard. All rights reserved.

@interface NSScanner (NSScannerAdditions)
- (BOOL) scanCharacterInto:(unichar *) unicharValue;
- (BOOL) scanStringLength:(int) length intoString:(NSString **) stringValue;
- (BOOL) scanCharactersFromSet:(NSCharacterSet *) scanSet maxLength:(int) length intoString:(NSString **) stringValue;
@end
