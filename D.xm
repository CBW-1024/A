//  DD小丑助手  (WeChat Jailbreak Tweak, Theos/Logos 单文件)
//  在微信内自定义聊天 / 资料 / 余额等显示
//  功能：聊天文字、图片、时间、转账改写；运动步数、好友数量；余额 / 零钱通自定义；微信账号 / 头像自定义
//  入口：微信 → 插件入口 → "DD小丑助手"设置页

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <string.h>

#pragma mark - 微信类声明
// 本插件 hook 的微信原生类与方法签名，均锚定微信8.0.78头文件 dump。


@interface WCUIAlertView : NSObject
- (id)initWithTitle:(id)a0 message:(id)a1;
- (void)showTextFieldWithMaxLen:(unsigned int)a0;
- (UITextField *)getTextField;
- (id)getTextFieldText;
- (void)setTextFieldDefaultText:(id)a0;
- (void)addBtnTitle:(id)a0 handler:(void (^)(void))a1;
- (void)addCancelBtnTitle:(id)a0 handler:(void (^)(void))a1;
- (void)show;
@end

@interface WeToast : NSObject
+ (id)toast;
- (void)showDoneToastWithText:(id)a0;
- (void)showErrorToastWithText:(id)a0;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightView:(id)rightView;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
+ (id)sectionWithFooter:(NSString *)footer;
+ (id)sectionWithHeader:(NSString *)header Footer:(NSString *)footer;
+ (id)defaultSection;
@property (nonatomic, copy) NSString *footerTitle;
- (void)addCell:(id)arg1;
- (unsigned long long)getCellCount;
- (id)getCellAt:(unsigned long long)a0;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadTableView;
- (id)getTableView;
- (id)getAllSections;
- (void)insertSection:(id)arg1 At:(unsigned int)a1;
@end

@interface CBaseContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@property (retain, nonatomic) NSString *m_nsAliasName;
- (BOOL)isSelf;
@end

@interface CSetting : NSObject
- (id)m_nsAliasName;
@end

@interface AddContactToChatRoomViewController : UIViewController
@property (retain, nonatomic) CBaseContact *m_contact;
- (void)ddWxidSwitchChanged:(UISwitch *)sender;        // 自定义用户账号
- (void)ddAvatarSwitchChanged:(UISwitch *)sender;      // 自定义用户头像
- (void)dd_injectProfileSection;                       // 聊天详情页插入头像 + 账号开关
@end

@interface CContact : CBaseContact
@end

@interface MMHeadImageView : UIView
@property (readonly, nonatomic) NSString *nsUsrName;
- (void)setHeadImageByName:(id)usrName;
- (void)doUpdateHeadImg:(BOOL)force;
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl;
- (void)updateHeadImage:(id)image;
- (void)ImageDidLoad:(id)image Url:(id)url;
- (void)didMoveToWindow;
@end

@interface ImageScrollView : UIView
- (void)updateImage:(id)image;
@end

@interface MMHDHeadImageView : UIView
@property (retain, nonatomic) CBaseContact *m_contact;
- (void)updateHead;
- (void)updateHDHead;
- (void)dd_applyCustomHDHead;
@end

@interface BaseMsgContentLogicController : NSObject
- (id)GetUsrTitle;
- (id)getSubTitle;
- (id)GetTitleTailImageView;
@end

@interface RoomContentLogicController : BaseMsgContentLogicController
- (id)GetUsrTitle;
- (id)getSubTitle;
- (id)getDefaultTitleTailSubViews;
- (id)getMemeberCountLabel;
@end

@interface CMessageWrap : NSObject
@property (nonatomic, assign) unsigned int m_uiMesLocalID;
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
- (BOOL)IsTextMsg;
- (BOOL)IsImgMsg;
- (BOOL)isReferMsgType;
- (NSString *)GetDisplayContent;
@end

@interface BaseMessageViewModel : NSObject
@property (nonatomic, retain) CMessageWrap *messageWrap;
- (void)resetLayoutCache;
@end

@interface CommonMessageViewModel : BaseMessageViewModel
@end

@interface BaseMessageCellView : UIView
- (void)layoutContentView;
- (void)layoutInternal;
- (void)prepareForReuse;
- (id)operationMenuItems;
@end

@interface CommonMessageCellView : BaseMessageCellView
@property (nonatomic, readonly) CommonMessageViewModel *viewModel;
- (void)setViewModel:(id)vm;
@end

@interface BaseMsgContentViewController : UIViewController
- (void)clearNodeLayoutCache;
- (void)reloadNodeWithMessageWrap:(CMessageWrap *)msgWrap;
- (void)reloadVisibleNodeWithCellView:(UIView *)cellView;
- (UITableView *)getMsgTableView;
@end

@interface TextMessageViewModel : CommonMessageViewModel
@property (readonly, nonatomic) NSString *contentText;
- (void)resetLayoutCache;
@end

// RichTextView：JokerApplyTextToRichView 以 id 接收并调用，类名在代码里不出现，
//   但方法确在调用（编译期需要声明，删了会 "no known instance method"）。
//   签名锚定 WeChat/RichTextView.h:131/132/146/223。
@interface RichTextView : UIView
- (id)getContent;
- (void)setContent:(id)content;
- (void)calculateAndUpdateFrame;
- (void)forceDisplayInSync;
@end

@interface TextMessageCellView : CommonMessageCellView
- (id)getRichTextView;
- (id)getTextString;
- (void)layoutContentView;
- (void)setViewModel:(id)vm;

@end

@interface WCPayTransferMessageViewModel : NSObject
- (CMessageWrap *)messageWrap;
- (NSString *)titleText;
- (NSString *)descText;
@end

@interface WCPayBaseMessageCellView : CommonMessageCellView
- (void)onTouchUpInside;
@end

@interface WCPayTransferMessageCellView : WCPayBaseMessageCellView
- (void)updateTitleLabel;
- (void)updateDescLabel;
@end

@interface WCPayControlData : NSObject
@property (retain, nonatomic) CMessageWrap *m_oSelectedMessageWrap;
@end

@interface WCPayBaseViewController : UIViewController
- (WCPayControlData *)data;
@end

@interface WCPayTransferMoneyStatusViewController : WCPayBaseViewController
@end

@interface ImageMessageCellView : CommonMessageCellView
- (void)showImage;
- (void)OnDownloadImageOk:(id)a0;
@end

@interface ChatTimeViewModel : BaseMessageViewModel
- (NSString *)timeText;
- (void)updateLayouts;
@end

@interface ChatTimeCellView : UIView
- (id)initWithViewModel:(id)vm;
- (void)setViewModel:(id)vm;
- (void)layoutInternal;
- (UILabel *)dk_timeLabel;
- (void)dk_installTimeEditGesture;
- (void)dk_handleTimeLongPress:(UILongPressGestureRecognizer *)g;
- (void)dk_showTimeInput;
@end

@interface MMMenuItem : UIMenuItem
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon target:(id)target action:(SEL)action;
@end

@interface WCDeviceStepObject : NSObject
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
@end

@interface ContactsDataLogic : NSObject
- (unsigned int)m_uiNormalContact;
@end
@interface ContactsViewController : UIViewController
- (void)updateCount;
@end

@interface WCPayBalanceDetailViewController : UIViewController
- (id)balanceTitleLabel;
- (void)updateBalanceTitleLabel;
- (void)refreshViewWithData:(id)arg;
@end

// TimeoutNumber 是 ScrollNumber 的外层容器，金额宽度/布局由它管，
//   改它的 updateNumber: 才会连带重算容器尺寸；直接改内层 ScrollNumber 会右溢顶格。
@interface TimeoutNumber : UIView
- (void)updateNumber:(unsigned long long)a0;
- (void)defaultNumber:(unsigned long long)a0;
- (void)updateScrollNumber;
- (id)scrollNumber;
- (CGSize)scrollNumberSize;
@end

// ScrollNumber：钱包页金额数字容器，运行时为 UIView（dump 声明为 NSObject，故按 UIView 声明以访问 frame）。
//   scrollNumberSize / widthOfNumber: 均以 currentNumber 推算文字宽度；改写余额须同时拦住
//   三个写入口（updateNumber: / defaultNumber: / setCurrentNumber:）与 currentNumber getter，
//   使容器宽度与改写值匹配，否则数字右溢顶格。
@interface ScrollNumber : UIView
- (unsigned long long)currentNumber;
- (void)setCurrentNumber:(unsigned long long)a0;
- (void)defaultNumber:(unsigned long long)a0;
- (void)updateNumber:(unsigned long long)a0;
- (id)container;      // dump 中存在：外层容器（TimeoutNumber）
@end

#pragma mark - 配置管理（接口）
// 全局开关与各功能自定义值；以 NSUserDefaults 持久化（见文件末"配置管理（实现）"）。


static NSString * const kDDFeatureTextEnabled = @"DDFeatureTextEnabled";
static NSString * const kDDFeatureTransferEnabled = @"DDFeatureTransferEnabled";
static NSString * const kDDFeatureImageEnabled = @"DDFeatureImageEnabled";
static NSString * const kDDFeatureTimeEnabled = @"DDFeatureTimeEnabled";
static NSString * const kDDFeatureBalanceEnabled = @"DDFeatureBalanceEnabled";
static NSString * const kDDFeatureStepsEnabled = @"DDFeatureStepsEnabled";
static NSString * const kDDFeatureContactsEnabled = @"DDFeatureContactsEnabled";
static NSString * const kDDFeatureFriendWxidEnabled = @"DDFeatureFriendWxidEnabled";
static NSString * const kDDFeatureWxidEnabled = @"DDFeatureWxidEnabled";
static NSString * const kDDFeatureWxidValue = @"DDFeatureWxidValue";
static NSString * const kDDFeatureAvatarEnabled = @"DDFeatureAvatarEnabled";
static NSString * const kDDFeatureHideChatName = @"DDFeatureHideChatName";

static NSString * const kDDStepsValueStringKey = @"DDStepsValueString";
static NSString * const kDDContactsCountValueKey = @"DDContactsCountValue";
static NSString * const kDDBalanceValueKey = @"DDBalanceValue";
static NSString * const kDDLingtongValueKey = @"DDLingtongValue";

@interface DDGlobalConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL textEnabled;
@property (nonatomic) BOOL imageEnabled;
@property (nonatomic) BOOL timeEnabled;
@property (nonatomic) BOOL transferEnabled;
@property (nonatomic) BOOL balanceEnabled;
@property (nonatomic) BOOL stepsEnabled;
@property (nonatomic) BOOL contactsEnabled;
@property (nonatomic) BOOL friendWxidEnabled;
@property (nonatomic) BOOL wxidEnabled;
@property (nonatomic, copy) NSString *wxidValue;
@property (nonatomic) BOOL avatarEnabled;
@property (nonatomic) BOOL hideChatName;

@property (nonatomic, copy) NSString *stepsValueString;
@property (nonatomic, copy) NSString *contactsValue;
@property (nonatomic, copy) NSString *balanceValue;
@property (nonatomic, copy) NSString *lingtongValue;
- (NSInteger)stepsIntegerValue;
- (BOOL)hasStepsValue;
- (BOOL)hasContactsValue;
- (BOOL)hasBalanceValue;
- (BOOL)hasLingtongValue;
- (void)saveSteps;
- (void)saveContacts;
@end

#pragma mark - 通用辅助


static BOOL DDStringHas(const char *haystack, const char *needle) {
    if (!haystack || !needle || !*needle) return NO;
    NSString *h = [[NSString stringWithUTF8String:haystack] lowercaseString];
    NSString *n = [[NSString stringWithUTF8String:needle] lowercaseString];
    return (h && n) ? ([h rangeOfString:n].location != NSNotFound) : NO;
}

#pragma mark - 聊天消息改写（文字 / 图片 / 转账）
// 长按消息弹出"小丑"菜单：文字改内容与引用标题、图片替换为相册所选图、转账改金额。
// 改写值按消息会话唯一键缓存到 plist，刷新走 cell/viewModel 重绘。


static CMessageWrap *JokerGetMessageWrapFromCell(CommonMessageCellView *cell) {
    return cell.viewModel.messageWrap;
}

