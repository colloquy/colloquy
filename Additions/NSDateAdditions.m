#import "NSDateAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDate (NSDateAdditions)
+ (NSMutableDictionary *) cq_cacheDictionary {
	static NSMutableDictionary *cacheDictionary = nil;
	if (cacheDictionary)
		return cacheDictionary;

	cacheDictionary = [NSMutableDictionary dictionary];

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

+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(NSDateFormatterStyle) dateStyle timeStyle:(NSDateFormatterStyle) timeStyle {
	NSString *key = [[NSString alloc] initWithFormat:@"%lu-%lu", (unsigned long)dateStyle, (unsigned long)timeStyle];
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

@implementation NSString (NSDateAdditions)
- (NSDate *) dateFromFormat:(NSString *) format {
	NSDateFormatter *dateFormatter = [NSDate cq_cacheDictionary][format];
	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateFormat = format;

		[NSDate cq_cacheDictionary][format] = dateFormatter;
	}

	return [dateFormatter dateFromString:self];
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
