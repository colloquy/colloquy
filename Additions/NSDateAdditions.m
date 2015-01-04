#import "NSDateAdditions.h"

@implementation NSDate (NSDateAdditions)
+ (NSString *) formattedStringWithDate:(NSDate *) date dateFormat:(NSString *) format {
	NSDateFormatter *dateFormatter = ([NSThread currentThread].threadDictionary)[format];
	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateFormat = format;

		[NSThread currentThread].threadDictionary[format] = dateFormatter;

		MVAutorelease(dateFormatter);
	}

	return [dateFormatter stringFromDate:date];
}

+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(int) dateStyle timeStyle:(int) timeStyle {
	NSMutableDictionary *dateFormatters = [NSThread currentThread].threadDictionary[@"dateFormatters"];
	if (!dateFormatters) {
		dateFormatters = [NSMutableDictionary dictionary];

		[NSThread currentThread].threadDictionary[@"dateFormatters"] = dateFormatters;
	}

	NSString *key = [NSString stringWithFormat:@"%d-%d", dateStyle, timeStyle];
	NSDateFormatter *dateFormatter = dateFormatters[key];

	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		dateFormatter.dateStyle = dateStyle;
		dateFormatter.timeStyle = timeStyle;

		dateFormatters[key] = dateFormatter;

		MVAutorelease(dateFormatter);
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

NSString *humanReadableTimeInterval(NSTimeInterval interval, BOOL longFormat) {
	static NSDictionary *singularWords;
	if (!singularWords)
		singularWords = @{
						  @(1U): NSLocalizedString(@"second", "Singular second"), @(60U): NSLocalizedString(@"minute", "Singular minute"),
						  @(3600U): NSLocalizedString(@"hour", "Singular hour"), @(86400U): NSLocalizedString(@"day", "Singular day"),
						  @(604800U): NSLocalizedString(@"week", "Singular week"), @(2628000U): NSLocalizedString(@"month", "Singular month"),
						  @(31536000U): NSLocalizedString(@"year", "Singular year")
						  };

	static NSDictionary *pluralWords;
	if (!pluralWords)
		pluralWords = @{
						@(1U): NSLocalizedString(@"seconds", "Plural seconds"), @(60U): NSLocalizedString(@"minutes", "Plural minutes"),
						@(3600U): NSLocalizedString(@"hours", "Plural hours"), @(86400U): NSLocalizedString(@"days", "Plural days"),
						@(604800U): NSLocalizedString(@"weeks", "Plural weeks"), @(2628000U): NSLocalizedString(@"months", "Plural months"),
						@(31536000U): NSLocalizedString(@"years", "Plural years")
						};

	static NSArray *breaks;
	if (!breaks)
		breaks = @[@(1U), @(60U), @(3600U), @(86400U), @(604800U), @(2628000U), @(31536000U)];

	NSTimeInterval seconds = ABS(interval);

	NSUInteger i = 0;
	while (i < [breaks count] && seconds >= [breaks[i] doubleValue]) ++i;
	if (i > 0) --i;

	float stop = [breaks[i] floatValue];
	NSUInteger value = (seconds / stop);
	NSDictionary *words = (value != 1 ? pluralWords : singularWords);

	NSMutableString *result = [NSMutableString stringWithFormat:NSLocalizedString(@"%u %@", "Time with a unit word"), value, words[@(stop)]];
	if (longFormat && i > 0) {
		NSUInteger remainder = ((NSUInteger)seconds % (NSUInteger)stop);
		stop = [breaks[--i] floatValue];
		remainder = (remainder / stop);
		if (remainder) {
			words = (remainder != 1 ? pluralWords : singularWords);
			[result appendFormat:NSLocalizedString(@" %u %@", "Time with a unit word, appended to a previous larger unit of time"), remainder, words[breaks[i]]];
		}
	}
	
	return result;
}
