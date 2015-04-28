#import <Foundation/Foundation.h>

extern NSString * __nonnull JVEmoticonSetsScannedNotification;

@interface JVEmoticonSet : NSObject {
	NSBundle *_bundle;
	NSDictionary *_emoticonMappings;
	NSArray *_emoticonMenu;
}
+ (void) scanForEmoticonSets;
+ (nonnull NSSet *) emoticonSets;
+ (nullable instancetype) emoticonSetWithIdentifier:(nonnull NSString *) identifier;
+ (nullable instancetype) newWithBundle:(nonnull NSBundle *) bundle;

+ (nonnull instancetype) textOnlyEmoticonSet;

- (nullable instancetype) initWithBundle:(nonnull NSBundle *) bundle;

- (void) unlink;
@property (readonly, getter=isCompliant) BOOL compliant;

- (void) performEmoticonSubstitution:(nonnull NSMutableAttributedString *) string;

@property (readonly, strong, nonatomic, null_resettable) NSBundle *bundle;
@property (readonly, copy, nonnull) NSString *identifier;

- (NSComparisonResult) compare:(nonnull JVEmoticonSet *) style;
@property (readonly, copy, nonnull) NSString *displayName;

@property (readonly, copy, nonnull) NSDictionary *emoticonMappings;
@property (readonly, copy, nonnull) NSArray *emoticonMenuItems;

@property (readonly, copy, nullable) NSURL *baseLocation;
@property (readonly, copy, nullable) NSURL *styleSheetLocation;

@property (readonly, copy, nonnull) NSString *contentsOfStyleSheet;
@end
