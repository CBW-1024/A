#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

// ============================================================
//  DD小丑资料助手  (WeChat Jailbreak Tweak, Theos/Logos 单文件)
//  在微信内自定义「自己的微信号」与「单聊联系人头像」
//
//  功能一 · 自定义微信号（只处理自己的账号）
//    设置页填入目标微信号并打开开关。显示侧 hook 两个数据出口：
//      CSetting.m_nsAliasName        —— 自己的账号资料模型（CSetting.h:58/301）
//      CBaseContact.m_nsAliasName    —— 联系人基类，仅 isSelf 时替换（CBaseContact.h:12/177）
//    只改内存里的显示值，不写数据库、不发网络请求；关闭开关即恢复真实微信号。
//
//  功能二 · 单聊联系人头像替换
//    总开关：设置页「自定义用户头像」→「备注用户头像」。
//    入口：单聊「聊天信息」页(AddContactToChatRoomViewController)第一个分组内插入「自定义头像」开关，
//      打开即调起微信相册选图并裁剪，关闭则删除本地图片。
//      该 VC 的表格是 MMTableViewInfo，它继承 WCTableViewManager(MMTableViewInfo.h:1)，
//      所以直接复用 WCTableViewSectionManager / WCTableViewCellManager 建行。
//    存储：Documents/DDAvatar/<userName>.png，按用户名一一对应，不额外维护映射表。
//    显示：hook MMHeadImageView 的三个写图入口，命中本地图就替换
//      updateHeadImage:            (MMHeadImageView.h:66)
//      updateUsrName:withHeadImgUrl: (MMHeadImageView.h:54)
//      ImageDidLoad:Url:           (MMHeadImageView.h:68，异步下载完成后会覆盖，必须拦)
//    限制：不支持群聊，命中 [CBaseContact isChatroom] 直接跳过注入(CBaseContact.h:129)。
// ============================================================


#pragma mark - 微信类声明
// 本插件 hook 的微信原生类与方法签名，均锚定微信 .h 头文件 dump。


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
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue rightImage:(id)rightImage;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightView:(id)rightView;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
+ (id)sectionWithFooter:(NSString *)footer;
+ (id)sectionWithHeader:(NSString *)header Footer:(NSString *)footer;
@property (nonatomic, copy) NSString *footerTitle;
@property (nonatomic, retain) id userInfo;
- (void)addCell:(id)arg1;
- (void)insertCell:(id)a0 At:(unsigned int)a1;
- (id)getAllCells;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(long long)style;
@property (retain, nonatomic) UITableView *tableView;
- (void)addSection:(id)arg1;
- (unsigned long long)getSectionCount;
- (id)getSectionAt:(unsigned long long)a0;
- (id)getAllSections;
- (void)reloadTableView;
@end

// 联系人数据模型。CContact 继承 CBaseContact(CContact.h:3)，字段都在基类。
@interface CBaseContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@property (retain, nonatomic) NSString *m_nsAliasName;
- (BOOL)isChatroom;
- (BOOL)isSelf;
@end

@interface CContact : CBaseContact
@end

// 自己的账号资料模型，微信号字段 m_nsAliasName(CSetting.h:58)，getter 见 CSetting.h:301。
@interface CSetting : NSObject
- (id)m_nsAliasName;
@end

// 微信头像视图：nsUsrName 可直接判断当前渲染的是谁(MMHeadImageView.h:23)。
@interface MMHeadImageView : UIView
@property (readonly, nonatomic) NSString *nsUsrName;
- (void)updateHeadImage:(id)image;
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl;
- (void)ImageDidLoad:(id)image Url:(id)url;
@end

// 微信原生选图器(MMImagePickerManager.h:82/12)：optionObj 只列本插件用到的配置项；
// m_delegate 是 weak，manager 由调用方强引用住(DDAvatarPicker.pickerManager)。
@interface MMImagePickerManagerOptionObj : NSObject
@property (nonatomic) long long maxImageCount;
@property (nonatomic) BOOL canSendMultiImage;
@property (nonatomic) BOOL disableVideoSelection;
@property (nonatomic) BOOL imageDirectToEditMode;
@property (nonatomic) BOOL m_directToFirstAlbum;
@end

