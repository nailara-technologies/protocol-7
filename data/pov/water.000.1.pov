// POV-Ray 3.6 / 3.7 Scene File "water.pov"

// adapted from canoe.pov

#version 3.6; // 3.7;
#global_settings{ assumed_gamma 1.0 }
#default{ finish{ ambient 0.1 diffuse 0.9 }}

#include "colors.inc"
#include "textures.inc"

// camera -----------------------------------------------------------
#declare cam0 = camera { perspective angle 142
                         location  < 0.0 , 5.47 , -13.0>
                         right     x*image_width/image_height
                         look_at   <0.42 , 0.13137 , 0.0> }
camera{ cam0 }
// sun ---------------------------------------------------------------
light_source{ < 1500,2500,-2500 > color rgb<0,0,0.13> }
// sky ---------------------------------------------------------------

// sphere{<0,0,0>,1 hollow
//     texture{ pigment{gradient <0,0,0.13>
//                     color_map{[0.0 color Black  ]
//                               [0.01 color SkyBlue*13]
//                               [0.7 color rgb<0,0,0.7>] }
//                     quick_color White }
//             finish { ambient 1 diffuse 0.42 phong 0.13 }
//            }
//     scale 10000 }


   sky_sphere{
    pigment{ gradient <0,1,0>
             color_map{
             [0.0 color rgb<1,1,1>        ]
             [0.1 color rgb<0.1,0.25,0.75>]
             [1.0 color rgb<0.1,0.25,0.75>]}
           } // end pigment
    } // end of sky_sphere -----------------

//------------------------------------------------------- the Water ----
difference{
plane{ <0,1,0>, 0 }

   texture{ Polished_Chrome

      normal{ bozo 1.113
         scale <2.0,1,0.3>*0.20
         rotate<0,10,0>
         turbulence 0.9
         translate<0,0,-2>
       }


//                normal {  bumps 0.97 // crackle 1.1
//                          scale 5
//                          turbulence 1 translate<0,0,3.13>}


                    finish { ambient 0 diffuse 0.5 reflection 0.42 } }
          }// end of difference

//------------------------------------------------------------------- end
