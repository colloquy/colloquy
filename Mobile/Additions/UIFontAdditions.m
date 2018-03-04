#import "UIFontAdditions.h"

#import <CoreText/CoreText.h>

NSString *const CQRemoteFontCourierFontLoadingDidSucceedNotification = @"CQRemoteFontCourierFontLoadingDidSucceedNotification";
NSString *const CQRemoteFontCourierFontLoadingDidFailNotification = @"CQRemoteFontCourierFontLoadingDidFailNotification";

NSString *const CQRemoteFontCourierFontLoadingFontNameKey = @"CQRemoteFontCourierFontLoadingFontNameKey";
NSString *const CQRemoteFontCourierFontLoadingFontKey = @"CQRemoteFontCourierFontLoadingFontKey";

NSString *const CQRemoteFontCourierDidLoadFontListNotification = @"CQRemoteFontCourierDidLoadFontListNotification";
NSString *const CQRemoteFontCourierFontListKey = @"CQRemoteFontCourierFontListKey";


static NSString *NSStringFromCTFontDescriptorMatchingState(CTFontDescriptorMatchingState state) {
	switch (state) {
		case kCTFontDescriptorMatchingDidBegin: return @"kCTFontDescriptorMatchingDidBegin";
		case kCTFontDescriptorMatchingDidFinish: return @"kCTFontDescriptorMatchingDidFinish";
		case kCTFontDescriptorMatchingWillBeginQuerying: return @"kCTFontDescriptorMatchingWillBeginQuerying";
		case kCTFontDescriptorMatchingStalled: return @"kCTFontDescriptorMatchingStalled";
		case kCTFontDescriptorMatchingWillBeginDownloading: return @"kCTFontDescriptorMatchingWillBeginDownloading";
		case kCTFontDescriptorMatchingDownloading: return @"kCTFontDescriptorMatchingDownloading";
		case kCTFontDescriptorMatchingDidFinishDownloading: return @"kCTFontDescriptorMatchingDidFinishDownloading";
		case kCTFontDescriptorMatchingDidMatch: return @"kCTFontDescriptorMatchingDidMatch";
		case kCTFontDescriptorMatchingDidFailWithError: return @"kCTFontDescriptorMatchingDidFailWithError";
	}
}

NS_ASSUME_NONNULL_BEGIN

@interface CQRemoteFontSessionDelegate : NSObject <NSURLSessionDataDelegate>
@property (copy) void (^completionBlock)(NSData *, NSError *__nullable);
@end

@implementation CQRemoteFontSessionDelegate {
	NSMutableData *_data;
	NSHTTPURLResponse *_response;
}

+ (void) load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
/* // full set of headers, at the time of writing this code
	 ~ % curl -I http://mesu.apple.com/assets/com_apple_MobileAsset_Font/com_apple_MobileAsset_Font.xml
	 HTTP/1.1 200 OK
	 Server: Apache
	 ETag: "bf45098c8cb9a94fefed33ed61d7ea19:1407171245"
	 Content-MD5: v0UJjIy5qU/v7TPtYdfqGQ==
	 Last-Modified: Mon, 04 Aug 2014 16:02:13 GMT
	 Accept-Ranges: bytes
	 Content-Length: 1211520
	 Content-Type: application/xml
	 Cache-Control: max-age=348
	 Expires: Mon, 19 Oct 2015 12:16:50 GMT
	 Date: Mon, 19 Oct 2015 12:11:02 GMT
	 Connection: keep-alive
*/
		// https://en.wikipedia.org/wiki/HTTP_ETag
		NSDictionary *CQRemoteFontDefaults = @{ @"CQRemoteFont-ETag": @"\"bf45098c8cb9a94fefed33ed61d7ea19:1407171245\"" };

		[[NSUserDefaults standardUserDefaults] registerDefaults:CQRemoteFontDefaults];
	});
}

- (void) URLSession:(NSURLSession *) session dataTask:(NSURLSessionDataTask *) dataTask didReceiveResponse:(NSURLResponse *)response  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition)) completionHandler {
	if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
	if ((HTTPResponse.statusCode / 100) != 2) {
		completionHandler(NSURLSessionResponseCancel);

		return;
	}

	NSString *newETag = HTTPResponse.allHeaderFields[@"ETag"];
	NSString *lastKnownETag = [[NSUserDefaults standardUserDefaults] objectForKey:@"CQRemoteFont-ETag"];
	BOOL isSameETag = newETag.length && [newETag isEqualToString:lastKnownETag];

	if (!isSameETag) {
		_data = [NSMutableData data];
		_response = [HTTPResponse copy];

		completionHandler(NSURLSessionResponseAllow);
	} else {
		completionHandler(NSURLSessionResponseCancel);
	}
}