@interface MMImagePickerManager : NSObject
@property (weak, nonatomic) id m_delegate;
- (void)showWithOptionObj:(id)option inViewController:(id)vc delegate:(id)delegate;
@end

// 单聊「聊天信息」页。m_contact 是当前联系人(AddContactToChatRoomViewController.h:24)。
// 下面 %new 方法先声明以便 hook 内互相调用。
@interface AddContactToChatRoomViewController : UIViewController
@property (retain, nonatomic) CContact *m_contact;
- (void)reloadTableData;
- (void)dd_injectAvatarCellIfNeeded;
- (void)toggleCustomContactAvatar:(id)a0;
@end


#pragma mark - 配置


static NSString *const kDDWxidEnabledKey  = @"DDProfileWxidEnabled";
static NSString *const kDDWxidValueKey    = @"DDProfileWxidValue";
static NSString *const kDDAvatarEnabledKey = @"DDProfileAvatarEnabled";

@interface DDProfileConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL wxidEnabled;
@property (nonatomic, copy) NSString *wxidValue;
@property (nonatomic) BOOL avatarEnabled;
@end


#pragma mark - 头像文件管理
// 按用户名直接落盘，文件名即 userName（去掉非字母数字字符），存在就有、不存在就没有。


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

static UIImage *DDAvatarImageForUser(NSString *usrName) {
    if (![DDProfileConfig shared].avatarEnabled) return nil;
    NSString *path = DDAvatarPathForUser(usrName);
    if (!path) return nil;
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    return (img && img.size.width > 0 && img.size.height > 0) ? img : nil;
}

// 等比缩到最大边 maxSide，避免原图过大拖慢列表渲染。
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
    return [data writeToFile:path atomically:YES];
}

static BOOL DDAvatarRemoveForUser(NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!path) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
    return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

