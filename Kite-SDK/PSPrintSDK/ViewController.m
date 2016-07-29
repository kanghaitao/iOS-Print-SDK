//
//  Modified MIT License
//
//  Copyright (c) 2010-2016 Kite Tech Ltd. https://www.kite.ly
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The software MAY ONLY be used with the Kite Tech Ltd platform and MAY NOT be modified
//  to be used with any competitor platforms. This means the software MAY NOT be modified
//  to place orders with any competitors to Kite Tech Ltd, all orders MUST go through the
//  Kite Tech Ltd platform servers.
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

/**********************************************************************
 * Insert your API keys here. These are found under your profile
 * by logging in to the developer portal at https://www.kite.ly
 **********************************************************************/
static NSString *const kAPIKeySandbox = @"REPLACE_WITH_YOUR_API_KEY"; // replace with your Sandbox API key found under the Profile section in the developer portal
static NSString *const kAPIKeyLive = @"REPLACE_WITH_YOUR_API_KEY"; // replace with your Live API key found under the Profile section in the developer portal

static NSString *const kApplePayMerchantIDKey = @"merchant.ly.kite.sdk"; // Replace with your merchant ID
static NSString *const kApplePayBusinessName = @"Kite.ly"; //Replace with your business name

#import "ViewController.h"
#import "OLKitePrintSDK.h"
#import "OLImageCachingManager.h"

@import Photos;

@interface ViewController () <UINavigationControllerDelegate, OLKiteDelegate>
@property (weak, nonatomic) IBOutlet UIButton *localPhotosButton;
@property (weak, nonatomic) IBOutlet UIButton *remotePhotosButton;
@property (nonatomic, weak) IBOutlet UISegmentedControl *environmentPicker;
@property (nonatomic, strong) OLPrintOrder* printOrder;
@end

@interface OLKitePrintSDK (Private)
+ (void)setUseStaging:(BOOL)staging;
@end

@implementation ViewController

-(void)viewDidAppear:(BOOL)animated{
    self.printOrder = [[OLPrintOrder alloc] init];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
#ifdef OL_KITE_OFFER_INSTAGRAM
    [OLKitePrintSDK setInstagramEnabledWithClientID:@"1af4c208cbdc4d09bbe251704990638f" secret:@"c8a5b1b1806f4586afad2f277cee1d5c" redirectURI:@"kitely://instagram-callback"];
#endif
    
#ifdef OL_KITE_OFFER_APPLE_PAY
    [OLKitePrintSDK setApplePayMerchantID:kApplePayMerchantIDKey];
    [OLKitePrintSDK setApplePayPayToString:kApplePayBusinessName];
#endif
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (IBAction)onButtonPrintLocalPhotos:(id)sender {
    if (![self isAPIKeySet]) return;
    
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined){
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
            if (status == PHAuthorizationStatusAuthorized){
                //TODO system image picker
            }
        }];
    }
    else{
        //TODO system image picker
    }
}

- (NSString *)apiKey {
    if ([self environment] == kOLKitePrintSDKEnvironmentSandbox) {
        return kAPIKeySandbox;
    } else {
        return kAPIKeyLive;
    }
}

- (NSString *)liveKey {
    return kAPIKeyLive;
}

- (NSString *)sandboxKey {
    return kAPIKeySandbox;
}

- (BOOL)isAPIKeySet {
#ifdef OL_KITE_CI_DEPLOY
    return YES;
#endif
    
    if (![[[NSProcessInfo processInfo]environment][@"OL_KITE_UI_TEST"] isEqualToString:@"1"]){
        if ([[self apiKey] isEqualToString:@"REPLACE_WITH_YOUR_API_KEY"] && ![OLKitePrintSDK apiKey]) {
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"API Key Required" message:@"Set your API keys at the top of ViewController.m before you can print. This can be found under your profile at http://kite.ly" preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:NULL]];
            [self presentViewController:ac animated:YES completion:NULL];
            return NO;
        }
    }
    else{
        [OLKitePrintSDK setAPIKey:[[NSProcessInfo processInfo]environment][@"TEST_API_KEY"] withEnvironment:kOLKitePrintSDKEnvironmentSandbox];
    }
    
    return YES;
}

- (OLKitePrintSDKEnvironment)environment {
    if (self.environmentPicker.selectedSegmentIndex == 0) {
        return kOLKitePrintSDKEnvironmentSandbox;
    } else {
        return kOLKitePrintSDKEnvironmentLive;
    }
}

