#import "CQPrinterPage.h"

static CGFloat CQInchesInAPoint = 72.;
static CGFloat CQCentimetersInAnInch = 2.54;

MVInline CGFloat CQInchesToPoints(CGFloat inches) {
	return inches * CQInchesInAPoint;
}

MVInline CGFloat CQCentimetersToPoints(CGFloat centimeters) {
	return centimeters * (CQInchesInAPoint / CQCentimetersInAnInch);
}

@implementation CQPrinterPage
- (BOOL) usesNorthAmericanPaper {
	NSString *countryCode = [[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode] lowercaseString];
	return [countryCode isEqualToString:@"us"] || [countryCode isEqualToString:@"ca"] || [countryCode isEqualToString:@"mx"];
}

#pragma mark -

- (CGSize) suggestedPaperSize {
	if (self.usesNorthAmericanPaper)
		return CGSizeMake(CQInchesToPoints(8.5), CQInchesToPoints(11.)); // 8.5x11
	return CGSizeMake(CQCentimetersToPoints(210.), CQCentimetersToPoints(297.)); // A4
}

- (UIEdgeInsets) suggestedPaperMargin {
	return UIEdgeInsetsMake(CQInchesToPoints(.75), CQInchesToPoints(.75), CQInchesToPoints(1.), CQInchesToPoints(.75));
}
@end
