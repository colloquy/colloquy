#import <Foundation/Foundation.h>
#import <AppKit/NSMenuItem.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * __nonnull JVEmoticonSetsScannedNotification;

@interface JVEmoticonSet : NSObject {
	NSBundle *_bundle;
	NSDictionary *_emoticonMappings;
	NSArray *_emoticonMenu;
}
+ (void) scanForEmoticonSets;
+ (NSSet<JVEmoticonSet*> *) emoticonSets;
+ (nullable instancetype) emoticonSetWithIdentifier:(NSString *) identifier;
+ (nullable instancetype) newWithBundle:(NSBundle *) bundle;

+ (instancetype) textOnlyEmoticonSet;

- (nullable instancetype) initWithBundle:(nonnull NSBundle *) bundle;

- (void) unlink;
@property (readonly, getter=isCompliant) BOOL compliant;

- (void) performEmoticonSubstitution:(NSMutableAttributedString *) string;

@property (readonly, strong, nonatomic, null_resettable) NSBundle *bundle;
@property (readonly, copy) NSString *identifier;

- (NSComparisonResult) compare:(JVEmoticonSet *) style;
@property (readonly, copy) NSString *displayName;

@property (readonly, copy) NSDictionary<NSString*, NSArray<NSString*>*> *emoticonMappings;
@property (readonly, copy) NSArray<NSMenuItem*> *emoticonMenuItems;

@property (readonly, copy, nullable) NSURL *baseLocation;
@property (readonly, copy, nullable) NSURL *styleSheetLocation;

@property (readonly, copy) NSString *contentsOfStyleSheet;
@end

NS_ASSUME_NONNULL_END
