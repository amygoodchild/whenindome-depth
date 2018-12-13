class Star{

  float x;
  float y;
  float hue;
  float opacity;
  boolean fadingin;
  boolean huefadingin;

  Star(){
    x = random(0,width);
    y = random(0,height);
    hue = random(0,360);
    opacity = random(0,360);
    float random = random(0,1);
    if (random > 0.5){
      fadingin = true;
      huefadingin = true;
    }
    else{
      fadingin = false;
      huefadingin = false;
    }
  }
  
  
  void move(){
    x = random(0,1235);
    y = random(0,960);    
  }
  
  void display(){
    fill(hue, 120,360,opacity);
   rect(x, y, 10,10);
  } 
  
  void update(){
    if (fadingin){
      opacity+=3;
    }
    else{
      opacity-=3;
    }
    
    if (opacity > 360){
      fadingin = false;
    }
    if (opacity <0){
      fadingin = true;
      this.move();
    }
    
    
    if (huefadingin){
      hue+=2;
    }
    else{
      hue-=2;
    }
    
    if (hue > 360){
      huefadingin = false;
    }
    if (hue <0){
      huefadingin = true;
    }
    
  }
}