static id JokerGetViewControllerFromView(UIView *view) {
    UIResponder *responder = view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

static BOOL JokerIsTextMessage(CMessageWrap *msg) {
    return [msg IsTextMsg];
}

static BOOL JokerIsReferMessage(CMessageWrap *msg) {
    return [msg isReferMsgType];
}

static NSString *JokerUnescapeXML(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || !s.length) return s;
    NSDictionary *map = @{@"&lt;":@"<", @"&gt;":@">", @"&amp;":@"&",
                          @"&quot;":@"\"", @"&apos;":@"'"};
    NSMutableString *m = [s mutableCopy];
    for (NSString *key in map) {
        [m replaceOccurrencesOfString:key withString:map[key]
                               options:NSLiteralSearch range:NSMakeRange(0, m.length)];
    }
    return m;
}

static NSString *JokerReferMessageTitle(CMessageWrap *msg) {
    NSString *xml = [msg m_nsContent];
    if (![xml isKindOfClass:[NSString class]] || !xml.length) return nil;
    static NSRegularExpression *re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"<title\\s*>(.*?)</title\\s*>"
                                                        options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                          error:nil];
    });
    NSTextCheckingResult *r = [re firstMatchInString:xml options:0 range:NSMakeRange(0, xml.length)];
    if (!r || r.numberOfRanges < 2) return nil;
    NSString *t = [xml substringWithRange:[r rangeAtIndex:1]];
    t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    t = JokerUnescapeXML(t);
    return t.length ? t : nil;
}

static BOOL JokerIsTransferCell(CommonMessageCellView *cell) {
    return [cell isKindOfClass:%c(WCPayTransferMessageCellView)];
}

static BOOL JokerIsSupportedCell(CommonMessageCellView *cell) {
    if (!cell) return NO;
    if (JokerIsTransferCell(cell)) return YES;
    if ([cell isKindOfClass:%c(TextMessageCellView)]) {
        CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
        return JokerIsTextMessage(msg) || JokerIsReferMessage(msg);
    }
    return NO;
}

static BOOL JokerEnabledForCell(CommonMessageCellView *cell) {
    if (JokerIsTransferCell(cell)) return [DDGlobalConfig shared].transferEnabled;
    return [DDGlobalConfig shared].textEnabled;
}

static NSString *JokerNormalizeAmount(NSString *amount) {
    NSString *trimmed = [amount stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return nil;
    NSMutableString *filtered = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if ((c >= '0' && c <= '9') || c == '.') {
            [filtered appendFormat:@"%C", c];
        }
    }
    if (!filtered.length) return nil;

    if ([filtered rangeOfString:@"."].location == NSNotFound) {
        [filtered appendString:@".00"];
    }
    return filtered;
}

static NSString * const kDDJokerTextCacheKey = @"DDJokerTextCache";
static NSString * const kDDJokerAmountCacheKey = @"DDJokerAmountCache";
static NSString * const kDDJokerTimeCacheKey = @"DDJokerTimeCache";

static NSString * const kDDJokerTextOriginalKey = @"DDJokerTextOriginal";

// localID 仅在单个会话内唯一（CMessageMgr.h:136 强制 usrName+localID 二元组定位），
// 不同会话的 localID 各自从 1 递增会碰撞。用 (fromUsr|toUsr|localID) 三元组作为全局唯一键，
// 确保不同会话的改写互不串扰。
static NSString *DDJokerMessageKey(CMessageWrap *msg) {
    NSString *from = [msg m_nsFromUsr] ?: @"";
    NSString *to   = [msg m_nsToUsr]   ?: @"";
    return [NSString stringWithFormat:@"%@|%@|%u", from, to, [msg m_uiMesLocalID]];
}

// 转账金额以 transferid 作为全局唯一缓存键：同一条转账在聊天列表与详情页的
// localID/from/to 可能不一致，但 transferid 必然相同（取自 m_nsContent 的 <transferid>），
// 用它才能稳定命中同一笔改写。
static NSString *DDTransferIDFromContent(NSString *xml) {
    if (!xml.length) return nil;
    NSRange ro = [xml rangeOfString:@"<transferid>" options:NSCaseInsensitiveSearch];
    if (ro.location == NSNotFound) return nil;
    NSUInteger start = ro.location + ro.length;
    NSRange rc = [xml rangeOfString:@"</transferid>" options:NSCaseInsensitiveSearch
                               range:NSMakeRange(start, xml.length - start)];
    if (rc.location == NSNotFound) return nil;
    NSString *tid = [xml substringWithRange:NSMakeRange(start, rc.location - start)];
    return tid.length ? tid : nil;
}
static NSString *DDJokerAmountKey(CMessageWrap *msg) {
    NSString *tid = DDTransferIDFromContent([msg m_nsContent]);
    return tid.length ? [@"TRF:" stringByAppendingString:tid] : nil;
}

static NSString *DDJokerCacheDir(void) {
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/DDJoker"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}
static NSString *DDJokerCacheFile(NSString *name) {
    return [DDJokerCacheDir() stringByAppendingPathComponent:[name stringByAppendingString:@".plist"]];
}
static NSMutableDictionary *DDJokerLoadCache(NSString *name) {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:DDJokerCacheFile(name)];
    return d ?: [NSMutableDictionary dictionary];
}
static void DDJokerSaveCache(NSString *name, NSDictionary *d) {
    [d writeToFile:DDJokerCacheFile(name) atomically:YES];
}
static NSString *DDJokerImagesDir(void) {
    NSString *dir = [DDJokerCacheDir() stringByAppendingPathComponent:@"DDJokerImages"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *DDJokerCachedText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerTextCacheKey);
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetCachedText(CMessageWrap *msg, NSString *text) {
    if (!msg) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerTextCacheKey);
    if (text.length) d[DDJokerMessageKey(msg)] = text;
    else [d removeObjectForKey:DDJokerMessageKey(msg)];
    DDJokerSaveCache(kDDJokerTextCacheKey, d);
}

static NSString *DDJokerOriginalText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerTextOriginalKey);
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetOriginalText(CMessageWrap *msg, NSString *text) {
    if (!msg || !text.length) return;
    if (DDJokerOriginalText(msg)) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerTextOriginalKey);
    d[DDJokerMessageKey(msg)] = text;
    DDJokerSaveCache(kDDJokerTextOriginalKey, d);
}

static NSString *DDJokerCachedAmount(CMessageWrap *msg) {
    if (!msg) return nil;
    NSString *key = DDJokerAmountKey(msg);
    if (!key) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerAmountCacheKey);
    NSString *v = d[key];
    return v.length ? v : nil;
}

static void DDJokerSetCachedAmount(CMessageWrap *msg, NSString *amount) {
    if (!msg) return;
    NSString *key = DDJokerAmountKey(msg);
    if (!key) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerAmountCacheKey);
    if (amount.length) d[key] = amount;
    else [d removeObjectForKey:key];
    DDJokerSaveCache(kDDJokerAmountCacheKey, d);
}

// 转账详情页作用域：由 WCPayTransferMoneyStatusViewController 的存活状态控制，
// viewDidLoad 时进入（同时取出缓存金额）、dealloc 时退出。金额统一经
// DDTransferDetailSetAmount 写入，label 每次刷新时实时取用，不依赖刷新时序。
static NSInteger gDDTransferDetailCount = 0;
static BOOL gDDInTransferDetail = NO;
static NSString *gDDTransferDetailAmount = nil;

static void DDTransferDetailSetAmount(NSString *amount) {
    gDDTransferDetailAmount = amount.length ? [amount copy] : nil;
}
static void DDTransferDetailEnter(CMessageWrap *msg) {
    gDDTransferDetailCount++;
    gDDInTransferDetail = YES;
    DDTransferDetailSetAmount(DDJokerCachedAmount(msg));
}
static void DDTransferDetailLeave(void) {
    gDDTransferDetailCount--;
    if (gDDTransferDetailCount <= 0) {
        gDDTransferDetailCount = 0;
        gDDInTransferDetail = NO;
        gDDTransferDetailAmount = nil;
    }
}

#pragma mark - 聊天时间 · 缓存与 ivar 读写
// 直接读写 ChatTimeViewModel 的 _showingTime ivar（double 时间戳）；缓存按消息或原始时间戳索引。


static Ivar DDShowingTimeIvarOf(id vm) {
    if (!vm) return NULL;
    Class cls = [vm class];
    Ivar iv = class_getInstanceVariable(cls, "_showingTime");
    if (iv) return iv;

    Class c = cls;
    while (c && !iv) {
        unsigned int n = 0;
        Ivar *list = class_copyIvarList(c, &n);
        for (unsigned int i = 0; i < n; i++) {
            const char *nm = ivar_getName(list[i]) ?: "";
            const char *ty = ivar_getTypeEncoding(list[i]) ?: "";
            if (strcmp(ty, "d") == 0 && DDStringHas(nm, "showingtime")) { iv = list[i]; break; }
        }
        free(list);
        c = class_getSuperclass(c);
    }
    return iv;
}

static double DDShowingTimeOf(id vm) {
    Ivar iv = DDShowingTimeIvarOf(vm);
    if (!iv) return 0.0;
    return *(double *)((uint8_t *)(__bridge void *)vm + ivar_getOffset(iv));
}

static void DDSetShowingTime(id vm, double ts) {
    Ivar iv = DDShowingTimeIvarOf(vm);
    if (!iv) return;
    *(double *)((uint8_t *)(__bridge void *)vm + ivar_getOffset(iv)) = ts;
}

static void DDRefreshTimeText(id vm) {
    [(ChatTimeViewModel *)vm updateLayouts];
}

static char kDDRawTimeKey;
static double DDRawShowingTimeOf(id vm) {
    if (!vm) return 0.0;
    NSNumber *raw = objc_getAssociatedObject(vm, &kDDRawTimeKey);
    if (!raw) {
        raw = @(DDShowingTimeOf(vm));
        objc_setAssociatedObject(vm, &kDDRawTimeKey, raw, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return [raw doubleValue];
}

static NSString *DDJokerTimeKey(id vm) {
    id wrap = [vm respondsToSelector:@selector(messageWrap)] ? [vm messageWrap] : nil;
    if ([wrap respondsToSelector:@selector(m_uiMesLocalID)] && [wrap m_uiMesLocalID] != 0) {
        return DDJokerMessageKey((CMessageWrap *)wrap);
    }
    return [NSString stringWithFormat:@"ts_%.3f", DDRawShowingTimeOf(vm)];
}

static NSNumber *DDJokerCachedTime(id vm) {
    if (!vm) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerTimeCacheKey);
    id v = d[DDJokerTimeKey(vm)];
    return [v isKindOfClass:[NSNumber class]] ? v : nil;
}

static void DDJokerSetCachedTime(id vm, double timestamp) {
    if (!vm) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerTimeCacheKey);
    if (timestamp > 0) d[DDJokerTimeKey(vm)] = @(timestamp);
    else [d removeObjectForKey:DDJokerTimeKey(vm)];
    DDJokerSaveCache(kDDJokerTimeCacheKey, d);
}

static void DDApplyTimeOverride(id vm) {
    if (!vm || ![DDGlobalConfig shared].timeEnabled) return;
    NSNumber *cached = DDJokerCachedTime(vm);
    if (cached && DDShowingTimeOf(vm) != [cached doubleValue]) {
        DDSetShowingTime(vm, [cached doubleValue]);
    }
}

static void DDJokerClearAllMessageCache(void) {
    NSFileManager *fm = [NSFileManager defaultManager];

    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerTextCacheKey) error:nil];
    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerAmountCacheKey) error:nil];
    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerTimeCacheKey) error:nil];

    [fm removeItemAtPath:DDJokerImagesDir() error:nil];
    DDTransferDetailLeave();
}


static void JokerCollectViewControllers(UIViewController *root, NSMutableArray *out) {
    if (!root || [out containsObject:root]) return;
    [out addObject:root];
    if (root.presentedViewController) JokerCollectViewControllers(root.presentedViewController, out);
    for (UIViewController *c in root.childViewControllers) JokerCollectViewControllers(c, out);
    if ([root isKindOfClass:[UINavigationController class]]) {
        for (UIViewController *c in ((UINavigationController *)root).viewControllers) JokerCollectViewControllers(c, out);
    }
    if ([root isKindOfClass:[UITabBarController class]]) {
        for (UIViewController *c in ((UITabBarController *)root).viewControllers) JokerCollectViewControllers(c, out);
    }
}

