#import "UIFontAdditions.h"

#import <CoreText/CoreText.h>

#import "NSNotificationAdditions.h"

NSString *CQRemoteFontCourierFontLoadingDidSucceedNotification = @"CQRemoteFontCourierFontLoadingDidSucceedNotification";
NSString *CQRemoteFontCourierFontLoadingDidFailNotification = @"CQRemoteFontCourierFontLoadingDidFailNotification";

NSString *CQRemoteFontCourierFontLoadingFontNameKey = @"CQRemoteFontCourierFontLoadingFontNameKey";
NSString *CQRemoteFontCourierFontLoadingFontKey = @"CQRemoteFontCourierFontLoadingFontKey";

NSString *NSStringFromCTFontDescriptorMatchingState(CTFontDescriptorMatchingState state);
NSString *NSStringFromCTFontDescriptorMatchingState(CTFontDescriptorMatchingState state) {
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


@implementation UIFont (Additions)
+ (NSArray *) cq_availableRemoteFontNames {
	static NSArray *availableRemoteFontNames = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		// postscript names
		availableRemoteFontNames = @[ @"HannotateSC-W5", @"HannotateTC-W5", @"HannotateSC-W7", @"HannotateTC-W7", @"KannadaMN", @"KannadaMN-Bold", @"STIXSizeTwoSym-Bold", @"Arial-ItalicMT", @"YuppySC-Regular", @"STIXSizeFiveSym-Regular", @"STIXIntegralsUp-Regular", @"BookAntiqua", @"BookAntiqua-Bold", @"BookAntiqua-Italic", @"BookAntiqua-BoldItalic", @"STIXNonUnicode-BoldItalic", @"ArialNarrow-BoldItalic", @"JazzLetPlain", @"MshtakanBoldOblique", @"NewPeninimMT", @"NewPeninimMT-Inclined", @"NewPeninimMT-BoldInclined", @"NewPeninimMT-Bold", @"NanumBrush", @"NanumPen", @"STHeiti", @"InaiMathi", @"MalayalamMN", @"MalayalamMN-Bold", @"STIXIntegralsUpD-Regular", @"Zawra-Bold", @"Zawra-Heavy", @"STYuanti-SC-Bold", @"STYuanti-SC-Light", @"STYuanti-SC-Regular", @"Garamond", @"Garamond-Bold", @"Garamond-Italic", @"Garamond-BoldItalic", @"HiraginoSansGB-W3", @"Kokonor", @"YuGo-Bold", @"HanziPenSC-W3", @"HanziPenTC-W3", @"HanziPenSC-W5", @"HanziPenTC-W5", @"STIXGeneral-BoldItalic", @"Sana", @"DiwanThuluth", @"STBaoli-SC-Regular", @"HiraMaruProN-W4", @"Waseem", @"WaseemLight", @"AppleSDGothicNeo-Bold", @"Laimoon", @"PlantagenetCherokee", @"AlTarikh", @"STLibian-SC-Regular", @"DearJoeFour-Regular", @"IowanOldStyle-Black", @"IowanOldStyle-BlackItalic", @"IowanOldStyle-Bold", @"IowanOldStyle-BoldItalic", @"IowanOldStyle-Italic", @"IowanOldStyle-Roman", @"IowanOldStyle-Titling", @"FZLTZHK--GBK1-0", @"FZLTXHK--GBK1-0", @"FZLTTHK--GBK1-0", @"FZLTZHB--B51-0", @"FZLTXHB--B51-0", @"FZLTTHB--B51-0", @"AppleMyungjo", @"CapitalsRegular", @"HiraginoSansGB-W6", @"DecoTypeNaskh", @".DecoTypeNaskhPUA", @"GujaratiMT-Bold", @"Impact", @"Luminari-Regular", @"STIXSizeOneSym-Regular", @"STIXIntegralsSm-Bold", @"YuGo-Medium", @"Basra-Bold", @"Basra", @"TamilMN", @"TamilMN-Bold", @"STKaiti-SC-Bold", @"STKaiti-SC-Regular", @"DFWaWaSC-W5", @"STIXIntegralsUpSm-Bold", @"Impact", @"MonotypeGurmukhi", @"Raanana", @"TwCenMT-Regular", @"TwCenMT-Bold", @"TwCenMT-Italic", @"TwCenMT-BoldItalic", @"MyanmarMN", @"MyanmarMN-Bold", @"StoneSansITCTT-Semi", @"StoneSansITCTT-SemiIta", @"StoneSansITCTT-Bold", @"YuGo-Medium", @"STIXIntegralsUp-Bold", @"BigCaslon-Medium", @"STIXIntegralsD-Regular", @"Farisi", @"AppleBraille-Outline8Dot", @"Kefa-Regular", @"Kefa-Bold", @"YuppySC-Regular", @"STKaiti-SC-Black", @"STKaiti-SC-Bold", @"STKaiTi-TC-Bold", @"STKaiti-SC-Regular", @"STKaiti", @"STKaiTi-TC-Regular", @"BraganzaITCTT", @"GujaratiMT-Bold", @"STFangsong", @"PTSerif-Regular", @"PTSerif-Italic", @"PTSerif-BoldItalic", @"PTSerif-Bold", @"Beirut", @"AppleSDGothicNeo-Heavy", @"Trattatello", @"SinhalaMN", @"SinhalaMN-Bold", @"ShreeDev0714", @"ShreeDev0714-Bold", @"ShreeDev0714-Italic", @"ShreeDev0714-Bold-Italic", @"Tahoma-Bold", @"FZLTZHK--GBK1-0", @"FZLTXHK--GBK1-0", @"FZLTTHK--GBK1-0", @"FZLTZHB--B51-0", @"FZLTXHB--B51-0", @"FZLTTHB--B51-0", @"KoufiAbjadi", @"KhmerSangamMN", @"NanumBrush", @"NanumPen", @"Osaka", @"YuGo-Bold", @"AppleSDGothicNeo-Regular", @"Kefa-Regular", @"Kefa-Bold", @"Raya", @"STIXSizeFourSym-Bold", @"HiraMaruProN-W4", @"BradleyHandITCTT-Bold", @"Damascus", @".DamascusPUA", @"DamascusLight", @".DamascusPUALight", @"DamascusMedium", @".DamascusPUAMedium", @"DamascusBold", @".DamascusPUABold", @"DamascusSemiBold", @".DamascusPUASemiBold", @"HiraginoSansGB-W3", @"HiraMinPro-W6", @"LiSongPro", @"ComicSansMS", @"ITFDevanagari-Book", @"ITFDevanagari-Bold", @"ITFDevanagari-Demi", @"ITFDevanagari-Light", @"ITFDevanagari-Medium", @"Raanana", @"RaananaBold", @"STIXVariants-Regular", @"MshtakanBold", @"Skia-Regular", @"Skia-Regular_Black", @"Skia-Regular_Extended", @"Skia-Regular_Condensed", @"Skia-Regular_Light", @"Skia-Regular_Black-Extended", @"Skia-Regular_Light-Extended", @"Skia-Regular_Black-Condensed", @"Skia-Regular_Light-Condensed", @"Skia-Regular_Bold", @"TwCenMT-Regular", @"TwCenMT-Bold", @"TwCenMT-Italic", @"TwCenMT-BoldItalic", @"STSongti-SC-Bold", @"STSongti-SC-Regular", @"STXihei", @"BrushScriptMT", @"JCsmPC", @"ArialMT", @"Farisi", @"GurmukhiSangamMN", @"GurmukhiSangamMN-Bold", @"JCsmPC", @"AppleSDGothicNeo-Heavy", @"ComicSansMS", @"STIXSizeTwoSym-Regular", @"AppleSDGothicNeo-UltraLight", @"Nisan", @"BlackmoorLetPlain", @"AppleSDGothicNeo-SemiBold", @"SchoolHouseCursiveB", @"SukhumvitSet-Thin", @"SukhumvitSet-Light", @"SukhumvitSet-Text", @"SukhumvitSet-Medium", @"SukhumvitSet-SemiBold", @"SukhumvitSet-Bold", @"CharcoalCY", @"MicrosoftSansSerif", @"MyanmarMN", @"MyanmarMN-Bold", @"STSongti-SC-Black", @"STSongti-SC-Light", @"STSongti-TC-Light", @"Wingdings2", @"JCkg", @"YuppyTC-Regular", @"STIXIntegralsSm-Regular", @"HiraKakuStd-W8", @"Yaziji", @"ComicSansMS-Bold", @"AlBayan-Bold", @"DiwanKufi", @"ArialNarrow-Italic", @"HannotateSC-W5", @"HannotateTC-W5", @"HannotateSC-W7", @"HannotateTC-W7", @"SavoyeLetPlain", @".SavoyeLetPlainCC", @"Chalkboard", @"Chalkboard-Bold", @"STIXIntegralsUpSm-Regular", @"AppleSDGothicNeo-ExtraBold", @"ArialNarrow-Bold", @"AlRafidainAlFanni", @"Herculanum", @"DFWaWaTC-W5", @"GenevaCyr", @"JCfg", @"STIXIntegralsD-Regular", @"BankGothic-Light", @"BankGothic-Medium", @"Waseem", @"WaseemLight", @"STXingkai-SC-Bold", @"STXingkai-SC-Light", @"YuMin-Demibold", @"STIXIntegralsUpD-Regular", @"Mshtakan", @"Basra", @"Basra-Bold", @"Nadeem", @"AppleSDGothicNeo-Heavy", @"CenturyGothic", @"CenturyGothic-Bold", @"CenturyGothic-Italic", @"CenturyGothic-BoldItalic", @"STIXGeneral-Regular", @"JCHEadA", @"AppleMyungjo", @"STIXSizeFourSym-Regular", @"YuMin-Demibold", @"Farah", @".FarahPUA", @"KannadaMN", @"KannadaMN-Bold", @"SignPainter-HouseScript", @"BigCaslon-Medium", @"GujaratiMT", @"Wingdings-Regular", @"AppleGothic", @"PTSerif-Caption", @"PTSerif-CaptionItalic", @"Webdings", @"Arial-Black", @"DevanagariMT", @"Sana", @"STIXIntegralsUpD-Bold", @"AppleBraille", @"AppleSDGothicNeo-Light", @"Arial-Black", @"AlBayan", @"STXingkai-SC-Bold", @"STXingkai-SC-Light", @"HopperScript-Regular", @"MonaLisaSolidITCTT", @"Somer", @"STLibian-SC-Regular", @"STIXIntegralsUp-Bold", @"Muna", @"MunaBold", @"MunaBlack", @"BordeauxRomanBoldLetPlain", @"Somer", @"DevanagariMT", @"NanumGothic", @"NanumGothicBold", @"NanumGothicExtraBold", @"STIXVariants-Bold", @"BookmanOldStyle", @"BookmanOldStyle-Bold", @"BookmanOldStyle-Italic", @"BookmanOldStyle-BoldItalic", @"Arial-BoldItalicMT", @"AcademyEngravedLetPlain", @"STSongti-SC-Black", @"STSongti-SC-Light", @"STSongti-SC-Bold", @"STSongti-TC-Bold", @"STSongti-SC-Regular", @"STSongti-TC-Regular", @"ArialNarrow-BoldItalic", @"STIXNonUnicode-Regular", @"STHeiti", @"AppleBraille-Pinpoint8Dot", @"CenturyGothic", @"CenturyGothic-Bold", @"CenturyGothic-Italic", @"CenturyGothic-BoldItalic", @"ArialHebrewScholar", @"ArialHebrewScholar-Bold", @"ArialHebrewScholar-Light", @"HiraKakuStdN-W8", @"STIXGeneral-Bold", @"NanumBrush", @"NanumPen", @"DearJoeFour-Small", @"STBaoli-SC-Regular", @"HopperScript-Regular", @"STIXIntegralsUp-Regular", @"AppleBraille", @"TeluguMN", @"TeluguMN-Bold", @"OriyaMN", @"OriyaMN-Bold", @"DevanagariMT-Bold", @"AppleSDGothicNeo-Thin", @"SantaFeLetPlain", @"Trattatello", @"Phosphate-Inline", @"Phosphate-Solid", @"LaoMN", @"LaoMN-Bold", @"Sathu", @"NewPeninimMT-BoldInclined", @"HiraKakuPro-W3", @"KufiStandardGK", @"Phosphate-Inline", @"Phosphate-Solid", @"AlTarikh", @"Apple-Chancery", @"DecoTypeNaskh", @"GujaratiMT", @"BanglaMN", @"BanglaMN-Bold", @"STIXVariants-Regular", @"HiraKakuStdN-W8", @"LiHeiPro", @"STBaoli-SC-Regular", @"GurmukhiSangamMN", @"GurmukhiSangamMN-Bold", @"Beirut", @"Apple-Chancery", @"STIXSizeThreeSym-Regular", @"CenturySchoolbook", @"CenturySchoolbook-Bold", @"CenturySchoolbook-Italic", @"CenturySchoolbook-BoldItalic", @"ArialNarrow-Bold", @"Algiers", @"STIXSizeOneSym-Bold", @"STKaiti-SC-Bold", @"STKaiTi-TC-Bold", @"STKaiti-SC-Regular", @"STKaiTi-TC-Regular", @"BanglaMN", @"BanglaMN-Bold", @"STIXNonUnicode-Bold", @"LaoSangamMN", @"Raya", @"MshtakanBold", @"AndaleMono", @"LiSongPro", @"STIXIntegralsUpD-Bold", @"Silom", @"Muna", @"MunaBold", @"MunaBlack", @"STIXIntegralsSm-Bold", @"STIXNonUnicode-Italic", @"Tahoma", @"JCHEadA", @"Sathu", @"Ayuthaya", @"Tahoma-Bold", @"AppleSDGothicNeo-Medium", @"PTSans-Regular", @"PTSans-Italic", @"PTSans-NarrowBold", @"PTSans-Narrow", @"PTSans-CaptionBold", @"PTSans-Caption", @"PTSans-BoldItalic", @"PTSans-Bold", @"BankGothic-Light", @"BankGothic-Medium", @"SignPainter-HouseScript", @"TamilMN", @"TamilMN-Bold", @"JCkg", @"MshtakanBoldOblique", @"STIXSizeFourSym-Bold", @"AppleSDGothicNeo-Thin", @"YuMin-Medium", @"YuGo-Bold", @"Dijla", @"Wingdings2", @"YuppyTC-Regular", @"MshtakanOblique", @"Silom", @"STIXSizeFiveSym-Regular", @"NanumGothic", @"NanumGothicBold", @"NanumGothicExtraBold", @"KufiStandardGK", @"STYuanti-SC-Bold", @"STYuanti-SC-Light", @"STYuanti-SC-Regular", @"SinhalaMN", @"SinhalaMN-Bold", @"LucidaGrande", @"LucidaGrande-Bold", @".LucidaGrandeUI", @".LucidaGrandeUI-Bold", @"STIXIntegralsD-Bold", @"NewPeninimMT-Inclined", @"AppleMyungjo", @"RaananaBold", @"Al-KhalilBold", @"Al-Khalil", @"CorsivaHebrew", @"CorsivaHebrew-Bold", @"CenturySchoolbook", @"CenturySchoolbook-Bold", @"CenturySchoolbook-Italic", @"CenturySchoolbook-BoldItalic", @"Zawra-Bold", @"Zawra-Heavy", @"HiraMinPro-W3", @"DFWaWaSC-W5", @"ArialNarrow", @"InaiMathi", @"STYuanti-SC-Bold", @"STYuanti-SC-Light", @"STYuanti-SC-Regular", @"NanumMyeongjo", @"NanumMyeongjoBold", @"NanumMyeongjoExtraBold", @"AppleGothic", @"HiraMaruPro-W4", @"ITFDevanagari-Book", @"ITFDevanagari-Bold", @"ITFDevanagari-Demi", @"ITFDevanagari-Light", @"ITFDevanagari-Medium", @"MonotypeGurmukhi", @"STIXNonUnicode-Italic", @"Weibei-TC-Bold", @"STIXSizeOneSym-Regular", @"Herculanum", @"Kokonor", @"OriyaMN", @"OriyaMN-Bold", @"Athelas-Regular", @"Athelas-Italic", @"Athelas-BoldItalic", @"Athelas-Bold", @"Al-Rafidain", @"STIXSizeTwoSym-Bold", @"DFWaWaTC-W5", @"Ayuthaya", @"Yaziji", @"STIXGeneral-Italic", @"Laimoon", @"NewPeninimMT-Bold", @"STIXNonUnicode-BoldItalic", @"HiraginoSansGB-W6", @"Krungthep", @"MicrosoftSansSerif", @"Osaka-Mono", @"AlRafidainAlFanni", @"AndaleMono", @"STSongti-SC-Black", @"STSongti-SC-Bold", @"STSongti-TC-Bold", @"STSongti-SC-Light", @"STSong", @"STSongti-TC-Light", @"STSongti-SC-Regular", @"STSongti-TC-Regular", @"ShreeDev0714", @"ShreeDev0714-Bold", @"ShreeDev0714-Italic", @"ShreeDev0714-Bold-Italic", @"Al-KhalilBold", @"Al-Khalil", @"ArialUnicodeMS", @"AppleBraille-Pinpoint6Dot", @"HiraKakuStd-W8", @"BraganzaITCTT", @"HiraginoSansGB-W3", @"DearJoeFour-Regular", @"Dijla", @"HoeflerText-Ornaments", @"NewPeninimMT", @"Tahoma", @"ArialNarrow", @"YuMin-Medium", @"JCfg", @"AlBayan", @"AlBayan-Bold", @"PrincetownLET", @"Weibei-SC-Bold", @"STIXIntegralsUpSm-Regular", @"Baghdad", @"HoeflerText-Ornaments", @"Osaka-Mono", @"TeluguMN", @"TeluguMN-Bold", @"HiraKakuPro-W6", @"SIL-Kai-Reg-Jian", @"PortagoITCTT", @"HiraMinPro-W3", @"Luminari-Regular", @"SchoolHousePrintedA", @"DearJoeFour-Small", @"SynchroLET", @"Baghdad", @"STIXVariants-Bold", @"BlairMdITCTT-Medium", @"AppleSDGothicNeo-ExtraBold", @"STLibian-SC-Regular", @"AppleSDGothicNeo-UltraLight", @"PTMono-Bold", @"PTMono-Regular", @"DFKaiShu-SB-Estd-BF", @"KoufiAbjadi", @"YuppySC-Regular", @"NanumGothic", @"NanumGothicBold", @"NanumGothicExtraBold", @"ForgottenFuturist-Regular", @"ForgottenFuturist-Italic", @"ForgottenFuturist-Bold", @"ForgottenFuturist-BoldItalic", @"ForgottenFuturist-Shadow", @"HelveticaCY-Bold", @"HelveticaCY-BoldOblique", @"HelveticaCY-Oblique", @"HelveticaCY-Plain", @"STIXIntegralsUpSm-Bold", @"KhmerMN", @"KhmerMN-Bold", @"KhmerMN", @"KhmerMN-Bold", @"MyanmarSangamMN", @"Nisan", @"AppleBraille-Outline6Dot", @"Algiers", @"Wingdings3", @"Al-Rafidain", @"HiraMinPro-W6", @"MyanmarSangamMN", @"HiraginoSansGB-W6", @"BookmanOldStyle", @"BookmanOldStyle-Bold", @"BookmanOldStyle-Italic", @"BookmanOldStyle-BoldItalic", @"STFangsong", @"ComicSansMS-Bold", @"HanziPenSC-W3", @"HanziPenTC-W3", @"HanziPenSC-W5", @"HanziPenTC-W5", @"HiraMaruProN-W4", @"LiHeiPro", @"STIXSizeTwoSym-Regular", @"Arial-BoldMT", @"NanumMyeongjo", @"NanumMyeongjoBold", @"NanumMyeongjoExtraBold", @"Al-Firat", @"LiHeiPro", @"AppleSymbols", @"ArialNarrow-Italic", @"STFangsong", @"STIXGeneral-BoldItalic", @"Krungthep", @"AppleSymbols", @"LiSungLight", @"STIXIntegralsSm-Regular", @"AppleBraille-Outline8Dot", @"CorsivaHebrew", @"AppleSDGothicNeo-ExtraBold", @"ArialUnicodeMS", @"Al-Firat", @"Chalkboard", @"Chalkboard-Bold", @"STIXSizeThreeSym-Regular", @"DFWaWaTC-W5", @"STIXGeneral-Italic", @"SukhumvitSet-Thin", @"SukhumvitSet-Light", @"SukhumvitSet-Text", @"SukhumvitSet-Medium", @"SukhumvitSet-SemiBold", @"SukhumvitSet-Bold", @"STIXNonUnicode-Bold", @"Webdings", @"PlantagenetCherokee", @"AppleBraille-Pinpoint8Dot", @"DiwanThuluth", @"LaoMN", @"LaoMN-Bold", @"JCsmPC", @"MshtakanOblique", @"PTSans-Regular", @"PTSans-Italic", @"PTSans-Bold", @"PTSans-BoldItalic", @"PTSans-Caption", @"PTSans-CaptionBold", @"PTSans-Narrow", @"PTSans-NarrowBold", @"SIL-Hei-Med-Jian", @"Wingdings-Regular", @"STIXNonUnicode-Regular", @"STIXSizeThreeSym-Bold", @"YuppyTC-Regular", @"HiraMaruPro-W4", @"LucidaGrande", @"LucidaGrande-Bold", @".LucidaGrandeUI", @".LucidaGrandeUI-Bold", @"CorsivaHebrew-Bold", @"JCHEadA", @"GurmukhiMN", @"GurmukhiMN-Bold", @"STIXGeneral-Regular", @"Wingdings3", @"STKaiti-SC-Black", @"AppleSDGothicNeo-SemiBold", @"Weibei-SC-Bold", @"MalayalamMN", @"MalayalamMN-Bold", @"STXingkai-SC-Bold", @"STXingkai-SC-Light", @"LiGothicMed", @"DiwanKufi", @"STIXIntegralsD-Bold", @"AppleBraille-Pinpoint6Dot", @"STIXSizeOneSym-Bold", @"YuMin-Medium", @"BrushScriptMT", @"Weibei-SC-Bold", @"DevanagariMT-Bold", @"Osaka", @"AppleSDGothicNeo-Regular", @"AppleBraille-Outline6Dot", @"Seravek", @"Seravek-Italic", @"Seravek-MediumItalic", @"Seravek-Medium", @"Seravek-LightItalic", @"Seravek-Light", @"Seravek-ExtraLightItalic", @"Seravek-ExtraLight", @"Seravek-BoldItalic", @"Seravek-Bold", @"HiraKakuPro-W3", @"JCfg", @"Mshtakan", @"YuGo-Medium", @"YuMin-Demibold", @"STIXSizeFourSym-Regular", @"HiraKakuPro-W6", @"Weibei-TC-Bold", @"Garamond", @"Garamond-Bold", @"Garamond-Italic", @"Garamond-BoldItalic", @"FZLTZHK--GBK1-0", @"FZLTXHK--GBK1-0", @"FZLTTHK--GBK1-0", @"FZLTZHB--B51-0", @"FZLTXHB--B51-0", @"FZLTTHB--B51-0", @"STIXGeneral-Bold", @"Weibei-TC-Bold", @"Charter-Roman", @"Charter-Italic", @"Charter-BoldItalic", @"Charter-Bold", @"Charter-BlackItalic", @"Charter-Black", @"NanumMyeongjo", @"NanumMyeongjoBold", @"NanumMyeongjoExtraBold", @"HiraKakuStdN-W8", @"AppleSDGothicNeo-Light", @"TypeEmbellishmentsOneLetPlain", @"LiSongPro", @"Nadeem", @"STIXSizeThreeSym-Bold", @"STXihei", @"DFKaiShu-SB-Estd-BF", @"STKaiti-SC-Black", @"BookAntiqua", @"BookAntiqua-Bold", @"BookAntiqua-Italic", @"BookAntiqua-BoldItalic", @"DFWaWaSC-W5" ];
		availableRemoteFontNames = [[NSSet setWithArray:availableRemoteFontNames].allObjects sortedArrayUsingSelector:@selector(compare:)];
	});

	return availableRemoteFontNames;
}

