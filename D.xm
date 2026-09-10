#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <string.h>     // strcmp（诊断段判断 ivar 类型编码用到）

#pragma mark - 微信类声明

// 微信原生带输入框 alert（头文件证据：WeChat/WCUIAlertView.h）
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

// 微信原生 toast（头文件证据：WeChat/WeToast.h）
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
@property (nonatomic, copy) NSAttributedString *attributedFooterTitle;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadTableView;
@end

// 已在最新 dump 逐条核对：CMessageWrap 只有 IsTextMsg / IsImgMsg / isReferMsgType /
// GetDisplayContent / m_uiMesLocalID / m_nsContent / m_nsFromUsr / m_nsToUsr，
// **没有** m_nsTitle，**没有** m_oWCPayInfoItem（只有 parseWCPayInfoItemIfNeed 这个方法）。
// 因此：引用消息不再改写 m_nsTitle（写了会 unrecognized selector 崩溃）；
// 转账一律用 cell/viewModel 类判断，不再碰任何支付字段。
//（WCPayInfoItem 的声明已整体移除，避免后人误用这些拿不到的属性。）
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

// 重要：这份 dump 把继承链抹成了 NSObject，只列出"本类自己实现"的方法，
// 父类方法不会重复出现在子类里。所以不能在子类头文件里搜不到就判定方法不存在 ——
// messageWrap / resetLayoutCache 实际定义在 BaseMessageViewModel
// （BaseMessageViewModel.h:57 -(id)messageWrap; :78 -(void)resetLayoutCache;），
// CommonMessageViewModel / TextMessageViewModel 靠继承拿到，运行时是能响应的。
@interface BaseMessageViewModel : NSObject
@property (nonatomic, retain) CMessageWrap *messageWrap;
- (void)resetLayoutCache;
@end

@interface CommonMessageViewModel : BaseMessageViewModel
@end

// BaseMessageCellView.h:94 -(void)layoutContentView; :96 -(void)layoutInternal;
//                    :126 -(void)prepareForReuse; :65 -(id)operationMenuItems;
// CommonMessageCellView.h:120 -(void)setViewModel:
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

// 文本消息：真正决定显示文本的是 viewModel 的 contentText（爱锋 hook 点，头文件 TextMessageViewModel.h:23/67）
@interface TextMessageViewModel : CommonMessageViewModel
@property (readonly, nonatomic) NSString *contentText;
- (void)resetLayoutCache;
@end

// 文本最终画在 RichTextView 上，而它是**异步绘制**的（RichTextView.h:120 newAsyncDisplayTask），
// 所以只改 viewModel 数据不会立刻重绘 —— 这正是"改完要退出重进才生效"的根因。
// 必须显式 setContent: + forceDisplayInSync 强制同步重绘，才能改完马上变。
// RichTextView.h:205 -(void)setContent:(id); :156 -(void)calculateAndUpdateFrame;
//              :171 -(void)forceDisplayInSync; :100 -(id)getContent;
@interface RichTextView : UIView
- (id)getContent;
- (void)setContent:(id)content;
- (void)calculateAndUpdateFrame;
- (void)forceDisplayInSync;
@end

@interface TextMessageCellView : CommonMessageCellView
- (id)getRichTextView;     // TextMessageCellView.h:36
- (id)getTextString;       // TextMessageCellView.h:40
- (void)layoutContentView; // TextMessageCellView.h:67
- (void)setViewModel:(id)vm; // TextMessageCellView.h:139
// layoutInternal 由父类提供（CommonMessageCellView.h:78），爱锋就是 hook 它
@end

// 转账：金额走 viewModel 的 titleText/descText（WCPayTransferMessageViewModel.h:29 / :20），
// 改完要主动触发 cell 的 updateTitleLabel/updateDescLabel 才会重画
@interface WCPayTransferMessageViewModel : NSObject
- (CMessageWrap *)messageWrap;   // 继承自 BaseMessageViewModel（BaseMessageViewModel.h -(id) messageWrap;）
- (NSString *)titleText;         // WCPayTransferMessageViewModel.h:29
- (NSString *)descText;          // WCPayTransferMessageViewModel.h:20
@end

@interface WCPayTransferMessageCellView : CommonMessageCellView
- (void)updateTitleLabel;        // WCPayTransferMessageCellView.h:25
- (void)updateDescLabel;         // WCPayTransferMessageCellView.h:23
@end

@interface ImageMessageCellView : CommonMessageCellView
- (void)showImage;                  // ImageMessageCellView.h，微信自身的图片加载/显示入口
- (void)OnDownloadImageOk:(id)a0;   // 异步下载完成后会再次 setImage，必须在这里补一次替换
@end

// 注意：头文件 dump 里没有 AppMessageCellView（只有 AppUrlMessageCellView 等），
// 引用消息（isReferMsgType）实际由 TextMessageCellView 渲染，统一走文本这条链路

// 聊天时间条（对应爱锋"时间小丑"）
// ChatTimeViewModel.h:14 -(id)timeText; :20 -(void)updateLayouts;
// 注意：showingTime(:10) / setShowingTime:(:19) 虽然头文件里有，但改不动时间条，
// 一律走 _showingTime ivar 直接读写（爱锋 @0xccfd8 / @0xcd044 同款，见下方 DDShowingTimeOf 注释）
// ChatTimeCellView.h:5 -(id)initWithViewModel:; :9 -(void)layoutInternal; :13 -(void)setViewModel:
@interface ChatTimeViewModel : BaseMessageViewModel
- (NSString *)timeText;
- (void)updateLayouts;   // ChatTimeViewModel.h:20，改时间后让 viewModel 重算布局
@end

@interface ChatTimeCellView : UIView
- (id)initWithViewModel:(id)vm;
- (void)setViewModel:(id)vm;
- (void)layoutInternal;
// 下面几个是本插件 %new 出来的，先声明以便相互调用（-Werror 下不能有未声明选择器）
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

// 好友数量小丑：对齐爱锋 —— 不 hook MMUILabel（全局 UILabel 复用会误伤/崩溃），
// 而是在数据层 ContactsDataLogic.m_uiNormalContact（unsigned int，ContactsDataLogic.h:58 确认）直接返回自定义值，
// 并可选地同步导航标题。爱锋 hooks_final.json：ContactsDataLogic.m_uiNormalContact @0xc5ae8 /
// ContactsViewController.viewWillAppear: @0xc5d74（真实实现里 updateCustomCountLabel 是死代码，
// 真正驱动"X个朋友"的是 m_uiNormalContact 的返回值，微信自行拼后缀）。
@interface ContactsDataLogic : NSObject
- (unsigned int)m_uiNormalContact;
@end
@interface ContactsViewController : UIViewController
- (void)updateCount;   // ContactsViewController.h:126，重算并刷新“X个朋友”计数显示
@end

// 余额/零钱通详情页的前向声明：每加一个新 %hook 类，都要补一行 @interface 让编译器把 self 视作该类，
// 否则 Logos %hook 会因“no visible @interface ... declares the selector 'viewWillAppear:'”编译失败
// （教训：之前 friendCount 修复就栽过一次，已补 ContactsViewController；这次不能再栽）。
// ScrollNumber.h:140 / WCPayBalanceDetailViewController.h:140 viewWillAppear: 是 UIViewController 自带的方法，
// 声明里一行空方法签名即可，重点是让编译器认得这两个类的存在。
// WCPayBalanceDetailViewController.h 证据链：
//   :14  -(id) balanceTitleLabel;          ← 我的零钱页顶部那个大数字，是 UILabel，不是 ScrollNumber
//   :108 -(void) updateBalanceTitleLabel;  ← 刷新它的入口
//   :71  -(void) refreshViewWithData:(id); ← 数据回来后整体重刷
// ⚠️ 关键结论：整个 dump 里引用 ScrollNumber 的只有 TimeoutNumber.h（付款码倒计时控件），
//    余额大数字从来不走 ScrollNumber —— 之前只强刷 ScrollNumber，对我的零钱/零钱通页完全无效。
//    所以这两个详情页必须走「UILabel 文本改写」这条路。
@interface WCPayBalanceDetailViewController : UIViewController
- (id)balanceTitleLabel;              // :14
- (void)updateBalanceTitleLabel;      // :108
- (void)refreshViewWithData:(id)arg;  // :71
@end

// WCPayLQTDetailViewController.h:121 refreshViewWithData:、:166 viewWillAppear:
// 零钱通详情页没暴露金额 label 属性（主内容由 :89 makeDetailMainContent: 现搭），
// 所以只能靠视图树兜底 + 数据源层 hook 双管齐下。
@interface WCPayLQTDetailViewController : UIViewController
- (void)refreshViewWithData:(id)arg;  // :121
@end

// 零钱通数据源（此前完全没 hook，这是零钱通页一直显示真值的直接原因）
// WCPayLQTInfo.h:16 -(unsigned long long)lqtAvailBalance;  :17 -(unsigned long long)lqtTotalBalance;
@interface WCPayLQTInfo : NSObject
- (unsigned long long)lqtAvailBalance;   // WCPayLQTInfo.h:16
- (unsigned long long)lqtTotalBalance;   // WCPayLQTInfo.h:17
@end

// WCPayLQTDetailControlLogic.h:23 -(long long)lqtBalance;（详情页控制逻辑里另存的一份余额）
@interface WCPayLQTDetailControlLogic : NSObject
- (long long)lqtBalance;                 // WCPayLQTDetailControlLogic.h:23
@end

// WCPayBalanceInfo.h: 服务页顶部"钱包 ¥2.40"读 wallet_balance（getter L28），
// 主页/详情页显示 m_uiAvailableBalance（getter L23）。之前 ScrollNumber 白名单不含服务页，
// 数据源又没 hook，所以服务入口的 ¥2.40 永远显示真实值。这里把数据层 getter 也接管，
// 作为 ScrollNumber hook 的正交双保险 —— 任何视图、任何 VC 读 WCPayBalanceInfo 拿到的都是修改值。
@interface WCPayBalanceInfo : NSObject
- (unsigned long long)wallet_balance;          // WCPayBalanceInfo.h:28  服务入口读这个
- (unsigned long long)m_uiAvailableBalance;    // WCPayBalanceInfo.h:23  主页/详情页读这个
- (unsigned long long)m_uiTotalBalance;        // WCPayBalanceInfo.h:27  备份
@end

// WCPayMainViewControllerV2 服务页（"我"→ 服务 tab）顶层 VC，
// dump 头文件 WCPayMainViewControllerV2.h:1、:115 viewWillAppear:
// ⚠️ dump 里继承被抹成 NSObject，但从 :114 viewDidLoad / :115 viewWillAppear: 看它实际必然是
//    UIViewController 子类。这里声明成 UIViewController，是为了让 [self view] 编译期可见
//    （CI 报过 "no visible @interface ... declares the selector 'view'"）。
//    Logos 的 %hook 是按【类名】在运行时 hook 的，声明的父类不影响 hook 是否生效。
@interface WCPayMainViewControllerV2 : UIViewController
@end

// ⚠️ 关键（用户实机视图层级截图）：名字叫 TimeoutNumber，实机却是【余额大数字的容器】。
//   【我的零钱 ¥2.40】KindaUIView → TimeoutNumber("我的零钱, 2点4 0元") → ScrollNumber
//   【零钱通 ¥0.10】KindaUIView("账户余额 0点1 0元") → TimeoutNumber(", 0点1 0元") → ScrollNumber
// 它是 UIView 子类（:28 layoutSubviews 可证），并在 :18 -(id) scrollNumber; 持有那个 ScrollNumber。
// 微信在数据回来后走它自己的填数方法把 ScrollNumber 写回真值，
// 所以只 hook ScrollNumber 会被它二次覆盖 —— 必须把它这一层也接管。
// 方法签名全部出自 dump 的 TimeoutNumber.h：
//   :27 -(void) defaultNumber:(unsigned long long);
//   :37 -(void) setNoAnimationStart:(unsigned long long);   ← "无动画起点"，就是初始显示值
//   :52 -(void) updateNumber:(unsigned long long);
//   :53 -(void) updateNumberInternal:(unsigned long long);  ← 内部更新数字
@interface TimeoutNumber : UIView
- (void)defaultNumber:(unsigned long long)a0;         // TimeoutNumber.h:27
- (void)setNoAnimationStart:(unsigned long long)a0;   // TimeoutNumber.h:37
- (void)updateNumber:(unsigned long long)a0;          // TimeoutNumber.h:52
- (void)updateNumberInternal:(unsigned long long)a0;  // TimeoutNumber.h:53
- (void)updateScrollNumber;                           // TimeoutNumber.h:54 最终落笔：把内部数字同步到 ScrollNumber
- (void)layoutSubviews;                               // TimeoutNumber.h:28 布局时兜底重绘
- (id)scrollNumber;                                   // TimeoutNumber.h:18
@end