static NSArray *JokerAllChatViewControllers(void) {
    NSMutableArray *all = [NSMutableArray array];
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            JokerCollectViewControllers(w.rootViewController, all);
        }
    }
    NSMutableArray *chats = [NSMutableArray array];
    for (UIViewController *vc in all) {
        if ([vc isKindOfClass:%c(BaseMsgContentViewController)]) [chats addObject:vc];
    }
    return chats;
}

static void JokerReloadAllMsgContent(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
    }
}

static void DDCollectViewsOfClass(UIView *root, Class cls, NSMutableArray *out) {
    if (!root) return;
    if ([root isKindOfClass:cls]) {
        if (![out containsObject:root]) [out addObject:root];
        return;
    }
    for (UIView *v in root.subviews) DDCollectViewsOfClass(v, cls, out);
}

static NSArray *DDVisibleCellViewsOfClass(UITableView *tv, Class cls) {
    NSMutableArray *out = [NSMutableArray array];
    if (![tv isKindOfClass:[UITableView class]] || !cls) return out;
    for (UITableViewCell *c in [tv visibleCells]) {
        DDCollectViewsOfClass(c.contentView, cls, out);
        DDCollectViewsOfClass(c, cls, out);
    }
    return out;
}

static void JokerRefreshVisibleImageCells(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if (![tv isKindOfClass:[UITableView class]]) continue;
        for (ImageMessageCellView *cellView in DDVisibleCellViewsOfClass(tv, %c(ImageMessageCellView))) {
            if ([cellView respondsToSelector:@selector(showImage)]) [cellView showImage];
        }
    }
}

static NSString *DDTransferFeedescAmount(NSString *xml);
static NSString *JokerGetDisplayText(CMessageWrap *msg, BOOL isTransfer) {
    if (isTransfer) {
        NSString *cached = DDJokerCachedAmount(msg);
        if (cached.length) return cached;
        NSString *raw = DDTransferFeedescAmount([msg m_nsContent]);
        return JokerNormalizeAmount(raw) ?: @"";
    }
    NSString *cached = DDJokerCachedText(msg);
    if (cached) return cached;

    if (JokerIsReferMessage(msg)) {
        NSString *t = JokerReferMessageTitle(msg);
        if (t) return t;
    }
    return [msg GetDisplayContent] ?: @"";
}

static UITableView *JokerFindTableView(UIView *view) {
    UIView *v = view;
    while (v) {
        if ([v isKindOfClass:[UITableView class]]) return (UITableView *)v;
        v = v.superview;
    }
    return nil;
}

static void JokerApplyTextToRichView(id richView, NSString *text) {
    if (!richView || !text) return;
    [richView setContent:text];
    [richView calculateAndUpdateFrame];
    [richView forceDisplayInSync];
    [richView setNeedsDisplay];
}

static void JokerResetViewModelCache(CommonMessageCellView *cell) {
    id vm = cell.viewModel;
    [vm resetLayoutCache];
}

static void JokerRefreshCellDirectly(CommonMessageCellView *cell) {
    if (!cell) return;
    JokerResetViewModelCache(cell);
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);

    if ([cell isKindOfClass:%c(TextMessageCellView)]) {
        NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;

        if (!cached && (JokerIsTextMessage(msg) || JokerIsReferMessage(msg))) {
            if (JokerIsReferMessage(msg)) {
                cached = JokerReferMessageTitle(msg) ?: [msg GetDisplayContent];
            } else {
                cached = [msg GetDisplayContent];
            }
        }
        JokerApplyTextToRichView([(TextMessageCellView *)cell getRichTextView], cached);
        [(TextMessageCellView *)cell layoutContentView];
    } else if ([cell isKindOfClass:%c(WCPayTransferMessageCellView)]) {
        [(WCPayTransferMessageCellView *)cell layoutContentView];

        [(WCPayTransferMessageCellView *)cell updateTitleLabel];
        [(WCPayTransferMessageCellView *)cell updateDescLabel];
    } else if ([cell isKindOfClass:%c(ImageMessageCellView)]) {
        [(ImageMessageCellView *)cell showImage];
    }
    [cell setNeedsLayout];
}

static void JokerInvalidateAllLayout(void);

static void JokerReloadCellAfterReplace(id vc, CMessageWrap *msg, CommonMessageCellView *cell) {
    JokerRefreshCellDirectly(cell);
    UITableView *tv = cell ? JokerFindTableView((UIView *)cell) : nil;
    if (![tv isKindOfClass:[UITableView class]] && [vc isKindOfClass:%c(BaseMsgContentViewController)]) {
        tv = [(BaseMsgContentViewController *)vc getMsgTableView];
    }
    if (![tv isKindOfClass:[UITableView class]]) {

        JokerReloadAllMsgContent();
        return;
    }

    CGPoint center = [cell convertPoint:CGPointMake(CGRectGetMidX(cell.bounds), CGRectGetMidY(cell.bounds)) toView:tv];
    NSIndexPath *ip = [tv indexPathForRowAtPoint:center];
    if (ip) {
        [UIView performWithoutAnimation:^{
            [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        }];
        return;
    }
    JokerInvalidateAllLayout();
}

static void JokerPresentEditor(CommonMessageCellView *cell) {

    if (!JokerIsSupportedCell(cell)) return;
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    id vc = JokerGetViewControllerFromView(cell);

    BOOL isTransfer = JokerIsTransferCell(cell);
    NSString *current = JokerGetDisplayText(msg, isTransfer);

    NSString *editorTitle = isTransfer ? @"转账修改" : @"文字修改";
    NSString *editorMessage = isTransfer ? @"请输入需要修改的金额\n留空还原" : @"请输入需要修改的文字\n留空还原";
    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:editorTitle message:editorMessage];
    if (!alert) return;
    [alert showTextFieldWithMaxLen:1000];
    [alert setTextFieldDefaultText:current];

    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{}];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;
        NSString *newText = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newText.length) {
            if ([newText isEqualToString:current]) { blockAlert = nil; return; }
            if (isTransfer) {
                NSString *normalized = JokerNormalizeAmount(newText);
                if (normalized) { DDJokerSetCachedAmount(msg, normalized); }
            } else {
                DDJokerSetCachedText(msg, newText);
            }
            JokerReloadCellAfterReplace(vc, msg, cell);
        } else if (isTransfer ? DDJokerCachedAmount(msg) : DDJokerCachedText(msg)) {

            if (isTransfer) DDJokerSetCachedAmount(msg, nil);
            else DDJokerSetCachedText(msg, nil);
            JokerReloadCellAfterReplace(vc, msg, cell);
        }
        blockAlert = nil;
    }];
    [alert show];
    UITextField *tf = [alert getTextField];
    if (tf) {
        inputField = tf;
        if (isTransfer) tf.keyboardType = UIKeyboardTypeDecimalPad;
    }
}

static NSArray *JokerInjectMenuItem(CommonMessageCellView *cell, NSArray *original) {

    if (!JokerEnabledForCell(cell)) return original;
    if (!JokerIsSupportedCell(cell)) return original;

    UIImage *icon = [[UIImage systemImageNamed:@"face.smiling.fill"] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *newItem = [(MMMenuItem *)[%c(MMMenuItem) alloc] initWithTitle:@"小丑" icon:icon target:cell action:@selector(joker_handleMenuItem:)];
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}

static void DDJokerApplyTextOverride(CMessageWrap *msg) {
    if (!msg) return;
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;
    NSString *original = DDJokerOriginalText(msg);
    if (!original.length) {
        DDJokerSetOriginalText(msg, msg.m_nsContent);
        original = msg.m_nsContent;
    }
    NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;
    NSString *target = cached ?: original;
    if (target.length && ![target isEqualToString:msg.m_nsContent]) {
        [msg setM_nsContent:target];
    }
}

%hook TextMessageViewModel
- (NSString *)contentText {
    DDJokerApplyTextOverride(self.messageWrap);
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    CMessageWrap *msg = self.messageWrap;

    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
%end

static BOOL gJokerNeedsResetLayout = NO;

static void JokerInvalidateAllLayout(void) {
    gJokerNeedsResetLayout = YES;
    JokerReloadAllMsgContent();
    JokerRefreshVisibleImageCells();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gJokerNeedsResetLayout = NO;
    });
}

%hook TextMessageCellView

- (void)setViewModel:(id)vm {
    %orig;
    if (![vm respondsToSelector:@selector(resetLayoutCache)]) return;
    CMessageWrap *msg = [(CommonMessageViewModel *)vm messageWrap];
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;

    if (gJokerNeedsResetLayout || DDJokerCachedText(msg) || ![DDGlobalConfig shared].textEnabled) {
        [(TextMessageViewModel *)vm resetLayoutCache];
    }
}
- (id)getTextString {
    CMessageWrap *msg = JokerGetMessageWrapFromCell(self);
    DDJokerApplyTextOverride(msg);
    id origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return JokerEnabledForCell(self) && JokerIsSupportedCell(self);
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

static NSString *DDTransferFeedescAmount(NSString *xml) {
    if (!xml.length) return nil;
    NSString *open = @"<feedesc><![CDATA[";
    NSString *close = @"]]></feedesc>";
    NSRange ro = [xml rangeOfString:open];
    if (ro.location == NSNotFound) return nil;
    NSUInteger start = ro.location + ro.length;
    NSRange rc = [xml rangeOfString:close options:0 range:NSMakeRange(start, xml.length - start)];
    if (rc.location == NSNotFound) return nil;
    return [xml substringWithRange:NSMakeRange(start, rc.location - start)];
}

static NSString *DDTransferReplaceAmountInText(NSString *text, NSString *override) {
    if (!text.length || !override.length) return text;
    // 转账消息金额：必带 ¥、两位小数（允许千分位逗号）。
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"¥\\d[\\d,]*\\.\\d{2}"
                                                                        options:0
                                                                          error:nil];
    if (!re) return text;
    NSString *newAmount = [@"¥" stringByAppendingString:override];
    return [re stringByReplacingMatchesInString:text
                                       options:0
                                         range:NSMakeRange(0, text.length)
                                  withTemplate:newAmount];
}

// 转账详情页金额改写：进入详情页时按 transferid 命中缓存金额并进入作用域；
// 金额 label 渲染时由 MMUILabel 的 hook 实时改写为目标值。
%hook WCPayTransferMoneyStatusViewController
- (void)viewDidLoad {
    DDTransferDetailEnter([self data].m_oSelectedMessageWrap);
    %orig;
}
- (void)dealloc {
    %orig;
    DDTransferDetailLeave();
}
%end

%hook WCPayTransferMessageCellView

- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {

    if (action == @selector(joker_handleMenuItem:)) {
        return [DDGlobalConfig shared].transferEnabled;
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

%hook WCPayTransferMessageViewModel
- (NSString *)titleText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].transferEnabled) return origin;
    NSString *cached = DDJokerCachedAmount(self.messageWrap);
    NSString *out = cached ? DDTransferReplaceAmountInText(origin, cached) : origin;
    return out;
}
- (NSString *)descText {
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].transferEnabled) return origin;
    NSString *cached = DDJokerCachedAmount(self.messageWrap);
    return cached ? DDTransferReplaceAmountInText(origin, cached) : origin;
}
%end

// 转账详情页金额 label 为 MMUILabel，直接 hook 其 setText:/setAttributedText:：
// 当处于转账详情页作用域、功能开启且文本为 ¥ 金额时，改写为目标金额。
// 每次 setText: 实时取用最新目标值，覆盖微信的状态刷新与重布局。

%hook MMUILabel
- (void)setText:(NSString *)text {
    if (gDDInTransferDetail && [DDGlobalConfig shared].transferEnabled && gDDTransferDetailAmount.length && [text hasPrefix:@"¥"]) {
        %orig([@"¥" stringByAppendingString:gDDTransferDetailAmount]);
    } else {
        %orig;
    }
}
- (void)setAttributedText:(NSAttributedString *)attr {
    if (gDDInTransferDetail && [DDGlobalConfig shared].transferEnabled && gDDTransferDetailAmount.length
        && attr.string.length && [attr.string hasPrefix:@"¥"]) {
        NSDictionary *attrs = [attr attributesAtIndex:0 effectiveRange:NULL];
        %orig([[NSAttributedString alloc] initWithString:[@"¥" stringByAppendingString:gDDTransferDetailAmount] attributes:attrs]);
    } else {
        %orig;
    }
}
%end

