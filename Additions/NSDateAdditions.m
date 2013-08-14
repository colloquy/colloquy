#import "NSDateAdditions.h"

@implementation NSDate (NSDateAdditions)
+ (NSString *) formattedStringWithDate:(NSDate *) date dateFormat:(NSString *) format {
	NSDateFormatter *dateFormatter = [[NSThread currentThread].threadDictionary objectForKey:format];
	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateFormat = format;

		[[NSThread currentThread].threadDictionary setObject:dateFormatter forKey:format];
	}

	return [dateFormatter stringFromDate:date];
}

+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(int) dateStyle timeStyle:(int) timeStyle {
	NSMutableDictionary *dateFormatters = [[NSThread currentThread].threadDictionary objectForKey:@"dateFormatters"];
	if (!dateFormatters) {
		dateFormatters = [NSMutableDictionary dictionary];

		[[NSThread currentThread].threadDictionary setObject:dateFormatters forKey:@"dateFormatters"];
	}

	NSString *key = [NSString stringWithFormat:@"%d-%d", dateStyle, timeStyle];
	NSDateFormatter *dateFormatter = [dateFormatters objectForKey:key];

	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateStyle = dateStyle;
		dateFormatter.timeStyle = timeStyle;

		[dateFormatters setObject:dateFormatter forKey:key];
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
	return [NSDate formattedStringWithDate:[NSDate date] dateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
}
@end
