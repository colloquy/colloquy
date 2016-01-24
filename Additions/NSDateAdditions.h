NS_ASSUME_NONNULL_BEGIN

@interface NSDate (NSDateAdditions)
+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(NSDateFormatterStyle) dateStyle timeStyle:(NSDateFormatterStyle) timeStyle;
+ (NSString *) formattedStringWithDate:(NSDate *) date dateFormat:(NSString *) format;

+ (NSString *) formattedShortDateStringForDate:(NSDate *) date;
+ (NSString *) formattedShortDateAndTimeStringForDate:(NSDate *) date;
+ (NSString *) formattedShortTimeStringForDate:(NSDate *) date;

@property (readonly, copy) NSString *localizedDescription;
@end

NSString *humanReadableTimeInterval(NSTimeInterval interval, BOOL longFormat);

NS_ASSUME_NONNULL_END
