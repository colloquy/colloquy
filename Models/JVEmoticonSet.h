extern NSString *JVEmoticonSetsScannedNotification;

@interface JVEmoticonSet : NSObject {
	NSBundle *_bundle;
	NSDictionary *_emoticonMappings;
	NSArray *_emoticonMenu;
}
+ (void) scanForEmoticonSets;
+ (NSSet *) emoticonSets;
+ (id) emoticonSetWithIdentifier:(NSString *) identifier;
+ (id) newWithBundle:(NSBundle *) bundle;

+ (id) textOnlyEmoticonSet;

- (id) initWithBundle:(NSBundle *) bundle;

- (void) unlink;
- (BOOL) isCompliant;

- (void) performEmoticonSubstitution:(NSMutableAttributedString *) string;

- (NSBundle *) bundle;
- (NSString *) identifier;

- (NSComparisonResult) compare:(JVEmoticonSet *) style;
- (NSString *) displayName;

- (NSDictionary *) emoticonMappings;
- (NSArray *) emoticonMenuItems;

- (NSURL *) baseLocation;
- (NSURL *) styleSheetLocation;

- (NSString *) contentsOfStyleSheet;
@end
