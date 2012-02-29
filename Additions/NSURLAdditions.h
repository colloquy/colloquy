@interface NSURL (NSURLAdditions)
+ (id) URLWithInternetLocationFile:(NSString *) path; // this can likely be removed in 3.0, when we don't need to migrate old favorites anymore
@end