- (void)printWithAssets:(NSArray *)assets {
#ifdef OL_KITE_CI_DEPLOY
    [self setupCIDeploymentWithAssets:assets];
    return;
#else
    if (![[[NSProcessInfo processInfo]environment][@"OL_KITE_UI_TEST"] isEqualToString:@"1"]){
        if (![self isAPIKeySet]) return;
        [OLKitePrintSDK setAPIKey:[self apiKey] withEnvironment:[self environment]];
    }
#endif
    
    OLKiteViewController *vc = [[OLKiteViewController alloc] initWithAssets:assets];
    vc.userEmail = @"";
    vc.userPhone = @"";
    vc.delegate = self;
    
    [self addCatsAndDogsImagePickersToKite:vc];
    
    [self presentViewController:vc animated:YES completion:NULL];
    
    //Register for push notifications
    NSUInteger types = (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
    [[UIApplication sharedApplication] registerUserNotificationSettings:
     [UIUserNotificationSettings settingsForTypes:types categories:nil]];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}
- (IBAction)onButtonPrintRemotePhotos:(id)sender {
    if (![self isAPIKeySet]) return;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Remote URLS" message:@"Feel free to Change hardcoded remote image URLs in ViewController.m onButtonPrintRemotePhotos:" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(id action){
        NSArray *assets = @[[OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/1.jpg"]],
                            [OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/2.jpg"]],
                            [OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/3.jpg"]],
                            [OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/4.jpg"]]];
        
        [self printWithAssets:assets];
    }]];
    [self presentViewController:ac animated:YES completion:NULL];
}

- (void)addCatsAndDogsImagePickersToKite:(OLKiteViewController *)kvc{
    OLImagePickerProviderCollection *dogsCollection = [[OLImagePickerProviderCollection alloc] initWithArray:@[[OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/5.jpg"]], [OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/6.jpg"]]] name:@"Dogs"];
    OLImagePickerProviderCollection *catsCollection = [[OLImagePickerProviderCollection alloc] initWithArray:@[[OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/1.jpg"]], [OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/2.jpg"]], [OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/3.jpg"]], [OLAsset assetWithURL:[NSURL URLWithString:@"https://s3.amazonaws.com/psps/sdk_static/4.jpg"]]] name:@"Cats"];
    [kvc addCustomPhotoProviderWithCollections:@[catsCollection, dogsCollection] name:@"Animals" icon:[UIImage imageNamed:@"dog"]];
}

#pragma mark - OLKiteDelete

- (BOOL)kiteControllerShouldAllowUserToAddMorePhotos:(OLKiteViewController *)controller {
    return YES;
}

//- (BOOL)shouldShowOptOutOfEmailsCheckbox{
//    return YES;
//}

//- (BOOL)shouldShowPhoneEntryOnCheckoutScreen{
//    return YES;
//}

- (IBAction)onButtonKiteClicked:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.kite.ly"]];
}

- (BOOL)shouldShowContinueShoppingButton{
    return YES;
}

- (void)logKiteAnalyticsEventWithInfo:(NSDictionary *)info{
#ifdef OL_KITE_VERBOSE
    NSLog(@"%@", info);
#endif
}

#pragma mark Internal

- (void)setupCIDeploymentWithAssets:(NSArray *)assets{
    BOOL shouldOfferAPIChange = YES;
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    if (!([pasteboard containsPasteboardTypes: [NSArray arrayWithObject:@"public.utf8-plain-text"]] && pasteboard.string.length == 40)) {
        shouldOfferAPIChange = NO;
    }
    
    if (shouldOfferAPIChange){
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Possible API key detected in clipboard", @"") message:NSLocalizedString(@"Do you want to use this instead of the built-in ones?", @"") preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", @"") style:UIAlertActionStyleDefault handler:^(id action){
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define OL_KITE_CI_DEPLOY_KEY @ STRINGIZE2(OL_KITE_CI_DEPLOY)
            [OLKitePrintSDK setAPIKey:OL_KITE_CI_DEPLOY_KEY withEnvironment:kOLKitePrintSDKEnvironmentSandbox];
            
#ifdef OL_KITE_OFFER_APPLE_PAY
            [OLKitePrintSDK setApplePayMerchantID:kApplePayMerchantIDKey];
#endif
            
            OLKiteViewController *vc = [[OLKiteViewController alloc] initWithAssets:assets info:@{}];
            vc.userEmail = @"";
            vc.userPhone = @"";
            vc.delegate = self;
            
            [self addCatsAndDogsImagePickersToKite:vc];
            
            [self presentViewController:vc animated:YES completion:NULL];
        }]];
        [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"") style:UIAlertActionStyleDefault handler:^(id action){
            [OLKitePrintSDK setAPIKey:pasteboard.string withEnvironment:[self environment]];
            
#ifdef OL_KITE_OFFER_APPLE_PAY
            [OLKitePrintSDK setApplePayMerchantID:kApplePayMerchantIDKey];
            [OLKitePrintSDK setApplePayPayToString:kApplePayBusinessName];
#endif
            
            OLKiteViewController *vc = [[OLKiteViewController alloc] initWithAssets:assets];
            vc.userEmail = @"";
            vc.userPhone = @"";
            vc.delegate = self;
            [self presentViewController:vc animated:YES completion:NULL];
        }]];
        [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes and use staging", @"") style:UIAlertActionStyleDefault handler:^(id action){
            [OLKitePrintSDK setUseStaging:YES];
            [OLKitePrintSDK setAPIKey:pasteboard.string withEnvironment:[self environment]];
            
#ifdef OL_KITE_OFFER_APPLE_PAY
            [OLKitePrintSDK setApplePayMerchantID:kApplePayMerchantIDKey];
            [OLKitePrintSDK setApplePayPayToString:kApplePayBusinessName];
#endif
            
            OLKiteViewController *vc = [[OLKiteViewController alloc] initWithAssets:assets];
            vc.userEmail = @"";
            vc.userPhone = @"";
            vc.delegate = self;
            
            [self addCatsAndDogsImagePickersToKite:vc];
            
            [self presentViewController:vc animated:YES completion:NULL];
        }]];
        [self presentViewController:ac animated:YES completion:NULL];
    }
    else{
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define OL_KITE_CI_DEPLOY_KEY @ STRINGIZE2(OL_KITE_CI_DEPLOY)
        [OLKitePrintSDK setAPIKey:OL_KITE_CI_DEPLOY_KEY withEnvironment:kOLKitePrintSDKEnvironmentSandbox];
        
#ifdef OL_KITE_OFFER_APPLE_PAY
        [OLKitePrintSDK setApplePayMerchantID:kApplePayMerchantIDKey];
#endif
        
        OLKiteViewController *vc = [[OLKiteViewController alloc] initWithAssets:assets];
        vc.userEmail = @"";
        vc.userPhone = @"";
        vc.delegate = self;
       
        [self addCatsAndDogsImagePickersToKite:vc];
        
        [self presentViewController:vc animated:YES completion:NULL];
    }
}

@end
