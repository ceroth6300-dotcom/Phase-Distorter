#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include "eb/game_session.hpp"
#include "eb/asset_store.hpp"
#include "generated_assets.hpp"
#include <memory>
#include <vector>
#include <filesystem>

@interface PhaseController : UIViewController <UIDocumentPickerDelegate>
@end
@implementation PhaseController {
    UILabel *_status;
    UIImageView *_screen;
    CADisplayLink *_clock;
    std::vector<uint8_t> _image;
    std::unique_ptr<eb::GameSession> _session;
    uint16_t _buttons;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    _screen = [[UIImageView alloc] init];
    _screen.contentMode = UIViewContentModeScaleAspectFit;
    _screen.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_screen];
    _status = [[UILabel alloc] init];
    _status.text = @"Phase Distorter — Select your own ROM";
    _status.textColor = UIColor.whiteColor;
    _status.textAlignment = NSTextAlignmentCenter;
    _status.numberOfLines = 3;
    _status.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_status];
    UIButton *importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [importButton setTitle:@"Import ROM" forState:UIControlStateNormal];
    importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [importButton addTarget:self action:@selector(selectROM) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:importButton];
    [NSLayoutConstraint activateConstraints:@[
        [_screen.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [_screen.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [_screen.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [_screen.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.52],
        [_status.topAnchor constraintEqualToAnchor:_screen.bottomAnchor constant:8],
        [_status.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_status.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [importButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [importButton.topAnchor constraintEqualToAnchor:_status.bottomAnchor constant:12]
    ]];
    NSArray<NSString *> *names = @[@"↑",@"↓",@"←",@"→",@"B",@"A",@"Y",@"X",@"L",@"R",@"Start",@"Select"];
    // SNES buttons are active-low; start with all released.
    _buttons = 0;
    UIStackView *rows = [[UIStackView alloc] init];
    rows.axis = UILayoutConstraintAxisVertical;
    rows.spacing = 8;
    rows.distribution = UIStackViewDistributionFillEqually;
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:rows];
    for (NSInteger r=0;r<3;r++) {
        UIStackView *line = [[UIStackView alloc] init];
        line.axis = UILayoutConstraintAxisHorizontal;
        line.spacing = 8;
        line.distribution = UIStackViewDistributionFillEqually;
        [rows addArrangedSubview:line];
        for (NSInteger c=0;c<4;c++) {
            NSInteger idx=r*4+c;
            UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
            [b setTitle:names[idx] forState:UIControlStateNormal];
            b.tag=idx;
            b.backgroundColor=[UIColor colorWithWhite:0.2 alpha:1];
            b.layer.cornerRadius=9;
            [b addTarget:self action:@selector(down:) forControlEvents:UIControlEventTouchDown];
            [b addTarget:self action:@selector(up:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
            [line addArrangedSubview:b];
        }
    }
    [NSLayoutConstraint activateConstraints:@[
        [rows.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [rows.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [rows.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        [rows.heightAnchor constraintEqualToConstant:140]
    ]];
}
- (void)down:(UIButton *)button {
    const int bits[]={4,5,6,7,0,8,1,9,10,11,3,2};
    _buttons |= (uint16_t)(1u << bits[button.tag]);
}
- (void)up:(UIButton *)button {
    const int bits[]={4,5,6,7,0,8,1,9,10,11,3,2};
    _buttons &= (uint16_t)~(1u << bits[button.tag]);
}
- (void)selectROM {
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.delegate=self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url=urls.firstObject;
    if (!url) return;
    @try {
        try {
            auto profiles=eb::asset_profiles();
            const auto &profile=eb::identify_rom(std::filesystem::path(url.path.UTF8String),profiles);
            NSString *base=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES) firstObject];
            NSString *pack=[base stringByAppendingPathComponent:(profile.version==eb::GameVersion::US?@"earthbound.ebpak":@"mother2.ebpak")];
            eb::import_game_assets(std::filesystem::path(url.path.UTF8String),std::filesystem::path(pack.UTF8String),profiles);
            auto assets=eb::load_game_assets(std::filesystem::path(pack.UTF8String),profiles);
            _session.reset();
            _image=std::move(assets.image);
            _session=std::make_unique<eb::GameSession>(_image,assets.version);
            _session->configure_presentation(256,false,false);
            _status.text=@"Game engine running (video only; audio not yet connected)";
            [_clock invalidate];
            _clock=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
            _clock.preferredFramesPerSecond=60;
            [_clock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        } catch(const std::exception &e) {
            _status.text=[NSString stringWithUTF8String:e.what()];
        }
    } @catch(NSException *ex) { _status.text=ex.reason; }
}
- (void)tick {
    if (!_session) return;
    try {
        _session->advance_frame(_buttons);
        auto pixels=_session->native_pixels();
        CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
        // Framebuffer format needs validation against the source renderer.
        CGDataProviderRef provider=CGDataProviderCreateWithData(NULL,pixels.data(),pixels.size_bytes(),NULL);
        CGImageRef cg=CGImageCreate(256,224,8,32,256*4,cs,kCGBitmapByteOrder32Little|kCGImageAlphaNoneSkipFirst,provider,NULL,false,kCGRenderingIntentDefault);
        if(cg) { _screen.image=[UIImage imageWithCGImage:cg]; CGImageRelease(cg); }
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(cs);
        // UIKit image has retained/copied its image reference by this point.
        (void)_session->take_audio_samples();
    } catch(const std::exception &e) {
        [_clock invalidate];
        _status.text=[NSString stringWithUTF8String:e.what()];
    }
}
@end
@interface PhaseDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation PhaseDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[[PhaseController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc,char **argv) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(PhaseDelegate.class)); } }