- (void) URLSession:(NSURLSession *) session dataTask:(NSURLSessionDataTask *) dataTask didReceiveData:(NSData *) data {
	[_data appendData:data];
}

- (void) URLSession:(NSURLSession *) session task:(NSURLSessionTask *) task didCompleteWithError:(NSError *__nullable) error {
	if (_completionBlock) {
		_completionBlock(_data, error);
	}

	if (_data.length && !error) {
		[[NSUserDefaults standardUserDefaults] setObject:_response.allHeaderFields[@"Content-MD5"] forKey:@"CQRemoteFont-Content-MD5"];
		[[NSUserDefaults standardUserDefaults] setObject:_response.allHeaderFields[@"Last-Modified"] forKey:@"CQRemoteFont-Last-Modified"];
	}
}
@end

#pragma mark -

@implementation UIFont (Additions)
static NSArray *__nullable availableRemoteFontNames = nil;

static BOOL loadedRemoteFontList = NO;
+ (void) cq_availableRemoteFontNames:(void (^)(NSArray *__nullable fontNames)) completion {
	static dispatch_once_t loadedStaleRemoteFontNamesList;
	dispatch_once(&loadedStaleRemoteFontNamesList, ^{
		availableRemoteFontNames = [[NSUserDefaults standardUserDefaults] arrayForKey:@"CQAvailableRemoteFontNames"];

		if (!availableRemoteFontNames.count) { // as of Mon, 04 Aug 2014 16:02:13 GMT
			availableRemoteFontNames = @[ @".DamascusPUA", @".DamascusPUABold", @".DamascusPUALight", @".DamascusPUAMedium", @".DamascusPUASemiBold", @".DecoTypeNaskhPUA", @".FarahPUA", @".LucidaGrandeUI", @".LucidaGrandeUI-Bold", @"AcademyEngravedLetPlain", @"Al-Firat", @"Al-Khalil", @"Al-KhalilBold", @"Al-Rafidain", @"AlBayan", @"AlBayan-Bold", @"AlRafidainAlFanni", @"AlTarikh", @"Algiers", @"AndaleMono", @"Apple-Chancery", @"AppleBraille", @"AppleBraille-Outline6Dot", @"AppleBraille-Outline8Dot", @"AppleBraille-Pinpoint6Dot", @"AppleBraille-Pinpoint8Dot", @"AppleMyungjo", @"AppleSDGothicNeo-ExtraBold", @"AppleSDGothicNeo-Heavy", @"AppleSymbols", @"Arial-Black", @"ArialHebrewScholar", @"ArialHebrewScholar-Bold", @"ArialHebrewScholar-Light", @"ArialNarrow", @"ArialNarrow-Bold", @"ArialNarrow-BoldItalic", @"ArialNarrow-Italic", @"ArialUnicodeMS", @"Athelas-Bold", @"Athelas-BoldItalic", @"Athelas-Italic", @"Athelas-Regular", @"Ayuthaya", @"Baghdad", @"BanglaMN", @"BanglaMN-Bold", @"BankGothic-Light", @"BankGothic-Medium", @"Basra", @"Basra-Bold", @"Beirut", @"BigCaslon-Medium", @"BlackmoorLetPlain", @"BlairMdITCTT-Medium", @"BookAntiqua", @"BookAntiqua-Bold", @"BookAntiqua-BoldItalic", @"BookAntiqua-Italic", @"BookmanOldStyle", @"BookmanOldStyle-Bold", @"BookmanOldStyle-BoldItalic", @"BookmanOldStyle-Italic", @"BordeauxRomanBoldLetPlain", @"BradleyHandITCTT-Bold", @"BraganzaITCTT", @"BrushScriptMT", @"CapitalsRegular", @"CenturyGothic", @"CenturyGothic-Bold", @"CenturyGothic-BoldItalic", @"CenturyGothic-Italic", @"CenturySchoolbook", @"CenturySchoolbook-Bold", @"CenturySchoolbook-BoldItalic", @"CenturySchoolbook-Italic", @"Chalkboard", @"Chalkboard-Bold", @"CharcoalCY", @"Charter-Black", @"Charter-BlackItalic", @"Charter-Bold", @"Charter-BoldItalic", @"Charter-Italic", @"Charter-Roman", @"ComicSansMS", @"ComicSansMS-Bold", @"CorsivaHebrew", @"CorsivaHebrew-Bold", @"DFWaWaSC-W5", @"DFWaWaTC-W5", @"Damascus", @"DamascusBold", @"DamascusLight", @"DamascusMedium", @"DamascusSemiBold", @"DearJoeFour-Regular", @"DearJoeFour-Small", @"DecoTypeNaskh", @"DevanagariMT", @"DevanagariMT-Bold", @"Dijla", @"DiwanKufi", @"DiwanThuluth", @"FZLTTHB--B51-0", @"FZLTTHK--GBK1-0", @"FZLTXHB--B51-0", @"FZLTXHK--GBK1-0", @"FZLTZHB--B51-0", @"FZLTZHK--GBK1-0", @"Farah", @"Farisi", @"ForgottenFuturist-Bold", @"ForgottenFuturist-BoldItalic", @"ForgottenFuturist-Italic", @"ForgottenFuturist-Regular", @"ForgottenFuturist-Shadow", @"Garamond", @"Garamond-Bold", @"Garamond-BoldItalic", @"Garamond-Italic", @"GenevaCyr", @"GujaratiMT", @"GujaratiMT-Bold", @"GurmukhiSangamMN", @"GurmukhiSangamMN-Bold", @"HannotateSC-W5", @"HannotateSC-W7", @"HannotateTC-W5", @"HannotateTC-W7", @"HanziPenSC-W3", @"HanziPenSC-W5", @"HanziPenTC-W3", @"HanziPenTC-W5", @"HelveticaCY-Bold", @"HelveticaCY-BoldOblique", @"HelveticaCY-Oblique", @"HelveticaCY-Plain", @"Herculanum", @"HiraKakuPro-W3", @"HiraKakuPro-W6", @"HiraKakuStd-W8", @"HiraKakuStdN-W8", @"HiraMaruPro-W4", @"HiraMaruProN-W4", @"HiraMinPro-W3", @"HiraMinPro-W6", @"HiraginoSansGB-W3", @"HiraginoSansGB-W6", @"HoeflerText-Ornaments", @"HopperScript-Regular", @"ITFDevanagari-Bold", @"ITFDevanagari-Book", @"ITFDevanagari-Demi", @"ITFDevanagari-Light", @"ITFDevanagari-Medium", @"Impact", @"InaiMathi", @"JCHEadA", @"JCfg", @"JCkg", @"JCsmPC", @"JazzLetPlain", @"KannadaMN", @"KannadaMN-Bold", @"Kefa-Bold", @"Kefa-Regular", @"KhmerMN", @"KhmerMN-Bold", @"Kokonor", @"KoufiAbjadi", @"Krungthep", @"KufiStandardGK", @"Laimoon", @"LaoMN", @"LaoMN-Bold", @"LiHeiPro", @"LiSongPro", @"LucidaGrande", @"LucidaGrande-Bold", @"Luminari-Regular", @"MalayalamMN", @"MalayalamMN-Bold", @"MicrosoftSansSerif", @"MonaLisaSolidITCTT", @"MonotypeGurmukhi", @"Mshtakan", @"MshtakanBold", @"MshtakanBoldOblique", @"MshtakanOblique", @"Muna", @"MunaBlack", @"MunaBold", @"MyanmarMN", @"MyanmarMN-Bold", @"MyanmarSangamMN", @"Nadeem", @"NanumBrush", @"NanumGothic", @"NanumGothicBold", @"NanumGothicExtraBold", @"NanumMyeongjo", @"NanumMyeongjoBold", @"NanumMyeongjoExtraBold", @"NanumPen", @"NewPeninimMT", @"NewPeninimMT-Bold", @"NewPeninimMT-BoldInclined", @"NewPeninimMT-Inclined", @"Nisan", @"OriyaMN", @"OriyaMN-Bold", @"Osaka", @"Osaka-Mono", @"PTMono-Bold", @"PTMono-Regular", @"PTSans-Bold", @"PTSans-BoldItalic", @"PTSans-Caption", @"PTSans-CaptionBold", @"PTSans-Italic", @"PTSans-Narrow", @"PTSans-NarrowBold", @"PTSans-Regular", @"PTSerif-Bold", @"PTSerif-BoldItalic", @"PTSerif-Caption", @"PTSerif-CaptionItalic", @"PTSerif-Italic", @"PTSerif-Regular", @"Phosphate-Inline", @"Phosphate-Solid", @"PlantagenetCherokee", @"PortagoITCTT", @"PrincetownLET", @"Raanana", @"RaananaBold", @"Raya", @"STBaoli-SC-Regular", @"STFangsong", @"STHeiti", @"STIXGeneral-Bold", @"STIXGeneral-BoldItalic", @"STIXGeneral-Italic", @"STIXGeneral-Regular", @"STIXIntegralsD-Bold", @"STIXIntegralsD-Regular", @"STIXIntegralsSm-Bold", @"STIXIntegralsSm-Regular", @"STIXIntegralsUp-Bold", @"STIXIntegralsUp-Regular", @"STIXIntegralsUpD-Bold", @"STIXIntegralsUpD-Regular", @"STIXIntegralsUpSm-Bold", @"STIXIntegralsUpSm-Regular", @"STIXNonUnicode-Bold", @"STIXNonUnicode-BoldItalic", @"STIXNonUnicode-Italic", @"STIXNonUnicode-Regular", @"STIXSizeFiveSym-Regular", @"STIXSizeFourSym-Bold", @"STIXSizeFourSym-Regular", @"STIXSizeOneSym-Bold", @"STIXSizeOneSym-Regular", @"STIXSizeThreeSym-Bold", @"STIXSizeThreeSym-Regular", @"STIXSizeTwoSym-Bold", @"STIXSizeTwoSym-Regular", @"STIXVariants-Bold", @"STIXVariants-Regular", @"STKaiTi-TC-Bold", @"STKaiTi-TC-Regular", @"STKaiti", @"STKaiti-SC-Black", @"STKaiti-SC-Bold", @"STKaiti-SC-Regular", @"STLibian-SC-Regular", @"STSong", @"STSongti-SC-Black", @"STSongti-SC-Bold", @"STSongti-SC-Light", @"STSongti-SC-Regular", @"STSongti-TC-Bold", @"STSongti-TC-Light", @"STSongti-TC-Regular", @"STXihei", @"STXingkai-SC-Bold", @"STXingkai-SC-Light", @"STYuanti-SC-Bold", @"STYuanti-SC-Light", @"STYuanti-SC-Regular", @"Sana", @"SantaFeLetPlain", @"Sathu", @"SchoolHouseCursiveB", @"SchoolHousePrintedA", @"Seravek", @"Seravek-Bold", @"Seravek-BoldItalic", @"Seravek-ExtraLight", @"Seravek-ExtraLightItalic", @"Seravek-Italic", @"Seravek-Light", @"Seravek-LightItalic", @"Seravek-Medium", @"Seravek-MediumItalic", @"ShreeDev0714", @"ShreeDev0714-Bold", @"ShreeDev0714-Bold-Italic", @"ShreeDev0714-Italic", @"SignPainter-HouseScript", @"Silom", @"SinhalaMN", @"SinhalaMN-Bold", @"Skia-Regular", @"Skia-Regular_Black", @"Skia-Regular_Black-Condensed", @"Skia-Regular_Black-Extended", @"Skia-Regular_Bold", @"Skia-Regular_Condensed", @"Skia-Regular_Extended", @"Skia-Regular_Light", @"Skia-Regular_Light-Condensed", @"Skia-Regular_Light-Extended", @"Somer", @"StoneSansITCTT-Bold", @"StoneSansITCTT-Semi", @"StoneSansITCTT-SemiIta", @"SukhumvitSet-Bold", @"SukhumvitSet-Light", @"SukhumvitSet-Medium", @"SukhumvitSet-SemiBold", @"SukhumvitSet-Text", @"SukhumvitSet-Thin", @"SynchroLET", @"Tahoma", @"Tahoma-Bold", @"TamilMN", @"TamilMN-Bold", @"TeluguMN", @"TeluguMN-Bold", @"Trattatello", @"TwCenMT-Bold", @"TwCenMT-BoldItalic", @"TwCenMT-Italic", @"TwCenMT-Regular", @"TypeEmbellishmentsOneLetPlain", @"Waseem", @"WaseemLight", @"Webdings", @"Weibei-SC-Bold", @"Weibei-TC-Bold", @"Wingdings-Regular", @"Wingdings2", @"Wingdings3", @"Yaziji", @"YuGo-Bold", @"YuGo-Medium", @"YuMin-Demibold", @"YuMin-Medium", @"YuppySC-Regular", @"YuppyTC-Regular", @"Zawra-Bold", @"Zawra-Heavy" ];
		}
	});

	if (loadedRemoteFontList && completion) {
		completion(availableRemoteFontNames);

		return;
	}

	static dispatch_once_t loadedFreshRemoteFontNamesList;
	dispatch_once(&loadedFreshRemoteFontNamesList, ^{
		NSURL *URL = [NSURL URLWithString:@"http://mesu.apple.com/assets/com_apple_MobileAsset_Font/com_apple_MobileAsset_Font.xml"];

		__block CQRemoteFontSessionDelegate *delegate = [[CQRemoteFontSessionDelegate alloc] init];
		delegate.completionBlock = ^(NSData *requestData, NSError *requestError) {
			NSData *data = [requestData copy];
			NSError *error = [requestError copy];

			delegate = nil;

			if (!data.length || error) {
				if (completion) {
					dispatch_async(dispatch_get_main_queue(), ^{
						completion(availableRemoteFontNames);
					});
				}

				if (error.code != NSURLErrorCancelled) {
					NSLog(@"Error fetching font list %@", error);
				}

				return;
			}

			NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
			NSError *plistParseError = nil;
			NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:&format error:&plistParseError];
			if (!plist || plistParseError) {
				if (completion) {
					dispatch_async(dispatch_get_main_queue(), ^{
						completion(availableRemoteFontNames);
					});
				}

				NSLog(@"Error parsing font list %@", plistParseError);

				return;
			}

			NSMutableSet *postscriptNames = [NSMutableSet set];
			for (NSDictionary *fontAssets in plist[@"Assets"]) {
				for (NSDictionary *fontAsset in fontAssets[@"FontInfo3"]) {
					NSString *postscriptName = fontAsset[@"PostScriptFontName"];

					if (postscriptName.length) {
						[postscriptNames addObject:postscriptName];
					}
				}
			}

			NSArray *sortedPostScriptNames = [postscriptNames sortedArrayUsingDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES] ]];
			if (!sortedPostScriptNames.count) {
				if (completion) {
					completion(availableRemoteFontNames);
				}

				NSLog(@"Refusing to use new list of fonts that contains 0 elements");

				return;
			}

			availableRemoteFontNames = [sortedPostScriptNames copy];
			loadedRemoteFontList = YES;

			[[NSUserDefaults standardUserDefaults] setObject:availableRemoteFontNames forKey:@"CQAvailableRemoteFontNames"];

			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:CQRemoteFontCourierDidLoadFontListNotification object:nil userInfo:@{ CQRemoteFontCourierFontListKey: [availableRemoteFontNames copy] }];

				if (completion) {
					completion(availableRemoteFontNames);
				}
			});
		};

		NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration] delegate:delegate delegateQueue:nil];
		[[session dataTaskWithURL:URL] resume];
	});
}

