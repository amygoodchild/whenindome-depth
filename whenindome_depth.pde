/*
/ Runs depth based imagery on "When in Dome", a geodesic dome filled with LEDs
/ 
/ Uses Fadecandy and OPC to map ~4300 LEDs
/ 
/ Uses a Kinect as a depth sensor. The depth camera feed is essentially mapped to colour, and displayed directly over the LEDs. 
/ The colour of each pixel in the depth feed dithers back and forth around it's actual hue, to add a shimmering effect.
/ When starting the sketch, click to take a background reading, then anything that is closer than that background reading will display, 
/ this means that actual movement stands out, instead of showing the whole globby mass of depthy nonsense. 
/
/ There is also a function to reset this background reading every x frames, so if people inside the dome are lying still,
/ they will not show up - allows for more interaction
/ 
/ Also has a background animation, the amount of this is inversely mapped to the amount of action happening in the dome,
/ so if no one is present or they are still, there is a lot of animation. Then it disappears when people move inside. 
*/

import org.openkinect.freenect.*;
import org.openkinect.processing.*;
import netP5.*;
import oscP5.*;

Kinect kinect;

// Options for the Kinect feed
boolean ir = false;
boolean colorDepth = true;
boolean mirror = true;

// Fadecandy server
OPC opc;

// Counting how many LEDs are in each section of strip, there are several different types of triangle so they have different lengths
int[][] isoCounts;
int[][] equiCounts;
int[][] isoLongFirst;       
int[][] isoLongFirstWrong; // Lol I literally have one triangle where I soldered one strip with one too many LEDs. 
                           // Decided to fix it in the code rather than get out the soldering iron

// Uh this is kind of nonsense but I mapped all the pixels on a high resolution monitor 
// and then just scaled it down so I can see what I'm doing on smaller monitors instead of redoing it all
float scale = 0.7;


boolean resetter = false; // Option to turn off the background resetting function
int resetSpeed = 240;  // How often (in frames) to run the resetting function

// Stars are the background animation
Star[] stars;
int numberOfStars = 300;
int numberOfStarstoDisplay = 300; // When there's lot of action happening, this number goes down
int action; // Counts up how much depth stuff is going on

// For dithering the colours back and forth
int maxHueDiff = 80;
int minHueDiff = -80;
float hueChangeSpeed = 5;
float[][] hueDifference;

PImage depth;

float[] depths;  // Depth feed in numbers
float[] originalDepths;  // Background readings to compare to

// Osc connection so I can control some variables via TouchOSC on my phone, 
// mainly because it is fun and makes me feel cool 
OscP5 oscP5;
NetAddress myRemoteLocation;

