//
//  ScanQRCodeViewController.m
//  ScanQRCodeDemo
//
//  Created by Bob on 2017/7/6.
//  Copyright © 2017年 ddl. All rights reserved.
//
#define kScreen_Width [UIScreen mainScreen].bounds.size.width
#define kScreen_Height [UIScreen mainScreen].bounds.size.height
#import "ScanQRCodeViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <CoreImage/CoreImage.h>
@interface ScanQRCodeViewController ()<AVCaptureMetadataOutputObjectsDelegate,UIImagePickerControllerDelegate,UIAlertViewDelegate>
@property(nonatomic,strong)AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic,assign)BOOL hasScanQR;
@property(nonatomic,strong)CIDetector *detector;
@property(nonatomic,strong)UIImageView *scanRectView;
@property(nonatomic,strong)UIImageView *scanLine;
@property(nonatomic,strong)UILabel *tipLabel;
@end

@implementation ScanQRCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"扫描识别二维码";
    self.view.backgroundColor = [UIColor clearColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"相册"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(accessPhotoLibrary)];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [self judgeCameraAuthorization];
    
}
- (CIDetector*)detector{
    if (!_detector) {
         _detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy:CIDetectorAccuracyHigh}];
    }
    return _detector;
}
//相机权限
-(void)judgeCameraAuthorization{
    AVAuthorizationStatus authorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (authorizationStatus) {
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler: ^(BOOL granted) {
                if (granted) {
                    [self setupUI];
                } else {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"error" message:@"相机访问受限" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
                    [alert show];
                    [self.navigationController popViewControllerAnimated:YES];
                }
            }];
            break;
        }
            
        case AVAuthorizationStatusAuthorized: {
            [self setupUI];
            break;
        }
            
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied: {
             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"error" message:@"相机访问受限" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
            [self.navigationController popViewControllerAnimated:YES];
            break;
        }
            
        default: {
            break;
        }
    }
}
//照片权限
-(BOOL)judgePhotoAuthorization{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (PHAuthorizationStatusRestricted==status || PHAuthorizationStatusDenied==status) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Tip" message:@"照片访问权限受阻,请在iPhone的“设置->隐私->照片”中打开本应用的访问权限" delegate:nil
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        return NO;
    }
    return YES;
}
- (void)setupUI{
    CGFloat width = kScreen_Width*2/3;
    CGFloat padding = (kScreen_Width-width)/2;
    CGRect scanRect = CGRectMake(padding, kScreen_Height/5, width, width);
    if (!_previewLayer) {
        NSError *error;
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (!input) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
            [self.navigationController popViewControllerAnimated:YES];
        }
        AVCaptureSession* session = [[AVCaptureSession alloc] init];
        [session addInput:input];
        AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
        [output setMetadataObjectsDelegate:self queue:dispatch_queue_create("capture_queue", NULL)];
        [session addOutput:output];
        output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureInputPortFormatDescriptionDidChangeNotification object:nil queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification * _Nonnull note) {
            output.rectOfInterest =[_previewLayer metadataOutputRectOfInterestForRect:scanRect];
        }];
        if (!_scanRectView) {
            _scanRectView = [[UIImageView alloc] initWithFrame:scanRect];
            _scanRectView.contentMode = PHImageContentModeAspectFill;
            _scanRectView.image = [[UIImage imageNamed:@"scan_bg"] resizableImageWithCapInsets:UIEdgeInsetsMake(25, 25, 25, 25)];
            _scanRectView.clipsToBounds = YES;
        }
        if (!_scanLine) {
            _scanLine = [[UIImageView alloc] initWithFrame:CGRectMake(0, -2, width, 2)];
            _scanLine.image = [UIImage imageNamed:@"scan_line"];
            _scanLine.contentMode = PHImageContentModeAspectFill;
            
        }
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
        [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        _previewLayer.frame = self.view.bounds;
        [self.view.layer insertSublayer:_previewLayer atIndex:0];
        [self.view addSubview:_scanRectView];
        [_scanRectView addSubview:_scanLine];
        [self startScan];
    }
    
    
}
- (void)viewWillAppear:(BOOL)animated{
    [self startScan];
}
-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self stopScan];
}

#pragma mark -AVCaptureMetadataOutputObjectsDelegate

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects
      fromConnection:(AVCaptureConnection *)connection{
    if (metadataObjects.count>0) {
        __block AVMetadataMachineReadableCodeObject *result = nil;
        [metadataObjects enumerateObjectsUsingBlock:^(AVMetadataMachineReadableCodeObject *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.type isEqualToString:CIDetectorTypeQRCode]) {
                result = obj;
                *stop = YES;
            }
        }];
        if (!result) {
            result = [metadataObjects firstObject];
        }
        [self analyseResult:result];
    }
}
- (void)analyseResult:(AVMetadataMachineReadableCodeObject*)result{
    if ([result isKindOfClass:[AVMetadataMachineReadableCodeObject class]] & !self.hasScanQR) {
        NSString *stringValue = result.stringValue;
        NSLog(@"%@",stringValue);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Tip" message:stringValue delegate:self cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil, nil];

        [alert show];
        self.hasScanQR = YES;
    }
    
}
- (void)stopScan{
    [self scanLineStopAnimation];
    [self.previewLayer.session stopRunning];
}
- (void)startScan{
    [self.previewLayer.session startRunning];
    [self scanLineStartAnimation];
}
- (void)scanLineStartAnimation{
    [self scanLineStopAnimation];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position.y"];
    animation.fromValue = @(-CGRectGetHeight(_scanLine.frame));
    animation.toValue = @(CGRectGetHeight(_scanRectView.frame));
    animation.repeatCount = MAXFLOAT;
    animation.duration = 2.0;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_scanLine.layer addAnimation:animation forKey:@"animation"];
}
- (void)scanLineStopAnimation{
    [_scanLine.layer removeAllAnimations];
}
- (void)accessPhotoLibrary{
    if (![self judgePhotoAuthorization]) {
        return;
    }
    [self stopScan];
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}
//识别二维码图片
- (void)scanImageQRCode:(NSDictionary*)info{
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    if (!image) {
        image = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    CIQRCodeFeature *feature = (CIQRCodeFeature*)[[self.detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]] firstObject];
    if (feature) {
        UIAlertView  *alert = [[UIAlertView alloc] initWithTitle:@"Tip" message:feature.messageString delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }else{
        UIAlertView  *alert = [[UIAlertView alloc] initWithTitle:@"Tip" message:@"无法识别二维码" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }
    [self startScan];
}

#pragma mark - UIAlertViewDelegate
-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    self.hasScanQR = NO;
}
#pragma mark - UIImagePickerControllerDelegate
-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    [picker dismissViewControllerAnimated:YES completion:^{
        [self scanImageQRCode:info];
    }];
}
#pragma mark Notification
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self startScan];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self stopScan];
}

-(void)dealloc{
    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