// ScrollNumber.h 确认存在：-(void)updateNumber:(unsigned long long); -(void)defaultNumber:(unsigned long long);
//                          -(unsigned long long)currentNumber; -(unsigned long long)getNumber;
// 注意 isLQT：爱锋 hooks_final.json 里它标记为 "new"，说明那本来就不是微信的 API，
// 而是爱锋自己 %new 出来的判定方法 —— 所以 dump 里搜不到是正常的，我们也自己实现一个。
// 真实父类无法从 dump 确认（继承被抹成 NSObject），可能是 UIView 也可能不是，
// 因此下面凡是走响应链的访问都必须先做 UIResponder 类型检查，否则 nextResponder 会崩。
@interface ScrollNumber : NSObject
// 注：本插件不再 %new isLQT 方法；改用 C 函数 DDBalancePageKindOf（见余额段），先按 VC 类名分流（详情页最稳），主页 KindaViewController 才退回爱锋"附近搜零钱通字样"支。
- (void)updateNumber:(unsigned long long)a0;
- (void)defaultNumber:(unsigned long long)a0;
- (void)setCurrentNumber:(unsigned long long)a0;   // ScrollNumber.h:39，详情页设数字的入口（之前漏掉，导致我的零钱/零钱通详情页只走 %orig 真值）
- (unsigned long long)currentNumber;
@end

// 主页入口卡（"零钱"/"零钱通"/"银行卡"）的数据承载视图 WCPayTableCellViewDataView（WCPayTableCellViewDataView.h:1-67）：
//   - m_title    (UILabel)  卡标题，如"零钱"/"零钱通"/"银行卡"
//   - m_numberView (ScrollNumber 或含 ScrollNumber)  卡右侧金额
//   - m_subTitle  副标题（"收益率 0.95%"等）
// 沿 ScrollNumber superview 上钻找到这个 view，读 m_title 就能精确判定是余额卡 / LQT 卡 / 银行卡卡（银行卡不动）。
// @class 前向声明即可，下面用 NSClassFromString + performSelector 不需要完整接口。
@class WCPayTableCellViewDataView;

#pragma mark - 配置管理（接口声明）

static NSString * const kDDFeatureTextEnabled = @"DDFeatureTextEnabled";
static NSString * const kDDFeatureTransferEnabled = @"DDFeatureTransferEnabled";
static NSString * const kDDFeatureImageEnabled = @"DDFeatureImageEnabled";
static NSString * const kDDFeatureTimeEnabled = @"DDFeatureTimeEnabled";
static NSString * const kDDFeatureBalanceEnabled = @"DDFeatureBalanceEnabled";
static NSString * const kDDFeatureStepsEnabled = @"DDFeatureStepsEnabled";
static NSString * const kDDFeatureContactsEnabled = @"DDFeatureContactsEnabled";
static NSString * const kDDFeatureDiagEnabled = @"DDFeatureDiagEnabled";

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
// 诊断日志开关（默认开）：关掉后所有 DDLOG 直接返回，避免高频 hook 刷爆日志
@property (nonatomic) BOOL diagEnabled;
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

#pragma mark - 通用日志模块 A：采集（所有功能共用）

// 以后改任何功能（文字/图片/时间/转账/步数/好友/余额）都能直接用的日志设施，对外只有四个入口：
//   DDLOG(fmt, ...)        打一条日志（同时进 NSLog 和内存缓冲，设置页可导出）
//   DDJokerHit(@"tag")     记一次 hook 命中（自己会节流，只打前 3 次和每 50 次）
//   DDJokerClearDiagLog()  清空缓冲与命中计数，得到一份只含本次复现的干净日志
//   DDJokerWriteDiagLog()  导出成文件（模块 B 里，设置页「诊断日志」分组调用）
// 内存缓冲按 30 万字符做环形截断，避免聊天页长时间挂着把内存吃满。
// 开关关闭时 DDLOG 直接返回，零开销；命中计数不受开关影响（很便宜，且统计要一直准）。

// strcasestr 在 iOS SDK 里不一定声明（-Werror 下隐式声明直接报错），自己实现一份大小写无关的包含判断
static BOOL DDStringHas(const char *haystack, const char *needle) {
    if (!haystack || !needle || !*needle) return NO;
    NSString *h = [[NSString stringWithUTF8String:haystack] lowercaseString];
    NSString *n = [[NSString stringWithUTF8String:needle] lowercaseString];
    return (h && n) ? ([h rangeOfString:n].location != NSNotFound) : NO;
}

static NSDateFormatter *DDLogTimeFormatter(void) {
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.dateFormat = @"HH:mm:ss.SSS";
    });
    return fmt;
}

static NSMutableString *DDLogBuffer(void) {
    static NSMutableString *buf = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ buf = [NSMutableString string]; });
    return buf;
}

static NSMutableDictionary *DDLogHits(void) {
    static NSMutableDictionary *hits = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ hits = [NSMutableDictionary dictionary]; });
    return hits;
}

static void DDJokerLog(NSString *fmt, ...) {
    if (![DDGlobalConfig shared].diagEnabled) return;
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"%@  %@",
                      [DDLogTimeFormatter() stringFromDate:[NSDate date]], msg];
    NSLog(@"[DD小丑] %@", line);
    NSMutableString *buf = DDLogBuffer();
    @synchronized (buf) {
        [buf appendFormat:@"%@\n", line];
        if (buf.length > 300000) {
            [buf deleteCharactersInRange:NSMakeRange(0, buf.length - 200000)];   // 只留最近 20 万字符
        }
    }
}

#define DDLOG(...) DDJokerLog(__VA_ARGS__)

// 命中计数：计数本身不受诊断开关影响（便宜），只有"打日志"受开关控制。
// timeText 这种每次重绘都走的 hook 只打前 3 次和每 50 次，总次数留到导出时一次性列出。
static void DDJokerHit(NSString *tag) {
    NSMutableDictionary *hits = DDLogHits();
    NSInteger n = 0;
    @synchronized (hits) {
        n = [hits[tag] integerValue] + 1;
        hits[tag] = @(n);
    }
    if (n <= 3 || n % 50 == 0) DDLOG(@"HIT %@ 第 %ld 次", tag, (long)n);
}

// 导出前先清空，可以得到一份"只含本次复现步骤"的干净日志
static void DDJokerClearDiagLog(void) {
    NSMutableString *buf = DDLogBuffer();
    @synchronized (buf) { [buf setString:@""]; }
    NSMutableDictionary *hits = DDLogHits();
    @synchronized (hits) { [hits removeAllObjects]; }
}

static NSString *DDJokerDescribeHitStats(void) {
    NSMutableDictionary *hits = DDLogHits();
    if (!hits.count) return @"  (还没有任何 hook 被触发)\n";
    NSMutableString *s = [NSMutableString string];
    for (NSString *k in [[hits allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        // 用 %@ 而不是 %s：NSString 的 %s 按系统编码解释字节，中文 key 会变成乱码（导出日志里已出现过）
        [s appendFormat:@"  %@ : %@ 次\n", k, hits[k]];
    }
    return s;
}

#pragma mark - ① 聊天文字/图片/转账修改

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

// 引用消息（type 57 appmsg）的 GetDisplayContent 返回的是原始 XML 碎片
// （<msg><appmsg><title>...</title><refermsg>...），直接回填输入框会全是 < > " 这类像正则的字符。
// 真正显示在气泡里的回复正文其实是 <appmsg><title>，这里把它解析出来作为预填/还原文本。
// 还原 XML/HTML 实体（引用标题里偶尔会被编码，例如回复正文含 < > & 等字符）
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

// 引用消息（type 57 appmsg）的 GetDisplayContent 返回原始 XML 碎片，回填输入框会一团乱；
// 真正显示在气泡里的回复正文就是 <appmsg><title>。引用消息 XML 里 <title> 只此一处
// （被引用内容在 <refermsg> 里用的是 <content>/<msgtitle>，不是 <title>，见上传样本），
// 所以用一条正则一次性精确捕获 <title ...>内容</title ...>，无需一堆 if 兜底。
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

// 已删除 JokerIsTransferMessage(msg)：CMessageWrap.h 里没有 m_oWCPayInfoItem
// （只有 :572 parseWCPayInfoItemIfNeed），那个判定在真机上恒为 NO，
// 用它会导致"金额改了没反应"和"点小丑不弹窗"。转账一律按下面的类判定。

// 判断转账的唯一可靠依据：cell 的类（不依赖任何支付字段）
static BOOL JokerIsTransferCell(CommonMessageCellView *cell) {
    return [cell isKindOfClass:%c(WCPayTransferMessageCellView)];
}

// 注意：必须用 cell 判定，不能用 msg 判定 —— 转账消息在 CMessageWrap 上没有任何可用标记
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
    // 转账金额：不带小数点的纯数字，自动补 .00（如 666 -> 666.00）；
    // 含小数点（666.5 / 666.）的保持原样，由微信按原始精度渲染
    if ([filtered rangeOfString:@"."].location == NSNotFound) {
        [filtered appendString:@".00"];
    }
    return filtered;
}

static NSString * const kDDJokerTextCacheKey = @"DDJokerTextCache";
static NSString * const kDDJokerAmountCacheKey = @"DDJokerAmountCache";
static NSString * const kDDJokerTimeCacheKey = @"DDJokerTimeCache";
// 文本/引用消息的原始 m_nsContent 备份（对齐爱锋 entry 里的 originalText，@0xccbb8）。
// 改文字会写回 CMessageWrap，没有这份备份就还原不回去 —— 清理缓存时它必须保留。
static NSString * const kDDJokerTextOriginalKey = @"DDJokerTextOriginal";

static NSString *DDJokerMessageKey(CMessageWrap *msg) {
    return [NSString stringWithFormat:@"%u", msg.m_uiMesLocalID];
}

// —— 自定义 plist 持久化层（替代 NSUserDefaults）——
// 越狱 tweak 注入 dylib 后，[NSUserDefaults standardUserDefaults] 的默认域在微信重启后常常落空/被微信
// 自身初始化清空，导致"重启后改过的时间/文字/金额全变回真实值"。日志实证：同一会话内 cache 命中正常
// （timeText 打印 缓存=1757347260），但重新打开微信后首屏 00:41:44 三条时间条全是 缓存=无。
// 改成自己管理 plist 文件（写在微信沙盒 Library/Caches/DDJoker/ 下），绕开 NSUserDefaults 的不确定性，
// 重启后照样在磁盘上，下次进来能恢复。
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

// 原始文案备份：只在第一次见到这条消息时记录（那时 m_nsContent 还没被改写）
static NSString *DDJokerOriginalText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerTextOriginalKey);
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetOriginalText(CMessageWrap *msg, NSString *text) {
    if (!msg || !text.length) return;
    if (DDJokerOriginalText(msg)) return;   // 已备份过就不再更新，否则会把改后的内容当成原始
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerTextOriginalKey);
    d[DDJokerMessageKey(msg)] = text;
    DDJokerSaveCache(kDDJokerTextOriginalKey, d);
}

static NSString *DDJokerCachedAmount(CMessageWrap *msg) {
    if (!msg) return nil;
    NSDictionary *d = DDJokerLoadCache(kDDJokerAmountCacheKey);
    NSString *v = d[DDJokerMessageKey(msg)];
    return v.length ? v : nil;
}

static void DDJokerSetCachedAmount(CMessageWrap *msg, NSString *amount) {
    if (!msg) return;
    NSMutableDictionary *d = DDJokerLoadCache(kDDJokerAmountCacheKey);
    if (amount.length) d[DDJokerMessageKey(msg)] = amount;
    else [d removeObjectForKey:DDJokerMessageKey(msg)];
    DDJokerSaveCache(kDDJokerAmountCacheKey, d);
}

#pragma mark - ①c 聊天时间修改缓存

