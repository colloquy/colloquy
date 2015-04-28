#import "NSRegularExpressionAdditions.h"

@interface NSRegularExpression (Additions)
+ (NSRegularExpression *) cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error;
- (NSArray *) cq_matchesInString:(NSString *) string;
@end