+ (void) cq_loadRemoteFontWithName:(NSString *) fontName completionHandler:(__nullable CQRemoteFontCompletionHandler) completionHandler {
	void (^postSuccessNotification)(NSString *, UIFont *) = ^(NSString *loadedFontName, UIFont *loadedFont) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSDictionary *userInfo = nil;
			if (loadedFontName && loadedFont) {
				userInfo = @{ CQRemoteFontCourierFontLoadingFontNameKey: loadedFontName, CQRemoteFontCourierFontLoadingFontKey: loadedFont };
			} else if (loadedFontName) {
				userInfo = @{ CQRemoteFontCourierFontLoadingFontNameKey: loadedFontName };
			} else if (loadedFont) {
				userInfo = @{ CQRemoteFontCourierFontLoadingFontKey: loadedFont };
			}

			[[NSNotificationCenter defaultCenter] postNotificationName:CQRemoteFontCourierFontLoadingDidSucceedNotification object:nil userInfo:userInfo];
		});
	};

	void (^postFailureNotification)(NSString *) = ^(NSString *failedFont) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSDictionary *userInfo = failedFont ? userInfo = @{ CQRemoteFontCourierFontLoadingFontNameKey: failedFont } : nil;

			[[NSNotificationCenter defaultCenter] postNotificationName:CQRemoteFontCourierFontLoadingDidFailNotification object:nil userInfo:userInfo];
		});
	};

	UIFont *font = [UIFont fontWithName:fontName size:12.];
	if (font && ([font.fontName caseInsensitiveCompare:fontName] == NSOrderedSame || [font.familyName caseInsensitiveCompare:fontName] == NSOrderedSame)) {
		if (completionHandler) {
			completionHandler(fontName, font);
		}

		postSuccessNotification(fontName, font);

		return;
	}

	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:fontName, kCTFontNameAttribute, nil];
