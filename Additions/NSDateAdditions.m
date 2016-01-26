#import "NSDateAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDate (NSDateAdditions)
+ (NSMutableDictionary *) cq_cacheDictionary {
	static NSMutableDictionary *cacheDictionary = nil;
	if (cacheDictionary)
		return cacheDictionary;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
	cacheDictionary = [[NSMutableDictionary alloc] init];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && defined(__MAC_10_9) && __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_9 && (__LP64__ || NS_BUILD_32_LIKE_64)
	cacheDictionary = [[NSMutableDictionary alloc] init];
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

+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(NSDateFormatterStyle) dateStyle timeStyle:(NSDateFormatterStyle) timeStyle {
	NSString *key = [NSString stringWithFormat:@"%lu-%lu", (unsigned long)dateStyle, (unsigned long)timeStyle];
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

NSString *humanReadableTimeInterval(NSTimeInterval interval, BOOL longFormat) {
	NSDictionary *singularWords = @{
		@(1U): NSLocalizedString(@"second", "Singular second"), @(60U): NSLocalizedString(@"minute", "Singular minute"),
		@(3600U): NSLocalizedString(@"hour", "Singular hour"), @(86400U): NSLocalizedString(@"day", "Singular day"),
		@(604800U): NSLocalizedString(@"week", "Singular week"), @(2628000U): NSLocalizedString(@"month", "Singular month"),
		@(31536000U): NSLocalizedString(@"year", "Singular year")
	};

	NSDictionary *pluralWords = @{
		@(1U): NSLocalizedString(@"seconds", "Plural seconds"), @(60U): NSLocalizedString(@"minutes", "Plural minutes"),
		@(3600U): NSLocalizedString(@"hours", "Plural hours"), @(86400U): NSLocalizedString(@"days", "Plural days"),
		@(604800U): NSLocalizedString(@"weeks", "Plural weeks"), @(2628000U): NSLocalizedString(@"months", "Plural months"),
		@(31536000U): NSLocalizedString(@"years", "Plural years")
	};

	NSArray <NSNumber *> *breaks = @[ @(1U), @(60U), @(3600U), @(86400U), @(604800U), @(2628000U), @(31536000U) ];

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

NS_ASSUME_NONNULL_END