#pragma mark - 聊天图片改写
// hook ImageMessageCellView 各渲染入口注入替换图；相册选图回调见下一段。


@interface DDWeChatImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) NSString *sessionKey;   // 会话唯一键（from|to|localID），区分不同会话的图片改写
@property (nonatomic, weak) id cellView;
@end

static NSString *DDImageReplacementPath(NSString *sessionKey) {
    NSString *folder = DDJokerImagesDir();
    NSString *safe = [sessionKey stringByReplacingOccurrencesOfString:@"|" withString:@"_"];
    return [folder stringByAppendingPathComponent:[safe stringByAppendingString:@".png"]];
}

static UIImage *DDImageReplacementForMessage(CMessageWrap *msg) {
    if (!msg || ![msg IsImgMsg]) return nil;
    NSString *path = DDImageReplacementPath(DDJokerMessageKey(msg));
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    return [UIImage imageWithContentsOfFile:path];
}

static UIImageView *DDImageViewFromCell(UIView *cell) {
    if (!cell) return nil;
    // 图片视图为 ImageMessageCellView 的 m_imageView ivar，直接读取，无需遍历。
    Ivar ivar = class_getInstanceVariable([cell class], "m_imageView");
    if (ivar) {
        id value = object_getIvar(cell, ivar);
        if ([value isKindOfClass:[UIImageView class]]) return (UIImageView *)value;
    }
    return nil;
}

static void DDImageApplyReplacementToCell(id cell) {
    if (![DDGlobalConfig shared].imageEnabled) return;
    CMessageWrap *msg = ((CommonMessageCellView *)cell).viewModel.messageWrap;
    UIImage *rep = DDImageReplacementForMessage(msg);
    if (rep) {
        UIImageView *iv = DDImageViewFromCell((UIView *)cell);
        [iv setImage:rep];
    }
}

%hook ImageMessageCellView
- (void)setViewModel:(id)vm {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!cfg.imageEnabled) return original;
    CMessageWrap *msg = self.viewModel.messageWrap;
    if (![msg IsImgMsg]) return original;
    UIImage *icon = [[UIImage systemImageNamed:@"face.smiling.fill"] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *newItem = [(MMMenuItem *)[%c(MMMenuItem) alloc] initWithTitle:@"小丑" icon:icon target:self action:@selector(dk_changeChatImage)];
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dk_changeChatImage)) {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.imageEnabled) return NO;
        CMessageWrap *msg = self.viewModel.messageWrap;
        return [msg IsImgMsg];
    }
    return %orig;
}
%new
- (void)dk_changeChatImage {
    CMessageWrap *msg = self.viewModel.messageWrap;
    if (![msg IsImgMsg]) return;
    id vc = JokerGetViewControllerFromView((UIView *)(id)self);
    if (!vc) return;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    picker.title = @"图片修改";
    DDWeChatImagePickerDelegate *delegate = [[DDWeChatImagePickerDelegate alloc] init];
    delegate.sessionKey = DDJokerMessageKey(msg);
    delegate.cellView = self;
    picker.delegate = delegate;

    objc_setAssociatedObject(picker, "dd_picker_delegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [vc presentViewController:picker animated:YES completion:nil];
}
- (void)showImage {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)OnDownloadImageOk:(id)a0 {

    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)layoutContentView {
    %orig;
    DDImageApplyReplacementToCell(self);
}
%end

@implementation DDWeChatImagePickerDelegate

#pragma mark - 系统相册选图回调
// 选图后落盘到以 sessionKey（from|to|localID）命名的 png，并刷新对应 cell。


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) [self dd_saveImage:image dismissPicker:picker];
    else [picker dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)dd_saveImage:(UIImage *)image dismissPicker:(UIImagePickerController *)picker {
    NSString *path = DDImageReplacementPath(self.sessionKey);
    NSData *data = UIImagePNGRepresentation(image);
    if (!data) { [picker dismissViewControllerAnimated:YES completion:nil]; return; }
    [data writeToFile:path atomically:YES];

    id cellView = self.cellView;
    if ([cellView isKindOfClass:%c(ImageMessageCellView)]) {
        DDImageApplyReplacementToCell(cellView);
        [(UIView *)cellView setNeedsLayout];
    } else {
        JokerInvalidateAllLayout();
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end

#pragma mark - 聊天时间改写
// hook ChatTimeViewModel / ChatTimeCellView：接管时间条显示，长按弹输入改时间。


static char kDDTimeVMKey;

static NSDateFormatter *DDTimeInputFormatter(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.dateFormat = @"yyyy-MM-dd HH:mm";
    return f;
}

static double DDTimeStampFromString(NSString *s) {
    if (!s.length) return 0;
    NSDate *d = [DDTimeInputFormatter() dateFromString:s];
    return d ? [d timeIntervalSince1970] : 0;
}

%hook ChatTimeViewModel
- (NSString *)timeText {

    double raw = DDRawShowingTimeOf(self);
    NSNumber *cached = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(self) : nil;
    double target = cached ? [cached doubleValue] : raw;

    if (target > 0 && DDShowingTimeOf(self) != target) {
        DDSetShowingTime(self, target);
        DDRefreshTimeText(self);
    }

    return %orig;
}

%end

%hook ChatTimeCellView
- (id)initWithViewModel:(id)vm {
    id r = %orig;

    objc_setAssociatedObject(r, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [(ChatTimeCellView *)r dk_installTimeEditGesture];
    return r;
}
- (void)setViewModel:(id)vm {
    %orig;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self dk_installTimeEditGesture];
}
- (void)didMoveToWindow {
    %orig;
    [self dk_installTimeEditGesture];
    if (!self.window) return;
    id vm = objc_getAssociatedObject(self, &kDDTimeVMKey);
    if (!vm) return;
    NSNumber *cached = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(vm) : nil;
    if (!cached) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;
        id v = objc_getAssociatedObject(self, &kDDTimeVMKey);
        if (!v) return;
        NSNumber *c = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(v) : nil;
        if (!c) return;
        DDApplyTimeOverride(v);
        DDRefreshTimeText(v);
        [(ChatTimeCellView *)self layoutInternal];
        [self setNeedsLayout];
    });
}
%new
- (UILabel *)dk_timeLabel {
    // 时间 label 为 ChatTimeCellView 的 m_timeLabel ivar，直接读取，无需遍历。
    Ivar iv = class_getInstanceVariable([self class], "m_timeLabel");
    if (iv) {
        id v = object_getIvar(self, iv);
        if ([v isKindOfClass:[UILabel class]]) return (UILabel *)v;
    }
    return nil;
}
%new
- (void)dk_installTimeEditGesture {
    if (![DDGlobalConfig shared].timeEnabled) return;
    UILabel *label = [self dk_timeLabel];
    if (!label) return;
    for (UIGestureRecognizer *g in label.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) return;
    }
    label.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleTimeLongPress:)];
    lp.minimumPressDuration = 0.5;
    lp.allowableMovement = 24;
    lp.cancelsTouchesInView = NO;
    [label addGestureRecognizer:lp];
}
%new
- (void)dk_handleTimeLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [self dk_showTimeInput];
}
%new
- (void)dk_showTimeInput {
    if (![DDGlobalConfig shared].timeEnabled) return;
    id vm = objc_getAssociatedObject(self, &kDDTimeVMKey);
    if (!vm || !%c(WCUIAlertView)) return;

    NSNumber *cached = DDJokerCachedTime(vm);
    double base = cached ? [cached doubleValue]
                         : DDShowingTimeOf(vm);
    NSString *defaultText = base > 0 ? [DDTimeInputFormatter() stringFromDate:[NSDate dateWithTimeIntervalSince1970:base]] : @"";

    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:@"时间修改"
                                                                           message:@"输入格式如下\n2024-08-01 22:30\n留空还原"];
    [alert showTextFieldWithMaxLen:100];
    [alert setTextFieldDefaultText:defaultText];

    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{ blockAlert = nil; }];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;
        NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        double ts = DDTimeStampFromString(t);
        if (ts > 0) {

            DDJokerSetCachedTime(vm, ts);
            DDSetShowingTime(vm, ts);
            DDRefreshTimeText(vm);
            [self layoutInternal];
            [self setNeedsLayout];
        } else if (DDJokerCachedTime(vm)) {

            DDJokerSetCachedTime(vm, 0);
            double rawTime = DDRawShowingTimeOf(vm);
            if (rawTime > 0) DDSetShowingTime(vm, rawTime);
            DDRefreshTimeText(vm);
            [self layoutInternal];
            [self setNeedsLayout];
        }
        blockAlert = nil;
    }];
    [alert show];
    UITextField *tf = [alert getTextField];
    if (tf) inputField = tf;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

#pragma mark - 运动步数改写
// hook WCDeviceStepObject 的 m7StepCount / hkStepCount getter，返回自定义步数。


%hook WCDeviceStepObject
- (unsigned int)m7StepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSInteger v = [cfg stepsIntegerValue];
        if (v > 0) return (unsigned int)MIN(v, 99999);
    }
    return %orig;
}

- (unsigned int)hkStepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSInteger v = [cfg stepsIntegerValue];
        if (v > 0) return (unsigned int)MIN(v, 99999);
    }
    return %orig;
}
%end

#pragma mark - 好友数量改写
// hook ContactsDataLogic 数量 getter 与通讯录页标题。


%hook ContactsDataLogic
- (unsigned int)m_uiNormalContact {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.contactsEnabled && [cfg hasContactsValue]) {
        NSInteger v = [cfg.contactsValue integerValue];
        if (v > 0) return (unsigned int)v;
    }
    return %orig;
}
%end

%hook ContactsViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.contactsEnabled && [cfg hasContactsValue]) {
        self.title = [NSString stringWithFormat:@"通讯录(%@)", cfg.contactsValue];
    }

    if ([self respondsToSelector:@selector(updateCount)]) [self updateCount];
}
%end

#pragma mark - 余额 / 零钱通改写（工具）
// 元→分换算、页面类型判定（余额 / 零钱通 / 无关）、金额文本正则改写。


static unsigned long long DDBalanceFenValue(void) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (![cfg hasBalanceValue]) return 0;
    double v = [cfg.balanceValue doubleValue];
    if (v < 0) v = 0;
    return (unsigned long long)(v * 100.0 + 0.5);
}

static unsigned long long DDLingtongFenValue(void) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (![cfg hasLingtongValue]) return 0;
    double v = [cfg.lingtongValue doubleValue];
    if (v < 0) v = 0;
    return (unsigned long long)(v * 100.0 + 0.5);
}

typedef NS_ENUM(NSInteger, DDBalancePageKind) {
    DDBalancePageNone = 0,
    DDBalancePageBalance,
    DDBalancePageLQT
};

// 页面判定：沿响应链上溯，命中的第一条规则即返回。
//   钱包页单元格：祖先 accessibilityIdentifier 为 balance_cell -> 余额，lqt_cell -> 零钱通
//   详情/服务页（VC description）：balanceEntryUIPage / WCPayMainViewControllerV2 -> 余额，lqtDetailUIPage -> 零钱通
static DDBalancePageKind DDBalancePageKindOf(id sn) {
    @try {
        if (![sn isKindOfClass:[UIView class]]) return DDBalancePageNone;
        UIResponder *r = (UIResponder *)sn;
        for (int depth = 0; depth < 24 && r; depth++) {
            if ([r isKindOfClass:[UIView class]]) {
                NSString *ai = ((UIView *)r).accessibilityIdentifier;
                if ([ai isEqualToString:@"lqt_cell"])
                    return DDBalancePageLQT;
                if ([ai isEqualToString:@"balance_cell"])
                    return DDBalancePageBalance;
            }
            if ([r isKindOfClass:[UIViewController class]]) {
                NSString *cls = NSStringFromClass([r class]) ?: @"";
                NSString *all = [NSString stringWithFormat:@"%@ %@", cls, [r description] ?: @""];
                if ([all rangeOfString:@"lqtDetailUIPage"].location != NSNotFound)
                    return DDBalancePageLQT;
                if ([all rangeOfString:@"balanceEntryUIPage"].location != NSNotFound ||
                    [cls rangeOfString:@"WCPayMainViewControllerV2"].location != NSNotFound)
                    return DDBalancePageBalance;
            }
            r = r.nextResponder;
        }
    } @catch (NSException *e) {}
    return DDBalancePageNone;
}