//	NSMutableDictionary *attributes = [@{ (__bridge id)kCTFontAttributeName: fontName } mutableCopy]; // this will cause downloads to fail and only return the system font (Helvetica Neue or San Francisco on iOS)

	CTFontDescriptorRef fontDescriptorRef = CFAutorelease(CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attributes));
	NSArray *descriptors = @[ (__bridge id)fontDescriptorRef ];

	__block BOOL errorEncountered = NO;
	bool didStartDownload = CTFontDescriptorMatchFontDescriptorsWithProgressHandler((__bridge CFArrayRef)descriptors, NULL, ^bool(CTFontDescriptorMatchingState state, CFDictionaryRef progressParameter) {
		NSLog(@"%@: { %@: { %@ } }", fontName,
			CFAutorelease(CTFontDescriptorCopyAttribute(CFArrayGetValueAtIndex((__bridge CFArrayRef)descriptors, 0), kCTFontNameAttribute)),
				NSStringFromCTFontDescriptorMatchingState(state)
		);

		if (state == kCTFontDescriptorMatchingDidFinish) {
			if (errorEncountered) {
				return false;
			}

			dispatch_async(dispatch_get_main_queue(), ^{
				CTFontRef fontRef = CFAutorelease(CTFontCreateWithName((__bridge CFStringRef)fontName, 0., NULL));
				if (fontRef) {
					CFURLRef fontURL = CFAutorelease(CTFontCopyAttribute(fontRef, kCTFontURLAttribute));

					if (fontURL) {
						bool registeredForUserScope = CTFontManagerRegisterFontsForURL(fontURL, kCTFontManagerScopeUser, NULL); // This scope is documented as unavailable on iOS. But, it's still defined, so, lets give it a try
						if (!registeredForUserScope) {
							bool registeredForCurrentProcess = CTFontManagerRegisterFontsForURL(fontURL, kCTFontManagerScopeProcess, NULL); // This scope is documented as available on iOS. But, it doesn't usually work, either
							if (!registeredForCurrentProcess) {
								NSLog(@"%@ = %@: Unable to register scope for user or process", fontName, fontURL);
							} else {
								NSLog(@"%@ = %@: Unable to register scope for user", fontURL, fontURL);
							}
						}
					}

					if (!errorEncountered && completionHandler) {
						UIFont *loadedFont = [UIFont fontWithName:fontName size:12.];
						completionHandler(fontName, loadedFont);

						postSuccessNotification(fontName, font);
					}
				}
			});
		} else if (state == kCTFontDescriptorMatchingDidFailWithError) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSLog(@"%@: { %@: { %@ }", fontName,
					CFAutorelease(CTFontDescriptorCopyAttribute(CFArrayGetValueAtIndex((__bridge CFArrayRef)descriptors, 0), kCTFontNameAttribute)),
						CFDictionaryGetValue(progressParameter, kCTFontDescriptorMatchingError)
				);
			});

			errorEncountered = YES;

			if (completionHandler) {
				completionHandler(fontName, NULL);
			}

			postFailureNotification(fontName);

			return false;
		}

		return true;
	});

	if (!didStartDownload) {
		if (completionHandler) {
			completionHandler(fontName, NULL);
		}

		postFailureNotification(fontName);
	}
}
@end

NS_ASSUME_NONNULL_END