void setup() {
  
  size(1765,1360);
  background(0);

  kinect = new Kinect(this);
  kinect.initDepth();
  kinect.initVideo();
  kinect.enableColorDepth(colorDepth);

  // background animation
  stars = new Star[numberOfStars];
  
  // initialise depth and background depth arrays
  depths = new float[307200];
  originalDepths = new float[307200];
   
  for (int i=0; i<depths.length; i++){
    depths[i] = 0;
  }
  for (int i=0; i<originalDepths.length; i++){
    originalDepths[i] = 0;
  }
  
  // initialise an array to dither the hue of each pixel
  hueDifference = new float[307200][2]; 
  
  for (int i=0; i<originalDepths.length; i++){   
    hueDifference[i][0] = random(minHueDiff,maxHueDiff); // start it off somewhere random
    hueDifference[i][1] = random(0,1);     // decides whether we're fading up or down
  }
  
  // background animation, its just a bunch of fadey circles, probably will improve this soon 
  for (int i=0; i<stars.length; i++){
    stars[i] = new Star();
  }

  colorMode(HSB, 360);
  frameRate(30);
  
  isoCounts = new int[2][7];
  equiCounts = new int[2][12];  
  isoLongFirst = new int[2][7];
  isoLongFirstWrong = new int[2][7];
  
  // fadecandy line counts
  isoLongFirst[0][0] = 0;
  isoLongFirst[0][1] = 28;
  isoLongFirst[0][2] = 64;
  isoLongFirst[0][3] = 83;
  isoLongFirst[0][4] = 98;
  isoLongFirst[0][5] = 109;
  isoLongFirst[0][6] = 116;   
  
  // in strip
  isoLongFirst[1][0] = 28;
  isoLongFirst[1][1] = 23;
  isoLongFirst[1][2] = 19;
  isoLongFirst[1][3] = 15;
  isoLongFirst[1][4] = 11;
  isoLongFirst[1][5] = 7;
  isoLongFirst[1][6] = 3;
  
  
  //fc count
  isoLongFirstWrong[0][0] = 0;
  isoLongFirstWrong[0][1] = 29;
  isoLongFirstWrong[0][2] = 64;
  isoLongFirstWrong[0][3] = 83;
  isoLongFirstWrong[0][4] = 98;
  isoLongFirstWrong[0][5] = 109;
  isoLongFirstWrong[0][6] = 116;   
  
  // in strip
  isoLongFirstWrong[1][0] = 29;
  isoLongFirstWrong[1][1] = 23;
  isoLongFirstWrong[1][2] = 19;
  isoLongFirstWrong[1][3] = 15;
  isoLongFirstWrong[1][4] = 11;
  isoLongFirstWrong[1][5] = 7;
  isoLongFirstWrong[1][6] = 3;
    
  //fc count
  isoCounts[0][0] = 0;
  isoCounts[0][1] = 3;
  isoCounts[0][2] = 10;
  isoCounts[0][3] = 21;
  isoCounts[0][4] = 36;
  isoCounts[0][5] = 64;
  isoCounts[0][6] = 87;   
  
  // in strip
  isoCounts[1][0] = 3;
  isoCounts[1][1] = 7;
  isoCounts[1][2] = 11;
  isoCounts[1][3] = 15;
  isoCounts[1][4] = 19;
  isoCounts[1][5] = 23;
  isoCounts[1][6] = 28;
  
  // fc count
  equiCounts[0][0] = 0;
  equiCounts[0][1] = 30;
  equiCounts[0][2] = 64;
  equiCounts[0][3] = 94;
  equiCounts[0][4] = 128;
  equiCounts[0][5] = 150;
  equiCounts[0][6] = 172;
  equiCounts[0][7] = 192;
  equiCounts[0][8] = 206;
  equiCounts[0][9] = 220;
  equiCounts[0][10] = 226;
  equiCounts[0][11] = 232;
  
  // in strip
  equiCounts[1][0] = 30;
  equiCounts[1][1] = 30;
  equiCounts[1][2] = 30;
  equiCounts[1][3] = 22;
  equiCounts[1][4] = 22;
  equiCounts[1][5] = 22;
  equiCounts[1][6] = 14;
  equiCounts[1][7] = 14;
  equiCounts[1][8] = 14;
  equiCounts[1][9] = 6;
  equiCounts[1][10] = 6;
  equiCounts[1][11] = 6;
  
  // Connect to the local instance of fadecandy server. 
  opc = new OPC(this, "127.0.0.1", 7890);
  opc.showLocations(false);
 
  // Mapping the LEDs 
 
 
  // void [variousisoscelestrianglefunctions)(int index, float x, float y, float angle){
  // index: start of the triangle on fadecandy
  // x: centre of pentagon
  // y: centre of pentagon
  // angle: angle of triangle from centre to base, in degrees to avoid destroying my brain
  // side 1 is base, clockwise from there. 
 
  // bottom left pentagon
  opc.isoShortFirstLeft(0, 330, 1060, 90);        // 1A
  opc.isoShortFirstLeft(128, 330, 1060, 162);      // 1B
  opc.isoShortFirstRight(256, 330, 1060, 234);     // 1C
  opc.isoLongFirstLeft(3456, 330, 1060, 306);    // 7C
  opc.isoLongFirstRight(3328, 330, 1060, 18);    // 7B
  
  // top left pentagon
  opc.isoLongFirstRight(3968, 520, 390, 90);      // 8C
  opc.isoLongFirstLeft(768, 520, 390, 162);       // 2B 
  opc.isoLongFirstRight(896, 520, 390, 234);      // 2C
  opc.isoLongFirstLeft(1024, 520, 390,306);     // 3A
  opc.isoLongFirstRight(4096, 520, 390, 18);     // 9A  
  
  // top right pentagon
  opc.isoLongFirstLeft(4608, width-520, 390, 90);      // 10A
  opc.isoLongFirstLeft(4480, width-520, 390, 162);      // 9C 
  opc.isoLongFirstRight(1408, width-520, 390, 234);     // 3C
  opc.isoLongFirstLeftWrong(1536, width-520, 390, 306);     // 4A
  opc.isoLongFirstRight(1664, width-520, 390, 18);     // 4B    
  
  // bottom right pentagon
  opc.isoShortFirstRight(2304, width-330, 1060, 90);   // 5C
  opc.isoLongFirstLeft(2816, width-330, 1060, 162);   // 6B
  opc.isoLongFirstRight(2944, width-330, 1060, 234);  // 6C
  opc.isoShortFirstLeft(2048, width-330, 1060, 306);  // 5A
  opc.isoShortFirstLeft(2176, width-330, 1060, 18);  // 5B 
  
  // centre pentagon
  opc.isoShortFirstRight(5248, width/2, 878, 126);   // 11B
  opc.isoLongFirstLeft(3584, width/2, 878, 198);   // 8A
  opc.isoShortFirstLeft(5376, width/2, 878, 270);  // 11C
  opc.isoLongFirstRight(4992, width/2, 878, 342);  // 10C
  opc.isoShortFirstLeft(5120, width/2, 878, 54);  // 11A  
  
  
  //void ledEquilateral(int index, float x, float y, float angle){
  // index: start of the triangle on fadecandy
  // x: centre of triangle
  // y: centre of triangle
  // angle: angle of triangle from centre to base, in degrees to avoid destroying my brain
  // side 1 is base, clockwise from there.
  
  // top pair
  opc.ledEquilateral(1152, width/2, 125, 150); // 3B 
  opc.ledEquilateral(4224, width/2, 513, 330);  // 9B  
  
  // right pair
  opc.ledEquilateral(1792, 1595, 641, 342); // 4C 
  opc.ledEquilateral(4736, 1225, 759, 282);  // 10B    
  
  // left pair
  opc.ledEquilateral(512, width-1595, 641, 318); // 2A
  opc.ledEquilateral(3712, width-1225, 759, 18);  // 8B   
  
  // bottom pair (left first)
  opc.ledEquilateral(3072, 685, 1182, 305); // 7A
  opc.ledEquilateral(2560, width-685, 1182, 355);  // 6A   
  
  
  // Connect to the local instance of fcserver. You can change this line to connect to another computer's fcserver
  opc = new OPC(this, "127.0.0.1", 7890);
  opc.showLocations(false);
  
  
  // start oscP5, listening for incoming messages at port 12000
  oscP5 = new OscP5(this,12000);
  // might want to send messages back one day i guess
  myRemoteLocation = new NetAddress("192.168.8.231",12000);
  
  noStroke();
}

