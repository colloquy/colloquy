@interface NSBundle (NSBundleAdditions)
- (NSComparisonResult) compare:(NSBundle *) bundle;
@property (readonly, copy) NSString *displayName;
@end