// 帧修正专用判定：只认钱包页零钱/零钱通单元格的标识符，
// 不认任何 VC，避免把微信支付总页（WCPayMainViewControllerV2 等）下其他页面的
// TimeoutNumber 也卷进 frame 重设（那种布局不同，强行右对齐会把数字顶没）。
static DDBalancePageKind DDBalanceCellKindOf(id sn) {
    @try {
        if (![sn isKindOfClass:[UIView class]]) return DDBalancePageNone;
        UIResponder *r = (UIResponder *)sn;
        for (int depth = 0; depth < 24 && r; depth++) {
            if ([r isKindOfClass:[UIView class]]) {
                NSString *ai = ((UIView *)r).accessibilityIdentifier;
                if ([ai isEqualToString:@"lqt_cell"])    return DDBalancePageLQT;
                if ([ai isEqualToString:@"balance_cell"]) return DDBalancePageBalance;
            }
            r = r.nextResponder;
        }
    } @catch (NSException *e) {}
    return DDBalancePageNone;
}

// 判定基准归一化：ScrollNumber 在部分 dump 里被标成 NSObject，运行时未必是 UIView。
//   若传入的对象不是 UIView，就改用它持有的 container（外层 TimeoutNumber）或 superview
//   作为判定基准 —— 否则所有 isKindOfClass:[UIView class] 的守卫都会直接返回"未命中"。
static id DDBalanceAnchorOf(id v) {
    if ([v isKindOfClass:[UIView class]]) return v;
    @try {
        if ([v respondsToSelector:@selector(container)]) {
            id c = [v container];
            if ([c isKindOfClass:[UIView class]]) return c;
        }
        if ([v respondsToSelector:@selector(superview)]) {
            id sp = [v superview];
            if ([sp isKindOfClass:[UIView class]]) return sp;
        }
    } @catch (NSException *e) {}
    return v;
}

// 改值判定（宽）：认 cell 标识符，也认详情页 / 服务页的 VC —— 这些页面的金额都要改，
//   覆盖面要广。与下面修帧用的窄判定刻意分开：改值可以广，动 frame 必须窄。
static DDBalancePageKind DDBalanceResolveKind(id v) {
    return DDBalancePageKindOf(DDBalanceAnchorOf(v));
}

// 修帧判定（窄）：只认钱包页两个金额单元格 balance_cell（零钱）/ lqt_cell（零钱通）。
//   这两个 cell 的金额行右侧有箭头，改值后数字变长会右溢盖住它，才需要重排；
//   服务页钱包入口、零钱 / 零钱通详情页的金额本来就不顶格，动它们的 frame 反而会被推歪。
static DDBalancePageKind DDBalanceFixKindFor(id v) {
    return DDBalanceCellKindOf(DDBalanceAnchorOf(v));
}

// 前向声明：DDClampFen 定义在本文件稍后（取目标值时要先钳位）
static unsigned long long DDClampFen(unsigned long long fen);

// 取该 view 应改成的目标值（分）；不需要改写返回 NO。
static BOOL DDBalanceWantFenFor(id v, DDBalancePageKind kind, unsigned long long *out) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { *out = DDClampFen(DDLingtongFenValue()); return YES; }
    if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { *out = DDClampFen(DDBalanceFenValue()); return YES; }
    return NO;
}

// 钱包页金额行右侧箭头 + 间距占用的宽度，沿用 28pt 右缘边距常量（不压箭头）。
static const CGFloat kDDWalletArrowGap = 28.0;

// frame 是否已够接近（避免重复赋值触发 Kinda 反复重排 → 闪烁）
static BOOL DDBalanceFrameNear(CGRect a, CGRect b) {
    return (fabs(a.origin.x - b.origin.x) < 0.5 && fabs(a.origin.y - b.origin.y) < 0.5 &&
            fabs(a.size.width - b.size.width) < 0.5 && fabs(a.size.height - b.size.height) < 0.5);
}

static unsigned long long DDClampFen(unsigned long long fen) {
    const unsigned long long kMaxFen = 99999999999ULL;
    return fen > kMaxFen ? kMaxFen : fen;
}

static NSString *DDBalanceRewriteMoneyText(NSString *text, unsigned long long fen) {
    if (!text.length) return text;
    // 金额由 ScrollNumber 以两位小数渲染，¥ 为独立 label，故匹配可选 ¥ + 两位小数数字。
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"[¥￥]?\\s*\\d[\\d,]*\\.\\d{2}" options:0 error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!m || m.range.location == NSNotFound) return text;
    NSRange r = m.range;
    NSString *num = [text substringWithRange:r];
    BOOL sym = ([num hasPrefix:@"¥"] || [num hasPrefix:@"￥"]);
    NSString *core = sym ? [num substringFromIndex:1] : num;
    core = [core stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL comma = ([core rangeOfString:@","].location != NSNotFound);
    NSInteger dec = 0;
    NSRange dot = [core rangeOfString:@"."];
    if (dot.location != NSNotFound) dec = (NSInteger)core.length - (NSInteger)dot.location - 1;
    unsigned long long scaled = fen;
    if (dec > 2) { for (int i = 0; i < dec - 2; i++) scaled *= 10; }
    else { for (int i = 0; i < 2 - dec; i++) scaled /= 10; }
    unsigned long long ip = scaled / (unsigned long long)pow(10, dec);
    unsigned long long fp = scaled % (unsigned long long)pow(10, dec);
    NSMutableString *ipStr = [NSMutableString stringWithFormat:@"%llu", ip];
    if (comma) {
        NSMutableString *tmp = [NSMutableString string];
        NSInteger c = 0;
        for (NSInteger i = (NSInteger)ipStr.length - 1; i >= 0; i--) {
            [tmp insertString:[ipStr substringWithRange:NSMakeRange(i, 1)] atIndex:0];
            if (++c % 3 == 0 && c < (NSInteger)ipStr.length) [tmp insertString:@"," atIndex:0];
        }
        ipStr = tmp;
    }
    NSString *newNum = dec > 0 ? [NSString stringWithFormat:@"%@.%0*llu", ipStr, (int)dec, fp] : [ipStr copy];
    if (sym) newNum = [@"¥" stringByAppendingString:newNum];
    NSMutableString *out = [text mutableCopy];
    [out replaceCharactersInRange:r withString:newNum];
    return out;
}

static void DDBalancePatchTitleLabel(id vc, unsigned long long fen) {
    @try {
        if (![vc respondsToSelector:@selector(balanceTitleLabel)]) return;
        id lb = [vc balanceTitleLabel];
        if (![lb isKindOfClass:[UILabel class]]) return;
        NSString *t = ((UILabel *)lb).text;
        if (!t.length) return;
        NSString *nt = DDBalanceRewriteMoneyText(t, fen);
        if (![nt isEqualToString:t]) { ((UILabel *)lb).text = nt; }
    } @catch (NSException *e) {}
}

#pragma mark - 余额 / 零钱通改写
// 金额由 TimeoutNumber（容器）内的 ScrollNumber（滚轮）渲染，两条链都要接管：
//   · 改值 —— 三个写入口 updateNumber: / defaultNumber: / setCurrentNumber: 全部换成目标值，
//     外加 currentNumber 读路径（原生按它推算宽度，只改写入口会导致宽度与新值不匹配）。
//     三个写入口缺一不可：服务页金额由 WCPayWalletGetAllFunctionCgi 回调经 setCurrentNumber:
//     异步直赋，漏了它就会先闪一下真实金额。
//   · 修帧 —— 钱包页两个金额单元格右侧有箭头，数字变长后原生 frame 仍是旧宽度会右溢盖住，
//     故在 layoutSubviews 里按 scrollNumberSize 重设滚轮与自身 frame，把右缘钉在箭头左侧。

%hook TimeoutNumber
- (void)updateNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceResolveKind(self);
            unsigned long long want = 0; BOOL rewrite = NO;
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue])          { want = DDClampFen(DDLingtongFenValue()); rewrite = YES; }
            else if (kind == DDBalancePageBalance && [cfg hasBalanceValue])   { want = DDClampFen(DDBalanceFenValue());   rewrite = YES; }
            if (rewrite) { %orig(want); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
- (void)defaultNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceResolveKind(self);
            unsigned long long want = 0; BOOL rewrite = NO;
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue])          { want = DDClampFen(DDLingtongFenValue()); rewrite = YES; }
            else if (kind == DDBalancePageBalance && [cfg hasBalanceValue])   { want = DDClampFen(DDBalanceFenValue());   rewrite = YES; }
            if (rewrite) { %orig(want); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
// 顶格修复三步，缺一不可：
//   1) [sn setFrame:] 原点不变、尺寸换成 scrollNumberSize —— 滚轮按新值的正确尺寸重设
//   2) [self updateScrollNumber]                         —— 容器按新滚轮尺寸重排内部
//   3) [self setFrame:] x = superview 宽度 - 28 - 宽度    —— 右缘钉在箭头左侧，数字往左长
// 前提：scrollNumberSize 按改后的值算，所以下方 %hook ScrollNumber 必须连 currentNumber
//   读路径一起改；只改写入口的话宽度仍按旧值算，光改 frame 救不回来。
- (void)layoutSubviews {
    %orig;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.balanceEnabled) return;
        // 只命中钱包页两个金额单元格才修帧，其余页面一律不碰。
        DDBalancePageKind fixKind = DDBalanceFixKindFor(self);
        if (fixKind != DDBalancePageBalance && fixKind != DDBalancePageLQT) return;
        unsigned long long want = 0;
        if (!DDBalanceWantFenFor(self, fixKind, &want)) return;
        if (![self respondsToSelector:@selector(scrollNumber)] ||
            ![self respondsToSelector:@selector(scrollNumberSize)]) return;
        UIView *sn = [self scrollNumber];
        if (![sn isKindOfClass:[UIView class]]) return;
        // 几何加固（必须放在改动任何 frame 之前，否则"拦了但宽度已经改过"，等于没拦）：
        //   钱包页金额行位于 cell 内，父容器宽度有限；父容器接近全宽的必然是
        //   零钱/零钱通详情页那种居中的大数字，一旦右对齐就会被推到屏幕边上。
        UIView *sp = self.superview;
        if (!sp) return;
        CGFloat spW = sp.bounds.size.width;
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        if (screenW > 0 && spW > screenW * 0.7) return;
        CGSize sz = [self scrollNumberSize];
        if (sz.width <= 0 || sz.height <= 0) return;
        // ① 滚轮尺寸按新值重设（原点保持不变）
        CGRect snF = sn.frame;
        CGRect snNew = CGRectMake(snF.origin.x, snF.origin.y, sz.width, sz.height);
        if (!DDBalanceFrameNear(snF, snNew)) sn.frame = snNew;
        // ② 容器按新的滚轮尺寸重排内部
        if ([self respondsToSelector:@selector(updateScrollNumber)]) [self updateScrollNumber];
        // ③ 自身右对齐：右缘钉在 superview 宽度 - 箭头区(28)，数字往左长 → 永远压不到箭头
        CGRect selfF = self.frame;
        CGFloat newX = spW - kDDWalletArrowGap - sz.width;
        // 越界处理：算出的位置越过左边界（或 superview 宽度异常）时退化为"右缘原地不动"
        if (spW <= 0 || newX < 0) newX = (selfF.origin.x + selfF.size.width) - sz.width;
        CGRect selfNew = CGRectMake(newX, selfF.origin.y, sz.width, selfF.size.height);
        if (!DDBalanceFrameNear(selfF, selfNew)) self.frame = selfNew;
    } @catch (NSException *e) {}
}
%end