+ (void) cq_loadAllAvailableFonts {
	[[UIFont cq_availableRemoteFontNames] enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id fontName, NSUInteger index, BOOL *stop) {
		// without the dispatch_after, CoreText will cause the CPU to spin at 100% for awhile
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(index * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[UIFont cq_loadFontWithName:fontName withCompletionHandler:NULL];
		});
	}];
}

+ (void) cq_loadFontWithName:(NSString *) fontName withCompletionHandler:(CQRemoteFontCompletionHandler)completionHandler {
	void (^postSuccessNotification)(NSString *, UIFont *) = ^(NSString *loadedFontName, UIFont *loadedFont) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSDictionary *userInfo = nil;
			if (loadedFontName && loadedFont) userInfo = @{ CQRemoteFontCourierFontLoadingFontNameKey: loadedFontName, CQRemoteFontCourierFontLoadingFontKey: loadedFont };
			else if (loadedFontName) userInfo = @{ CQRemoteFontCourierFontLoadingFontNameKey: loadedFontName };
			else if (loadedFont) userInfo = @{ CQRemoteFontCourierFontLoadingFontKey: loadedFont };
			[[NSNotificationCenter chatCenter] postNotificationName:CQRemoteFontCourierFontLoadingDidSucceedNotification object:nil userInfo:userInfo];
		});
	};

	void (^postFailureNotification)(NSString *) = ^(NSString *failedFont) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSDictionary *userInfo = failedFont ? userInfo = @{ CQRemoteFontCourierFontLoadingFontNameKey: failedFont } : nil;
			[[NSNotificationCenter chatCenter] postNotificationName:CQRemoteFontCourierFontLoadingDidFailNotification object:nil userInfo:userInfo];
		});
	};

	UIFont *font = [UIFont fontWithName:fontName size:12.];
	if (font && ([font.fontName compare:fontName] == NSOrderedSame || [font.familyName compare:fontName] == NSOrderedSame)) {
		if (completionHandler)
			completionHandler(fontName, font);
		postSuccessNotification(fontName, font);
		return;
	}

	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:fontName, kCTFontNameAttribute, nil];