void draw() {
 
  //background(0);
  
  fill(0,0,0,30);
  rect(0,0,width,height);  // low opacity background for nice fadey-ness
  
  //image(kinect.getVideoImage(), 620, 0); // useful for testing

   numberOfStarstoDisplay = int( map(action, 0,1500, numberOfStars, 0)); // map the amount of stars to the action, inversely
   action = 0; // reset the action amount
   
  for (int i=0; i< numberOfStarstoDisplay; i++){
    stars[i].update();
    stars[i].display();
  }
  
  fill(100,50,100);
  noStroke();

  depth = kinect.getDepthImage();

  // Take a new background reading
  if (frameCount % resetSpeed == 0 && resetter == true){

    for (int x=0; x < depth.width; x++){
      for (int y=0; y < depth.height; y++){
        int loc = x + y * depth.width;
        color currentColor = depth.pixels[loc];     
        if (hue(currentColor) !=0){
          originalDepths[loc] = hue(currentColor);  
        }
      }
    }      
  }
  

  adjustHue();
  drawDepthDifference();
  
 
  fill(0,0,0);
  rect(0,0,50,30);
  fill(360,0,360);
  text(frameRate,10,10);

  
}



void drawDepthDifference(){
   
  // Go through each pixel in the depth feed (well, actually, skip through them in fours, for speed) 
  for (int x=0; x < depth.width; x+=4){
    for (int y=0; y < depth.height; y+=4){
      int loc = x + y * depth.width;
      color currentColor = depth.pixels[loc];
      
      // if it's sufficiently different from the background depth
      if (hue(currentColor)+10<originalDepths[loc]){
        
        // update the value in the array, but gently, using lerp, this makes everything smoother
        depths[loc] = lerp(depths[loc], hue(currentColor), 0.3);
        
        // checking for outliers
        if (depths[loc] > 20 && depths[loc] < 350){
          
          // dither the hue by the difference amount
          float hue = depths[loc] + hueDifference[loc][0];
          if (hue > 360){
            hue = 360-hue;
          }
          
          if (hue < 0){
            hue = 360+hue;
          }
          // this pixel shows some movement, so add to the action count
          action++;
          
          // Draw that shit. 
          // Translated around so it fits on the LEDs in the right place
          fill(hue, 200,360,100);
          pushMatrix();
          translate(width/2, height/2);
          rotate(3.14);
          translate(900, -260);
          scale(-1,1);
          rect(x*2,y*2,12,12);
          popMatrix();
        }
      }
    }
  }
}