// 读路径必须一起改：scrollNumberSize / widthOfNumber: 都读 currentNumber 推算宽度，
//   只改写入口的话内部宽度仍按旧值算，容器与内容对不上 → 数字右溢盖箭头（顶格）。
%hook ScrollNumber
// 写入口③：property setter 直赋。服务页（WCPayMainViewControllerV2）的金额由
//   WCPayWalletGetAllFunctionCgi 回调异步写入，闪出真实金额的就是这条未拦截的路径。
//   与 currentNumber getter 的改写自洽：写入假值 → 重排按假值算宽 → getter 返回同值。
- (void)setCurrentNumber:(unsigned long long)original {
    unsigned long long v = original;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceResolveKind(self);
            unsigned long long want = 0;
            if (DDBalanceWantFenFor(self, kind, &want)) v = want;
        }
    } @catch (NSException *e) {}
    %orig(v);
}
- (unsigned long long)currentNumber {
    unsigned long long orig = %orig;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.balanceEnabled) return orig;
        DDBalancePageKind kind = DDBalanceResolveKind(self);
        unsigned long long want = 0;
        if (!DDBalanceWantFenFor(self, kind, &want)) return orig;
        return want;
    } @catch (NSException *e) {}
    return orig;
}
- (void)defaultNumber:(unsigned long long)original {
    unsigned long long v = original;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceResolveKind(self);
            unsigned long long want = 0;
            if (DDBalanceWantFenFor(self, kind, &want)) v = want;
        }
    } @catch (NSException *e) {}
    %orig(v);
}
- (void)updateNumber:(unsigned long long)original {
    unsigned long long v = original;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceResolveKind(self);
            unsigned long long want = 0;
            if (DDBalanceWantFenFor(self, kind, &want)) v = want;
        }
    } @catch (NSException *e) {}
    %orig(v);
}
%end

%hook WCPayBalanceDetailViewController
- (void)refreshViewWithData:(id)arg {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()));
}
- (void)updateBalanceTitleLabel {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()));
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()));
}
%end


#pragma mark - 用户账号自定义（按用户名，聊天详情页逐人设置）

static NSString * const kDDFriendWxidChangedNotification = @"DDFriendWxidChanged";

static NSString *DDFriendWxidStorePath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = paths.firstObject;
    if (doc.length == 0) doc = @"/var/mobile/Documents";
    return [doc stringByAppendingPathComponent:@"DDFriendWxid.plist"];
}

static NSMutableDictionary *DDFriendWxidMap(void) {
    static NSMutableDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:DDFriendWxidStorePath()];
        map = [disk mutableCopy];
        if (!map) map = [NSMutableDictionary dictionary];
    });
    return map;
}

static NSString *DDFriendWxidForUser(NSString *usrName) {
    if (![DDGlobalConfig shared].friendWxidEnabled) return nil;
    if (usrName.length == 0) return nil;
    NSString *value = DDFriendWxidMap()[usrName];
    return [value isKindOfClass:[NSString class]] ? value : nil;   // 存了空串也算，效果＝隐藏
}

static void DDFriendWxidSetForUser(NSString *value, NSString *usrName) {
    if (usrName.length == 0) return;
    DDFriendWxidMap()[usrName] = value ?: @"";
    [DDFriendWxidMap() writeToFile:DDFriendWxidStorePath() atomically:YES];
}

static void DDFriendWxidRemoveForUser(NSString *usrName) {
    if (usrName.length == 0) return;
    [DDFriendWxidMap() removeObjectForKey:usrName];
    [DDFriendWxidMap() writeToFile:DDFriendWxidStorePath() atomically:YES];
}

#pragma mark - 头像文件管理

static void DDRefreshAvatarViewsForUser(NSString *usrName);

static NSString *DDAvatarDir(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = paths.firstObject;
    if (doc.length == 0) doc = @"/var/mobile/Documents";
    NSString *dir = [doc stringByAppendingPathComponent:@"DDAvatar"];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
    }
    return dir;
}

static NSString *DDAvatarPathForUser(NSString *usrName) {
    if (usrName.length == 0) return nil;
    NSCharacterSet *keep = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *safe = [NSMutableString string];
    for (NSUInteger i = 0; i < usrName.length; i++) {
        unichar c = [usrName characterAtIndex:i];
        if ([keep characterIsMember:c]) {
            [safe appendFormat:@"%C", c];
        } else {
            [safe appendString:@"_"];
        }
    }
    return [DDAvatarDir() stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"png"]];
}

static NSCache *DDAvatarCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
    });
    return cache;
}

static void DDAvatarCacheInvalidate(NSString *usrName) {
    if (usrName.length) [DDAvatarCache() removeObjectForKey:usrName];
    else [DDAvatarCache() removeAllObjects];
}

static UIImage *DDAvatarImageForUser(NSString *usrName) {
    if (![DDGlobalConfig shared].avatarEnabled) return nil;
    if (usrName.length == 0) return nil;
    NSCache *cache = DDAvatarCache();
    id cached = [cache objectForKey:usrName];
    if (cached) return (cached == [NSNull null]) ? nil : (UIImage *)cached;

    UIImage *img = [UIImage imageWithContentsOfFile:DDAvatarPathForUser(usrName)];
    if (!(img && img.size.width > 0 && img.size.height > 0)) img = nil;
    [cache setObject:(img ?: (UIImage *)[NSNull null]) forKey:usrName];
    return img;
}

static UIImage *DDScaledImage(UIImage *image, CGFloat maxSide) {
    if (!image || maxSide <= 0) return image;
    CGSize size = image.size;
    CGFloat longest = MAX(size.width, size.height);
    if (longest <= maxSide) return image;
    CGFloat ratio = maxSide / longest;
    CGSize target = CGSizeMake(round(size.width * ratio), round(size.height * ratio));
    UIGraphicsBeginImageContextWithOptions(target, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled ?: image;
}

static BOOL DDAvatarSaveImage(UIImage *image, NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!image || !path) return NO;
    NSData *data = UIImagePNGRepresentation(DDScaledImage(image, 400.0));
    if (data.length == 0) return NO;
    BOOL ok = [data writeToFile:path atomically:YES];
    if (ok) {
        DDAvatarCacheInvalidate(usrName);
        DDRefreshAvatarViewsForUser(usrName);
    }
    return ok;
}

static BOOL DDAvatarRemoveForUser(NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!path) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    DDAvatarCacheInvalidate(usrName);
    if (ok) DDRefreshAvatarViewsForUser(usrName);
    return ok;
}

static NSInteger DDAvatarRemoveAll(void) {
    NSString *dir = DDAvatarDir();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSInteger n = 0;
    for (NSString *f in files) {
        if (![f.pathExtension isEqualToString:@"png"]) continue;
        if ([[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil]) n++;
    }
    if (n > 0) {
        DDAvatarCacheInvalidate(nil);
        DDRefreshAvatarViewsForUser(nil);
    }
    return n;
}

#pragma mark - 选图（系统 UIImagePickerController）

typedef void (^DDAvatarPickCompletion)(UIImage *image);

@interface DDAvatarPicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) DDAvatarPickCompletion completion;
+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion;
@end

@implementation DDAvatarPicker

static char kDDAvatarPickerDelegateKey;

static UIViewController *DDTopPresentedViewController(UIViewController *vc) {
    UIViewController *top = vc;
    NSInteger guard = 0;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed && guard++ < 8) {
        top = top.presentedViewController;
    }
    return top;
}

+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion {
    if (!vc) {
        if (completion) completion(nil);
        return;
    }
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        if (completion) completion(nil);
        return;
    }

    UIViewController *presenter = DDTopPresentedViewController(vc);

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.title = @"头像修改";

    DDAvatarPicker *proxy = [[DDAvatarPicker alloc] init];
    proxy.completion = completion;
    picker.delegate = proxy;
    objc_setAssociatedObject(picker, &kDDAvatarPickerDelegateKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!presenter.view.window || presenter.isBeingDismissed || presenter.presentedViewController) {
            if (completion) completion(nil);
            return;
        }
        [presenter presentViewController:picker animated:YES completion:^{
        }];
    });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(image);
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(nil);
    }];
}

@end

#pragma mark - 自定义自己账号（只改自己）

static NSString *DDCustomWxid(void) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!cfg.wxidEnabled) return nil;
    NSString *value = cfg.wxidValue;
    if (value.length == 0) return nil;
    return value;
}

#pragma mark - 数据源（微信「账号」统一拦截）

%hook CBaseContact

// CBaseContact.h:12 —— m_nsAliasName 即「账号」。
// 用户：查自定义表，命中返回自定义值（空串＝隐藏），未命中回原值。
- (id)m_nsAliasName {
    NSString *alias = DDFriendWxidForUser([self m_nsUsrName]);
    if (alias) return alias;
    return %orig;
}

%end

%hook CSetting
// CSetting.h:58/301 —— 微信「我」页面、设置等读取的自己的 m_nsAliasName 数据源。
// CSetting 独立继承 NSObject，不继承 CBaseContact，需单独 hook。
- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom) return custom;
    return %orig;
}
%end

#pragma mark - 头像替换（显示侧）

static NSHashTable *DDAvatarViews(void) {
    static NSHashTable *t = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ t = [NSHashTable weakObjectsHashTable]; });
    return t;
}

static void DDRefreshAvatarViewsForUser(NSString *usrName) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ DDRefreshAvatarViewsForUser(usrName); });
        return;
    }
    for (MMHeadImageView *v in DDAvatarViews()) {
        NSString *name = v.nsUsrName;
        if (name.length == 0) continue;
        if (usrName.length && ![name isEqualToString:usrName]) continue;
        [v setHeadImageByName:name];
    }
}

static BOOL DDTryApplyCustomAvatar(MMHeadImageView *view, NSString *usrName) {
    NSString *name = usrName.length ? usrName : view.nsUsrName;
    UIImage *custom = DDAvatarImageForUser(name);
    if (!custom) return NO;
    [view updateHeadImage:custom];
    return YES;
}

%hook MMHeadImageView

- (void)updateHeadImage:(id)image {
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    %orig(custom ?: image);
}

- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl {
    %orig(usrName, headImgUrl);
    UIImage *custom = DDAvatarImageForUser(usrName ?: [self nsUsrName]);
    if (custom) {
        [self updateHeadImage:custom];
    }
}

- (void)ImageDidLoad:(id)image Url:(id)url {
    %orig(image, url);
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    if (custom) {
        [self updateHeadImage:custom];
    }
}

- (void)setHeadImageByName:(id)usrName {
    %orig(usrName);
    DDTryApplyCustomAvatar(self, usrName);
}

- (void)doUpdateHeadImg:(BOOL)force {
    %orig(force);
    DDTryApplyCustomAvatar(self, nil);
}

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    [DDAvatarViews() addObject:self];
    DDTryApplyCustomAvatar(self, nil);
}

%end

#pragma mark - 头像替换 · 高清大图（点开资料页头像后）

static UIView *DDFindImageScrollViewIn(UIView *root) {
    if (!root) return nil;
    Class cls = %c(ImageScrollView);
    if (!cls) return nil;
    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:cls]) return v;
        UIView *found = DDFindImageScrollViewIn(v);
        if (found) return found;
    }
    return nil;
}

%hook MMHDHeadImageView

%new
- (void)dd_applyCustomHDHead {
    UIImage *custom = DDAvatarImageForUser([self.m_contact m_nsUsrName]);
    if (!custom) return;
    ImageScrollView *sv = (ImageScrollView *)DDFindImageScrollViewIn(self);
    if (!sv) return;
    [sv updateImage:custom];
}

- (void)updateHead {
    %orig;
    [self dd_applyCustomHDHead];
}

- (void)updateHDHead {
    %orig;
    [self dd_applyCustomHDHead];
}

%end

#pragma mark - 聊天详情页「自定义头像 / 自定义账号」入口

static NSString * const kDDProfileChangedNotification = @"DDProfileContentChanged";

static const void *kDDInjectedCellMarker = &kDDInjectedCellMarker;

