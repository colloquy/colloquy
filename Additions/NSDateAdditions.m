#import "NSDateAdditions.h"

@implementation NSDate (NSDateAdditions)
+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(NSDateFormatterStyle) dateStyle timeStyle:(NSDateFormatterStyle) timeStyle {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:dateStyle];
	[dateFormatter setTimeStyle:timeStyle];

	NSString *formattedDate = [dateFormatter stringFromDate:date];
	[dateFormatter release];

	return formattedDate;
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
	return [[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S %z" timeZone:[NSTimeZone localTimeZone] locale:[NSLocale currentLocale]];
}
@end
