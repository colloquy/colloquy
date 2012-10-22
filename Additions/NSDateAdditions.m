#import "NSDateAdditions.h"

@implementation NSDate (NSDateAdditions)
+ (NSString *) formattedStringWithDate:(NSDate *) date dateFormat:(NSString *) format {
	NSDateFormatter *dateFormatter = [[NSThread currentThread].threadDictionary objectForKey:format];
	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateFormat = format;

		[[NSThread currentThread].threadDictionary setObject:dateFormatter forKey:format];

		[dateFormatter release];
	}

	return [dateFormatter stringFromDate:date];
}

+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(NSDateFormatterStyle) dateStyle timeStyle:(NSDateFormatterStyle) timeStyle {
	NSMutableSet *dateFormatters = [[[NSThread currentThread].threadDictionary objectForKey:@"dateFormatters"] retain];
	if (!dateFormatters) {
		dateFormatters = [[NSMutableSet alloc] initWithCapacity:3];
		[[NSThread currentThread].threadDictionary setObject:dateFormatters forKey:@"dateFormatters"];
	}

	NSDateFormatter *dateFormatter = nil;
	for (dateFormatter in dateFormatters) {
		if (dateFormatter.dateStyle == dateStyle && dateFormatter.timeStyle == timeStyle) {
			[dateFormatter retain];
			break;
		}

		dateFormatter = nil;
	}

	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateStyle = dateStyle;
		dateFormatter.timeStyle = timeStyle;
		[dateFormatters addObject:dateFormatter];
	}

	NSString *formattedDate = [dateFormatter stringFromDate:date];
	[dateFormatter release];
	[dateFormatters release];

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
	return [NSDate formattedStringWithDate:[NSDate date] dateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
}
@end