static NSInteger DDAvatarRemoveAll(void) {
    NSString *dir = DDAvatarDir();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSInteger n = 0;
    for (NSString *f in files) {
        if (![f.pathExtension isEqualToString:@"png"]) continue;
        if ([[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil]) n++;
    }
    return n;
}


#pragma mark - 选图（微信原生 MMImagePickerManager）
// 走微信自己的选图 + 裁剪链路：MMImagePickerManager + MMImagePickerManagerOptionObj
//   (MMImagePickerManager.h:82  showWithOptionObj:inViewController:delegate:)
// 回调方法名由两处原生实现确证：TakeOrSelectHeadImageLogic.h:17、NewRemarkViewController.h:290
//   MMImagePickerManager:didFinishPickingImageWithInfo: / MMImagePickerManagerDidCancel:
// 仍用独立代理对象承接，不往微信 VC 上加同名 %new 方法——该 VC 自己已有
// imagePickerController:didFinishPickingMediaWithInfo:(AddContactToChatRoomViewController.h:76)。
// 注意 m_delegate 是 weak(MMImagePickerManager.h:12)，manager 必须自己强引用住。


typedef void (^DDAvatarPickCompletion)(UIImage *image);

// info 的 key 由微信内部决定，做通用提取：先按系统 key 取，取不到就遍历值找 UIImage。
static UIImage *DDExtractImageFromInfo(id info) {
    if (!info) return nil;
    if ([info isKindOfClass:[UIImage class]]) return (UIImage *)info;
    if (![info isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *dic = (NSDictionary *)info;
    UIImage *img = dic[UIImagePickerControllerEditedImage] ?: dic[UIImagePickerControllerOriginalImage];
    if (img) return img;
    for (id value in dic.allValues) {
        if ([value isKindOfClass:[UIImage class]]) return (UIImage *)value;
    }
    return nil;
}

@interface DDAvatarPicker : NSObject
@property (nonatomic, copy) DDAvatarPickCompletion completion;
@property (nonatomic, strong) MMImagePickerManager *pickerManager;
+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion;
@end

@implementation DDAvatarPicker

// 强引用持有：代理和 manager 都得活到选图结束。
static DDAvatarPicker *gDDAvatarPicker = nil;

+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion {
    if (!vc) return;

    MMImagePickerManagerOptionObj *option = [[%c(MMImagePickerManagerOptionObj) alloc] init];
    option.maxImageCount = 1;            // 头像只要一张
    option.canSendMultiImage = NO;
    option.disableVideoSelection = YES;  // 只要图片，不要视频
    option.imageDirectToEditMode = YES;  // 选完直接进裁剪页
    option.m_directToFirstAlbum = YES;

    MMImagePickerManager *manager = [[%c(MMImagePickerManager) alloc] init];
    DDAvatarPicker *proxy = [[DDAvatarPicker alloc] init];
    proxy.completion = completion;
    proxy.pickerManager = manager;       // 强引用，否则 m_delegate(weak) 一放就断
    manager.m_delegate = (id)proxy;
    gDDAvatarPicker = proxy;

    [manager showWithOptionObj:option inViewController:vc delegate:(id)proxy];
}

- (void)MMImagePickerManager:(id)manager didFinishPickingImageWithInfo:(id)info {
    UIImage *image = DDExtractImageFromInfo(info);
    DDAvatarPickCompletion cb = self.completion;
    gDDAvatarPicker = nil;
    if (cb) cb(image);
}

- (void)MMImagePickerManagerDidCancel:(id)manager {
    DDAvatarPickCompletion cb = self.completion;
    gDDAvatarPicker = nil;
    if (cb) cb(nil);
}

@end


#pragma mark - 自定义微信号（只改自己）


// 开关未开或没填值就返回 nil，各 hook 点原样走 %orig。
static NSString *DDCustomWxid(void) {
    DDProfileConfig *cfg = [DDProfileConfig shared];
    if (!cfg.wxidEnabled) return nil;
    NSString *value = cfg.wxidValue;
    if (value.length == 0) return nil;
    return value;
}

%hook CSetting

- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom) return custom;
    return %orig;
}

%end

%hook CBaseContact

- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom && [self isSelf]) return custom;
    return %orig;
}

%end


#pragma mark - 头像替换（显示侧）


%hook MMHeadImageView

// 同步写图入口：命中本地图就直接换成本地图，不再显示网络头像。
- (void)updateHeadImage:(id)image {
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    %orig(custom ?: image);
}

// 设置用户名 + 头像地址时补一次，避免首屏没走到 updateHeadImage:。
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl {
    %orig(usrName, headImgUrl);
    UIImage *custom = DDAvatarImageForUser(usrName ?: [self nsUsrName]);
    if (custom) [self updateHeadImage:custom];
}

// 网络头像异步下载完成会走这里，不拦的话本地图会被真头像盖掉。
- (void)ImageDidLoad:(id)image Url:(id)url {
    %orig(image, url);
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    if (custom) [self updateHeadImage:custom];
}

%end


#pragma mark - 头像修改入口（单聊「聊天信息」页）


static NSString *const kDDAvatarCellId = @"DDProfileAvatarCell";

%hook AddContactToChatRoomViewController

// 微信不同版本构建聊天详情页的时机不同：有的走 reloadTableData，有的只在 viewWillAppear 之后才算构建完。
// 这里双入口注入，靠 cell 的 userInfo 去重，不会重复插行。
- (void)reloadTableData {
    %orig;
    [self dd_injectAvatarCellIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self dd_injectAvatarCellIfNeeded];
}

