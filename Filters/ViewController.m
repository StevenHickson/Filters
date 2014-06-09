//
//  ViewController.m
//  Filters
//
//  Created by Steven Hickson on 6/7/14.
//  Copyright (c) 2014 Fyusion. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage.h"

@interface ViewController ()
{
    UIImage *originalImage;
    GPUImageMaskFilter *maskFilter;
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
    UIImage *maskImage = [UIImage imageNamed:@"mask4"];
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

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