// 爱锋 DKWriteShowingTime @0xccfd8 / DKRawShowingTime @0xcd044 都是直接读写 vm 的 ivar：
//   class_getInstanceVariable(cls, "_showingTime") @0xcd008 / @0xcd06c
//   → ivar_getOffset → str/ldr d8, [x19, x0]（@0xcd014 写 / @0xcd078 读）
// 全程不走 setShowingTime: —— 实测 setter 改不动时间条的显示，必须直接改 ivar 才生效。
// （_showingTime 这个 ivar 名来自反汇编里 class_getInstanceVariable 的实参字符串 @0x114f19）
// 先按名字精确找 _showingTime；找不到就退回模糊匹配（真身名字可能随版本变了），
// 实在找不到返回 NULL —— 这种情况导出日志里的 ivar 列表会直接给出正确答案。
static Ivar DDShowingTimeIvarOf(id vm) {
    if (!vm) return NULL;
    Class cls = [vm class];
    Ivar iv = class_getInstanceVariable(cls, "_showingTime");
    if (iv) return iv;
    // 沿父类链找"名字里带 showingtime 的 double ivar"
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

// 改完 showingTime 让微信重算：updateLayouts 会按新的 showingTime 重新生成 m_timeText
// （导出日志实证：写 ivar → updateLayouts → timeText 立刻返回新时间的文本）。
// 千万不要手动把 m_timeText 置 nil：日志里出现过清掉后微信补不上、timeText 返回 (null)
// 导致时间条空白 20 秒的情况；而 updateLayouts 本身就会重算，清缓存属于多余且有风险。
static void DDRefreshTimeText(id vm) {
    [(ChatTimeViewModel *)vm updateLayouts];   // ChatTimeViewModel.h:20
}

// 时间条没有消息身份时，只能用 showingTime 当 key。但我们改时间会直接改写这个 ivar，
// 它一变 key 就漂移到新值，下次读到空缓存 → 弹回真实时间（这是之前"改了没反应"的根因之一）。
// 对齐爱锋 DKRawShowingTime @0xcd044：记住这条时间条的"原始 showingTime"，
// 首次读取时（此时还没被改写）记下来，之后一律用原始值算 key，key 就不再漂移。
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

// 时间条（ChatTimeViewModel）可能绑定消息，也可能只是个纯时间分隔条。
// 爱锋同样是优先用消息 ID（wechatku.dylib @0xcb650 / DKPersistentKeyForTimeModel @0xcce10）：
//   有消息 → "time_" + 消息 key；拿不到消息才退回 "time_timestamp_%.3f"。
// 这里沿用同样的优先级，但复用插件统一的消息 key，方便"清除修改缓存"一次清干净。
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

// 把"缓存的修改时间"写进 showingTime 的 ivar：开关开 + 该条有缓存 + 当前不是修改值才写。
// 在【布局通路之外】调用（didMoveToWindow 的 dispatch_async）才会让微信按新值重算 m_timeText；
// 在布局通路内（首帧 layout / updateLayouts / layoutInternal 钩子里）调用只改 ivar、不触发重绘，属兜底。
static void DDApplyTimeOverride(id vm) {
    if (!vm || ![DDGlobalConfig shared].timeEnabled) return;
    NSNumber *cached = DDJokerCachedTime(vm);
    if (cached && DDShowingTimeOf(vm) != [cached doubleValue]) {
        DDSetShowingTime(vm, [cached doubleValue]);
    }
}

static void DDJokerClearAllMessageCache(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    // 文字/金额/时间覆盖值：随聊天内容刷新，清掉无妨
    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerTextCacheKey) error:nil];
    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerAmountCacheKey) error:nil];
    [fm removeItemAtPath:DDJokerCacheFile(kDDJokerTimeCacheKey) error:nil];
    // kDDJokerTextOriginalKey 故意保留：文字走数据层后 m_nsContent 已被改写，
    // 清掉覆盖值后要靠这份原始备份才能写回还原（爱锋的 originalText 同样是持久化的）。
    [fm removeItemAtPath:DDJokerImagesDir() error:nil];
}

// 导出日志时用的"最近一条时间条"：弱引用，vm 被释放自动置 nil，不会延长生命周期
static __weak id gDDLastTimeVM = nil;

static NSString *DDTimeDesc(double ts) {
    if (ts <= 0) return @"0 (无效)";
    return [NSString stringWithFormat:@"%.3f  %@", ts, [NSDate dateWithTimeIntervalSince1970:ts]];
}

// iOS 15+ 起 UIApplication.windows 已废弃，改用 UIWindowScene.windows（按 iOS 18 编译，不做低版本判断）
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

// 遍历所有 window 的整棵 VC 树：聊天页与插件设置页处在不同导航栈，
// 只查 keyWindow 的 nav.viewControllers 是找不到 BaseMsgContentViewController 的
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

// 关键：微信聊天页里 [tableView visibleCells] 返回的是 UITableViewCell，
// 而 ImageMessageCellView / TextMessageCellView 是挂在 cell.contentView 上的 UIView，
// 直接对 visibleCells 判 isKindOfClass 永远匹配不到 —— 必须递归往子里找。
static void DDCollectViewsOfClass(UIView *root, Class cls, NSMutableArray *out) {
    if (!root) return;
    if ([root isKindOfClass:cls]) {
        if (![out containsObject:root]) [out addObject:root];
        return;   // 命中即停，避免把子层同名 view 也收进来
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

// 图片：重走微信自己的加载流程，替换图才会落到 imageView 上
static void JokerRefreshVisibleImageCells(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if (![tv isKindOfClass:[UITableView class]]) continue;
        for (ImageMessageCellView *cellView in DDVisibleCellViewsOfClass(tv, %c(ImageMessageCellView))) {
            if ([cellView respondsToSelector:@selector(showImage)]) [cellView showImage];
        }
    }
}

// 输入框回填要显示"当前正在显示的内容"，所以优先取缓存值。
// 转账金额不再从 WCPayInfoItem 读（新版本拿不到），直接用缓存值回填
static NSString *DDTransferFeedescAmount(NSString *xml);  // 前向声明：从 m_nsContent 解析原始转账金额
static NSString *JokerGetDisplayText(CMessageWrap *msg, BOOL isTransfer) {
    if (isTransfer) {
        NSString *cached = DDJokerCachedAmount(msg);
        if (cached.length) return cached;                            // 已修改 → 显示修改后的金额
        NSString *raw = DDTransferFeedescAmount([msg m_nsContent]);  // 未修改 → 真实金额
        return JokerNormalizeAmount(raw) ?: @"";                     // 去掉 ¥，与缓存格式统一
    }
    NSString *cached = DDJokerCachedText(msg);
    if (cached) return cached;
    // 引用消息的 GetDisplayContent 是原始 XML 碎片（像正则），回填输入框会一团乱，
    // 改成取 <title>（即气泡里真正显示的回复正文），与 %orig 的 contentText 显示一致
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

// 富文本是异步绘制的（RichTextView.h:120 newAsyncDisplayTask），改完数据不会自动重绘 ——
// 必须显式 setContent: + forceDisplayInSync，否则要等 cell 复用/重进页面才看得到变化。
static void JokerApplyTextToRichView(id richView, NSString *text) {
    if (!richView || !text) return;
    [richView setContent:text];
    [richView calculateAndUpdateFrame];
    [richView forceDisplayInSync];
    [richView setNeedsDisplay];
}

// TextMessageViewModel 把 contentText 懒加载缓存进 ivar，不清就一直返回旧值，
// 这正是"改完要退出重进才生效"的根因（resetLayoutCache 见 BaseMessageViewModel.h:78）
static void JokerResetViewModelCache(CommonMessageCellView *cell) {
    id vm = cell.viewModel;
    [vm resetLayoutCache];
}

// 与爱锋一致：不依赖 tableView reload，而是直接触发 cell 自身的显示/布局流程
static void JokerRefreshCellDirectly(CommonMessageCellView *cell) {
    if (!cell) return;
    JokerResetViewModelCache(cell);
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);

    if ([cell isKindOfClass:%c(TextMessageCellView)]) {
        NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;
        // 没有缓存（关开关 / 清过缓存）就还原成原文，否则关掉修改后文字变不回去
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
        // 金额是在这两个方法里落到 label 上的，只 layout 不够
        [(WCPayTransferMessageCellView *)cell updateTitleLabel];
        [(WCPayTransferMessageCellView *)cell updateDescLabel];
    } else if ([cell isKindOfClass:%c(ImageMessageCellView)]) {
        [(ImageMessageCellView *)cell showImage];
    }
    [cell setNeedsLayout];
}

// 提前声明：JokerInvalidateAllLayout 的定义在下方（依赖 gJokerNeedsResetLayout），
// 但本函数及多处开关回调在定义之前就会调用它，static 函数必须先声明后使用
static void JokerInvalidateAllLayout(void);

static void JokerReloadCellAfterReplace(id vc, CMessageWrap *msg, CommonMessageCellView *cell) {
    JokerRefreshCellDirectly(cell);
    UITableView *tv = cell ? JokerFindTableView((UIView *)cell) : nil;
    if (![tv isKindOfClass:[UITableView class]] && [vc isKindOfClass:%c(BaseMsgContentViewController)]) {
        tv = [(BaseMsgContentViewController *)vc getMsgTableView];
    }
    if (![tv isKindOfClass:[UITableView class]]) {
        // 拿不到 tableView 就退化为全局刷新，避免"改了没反应、要重进才生效"
        JokerReloadAllMsgContent();
        return;
    }
    // cell 是挂在 UITableViewCell.contentView 上的 UIView，直接传给 indexPathForCell:
    // 永远返回 nil（类型都不对），只能靠全局刷新兜底 —— 改成按中心点换算 indexPath
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
    // 用 cell 判定，不能用 msg 判定：转账消息在 CMessageWrap 上没有任何可用标记，
    // 用 JokerIsSupportedMessage(msg) 会把转账直接拦掉 —— 表现为"点小丑没弹窗"
    if (!JokerIsSupportedCell(cell)) return;
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    id vc = JokerGetViewControllerFromView(cell);   // 取不到也不影响弹窗，只影响兜底刷新

    // 转账用 cell 类型判断，不依赖 CMessageWrap 的支付字段（新 dump 已无 m_oWCPayInfoItem）
    BOOL isTransfer = JokerIsTransferCell(cell);
    NSString *current = JokerGetDisplayText(msg, isTransfer);

    // 微信原生带输入框 alert：WCUIAlertView（声明见文件顶部）。标题按类型区分，
    // 副标题给出输入指引（金额/文字），输入框本身不放 placeholder —— 默认文本已经是当前值
    NSString *editorTitle = isTransfer ? @"转账修改" : @"文字修改";
    NSString *editorMessage = isTransfer ? @"请输入需要修改的金额\n留空还原" : @"请输入需要修改的文字\n留空还原";
    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:editorTitle message:editorMessage];
    if (!alert) return;
    [alert showTextFieldWithMaxLen:1000];
    [alert setTextFieldDefaultText:current];

    // 注意两点（都踩过坑）：
    // 1) 不能用 __weak 引用 alert —— 回调触发时它可能已释放，nil 会让修改静默失效；
    // 2) 不能在 show 之前判断 getTextField 为空就 return —— 那会让弹窗根本不显示。
    // 所以：alert 与输入框都强引用，取文本时两条路径都试。
    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{}];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;
        NSString *newText = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newText.length) {
            if ([newText isEqualToString:current]) { blockAlert = nil; return; }   // 没改动
            if (isTransfer) {
                NSString *normalized = JokerNormalizeAmount(newText);
                if (normalized) DDJokerSetCachedAmount(msg, normalized);
            } else {
                DDJokerSetCachedText(msg, newText);
            }
            JokerReloadCellAfterReplace(vc, msg, cell);
        } else if (isTransfer ? DDJokerCachedAmount(msg) : DDJokerCachedText(msg)) {
            // 留空 = 还原：清掉这条消息的覆盖值，立即回到原始内容。
            // 转账走显示层，清了缓存 vm 重算 titleText 就是真实金额；
            // 文字走数据层，DDJokerApplyTextOverride 会用 DDJokerTextOriginal 里的备份写回 m_nsContent。
            if (isTransfer) DDJokerSetCachedAmount(msg, nil);
            else DDJokerSetCachedText(msg, nil);
            JokerReloadCellAfterReplace(vc, msg, cell);
        }
        blockAlert = nil;   // 打破 alert -> handler -> alert 的保留环
    }];
    [alert show];
    UITextField *tf = [alert getTextField];   // show 之后输入框一定已创建
    if (tf) {
        inputField = tf;
        if (isTransfer) tf.keyboardType = UIKeyboardTypeDecimalPad;
    }
}

