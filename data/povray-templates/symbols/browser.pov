// browser : globe with latitude and longitude
union {
    torus { 0.64, 0.09 rotate <90, 0, 0> }
    torus { 0.64, 0.055 scale <0.43, 1, 1> rotate <90, 0, 0> }
    cylinder { <-0.58, 0, 0>, <0.58, 0, 0>, 0.055 }
    cylinder { <0, -0.58, 0>, <0, 0.58, 0>, 0.045 }
    material { IconMaterial }
}
