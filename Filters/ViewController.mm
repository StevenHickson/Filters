//
//  ViewController.m
//  Filters
//
//  Created by Steven Hickson on 6/7/14.
//  Copyright (c) 2014 Fyusion. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage.h"
#import <opencv2/opencv.hpp>
#import <opencv2/core.hpp>

@interface ViewController ()
{
    UIImage *originalImage;
    GPUImageMaskFilter *maskFilter;
    UIPinchGestureRecognizer *pinchGestureRecognizer;
    int circleX, circleY, circleR;
}

@property(nonatomic, weak) IBOutlet UIImageView *selectedImageView;
@property(nonatomic, weak) IBOutlet UIBarButtonItem *filterButton;
@property(nonatomic, weak) IBOutlet UIBarButtonItem *saveButton;

- (IBAction)photoFromAlbum;
- (IBAction)photoFromCamera;
- (IBAction)applyImageFilter:(id)sender;
- (IBAction)saveImageToAlbum;

@end

@implementation ViewController

@synthesize selectedImageView, filterButton, saveButton;

+ (UIImage *)imageWithCVMat:(const cv::Mat&)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize() * cvMat.total()];
    
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                     // Width
                                        cvMat.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * cvMat.elemSize(),                           // Bits per pixel
                                        cvMat.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        kCGImageAlphaNone | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return image;
}

cv::Mat makeCircle(const int width, const int height, const int x, const int y, const int radius) {
    cv::Mat result = cv::Mat::zeros(height,width, CV_8UC1);
    circle(result,cv::Point(x,y),radius,cv::Scalar(255),-1);
    return result;
}

- (IBAction)photoFromAlbum
{
    UIImagePickerController *photoPicker = [[UIImagePickerController alloc] init];
    photoPicker.delegate = self;
    photoPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self presentViewController:photoPicker animated:YES completion:NULL];
    
}

- (IBAction)photoFromCamera
{
    UIImagePickerController *photoPicker = [[UIImagePickerController alloc] init];
    
    photoPicker.delegate = self;
    photoPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    [self presentViewController:photoPicker animated:YES completion:NULL];
    
}

- (void)imagePickerController:(UIImagePickerController *)photoPicker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.saveButton.enabled = YES;
    self.filterButton.enabled = YES;
    
    originalImage = [info valueForKey:UIImagePickerControllerOriginalImage];
    
    [self.selectedImageView setImage:originalImage];
    
    [photoPicker dismissModalViewControllerAnimated:YES];
}