static BOOL DDSectionHasInjectedCell(id section) {
    @try {
        unsigned long long n = [section getCellCount];
        for (unsigned long long i = 0; i < n; i++) {
            id c = [section getCellAt:i];
            if (objc_getAssociatedObject(c, kDDInjectedCellMarker) != nil) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

static __weak AddContactToChatRoomViewController *s_profileVC = nil;

static AddContactToChatRoomViewController *DDProfileVCForTable(id tableViewInfo) {
    AddContactToChatRoomViewController *vc = s_profileVC;
    if (!vc || !tableViewInfo) return nil;
    id tv = nil;
    @try { tv = [vc valueForKey:@"m_tableViewInfo"]; } @catch (NSException *e) { tv = nil; }
    if (tv != tableViewInfo) return nil;
    return vc;
}

// 在微信重建表格的同一次 runloop 内将入口插入到位置 At:1（资料卡正下方），不产生额外帧。
static void DDInjectProfileSectionIntoTable(AddContactToChatRoomViewController *vc, BOOL reloadNow) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!cfg.avatarEnabled && !cfg.friendWxidEnabled) return;
    if (![vc m_contact]) return;
    id tableViewInfo = [vc valueForKey:@"m_tableViewInfo"];
    if (!tableViewInfo) return;
    NSArray *sections = [tableViewInfo getAllSections];
    if (sections.count == 0) return;
    for (id s in sections) {
        if (DDSectionHasInjectedCell(s)) return;
    }

    NSString *usrName = [[vc m_contact] m_nsUsrName];
    id section = [%c(WCTableViewSectionManager) defaultSection];
    id firstCell = nil;

    if (cfg.avatarEnabled) {
        BOOL hasCustom = DDAvatarImageForUser(usrName) != nil;
        id cell = [%c(WCTableViewCellManager) switchCellForSel:@selector(ddAvatarSwitchChanged:)
                                                       target:vc
                                                        title:@"自定义头像"
                                                           on:hasCustom];
        if (cell) { [section addCell:cell]; if (!firstCell) firstCell = cell; }
    }
    if (cfg.friendWxidEnabled) {
        BOOL hasCustom = DDFriendWxidForUser(usrName) != nil;
        id cell = [%c(WCTableViewCellManager) switchCellForSel:@selector(ddWxidSwitchChanged:)
                                                       target:vc
                                                        title:@"自定义账号"
                                                           on:hasCustom];
        if (cell) { [section addCell:cell]; if (!firstCell) firstCell = cell; }
    }
    if (!firstCell) return;

    // 只给第一行打标记：查重靠它，两行始终同进同退
    objc_setAssociatedObject(firstCell, kDDInjectedCellMarker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tableViewInfo insertSection:section At:1];
    if (reloadNow) [[tableViewInfo getTableView] reloadData];
}

%hook WCTableViewManager

// 微信重建表格走 clearAllSection → addSection ×N；首个 addSection 回调时资料卡已加回，
//   此刻同步插入到 At:1，与重建在同一 runloop 内完成，随后一次 reloadData 即带出该行。
- (void)addSection:(id)a0 {
    %orig;
    if (!a0) return;
    AddContactToChatRoomViewController *vc = DDProfileVCForTable(self);
    if (!vc || ![vc m_contact]) return;
    DDInjectProfileSectionIntoTable(vc, NO);
}

%end

%hook AddContactToChatRoomViewController

// s_profileVC 须在 %orig 之前赋值：微信在 super viewDidLoad 内部即完成表格装配，
//   若晚于 %orig 赋值，装配期的 addSection 钩子会无法识别本表而跳过，需退到 viewWillAppear 才补插。
- (void)viewDidLoad {
    s_profileVC = self;
    %orig;
    s_profileVC = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadTableData)
                                                 name:kDDProfileChangedNotification
                                               object:nil];
    [self dd_injectProfileSection];   // 表格已装配完、页面尚未显示，首帧即带开关
}

// 转场前再确认一次：若微信在 %orig 内又重建表格，此处补插（已插入时由查重跳过）。
- (void)viewWillAppear:(BOOL)animated {
    s_profileVC = self;
    %orig;
    s_profileVC = self;
    [self dd_injectProfileSection];
}

- (void)dealloc {
    if (s_profileVC == self) s_profileVC = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kDDProfileChangedNotification object:nil];
    %orig;
}

%new
- (void)dd_injectProfileSection {
    DDInjectProfileSectionIntoTable(self, YES);
}

%new
- (void)ddAvatarSwitchChanged:(UISwitch *)sender {
    CBaseContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    if (DDAvatarImageForUser(usrName)) {
        (void)DDAvatarRemoveForUser(usrName);
        [[NSNotificationCenter defaultCenter] postNotificationName:kDDProfileChangedNotification object:nil];
    } else {
        __weak typeof(self) weakSelf = self;
        __weak UISwitch *weakSw = sender;
        [DDAvatarPicker presentFromViewController:self completion:^(UIImage *image) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (!image) {
                [weakSw setOn:NO animated:YES];
                return;
            }
            if (!DDAvatarSaveImage(image, usrName)) {
                [weakSw setOn:NO animated:YES];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:kDDProfileChangedNotification object:nil];
            }
        }];
    }
}

// 与「自定义头像」对称：开 → 微信原生输入弹窗；关 → 清掉该用户的自定义。
// 弹窗里留空直接确定 = 存空串，效果等同隐藏。
%new
- (void)ddWxidSwitchChanged:(UISwitch *)sender {
    CBaseContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    if (DDFriendWxidForUser(usrName)) {
        DDFriendWxidRemoveForUser(usrName);
        [[NSNotificationCenter defaultCenter] postNotificationName:kDDFriendWxidChangedNotification object:nil];
        return;
    }

    WCUIAlertView *alert = [[%c(WCUIAlertView) alloc] initWithTitle:@"账号修改" message:@"请输入账号如：520\n输入空格隐藏账号\n留空还原"];
    if (!alert) {
        [sender setOn:NO animated:YES];
        return;
    }
    [alert showTextFieldWithMaxLen:32];
    [alert setTextFieldDefaultText:[contact m_nsAliasName] ?: @""];

    // 无参 block 配合 __block 强持有，回调末尾置 nil 打破循环；
    //   getTextField 需在 show 之后才有，故直接 getTextFieldText 取文本。
    __block WCUIAlertView *blockAlert = alert;
    __weak UISwitch *weakSw = sender;

    [alert addCancelBtnTitle:@"取消" handler:^{
        [weakSw setOn:NO animated:YES];
        blockAlert = nil;
    }];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *text = [blockAlert getTextFieldText] ?: @"";
        if (text.length == 0) {
            // 没有输入：关闭该用户自定义并回弹开关
            DDFriendWxidRemoveForUser(usrName);
            [weakSw setOn:NO animated:YES];
        } else {
            // 空格 / 文字：原样保存（空格＝空白账号即隐藏）
            DDFriendWxidSetForUser(text, usrName);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kDDFriendWxidChangedNotification object:nil];
        blockAlert = nil;
    }];
    [alert show];
}

%end

#pragma mark - 隐藏聊天顶栏名字（单聊 / 群聊）

static BOOL DDHideChatName(void) {
    return [DDGlobalConfig shared].hideChatName;
}

%hook BaseMsgContentLogicController

- (id)GetUsrTitle {
    if (DDHideChatName()) return @"";
    return %orig;
}

- (id)getSubTitle {
    if (DDHideChatName()) return @"";
    return %orig;
}

- (id)GetTitleTailImageView {
    if (DDHideChatName()) return nil;
    return %orig;
}

%end

%hook RoomContentLogicController

- (id)GetUsrTitle {
    if (DDHideChatName()) return @"";
    return %orig;
}

- (id)getSubTitle {
    if (DDHideChatName()) return @"";
    return %orig;
}

- (id)getDefaultTitleTailSubViews {
    if (DDHideChatName()) return nil;
    return %orig;
}

- (id)getMemeberCountLabel {
    if (DDHideChatName()) return nil;
    return %orig;
}

%end

#pragma mark - 设置界面
// 各功能开关、自定义值输入；表视图委托转发给微信原生 manager。


@interface DDJokerSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *stepsField;
@property (nonatomic, strong) UITextField *contactsField;
@property (nonatomic, strong) UITextField *balanceField;
@property (nonatomic, strong) UITextField *lingtongField;
@property (nonatomic, strong) UITextField *wxidField;
@end

@implementation DDJokerSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
    UITextField *_wxidField;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小丑助手设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:[[UIScreen mainScreen] bounds] style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];

    _originalDelegate = _tableViewManager.delegate;
    _tableViewManager.delegate = self;

    [self buildTable];
}

- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action placeholder:(NSString *)placeholder text:(NSString *)text {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    container.backgroundColor = [UIColor clearColor];

    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
    field.placeholder = placeholder;
    field.text = text;
    field.textAlignment = NSTextAlignmentRight;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.backgroundColor = [UIColor systemGray5Color];
    field.layer.cornerRadius = 6.0;
    field.layer.masksToBounds = YES;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.rightViewMode = UITextFieldViewModeAlways;
    [container addSubview:field];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(168, 0, 52, 34);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];

    return container;
}

- (UIButton *)dd_actionButton:(NSString *)title action:(SEL)action x:(CGFloat)x {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(x, 0, 52, 34);
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)buildTable {
    [_tableViewManager clearAllSection];

    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    Class cellCls = %c(WCTableViewCellManager);

    WCTableViewSectionManager *chatSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"聊天小丑"];
    chatSection.footerTitle = @"开启后长按消息，弹窗菜单点击「小丑」修改";
    [chatSection addCell:[cellCls switchCellForSel:@selector(textSwitchChanged:) target:self title:@"聊天文字修改" on:cfg.textEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(imageSwitchChanged:) target:self title:@"聊天图片修改" on:cfg.imageEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(timeSwitchChanged:) target:self title:@"聊天时间修改" on:cfg.timeEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(transferSwitchChanged:) target:self title:@"聊天转账修改" on:cfg.transferEnabled]];
    UIButton *clearBtn = [self dd_actionButton:@"清理" action:@selector(clearChatCacheTapped:) x:0];
    UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [clearRight addSubview:clearBtn];
    [chatSection addCell:[cellCls normalCellForSel:nil target:nil title:@"清空修改记录" rightView:clearRight]];
    [_tableViewManager addSection:chatSection];

    WCTableViewSectionManager *profileSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"资料小丑"];
    profileSection.footerTitle = @"开启设置用户账号/头像后在「聊天详情」页逐人自定义";
    [profileSection addCell:[cellCls switchCellForSel:@selector(balanceSwitchChanged:) target:self title:@"零钱余额修改" on:cfg.balanceEnabled]];
    if (cfg.balanceEnabled) {
        self.balanceField = [[UITextField alloc] init];
        [self.balanceField addTarget:self action:@selector(balanceChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentBalance = [cfg hasBalanceValue] ? cfg.balanceValue : @"";
        UIView *balanceRight = [self inputRowWithField:self.balanceField
                                                action:@selector(balanceConfirm:)
                                           placeholder:@"例如：888.88"
                                                  text:currentBalance];
        self.balanceField.keyboardType = UIKeyboardTypeDecimalPad;
        WCTableViewCellManager *balanceSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳余额自定义" rightView:balanceRight];
        balanceSubCell.userInfo = @"SubCell";
        [profileSection addCell:balanceSubCell];

        self.lingtongField = [[UITextField alloc] init];
        [self.lingtongField addTarget:self action:@selector(lingtongChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentLingtong = [cfg hasLingtongValue] ? cfg.lingtongValue : @"";
        UIView *lingtongRight = [self inputRowWithField:self.lingtongField
                                                 action:@selector(lingtongConfirm:)
                                            placeholder:@"例如：888.88"
                                                   text:currentLingtong];
        self.lingtongField.keyboardType = UIKeyboardTypeDecimalPad;
        WCTableViewCellManager *lingtongSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳零钱通自定义" rightView:lingtongRight];
        lingtongSubCell.userInfo = @"SubCell";
        [profileSection addCell:lingtongSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(stepsSwitchChanged:) target:self title:@"运动步数修改" on:cfg.stepsEnabled]];
    if (cfg.stepsEnabled) {
        self.stepsField = [[UITextField alloc] init];
        [self.stepsField addTarget:self action:@selector(stepsChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentSteps = [cfg hasStepsValue] ? cfg.stepsValueString : @"";
        UIView *rightView = [self inputRowWithField:self.stepsField
                                             action:@selector(stepsConfirm:)
                                        placeholder:@"例如：88888"
                                               text:currentSteps];
        WCTableViewCellManager *stepsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳步数自定义" rightView:rightView];
        stepsSubCell.userInfo = @"SubCell";
        [profileSection addCell:stepsSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(contactsSwitchChanged:) target:self title:@"好友数量修改" on:cfg.contactsEnabled]];
    if (cfg.contactsEnabled) {
        self.contactsField = [[UITextField alloc] init];
        [self.contactsField addTarget:self action:@selector(contactsChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentContacts = [cfg hasContactsValue] ? cfg.contactsValue : @"";
        UIView *rightView = [self inputRowWithField:self.contactsField
                                             action:@selector(contactsConfirm:)
                                        placeholder:@"例如：520"
                                               text:currentContacts];
        WCTableViewCellManager *contactsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳数量自定义" rightView:rightView];
        contactsSubCell.userInfo = @"SubCell";
        [profileSection addCell:contactsSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(wxidSwitchChanged:) target:self title:@"设置自己账号" on:cfg.wxidEnabled]];
    if (cfg.wxidEnabled) {
        self.wxidField = [[UITextField alloc] init];
        NSString *currentWxid = cfg.wxidValue.length ? cfg.wxidValue : @"";
        UIView *rightView = [self inputRowWithField:self.wxidField
                                         action:@selector(wxidConfirm:)
                                    placeholder:@"例如：520"
                                           text:currentWxid];
        self.wxidField.keyboardType = UIKeyboardTypeASCIICapable;
        WCTableViewCellManager *wxidSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳账号自定义" rightView:rightView];
        wxidSubCell.userInfo = @"SubCell";
        [profileSection addCell:wxidSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(friendWxidSwitch:) target:self title:@"设置用户账号" on:cfg.friendWxidEnabled]];

    [profileSection addCell:[cellCls switchCellForSel:@selector(hideChatNameSwitch:) target:self title:@"隐藏顶栏名字" on:cfg.hideChatName]];

    [profileSection addCell:[cellCls switchCellForSel:@selector(avatarSwitchChanged:) target:self title:@"设置用户头像" on:cfg.avatarEnabled]];
    UIButton *avatarClearBtn = [self dd_actionButton:@"清理" action:@selector(clearAllAvatarTapped:) x:0];
    UIView *avatarClearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [avatarClearRight addSubview:avatarClearBtn];
    [profileSection addCell:[cellCls normalCellForSel:nil target:nil title:@"清空全部头像" rightView:avatarClearRight]];

    [_tableViewManager addSection:profileSection];

    [_tableViewManager reloadTableView];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = [self.tableViewManager cellInfoAtIndexPath:indexPath];
    if ([cellInfo.userInfo isEqualToString:@"SubCell"]) {
        cell.indentationLevel = 1;
        cell.indentationWidth = 16.0;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    return UITableViewAutomaticDimension;
}

- (void)textSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].textEnabled = sender.isOn;
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)imageSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].imageEnabled = sender.isOn;
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)timeSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].timeEnabled = sender.isOn;
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)transferSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].transferEnabled = sender.isOn;

    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)clearChatCacheTapped:(id)sender {
    DDJokerClearAllMessageCache();
    JokerInvalidateAllLayout();
    [self buildTable];
    [self dd_showDoneToast:@"记录已清理"];
}

