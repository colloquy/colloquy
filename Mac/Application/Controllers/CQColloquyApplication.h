@interface CQColloquyApplication : NSApplication <NSApplicationDelegate> {
@private
	NSDate *_launchDate;
}
+ (CQColloquyApplication *) sharedApplication;

@property (nonatomic, readonly) NSDate *launchDate;
@end
