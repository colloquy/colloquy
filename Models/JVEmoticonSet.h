#import <Foundation/Foundation.h>
#import <AppKit/NSMenuItem.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * __nonnull JVEmoticonSetsScannedNotification;

COLLOQUY_EXPORT
@interface JVEmoticonSet : NSObject {
	NSBundle *_bundle;
	NSDictionary *_emoticonMappings;
	NSArray *_emoticonMenu;
}
+ (void) scanForEmoticonSets;
#if __has_feature(objc_class_property)
@property (readonly, class, copy) NSSet<JVEmoticonSet*> *emoticonSets;
#else
+ (NSSet<JVEmoticonSet*> *) emoticonSets;
#endif
+ (nullable JVEmoticonSet*) emoticonSetWithIdentifier:(NSString *) identifier;
+ (nullable JVEmoticonSet*) newWithBundle:(NSBundle *) bundle NS_SWIFT_NAME(with(bundle:));

#if __has_feature(objc_class_property)
@property (class, strong, readonly) JVEmoticonSet* textOnlyEmoticonSet;
#else
+ (JVEmoticonSet*) textOnlyEmoticonSet;
#endif

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