%new
- (void)dd_injectAvatarCellIfNeeded {
    // 全局总开关关闭时不注入聊天详情页入口。
    if (![DDProfileConfig shared].avatarEnabled) return;

    CContact *contact = [self m_contact];
    if (!contact) return;
    // 群聊不支持，直接跳过。
    if ([contact isChatroom]) return;

    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    WCTableViewManager *info = nil;
    @try {
        info = (WCTableViewManager *)[self valueForKey:@"m_tableViewInfo"];
    } @catch (NSException *e) {
        info = nil;
    }
    if (!info) return;

    // 详情页第一个分组：把「自定义头像」开关作为它的首行插入。
    id firstSection = nil;
    @try {
        firstSection = [info getSectionAt:0];
    } @catch (NSException *e) {
        firstSection = nil;
    }
    if (!firstSection) return;

    // 已注入则跳过（每次 reloadTableData 都会走到，靠 cell 的 userInfo 去重）。
    for (id c in [firstSection getAllCells]) {
        if ([[c userInfo] isEqual:kDDAvatarCellId]) return;
    }

    // 原生 switchCell：on 状态取决于当前联系人是否已保存本地头像(WCTableViewCellManager.h:55)。
    Class cellCls = %c(WCTableViewCellManager);
    BOOL hasCustom = DDAvatarImageForUser(usrName) != nil;
    id cell = [cellCls switchCellForSel:@selector(toggleCustomContactAvatar:)
                                target:self
                                 title:@"自定义头像"
                                    on:hasCustom];
    [cell setUserInfo:kDDAvatarCellId];
    [firstSection insertCell:cell At:0];
    [info reloadTableView];
}

// 复用微信原生的「自定义头像」开关 action（AddContactToChatRoomViewController.h:66）：
// 上面插入的开关 cell 把 sel 指向它，逻辑统一在这里实现，不再自己起 dd_ 前缀方法。
// 不依赖传入参数判断状态，改以「当前联系人是否已有本地头像」决定开/关，规避参数签名不确定的风险。
- (void)toggleCustomContactAvatar:(id)a0 {
    CContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    if (DDAvatarImageForUser(usrName)) {
        // 当前有图 -> 切换为关闭，删除本地图片。
        DDAvatarRemoveForUser(usrName);
        [[%c(WeToast) toast] showDoneToastWithText:@"已恢复默认头像"];
    } else {
        // 当前无图 -> 切换为打开，调起微信相册选图并裁剪。
        __weak typeof(self) weakSelf = self;
        [DDAvatarPicker presentFromViewController:self completion:^(UIImage *image) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (!image) {
                [strongSelf reloadTableData];
                return;
            }
            if (!DDAvatarSaveImage(image, usrName)) {
                [[%c(WeToast) toast] showErrorToastWithText:@"保存失败"];
            } else {
                [[%c(WeToast) toast] showDoneToastWithText:@"头像已替换"];
            }
            [strongSelf reloadTableData];
        }];
    }
}

%end


#pragma mark - 设置页


@interface DDProfileSettingsViewController : UIViewController
@end

@implementation DDProfileSettingsViewController {
    WCTableViewManager *_tableViewManager;
    UITextField *_wxidField;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小丑资料设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:[[UIScreen mainScreen] bounds]
                                                                                     style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];

    [self buildTable];
}

