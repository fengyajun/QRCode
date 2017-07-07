//
//  ViewController.m
//  ScanQRCodeDemo
//
//  Created by Bob on 2017/7/6.
//  Copyright © 2017年 ddl. All rights reserved.
//

#import "ViewController.h"
#import "ScanQRCodeViewController.h"
#import <Photos/Photos.h>
@interface ViewController ()<UIAlertViewDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *QRCodeImage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(IBAction)scanButton:(id)sender{
    ScanQRCodeViewController *scanController = [ScanQRCodeViewController new];
    [self.navigationController pushViewController:scanController animated:YES];

}
-(IBAction)makeQRCode:(id)sender{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"输入要生成二维码的文本" message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (!buttonIndex) {
        [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
    }else{
        NSString *QRCodeText = [alertView textFieldAtIndex:0].text;
        if (!QRCodeText) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Tip" message:@"文本不能为空" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
        }else{
            NSData *data = [QRCodeText dataUsingEncoding:NSUTF8StringEncoding];
            CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
            [filter setValue:data forKey:@"inputMessage"];
            CIImage *ciImage = filter.outputImage;
            CGFloat scale = CGRectGetWidth(self.QRCodeImage.bounds)/CGRectGetWidth(ciImage.extent);
            CIImage *transformImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(scale ,scale)];
            self.QRCodeImage.image = [[UIImage imageWithCIImage:transformImage] resizableImageWithCapInsets:UIEdgeInsetsMake(20, 20, 20, 20)];
            UIImageWriteToSavedPhotosAlbum(self.QRCodeImage.image, self, nil, NULL);
//            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
//                
//                //写入图片到相册
//                PHAssetChangeRequest *req = [PHAssetChangeRequest creationRequestForAssetFromImage:self.QRCodeImage.image];
//                
//                
//            } completionHandler:^(BOOL success, NSError * _Nullable error) {
//                
//                NSLog(@"success = %d, error = %@", success, error);
//                
//            }];
        }
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
}
-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO];
}
@end