static NSArray *JokerInjectMenuItem(CommonMessageCellView *cell, NSArray *original) {
    // 一律用 cell 判定：CMessageWrap 上没有任何可用的转账标记，
    // 用 msg 判定会让转账消息既拿不到菜单、也弹不出修改框
    if (!JokerEnabledForCell(cell)) return original;
    if (!JokerIsSupportedCell(cell)) return original;

    UIImage *icon = [[UIImage systemImageNamed:@"face.smiling.fill"] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *newItem = [(MMMenuItem *)[%c(MMMenuItem) alloc] initWithTitle:@"小丑" icon:icon target:cell action:@selector(joker_handleMenuItem:)];
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}

// 真正决定文本显示的是 viewModel 的 contentText（TextMessageViewModel.h:23）。
// 现在按爱锋 DKApplyTextOverrideToModel @0xccb08 的做法叠加数据层：
//   ① 在 contentText 取值那一刻改 m_nsContent（@0xccbfc setM_nsContent:），再让微信按新值自己算；
//   ② 缓存里有值就直接返回（爱锋 @0xba1b4~0xba1f0 读 entry[@"text"] 后直接返回），气泡显示不依赖 XML；
//   ③ 没覆盖值（关开关 / 清过缓存）就用 originalText 备份写回（@0xccbb8），保证还原得回去。
// 与爱锋一致不区分消息类型：引用消息的 m_nsContent 是 XML，也会被整段换成纯文本。
// 注意时序——只在 getter 里改才生效；之前在 cell 的 setViewModel: 里改，文本早算完了，白改还污染 model。
static void DDJokerApplyTextOverride(CMessageWrap *msg) {
    if (!msg) return;
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;
    NSString *original = DDJokerOriginalText(msg);
    if (!original.length) {
        DDJokerSetOriginalText(msg, msg.m_nsContent);   // 首次见到：此时还没被改写，存下来当原始
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
    DDJokerApplyTextOverride(self.messageWrap);   // 爱锋 @0xba15c：先改 model 再取 %orig
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    CMessageWrap *msg = self.messageWrap;
    // 引用消息（isReferMsgType）同样由 TextMessageCellView 渲染，走同一条替换链路
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
%end

// 清理缓存/切换开关后需要强制清掉 viewModel 里已算好的 contentText 布局缓存，否则仍显示旧文本
static BOOL gJokerNeedsResetLayout = NO;

// 开关切换、清理缓存都走这里：置位 → 全量重绘 → 稍后复位。
// 置位期间 TextMessageCellView 的 setViewModel: 才主动清懒加载缓存，文字才还原得回去。
static void JokerInvalidateAllLayout(void) {
    gJokerNeedsResetLayout = YES;
    JokerReloadAllMsgContent();
    JokerRefreshVisibleImageCells();   // 图片走的是 setImage，需触发微信重新加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gJokerNeedsResetLayout = NO;
    });
}

%hook TextMessageCellView
// 之前这里在 %orig 前临时改 m_nsContent、%orig 后又立刻还原，而真正的文本计算发生在
// 之后的 layoutContentView，所以那段改写完全无效，还白白污染了一次 CMessageWrap。
// 正确做法：%orig 之后清掉 viewModel 的懒加载缓存，等布局重新取 contentText 时就会拿到替换值。
- (void)setViewModel:(id)vm {
    %orig;
    if (![vm respondsToSelector:@selector(resetLayoutCache)]) return;
    CMessageWrap *msg = [(CommonMessageViewModel *)vm messageWrap];
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;
    // 开启且有缓存 → 清缓存让替换值生效；关闭 → 也清一次让原文还原回去
    if (gJokerNeedsResetLayout || DDJokerCachedText(msg) || ![DDGlobalConfig shared].textEnabled) {
        [(TextMessageViewModel *)vm resetLayoutCache];
    }
}
- (id)getTextString {
    CMessageWrap *msg = JokerGetMessageWrapFromCell(self);
    DDJokerApplyTextOverride(msg);   // 爱锋 @0xbcb80：getTextString 里同样先改 model，复制/转发取到的是改后文本
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

// 转账金额走显示层覆盖：只改 viewModel 吐给 label 的文本，绝不回写 m_nsContent。
// 之前的数据层方案（把覆盖金额写回 CMessageWrap.m_nsContent，CMessageWrap.h:676 setM_nsContent:）
// 会被微信持久化进消息 DB，表现为"清理缓存后重启微信，金额仍是修改后的、还原不回去"。
// 与文字修改同一套路：hook WCPayTransferMessageViewModel 的 titleText/descText（头文件 :29 / :20），
// 只在文本里精准替换金额那一段，CMessageWrap 保持原样 —— 清理缓存后重算即还原真实金额。
// 从转账 m_nsContent 的 <feedesc><![CDATA[金额]]></feedesc> 里解析出真实金额（如 ¥888.88），
// 仅用于弹窗预填（未修改时显示真实金额），不参与渲染。
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
// 金额在标题/描述文本里就是一段"¥数字"（可能带小数），正则一次命中整段替换，其余字符原样保留。
// 缓存里的金额已由 JokerNormalizeAmount 归一为纯数字（补 .00、去 ¥），这里统一补回 ¥ 前缀。
static NSString *DDTransferReplaceAmountInText(NSString *text, NSString *override) {
    if (!text.length || !override.length) return text;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"¥?\\d+(?:\\.\\d+)?"
                                                                        options:0
                                                                          error:nil];
    if (!re) return text;
    NSString *newAmount = [@"¥" stringByAppendingString:override];
    return [re stringByReplacingMatchesInString:text
                                       options:0
                                         range:NSMakeRange(0, text.length)
                                  withTemplate:newAmount];
}

%hook WCPayTransferMessageCellView
// 渲染时不需要在这里做任何事：金额由 WCPayTransferMessageViewModel 的 titleText/descText 覆盖，
// 这里只负责把"小丑"菜单注入转账气泡。
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    // 本 hook 就挂在 WCPayTransferMessageCellView 上，天然是转账 cell，直接用开关判定
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

// 转账金额显示层覆盖（对齐文字修改的 contentText hook 套路）：
// titleText 是气泡上的金额大字（WCPayTransferMessageViewModel.h:29），
// descText 是"已收款/已退款"等说明（同文件 :20，退款类文案同样带金额）。
// vm 继承自 BaseMessageViewModel，messageWrap 可用（BaseMessageViewModel.h 的 -(id) messageWrap;）——
// 现有 JokerGetMessageWrapFromCell 在转账 cell 上已实测拿到 msg，即 runtime 证据。
// 命中的是金额正则段，文本里没有金额时原样返回。
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

#pragma mark - ①b 聊天图片修改

// 聊天图片替换用 Apple UIImagePickerController：
// 爱锋 DKChatImagePickerDelegate 反汇编（@0xa59cc）证实聊天图片替换走
// imagePickerController:didFinishPickingMediaWithInfo: + UIImagePickerControllerOriginalImage，
// 与下方实现一致，故回退到这条被证实可用的路径（原生 MMImagePickerController 直接 present 会闪退）。
@interface DDWeChatImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) unsigned int mesLocalID;
@property (nonatomic, weak) id cellView;   // 对齐爱锋：[self cell] 直接持有要替换的 ImageMessageCellView
@end

