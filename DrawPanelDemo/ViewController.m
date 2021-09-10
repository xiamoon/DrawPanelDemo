//
//  ViewController.m
//  DrawPanelDemo
//
//  Created by liqian on 2021/9/10.
//

#import "ViewController.h"
#import "UkeDrawingCanvas.h"

@interface ViewController ()
@property (nonatomic, strong) UkeDrawingCanvas *canvas;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createCanvas];
}

- (IBAction)brush:(id)sender {
    [self.canvas chooseBrush];
}

- (IBAction)eraser:(id)sender {
    [self.canvas chooseEraser];
}

- (IBAction)reset:(id)sender {
    [self.canvas removeFromSuperview];
    self.canvas = nil;
}

- (void)createCanvas {
    [self.canvas removeFromSuperview];
    self.canvas = nil;
    
    CGFloat ratio = 16.f / 9.f;
    UkeDrawingCanvas *canvas = [[UkeDrawingCanvas alloc] init];
    canvas.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.3f];
    canvas.frame = CGRectMake(0, 0, CGRectGetHeight(self.view.frame) * 0.8f * ratio, CGRectGetHeight(self.view.frame) * 0.8f);
    canvas.visualSize = canvas.frame.size;
    canvas.center = self.view.center;
    [self.view addSubview:canvas];
    [canvas authorizeDrawing];
    
    self.canvas = canvas;
}

@end
