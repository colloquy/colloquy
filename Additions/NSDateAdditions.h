@interface NSDate (NSDateAdditions)
+ (NSString *) formattedStringWithDate:(NSDate *) date dateStyle:(NSDateFormatterStyle) dateStyle timeStyle:(NSDateFormatterStyle) timeStyle;

+ (NSString *) formattedShortDateStringForDate:(NSDate *) date;
+ (NSString *) formattedShortDateAndTimeStringForDate:(NSDate *) date;
+ (NSString *) formattedShortTimeStringForDate:(NSDate *) date;

- (NSString *) localizedDescription;
@end