static NSString *DDImageReplacementPath(unsigned int mesLocalID) {
    NSString *folder = DDJokerImagesDir();
    return [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%u.png", mesLocalID]];
}

static UIImage *DDImageReplacementForMessage(CMessageWrap *msg) {
    if (!msg || ![msg IsImgMsg]) return nil;
    NSString *path = DDImageReplacementPath(msg.m_uiMesLocalID);
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    return [UIImage imageWithContentsOfFile:path];
}

// 最新 dump 不含 ivar 信息，无法确认 m_imageView 是否还在。
// 直接 valueForKey: 一旦 key 不存在会抛 NSUnknownKeyException 让微信崩溃，
// 所以先用 class_getInstanceVariable 探测，取不到再退化为按面积找最大的 UIImageView
static UIImageView *DDImageViewFromCell(UIView *cell) {
    if (!cell) return nil;
    Ivar ivar = class_getInstanceVariable([cell class], "m_imageView");
    if (ivar) {
        id value = object_getIvar(cell, ivar);
        if ([value isKindOfClass:[UIImageView class]]) return (UIImageView *)value;
    }
    UIImageView *best = nil;
    CGFloat bestArea = 0;
    for (UIView *v in cell.subviews) {
        if (![v isKindOfClass:[UIImageView class]]) continue;
        CGFloat area = v.bounds.size.width * v.bounds.size.height;
        if (area > bestArea) { bestArea = area; best = (UIImageView *)v; }
    }
    return best;
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
    delegate.mesLocalID = msg.m_uiMesLocalID;
    delegate.cellView = self;   // 对齐爱锋：delegate 直接持有 cell，dismiss 后无需递归查找
    picker.delegate = delegate;
    // 强引用 delegate：picker 不持有外部 delegate，避免回调时已被释放
    objc_setAssociatedObject(picker, "dd_picker_delegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [vc presentViewController:picker animated:YES completion:nil];
}
- (void)showImage {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)OnDownloadImageOk:(id)a0 {
    // 微信异步下载完成后会再次 setImage 覆盖掉替换图，必须在这里补一次
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)layoutContentView {
    %orig;
    DDImageApplyReplacementToCell(self);
}
%end

@implementation DDWeChatImagePickerDelegate

#pragma mark - Apple 系统相册（爱锋聊天图片替换同款）
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) [self dd_saveImage:image dismissPicker:picker];
    else [picker dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)dd_saveImage:(UIImage *)image dismissPicker:(UIImagePickerController *)picker {
    NSString *path = DDImageReplacementPath(self.mesLocalID);
    NSData *data = UIImagePNGRepresentation(image);
    if (!data) { [picker dismissViewControllerAnimated:YES completion:nil]; return; }
    [data writeToFile:path atomically:YES];

    // 对齐爱锋 DKChatImagePickerDelegate（@0xa59cc）：delegate 直接持有 cell（[self cell]），
    // 在 dismiss 之前【同步】刷新，dismiss 的 completion 为 nil，不屏蔽交互、不调 showImage
    // （showImage 的 %orig 会打开微信图片预览——之前"选完图预览被打开"正是这里触发；
    //  爱锋用 updateLayouts+setNeedsLayout 刷新，从不调 showImage）。
    // DD 的替换图应用集中在 DDImageApplyReplacementToCell（直接 setImage 到内部 imageView），
    // 等价于爱锋 updateLayouts 做的事；setNeedsLayout 对齐爱锋的 cell 级刷新。
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

#pragma mark - ①c 聊天时间修改

static char kDDTimeVMKey;

// 时间条的显示格式一律由微信原生 timeText 决定，本插件不再自创任何格式串
// （曾经自己拼过"今天 HH:mm"，而微信当天只显示"15:56"，与原生不一致 —— 已彻底移除）。
// 这里只保留弹窗的输入/解析格式：用户按 yyyy-MM-dd HH:mm 输入，en_US_POSIX 保证
// 改了 12/24 小时制或地区后仍能解析（爱锋 timestampFromDateString: @0xbaf30 同款）。
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

// 时间条显示的就是 viewModel 的 timeText（ChatTimeViewModel.h:14）：
// 本插件只负责把 showingTime 改成目标时间戳，显示文本与格式全部由微信原生实现给出。
%hook ChatTimeViewModel
- (NSString *)timeText {
    gDDLastTimeVM = self;   // 供设置页导出日志时取"最近一条时间条"（导出时会顺带 dump 它的类结构）

    // 先取一次原始 showingTime：首次调用时它还没被改写，正好把 key 钉在原始值上
    double raw = DDRawShowingTimeOf(self);
    NSNumber *cached = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(self) : nil;
    double target = cached ? [cached doubleValue] : raw;   // 没覆盖值时目标是原始时间（顺带完成还原）

    // showingTime 不是目标值就写进去，再让微信按新值重算 m_timeText。
    // 关开关 / 清缓存时 target 就是原始值，同一段逻辑顺带把显示还原回真实时间。
    if (target > 0 && DDShowingTimeOf(self) != target) {
        DDSetShowingTime(self, target);
        DDRefreshTimeText(self);
    }

    // 格式完全交给微信原生实现：今天只显示"15:56"、昨天"昨天 15:56"、更早带日期，
    // 全都由微信自己的分档规则决定。之前自己拼"今天 HH:mm"与原生不一致，现已不再自创格式。
    NSString *o = %orig;
    if (!o && cached) {
        // 日志实证（DDJokerDiag-2.log 00:20:45）：新建的 vm 上 updateLayouts 没能把 m_timeText 算出来，
        // 微信就返回 nil，界面上表现为时间条空白。这里不自创文本填补（避免和原生日历口径不一致），
        // 只留一条醒目标记，下次导出日志一眼能看出是"微信没算出来"还是"我们没写进去"。
    }
    return o;
}
// 改时间后微信重算时间条就走这里，打出来才能确认"改了没反应"到底卡在哪一步
- (void)updateLayouts {
    %orig;
}
%end

%hook ChatTimeCellView
- (id)initWithViewModel:(id)vm {
    id r = %orig;
    // vm 先存起来：弹窗时要用它读 showingTime 和写缓存
    objc_setAssociatedObject(r, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [(ChatTimeCellView *)r dk_installTimeEditGesture];
    return r;
}
- (void)setViewModel:(id)vm {
    %orig;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self dk_installTimeEditGesture];
}
- (void)layoutInternal {
    %orig;
}
// 微信时间条有第二种显示：点一下时间条会切出带日期的完整时间（ChatTimeCellView.h:11 onClickTimeLabel）。
// 两种格式都由同一个 showingTime 推导，所以我们改 showingTime 后两者会同步变化，无需单独处理。
// 长按手势装在 label 上，而 label 可能晚于 init 才创建，cell 复用时也会换，
// 决定性修复落点：把编辑路径（长按弹窗确定后那套 setShowingTime+updateLayouts+layoutInternal+setNeedsLayout）
// 延到【布局通路之外】执行。日志实证：微信只在布局通路之外被调 updateLayouts 时才会用修改值重算 m_timeText；
// 首帧 layout / 布局通路内的 updateLayouts（initWithViewModel、layoutInternal、timeText 钩子里调用的那次）
// 一律不重算，导致重进聊天页普通时间条显示真实时间、要等点一下才变——点一下正好触发了布局通路外的重排。
- (void)didMoveToWindow {
    %orig;
    [self dk_installTimeEditGesture];
    if (!self.window) return;
    id vm = objc_getAssociatedObject(self, &kDDTimeVMKey);
    if (!vm) return;
    NSNumber *cached = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(vm) : nil;
    if (!cached) return;   // 无覆盖的时间条零开销，普通聊天气泡不受影响
    // didMoveToWindow 可能仍落在微信当前布局周期内，故用 dispatch_async(main) 把重排推到布局通路之外，
    // 与编辑路径（弹窗确定回调里同步重排）等价 → 首帧即显示修改时间。
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;
        id v = objc_getAssociatedObject(self, &kDDTimeVMKey);
        if (!v) return;
        NSNumber *c = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(v) : nil;
        if (!c) return;
        DDApplyTimeOverride(v);
        DDRefreshTimeText(v);                 // [vm updateLayouts] —— 布局通路外重算 m_timeText（编辑路径实证生效）
        [(ChatTimeCellView *)self layoutInternal];
        [self setNeedsLayout];
    });
}
%new
- (UILabel *)dk_timeLabel {
    // 爱锋 @0xbac08 也是先试 ivar m_timeLabel，取不到再退化为遍历
    Ivar iv = class_getInstanceVariable([self class], "m_timeLabel");
    if (iv) {
        id v = object_getIvar(self, iv);
        if ([v isKindOfClass:[UILabel class]]) return (UILabel *)v;
    }
    NSMutableArray *q = [NSMutableArray arrayWithObject:self];
    for (NSUInteger i = 0; i < q.count && i < 40; i++) {
        UIView *v = q[i];
        // 日志实证（DDJokerDiag-2.log）：m_timeLabel 的 text 恒为 nil，微信时间条走的是 attributedText。
        // 所以这里不能只看 text，否则退化遍历时会把真正的时间 label 漏掉、手势装到别的 label 上。
        if (v != (UIView *)self && [v isKindOfClass:[UILabel class]] &&
            (((UILabel *)v).text.length || ((UILabel *)v).attributedText.length)) {
            return (UILabel *)v;
        }
        for (UIView *s in v.subviews) [q addObject:s];
    }
    return nil;
}
%new
- (void)dk_installTimeEditGesture {
    if (![DDGlobalConfig shared].timeEnabled) return;
    UILabel *label = [self dk_timeLabel];
    if (!label) return;   // 找不到 label 长按就永远不弹窗
    for (UIGestureRecognizer *g in label.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) return;   // 幂等，不重复装
    }
    label.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleTimeLongPress:)];
    lp.minimumPressDuration = 0.5;      // 爱锋 @0xbada4 同为 0.5 秒
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

    // 与爱锋一致：微信原生 WCUIAlertView，标题/提示文案都沿用它的（@0xbb174 / @0x6287e8 / @0x628828）
    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:@"时间修改"
                                                                           message:@"输入格式如下\n2024-08-01 22:30\n留空还原"];
    [alert showTextFieldWithMaxLen:100];
    [alert setTextFieldDefaultText:defaultText];
    // 这里**不能**用 __weak 引用 alert —— 导出日志实证（23:07:29 那条）：
    //   点击确定时 weakAlert 已经变成 nil，[a getTextFieldText] 取到 (null)
    //   → 解析成 0 → 一个字都没写 → 表现就是"改时间没反应"。
    //   原因：WCUIAlertView 不被微信长期持有，show 之后没人强引用它，weak 立刻失效。
    // 正确做法与 JokerPresentEditor 完全一致：__block 强引用 + 两个回调末尾置 nil 打破保留环，
    // 并在 show 之后抓住 UITextField 作为第二条取值路径（alert 出意外也能拿到输入）。
    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{ blockAlert = nil; }];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;   // alert 提前释放时的兜底取值路径
        NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        double ts = DDTimeStampFromString(t);
        if (ts > 0) {
            // 爱锋 changeTime @0xbb284 的收尾（反汇编实证）：
            //   DKWriteShowingTime @0xccfd8 把新时间戳直接写进 vm 的 showingTime ivar（str d8, [x19, x0]），
            //   → [vm updateLayouts] (@0xbb500) → [cell layoutInternal] (@0xbb590) → setNeedsLayout (@0xbb598)。
            // 之前只写缓存 + 触发布局，showingTime 没动，vm 重算出来的仍然是真实时间 —— 这才是真正根因。
            // 顺序不能反：先写缓存（此时 showingTime 还是原始值，key 才钉得住），再改 showingTime。
            DDJokerSetCachedTime(vm, ts);
            DDSetShowingTime(vm, ts);    // 直接写 _showingTime ivar，爱锋 @0xccfd8 同款
            DDRefreshTimeText(vm);       // updateLayouts 按新的 showingTime 重算 m_timeText
            [self layoutInternal];       // ChatTimeCellView.h:9，用重算后的 timeText 重画
            [self setNeedsLayout];
        } else if (DDJokerCachedTime(vm)) {
            // 留空 = 还原：清缓存（传 0 即移除），并把 showingTime 写回原始值
            DDJokerSetCachedTime(vm, 0);
            double rawTime = DDRawShowingTimeOf(vm);
            if (rawTime > 0) DDSetShowingTime(vm, rawTime);
            DDRefreshTimeText(vm);
            [self layoutInternal];
            [self setNeedsLayout];
        }
        blockAlert = nil;   // 打破 alert -> handler -> alert 的保留环
    }];
    [alert show];
    UITextField *tf = [alert getTextField];   // show 之后输入框一定已创建
    if (tf) inputField = tf;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

#pragma mark - ② 运动步数修改
// 对齐爱锋：WCDeviceStepObject.m7StepCount / hkStepCount 直接返回自定义步数
// （爱锋 hooks_final.json 0xb313c / 0xb318c）。这两个 getter 是微信运动排行榜刷新的热路径，
// 爱锋实现里除读开关 + 自定义值外不做任何磁盘 IO（反汇编确认：调 [DKHelperConfig changeSteps]/
// [DKHelperConfig changedSteps] 后 csel 返回，无 NSUserDefaults 写）。因此这里绝不写磁盘，值上限 99999
// （爱锋弹窗建议 ≤60000，showTextFieldWithMaxLen:5）。

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

#pragma mark - ③ 好友数量修改
// 对齐爱锋：不 hook MMUILabel（全局 UILabel 复用会误伤/崩溃），而是在数据层
// ContactsDataLogic.m_uiNormalContact（unsigned int，ContactsDataLogic.h:58 确认）直接返回自定义好友数，
// 并可选地同步导航标题。爱锋 hooks_final.json：ContactsDataLogic.m_uiNormalContact @0xc5ae8 /
// ContactsViewController.viewWillAppear: @0xc5d74。爱锋真实实现里 updateCustomCountLabel 是死代码，
// 真正驱动"X个朋友"的是 m_uiNormalContact 的返回值（微信自行拼后缀）。

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
    // 好友数量改完返回通讯录页须即时刷新“X个朋友”文案：数据层 m_uiNormalContact 已被 hook 成自定义值
    // （ContactsDataLogic.h:58），但微信把该数字缓存在列表 UI 上，viewWillAppear 默认不会重读，
    // 必须显式调 updateCount（ContactsViewController.h:126）重算并刷新计数显示；否则只有重启微信、
    // 重建 ContactsDataLogic 才生效。关掉开关时同样靠它走 %orig 把“X个朋友”还原成真实值。
    if ([self respondsToSelector:@selector(updateCount)]) [self updateCount];
}
%end

#pragma mark - ④ 余额显示修改

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

// ScrollNumber 上下文判定。
//
// 上一版只用视图树搜"零钱通"字样，对详情页来说有两个致命问题：
//   ① "我的零钱"详情页里有"转入零钱通，能赚又能花"小字文案，搜到 → 误判为 LQT → 用零钱通值
//   ② "零钱通"详情页里"零钱通"是 navigationItem.title（不在 view 树），搜不到 → 误判为余额 → 用余额值
// 实测两页恰好完全反（见用户 2026-09-10 06:32 反馈 + HIT 统计 defaultNumber.LQT=2 / defaultNumber.余额=26）。
//
// 修正：先沿响应链拿所属 VC，按 VC 类名分流（爱锋用结构定位"WCPayWebImageView 旁 label"，我们用类名更稳）。
//   WCPayLQTDetailViewController         → LQT
//   WCPayBalanceDetailViewController     → 余额
//   KindaViewController（钱包主页）        → 退回爱锋"附近搜零钱通字样"（主页结构简单，两张入口卡）
//   其它页                              → 不动（防 ScrollNumber/TimeoutNumber 通用控件被误伤闪退）
//
// ScrollNumber 真实父类被 dump 抹成 NSObject，故入参用 id，内部必要时再转 UIView*。

typedef NS_ENUM(NSInteger, DDBalancePageKind) {
    DDBalancePageNone = 0,     // 无关页：不插手
    DDBalancePageBalance,      // 余额/我的零钱
    DDBalancePageLQT           // 零钱通
};

// 诊断：记录最近一次余额页判定的命中字样（"我的零钱"/"账户余额"/"零钱通"/"零钱"），供导出与 HIT 标签。
static NSString *gDDLastBalanceHint = nil;
static DDBalancePageKind gDDLastBalanceKind = DDBalancePageNone;
// 诊断：记录最近一次判定的 superview 链前 8 层类名（用于抓"服务页钱包卡"等未知入口的精确类名，下一轮硬编码进判定）
static NSString *gDDLastBalanceChain = nil;

// 关联对象缓存 key：currentNumber 每帧调用，首判后缓存判定结果到 ScrollNumber 实例；
// 写路径（updateNumber:/defaultNumber:/setCurrentNumber:，数据刷新或 cell 复用时）清缓存重判。
static const void *kDDBalanceKindKey = &kDDBalanceKindKey;
static const void *kDDBalanceHintKey = &kDDBalanceHintKey;

// 从 view 起递归下挖所有子视图，找 UILabel 的 text 是否匹配 key。
// exact=YES 用 isEqual 精确匹配（详情页用，避开"转入零钱通，能赚又能花"小字）；
// exact=NO 用 hasPrefix 前缀匹配（主页用，主页无小字干扰，安全且能覆盖"零钱"/"零钱通"标题）。
static BOOL DDViewDescendantHasText(UIView *view, NSString *key, BOOL exact) {
    if (!view || !key.length) return NO;
    @try {
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:[UILabel class]]) {
                NSString *t = ((UILabel *)sub).text;
                if (t.length && (exact ? [t isEqualToString:key] : [t hasPrefix:key])) return YES;
            }
            if (DDViewDescendantHasText(sub, key, exact)) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

