NS_ASSUME_NONNULL_BEGIN

@interface NSDate (NSDateAdditions)
+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(int /*NSDateFormatterStyle*/) dateStyle timeStyle:(int /*NSDateFormatterStyle*/) timeStyle;
+ (NSString *) formattedStringWithDate:(NSDate *) date dateFormat:(NSString *) format;

+ (NSString *) formattedShortDateStringForDate:(NSDate *) date;
+ (NSString *) formattedShortDateAndTimeStringForDate:(NSDate *) date;
+ (NSString *) formattedShortTimeStringForDate:(NSDate *) date;

@property (readonly, copy) NSString *localizedDescription;
@end

NSString *humanReadableTimeInterval(NSTimeInterval interval);

NS_ASSUME_NONNULL_END