// Dithering the hue back and forth
void adjustHue(){
  for (int i=0; i<originalDepths.length; i++){   
    if (hueDifference[i][1] > 0.5){
      hueDifference[i][0] += hueChangeSpeed;
    }
    else{
       hueDifference[i][0] -= hueChangeSpeed;
    }
    
    if (hueDifference[i][0] > maxHueDiff){
      hueDifference[i][1] = 0.0; 
    }
    if (hueDifference[i][0] < minHueDiff){
      hueDifference[i][1] = 1.0; 
    }    
  }  
}


/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage) {
  // update various variables when receiving messages from TouchOSC app. 
  
  if (theOscMessage.addrPattern().equals("/resettimer")){
     
     resetSpeed = int(theOscMessage.get(0).floatValue());
  }
  if (theOscMessage.addrPattern().equals("/resetnever")){
     
     resetter = false;
  }
  if (theOscMessage.addrPattern().equals("/maxhuediff")){
     maxHueDiff = int(theOscMessage.get(0).floatValue());
  }  
  if (theOscMessage.addrPattern().equals("/minhuediff")){
     minHueDiff = int(theOscMessage.get(0).floatValue());
  }  
  if (theOscMessage.addrPattern().equals("/huechangespeed")){
     hueChangeSpeed = int(theOscMessage.get(0).floatValue());
  }   
  if (theOscMessage.addrPattern().equals("/resetnow")){
    
    for (int x=0; x < depth.width; x++){
        for (int y=0; y < depth.height; y++){
          int loc = x + y * depth.width;
          color currentColor = depth.pixels[loc];     
          if (hue(currentColor) !=0){
            originalDepths[loc] = hue(currentColor);  
          }
       }
     }   
  }  
}

void mousePressed(){
  // Do the background reading
  for (int x=0; x < depth.width; x++){
    for (int y=0; y < depth.height; y++){
      int loc = x + y * depth.width;
      color currentColor = depth.pixels[loc];     
      if (hue(currentColor) !=0){
        originalDepths[loc] = hue(currentColor);  
      }  
    }
  }   
}
  


// Other older functions below, not using these any more but could be useful for testing

void drawDepthFull(){
  for (int x=0; x < depth.width; x++){
    for (int y=0; y < depth.height; y++){
      int loc = x + y * depth.width;
      color currentColor = depth.pixels[loc];
      //depths[loc] = hue(currentColor);
      depths[loc] = lerp(depths[loc], hue(currentColor), 0.3);
      if (depths[loc] > 10 && depths[loc] < 350){
        fill(depths[loc], 300,360);
        pushMatrix();
        translate(width/2, height/2);
        rotate(3.14);
        translate(900, -260);
        scale(-1,1);
        rect(x*2,y*2,2,2);
        popMatrix();
      }
    }
  }
}

void drawDepth(){
  for (int x=0; x < depth.width; x+=5){
    for (int y=0; y < depth.height; y+=5){
      int loc = x + y * depth.width;
      color currentColor = depth.pixels[loc];
      //depths[loc] = hue(currentColor);
      depths[loc] = lerp(depths[loc], hue(currentColor), 0.3);
      if (depths[loc] > 10 && depths[loc] < 350){
        fill(depths[loc], 300,360);
        pushMatrix();
        translate(width/2, height/2);
        rotate(3.14);
        translate(-800, -700);
        rect(x*3,y*3,30,30);
        popMatrix();
      }
    }
  }
}


void drawRawDepth(){
  
  pushMatrix();
  scale(2.5);
  translate(width/2, height/2);
  rotate(3.14);
  translate(400, 200);
  image(depth,0, 0);
  popMatrix();
  
}

void drawRawDepthNoAdjust(){
  
 
  image(depth,0, 0);
  
}