// ⚠️ 微信的余额/零钱通页面体系【全是 NSObject 容器】，不是标准 UIViewController 树（头文件硬证据）：
//   WCPayLQTDetailViewController.h:1 / WCPayBalanceDetailViewController.h:1 / KindaViewController.h:1 /
//   MinimizeViewController.h:1 全部 `: NSObject`。它们模拟了 viewDidLoad/viewWillAppear 等生命周期，
//   但 isKindOfClass:[UITabBarController]/[UINavigationController] 都是 NO，presentedViewController /
//   childViewControllers 根本调不到。所以"从 rootViewController 沿 UIKit 递归取 VC"对微信【彻底失效】，
//   这正是之前所有版本 HIT=0 的真正根因（比 connectedScenes 取空更深一层）。
//   爱锋 isLQT（0xbe820 真反汇编）也是走【view 树】判定而非 VC 树。故判定改为：从 ScrollNumber 自身
//   沿 superview 链向上爬检查字样，完全不碰 VC。详见下方 DDBalancePageKindOf。

// 对齐爱锋 ScrollNumber.isLQT（0xbe820 真反汇编）的判定，但改为【纯 view 树爬祖先链】（原因见上方注释）：
//   微信控制器全是 NSObject，取不到 VC；只能从 ScrollNumber 自身沿 superview 向上爬，检查每层（含子树）字样。
//   强信号（均精确 isEqual，避开"转入零钱通，能赚又能花"小字）：
//     "我的零钱" → Balance（仅余额详情页；主页余额卡叫"零钱"，不命中"我的零钱"）
//     "账户余额" → LQT   （仅零钱通详情页，图 1 证据：KindaUIView·账户余额 0点10元）
//     "零钱通"   → LQT   （主页零钱通卡 + 详情页都有，判 LQT 无歧义）
//     "零钱"     → Balance（主页余额卡；详情页不命中"零钱"精确，避免误判）
//   主页零钱通卡标题能爬到"零钱通"（LQT），主余额卡标题"零钱"（Balance）；与详情页一致，无需分主页/详情两条路径。
//   只爬一条祖先链（O(深度)），比整树递归快；currentNumber 每帧调用也扛得住。
// 判定当前 ScrollNumber 属于【余额 / 零钱通 / 无关页】，两层：
//   ① 第一遍：沿 superview 链检查每个祖先的 className 关键字（O(深度)，每层只比较类名，【不递归子树】，比②快且稳）。
//      微信所有视图类均 NSObject（头文件硬证据），ScrollNumber 的祖先链上必有明确业务类，其类名编译期固定，
//      比运行时拼的 UILabel 文本可靠：
//        · 含 "LQT"/"LingTong"/"KindaMoneyLoadingView" → 零钱通（KindaMoneyLoadingView 是零钱通详情页数字容器，头文件证据：KindaMoneyLoadingView.h:12 timeoutNumber / :21 setMoney:animated:）
//        · 含 "Wallet"/"Balance"/"Entrance" → 余额入口（钱包主页卡 WCPayWalletViewCell、服务页钱包卡、零钱通详情页余额卡等）
//   ② 第二遍（文本兜底，最后保险）：保留原四字精确 + "钱包"兜底递归子树，仅当①全 miss 时才执行（基本不跑）。
//   诊断：记录 superview 链前 8 层类名到 gDDLastBalanceChain，用于抓"服务页钱包卡"等未知入口的精确类名。
static DDBalancePageKind DDBalancePageKindOf(id sn) {
    @try {
        if (![sn isKindOfClass:[UIView class]]) return DDBalancePageNone;
        UIView *v = (UIView *)sn;
        NSMutableString *chain = [NSMutableString string];
        // ① 第一遍：沿祖先链检查 className 关键字（无子树递归）
        for (int depth = 0; depth < 24 && v; depth++) {
            NSString *cls = NSStringFromClass([v class]);
            if (depth < 8) [chain appendFormat:@"%d:%@ ", depth, cls];
            if ([cls rangeOfString:@"LQT"].location != NSNotFound ||
                [cls rangeOfString:@"LingTong"].location != NSNotFound ||
                [cls rangeOfString:@"KindaMoneyLoadingView"].location != NSNotFound) {
                gDDLastBalanceHint = [NSString stringWithFormat:@"类名:%@", cls];
                gDDLastBalanceChain = chain;
                return DDBalancePageLQT;
            }
            if ([cls rangeOfString:@"Wallet"].location != NSNotFound ||
                [cls rangeOfString:@"Balance"].location != NSNotFound ||
                [cls rangeOfString:@"Entrance"].location != NSNotFound) {
                gDDLastBalanceHint = [NSString stringWithFormat:@"类名:%@", cls];
                gDDLastBalanceChain = chain;
                return DDBalancePageBalance;
            }
            v = v.superview;
        }
        // ② 第二遍（文本兜底，最后保险）：四字精确 + "钱包"兜底
        v = (UIView *)sn;
        for (int depth = 0; depth < 24 && v; depth++) {
            if (DDViewDescendantHasText(v, @"我的零钱", YES)) { gDDLastBalanceHint = @"我的零钱"; gDDLastBalanceChain = chain; return DDBalancePageBalance; }
            if (DDViewDescendantHasText(v, @"账户余额", YES)) { gDDLastBalanceHint = @"账户余额"; gDDLastBalanceChain = chain; return DDBalancePageLQT; }
            if (DDViewDescendantHasText(v, @"零钱通",   YES)) { gDDLastBalanceHint = @"零钱通";   gDDLastBalanceChain = chain; return DDBalancePageLQT; }
            if (DDViewDescendantHasText(v, @"零钱",     YES)) { gDDLastBalanceHint = @"零钱";     gDDLastBalanceChain = chain; return DDBalancePageBalance; }
            v = v.superview;
        }
        v = (UIView *)sn;
        for (int depth = 0; depth < 8 && v; depth++) {
            if (DDViewDescendantHasText(v, @"钱包", YES)) { gDDLastBalanceHint = @"钱包"; gDDLastBalanceChain = chain; return DDBalancePageBalance; }
            v = v.superview;
        }
        gDDLastBalanceHint = nil;
        gDDLastBalanceChain = chain;
    } @catch (NSException *e) {}
    return DDBalancePageNone;
}

// ScrollNumber 会为每一位数字建一整列滚动 view，位数极端时内存暴涨会被系统杀掉（也是闪退），
// 所以给金额封顶 11 位（约 9999 万元），足够用且不会把控件撑爆
static unsigned long long DDClampFen(unsigned long long fen) {
    const unsigned long long kMaxFen = 99999999999ULL;
    return fen > kMaxFen ? kMaxFen : fen;
}

// 详情页（我的零钱 / 零钱通）余额大数字有两种可能载体：
//   WCPayBalanceDetailViewController.h:14 balanceTitleLabel（UILabel）
//   WCPayBalanceDetailViewController.h:46 / WCPayLQTDetailViewController.h:54 timeoutNumber（TimeoutNumber）
// 上面只 hook TimeoutNumber 的 updateNumber: 在详情页没生效，说明详情页走的是别的赋值入口，
// 或主数字干脆就是 balanceTitleLabel 这个 UILabel。所以这俩载体都要接管。
//
// 下面这个工具：把文本里第一个金额 token 换成自定义值（分），保留原格式（¥ 前缀 / 小数位 / 千分位）。
// 找不到任何金额就返回原串，绝不破坏其它文本。证据：用户最初截图「我的零钱 ¥2.40」「零钱通 ¥0.10」。
static NSString *DDBalanceRewriteMoneyText(NSString *text, unsigned long long fen) {
    if (!text.length) return text;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"[¥￥]\\s*\\d[\\d,]*(\\.\\d+)?" options:0 error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!m || m.range.location == NSNotFound) {
        re = [NSRegularExpression regularExpressionWithPattern:@"\\d[\\d,]*(\\.\\d+)?" options:0 error:nil];
        m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    }
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
    if (dec < 0) dec = 0; if (dec > 6) dec = 6;
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

// 详情页（我的零钱）余额 UILabel 改写：refreshViewWithData: / updateBalanceTitleLabel 之后，
// 把 balanceTitleLabel.text 的金额换成自定义值。只动这一个 label，不碰其它文本，避免误伤"昨日收益"等小字。
// ⚠️ 必须定义在 %hook 块【外面】：Logos 的 %hook 会把方法展开成 C 函数，里面写 static 函数会变成非法嵌套。
static void DDBalancePatchTitleLabel(id vc, unsigned long long fen, NSString *hit) {
    @try {
        if (![vc respondsToSelector:@selector(balanceTitleLabel)]) return;
        id lb = [vc balanceTitleLabel];
        if (![lb isKindOfClass:[UILabel class]]) return;
        NSString *t = ((UILabel *)lb).text;
        if (!t.length) return;
        NSString *nt = DDBalanceRewriteMoneyText(t, fen);
        if (![nt isEqualToString:t]) { ((UILabel *)lb).text = nt; DDJokerHit(hit); }
    } @catch (NSException *e) {}
}


#pragma mark - ④ 余额显示修改（锚定爱锋 wechatku.dylib 真反汇编：只读 getter 接管）

// 爱锋 wechatku.dylib 反汇编实证（hooks_final.json + stubmap 反汇编）：
//   ScrollNumber 挂了 4 个 hook：
//     currentNumber        (getter, 0xbecc4) —— 只读入口：每次渲染都读它
//     updateNumber:        (0xbed30)          —— 写入口（替换传入值）
//     defaultNumber:       (0xbeda4)          —— 写入口（初始化值）
//     isLQT                (%new, 0xbe820)     —— 运行时判定"这是不是零钱通数字"
//   TimeoutNumber 只挂了 layoutSubviews (0xbe624)：%orig 之后调 [self updateScrollNumber] 强制重绘。
//
//   关键结论：爱锋【不 hook 任何 TimeoutNumber 写方法】，而是直接打 ScrollNumber 这一叶渲染层，
//            并且最重要的是 hook 了 currentNumber getter（读路径）。无论微信走哪条写路径
//            （updateNumber:/defaultNumber:/setCurrentNumber:），最终渲染都读 getter ——
//            在读路径把真值换成自定义值，就永远赢，不存在"被二次覆盖回真值"。
//
//   这正是我们之前一直失败的根因：我们打的是 TimeoutNumber 的写方法（写路径），
//   而详情页的大数字由 ScrollNumber 直接持有/渲染，且详情页走的是 ScrollNumber.setCurrentNumber:
//   这条写路径（见 ScrollNumber.h:39 前向声明注释），它根本不经过我们 hook 的 TimeoutNumber 四个方法，
//   于是详情页只看到 %orig 真值。之前还加了"只详情页生效"的白名单（DDIsWalletBalancePage），但 hook 的类错了，
//   缩窄白名单也没用 —— 真问题是"插在写路径、且插错了类"。
//
//   上两版的根因（已用 2026-09-10 日志 + 爱锋反汇编坐实）：
//     ① 详情页"两页都反"的真凶是【判定当前页的方式错】：之前沿 ScrollNumber 的响应链（nextResponder 链）
//        找 VC，详情页 push/modal 后响应链常指到容器/主页 VC，于是详情页被当成主页、再用附近
//        字样误判——"我的零钱"详情页附近有"转入零钱通"小字 → 误判 LQT（显示 3）；"零钱通"详情页标题
//        在 nav bar 不在 view 树 → 搜不到 → 误判余额（显示 6）。两条恰好全反。
//     ② 主页零钱通卡扑空是【模糊匹配】的锅：之前用 rangeOfString 搜"零钱通"，层级一变就搜不到。
//
//   修正（彻底对齐爱锋 isLQT @0xbe820 反汇编）：
//     A. 判定当前页改用 view 树爬祖先链（微信页面体系全是 NSObject 容器，标准 UIKit 取 VC 全部失效，见 DDBalancePageKindOf 注释）：
//        顶层 VC 恒为当前可见页，主页=WCPayMainViewControllerV2、进详情后=WCPayLQTDetail/WCPayBalanceDetail，
//        不会再指错 —— 这是修好"两页都反"的关键。
//     B. 详情页按 VC 类名分流（爱锋详情页支用 WCPayWebImageView 旁 label 结构定位，我们用类名更稳）：
//        WCPayLQTDetailViewController     → LQT
//        WCPayBalanceDetailViewController → 余额
//     C. 主页按附近"零钱通"【精确匹配】(isEqual，对齐爱锋 0xbeb80 的 isEqual:) 分流 —— 正好避开"转入零钱通"
//        小字（它不等于"零钱通"，不会被精确匹配命中）；hasPrefix 仅作标题带后缀的兜底：
//        WCPayMainViewControllerV2 / KindaViewController（钱包主页，title=="钱包"） →
//          附近精确"零钱通" → LQT；精确"零钱" → 余额；都不是（银行卡等无关卡）→ 不动（防误伤）
//     D. 其它页 → 不动（防 ScrollNumber/TimeoutNumber 通用控件被误伤闪退）
//   因此主页零钱/零钱通两张卡 + 我的零钱/零钱通两个详情页全部精确分流；getter 读路径不闪。
//   写入口 HIT 标签已带顶层 VC 类名（如 余额.SN.defaultNumber.LQT.WCPayLQTDetailViewController），下一版日志
//   即可直接看出"哪个页被判成了哪种"，无需再猜测。
//
//   ⚠️ getter 每帧都会调，绝不能打日志/计数（会刷屏+掉帧），计数只放在写入口 hook 里。

