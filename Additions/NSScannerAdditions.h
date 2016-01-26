//  Created by Kevin Ballard on 2/12/05.
//  Copyright 2005 Kevin Ballard. All rights reserved.

#import <Foundation/NSScanner.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSScanner (NSScannerAdditions)
- (BOOL) scanCharactersFromSet:(NSCharacterSet *) scanSet maxLength:(NSUInteger) maxLength intoString:(NSString *__nullable * __nullable) stringValue;
@end

NS_ASSUME_NONNULL_END
