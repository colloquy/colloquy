#import "NSDateAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDate (NSDateAdditions)
+ (NSMutableDictionary *) cq_cacheDictionary {
	static NSMutableDictionary *cacheDictionary = nil;
	if (cacheDictionary)
		return cacheDictionary;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
	cacheDictionary = [NSMutableDictionary dictionary];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && defined(__MAC_10_9) && __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_9 && (__LP64__ || NS_BUILD_32_LIKE_64)
	cacheDictionary = [NSMutableDictionary dictionary];
#else
	cacheDictionary = [NSThread currentThread].threadDictionary;
#endif

	return cacheDictionary;
}

+ (NSString *) formattedStringWithDate:(NSDate *) date dateFormat:(NSString *) format {
	NSDateFormatter *dateFormatter = [self cq_cacheDictionary][format];
	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateFormat = format;

		[self cq_cacheDictionary][format] = dateFormatter;
	}

	return [dateFormatter stringFromDate:date];
}

+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(int) dateStyle timeStyle:(int) timeStyle {
	NSString *key = [NSString stringWithFormat:@"%d-%d", dateStyle, timeStyle];
	NSDateFormatter *dateFormatter = [self cq_cacheDictionary][key];

	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateStyle = dateStyle;
		dateFormatter.timeStyle = timeStyle;

		[self cq_cacheDictionary][key] = dateFormatter;
	}

	return [dateFormatter stringFromDate:date];
}

+ (NSString *) formattedShortDateStringForDate:(NSDate *) date {
	return [self formattedStringWithDate:date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
}

+ (NSString *) formattedShortDateAndTimeStringForDate:(NSDate *) date {
	return [self formattedStringWithDate:date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
}

+ (NSString *) formattedShortTimeStringForDate:(NSDate *) date {
	return [self formattedStringWithDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
}

#pragma mark -

- (NSString *) localizedDescription {
	return [NSDate formattedStringWithDate:self dateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
}
@end

NSString *humanReadableTimeInterval(NSTimeInterval interval) {
	NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
	formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
	formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
	formatter.collapsesLargestUnit = YES;

	return [formatter stringFromTimeInterval:interval];
}

NS_ASSUME_NONNULL_END