%hook ScrollNumber
- (unsigned long long)currentNumber {
    unsigned long long orig = %orig;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.balanceEnabled) return orig;
        // 判定结果用关联对象缓存到 ScrollNumber 实例：currentNumber 每帧每位数字都调，
        // 首判后直读缓存 O(1)，不再每帧爬祖先链（解决性能）。写路径更新缓存即失效，cell 复用/数据刷新时重判。
        NSNumber *cached = objc_getAssociatedObject(self, kDDBalanceKindKey);
        DDBalancePageKind kind = cached ? (DDBalancePageKind)cached.integerValue : DDBalancePageNone;
        if (!cached) {
            kind = DDBalancePageKindOf(self);
            gDDLastBalanceKind = kind;
            objc_setAssociatedObject(self, kDDBalanceKindKey, @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, kDDBalanceHintKey, gDDLastBalanceHint ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) return DDClampFen(DDLingtongFenValue());
        if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) return DDClampFen(DDBalanceFenValue());
    } @catch (NSException *e) {}
    return orig;
}

// 写入口：把真值换成自定义值再 %orig，让滚动动画起点就是自定义值，渲染读 getter 也是自定义值，
// 不会出现"真值→自定义值"的一帧闪烁。三条写路径全接管（updateNumber:/defaultNumber:/setCurrentNumber:）。
- (void)updateNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            objc_setAssociatedObject(self, kDDBalanceKindKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); // 写路径=数据刷新时机：清缓存，让 currentNumber 渲染时重判最新
            DDBalancePageKind kind = DDBalancePageKindOf(self);
            gDDLastBalanceKind = kind;
            NSString *hint = gDDLastBalanceHint ?: @"?";
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { DDJokerHit([NSString stringWithFormat:@"余额.SN.updateNumber.LQT.%@", hint]); %orig(DDClampFen(DDLingtongFenValue())); return; }
            if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { DDJokerHit([NSString stringWithFormat:@"余额.SN.updateNumber.余额.%@", hint]); %orig(DDClampFen(DDBalanceFenValue())); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
- (void)defaultNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            objc_setAssociatedObject(self, kDDBalanceKindKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); // 写路径=数据刷新时机：清缓存，让 currentNumber 渲染时重判最新
            DDBalancePageKind kind = DDBalancePageKindOf(self);
            gDDLastBalanceKind = kind;
            NSString *hint = gDDLastBalanceHint ?: @"?";
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { DDJokerHit([NSString stringWithFormat:@"余额.SN.defaultNumber.LQT.%@", hint]); %orig(DDClampFen(DDLingtongFenValue())); return; }
            if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { DDJokerHit([NSString stringWithFormat:@"余额.SN.defaultNumber.余额.%@", hint]); %orig(DDClampFen(DDBalanceFenValue())); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
- (void)setCurrentNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            objc_setAssociatedObject(self, kDDBalanceKindKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); // 写路径=数据刷新时机：清缓存，让 currentNumber 渲染时重判最新
            DDBalancePageKind kind = DDBalancePageKindOf(self);
            gDDLastBalanceKind = kind;
            NSString *hint = gDDLastBalanceHint ?: @"?";
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { DDJokerHit([NSString stringWithFormat:@"余额.SN.setCurrentNumber.LQT.%@", hint]); %orig(DDClampFen(DDLingtongFenValue())); return; }
            if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { DDJokerHit([NSString stringWithFormat:@"余额.SN.setCurrentNumber.余额.%@", hint]); %orig(DDClampFen(DDBalanceFenValue())); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
%end

// TimeoutNumber 这一层不再 hook 写方法（爱锋也不 hook）。只保留 layoutSubviews 兜底：
// 在布局时强制 [self updateScrollNumber] 把内部数字重新同步到 ScrollNumber，
// 让刚进详情页、首帧还没赋值时的那一版重绘也走我们的 getter。
%hook TimeoutNumber
- (void)layoutSubviews {
    %orig;
    @try {
        // 对齐爱锋 0xbe624：%orig 之后直接 [self updateScrollNumber] 强制重绘，
        // 不查白名单（爱锋全量生效），让首帧还没赋值时的那一版重绘也走我们的 getter。
        if ([self respondsToSelector:@selector(updateScrollNumber)])
            [self updateScrollNumber];
    } @catch (NSException *e) {}
}
%end

// 详情页（我的零钱）UILabel 这一支：数据回来后 refreshViewWithData: 读 WCPayBalanceInfo 把 balanceTitleLabel.text
// 设成真值。我们在 %orig 之后把那个 label 的文本金额改写成自定义值，作为 ScrollNumber getter 那一支的正交双保险。
// 只动 balanceTitleLabel 一个 label，不碰其它文本。每次改写都幂等（已是目标值就跳过）。
%hook WCPayBalanceDetailViewController
- (void)refreshViewWithData:(id)arg {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()), @"余额.详情UILabel.余额");
}
- (void)updateBalanceTitleLabel {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()), @"余额.详情UILabel.余额");
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!(cfg.balanceEnabled && [cfg hasBalanceValue])) return;
    // 数据可能在 viewWillAppear 之后才补齐（首帧先画真值），延迟重试一次，幂等无副作用。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try { DDBalancePatchTitleLabel(self, DDClampFen(DDBalanceFenValue()), @"余额.详情UILabel.余额"); } @catch (NSException *e) {}
    });
}
%end

// 详情页（零钱通）：主余额由上面 ScrollNumber getter（读路径）接管；
// 这里再补一道 UILabel 兜底——万一它的余额也走了 balanceTitleLabel 这个 label，刷新后一并改写。
%hook WCPayLQTDetailViewController
- (void)refreshViewWithData:(id)arg {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasLingtongValue])
        DDBalancePatchTitleLabel(self, DDClampFen(DDLingtongFenValue()), @"余额.详情UILabel.LQT");
}
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!(cfg.balanceEnabled && [cfg hasLingtongValue])) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try { DDBalancePatchTitleLabel(self, DDClampFen(DDLingtongFenValue()), @"余额.详情UILabel.LQT"); } @catch (NSException *e) {}
    });
}
%end


#pragma mark - 通用日志模块 B：快照与导出（所有功能共用）

// 导出内容：环境信息 → 命中统计 → 缓存盘点 → 最近一条时间条 → 该类运行时结构 → 日志正文。
// 模块 B 放在所有功能 hook 之后，就是为了能直接引用各功能段已定义的函数，不需要任何前向声明。

// 把任意类的 ivar / 方法 / 父类链全列出来：以后改任何功能，换个类名 dump 一次就知道字段真身叫什么
static NSString *DDJokerDescribeClassIvars(Class cls) {
    NSMutableString *s = [NSMutableString string];
    if (!cls) return @"  (类不存在：dump 里的类名在当前微信版本变了)\n";
    [s appendFormat:@"  类名    : %s\n", class_getName(cls)];

    NSMutableArray *chain = [NSMutableArray array];
    Class sup = class_getSuperclass(cls);
    while (sup) { [chain addObject:[NSString stringWithUTF8String:class_getName(sup)]]; sup = class_getSuperclass(sup); }
    [s appendFormat:@"  父类链  : %@\n", chain.count ? [chain componentsJoinedByString:@" → "] : @"(无)"];

    // ivar 全列，名字含 time/date 的自动打 <<< 标记 —— 换任何类都能一眼找到目标字段
    unsigned int n = 0;
    Ivar *list = class_copyIvarList(cls, &n);
    [s appendFormat:@"  ivar 数 : %u\n", n];
    for (unsigned int i = 0; i < n; i++) {
        Ivar iv = list[i];
        const char *nm = ivar_getName(iv) ?: "";
        [s appendFormat:@"    [%02u] %-32s type=%-8s offset=%td%s\n",
         i, nm, ivar_getTypeEncoding(iv) ?: "", ivar_getOffset(iv),
         (DDStringHas(nm, "time") || DDStringHas(nm, "date")) ? "  <<<" : ""];
    }
    free(list);

    unsigned int m = 0;
    Method *ms = class_copyMethodList(cls, &m);
    [s appendFormat:@"  方法数  : %u（只列名字含 time/date 的）\n", m];
    for (unsigned int i = 0; i < m; i++) {
        SEL sel = method_getName(ms[i]);
        const char *nm = sel_getName(sel) ?: "";
        if (DDStringHas(nm, "time") || DDStringHas(nm, "date")) {
            [s appendFormat:@"    - %-34s %s\n", nm, method_getTypeEncoding(ms[i]) ?: ""];
        }
    }
    free(ms);
    return s;
}

static NSString *DDJokerDescribeTimeVM(id vm) {
    if (!vm) return @"  (还没触发过 ChatTimeViewModel.timeText：先打开一个聊天页滚动几下再导出)\n";
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"  vm=%p  类=%s\n", vm, class_getName([vm class])];
    [s appendFormat:@"  showingTime 当前值 : %@\n", DDTimeDesc(DDShowingTimeOf(vm))];
    [s appendFormat:@"  原始 showingTime   : %@\n", DDTimeDesc(DDRawShowingTimeOf(vm))];
    [s appendFormat:@"  时间 key           : %@\n", DDJokerTimeKey(vm)];
    NSNumber *cached = DDJokerCachedTime(vm);
    [s appendFormat:@"  缓存命中           : %@\n", cached ? DDTimeDesc([cached doubleValue]) : @"无"];
    return s;
}

// 缓存盘点：顺带回答"清理之后到底有没有残留"
static NSString *DDJokerDescribeCaches(void) {
    NSMutableString *s = [NSMutableString string];
    NSDictionary *time = DDJokerLoadCache(kDDJokerTimeCacheKey);
    NSDictionary *text = DDJokerLoadCache(kDDJokerTextCacheKey);
    NSDictionary *amount = DDJokerLoadCache(kDDJokerAmountCacheKey);
    NSDictionary *origin = DDJokerLoadCache(kDDJokerTextOriginalKey);
    [s appendFormat:@"  时间缓存 %lu 条 : %@\n", (unsigned long)time.count, time ?: @{}];
    [s appendFormat:@"  文字缓存 %lu 条\n", (unsigned long)text.count];
    [s appendFormat:@"  金额缓存 %lu 条\n", (unsigned long)amount.count];
    [s appendFormat:@"  原文备份 %lu 条（清理缓存时刻意保留，用于文字还原）\n", (unsigned long)origin.count];
    NSString *folder = DDJokerImagesDir();
    NSArray *imgs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:nil];
    [s appendFormat:@"  替换图片目录 %@ : %lu 个文件\n", folder, (unsigned long)imgs.count];
    return s;
}

