NS_ASSUME_NONNULL_BEGIN

@interface NSRegularExpression (Additions)
+ (NSRegularExpression *) cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error;
- (NSArray <NSTextCheckingResult *> *) cq_matchesInString:(NSString *) string;
@end

NS_ASSUME_NONNULL_END