- (IBAction)saveImageToAlbum
{
    UIImageWriteToSavedPhotosAlbum(self.selectedImageView.image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSString *alertTitle;
    NSString *alertMessage;
    
    if(!error)
    {
        alertTitle   = @"Image Saved";
        alertMessage = @"Image saved to photo album successfully.";
    }
    else
    {
        alertTitle   = @"Error";
        alertMessage = @"Unable to save to photo album.";
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:alertTitle
                                                    message:alertMessage
                                                   delegate:self
                                          cancelButtonTitle:@"Okay"
                                          otherButtonTitles:nil];
    [alert show];
}

- (IBAction)applyImageFilter:(id)sender
{
    UIActionSheet *filterActionSheet = [[UIActionSheet alloc] initWithTitle:@"Select Filter"
                                                                   delegate:self
                                                          cancelButtonTitle:@"Cancel"
                                                     destructiveButtonTitle:nil
                                                          otherButtonTitles:@"Grayscale", @"Sepia", @"Sketch", @"Pixellate", @"Color Invert", @"Toon", @"Pinch Distort", @"None", nil];
    
    [filterActionSheet showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    GPUImageFilter *selectedFilter;
    
    switch (buttonIndex) {
        case 0:
            selectedFilter = [[GPUImageGrayscaleFilter alloc] init];
            break;
        case 1:
            selectedFilter = [[GPUImageSepiaFilter alloc] init];
            break;
        case 2:
            selectedFilter = [[GPUImageSketchFilter alloc] init];
            break;
        case 3:
            selectedFilter = [[GPUImagePixellateFilter alloc] init];
            break;
        case 4:
            selectedFilter = [[GPUImageColorInvertFilter alloc] init];
            break;
        case 5:
            selectedFilter = [[GPUImageToonFilter alloc] init];
            break;
        case 6:
            selectedFilter = [[GPUImagePinchDistortionFilter alloc] init];
            break;
        case 7:
            selectedFilter = [[GPUImageFilter alloc] init];
            break;
        default:
            break;
    }
    
    GPUImagePicture *imageToProcess = [[GPUImagePicture alloc] initWithImage:originalImage smoothlyScaleOutput:YES];
    
    maskFilter = [[GPUImageMaskFilter alloc] init];
    //[maskFilter setBackgroundColorRed:1.0 green:0.0 blue:0.0 alpha:1.0];
    //UIImage *maskImage = [UIImage imageNamed:@"mask4"];
    cv::Mat tmpMat = makeCircle(originalImage.size.width,originalImage.size.height,circleX,circleY,circleR);
    UIImage *maskImage = [ViewController imageWithCVMat:tmpMat];
    GPUImagePicture* maskPicture = [[GPUImagePicture alloc] initWithImage:maskImage smoothlyScaleOutput:YES];
    
    //Proper order is addTarget, useNextFrame, processImage, imageFromCurrentFrameBuffer
    
//    Note that for a manual capture of an image from a filter, you need to set -useNextFrameForImageCapture in order to tell the filter that you'll be needing to capture from it later. By default, GPUImage reuses framebuffers within filters to conserve memory, so if you need to hold on to a filter's framebuffer for manual image capture, you need to let it know ahead of time. 
    
    //If I switch these around, weird things happen
    [imageToProcess addTarget:maskFilter];
    
    //[imageToProcess processImage];
    [maskFilter useNextFrameForImageCapture];
    
    [maskPicture addTarget:maskFilter];
    //[maskPicture processImage];
    
    //need to apply selected filter to the result of maskFilter.
    [maskFilter addTarget:selectedFilter];
    [selectedFilter useNextFrameForImageCapture];
    //[imageToProcess processImage];
    [maskPicture processImage];
    
    GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
    blendFilter.mix = 1.0f;
    
    //the order of these matters a lot
    [imageToProcess addTarget:blendFilter];
    [selectedFilter addTarget:blendFilter];
    //I need useNextFrameForImageCapture or it crashes.
    [blendFilter useNextFrameForImageCapture];
    [imageToProcess processImage];
    
    UIImage *filteredImage = [blendFilter imageFromCurrentFramebuffer];
    
    [self.selectedImageView setImage:filteredImage];
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)pinchGesture
{
    CGPoint imageViewPoint = [pinchGesture locationInView:selectedImageView];
    
    float percentX = imageViewPoint.x / selectedImageView.frame.size.width;
    float percentY = imageViewPoint.y / selectedImageView.frame.size.height;
    
    float x = originalImage.size.width * percentX;
    float y = originalImage.size.height * percentY;
    
    //1
    if (pinchGesture.state == UIGestureRecognizerStateBegan) {
        circleX = int(x);
        circleY = int(y);
        NSLog(@"X: %f, Y: %f", x,y);
    }
    
    //2
    //if ([pinchGesture numberOfTouches] == 2) {
    
    //3
    if (pinchGesture.state == UIGestureRecognizerStateEnded) {
        float diffX = x - circleX;
        float diffY = y - circleY;
        circleR = int(sqrt(diffX*diffX + diffY*diffY));
        NSLog(@"Radius: %d, percentX: %f, percentY: %f",circleR,percentX,percentY);
        //NSLog(@"%f",pinchGesture.scale);
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    [pinchGestureRecognizer setDelegate:(id)self];
    [self.view addGestureRecognizer:pinchGestureRecognizer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
