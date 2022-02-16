// POV-Ray 3.6 / 3.7 Scene File "canoe.pov"

// code borrowed from Friedrich A. Lohmueller's '2009/Jan-2011'-example

#version 3.6; // 3.7;
#global_settings{ assumed_gamma 1.0 }
#default{ finish{ ambient 0.1 diffuse 0.9 }}

#include "colors.inc"
#include "textures.inc"

// camera -----------------------------------------------------------
#declare Cam0 = camera {perspective angle 40
                        location  < 0.0 , 5.47 , -13.0>
                        right     x*image_width/image_height
                        look_at   <0.4 , 0.013137 , 0.0>}
camera{Cam0}
// sun ---------------------------------------------------------------
light_source{<1500,2500,-2500> color rgb<1,0.9,0.13>}
// sky ---------------------------------------------------------------
sphere{<0,0,0>,1 hollow
       texture{pigment{gradient <0,1,0>
                       color_map{[0.0 color Black  ]
                                 [0.01 color SkyBlue*0.13]
                                 [1.0 color rgb<0,0,0.7>] }
                       quick_color White }
               finish {ambient 1 diffuse 0.42 phong 0.13 }
               }
       scale 10000}

//------------------------------------------------------- the Water ----
difference{
plane{<0,1,0>, 0 }
   texture{Polished_Chrome
                    normal { crackle 1 scale 5
                             turbulence 1 translate<0,0,3.13>}
                    finish { diffuse 0.5 reflection 0.30}}
          }// end of difference

//------------------------------------------------------------------- end