//	NSMutableDictionary *attributes = [@{ (__bridge id)kCTFontAttributeName: fontName } mutableCopy]; // this will cause downloads to fail and only return the system font (Helvetica on iOS)

	CTFontDescriptorRef fontDescriptorRef = CFAutorelease(CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attributes));
	NSArray *descriptors = @[ (__bridge id)fontDescriptorRef ];

	__block BOOL errorEncountered = NO;
	bool didStartDownload = CTFontDescriptorMatchFontDescriptorsWithProgressHandler((__bridge CFArrayRef)descriptors, NULL, ^bool(CTFontDescriptorMatchingState state, CFDictionaryRef progressParameter) {
		NSLog(@"%@: { %@: { %@ } }", fontName,
			CFAutorelease(CTFontDescriptorCopyAttribute(CFArrayGetValueAtIndex((__bridge CFArrayRef)descriptors, 0), kCTFontNameAttribute)),
				NSStringFromCTFontDescriptorMatchingState(state)
		);

		if (state == kCTFontDescriptorMatchingDidFinish) {
			if (errorEncountered)
				return false;;

			dispatch_async(dispatch_get_main_queue(), ^{
				CTFontRef fontRef = CFAutorelease(CTFontCreateWithName((__bridge CFStringRef)fontName, 0., NULL));
				if (fontRef) {
					CFURLRef fontURL = CFAutorelease(CTFontCopyAttribute(fontRef, kCTFontURLAttribute));

					if (fontURL)
						CTFontManagerRegisterFontsForURL(fontURL, kCTFontManagerScopeUser, NULL); // This scope is documented as unavailable on iOS. But, it still seems to work.

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

			if (completionHandler)
				completionHandler(fontName, NULL);
			postFailureNotification(fontName);

			return false;
		}

		return true;
	});

	if (!didStartDownload) {
		if (completionHandler)
			completionHandler(fontName, NULL);
		postFailureNotification(fontName);
	}
}
@end