static NSString *DDJokerExportLogText(void) {
    NSMutableString *out = [NSMutableString string];
    [out appendString:@"===== DD小丑助手 诊断日志 =====\n"];

    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    f.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    [out appendFormat:@"导出时间 : %@\n", [f stringFromDate:[NSDate date]]];
    [out appendFormat:@"系统版本 : %@ %@\n", [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion];
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    [out appendFormat:@"微信版本 : %@ (%@)\n", info[@"CFBundleShortVersionString"], info[@"CFBundleVersion"]];

    DDGlobalConfig *c = [DDGlobalConfig shared];
    [out appendFormat:@"开关状态 : 文字=%d 图片=%d 时间=%d 转账=%d 诊断=%d 余额=%d 余额值=%@ 零钱通值=%@\n",
     c.textEnabled, c.imageEnabled, c.timeEnabled, c.transferEnabled, c.diagEnabled,
     c.balanceEnabled, ([c hasBalanceValue] ? c.balanceValue : @"-"), ([c hasLingtongValue] ? c.lingtongValue : @"-")];
    [out appendString:@"复现步骤 : 清空日志 → 复现问题（改时间/文字/金额/图片/步数…）→ 回本页导出，把日志发出去即可定位\n"];

    [out appendString:@"\n----- hook 命中统计 -----\n"];
    [out appendString:DDJokerDescribeHitStats()];

    [out appendString:@"\n----- 缓存盘点 -----\n"];
    [out appendString:DDJokerDescribeCaches()];

    [out appendString:@"\n----- 最近一条时间条 -----\n"];
    [out appendString:DDJokerDescribeTimeVM(gDDLastTimeVM)];

    // 类名不再写死：默认 dump 上面那条时间条的类，拿不到才退回 ChatTimeViewModel
    [out appendString:@"\n----- 该类运行时结构 -----\n"];
    [out appendString:DDJokerDescribeClassIvars([gDDLastTimeVM class] ?: NSClassFromString(@"ChatTimeViewModel"))];

    // 余额相关类运行时存在性：dump 头文件来自某个微信版本，类名一换 hook 就全部静默失效。
    // 这段直接把"当前微信里到底有没有这个类、有没有目标方法"打出来，避免继续对着不存在的类名排查。
    [out appendString:@"\n----- 余额相关类运行时存在性 -----\n"];
    {
        NSDictionary *checks = @{
            @"WCPayBalanceDetailViewController" : @[@"balanceTitleLabel", @"updateBalanceTitleLabel", @"refreshViewWithData:"],
            @"WCPayLQTDetailViewController"     : @[@"refreshViewWithData:", @"viewWillAppear:"],
            @"WCPayBalanceInfo"                 : @[@"wallet_balance", @"m_uiAvailableBalance", @"m_uiTotalBalance"],
            @"WCPayLQTInfo"                     : @[@"lqtAvailBalance", @"lqtTotalBalance"],
            @"WCPayLQTDetailControlLogic"       : @[@"lqtBalance"],
            @"WCPayMainViewControllerV2"        : @[@"viewWillAppear:"],
            @"ScrollNumber"                     : @[@"defaultNumber:", @"updateNumber:", @"setCurrentNumber:"],
            @"TimeoutNumber"                    : @[@"defaultNumber:", @"setNoAnimationStart:", @"updateNumber:", @"updateNumberInternal:", @"updateScrollNumber", @"layoutSubviews", @"scrollNumber"],
        };
        for (NSString *clsName in checks) {
            Class cls = NSClassFromString(clsName);
            if (!cls) { [out appendFormat:@"  %-34s : ❌ 类不存在（hook 无效）\n", clsName.UTF8String]; continue; }
            NSMutableArray *miss = [NSMutableArray array];
            for (NSString *selName in checks[clsName]) {
                if (![cls instancesRespondToSelector:NSSelectorFromString(selName)]) [miss addObject:selName];
            }
            [out appendFormat:@"  %-34s : ✅ 存在%@\n", clsName.UTF8String,
             miss.count ? [NSString stringWithFormat:@"，但缺方法 %@", [miss componentsJoinedByString:@"/"]] : @""];
        }
    }

    // 余额页判定最近上下文：最近一次钱包渲染时，从 ScrollNumber 爬祖先链命中的字样、判成哪种。
    // 若实测 HIT 仍为 0，看这里就知是"页面字样未命中"（比如某页标题不是上面四字之一）。
    [out appendString:@"\n----- 余额页判定最近上下文（最近一次钱包渲染）-----\n"];
    {
        NSString *kindStr = @"(无)";
        if (gDDLastBalanceKind == DDBalancePageLQT)         kindStr = @"零钱通(LQT)";
        else if (gDDLastBalanceKind == DDBalancePageBalance) kindStr = @"余额(Balance)";
        else if (gDDLastBalanceKind == DDBalancePageNone)    kindStr = @"无关页(None)";
        [out appendFormat:@"  命中字样 : %@\n", gDDLastBalanceHint ?: @"(空→页面字样未命中，即 HIT=0 根因)"];
        [out appendFormat:@"  页判定 : %@\n", kindStr];
        [out appendFormat:@"  superview链(前8层类名) : %@\n", gDDLastBalanceChain ?: @"(无)"];
        [out appendString:@"  ⚠️ 若某页没改成功，把上一条 superview 链贴出来——找含 Wallet/Balance/LQT/Entrance 的类名，下一版直接硬编码进 DDBalancePageKindOf 的 className 判定\n"];
    }

    [out appendString:@"\n----- 日志正文 -----\n"];
    NSMutableString *buf = DDLogBuffer();
    NSString *body = @"";
    @synchronized (buf) { body = [buf copy]; }
    [out appendString:body.length ? body : @"(空：诊断开关没开，或还没触发过相关 hook)\n"];
    return out;
}

// 写到微信 Documents（Filza / 文件 App 可直接取），路径同步进剪贴板
static NSString *DDJokerWriteDiagLog(void) {
    NSString *text = DDJokerExportLogText();
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (!dir.length) return nil;
    NSString *path = [dir stringByAppendingPathComponent:@"DDJokerDiag.log"];
    NSError *err = nil;
    [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (err) { NSLog(@"[DD小丑] 写诊断日志失败: %@", err); return nil; }
    [[UIPasteboard generalPasteboard] setString:path];
    return path;
}

#pragma mark - 设置界面

@interface DDJokerSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *stepsField;
@property (nonatomic, strong) UITextField *contactsField;
@property (nonatomic, strong) UITextField *balanceField;
@property (nonatomic, strong) UITextField *lingtongField;
@end

@implementation DDJokerSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

- (NSAttributedString *)dd_centeredFooterString:(NSString *)text {
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    ps.lineBreakMode = NSLineBreakByWordWrapping;
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:text];
    [attr addAttribute:NSParagraphStyleAttributeName value:ps range:NSMakeRange(0, text.length)];
    return attr;
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

    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
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

// 右侧小按钮（清理 / 导出 / 清空共用，样式统一，避免每段重复十来行）
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

    WCTableViewSectionManager *chatSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"聊天设置"];
    chatSection.attributedFooterTitle = [self dd_centeredFooterString:@"聊天文字 / 图片 / 时间 / 转账修改 为独立开关：长按消息弹窗菜单小丑按钮，文字改内容与引用标题、图片替换为相册所选图、时间改显示、转账改金额"];
    [chatSection addCell:[cellCls switchCellForSel:@selector(textSwitchChanged:) target:self title:@"聊天文字修改" on:cfg.textEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(imageSwitchChanged:) target:self title:@"聊天图片修改" on:cfg.imageEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(timeSwitchChanged:) target:self title:@"聊天时间修改" on:cfg.timeEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(transferSwitchChanged:) target:self title:@"聊天转账修改" on:cfg.transferEnabled]];
    UIButton *clearBtn = [self dd_actionButton:@"清理" action:@selector(clearChatCacheTapped:) x:0];
    UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [clearRight addSubview:clearBtn];
    [chatSection addCell:[cellCls normalCellForSel:nil target:nil title:@"清除修改缓存" rightView:clearRight]];
    [_tableViewManager addSection:chatSection];

    WCTableViewSectionManager *profileSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"资料设置"];
    profileSection.attributedFooterTitle = [self dd_centeredFooterString:@"零钱余额修改开启后可自定义余额与零钱通金额。步数与好友数量修改后返回对应页面即生效（重新进入微信运动或通讯录、或下拉刷新），无需重启微信"];
    [profileSection addCell:[cellCls switchCellForSel:@selector(balanceSwitchChanged:) target:self title:@"零钱余额修改" on:cfg.balanceEnabled]];
    if (cfg.balanceEnabled) {
        self.balanceField = [[UITextField alloc] init];
        [self.balanceField addTarget:self action:@selector(balanceChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentBalance = [cfg hasBalanceValue] ? cfg.balanceValue : @"";
        UIView *balanceRight = [self inputRowWithField:self.balanceField
                                                action:@selector(balanceConfirm:)
                                           placeholder:@"例如：888.88"
                                                  text:currentBalance];
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
                                        placeholder:@"例如：5200"
                                               text:currentContacts];
        WCTableViewCellManager *contactsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳数量自定义" rightView:rightView];
        contactsSubCell.userInfo = @"SubCell";
        [profileSection addCell:contactsSubCell];
    }
    [_tableViewManager addSection:profileSection];

    // 诊断日志独立成组：不属于任何单个功能，以后改哪个功能都用同一套日志定位
    WCTableViewSectionManager *diagSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"诊断日志"];
    diagSection.attributedFooterTitle = [self dd_centeredFooterString:@"所有功能（文字/图片/时间/转账/步数/好友/余额）的运行时日志都记在这一处。排查问题：清空 → 复现 → 导出，日志含各 hook 命中次数、缓存盘点与运行时类结构"];
    [diagSection addCell:[cellCls switchCellForSel:@selector(diagSwitchChanged:) target:self title:@"记录运行日志" on:cfg.diagEnabled]];
    UIButton *exportBtn = [self dd_actionButton:@"导出" action:@selector(exportDiagLogTapped:) x:0];
    UIButton *logClearBtn = [self dd_actionButton:@"清空" action:@selector(clearDiagLogTapped:) x:60];
    UIView *logRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 112, 34)];
    [logRight addSubview:exportBtn];
    [logRight addSubview:logClearBtn];
    [diagSection addCell:[cellCls normalCellForSel:nil target:nil title:@"导出日志" rightView:logRight]];
    [_tableViewManager addSection:diagSection];

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
    JokerInvalidateAllLayout();   // 关闭立即恢复原文，开启立即套用已保存的修改
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
    // 关开关时也必须走全量重绘：vm 里已算好的 titleText 是懒加载缓存，不清就一直显示旧金额
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)clearChatCacheTapped:(id)sender {
    DDJokerClearAllMessageCache();    // 清文本/金额缓存字典 + 替换图目录
    JokerInvalidateAllLayout();       // 全量重绘所有聊天页（遍历全部 window 的 VC 树，不再只查单个导航栈）
    [self buildTable];
    [self dd_showDoneToast:@"已清理"];
}

- (void)diagSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].diagEnabled = sender.isOn;
    [self buildTable];
}

- (void)clearDiagLogTapped:(id)sender {
    DDJokerClearDiagLog();
    [self dd_showDoneToast:@"日志已清空"];
}

- (void)exportDiagLogTapped:(id)sender {
    NSString *path = DDJokerWriteDiagLog();
    if (!path.length) { [self dd_showDoneToast:@"导出失败"]; return; }
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (av.popoverPresentationController) {   // iPad 必须给一个锚点，否则 present 直接崩
        UIView *anchor = [sender isKindOfClass:[UIView class]] ? (UIView *)sender : self.view;
        av.popoverPresentationController.sourceView = anchor;
        av.popoverPresentationController.sourceRect = anchor.bounds;
    }
    __weak DDJokerSettingsViewController *weakSelf = self;
    av.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        [weakSelf dd_showDoneToast:completed ? @"日志已导出" : @"已取消"];
    };
    [self presentViewController:av animated:YES completion:nil];
}

- (void)dd_showDoneToast:(NSString *)text {
    if (!text.length) return;
    // 微信原生带勾 success toast：WeToast - showDoneToastWithText:（声明见文件顶部）
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

// 实时回调：边打边存，不重建 table（重建会销毁正在编辑的 textField、丢焦点并让键盘抖动）。
// 键盘回收仍交给"确认"按钮的 buildTable 完成。
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
        // 诊断日志默认开：没写过这个 key 时 boolForKey 会返回 NO，这里手动兜成 YES
        _diagEnabled = [def objectForKey:kDDFeatureDiagEnabled] ? [def boolForKey:kDDFeatureDiagEnabled] : YES;
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

- (void)setDiagEnabled:(BOOL)enabled {
    _diagEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureDiagEnabled];
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

%ctor {
    @autoreleasepool {
        DDLOG(@"=== 插件加载 ===");
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑助手"
                                 version:@"1.0.0"
                              controller:@"DDJokerSettingsViewController"];
    }
}