- (UIView *)inputRowWithField:(UITextField *)field
                       action:(SEL)action
                  placeholder:(NSString *)placeholder
                         text:(NSString *)text
                     keyboard:(UIKeyboardType)keyboard {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    container.backgroundColor = [UIColor clearColor];

    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
    field.placeholder = placeholder;
    field.text = text;
    field.textAlignment = NSTextAlignmentRight;
    field.keyboardType = keyboard;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
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

- (void)buildTable {
    DDProfileConfig *cfg = [DDProfileConfig shared];
    Class cellCls = %c(WCTableViewCellManager);

    WCTableViewSectionManager *wxidSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"微信号"];
    wxidSection.footerTitle = @"开启后只改变你自己的微信号显示，不修改服务器数据；关闭开关即恢复真实微信号";
    [wxidSection addCell:[cellCls switchCellForSel:@selector(wxidSwitchChanged:)
                                            target:self
                                             title:@"自定义微信号"
                                                on:cfg.wxidEnabled]];
    if (cfg.wxidEnabled) {
        _wxidField = [[UITextField alloc] init];
        UIView *right = [self inputRowWithField:_wxidField
                                        action:@selector(wxidConfirm:)
                                   placeholder:@"例如：wxid_abc123"
                                          text:cfg.wxidValue ?: @""
                                      keyboard:UIKeyboardTypeASCIICapable];
        [wxidSection addCell:[cellCls normalCellForSel:nil
                                               target:nil
                                                title:@"↳目标微信号"
                                            rightView:right]];
    }
    [_tableViewManager addSection:wxidSection];

    WCTableViewSectionManager *avatarSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"自定义用户头像"];
    avatarSection.footerTitle = @"开启后可在单聊「聊天信息」页替换联系人头像；关闭后不再显示替换入口，也不替换头像";
    [avatarSection addCell:[cellCls switchCellForSel:@selector(avatarSwitchChanged:)
                                               target:self
                                                title:@"备注用户头像"
                                                   on:cfg.avatarEnabled]];
    [avatarSection addCell:[cellCls normalCellForSel:@selector(clearAllAvatarTapped:)
                                               target:self
                                                title:@"一键全部还原"
                                           rightValue:@"清理"]];
    [_tableViewManager addSection:avatarSection];
}

- (void)wxidSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDProfileConfig shared].wxidEnabled = sw.on;
    [self rebuild];
}

- (void)wxidConfirm:(id)sender {
    NSString *text = [_wxidField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [DDProfileConfig shared].wxidValue = text;
    [_wxidField resignFirstResponder];
    [[%c(WeToast) toast] showDoneToastWithText:(text.length ? @"已保存" : @"已清空")];
    [self rebuild];
}

- (void)avatarSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDProfileConfig shared].avatarEnabled = sw.on;
    [self rebuild];
}

- (void)clearAllAvatarTapped:(id)sender {
    NSInteger n = DDAvatarRemoveAll();
    [[%c(WeToast) toast] showDoneToastWithText:(n > 0 ? [NSString stringWithFormat:@"已清除 %ld 个", (long)n] : @"暂无替换")];
}

- (void)rebuild {
    // 开关 / 输入变化后重建整表：移除旧 tableView，重建 manager 再灌数据。
    for (UIView *v in self.view.subviews) {
        if ([v isKindOfClass:[UITableView class]]) [v removeFromSuperview];
    }
    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:[[UIScreen mainScreen] bounds]
                                                                                     style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];
    [self buildTable];
    [_tableViewManager reloadTableView];
}

@end


#pragma mark - 配置实现


@implementation DDProfileConfig

+ (instancetype)shared {
    static DDProfileConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDProfileConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        _wxidEnabled = [def boolForKey:kDDWxidEnabledKey];
        _wxidValue = [def stringForKey:kDDWxidValueKey] ?: @"";
        _avatarEnabled = [def boolForKey:kDDAvatarEnabledKey];
    }
    return self;
}

- (void)setWxidEnabled:(BOOL)wxidEnabled {
    _wxidEnabled = wxidEnabled;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:wxidEnabled forKey:kDDWxidEnabledKey];
    [def synchronize];
}

- (void)setWxidValue:(NSString *)wxidValue {
    _wxidValue = wxidValue ?: @"";
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setObject:_wxidValue forKey:kDDWxidValueKey];
    [def synchronize];
}

- (void)setAvatarEnabled:(BOOL)avatarEnabled {
    _avatarEnabled = avatarEnabled;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setBool:avatarEnabled forKey:kDDAvatarEnabledKey];
    [def synchronize];
}

@end


#pragma mark - 插件注册


%ctor {
    @autoreleasepool {
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑资料"
                                 version:@"1.0.0"
                              controller:@"DDProfileSettingsViewController"];
    }
}
