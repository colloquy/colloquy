@interface NSURL (NSURLAdditions)
+ (id) URLWithInternetLocationFile:(NSString *) path;
- (void) writeToInternetLocationFile:(NSString *) path;
@end
