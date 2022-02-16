// copied from 'PoVRay 3.7 Scene File "IsoWaterPool_01.pov" [f-lohmueller.de]'
//--------------------------------------------------------------------------
#version 3.7;
global_settings{ assumed_gamma 1.0 }
#default{ finish{ ambient 0.1 diffuse 0.9 }}
//--------------------------------------------------------------------------
#include "colors.inc"
#include "textures.inc"
#include "glass.inc"
#include "metals.inc"
#include "golds.inc"
#include "stones.inc"
#include "woods.inc"
#include "shapes.inc"
#include "shapes2.inc"
#include "functions.inc"
#include "math.inc"
#include "transforms.inc"
//--------------------------------------------------------------------------
// camera ------------------------------------------------------------------
//#declare Camera_0 = camera {/*ultra_wide_angle*/ angle 75    // front view
#declare Camera_0 = camera {/*ultra_wide_angle*/ angle 17      // front view
                            location  <0.0 , 1.0 ,-6.0>
                            right     x*image_width/image_height
                            look_at   <0.0 , -1.0, 0.0>}
#declare Camera_1 = camera {/*ultra_wide_angle*/ angle 70   // diagonal view
                            location  <4.0 , 7.5 ,-5.0>
                            right     x*image_width/image_height
                            look_at   <1.0 , 0.0 , -2.5>}
#declare Camera_2 = camera {/*ultra_wide_angle*/ angle 90 // right side view
                            location  <4.0 , 1.0 , 0.0>
                            right     x*image_width/image_height
                            look_at   <0.0 , 0.0 , 0.0>}
#declare Camera_3 = camera {/*ultra_wide_angle*/ angle 40        // top view
                            location  <0.0 , 20.0 ,-2.00-0.001>
                            right     x*image_width/image_height
                            look_at   <0.0 , 1.0 , -2.00>}
camera{ Camera_0 }
// sun ---------------------------------------------------------------------
light_source{<-3500,1000,-1500> color rgb<0.8,0.9,1> }
// sky ---------------------------------------------------------------------
plane{<0,1,0>,1 hollow
       texture{ pigment{ bozo turbulence 0.92
                         color_map { [0.00 rgb <0.25, 0.30, 1.0>*0.8]
                                     [0.50 rgb <0.25, 0.30, 1.0>*0.8]
                                     [0.70 rgb <1,1,1>]
                                     [0.85 rgb <0.25,0.25,0.25>]
                                     [1.0 rgb <0.5,0.5,0.5>]}
                        scale<1,1,1.5>*2.5  translate<-2,0,0>
                       }
                finish {ambient 1 diffuse 0} }
       scale 10000}
// fog on the ground -------------------------------------------------
fog { fog_type   2
      distance   150
      color      rgb<0,0,0.07>
      fog_offset 0.1
      fog_alt    2.5
      turbulence 1.8
    }
//---------------------------------------------
//----------------------------- Pool texture
#declare Pool_Tex =
          texture{ pigment{ color rgb<0,0,0.07> }
                   finish { phong 0.50 }
                 } // end of texture
//---------------------------------------------
//----------------------------- Pool dimensions
#declare Pool_X = 5.00;
#declare Pool_Y = 2.00;
#declare Pool_Z = 8.00;
#declare Pool_Inner_Size = <5,-2,8>;
#declare Border = 0.50;
//---------------------------------------------
#declare Pool_Transformation =
  transform{ rotate<0,0,0>
             translate<-2.5,0.10,-6>
           } // end transforme
//---------------------------------------------
#declare Pool_Inner =
  box{<0,-Pool_Y,0>,<Pool_X,Pool_Y,Pool_Z>
     } //--------------------------------------
#declare Pool_Outer =
  box{<-Border, -Pool_Y-0.01, -Border> ,
      <Pool_X+Border,0.001,Pool_Z+Border>
     } //--------------------------------------
//---------------------------------------------
#declare Pool =
difference{
 object{ Pool_Outer texture{Pool_Tex}}
 object{ Pool_Inner texture{Pool_Tex}}
} // end of Difference
//---------------------------------------------
// grass ground
difference{
 plane{ <0,1,0>, 0
        texture{
         pigment{ color rgb<0.35,0,0.65>*0.13 }
         normal { bumps 0.75 scale 0.015 }
         finish { phong 0.1 }
        } // end of texture
      }// end plane
 object{ Pool_Outer
        texture{ Pool_Tex }
         transform Pool_Transformation
       } // end hole for the pool
} // end of ground
//---------------------------------------
//---------------------------------------
// placing of the pool:
object{ Pool
        transform Pool_Transformation }
//---------------------------------------
//---------------------------------------
// transparent pool water //-------------
#declare Water_Material =
material{
 texture{
   pigment{ rgbf <0.92,0.99,0.96,0.45> }
   finish { diffuse 0.1 reflection 0.5
            specular 0.8 roughness 0.0003
            phong 1 phong_size 400}
 } // end of texture --------------------
 interior{ ior 1.3 caustics 0.15
 } // end of interior -------------------
} // end of material --------------------
//---------------------------------------
// pigment pattern for modulation
#declare Pigment_01 =
 pigment{ bumps
          turbulence 0.20
          scale <3,1,3>*0.12
          translate<1,0,0>
 } // end pigment
//---------------------------------------
#declare Pigment_Function_01 =
function {
  pigment { Pigment_01 }
} // end of function
//---------------------------------------
// modulation by pigment function
isosurface {
 function{
   y
   +Pigment_Function_01(x,y,z).gray*0.2
 } // end function
 contained_by{
   box{<-Border,-Pool_Y-1.01,-Border>,
       < Pool_X+Border,1, Pool_Z+Border>
      } //
    } // end contained_by
 accuracy 0.01
 max_gradient 2
 material{ Water_Material }
 // dont scale this isosurface!
 // scale the Pigment_01 if necessary!
 transform  Pool_Transformation
} // end of isosurface ------------------
//---------------------------------------
//---------------------------------------