- (void)dd_showDoneToast:(NSString *)text {
    if (!text.length) return;

    WeToast *toast = [%c(WeToast) toast];
    if (toast) [toast showDoneToastWithText:text];
}

- (void)balanceSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].balanceEnabled = sender.isOn;
    [self buildTable];
}

- (void)stepsSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].stepsEnabled = sender.isOn;
    [self buildTable];
}

- (void)contactsSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].contactsEnabled = sender.isOn;
    [self buildTable];
}

- (void)friendWxidSwitch:(UISwitch *)sender {
    [DDGlobalConfig shared].friendWxidEnabled = sender.isOn;
}

- (void)wxidSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDGlobalConfig shared].wxidEnabled = sw.on;
    [self buildTable];
}

- (void)wxidConfirm:(id)sender {
    // 原样保存：空＝不覆盖，空格＝空白账号（隐藏），其他＝自定义值
    [DDGlobalConfig shared].wxidValue = self.wxidField.text ?: @"";
    [self.wxidField resignFirstResponder];
    [self buildTable];
}

- (void)avatarSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDGlobalConfig shared].avatarEnabled = sw.on;
    if (!sw.on) DDRefreshAvatarViewsForUser(nil);
    [self buildTable];
}

- (void)hideChatNameSwitch:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDGlobalConfig shared].hideChatName = sw.on;
}

- (void)clearAllAvatarTapped:(id)sender {
    (void)DDAvatarRemoveAll();
    [self dd_showDoneToast:@"头像已清理"];
}

- (void)stepsConfirm:(id)sender {
    NSString *input = self.stepsField.text;
    [self saveStepsInput:input];
    [self buildTable];
}

- (void)contactsConfirm:(id)sender {
    NSString *input = self.contactsField.text;
    [self saveContactsInput:input];
    [self buildTable];
}

- (void)balanceConfirm:(id)sender {
    NSString *input = self.balanceField.text;
    [self saveBalanceInput:input];
    [self buildTable];
}

- (void)lingtongConfirm:(id)sender {
    NSString *input = self.lingtongField.text;
    [self saveLingtongInput:input];
    [self buildTable];
}

- (void)balanceChanged:(id)sender {
    [self saveBalanceInput:self.balanceField.text];
}

- (void)lingtongChanged:(id)sender {
    [self saveLingtongInput:self.lingtongField.text];
}

- (void)stepsChanged:(id)sender {
    [self saveStepsInput:self.stepsField.text];
}

- (void)contactsChanged:(id)sender {
    [self saveContactsInput:self.contactsField.text];
}

- (void)saveStepsInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.stepsValueString = nil;
    } else {
        NSInteger val = [trimmed integerValue];
        if (val < 0) val = 0;
        if (val > 100000) val = 100000;
        cfg.stepsValueString = [NSString stringWithFormat:@"%ld", (long)val];
    }
}

- (void)saveContactsInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.contactsValue = nil;
    } else {
        NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        if ([trimmed rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
            cfg.contactsValue = trimmed;
        }
    }
}

- (void)saveBalanceInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.balanceValue = nil;
        return;
    }
    NSMutableString *filtered = [NSMutableString string];
    BOOL hasDot = NO;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [filtered appendFormat:@"%C", c];
        } else if (c == '.' && !hasDot) {
            [filtered appendFormat:@"%C", c];
            hasDot = YES;
        }
    }
    cfg.balanceValue = filtered.length ? filtered : nil;
}

- (void)saveLingtongInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.lingtongValue = nil;
        return;
    }
    NSMutableString *filtered = [NSMutableString string];
    BOOL hasDot = NO;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [filtered appendFormat:@"%C", c];
        } else if (c == '.' && !hasDot) {
            [filtered appendFormat:@"%C", c];
            hasDot = YES;
        }
    }
    cfg.lingtongValue = filtered.length ? filtered : nil;
}

@end

#pragma mark - 配置管理（实现）
// DDGlobalConfig 单例：属性 setter 同步 NSUserDefaults。


@implementation DDGlobalConfig

+ (instancetype)shared {
    static DDGlobalConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDGlobalConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        _textEnabled = [def boolForKey:kDDFeatureTextEnabled];
        _imageEnabled = [def boolForKey:kDDFeatureImageEnabled];
        _timeEnabled = [def boolForKey:kDDFeatureTimeEnabled];
        _transferEnabled = [def boolForKey:kDDFeatureTransferEnabled];
        _balanceEnabled = [def boolForKey:kDDFeatureBalanceEnabled];
        _stepsEnabled = [def boolForKey:kDDFeatureStepsEnabled];
        _contactsEnabled = [def boolForKey:kDDFeatureContactsEnabled];
        _friendWxidEnabled = [def boolForKey:kDDFeatureFriendWxidEnabled];
        _wxidEnabled = [def boolForKey:kDDFeatureWxidEnabled];
        _wxidValue = [def stringForKey:kDDFeatureWxidValue] ?: @"";
        _avatarEnabled = [def boolForKey:kDDFeatureAvatarEnabled];
        _hideChatName = [def boolForKey:kDDFeatureHideChatName];

        _stepsValueString = [def stringForKey:kDDStepsValueStringKey];
        _contactsValue = [def stringForKey:kDDContactsCountValueKey];
        _balanceValue = [def stringForKey:kDDBalanceValueKey];
        _lingtongValue = [def stringForKey:kDDLingtongValueKey];
    }
    return self;
}

- (void)setTextEnabled:(BOOL)enabled {
    _textEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTextEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setTransferEnabled:(BOOL)enabled {
    _transferEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTransferEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setImageEnabled:(BOOL)enabled {
    _imageEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureImageEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setTimeEnabled:(BOOL)enabled {
    _timeEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTimeEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setBalanceEnabled:(BOOL)enabled {
    _balanceEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureBalanceEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setStepsEnabled:(BOOL)enabled {
    _stepsEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureStepsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setContactsEnabled:(BOOL)enabled {
    _contactsEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureContactsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setWxidEnabled:(BOOL)wxidEnabled {
    _wxidEnabled = wxidEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:wxidEnabled forKey:kDDFeatureWxidEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setWxidValue:(NSString *)wxidValue {
    _wxidValue = [wxidValue copy];
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_wxidValue.length) {
        [def setObject:_wxidValue forKey:kDDFeatureWxidValue];
    } else {
        [def removeObjectForKey:kDDFeatureWxidValue];
    }
    [def synchronize];
}

- (void)setAvatarEnabled:(BOOL)avatarEnabled {
    _avatarEnabled = avatarEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:avatarEnabled forKey:kDDFeatureAvatarEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setHideChatName:(BOOL)hideChatName {
    _hideChatName = hideChatName;
    [[NSUserDefaults standardUserDefaults] setBool:hideChatName forKey:kDDFeatureHideChatName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)setStepsValueString:(NSString *)stepsValueString {
    _stepsValueString = [stepsValueString copy];
    [self saveSteps];
}

- (void)setContactsValue:(NSString *)contactsValue {
    _contactsValue = [contactsValue copy];
    [self saveContacts];
}

- (void)setBalanceValue:(NSString *)balanceValue {
    _balanceValue = [balanceValue copy];
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_balanceValue.length) {
        [def setObject:_balanceValue forKey:kDDBalanceValueKey];
    } else {
        [def removeObjectForKey:kDDBalanceValueKey];
    }
    [def synchronize];
}

- (void)setLingtongValue:(NSString *)lingtongValue {
    _lingtongValue = [lingtongValue copy];
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_lingtongValue.length) {
        [def setObject:_lingtongValue forKey:kDDLingtongValueKey];
    } else {
        [def removeObjectForKey:kDDLingtongValueKey];
    }
    [def synchronize];
}

- (NSInteger)stepsIntegerValue {
    if (![self hasStepsValue]) return 0;
    return [_stepsValueString integerValue];
}

- (BOOL)hasStepsValue {
    return _stepsValueString.length > 0;
}

- (BOOL)hasContactsValue {
    return _contactsValue.length > 0;
}

- (BOOL)hasBalanceValue {
    return _balanceValue.length > 0;
}

- (BOOL)hasLingtongValue {
    return _lingtongValue.length > 0;
}

- (void)saveSteps {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_stepsValueString.length) {
        [def setObject:_stepsValueString forKey:kDDStepsValueStringKey];
    } else {
        [def removeObjectForKey:kDDStepsValueStringKey];
    }
    [def synchronize];
}

- (void)saveContacts {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_contactsValue.length) {
        [def setObject:_contactsValue forKey:kDDContactsCountValueKey];
    } else {
        [def removeObjectForKey:kDDContactsCountValueKey];
    }
    [def synchronize];
}

@end

#pragma mark - 插件注册
// %ctor 把设置页注册到微信插件入口。


%ctor {
    @autoreleasepool {
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑助手"
                                 version:@"1.0.0"
                              controller:@"DDJokerSettingsViewController"];
    }
}

